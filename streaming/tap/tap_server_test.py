#!/usr/bin/env python3
"""The tap server's own test (M15 opt2-2), run inside the distro by
`tools/stream.sh selftest`.

The rules here are PROTOCOL.md's: a bounded queue per client, a drop to the next
keyframe when a client falls behind, and the RFC 6455 handshake and frames a
browser needs. The queue, the header and the framing are tested without sockets;
the rest over loopback, with a client built here from the standard library.

    python3 streaming/tap/tap_server_test.py
"""

import base64
import json
import os
import socket
import struct
import sys
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tap_queue
import tap_server
import tap_ws

# RFC 6455 section 1.3's example handshake: the key a browser sends and the
# accept value the server must answer with.
RFC_KEY = "dGhlIHNhbXBsZSBub25jZQ=="
RFC_ACCEPT = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

# How long a socket test waits for one answer before it fails.
WAIT_S = 5

# What a slow-client test sends per frame and how many frames it takes: enough
# bytes that a client which never reads fills its socket buffers and stalls.
SLOW_FRAME_BYTES = 256 * 1024
SLOW_TEST_FRAMES = 64

# The client frame opcodes RFC 6455 5.2 names.
OPCODE_CONTINUATION = 0x0
OPCODE_TEXT = 0x1
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA


def masked_frame(opcode, payload, fin=True, mask=b"\x01\x02\x03\x04"):
    """One client frame as RFC 6455 has it: masked, the length in its shortest form."""
    head = bytes([(0x80 if fin else 0) | opcode])
    length = len(payload)
    if length < 126:
        head += bytes([0x80 | length])
    elif length < 65536:
        head += bytes([0x80 | 126]) + struct.pack(">H", length)
    else:
        head += bytes([0x80 | 127]) + struct.pack(">Q", length)
    return head + mask + bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))


def diag_field(line, name):
    """One integer field of a diag line, by its name (M15 opt2c)."""
    for item in line.split()[1:]:
        field, _, value = item.partition("=")
        if field == name:
            return int(value)
    raise AssertionError("the diag line has no %s: %r" % (name, line))


class TestClient:
    """A browser's side of the tap: the upgrade, then masked client frames."""

    def __init__(self, port, rcvbuf_bytes=None):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        if rcvbuf_bytes is not None:
            # A client that never reads still lets the server's sends succeed
            # while this much fits; a small buffer keeps the test's frames few.
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, rcvbuf_bytes)
        self.sock.settimeout(WAIT_S)
        self.sock.connect(("127.0.0.1", port))
        self.buffer = b""
        self.head = ""

    def _until(self, marker):
        while marker not in self.buffer:
            data = self.sock.recv(4096)
            if not data:
                raise AssertionError("the server closed before it answered %r" % (marker,))
            self.buffer += data
        head, _, self.buffer = self.buffer.partition(marker)
        return (head + marker).decode("latin-1")

    def connect(self):
        """Sends the browser's upgrade on /tap, and answers the head it got."""
        self.sock.sendall(
            (
                "GET /tap HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\n"
                "Connection: Upgrade\r\nSec-WebSocket-Key: %s\r\n"
                "Sec-WebSocket-Version: 13\r\n\r\n" % RFC_KEY
            ).encode("ascii")
        )
        self.head = self._until(b"\r\n\r\n")
        return self.head

    def send(self, opcode, payload, fin=True):
        """One masked client frame."""
        self.sock.sendall(masked_frame(opcode, payload, fin=fin))

    def send_raw(self, data):
        """Bytes as they are, for a frame a server must refuse."""
        self.sock.sendall(data)

    def message(self, timeout_s=WAIT_S):
        """The next (opcode, payload) the server sent; (None, b"") when it closed."""
        deadline = time.monotonic() + timeout_s
        while True:
            frame = tap_ws.decode_frame(self.buffer)
            if frame is not None:
                self.buffer = self.buffer[frame.consumed :]
                return frame.opcode, frame.payload
            if time.monotonic() > deadline:
                raise AssertionError("no frame within %s s" % timeout_s)
            data = self.sock.recv(tap_server.SOCKET_READ_BYTES)
            if not data:
                return None, b""
            self.buffer += data

    def hello(self):
        """The hello text, decoded: the first frame every client gets."""
        opcode, payload = self.message()
        if opcode != OPCODE_TEXT:
            raise AssertionError("the first frame is not the hello text: %r" % opcode)
        return json.loads(payload.decode("utf-8"))

    def close(self):
        self.sock.close()


