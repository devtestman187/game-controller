#!/usr/bin/env python3
"""The tap client queue's keyframe rule (M15 opt2c-3), run inside the distro by
`tools/stream.sh selftest`.

PROTOCOL.md now fixes the rule this file checks: one keyframe request
outstanding per client, cleared by a keyframe queued for that client or after
2.5 s, and no two asks closer together than 1.5 s. A keyframe request here is a
counter and a callable, and the clock is the test's own, so every timing is
exact and no socket is involved.

    python3 streaming/tap/tap_queue_test.py
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_queue

# The fake clock's first instant, in seconds: any fixed number does.
START_S = 1000.0


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

    def test_the_first_overflow_after_a_keyframe_asks_once(self):
        self.fill()
        self.assertFalse(self.queue.offer(5, 0, False, b"p"))
        self.clock.now_s += 0.1
        self.queue.drop_to_keyframe()
        stats = self.queue.stats()
        self.assertEqual((self.asked, stats["keyreq"], stats["keyreq_suppressed"]), (1, 1, 1))

    def test_an_overflow_while_waiting_for_a_keyframe_asks_nothing(self):
        self.fill()
        self.queue.drop_to_keyframe()
        self.queue.drop_to_keyframe()
        stats = self.queue.stats()
        self.assertEqual((self.asked, stats["keyreq"], stats["keyreq_suppressed"]), (1, 1, 1))

    def test_the_totals_carry_the_suppressed_asks(self):
        self.queue.request_keyframe()
        self.queue.request_keyframe()
        self.assertEqual(tap_queue.totals([self.queue])["keyreq_suppressed"], 1)

    def fill(self):
        """A client started on a keyframe with four delta frames behind it."""
        self.queue.offer(0, 0, True, b"k")
        self.queue.take(0)
        for number in range(1, tap_queue.QUEUE_FRAMES + 1):
            self.queue.offer(number, 0, False, b"p")


if __name__ == "__main__":
    unittest.main(verbosity=2)
