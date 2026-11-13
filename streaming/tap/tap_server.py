"""The tap's WebSocket server: every phone gets the encoder's access units (M15 opt2-2).

PROTOCOL.md fixes what it sends: a hello on connect, then one binary message per
access unit with a 24-byte header (tap_queue builds both), `{"type":"end"}` when
the pipeline ends, and `{"type":"key"}` from a client asking for a keyframe; the
WebSocket wire is tap_ws (RFC 6455's server side). It listens on loopback only:
the phone reaches it through the player relay's existing port at path `/tap`, so
no new port and no firewall rule is needed.

Delay can never pile up: each client's queue is bounded, and one that falls
behind has its backlog dropped and waits for the next keyframe, which carries
FLAG_DISCONTINUITY (PROTOCOL.md, backlog rule).

One thread accepts, one logs the counters every STATS_LOG_INTERVAL_S, and one
serves each client: it waits on the client's socket and on a wake pipe that
publish() writes one byte to, so the pipeline's thread never blocks and the
client's thread never polls.
"""

import json
import select
import socket
import sys
import threading
import time

import tap_diag
import tap_queue
import tap_ws

# Where the server listens: the session's own machine only, because the relay
# is the only thing that may reach it (PROTOCOL.md).
LISTEN_ADDRESS = "127.0.0.1"

# What one socket read takes: a handshake head, a client's message, or what the
# tap server has sent so far (PROTOCOL.md's tunnel rule).
SOCKET_READ_BYTES = 64 * 1024

# How long a write to a client may block before that client is dropped to its
# next keyframe: on a LAN page, 50 ms of a stalled socket is already late.
SEND_TIMEOUT_S = 0.05

# How often the listener looks up, so stop() can end the accept loop; no client
# ever waits on it.
ACCEPT_TIMEOUT_S = 0.2

# How long a new connection gets to send its upgrade head: the relay forwards
# a head it has already read, so this only catches a connection that never
# speaks.
HANDSHAKE_TIMEOUT_S = 2.0

# How often the counters go to the session's log (PROTOCOL.md's line).
STATS_LOG_INTERVAL_S = 5.0

# How often the diagnostics line goes there: one window a second, so a stall of
# three seconds is three lines (M15 opt2c). PROTOCOL.md's counters keep their
# STATS_LOG_INTERVAL_S, counted in these ticks.
DIAG_LOG_INTERVAL_S = 1.0
STATS_LOG_TICKS = int(STATS_LOG_INTERVAL_S / DIAG_LOG_INTERVAL_S)

# How long stop() gives a client thread to send `end` and close.
SHUTDOWN_WAIT_S = 1.0

# The most a handshake head and a client's message may be: a browser's upgrade
# is a few hundred bytes and a key request a few dozen.
HANDSHAKE_MAX_BYTES = 8 * 1024
CLIENT_MESSAGE_MAX_BYTES = 64 * 1024

# How many connection requests the kernel may hold for a server that accepts
# them one at a time.
LISTEN_BACKLOG = 8


class _Client:
    """One client's socket, queue and the pipe a publish wakes its thread on."""

    def __init__(self, sock, request_key, clock):
        self.sock = sock
        self.queue = tap_queue.ClientQueue(request_key, clock=clock)
        self.wake, self.wake_sender = socket.socketpair()
        self.wake.setblocking(False)
        self.wake_sender.setblocking(False)


