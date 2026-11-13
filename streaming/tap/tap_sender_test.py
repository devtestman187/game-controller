#!/usr/bin/env python3
"""The tap sender's message boundaries and its wait for the socket (M15 opt2c-4),
run inside the distro by `tools/stream.sh selftest`.

What the sender is for: a message is written to its end over as many send()
calls as the socket needs, so a phone on a slow link pushes back to the host
instead of being closed half a keyframe in. What the queue hands it (the age
rule, the jump to a keyframe) is tap_queue's and tested there; here a real
socket pair takes the bytes and a fake clock moves the waits, so every number
is exact.

    python3 streaming/tap/tap_sender_test.py
"""

import os
import socket
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_queue
import tap_sender
import tap_ws

# A socket buffer small enough that one frame takes many send() calls.
SNDBUF_BYTES = 4096

# One frame's payload in the tests that need the socket to fill: 64 KiB is more
# than the buffer above and a plausible delta frame on a busy scene.
FRAME_BYTES = 64 * 1024

# How long a read from the test's own socket pair may take before it fails.
WAIT_S = 5

# The fake clock's first instant, in seconds: any fixed number does.
START_S = 1000.0


class FakeClock:
    """A monotonic clock the test moves by hand."""

    def __init__(self, now_s=START_S):
        self.now_s = now_s

    def __call__(self):
        return self.now_s


class FakeDiag:
    """What the sender measured, as tap_diag.TapDiag.send() would take it."""

    def __init__(self):
        self.calls = 0
        self.sent_bytes = 0
        self.slowest_s = 0.0

    def send(self, client, size_bytes, seconds):
        self.calls += 1
        self.sent_bytes += size_bytes
        self.slowest_s = max(self.slowest_s, seconds)


