#!/usr/bin/env python3
"""The tap's diagnostics' own test (M15 opt2c), run inside the distro by
`tools/stream.sh selftest`.

The diag line is what says where a collapsed run's backlog started, so what it
counts and how it adds several clients up is worth a test of its own. A fake
clock moves the windows and a fake socket stands in for a client's, so no test
waits a second; the kernel's own send-queue reading gets one real socketpair.

    python3 streaming/tap/tap_diag_test.py
"""

import os
import socket
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_diag

# One kilobyte as the line's KB fields count it.
KIB = 1024

# A socket's send buffer small enough that a peer which reads nothing fills it.
SNDBUF_BYTES = 4096

# How much a test writes at a socket nobody reads before it fills.
FILL_BYTES = 1024 * 1024


def fields_of(line):
    """The line's `name=value` pairs as integers, `tapdiag:` left out."""
    return {name: int(value) for name, value in (item.split("=") for item in line.split()[1:])}


class FakeClock:
    """A clock the test moves by hand: the diag's windows are its seconds."""

    def __init__(self, now=1000.0):
        self.now = now

    def __call__(self):
        return self.now


class FakeQueue:
    """One client's queue counters, as tap_queue.ClientQueue.level() gives them."""

    def __init__(self):
        self.depth = 0
        self.dropped = 0
        self.key_requests = 0

    def level(self):
        return self.depth, self.dropped, self.key_requests


class FakeSock:
    """A client socket whose kernel send queue the test sets to any value."""

    def __init__(self, outq=0):
        self.outq = outq


class ReadySocket:
    """A socket that takes every byte of a message in one send."""

    def __init__(self):
        self.bytes = 0

    def send(self, data):
        self.bytes += len(data)
        return len(data)


class StalledSocket:
    """A socket whose send times out without taking a byte."""

    def send(self, data):
        raise socket.timeout()


class HalfSocket:
    """A socket that takes half of a message and then times out."""

    def __init__(self):
        self.taken = 0

    def send(self, data):
        if self.taken:
            raise socket.timeout()
        self.taken = len(data) // 2
        return self.taken


class WindowTest(unittest.TestCase):
    """What one window counts and what its line says."""

    def setUp(self):
        self.clock = FakeClock()
        self.diag = tap_diag.TapDiag(clock=self.clock, send_queue_bytes=lambda sock: sock.outq)

    def client(self, name="phone", outq=0):
        """Tracks one client in the window; answers its fake queue."""
        queue = FakeQueue()
        self.diag.client_added(name, FakeSock(outq), queue.level)
        return queue

    def test_a_window_of_frames_is_one_line_with_the_encoder_s_numbers(self):
        self.client()
        self.diag.frame(True, 200 * KIB)
        self.diag.frame(False, 10 * KIB)
        self.diag.frame(False, 20 * KIB)
        fields = fields_of(self.diag.line())
        self.assertEqual(
            {name: fields[name] for name in ("fr", "kb", "key", "keymax", "dmax")},
            {"fr": 3, "kb": 230, "key": 1, "keymax": 200, "dmax": 20},
        )

    def test_the_delta_frames_average_is_kept_too(self):
        self.client()
        self.diag.frame(False, 10 * KIB)
        self.diag.frame(False, 20 * KIB)
        self.diag.line()
        self.assertEqual(self.diag.window()["delta_avg_kb"], 15)

    def test_frames_with_no_client_connected_are_no_line(self):
        self.diag.frame(False, 10 * KIB)
        self.assertIsNone(self.diag.line())

    def test_a_connected_client_gets_a_line_even_with_no_frames(self):
        self.client()
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["fr"], fields["q"], fields["sent"]), (0, 0, 0))

    def test_a_client_seen_in_the_last_ten_seconds_keeps_the_line_of_a_window_with_frames(self):
        self.client()
        self.diag.frame(False, KIB)
        self.diag.client_removed("phone")
        self.clock.now += tap_diag.CLIENT_RECENT_S
        self.assertIsNotNone(self.diag.line())

    def test_a_window_long_after_the_last_client_is_no_line(self):
        self.client()
        self.diag.client_removed("phone")
        self.clock.now += tap_diag.CLIENT_RECENT_S + 2
        self.assertIsNone(self.diag.line())

    def test_the_queue_field_is_the_depth_max_of_the_window(self):
        queue = self.client()
        for depth in (3, 1, 2):
            queue.depth = depth
            self.diag.queued("phone")
        self.assertEqual(fields_of(self.diag.line())["q"], 3)

    def test_drops_and_key_requests_count_only_what_the_window_added(self):
        queue = self.client()
        # What the queue held before the diag looked is not this window's.
        queue.dropped, queue.key_requests = 5, 2
        self.diag.queued("phone")
        queue.dropped, queue.key_requests = 7, 3
        self.diag.queued("phone")
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["drop"], fields["kreq"]), (2, 1))

    def test_the_counters_the_client_thread_moved_are_seen_at_the_window_s_end(self):
        queue = self.client(outq=0)
        self.diag.queued("phone")
        queue.dropped, queue.key_requests = 4, 1
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["drop"], fields["kreq"]), (4, 1))

    def test_a_window_starts_again_for_each_client_too(self):
        queue = self.client()
        queue.depth = 2
        self.diag.queued("phone")
        self.diag.send("phone", 4 * KIB, 0.020)
        self.diag.line()
        self.assertEqual((self.diag.window()["sent_kb"], self.diag.window()["depth_max"]), (4, 2))
        queue.depth = 0
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["sent"], fields["q"], fields["slow"], fields["sendmax"]), (0, 0, 0, 0))

    def test_a_window_starts_again_after_its_line(self):
        self.client()
        self.diag.frame(True, KIB)
        first = fields_of(self.diag.line())
        second = fields_of(self.diag.line())
        self.assertEqual((first["fr"], first["key"], second["fr"], second["kb"]), (1, 1, 0, 0))

    def test_send_times_are_the_max_and_the_count_over_ten_milliseconds(self):
        self.client()
        self.diag.send("phone", 2 * KIB, 0.020)
        self.diag.send("phone", KIB, 0.002)
        self.diag.send("phone", 0, 0.001, timed_out=True)
        self.diag.send("phone", KIB // 2, 0.030, partial=True)
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["sent"], fields["sendmax"], fields["slow"]), (3, 30, 2))
        window = self.diag.window()
        self.assertEqual((window["partial"], window["timeouts"]), (1, 1))

    def test_several_clients_are_summed_or_maxed_as_the_names_say(self):
        first = self.client("a", outq=4 * KIB)
        second = self.client("b", outq=8 * KIB)
        first.depth, second.depth = 4, 2
        self.diag.queued("a")
        self.diag.queued("b")
        self.diag.send("a", KIB, 0.020)
        self.diag.send("b", 2 * KIB, 0.050)
        fields = fields_of(self.diag.line())
        self.assertEqual((fields["q"], fields["sent"], fields["sendmax"], fields["outq"]), (4, 3, 50, 8))

    def test_outq_is_minus_one_when_the_kernel_will_not_say(self):
        self.client(outq=-1)
        self.assertEqual(fields_of(self.diag.line())["outq"], -1)

    def test_the_line_has_every_field_in_its_documented_order(self):
        self.client()
        self.assertRegex(
            self.diag.line(),
            r"^tapdiag: t=1000 fr=\d+ kb=\d+ key=\d+ keymax=\d+ dmax=\d+ q=\d+ drop=\d+ "
            r"kreq=\d+ sent=\d+ sendmax=\d+ slow=\d+ outq=-?\d+$",
        )