class FramingTest(unittest.TestCase):
    """The RFC 6455 pieces, without a socket."""

    def test_the_handshake_accept_value_is_the_rfc_example(self):
        self.assertEqual(tap_ws.accept_value(RFC_KEY), RFC_ACCEPT)

    def test_the_upgrade_key_is_read_from_a_get_for_tap(self):
        head = (
            "GET /tap HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\n"
            "Sec-WebSocket-Key: %s\r\n\r\n" % RFC_KEY
        ).encode("latin-1")
        self.assertEqual(tap_ws.upgrade_key(head), RFC_KEY)

    def test_anything_but_an_upgrade_on_tap_has_no_key(self):
        plain = b"GET /tap HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        elsewhere = (
            "GET /clock HTTP/1.1\r\nUpgrade: websocket\r\nSec-WebSocket-Key: %s\r\n\r\n" % RFC_KEY
        ).encode("latin-1")
        self.assertIsNone(tap_ws.upgrade_key(plain))
        self.assertIsNone(tap_ws.upgrade_key(elsewhere))

    def test_a_masked_client_frame_is_unmasked(self):
        wire = masked_frame(OPCODE_TEXT, b'{"type":"key"}')
        frame = tap_ws.decode_frame(wire)
        self.assertEqual(
            (frame.opcode, frame.payload, frame.fin, frame.masked),
            (OPCODE_TEXT, b'{"type":"key"}', True, True),
        )
        self.assertEqual(frame.consumed, len(wire))

    def test_a_frame_with_no_mask_is_reported_unmasked(self):
        wire = bytes([0x80 | OPCODE_TEXT, 3]) + b"abc"
        frame = tap_ws.decode_frame(wire)
        self.assertFalse(frame.masked)

    def test_an_incomplete_frame_decodes_to_nothing(self):
        wire = masked_frame(OPCODE_TEXT, b"x" * 200)
        self.assertIsNone(tap_ws.decode_frame(wire[:7]))
        self.assertIsNone(tap_ws.decode_frame(wire[:-1]))

    def test_a_fragmented_text_frame_reports_its_end(self):
        first = tap_ws.decode_frame(masked_frame(OPCODE_TEXT, b"ab", fin=False))
        second = tap_ws.decode_frame(masked_frame(OPCODE_CONTINUATION, b"cd"))
        self.assertEqual((first.fin, second.fin, second.opcode), (False, True, OPCODE_CONTINUATION))


class FrameMessageTest(unittest.TestCase):
    """PROTOCOL.md's 24-byte header before every access unit."""

    def test_a_keyframe_with_a_discontinuity_sets_both_flags(self):
        frame = tap_queue.Frame(7, 1200, True, True, b"\x00\x00\x00\x01\x65")
        message = tap_queue.frame_message(frame, 999)
        magic, version, flags, reserved, number, pts, sent = struct.unpack(">BBBBIQQ", message[:24])
        self.assertEqual((magic, version, flags, reserved), (0x54, 1, 0x03, 0))
        self.assertEqual((number, pts, sent), (7, 1200, 999))
        self.assertEqual(message[24:], b"\x00\x00\x00\x01\x65")

    def test_a_delta_frame_sets_no_flag(self):
        message = tap_queue.frame_message(tap_queue.Frame(8, 0, False, False, b"p"), 1)
        self.assertEqual(message[2], 0x00)
        self.assertEqual(len(message), tap_queue.HEADER_BYTES + 1)


