"""One tap client's frame queue and PROTOCOL.md's messages (M15 opt2-2).

Pure Python with no socket: ClientQueue is what a client's thread takes frames
from and the pipeline's thread offers them to, with the backlog rule that makes
a client which falls behind start again at a keyframe. The messages it builds
are PROTOCOL.md's: the 24-byte header before every access unit, and the hello
a page configures its decoder with.
"""

import json
import threading
from collections import deque, namedtuple

import tap_frames

# The frames one client may have waiting: PROTOCOL.md's four.
QUEUE_FRAMES = 4

# The header tap_frames packs before every access unit; the page reads it first.
HEADER_BYTES = tap_frames.HEADER_BYTES

# PROTOCOL.md's two text messages, as they go on the wire.
END_MESSAGE = b'{"type":"end"}'
KEY_MESSAGE_TYPE = "key"

# One access unit on its way to a client: what it is and where it came from.
Frame = namedtuple("Frame", "frame_no pts_us is_key discontinuity data")


def frame_message(frame, sent_us):
    """The payload of one binary message: PROTOCOL.md's header, then the access unit."""
    flags = 0
    if frame.is_key:
        flags |= tap_frames.FLAG_KEYFRAME
    if frame.discontinuity:
        flags |= tap_frames.FLAG_DISCONTINUITY
    return tap_frames.pack_header(flags, frame.frame_no, frame.pts_us, sent_us) + frame.data


def hello_message(info):
    """PROTOCOL.md's hello: what a page needs to configure its decoder.

    `profile` is left out until the tap has seen an SPS; the other fields are
    the stream's, which the page needs before its first frame.
    """
    hello = {
        "type": "hello",
        "version": tap_frames.VERSION,
        "width": info.get("width"),
        "height": info.get("height"),
        "fps": info.get("fps"),
    }
    if info.get("profile"):
        hello["profile"] = info["profile"]
    return json.dumps(hello)


def totals(queues):
    """PROTOCOL.md's counters over every client's queue, each and in total."""
    per_client = [queue.stats() for queue in queues]
    return {
        "clients": len(per_client),
        "sent": sum(stats["sent"] for stats in per_client),
        "dropped": sum(stats["dropped"] for stats in per_client),
        "keyreq": sum(stats["keyreq"] for stats in per_client),
        "high_water": max((stats["high_water"] for stats in per_client), default=0),
        "bytes": sum(stats["bytes"] for stats in per_client),
        "per_client": per_client,
    }


class ClientQueue:
    """One client's bounded frame queue and the counters its stats report.

    The client's thread takes frames from it, the pipeline's thread offers them,
    and a queue that fills drops its backlog and asks the encoder for a
    keyframe, so the client starts again on a frame it can decode (PROTOCOL.md,
    backlog rule). No socket and no clock: every rule here is testable alone.
    """

    def __init__(self, request_key, frame_limit=QUEUE_FRAMES):
        self._request_key = request_key
        self._limit = frame_limit
        self._frames = deque()
        self._condition = threading.Condition()
        self.needs_keyframe = True
        self.pending_discontinuity = False
        self.sent = 0
        self.dropped = 0
        self.key_requests = 0
        self.high_water = 0
        self.bytes = 0

    def offer(self, frame_no, pts_us, is_key, data):
        """Queues one access unit; True when it will be sent, False when it is dropped."""
        with self._condition:
            if self.needs_keyframe and not is_key:
                self.dropped += 1
                return False
            if len(self._frames) >= self._limit:
                self._clear_to_keyframe()
                if not is_key:
                    self.dropped += 1
                    return False
            self.needs_keyframe = False
            frame = Frame(frame_no, pts_us, is_key, self.pending_discontinuity, data)
            self.pending_discontinuity = False
            self._frames.append(frame)
            self.high_water = max(self.high_water, len(self._frames))
            self._condition.notify()
            return True

    def take(self, timeout_s):
        """The oldest queued frame, or None when none is waiting after timeout_s."""
        with self._condition:
            if not self._frames:
                self._condition.wait(timeout_s)
            if not self._frames:
                return None
            return self._frames.popleft()

    def request_keyframe(self):
        """Asks the encoder for the keyframe this client is waiting for."""
        with self._condition:
            self.key_requests += 1
            self._request_key()

    def drop_to_keyframe(self):
        """Clears the backlog after a write the socket would not take."""
        with self._condition:
            self.dropped += 1
            self._clear_to_keyframe()

    def note_sent(self, size_bytes):
        """Counts one frame the client's thread has written."""
        with self._condition:
            self.sent += 1
            self.bytes += size_bytes

    def level(self):
        """The depth of the backlog and the totals a diag window reads (M15 opt2c)."""
        with self._condition:
            return len(self._frames), self.dropped, self.key_requests

    def stats(self):
        """What this client has been sent and has lost."""
        with self._condition:
            return {
                "sent": self.sent,
                "dropped": self.dropped,
                "keyreq": self.key_requests,
                "high_water": self.high_water,
                "bytes": self.bytes,
            }

    def _clear_to_keyframe(self):
        """The next frame must be a keyframe, flagged as the first after a gap."""
        self.dropped += len(self._frames)
        self._frames.clear()
        self.needs_keyframe = True
        self.pending_discontinuity = True
        self.key_requests += 1
        self._request_key()
