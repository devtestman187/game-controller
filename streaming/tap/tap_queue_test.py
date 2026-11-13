#!/usr/bin/env python3
"""The tap client queue's keyframe and age rules (M15 opt2c-3, opt2c-4), run
inside the distro by `tools/stream.sh selftest`.

PROTOCOL.md fixes the rules this file checks: one keyframe request outstanding
per client, cleared by a keyframe queued for that client or after 2.5 s, and no
two asks closer together than 1.5 s; and a frame more than two frame times old
is not worth sending, so it is dropped before a message starts. A keyframe
request here is a counter and a callable, and the clock is the test's own, so
every timing is exact and no socket is involved.

    python3 streaming/tap/tap_queue_test.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_queue

# The fake clock's first instant, in seconds: any fixed number does.
START_S = 1000.0

# The age limit at the pipeline's 60 fps: two frame times, 1/30 s (opt2c-4).
AGE_LIMIT_S = 2 / 60

# An age limit no test frame reaches, where the rule is not what is checked.
AGE_NEVER_S = 3600.0


class FakeClock:
    """A monotonic clock the test moves by hand."""

    def __init__(self):
        self.now_s = START_S

    def __call__(self):
        return self.now_s


class KeyRequestGateTest(unittest.TestCase):
    """The rule both the client queue and the encoder side use, alone."""

    def setUp(self):
        self.clock = FakeClock()
        self.gate = tap_queue.KeyRequestGate(self.clock)

    def test_the_first_ask_goes(self):
        self.assertTrue(self.gate.allows())

    def test_a_second_ask_inside_the_spacing_is_refused(self):
        self.assertTrue(self.gate.allows())
        self.clock.now_s += 1.4
        self.assertFalse(self.gate.allows())

    def test_an_ask_no_keyframe_answers_expires_after_2_5_s(self):
        self.assertTrue(self.gate.allows())
        self.clock.now_s += 2.4
        self.assertFalse(self.gate.allows())
        # 2.5 s after the ask: the wait is over and the spacing is long past.
        self.clock.now_s += 0.1
        self.assertTrue(self.gate.allows())

    def test_a_keyframe_answered_ask_waits_for_the_spacing_only(self):
        self.assertTrue(self.gate.allows())
        self.gate.note_keyframe()
        self.clock.now_s += 1.4
        self.assertFalse(self.gate.allows())
        self.clock.now_s += 0.1
        self.assertTrue(self.gate.allows())

    def test_a_keyframe_with_no_ask_outstanding_is_harmless(self):
        self.gate.note_keyframe()
        self.assertTrue(self.gate.allows())


class ClientQueueKeyTest(unittest.TestCase):
    """One client's asks: what reaches the encoder, and what is held back."""

    def setUp(self):
        self.clock = FakeClock()
        self.asked = 0

        def request_key():
            self.asked += 1

        self.queue = tap_queue.ClientQueue(request_key, clock=self.clock)

    def test_the_first_ask_on_connect_goes(self):
        self.queue.request_keyframe()
        self.assertEqual((self.asked, self.queue.stats()["keyreq"]), (1, 1))

    def test_a_second_ask_inside_the_spacing_is_suppressed(self):
        self.queue.request_keyframe()
        self.clock.now_s += 1.4
        self.queue.request_keyframe()
        stats = self.queue.stats()
        self.assertEqual((self.asked, stats["keyreq"], stats["keyreq_suppressed"]), (1, 1, 1))

    def test_a_keyframe_queued_for_the_client_frees_the_next_ask(self):
        self.queue.request_keyframe()
        self.clock.now_s += 0.2
        self.assertTrue(self.queue.offer(0, 0, True, b"k"))
        self.clock.now_s += 1.4
        self.queue.request_keyframe()
        self.assertEqual((self.asked, self.queue.stats()["keyreq"]), (2, 2))

    def test_an_ask_no_keyframe_answers_expires_after_2_5_s(self):
        self.queue.request_keyframe()
        self.clock.now_s += 2.4
        self.queue.request_keyframe()
        self.assertEqual(self.asked, 1)
        self.clock.now_s += 0.2
        self.queue.request_keyframe()
        self.assertEqual(self.asked, 2)

    def test_the_totals_carry_the_suppressed_asks(self):
        self.queue.request_keyframe()
        self.queue.request_keyframe()
        self.assertEqual(tap_queue.totals([self.queue])["keyreq_suppressed"], 1)


