"""One tap client's frame queue and PROTOCOL.md's messages (M15 opt2-2).

Pure Python with no socket: ClientQueue is what a client's sender takes frames
from and the pipeline's thread offers them to, with the backlog rule that makes
a client which falls behind start again at a keyframe. The messages it builds
are PROTOCOL.md's: the 24-byte header before every access unit, and the hello
a page configures its decoder with.

The age rule is here too (M15 opt2c-4): a queued frame carries when it was
queued, and one older than the sender's limit is dropped before its message
starts, because its picture is already late.
"""

import json
import threading
import time
from collections import deque, namedtuple

import tap_frames

# The frames one client may have waiting: PROTOCOL.md's four.
QUEUE_FRAMES = 4

# How long one keyframe request may be outstanding before another may go: a
# keyframe leaves the encoder within this, the natural IDR being at most a
# second away, and a request whose keyframe never comes must not hold a client
# back for good (M15 opt2c-3).
KEY_OUTSTANDING_TIMEOUT_S = 2.5

# The shortest gap between two keyframe requests, from anyone: a client that
# asks over and over cannot turn the stream into a keyframe storm (M15 opt2c-3).
KEY_MIN_SPACING_S = 1.5

# The header tap_frames packs before every access unit; the page reads it first.
HEADER_BYTES = tap_frames.HEADER_BYTES

# PROTOCOL.md's two text messages, as they go on the wire.
END_MESSAGE = b'{"type":"end"}'
KEY_MESSAGE_TYPE = "key"

# One access unit on its way to a client: what it is, where it came from, and
# when the queue took it, which the age rule measures against.
Frame = namedtuple("Frame", "frame_no pts_us is_key discontinuity data enqueued_s")


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
        "aged": sum(stats["aged"] for stats in per_client),
        "keyreq": sum(stats["keyreq"] for stats in per_client),
        "keyreq_suppressed": sum(stats["keyreq_suppressed"] for stats in per_client),
        "high_water": max((stats["high_water"] for stats in per_client), default=0),
        "bytes": sum(stats["bytes"] for stats in per_client),
        "per_client": per_client,
    }


class KeyRequestGate:
    """At most one keyframe request outstanding, and a gap between two asks.

    The one rule both sides of the tap use (M15 opt2c-3): a client's queue
    holds an ask until a keyframe is queued for it or the wait expires, and
    the runner holds the pipeline's force-key-unit event until a keyframe
    leaves the encoder or the wait expires. `allows()` says whether an ask may
    go now and starts its wait; `note_keyframe()` ends one that a keyframe
    answered. A clock is injected so a test can move time.
    """

    def __init__(self, clock=time.monotonic):
        self._clock = clock
        self._last_ask_s = None
        self._outstanding_since_s = None

    def allows(self):
        """True when a request may go now; False when it is held back.

        A true answer counts as the ask: the spacing runs from it and the
        outstanding wait starts.
        """
        now_s = self._clock()
        if self._outstanding_since_s is not None and now_s - self._outstanding_since_s < KEY_OUTSTANDING_TIMEOUT_S:
            return False
        if self._last_ask_s is not None and now_s - self._last_ask_s < KEY_MIN_SPACING_S:
            return False
        self._last_ask_s = now_s
        self._outstanding_since_s = now_s
        return True

    def note_keyframe(self):
        """A keyframe answered the outstanding ask, if there was one."""
        self._outstanding_since_s = None