class TapServer:
    """The tap's server on loopback: a thread per client, a queue each."""

    def __init__(self, port, request_key, info, clock=time.monotonic):
        self.port = port
        self._request_key = request_key
        self._info = info
        self._clock = clock
        self._lock = threading.Lock()
        self._clients = []
        self._client_threads = []
        self._threads = []
        self._listener = None
        self._closed = threading.Event()
        # The once-a-second counters that say where a backlog grows (M15 opt2c):
        # the pipeline's thread offers frames to it, the client threads report
        # their sends, and the stats thread writes its line.
        self.diag = tap_diag.TapDiag()

    def start(self):
        """Listens on loopback and serves clients until stop()."""
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        listener.bind((LISTEN_ADDRESS, self.port))
        listener.listen(LISTEN_BACKLOG)
        listener.settimeout(ACCEPT_TIMEOUT_S)
        self.port = listener.getsockname()[1]
        self._listener = listener
        for target in (self._accept_loop, self._stats_loop):
            thread = threading.Thread(target=target, daemon=True)
            thread.start()
            self._threads.append(thread)

    def publish(self, frame_no, pts_us, is_key, data):
        """Queues one access unit for every client; never blocks the pipeline."""
        with self._lock:
            clients = list(self._clients)
        for client in clients:
            if client.queue.offer(frame_no, pts_us, is_key, data):
                self._wake(client)
            # The diag reads the queue's depth and its counters after the offer,
            # so a drop or a lost frame is in the second it happened.
            self.diag.queued(client)

    def stop(self):
        """Sends PROTOCOL.md's `end` to every client and closes the server."""
        if self._closed.is_set():
            return
        self._closed.set()
        if self._listener is not None:
            self._listener.close()
        with self._lock:
            clients = list(self._clients)
        for client in clients:
            self._wake(client)
        with self._lock:
            threads = list(self._client_threads)
        for thread in self._threads + threads:
            thread.join(SHUTDOWN_WAIT_S)

    def stats(self):
        """The counters PROTOCOL.md's log line reports: per client and in total."""
        with self._lock:
            queues = [client.queue for client in self._clients]
        return tap_queue.totals(queues)

    def log_stats(self):
        """One line to stderr, as PROTOCOL.md has it: the session's log reads it."""
        stats = self.stats()
        sys.stderr.write(
            "tap: clients=%d sent=%d dropped=%d keyreq=%d\n"
            % (stats["clients"], stats["sent"], stats["dropped"], stats["keyreq"])
        )

    def _accept_loop(self):
        while not self._closed.is_set():
            try:
                sock, _ = self._listener.accept()
            except socket.timeout:
                continue
            except OSError:
                # stop() closed the listener under this accept.
                return
            self._add(sock)

    def _stats_loop(self):
        # wait() returns at once when stop() sets the event, so the thread ends
        # with the server. Each tick closes a diag window; every STATS_LOG_TICKS
        # of them PROTOCOL.md's own counters go out.
        ticks = 0
        while not self._closed.wait(DIAG_LOG_INTERVAL_S):
            line = self.diag.line()
            if line is not None:
                sys.stderr.write(line + "\n")
            ticks += 1
            if ticks % STATS_LOG_TICKS == 0:
                self.log_stats()

    def _add(self, sock):
        """Starts the thread that serves one freshly accepted connection."""
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.settimeout(HANDSHAKE_TIMEOUT_S)
        client = _Client(sock, self._request_key, self._clock)
        self.diag.client_added(client, sock, client.queue.level)
        with self._lock:
            self._clients.append(client)
            thread = threading.Thread(target=self._serve, args=(client,), daemon=True)
            self._client_threads.append(thread)
        thread.start()

    def _serve(self, client):
        try:
            leftover = self._handshake(client)
            if leftover is None:
                return
            # Both directions time out from here: a write that blocks past
            # SEND_TIMEOUT_S drops the client to its next keyframe, and a read
            # only ever happens when select says there is something to read.
            client.sock.settimeout(SEND_TIMEOUT_S)
            if not self._write(client, tap_ws.OPCODE_TEXT, self._hello_text().encode("utf-8"), is_frame=False):
                return
            # PROTOCOL.md: a new client starts on the next keyframe, so one is
            # asked for here, before the first frame it could be sent.
            client.queue.request_keyframe()
            self._loop(client, leftover)
        finally:
            self._remove(client)

    def _hello_text(self):
        """PROTOCOL.md's hello with `chroma420` beside its fields (M15 opt2b-2).

        The field is extra to v1, which has no name for it: a page that does
        not know it ignores it, and one that does can say why a Safari decoder
        refuses a stream that is not 4:2:0.
        """
        info = self._info()
        hello = json.loads(tap_queue.hello_message(info))
        hello["chroma420"] = info.get("chroma420")
        return json.dumps(hello)

    def _handshake(self, client):
        """Answers RFC 6455's upgrade; the bytes received after the head, or None.

        Only a GET for /tap that asks to upgrade is a WebSocket client; anything
        else is closed unanswered, because the relay only tunnels that one
        request and nothing else can reach this port.
        """
        buffer = b""
        while b"\r\n\r\n" not in buffer:
            if len(buffer) > HANDSHAKE_MAX_BYTES:
                return None
            try:
                data = client.sock.recv(SOCKET_READ_BYTES)
            except OSError:
                return None
            if not data:
                return None
            buffer += data
        head, _, leftover = buffer.partition(b"\r\n\r\n")
        key = tap_ws.upgrade_key(head)
        if key is None:
            return None
        answer = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "Sec-WebSocket-Accept: %s\r\n\r\n" % tap_ws.accept_value(key)
        )
        try:
            client.sock.sendall(answer.encode("ascii"))
        except OSError:
            return None
        return leftover

    def _loop(self, client, buffer):
        """Serves one client: reads its messages and writes its queued frames."""
        fragments = bytearray()
        while True:
            readable, _, _ = select.select([client.sock, client.wake], [], [])
            if self._closed.is_set():
                self._write(client, tap_ws.OPCODE_TEXT, tap_queue.END_MESSAGE, is_frame=False)
                return
            if client.wake in readable:
                self._wake_drained(client)
            if client.sock in readable:
                try:
                    data = client.sock.recv(SOCKET_READ_BYTES)
                except OSError:
                    return
                if not data:
                    return
                buffer += data
                buffer, fragments = self._read_frames(client, buffer, fragments)
                if buffer is None:
                    return
            if not self._write_queued(client):
                return

    def _read_frames(self, client, buffer, fragments):
        """Every whole frame in `buffer`; a None buffer means the client must go."""
        while True:
            wire = tap_ws.decode_frame(buffer)
            if wire is None:
                return buffer, fragments
            buffer = buffer[wire.consumed :]
            if not wire.masked or len(wire.payload) > CLIENT_MESSAGE_MAX_BYTES:
                return None, fragments
            if wire.opcode == tap_ws.OPCODE_CLOSE:
                self._write(client, tap_ws.OPCODE_CLOSE, wire.payload, is_frame=False)
                return None, fragments
            if wire.opcode == tap_ws.OPCODE_PING:
                if not self._write(client, tap_ws.OPCODE_PONG, wire.payload, is_frame=False):
                    return None, fragments
                continue
            if wire.opcode not in (tap_ws.OPCODE_TEXT, tap_ws.OPCODE_CONTINUATION):
                continue
            fragments += wire.payload
            if len(fragments) > CLIENT_MESSAGE_MAX_BYTES:
                return None, fragments
            if wire.fin:
                self._message(client, bytes(fragments))
                fragments = bytearray()

    def _message(self, client, payload):
        """PROTOCOL.md's client text: a key request is the only one acted on.

        `{"type":"stats",...}` is optional and ignored, and so is anything this
        version does not know: a page must not lose its stream over a message
        the server did not expect.
        """
        try:
            message = json.loads(payload.decode("utf-8"))
        except ValueError:
            return
        if isinstance(message, dict) and message.get("type") == tap_queue.KEY_MESSAGE_TYPE:
            client.queue.request_keyframe()

    def _write_queued(self, client):
        """Writes every frame queued for this client; False when the client must go."""
        while True:
            frame = client.queue.take(0)
            if frame is None:
                return True
            if not self._write(client, tap_ws.OPCODE_BINARY, tap_queue.frame_message(frame, int(time.time() * 1e6))):
                return False

    def _write(self, client, opcode, payload, is_frame=True):
        """Writes one frame; False when the connection can never be in step again.

        A send that blocks past the socket's timeout drops the client to its
        next keyframe while nothing of the frame has gone out; after a partial
        send the frame is half on the wire, so that client is closed instead of
        being sent a stream no browser could parse. tap_diag sends and measures
        it, so every call's time and outcome reach the diag line.
        """
        outcome = tap_diag.send_message(self.diag, client, client.sock, tap_ws.encode_frame(opcode, payload))
        if outcome == tap_diag.SEND_BROKEN:
            return False
        if outcome == tap_diag.SEND_BLOCKED:
            client.queue.drop_to_keyframe()
            return True
        if is_frame:
            client.queue.note_sent(len(payload))
        return True

    def _wake(self, client):
        """Notes that a frame is queued; a full pipe already has a wake pending."""
        try:
            client.wake_sender.send(b"\x01")
        except BlockingIOError:
            pass
        except OSError:
            # The client thread closed its pipe as it left.
            pass

    @staticmethod
    def _wake_drained(client):
        """Empties the wake pipe so the next publish writes one byte again."""
        try:
            while client.wake.recv(SOCKET_READ_BYTES):
                pass
        except OSError:
            # An empty pipe is the normal end of this loop.
            pass

    def _remove(self, client):
        self.diag.client_removed(client)
        with self._lock:
            if client in self._clients:
                self._clients.remove(client)
        for sock in (client.wake, client.wake_sender, client.sock):
            try:
                sock.close()
            except OSError:
                pass