class ClientQueueTest(unittest.TestCase):
    """PROTOCOL.md's backlog rule, without a socket."""

    def setUp(self):
        self.key_requests = 0

        def request_key():
            self.key_requests += 1

        self.queue = tap_queue.ClientQueue(request_key)

    def offer_frames(self, first, count, is_key=False):
        for number in range(first, first + count):
            self.queue.offer(number, 0, is_key, b"p")

    def fill(self):
        """A client started on a keyframe with four delta frames behind it."""
        self.queue.offer(0, 0, True, b"k")
        self.queue.take(0)
        self.offer_frames(1, tap_queue.QUEUE_FRAMES)

    def test_a_new_client_waits_for_a_keyframe(self):
        self.assertTrue(self.queue.needs_keyframe)
        self.assertFalse(self.queue.offer(1, 0, False, b"p"))
        self.assertEqual(self.queue.stats()["dropped"], 1)

    def test_a_keyframe_starts_the_client_without_the_flag(self):
        self.assertTrue(self.queue.offer(1, 0, True, b"k"))
        frame = self.queue.take(0)
        self.assertEqual((frame.frame_no, frame.is_key, frame.discontinuity), (1, True, False))
        self.assertFalse(self.queue.needs_keyframe)

    def test_the_queue_holds_four_frames(self):
        self.fill()
        self.assertEqual(self.queue.stats()["high_water"], tap_queue.QUEUE_FRAMES)
        frame = self.queue.take(0)
        self.assertEqual(frame.frame_no, 1)

    def test_an_overflow_drops_the_backlog_and_asks_for_a_key(self):
        self.fill()
        self.assertFalse(self.queue.offer(5, 0, False, b"p"))
        self.assertTrue(self.queue.needs_keyframe)
        self.assertEqual(self.key_requests, 1)
        # The four queued frames and the one that found the queue full.
        self.assertEqual(self.queue.stats()["dropped"], tap_queue.QUEUE_FRAMES + 1)
        self.assertIsNone(self.queue.take(0))

    def test_delta_frames_are_ignored_until_a_keyframe(self):
        self.fill()
        self.queue.offer(5, 0, False, b"p")
        for number in range(6, 10):
            self.assertFalse(self.queue.offer(number, 0, False, b"p"))
        self.assertEqual(self.key_requests, 1)
        self.assertIsNone(self.queue.take(0))

    def test_the_first_frame_after_a_drop_is_a_flagged_keyframe(self):
        self.fill()
        self.queue.offer(5, 0, False, b"p")
        self.assertTrue(self.queue.offer(6, 0, True, b"k"))
        frame = self.queue.take(0)
        self.assertEqual((frame.frame_no, frame.is_key, frame.discontinuity), (6, True, True))
        self.assertEqual(self.key_requests, 1)

    def test_one_overflow_asks_for_one_keyframe(self):
        self.fill()
        for number in range(5, 15):
            self.queue.offer(number, 0, False, b"p")
        self.assertEqual(self.key_requests, 1)

    def test_the_counters_follow_what_was_sent(self):
        self.queue.offer(0, 0, True, b"key")
        frame = self.queue.take(0)
        self.queue.note_sent(len(frame.data))
        stats = self.queue.stats()
        self.assertEqual((stats["sent"], stats["bytes"], stats["dropped"]), (1, 3, 0))

    def test_a_blocked_write_drops_to_a_keyframe_and_counts_the_frame(self):
        self.fill()
        self.queue.drop_to_keyframe()
        self.assertTrue(self.queue.needs_keyframe)
        self.assertEqual(self.key_requests, 1)
        self.assertEqual(self.queue.stats()["dropped"], tap_queue.QUEUE_FRAMES + 1)


class FakeClock:
    """The clients' clock, moved by hand so a keyframe rule is exact (M15 opt2c-3)."""

    def __init__(self):
        self.now_s = 1000.0

    def __call__(self):
        return self.now_s


