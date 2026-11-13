#!/usr/bin/env python3
"""The tap runner's encoder-side keyframe rule (M15 opt2c-3), run inside the
distro by `tools/stream.sh selftest`.

Clients' asks reach the encoder through one rule for the whole pipeline: one
force-key-unit event outstanding until a keyframe leaves the encoder or 2.5 s
pass, and at least 1.5 s between two events. The pipeline is faked (a sink, a
sample and a buffer), so the rule is tested without GStreamer running.

    python3 streaming/tap/tap_runner_test.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_runner

# The fake clock's first instant, in seconds: any fixed number does.
START_S = 1000.0
# One access unit the runner reads as a keyframe: Annex B with an IDR slice.
KEY_AU = b"\x00\x00\x00\x01\x65key"
# One the runner reads as a delta: Annex B with a non-IDR slice.
DELTA_AU = b"\x00\x00\x00\x01\x41delta"


class FakeClock:
    """A monotonic clock the test moves by hand."""

    def __init__(self):
        self.now_s = START_S

    def __call__(self):
        return self.now_s


class FakePad:
    """A pad that takes the force-key-unit event."""

    def __init__(self):
        self.events = 0

    def send_event(self, event):
        self.events += 1
        return True


class FakeSink:
    """The appsink: what it emits next, and a pad for the upstream event."""

    def __init__(self):
        self.sample = None
        self.signals = {}
        self.pad = FakePad()
        self.pads = []

    def connect(self, signal, callback):
        self.signals[signal] = callback

    def emit(self, signal):
        return self.sample

    def get_static_pad(self, name):
        return self.pad


class FakePipeline:
    def __init__(self, sink):
        self.sink = sink

    def get_by_name(self, name):
        return self.sink


class FakeDiag:
    def __init__(self):
        self.frames = []

    def frame(self, is_key, size_bytes):
        self.frames.append((is_key, size_bytes))


class FakeServer:
    """The tap server's two callbacks the sample path makes."""

    def __init__(self):
        self.diag = FakeDiag()
        self.published = []

    def publish(self, frame_no, pts_us, is_key, data):
        self.published.append((frame_no, is_key, data))


class _Mapped:
    def __init__(self, data):
        self.data = data


class FakeBuffer:
    def __init__(self, data):
        self.data = data
        self.pts = 0
        self.dts = 0

    def map(self, flags):
        return True, _Mapped(self.data)

    def unmap(self, mapped):
        pass


class FakeSample:
    def __init__(self, data):
        self.buffer = FakeBuffer(data)

    def get_buffer(self):
        return self.buffer

    def get_caps(self):
        return None


class KeyUnitRuleTest(unittest.TestCase):
    """request_key_unit and the keyframe that answers it."""

    def setUp(self):
        self.clock = FakeClock()
        self.sink = FakeSink()
        self.runner = tap_runner.TapRunner(FakePipeline(self.sink), 9100, clock=self.clock)
        self.runner.server = FakeServer()

    def test_the_first_request_is_taken(self):
        self.assertTrue(self.runner.request_key_unit())

    def test_a_request_inside_the_spacing_is_refused(self):
        self.assertTrue(self.runner.request_key_unit())
        self.clock.now_s += 1.4
        self.assertFalse(self.runner.request_key_unit())

    def test_a_request_no_keyframe_answers_expires_after_2_5_s(self):
        self.assertTrue(self.runner.request_key_unit())
        self.clock.now_s += 2.4
        self.assertFalse(self.runner.request_key_unit())
        self.clock.now_s += 0.1
        self.assertTrue(self.runner.request_key_unit())

    def test_a_keyframe_from_the_encoder_frees_the_next_request(self):
        self.assertTrue(self.runner.request_key_unit())
        self.sink.sample = FakeSample(KEY_AU)
        self.runner._on_new_sample(self.sink)
        # 1.5 s after the ask the spacing is over and the keyframe ended the wait.
        self.clock.now_s += 1.5
        self.assertTrue(self.runner.request_key_unit())

    def test_a_delta_from_the_encoder_frees_nothing(self):
        self.assertTrue(self.runner.request_key_unit())
        self.sink.sample = FakeSample(DELTA_AU)
        self.runner._on_new_sample(self.sink)
        self.clock.now_s += 1.5
        self.assertFalse(self.runner.request_key_unit())

    def test_the_taken_request_goes_out_with_the_next_frame(self):
        self.assertTrue(self.runner.request_key_unit())
        self.sink.sample = FakeSample(DELTA_AU)
        self.runner._on_new_sample(self.sink)
        self.assertEqual(self.sink.pad.events, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
