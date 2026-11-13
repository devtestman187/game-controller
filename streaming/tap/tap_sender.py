"""The tap's sender: one message at a time, finished when the socket allows (M15 opt2c-4).

The client's queue (tap_queue) holds the frames; this writes them to the
socket. A message is never abandoned half-way: when the socket takes only part
of it, the rest waits for writability and the client's thread selects on it, so
a phone on a slow link pushes back to the host instead of being closed half a
keyframe in. The frames that arrive meanwhile wait in the client's four-frame
queue, and a control message (hello, pong, close, end) goes after the message
that is half written, never inside it, because a WebSocket frame may not be
interrupted.

Back-pressure is only visible because a hop's send buffer is small
(tap_server.TAP_SNDBUF_BYTES, the same on the relay's phone side): with the
kernel's auto-tuned megabytes a stalled phone absorbs seconds of video before a
send blocks, and nothing on the host side sees the stall (M15 opt2c's evidence).
`blocked_s()` is how long this client's messages have waited in all, which is
what the diag line reports as `blocked`.

Before a message starts, the queue drops every frame older than two frame times
of the hello's fps (AGE_FRAME_TIMES, 34 ms at 60 fps): a frame that old draws a
picture the page has already passed. A client that takes nothing for
STALL_CLOSE_S has left, and its thread closes the connection.
"""

import socket
import time
from collections import deque

import tap_queue
import tap_ws

# The frame rate a hello that names none is taken as: the pipeline's default.
DEFAULT_FPS = 60

# How many frame times a queued frame stays worth sending: two, so a frame is
# never more than 34 ms old at 60 fps when its message starts (M15 opt2c-4).
AGE_FRAME_TIMES = 2

# How long a client may take nothing at all before it is closed: a phone that
# has read no byte in five seconds has left, and waiting longer holds the frame
# it is owed and the socket's buffers for nothing (M15 opt2c-4).
STALL_CLOSE_S = 5.0

# Microseconds in a second: the header's sent_us is whole microseconds.
US_PER_S = 1000 * 1000


def age_limit_s(fps):
    """How old a queued frame may be and still be sent: two frame times."""
    return AGE_FRAME_TIMES / (fps or DEFAULT_FPS)


class MessageSender:
    """One client's outgoing messages and how long they waited for its socket.

    The client's thread calls pump() whenever the socket may accept data; what
    it does not take stays pending and goes out once select says the socket is
    writable again. `wait_s()` says how long select may wait, so a client that
    takes nothing is closed at its deadline rather than held for good.
    """

    def __init__(self, sock, diag, client, fps=DEFAULT_FPS, clock=time.monotonic):
        self._sock = sock
        self._diag = diag
        self._client = client
        self._clock = clock
        self._age_limit_s = age_limit_s(fps)
        self._control = deque()
        self._pending = b""
        self._pending_frame_bytes = 0
        self._pending_since_s = None
        self._blocked_total_s = 0.0

    def send_control(self, opcode, payload):
        """Queues a control message: it goes after a frame that is half written."""
        self._control.append(tap_ws.encode_frame(opcode, payload))

    def write_sockets(self):
        """The sockets select should say are writable: the client's while a message waits."""
        return [self._sock] if self._pending else []

    def pending_s(self, now_s):
        """Seconds the message being written has waited for its socket; 0 when none."""
        return 0.0 if self._pending_since_s is None else max(0.0, now_s - self._pending_since_s)

    def blocked_s(self):
        """Seconds with a message pending so far: what the diag line's `blocked` counts."""
        return self._blocked_total_s + self.pending_s(self._clock())

    def has_stalled(self, now_s):
        """True when a client has taken nothing for STALL_CLOSE_S: it must be closed."""
        return self.pending_s(now_s) >= STALL_CLOSE_S

    def wait_s(self, now_s):
        """How long select may wait: none when nothing is pending, else the stall's remainder."""
        if not self._pending:
            return None
        return max(0.0, STALL_CLOSE_S - self.pending_s(now_s))

    def pump(self, queue):
        """Writes what the socket takes now; False when the client must be closed."""
        while True:
            if self._pending:
                if not self._flush(queue):
                    return False
                if self._pending:
                    return True
            message = self._next_message(queue)
            if message is None:
                return True
            self._start(*message)

    def _next_message(self, queue):
        """The next whole message to write and, for a frame, the size it counts."""
        if self._control:
            return self._control.popleft(), 0
        if queue is None:
            return None
        frame = queue.take_for_send(self._age_limit_s)
        if frame is None:
            return None
        payload = tap_queue.frame_message(frame, int(time.time() * US_PER_S))
        return tap_ws.encode_frame(tap_ws.OPCODE_BINARY, payload), len(payload)

    def _start(self, message, frame_bytes):
        """Begins one message; frame_bytes is 0 for a control message."""
        self._pending = message
        self._pending_frame_bytes = frame_bytes

    def _flush(self, queue):
        """Sends as much of the pending message as the socket takes; False when it is gone.

        Every send() call is counted by the diag, so a slow or a stalled client
        shows in the line as long calls and unsent bytes rather than as a
        connection that vanished.
        """
        while self._pending:
            started_s = self._clock()
            try:
                sent = self._sock.send(self._pending, socket.MSG_DONTWAIT)
            except BlockingIOError:
                self._note_waiting()
                return True
            except OSError:
                return False
            if sent == 0:
                return False
            self._diag.send(self._client, sent, self._clock() - started_s)
            self._pending = self._pending[sent:]
            if self._pending:
                self._note_waiting()
        self._finish(queue)
        return True

    def _note_waiting(self):
        """Starts this message's wait at its first send the socket would not take."""
        if self._pending_since_s is None:
            self._pending_since_s = self._clock()

    def _finish(self, queue):
        """The message is on the wire: count its wait and, for a frame, the frame."""
        if self._pending_since_s is not None:
            self._blocked_total_s += max(0.0, self._clock() - self._pending_since_s)
            self._pending_since_s = None
        if self._pending_frame_bytes and queue is not None:
            queue.note_sent(self._pending_frame_bytes)
        self._pending_frame_bytes = 0
