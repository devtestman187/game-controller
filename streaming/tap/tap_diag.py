"""Where the delay comes from: the tap's once-a-second counters (M15 opt2c).

A collapsed run says a backlog grew but not where it did: these counters keep
the encoder's output, each client's queue and each client's socket apart, in
windows of one second, and render one line per window for the session's log:

    tapdiag: t=<unix s> fr=<n> kb=<n> key=<n> keymax=<KB> dmax=<KB> q=<max depth>
        drop=<n> kreq=<n> sent=<KB> sendmax=<ms> slow=<n> blocked=<ms> aged=<n>
        outq=<KB max>

`fr` is the encoder's frames in the window and `kb` their kilobytes, `key` the
keyframes and `keymax` the largest of them, `dmax` the largest delta frame (the
deltas' average is kept too, see window()). `q` is the deepest any client's
queue was, `drop` the frames clients lost and `kreq` the keyframes they asked
for, `aged` the frames dropped for being too old to send, `sent` the bytes
written to their sockets and `sendmax` the longest one send() call took, `slow`
how many took over SLOW_SEND_S, `blocked` the time any client's message spent
waiting for its socket (M15 opt2c-4), and `outq` the bytes still unsent in a
kernel send buffer. With several clients `q`, `sendmax` and `outq` are the
largest any of them saw; `drop`, `kreq`, `aged`, `sent`, `slow` and `blocked`
are sums. `outq` is -1 when the kernel will not say.

Each method takes one lock and touches a few integers, so the pipeline's thread
pays almost nothing for a frame.
"""

import fcntl
import struct
import threading
import time

# How long one send() call may take before it counts as slow: on a LAN page ten
# milliseconds of one write is the socket, not the encoder.
SLOW_SEND_S = 0.01

# How long after the last client was seen a window with frames in it still gets
# a line: those frames may still be on their way to that client.
CLIENT_RECENT_S = 10.0

# The line's own units: whole kilobytes, whole milliseconds.
KB_BYTES = 1024
MS_PER_S = 1000

# fcntl.ioctl's TIOCOUTQ: the bytes queued in a socket's kernel send buffer.
# Linux's value, and the reading a kernel that will not answer gives is -1.
TIOCOUTQ = 0x5411


def socket_send_queue(sock):
    """The bytes still unsent in [sock]'s kernel send buffer, or -1 if unknown.

    This is the number that hides a backlog from its sender: a socket whose
    reader is slow takes write after write into its buffer, so send() returns at
    once while the picture is already late.
    """
    try:
        unsent = fcntl.ioctl(sock.fileno(), TIOCOUTQ, b"\x00\x00\x00\x00")
    except (OSError, ValueError):
        return -1
    return struct.unpack("i", unsent)[0]


def _kb(size_bytes):
    """Bytes as the line counts them: whole kilobytes, -1 kept as it is."""
    return -1 if size_bytes < 0 else size_bytes // KB_BYTES


class _ClientWindow:
    """One client's part of a window: its queue's counters and its sender's waits.

    The queue's counters are totals that both threads move, so what this window
    counts is what they did since the diag last looked; the sender's blocked
    time is a total too, so a message still waiting is in the window it waits in.
    """

    def __init__(self, sock, level, blocked_s):
        self.sock = sock
        self.level = level
        self.blocked = blocked_s
        self.closed = False
        self.depth_max = 0
        self.dropped = 0
        self.key_requests = 0
        self.aged = 0
        self.blocked_s = 0.0
        self.dropped_total = None
        self.key_total = None
        self.aged_total = None
        self.blocked_total = None
        self.sent_bytes = 0
        self.send_max_s = 0.0
        self.slow = 0
        self.outq = -1

    def look(self):
        """Adds what the queue's and the sender's totals did since the last look."""
        depth, dropped, key_requests, aged = self.level()
        blocked_s = self.blocked()
        self.depth_max = max(self.depth_max, depth)
        if self.dropped_total is not None:
            self.dropped += max(0, dropped - self.dropped_total)
            self.key_requests += max(0, key_requests - self.key_total)
            self.aged += max(0, aged - self.aged_total)
            self.blocked_s += max(0.0, blocked_s - self.blocked_total)
        self.dropped_total = dropped
        self.key_total = key_requests
        self.aged_total = aged
        self.blocked_total = blocked_s

    def reset(self):
        """Starts a window: what this client did is the last line's, not the next one's."""
        self.depth_max = 0
        self.dropped = 0
        self.key_requests = 0
        self.aged = 0
        self.blocked_s = 0.0
        self.sent_bytes = 0
        self.send_max_s = 0.0
        self.slow = 0
        self.outq = -1