class LoopbackTest(unittest.TestCase):
    """The server over a real loopback socket, with a client built here."""

    def setUp(self):
        self.key_requests = 0

        def request_key():
            self.key_requests += 1

        self.clock = FakeClock()
        self.server = tap_server.TapServer(0, request_key, self.info, clock=self.clock)
        self.server.start()
        self.addCleanup(self.server.stop)

    @staticmethod
    def info():
        return {"width": 1920, "height": 1080, "fps": 60, "profile": "avc1.F4002A", "chroma420": True}

    def client(self, **kwargs):
        client = TestClient(self.server.port, **kwargs)
        self.addCleanup(client.close)
        client.connect()
        return client

    def wait_for(self, condition, what):
        deadline = time.monotonic() + WAIT_S
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.01)
        self.fail("no %s within %s s" % (what, WAIT_S))

    def test_a_client_gets_the_hello_then_the_frames(self):
        client = self.client()
        self.assertIn("101", client.head)
        self.assertIn(RFC_ACCEPT, client.head)
        hello = client.hello()
        self.assertEqual(
            {key: hello[key] for key in ("type", "version", "width", "height", "fps", "profile")},
            {"type": "hello", "version": 1, "width": 1920, "height": 1080, "fps": 60, "profile": "avc1.F4002A"},
        )
        self.server.publish(0, 1000, True, b"\x00\x00\x00\x01\x65key")
        self.server.publish(1, 17000, False, b"\x00\x00\x00\x01\x41delta")
        first = client.message()
        second = client.message()
        self.assertEqual((first[0], second[0]), (tap_ws.OPCODE_BINARY, tap_ws.OPCODE_BINARY))
        numbers = [struct.unpack(">I", payload[4:8])[0] for _, payload in (first, second)]
        self.assertEqual(numbers, [0, 1])
        self.assertEqual(struct.unpack(">Q", first[1][8:16])[0], 1000)
        self.assertEqual(first[1][2], 0x01)
        self.assertEqual(second[1][2], 0x00)

    def test_the_hello_says_whether_the_stream_is_4_2_0(self):
        # Extra to PROTOCOL.md v1's fields: a page that knows it can say why a
        # 4:4:4 stream will not decode, and one that does not ignores it.
        self.assertIs(self.client().hello()["chroma420"], True)

    def test_the_hello_leaves_the_chroma_format_open_until_the_sps_comes(self):
        # None is what the tap knows before its first SPS, like profile.
        server = tap_server.TapServer(0, lambda: None, lambda: {"chroma420": None})
        server.start()
        self.addCleanup(server.stop)
        client = TestClient(server.port)
        self.addCleanup(client.close)
        client.connect()
        self.assertIsNone(client.hello()["chroma420"])

    def test_a_client_is_asked_for_a_keyframe_when_it_connects(self):
        self.client()
        self.wait_for(lambda: self.key_requests == 1, "keyframe request at connect")

    def test_a_key_message_asks_the_encoder(self):
        client = self.client()
        self.wait_for(lambda: self.key_requests == 1, "keyframe request at connect")
        # The connect's own ask is still outstanding: the client's message may
        # ask again only once it has expired (PROTOCOL.md's key rule).
        self.clock.now_s += 2.6
        client.send(OPCODE_TEXT, b'{"type":"key"}')
        self.wait_for(lambda: self.key_requests == 2, "keyframe request from the client")

    def test_a_key_message_inside_the_outstanding_request_asks_nothing(self):
        client = self.client()
        self.wait_for(lambda: self.key_requests == 1, "keyframe request at connect")
        client.send(OPCODE_TEXT, b'{"type":"key"}')
        self.wait_for(lambda: self.server.stats()["keyreq_suppressed"] == 1, "the ask to be held back")
        self.assertEqual(self.key_requests, 1)

    def test_a_ping_is_answered_with_its_own_payload(self):
        client = self.client()
        client.hello()
        client.send(OPCODE_PING, b"are you there")
        opcode, payload = client.message()
        self.assertEqual((opcode, payload), (OPCODE_PONG, b"are you there"))

    def test_a_fragmented_key_message_asks_the_encoder(self):
        client = self.client()
        self.wait_for(lambda: self.key_requests == 1, "keyframe request at connect")
        self.clock.now_s += 2.6
        client.send(OPCODE_TEXT, b'{"type":', fin=False)
        client.send(OPCODE_CONTINUATION, b'"key"}')
        self.wait_for(lambda: self.key_requests == 2, "keyframe request from the fragments")

    def test_a_close_frame_ends_the_client(self):
        client = self.client()
        client.hello()
        client.send(OPCODE_CLOSE, b"")
        opcode, _ = client.message()
        self.assertIn(opcode, (OPCODE_CLOSE, None))
        self.wait_for(lambda: self.server.stats()["clients"] == 0, "the client to go")

    def test_an_unmasked_client_frame_ends_the_client(self):
        client = self.client()
        unmasked = bytes([0x80 | OPCODE_TEXT, 2]) + b"{}"
        client.send_raw(unmasked)
        self.wait_for(lambda: self.server.stats()["clients"] == 0, "the client to go")

    def test_a_slow_client_falls_to_a_keyframe_while_a_fast_one_gets_every_frame(self):
        fast = self.client()
        fast.hello()
        slow = self.client(rcvbuf_bytes=4096)
        slow.hello()
        self.wait_for(lambda: self.server.stats()["clients"] == 2, "both clients")
        frame = bytes(SLOW_FRAME_BYTES)
        self.server.publish(0, 0, True, frame)
        self.assertEqual(fast.message()[0], tap_ws.OPCODE_BINARY)
        for number in range(1, SLOW_TEST_FRAMES + 1):
            self.server.publish(number, number * 1000, False, frame)
            _, payload = fast.message()
            self.assertEqual(struct.unpack(">I", payload[4:8])[0], number)
        stats = self.server.stats()
        self.assertGreater(stats["dropped"], 0)
        self.assertGreaterEqual(self.key_requests, 2)

    def test_end_is_sent_when_the_server_stops(self):
        client = self.client()
        client.hello()
        self.server.publish(0, 0, True, b"key")
        client.message()
        self.server.stop()
        opcode, payload = client.message()
        self.assertEqual((opcode, json.loads(payload.decode("utf-8"))), (tap_ws.OPCODE_TEXT, {"type": "end"}))
        self.assertEqual(client.message(), (None, b""))
        self.assertEqual(self.server.stats()["clients"], 0)

    def test_the_diag_line_counts_the_encoder_and_what_was_sent(self):
        """The hooks the tap's line needs: the encoder's frame and a client's socket."""
        client = self.client()
        client.hello()
        self.server.diag.frame(True, tap_queue.HEADER_BYTES + 3)
        self.server.publish(0, 0, True, b"key")
        client.message()
        self.wait_for(lambda: self.server.stats()["sent"] == 1, "the frame to be counted")
        line = self.server.diag.line()
        self.assertEqual((diag_field(line, "fr"), diag_field(line, "key")), (1, 1))
        self.assertEqual(diag_field(line, "q"), 1)
        self.assertGreaterEqual(diag_field(line, "outq"), 0)

    def test_a_window_with_no_client_is_no_diag_line(self):
        self.assertIsNone(self.server.diag.line())

    def test_the_stats_name_what_was_sent_and_dropped(self):
        client = self.client()
        client.hello()
        self.server.publish(0, 0, True, b"key")
        client.message()
        self.wait_for(lambda: self.server.stats()["sent"] == 1, "the frame to be counted")
        stats = self.server.stats()
        self.assertEqual(stats["bytes"], tap_queue.HEADER_BYTES + 3)
        self.assertEqual(stats["clients"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