class AgedFrameTest(unittest.TestCase):
    """The age rule: a frame older than two frame times is not worth sending.

    Two frame times at 60 fps is 1/30 s (33.3 ms), which sets the ageing in
    every line of `now_s` below; the queue is told the limit, as the sender
    tells it (M15 opt2c-4).
    """

    def setUp(self):
        self.clock = FakeClock()
        self.asked = 0

        def request_key():
            self.asked += 1

        self.queue = tap_queue.ClientQueue(request_key, clock=self.clock)

    def start(self):
        """A client that has taken its first keyframe and is in step with the stream."""
        self.queue.offer(0, 0, True, b"k")
        self.queue.take_for_send(AGE_NEVER_S)

    def test_a_frame_inside_the_limit_is_sent(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S
        frame = self.queue.take_for_send(AGE_LIMIT_S)
        self.assertEqual((frame.frame_no, self.queue.stats()["aged"]), (1, 0))

    def test_a_frame_past_the_limit_is_dropped_and_counted_as_aged(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S + 0.001
        self.assertIsNone(self.queue.take_for_send(AGE_LIMIT_S))
        stats = self.queue.stats()
        self.assertEqual((stats["aged"], stats["dropped"]), (1, 1))
        # Nothing decodable is left: the client waits for a keyframe, asked once.
        self.assertTrue(self.queue.needs_keyframe)
        self.assertEqual(self.asked, 1)

    def test_a_delta_behind_an_aged_one_jumps_to_the_newest_keyframe(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.clock.now_s += 0.02
        self.queue.offer(2, 0, False, b"p")
        self.queue.offer(3, 0, True, b"k")
        self.clock.now_s += 0.02
        # Frame 1 is 40 ms old and goes; frames 2 and 3 are 20 ms old and stay,
        # but frame 2 cannot be decoded without it.
        frame = self.queue.take_for_send(AGE_LIMIT_S)
        self.assertEqual((frame.frame_no, frame.is_key, frame.discontinuity), (3, True, True))
        stats = self.queue.stats()
        self.assertEqual((stats["aged"], stats["dropped"]), (1, 2))
        self.assertFalse(self.queue.needs_keyframe)

    def test_with_no_keyframe_left_it_clears_and_waits(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.queue.offer(2, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S + 0.001
        self.assertIsNone(self.queue.take_for_send(AGE_LIMIT_S))
        stats = self.queue.stats()
        self.assertEqual((stats["aged"], stats["dropped"], self.asked), (2, 2, 1))
        self.assertTrue(self.queue.needs_keyframe)
        # The next delta is refused and the keyframe that follows is flagged as
        # the first after the gap.
        self.assertFalse(self.queue.offer(3, 0, False, b"p"))
        self.assertTrue(self.queue.offer(4, 0, True, b"k"))
        self.assertTrue(self.queue.take_for_send(AGE_LIMIT_S).discontinuity)

    def test_a_second_clear_inside_the_key_spacing_asks_nothing(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S + 0.001
        self.assertIsNone(self.queue.take_for_send(AGE_LIMIT_S))
        self.clock.now_s += 0.1
        self.queue.offer(2, 0, True, b"k")
        self.queue.take_for_send(AGE_NEVER_S)
        self.clock.now_s += 0.1
        self.queue.offer(3, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S + 0.001
        self.assertIsNone(self.queue.take_for_send(AGE_LIMIT_S))
        stats = self.queue.stats()
        self.assertEqual((self.asked, stats["keyreq"], stats["keyreq_suppressed"]), (1, 1, 1))

    def test_the_totals_carry_the_aged_frames(self):
        self.start()
        self.queue.offer(1, 0, False, b"p")
        self.clock.now_s += AGE_LIMIT_S + 0.001
        self.queue.take_for_send(AGE_LIMIT_S)
        self.assertEqual(tap_queue.totals([self.queue])["aged"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
