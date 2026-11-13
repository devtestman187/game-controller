"""The WebSocket wire the tap server speaks: RFC 6455's server side (M15 opt2-2).

Pure Python with no socket in it, so the handshake value, the frame reader and
the frame writer can be tested without a connection: a masked client frame in,
its payload out; a server frame out, unmasked with its length in the shortest
form RFC 6455 allows. The server itself is tap_server.py.
"""

import base64
import hashlib
import struct
from collections import namedtuple

# RFC 6455 5.2's opcodes and 4.2.2's GUID.
OPCODE_CONTINUATION = 0x0
OPCODE_TEXT = 0x1
OPCODE_BINARY = 0x2
OPCODE_CLOSE = 0x8
OPCODE_PING = 0x9
OPCODE_PONG = 0xA
WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# The path a browser's upgrade asks for (PROTOCOL.md).
TAP_PATH = "/tap"

# One frame as a client sent it; `consumed` bytes of the buffer made it.
WireFrame = namedtuple("WireFrame", "opcode payload fin masked consumed")

# The two length escapes of RFC 6455 5.2, and the bits of a frame's first bytes.
_LENGTH_16_BYTES = 126
_LENGTH_64_BYTES = 127
_FIN_BIT = 0x80
_MASK_BIT = 0x80
_OPCODE_BITS = 0x0F
_LENGTH_BITS = 0x7F


def accept_value(key):
    """RFC 6455 4.2.2's Sec-WebSocket-Accept: sha1 of the key and the GUID, in base64."""
    digest = hashlib.sha1((key + WEBSOCKET_GUID).encode("ascii")).digest()
    return base64.b64encode(digest).decode("ascii")


def upgrade_key(head):
    """The Sec-WebSocket-Key of a GET for /tap that upgrades, or None for anything else."""
    lines = head.decode("latin-1").split("\r\n")
    parts = lines[0].split(" ")
    if len(parts) < 2 or parts[0] != "GET" or parts[1].partition("?")[0] != TAP_PATH:
        return None
    headers = {}
    for line in lines[1:]:
        name, _, value = line.partition(":")
        headers[name.strip().lower()] = value.strip()
    if headers.get("upgrade", "").lower() != "websocket":
        return None
    return headers.get("sec-websocket-key") or None


def decode_frame(buffer):
    """The first whole frame in `buffer`, or None while more bytes are needed.

    A masked payload is unmasked here; `masked` says whether the client sent a
    mask, which RFC 6455 5.1 requires of every frame a client sends.
    """
    if len(buffer) < 2:
        return None
    first, second = buffer[0], buffer[1]
    fin = bool(first & _FIN_BIT)
    opcode = first & _OPCODE_BITS
    masked = bool(second & _MASK_BIT)
    length = second & _LENGTH_BITS
    offset = 2
    if length == _LENGTH_16_BYTES:
        if len(buffer) < offset + 2:
            return None
        length = struct.unpack_from(">H", buffer, offset)[0]
        offset += 2
    elif length == _LENGTH_64_BYTES:
        if len(buffer) < offset + 8:
            return None
        length = struct.unpack_from(">Q", buffer, offset)[0]
        offset += 8
    if masked:
        offset += 4
    if len(buffer) < offset + length:
        return None
    payload = buffer[offset : offset + length]
    if masked:
        mask = buffer[offset - 4 : offset]
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return WireFrame(opcode, bytes(payload), fin, masked, offset + length)


def encode_frame(opcode, payload):
    """One server frame, unmasked, with its length in RFC 6455 5.2's shortest form."""
    length = len(payload)
    if length < _LENGTH_16_BYTES:
        head = struct.pack(">BB", _FIN_BIT | opcode, length)
    elif length < 65536:
        head = struct.pack(">BBH", _FIN_BIT | opcode, _LENGTH_16_BYTES, length)
    else:
        head = struct.pack(">BBQ", _FIN_BIT | opcode, _LENGTH_64_BYTES, length)
    return head + payload
