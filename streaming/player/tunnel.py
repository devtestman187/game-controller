"""The relay's /tap tunnel and its once-a-second line (M15 opt2c).

serve.py's Handler passes a page's WebSocket, byte for byte, to the session's
tap server on loopback (PROTOCOL.md); this module is that passing, plus the
counters that say whether the tunnel is where a stream backs up. A phone that
stops reading costs the relay nothing visible — a write goes into the kernel's
send buffer and returns — so the buffer's own size (TIOCOUTQ) and the longest
write are what the line reports, one line a second while a tunnel is open:

    tunnel: t=<unix s> up=<KB> down=<KB> sendmax=<ms> slow=<n> outq=<KB max>

`up` is what the page sent toward the tap server and `down` what the tap server
sent toward the page, both in the window; `sendmax` is the longest write toward
the phone and `slow` how many took over slow_write_s; `outq` is the larger of
the two sockets' unsent bytes, -1 when the kernel will not say.
"""

import fcntl
import socket
import struct
import sys
import threading
import time

# Where the tap server listens, the most one read of the tunnel holds, and the
# wait for a tap server that is not listening yet (PROTOCOL.md: loopback only).
tap_address = "127.0.0.1"
tunnel_read_bytes = 64 * 1024
tunnel_connect_timeout_s = 2

# How often a line goes to the log while the tunnel is open.
log_interval_s = 1.0

# The write time past which one counts as slow: on a LAN page ten milliseconds
# of one write already means the phone, not the network, is the slow side.
slow_write_s = 0.01

# The line's own units: whole kilobytes, whole milliseconds.
kb_bytes = 1024
ms_per_s = 1000

# fcntl.ioctl's TIOCOUTQ: the bytes queued in a socket's kernel send buffer.
# Linux's value, and the reading a kernel that will not answer gives is -1.
tiocoutq = 0x5411


def socket_send_queue(sock):
    """The bytes still unsent in [sock]'s kernel send buffer, or -1 if unknown.

    The same reading tap_diag makes for a tap client
    (streaming/tap/tap_diag.py): the two run in different processes and folders,
    so each keeps its own copy.
    """
    try:
        unsent = fcntl.ioctl(sock.fileno(), tiocoutq, b"\x00\x00\x00\x00")
    except (OSError, ValueError):
        return -1
    return struct.unpack("i", unsent)[0]


def relay(tap_port, phone, phone_read, requestline, headers):
    """Tunnels one request to the tap server until a side closes.

    `phone` is the page's connection, `phone_read` its buffered read
    (rfile.read1), and `requestline` and `headers` the head the page sent, which
    the tap server answers itself. A tap server that is not answering raises
    OSError before anything is written, so the caller can still answer 502.
    """
    tap = socket.create_connection((tap_address, tap_port), timeout=tunnel_connect_timeout_s)
    tap.settimeout(None)
    for sock in (tap, phone):
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    head = requestline + "\r\n" + "".join("%s: %s\r\n" % item for item in headers.items()) + "\r\n"
    Tunnel(phone, tap).run(head.encode("latin-1"), phone_read)


def _copy(read, write):
    """Copies one side of a tunnel to the other until a side closes."""
    try:
        while True:
            data = read(tunnel_read_bytes)
            if not data:
                return
            write(data)
    except OSError:
        pass  # a socket closed under the copy, which is how a tunnel ends


def _shut(sock):
    """Ends a tunnel socket both ways, so a thread blocked on it returns."""
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass


def _kb(size_bytes):
    """Bytes as the line counts them: whole kilobytes, -1 kept as it is."""
    return -1 if size_bytes < 0 else size_bytes // kb_bytes


class Tunnel:
    """One tunnel's counters and the thread that writes its line a second.

    Each direction is copied by one thread, so the lock only keeps the line's
    reads and the copies' additions apart.
    """

    def __init__(self, phone, tap, clock=time.time, send_queue_bytes=socket_send_queue):
        self._phone = phone
        self._tap = tap
        self._clock = clock
        self._send_queue_bytes = send_queue_bytes
        self._lock = threading.Lock()
        self._closed = threading.Event()
        self._up = 0
        self._down = 0
        self._send_max_s = 0.0
        self._slow = 0
        self._thread = threading.Thread(target=self._log_loop, daemon=True)

    def run(self, head, phone_read):
        """Takes the page's head to the tap server and copies both ways until a side closes."""
        self._thread.start()
        try:
            # The tap server's answer may come before the page sends anything
            # more, so its way down starts first (as the relay always had it).
            threading.Thread(target=self._copy_down, daemon=True).start()
            self._write_up(head)
            _copy(phone_read, self._write_up)
        finally:
            self._closed.set()
            self._thread.join(log_interval_s)
            _shut(self._tap)
            _shut(self._phone)

    def line(self):
        """One line for the window that just ended; a new window starts with it."""
        with self._lock:
            outq = max(self._send_queue_bytes(self._phone), self._send_queue_bytes(self._tap))
            line = "tunnel: t=%d up=%d down=%d sendmax=%d slow=%d outq=%d\n" % (
                int(self._clock()),
                _kb(self._up),
                _kb(self._down),
                int(round(self._send_max_s * ms_per_s)),
                self._slow,
                _kb(outq),
            )
            self._up = 0
            self._down = 0
            self._send_max_s = 0.0
            self._slow = 0
            return line

    def _log_loop(self):
        # wait() returns at once when the tunnel closes, so the thread ends with it.
        while not self._closed.wait(log_interval_s):
            sys.stderr.write(self.line())

    def _copy_down(self):
        """The tap server's bytes toward the phone, timed (a phone that stalls shows here)."""
        _copy(self._tap.recv, self._write_phone)

    def _write_up(self, data):
        """Writes one block toward the tap server, counting it up."""
        self._tap.sendall(data)
        with self._lock:
            self._up += len(data)

    def _write_phone(self, data):
        """Writes one block toward the phone, counting it and how long it took."""
        started = time.monotonic()
        self._phone.sendall(data)
        seconds = time.monotonic() - started
        with self._lock:
            self._down += len(data)
            self._send_max_s = max(self._send_max_s, seconds)
            if seconds > slow_write_s:
                self._slow += 1
