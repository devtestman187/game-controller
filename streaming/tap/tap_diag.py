"""Where the delay comes from: the tap's once-a-second counters (M15 opt2c).

A collapsed run says a backlog grew but not where it did: these counters keep
the encoder's output, each client's queue and each client's socket apart, in
windows of one second, and render one line per window for the session's log:

    tapdiag: t=<unix s> fr=<n> kb=<n> key=<n> keymax=<KB> dmax=<KB> q=<max depth>
        drop=<n> kreq=<n> sent=<KB> sendmax=<ms> slow=<n> outq=<KB max>

`fr` is the encoder's frames in the window and `kb` their kilobytes, `key` the
keyframes and `keymax` the largest of them, `dmax` the largest delta frame (the
deltas' average is kept too, see window()). `q` is the deepest any client's
queue was, `drop` the frames clients lost and `kreq` the keyframes they asked
for, `sent` the bytes written to their sockets and `sendmax` the longest one
send() call took, `slow` how many took over SLOW_SEND_S, and `outq` the bytes
still unsent in a kernel send buffer. With several clients `q`, `sendmax` and
`outq` are the largest any of them saw; `drop`, `kreq` and `sent` are sums;
partial sends and timeouts are counted too and read through window(). `outq` is
-1 when the kernel will not say.

Each method takes one lock and touches a few integers, so the pipeline's thread
pays almost nothing for a frame.
"""

import fcntl
import socket
import struct
import threading
import time

# How long one send() call may take before it counts as slow: on a LAN page ten
# milliseconds of one write is the socket, not the encoder.
SLOW_SEND_S = 0.01

# How long after the last client was seen a window with frames in it still gets
# a line: those frames may still be on their way to that client.
CLIENT_RECENT_S = 10.0

# What one message's send came to: all of it, nothing of it (the client falls to
# its next keyframe) or part of it (the client can never be in step again).
SEND_OK = "ok"
SEND_BLOCKED = "blocked"
SEND_BROKEN = "broken"

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


def send_message(diag, client, sock, message):
    """Sends one whole message, measuring every send() call; answers a SEND_ value.

    A call that times out with nothing of the message sent leaves the client
    able to start again at its next keyframe; one that times out after part of
    it has gone out leaves a stream no browser could parse, and the client is
    closed instead.
    """
    sent = 0
    while sent < len(message):
        chunk = message[sent:]
        started = time.monotonic()
        try:
            count = sock.send(chunk)
        except socket.timeout:
            diag.send(client, 0, time.monotonic() - started, timed_out=True)
            return SEND_BROKEN if sent else SEND_BLOCKED
        except OSError:
            # A closed or reset connection: the client goes either way.
            return SEND_BROKEN
        sent += count
        diag.send(client, count, time.monotonic() - started, partial=count < len(chunk))
    return SEND_OK


def _kb(size_bytes):
    """Bytes as the line counts them: whole kilobytes, -1 kept as it is."""
    return -1 if size_bytes < 0 else size_bytes // KB_BYTES


class _ClientWindow:
    """One client's part of a window: its queue's counters and its socket's sends.

    The queue's counters are totals that both threads move, so what this window
    counts is what they did since the diag last looked.
    """

    def __init__(self, sock, level):
        self.sock = sock
        self.level = level
        self.closed = False
        self.depth_max = 0
        self.dropped = 0
        self.key_requests = 0
        self.dropped_total = None
        self.key_total = None
        self.sent_bytes = 0
        self.send_max_s = 0.0
        self.slow = 0
        self.timeouts = 0
        self.partial = 0
        self.outq = -1

    def look(self):
        """Adds what the queue's counters did since the last look, and its depth."""
        depth, dropped, key_requests = self.level()
        self.depth_max = max(self.depth_max, depth)
        if self.dropped_total is not None:
            self.dropped += max(0, dropped - self.dropped_total)
            self.key_requests += max(0, key_requests - self.key_total)
        self.dropped_total = dropped
        self.key_total = key_requests

    def reset(self):
        """Starts a window: what this client did is the last line's, not the next one's."""
        self.depth_max = 0
        self.dropped = 0
        self.key_requests = 0
        self.sent_bytes = 0
        self.send_max_s = 0.0
        self.slow = 0
        self.timeouts = 0
        self.partial = 0
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

    def client_added(self, client, sock, level):
        """Tracks one client: the key the other calls use, its socket, its queue's level().

        `level()` answers the queue's depth and its totals of dropped frames and
        keyframe requests, as tap_queue.ClientQueue.level() does.
        """
        with self._lock:
            self._clients[client] = _ClientWindow(sock, level)
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

    def send(self, client, size_bytes, seconds, timed_out=False, partial=False):
        """Counts one send() call: its bytes, how long it took and how it ended."""
        with self._lock:
            window = self._clients.get(client)
            if window is None:
                return
            window.sent_bytes += size_bytes
            window.send_max_s = max(window.send_max_s, seconds)
            if seconds > SLOW_SEND_S:
                window.slow += 1
            if timed_out:
                window.timeouts += 1
            if partial:
                window.partial += 1
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
            "sent=%d sendmax=%d slow=%d outq=%d"
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
                "sent_bytes": 0,
                "send_max_s": 0.0,
                "slow": 0,
                "timeouts": 0,
                "partial": 0,
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
                "sent_kb": _kb(clients["sent_bytes"]),
                "send_max_ms": int(round(clients["send_max_s"] * MS_PER_S)),
                "slow": clients["slow"],
                "timeouts": clients["timeouts"],
                "partial": clients["partial"],
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
        clients["sent_bytes"] += window.sent_bytes
        clients["send_max_s"] = max(clients["send_max_s"], window.send_max_s)
        clients["slow"] += window.slow
        clients["timeouts"] += window.timeouts
        clients["partial"] += window.partial
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