class SendMessageTest(unittest.TestCase):
    """One message to a client, measured and reported as its end."""

    def setUp(self):
        self.clock = FakeClock()
        self.diag = tap_diag.TapDiag(clock=self.clock, send_queue_bytes=lambda sock: 0)
        self.diag.client_added("phone", FakeSock(), lambda: (0, 0, 0))

    def test_a_message_a_socket_takes_whole_is_ok_and_counted(self):
        sock = ReadySocket()
        self.assertEqual(tap_diag.send_message(self.diag, "phone", sock, b"x" * (2 * KIB)), tap_diag.SEND_OK)
        self.assertEqual(sock.bytes, 2 * KIB)
        self.diag.line()
        self.assertEqual(self.diag.window()["sent_kb"], 2)

    def test_a_socket_that_times_out_at_once_is_blocked_not_broken(self):
        message = b"x" * (2 * KIB)
        self.assertEqual(tap_diag.send_message(self.diag, "phone", StalledSocket(), message), tap_diag.SEND_BLOCKED)
        self.diag.line()
        self.assertEqual(self.diag.window()["timeouts"], 1)

    def test_a_message_half_sent_leaves_the_client_broken(self):
        sock = HalfSocket()
        self.assertEqual(tap_diag.send_message(self.diag, "phone", sock, b"x" * (4 * KIB)), tap_diag.SEND_BROKEN)
        self.diag.line()
        self.assertEqual((self.diag.window()["partial"], self.diag.window()["sent_kb"]), (1, 2))


class SendQueueTest(unittest.TestCase):
    """The kernel's own answer for a socket's unsent bytes."""

    def test_the_send_queue_of_a_socket_nobody_reads_holds_bytes(self):
        writer, reader = socket.socketpair()
        self.addCleanup(writer.close)
        self.addCleanup(reader.close)
        writer.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, SNDBUF_BYTES)
        writer.setblocking(False)
        written = 0
        while written < FILL_BYTES:
            try:
                written += writer.send(bytes(KIB))
            except BlockingIOError:
                break
        self.assertGreater(tap_diag.socket_send_queue(writer), 0)

    def test_a_socket_the_kernel_will_not_answer_for_is_minus_one(self):
        closed = socket.socket()
        closed.close()
        self.assertEqual(tap_diag.socket_send_queue(closed), -1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