class SenderTest(unittest.TestCase):
    """One client's messages over a real socket pair, with a fake clock."""

    def setUp(self):
        self.clock = FakeClock()
        self.diag = FakeDiag()
        self.queue = tap_queue.ClientQueue(lambda: None, clock=self.clock)
        self.sock, self.peer = socket.socketpair()
        self.addCleanup(self.sock.close)
        self.addCleanup(self.peer.close)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, SNDBUF_BYTES)
        self.peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, SNDBUF_BYTES)
        self.sender = tap_sender.MessageSender(self.sock, self.diag, "phone", clock=self.clock)

    def sender_at(self, fps):
        """A sender told the stream's frame rate, as the server tells it."""
        return tap_sender.MessageSender(self.sock, self.diag, "phone", fps=fps, clock=self.clock)

    def read_frames(self, sender, count):
        """Reads `count` whole messages from the peer, letting the sender write between reads."""
        self.peer.settimeout(WAIT_S)
        buffer = b""
        frames = []
        while len(frames) < count:
            self.assertTrue(sender.pump(self.queue))
            buffer += self.peer.recv(SNDBUF_BYTES)
            while True:
                frame = tap_ws.decode_frame(buffer)
                if frame is None:
                    break
                buffer = buffer[frame.consumed :]
                frames.append(frame)
        return frames

    def test_a_message_the_socket_takes_whole_is_sent_and_counted(self):
        self.queue.offer(0, 0, True, b"key")
        self.assertTrue(self.sender.pump(self.queue))
        self.assertEqual(self.sender.write_sockets(), [])
        self.assertEqual(self.queue.stats()["sent"], 1)
        frame = self.read_frames(self.sender, 1)[0]
        self.assertEqual((frame.opcode, frame.payload[tap_queue.HEADER_BYTES :]), (tap_ws.OPCODE_BINARY, b"key"))

    def test_a_message_a_socket_takes_in_parts_is_finished_byte_for_byte(self):
        frame = bytes(FRAME_BYTES)
        self.queue.offer(0, 0, True, frame)
        self.assertTrue(self.sender.pump(self.queue))
        # The socket is full: the rest of the message waits, and nothing is
        # counted as sent until the whole of it is on the wire.
        self.assertEqual(self.sender.write_sockets(), [self.sock])
        self.assertEqual(self.queue.stats()["sent"], 0)
        sent = self.read_frames(self.sender, 1)[0]
        self.assertEqual((sent.opcode, sent.payload[tap_queue.HEADER_BYTES :]), (tap_ws.OPCODE_BINARY, frame))
        self.assertEqual(self.queue.stats()["sent"], 1)
        self.assertEqual(self.diag.sent_bytes, len(tap_ws.encode_frame(tap_ws.OPCODE_BINARY, sent.payload)))

    def test_the_wait_for_a_full_socket_is_counted_as_blocked(self):
        self.queue.offer(0, 0, True, bytes(FRAME_BYTES))
        self.assertTrue(self.sender.pump(self.queue))
        self.assertEqual(self.sender.blocked_s(), 0.0)
        self.clock.now_s += 0.2
        self.assertAlmostEqual(self.sender.blocked_s(), 0.2, places=3)
        self.read_frames(self.sender, 1)
        # The message is on the wire: its wait is kept, and no new one starts.
        self.assertAlmostEqual(self.sender.blocked_s(), 0.2, places=3)

    def test_a_client_that_takes_nothing_for_five_seconds_has_stalled(self):
        self.queue.offer(0, 0, True, bytes(FRAME_BYTES))
        self.sender.pump(self.queue)
        self.assertFalse(self.sender.has_stalled(self.clock.now_s))
        self.clock.now_s += tap_sender.STALL_CLOSE_S - 0.1
        self.assertFalse(self.sender.has_stalled(self.clock.now_s))
        self.clock.now_s += 0.2
        self.assertTrue(self.sender.has_stalled(self.clock.now_s))

    def test_the_wait_for_select_ends_at_the_stall_deadline(self):
        self.assertIsNone(self.sender.wait_s(self.clock.now_s))
        self.queue.offer(0, 0, True, bytes(FRAME_BYTES))
        self.sender.pump(self.queue)
        self.assertAlmostEqual(self.sender.wait_s(self.clock.now_s), tap_sender.STALL_CLOSE_S, places=3)
        self.clock.now_s += 1.5
        self.assertAlmostEqual(
            self.sender.wait_s(self.clock.now_s), tap_sender.STALL_CLOSE_S - 1.5, places=3
        )

    def test_frames_that_arrive_while_a_message_waits_stay_in_the_queue(self):
        self.queue.offer(0, 0, True, bytes(FRAME_BYTES))
        self.sender.pump(self.queue)
        for number in range(1, tap_queue.QUEUE_FRAMES + 1):
            self.assertTrue(self.queue.offer(number, 0, False, b"p"))
        self.assertEqual(self.queue.level()[0], tap_queue.QUEUE_FRAMES)
        # The backlog rule still holds behind the pending message.
        self.assertFalse(self.queue.offer(tap_queue.QUEUE_FRAMES + 1, 0, False, b"p"))

    def test_a_control_message_waits_for_the_frame_that_is_half_written(self):
        frame = bytes(FRAME_BYTES)
        self.queue.offer(0, 0, True, frame)
        self.sender.pump(self.queue)
        self.sender.send_control(tap_ws.OPCODE_TEXT, b'{"type":"end"}')
        first, second = self.read_frames(self.sender, 2)
        self.assertEqual((first.opcode, first.payload[tap_queue.HEADER_BYTES :]), (tap_ws.OPCODE_BINARY, frame))
        self.assertEqual((second.opcode, second.payload), (tap_ws.OPCODE_TEXT, b'{"type":"end"}'))

    def test_a_socket_that_is_gone_ends_the_client(self):
        self.peer.close()
        self.queue.offer(0, 0, True, b"key")
        self.assertFalse(self.sender.pump(self.queue))

    def test_a_frame_older_than_two_frame_times_at_the_hello_s_fps_is_not_sent(self):
        at_30_fps = self.sender_at(30)
        self.queue.offer(0, 0, True, b"k")
        self.assertTrue(at_30_fps.pump(self.queue))
        self.queue.offer(1, 0, False, b"p")
        # 40 ms is past two frame times at 60 fps (33.3 ms) and inside two at 30.
        self.clock.now_s += 0.04
        self.assertTrue(at_30_fps.pump(self.queue))
        self.assertEqual(self.queue.stats()["aged"], 0)


class AgeLimitTest(unittest.TestCase):
    """The age limit the sender hands the queue: two frame times of the hello."""

    def test_the_limit_is_two_frame_times_of_the_hello_s_fps(self):
        self.assertAlmostEqual(tap_sender.age_limit_s(60), 2 / 60)
        self.assertAlmostEqual(tap_sender.age_limit_s(30), 2 / 30)

    def test_a_hello_that_names_no_frame_rate_gets_the_default(self):
        self.assertAlmostEqual(tap_sender.age_limit_s(None), 2 / tap_sender.DEFAULT_FPS)
        self.assertAlmostEqual(tap_sender.age_limit_s(0), 2 / tap_sender.DEFAULT_FPS)


if __name__ == "__main__":
    unittest.main(verbosity=2)