class TapDiag:
    """The window's counters and the line they make (M15 opt2c).

    Thread-safe: the pipeline's thread counts frames and queue offers, each
    client's thread reports its sends, and the server's stats thread closes the
    window once a second with line().
    """

    def __init__(self, clock=time.time, send_queue_bytes=socket_send_queue):
        self._clock = clock
        self._send_queue_bytes = send_queue_bytes
        self._lock = threading.Lock()
        self._clients = {}
        self._last_client_s = None
        self._last_window = {}
        self._reset()

    def frame(self, is_key, size_bytes):
        """Counts one access unit from the encoder: the pipeline thread's only call."""
        with self._lock:
            self._frames += 1
            self._frame_bytes += size_bytes
            if is_key:
                self._keys += 1
                self._key_max = max(self._key_max, size_bytes)
            else:
                self._delta_frames += 1
                self._delta_bytes += size_bytes
                self._delta_max = max(self._delta_max, size_bytes)

    def client_added(self, client, sock, level, blocked_s):
        """Tracks one client: the key the other calls use, its socket, its totals.

        `level()` answers the queue's depth and its totals of dropped, aged and
        asked frames, as tap_queue.ClientQueue.level() does; `blocked_s()`
        answers the seconds its sender's messages have waited, as
        tap_sender.MessageSender.blocked_s() does.
        """
        with self._lock:
            self._clients[client] = _ClientWindow(sock, level, blocked_s)
            self._last_client_s = self._clock()

    def client_removed(self, client):
        """Stops tracking a client; what it did is counted until the window closes."""
        with self._lock:
            window = self._clients.get(client)
            if window is not None:
                window.look()
                window.closed = True
            self._last_client_s = self._clock()

    def queued(self, client):
        """Counts one frame offered to a client: its queue's depth and counters."""
        with self._lock:
            window = self._clients.get(client)
            if window is None:
                return
            window.look()
            self._last_client_s = self._clock()

    def send(self, client, size_bytes, seconds):
        """Counts one send() call: its bytes, how long it took and what is left in the socket."""
        with self._lock:
            window = self._clients.get(client)
            if window is None:
                return
            window.sent_bytes += size_bytes
            window.send_max_s = max(window.send_max_s, seconds)
            if seconds > SLOW_SEND_S:
                window.slow += 1
            window.outq = max(window.outq, self._send_queue_bytes(window.sock))
            self._last_client_s = self._clock()

    def window(self):
        """The numbers of the window line() last closed, as a copy; empty before one."""
        return dict(self._last_window)

    def line(self):
        """Closes the window and renders it, or None when no client is worth a line.

        One line a second while a client is connected, and after the last one
        for a window that holds frames and a client seen within
        CLIENT_RECENT_S; every other window is counted and dropped.
        """
        numbers = self._take(self._clock())
        if not numbers["wanted"]:
            return None
        return (
            "tapdiag: t=%d fr=%d kb=%d key=%d keymax=%d dmax=%d q=%d drop=%d kreq=%d "
            "sent=%d sendmax=%d slow=%d blocked=%d aged=%d outq=%d"
            % (
                numbers["t"],
                numbers["frames"],
                numbers["kb"],
                numbers["keys"],
                numbers["key_max_kb"],
                numbers["delta_max_kb"],
                numbers["depth_max"],
                numbers["dropped"],
                numbers["key_requests"],
                numbers["sent_kb"],
                numbers["send_max_ms"],
                numbers["slow"],
                numbers["blocked_ms"],
                numbers["aged"],
                numbers["outq_kb"],
            )
        )

    def _take(self, now):
        """Closes the window: its numbers, and whether a client asked for a line."""
        with self._lock:
            clients = {
                "connected": False,
                "depth_max": 0,
                "dropped": 0,
                "key_requests": 0,
                "aged": 0,
                "blocked_s": 0.0,
                "sent_bytes": 0,
                "send_max_s": 0.0,
                "slow": 0,
                "outq": -1,
            }
            for key, window in list(self._clients.items()):
                self._add_client(clients, window)
                if window.closed:
                    del self._clients[key]
                else:
                    window.reset()
            recent = self._last_client_s is not None and now - self._last_client_s <= CLIENT_RECENT_S
            delta_average = self._delta_bytes // self._delta_frames if self._delta_frames else 0
            numbers = {
                "t": int(now),
                "frames": self._frames,
                "kb": _kb(self._frame_bytes),
                "keys": self._keys,
                "key_max_kb": _kb(self._key_max),
                "delta_avg_kb": _kb(delta_average),
                "delta_max_kb": _kb(self._delta_max),
                "depth_max": clients["depth_max"],
                "dropped": clients["dropped"],
                "key_requests": clients["key_requests"],
                "aged": clients["aged"],
                "blocked_ms": int(round(clients["blocked_s"] * MS_PER_S)),
                "sent_kb": _kb(clients["sent_bytes"]),
                "send_max_ms": int(round(clients["send_max_s"] * MS_PER_S)),
                "slow": clients["slow"],
                "outq_kb": _kb(clients["outq"]),
                "wanted": clients["connected"] or (self._frames > 0 and recent),
            }
            self._reset()
            self._last_window = numbers
            return numbers

    def _add_client(self, clients, window):
        """Adds one client's numbers to the window's, each as its line field says."""
        window.look()
        window.outq = max(window.outq, self._send_queue_bytes(window.sock))
        clients["connected"] = clients["connected"] or not window.closed
        clients["depth_max"] = max(clients["depth_max"], window.depth_max)
        clients["dropped"] += window.dropped
        clients["key_requests"] += window.key_requests
        clients["aged"] += window.aged
        clients["blocked_s"] += window.blocked_s
        clients["sent_bytes"] += window.sent_bytes
        clients["send_max_s"] = max(clients["send_max_s"], window.send_max_s)
        clients["slow"] += window.slow
        clients["outq"] = max(clients["outq"], window.outq)

    def _reset(self):
        """Starts a window: the encoder's counters at nothing."""
        self._frames = 0
        self._frame_bytes = 0
        self._keys = 0
        self._key_max = 0
        self._delta_frames = 0
        self._delta_bytes = 0
        self._delta_max = 0