class ClientQueue:
    """One client's bounded frame queue and the counters its stats report.

    The client's sender takes frames from it, the pipeline's thread offers them,
    and a queue that fills drops its backlog and asks the encoder for a
    keyframe, so the client starts again on a frame it can decode (PROTOCOL.md,
    backlog rule). No socket and no clock: every rule here is testable alone.
    """

    def __init__(self, request_key, frame_limit=QUEUE_FRAMES, clock=time.monotonic):
        self._request_key = request_key
        self._limit = frame_limit
        self._clock = clock
        self._key_gate = KeyRequestGate(clock)
        self._frames = deque()
        self._lock = threading.Lock()
        self.needs_keyframe = True
        self.pending_discontinuity = False
        self.sent = 0
        self.dropped = 0
        self.aged = 0
        self.key_requests = 0
        self.keyreq_suppressed = 0
        self.high_water = 0
        self.bytes = 0

    def offer(self, frame_no, pts_us, is_key, data):
        """Queues one access unit; True when it will be sent, False when it is dropped."""
        with self._lock:
            if self.needs_keyframe and not is_key:
                self.dropped += 1
                return False
            if len(self._frames) >= self._limit:
                self._clear_to_keyframe()
                if not is_key:
                    self.dropped += 1
                    return False
            self.needs_keyframe = False
            frame = Frame(frame_no, pts_us, is_key, self.pending_discontinuity, data, self._clock())
            self.pending_discontinuity = False
            if is_key:
                self._key_gate.note_keyframe()
            self._frames.append(frame)
            self.high_water = max(self.high_water, len(self._frames))
            return True

    def take_for_send(self, age_limit_s):
        """The frame this client may be sent now, after the age rule (M15 opt2c-4).

        A frame older than age_limit_s is worth nothing to the page: its picture
        is already late, so it is dropped before its message starts and counted
        as aged. A delta whose predecessor went that way cannot be decoded, so
        the client jumps to the newest keyframe in its queue, flagged as the
        first after a gap; with none it clears and waits for the next keyframe
        under the key rule, which asks once and no more.
        """
        with self._lock:
            now_s = self._clock()
            aged = 0
            while self._frames and now_s - self._frames[0].enqueued_s > age_limit_s:
                self._frames.popleft()
                aged += 1
            if aged:
                self.aged += aged
                self.dropped += aged
                if not self._frames or not self._frames[0].is_key:
                    return self._jump_to_keyframe()
            return self._frames.popleft() if self._frames else None

    def request_keyframe(self):
        """Asks the encoder for the keyframe this client is waiting for.

        Through the client's own rule: one ask outstanding, and 1.5 s between
        two of them, so a page that asks over and over is held back here
        (M15 opt2c-3). A held-back ask is counted, never sent.
        """
        with self._lock:
            self._ask_for_key()

    def _ask_for_key(self):
        """One ask through the gate; False when it was held back."""
        if not self._key_gate.allows():
            self.keyreq_suppressed += 1
            return False
        self.key_requests += 1
        self._request_key()
        return True

    def note_sent(self, size_bytes):
        """Counts one frame the client's sender has written whole."""
        with self._lock:
            self.sent += 1
            self.bytes += size_bytes

    def level(self):
        """The backlog's depth and the totals a diag window reads (M15 opt2c)."""
        with self._lock:
            return len(self._frames), self.dropped, self.key_requests, self.aged

    def stats(self):
        """What this client has been sent and has lost."""
        with self._lock:
            return {
                "sent": self.sent,
                "dropped": self.dropped,
                "aged": self.aged,
                "keyreq": self.key_requests,
                "keyreq_suppressed": self.keyreq_suppressed,
                "high_water": self.high_water,
                "bytes": self.bytes,
            }

    def _jump_to_keyframe(self):
        """Drops what cannot be decoded and returns the newest keyframe, if any.

        The keyframe is flagged as after a gap: the frames before it never
        reached the page. With none in the queue the client waits for the next
        one, which the key rule asks for once.
        """
        newest = None
        for index, frame in enumerate(self._frames):
            if frame.is_key:
                newest = index
        if newest is None:
            self._clear_to_keyframe()
            return None
        for _ in range(newest):
            self._frames.popleft()
        self.dropped += newest
        return self._frames.popleft()._replace(discontinuity=True)

    def _clear_to_keyframe(self):
        """The next frame must be a keyframe, flagged as the first after a gap.

        A client that already waits for one has already asked: nothing goes to
        the encoder again, or every dropped frame would ask (M15 opt2c-3).
        """
        waiting = self.needs_keyframe
        self.dropped += len(self._frames)
        self._frames.clear()
        self.needs_keyframe = True
        self.pending_discontinuity = True
        if waiting:
            self.keyreq_suppressed += 1
        else:
            self._ask_for_key()
