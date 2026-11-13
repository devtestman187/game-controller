"""Access-unit helpers for the host tap (M15 opt2).

Pure Python with no GStreamer import, so the rules can be tested without a
pipeline: the 24-byte header the tap server puts before each access unit
(docs/briefs/m15/opt2/PROTOCOL.md), splitting the encoder's Annex B output into
NAL units, and the few SPS fields a WebCodecs player is told at hello.
"""

import struct

# The header PROTOCOL.md v1 fixes: magic 'T', version, flags, reserved, the
# encoder's frame number, the buffer's PTS in microseconds and the host's wall
# clock in microseconds when the frame is sent.
MAGIC = 0x54
VERSION = 1
FLAG_KEYFRAME = 0x01
FLAG_DISCONTINUITY = 0x02
HEADER = struct.Struct(">BBBBIQQ")
HEADER_BYTES = HEADER.size

# NAL unit types and the mask of the header byte that carries them (ITU-T H.264
# table 7-1): an IDR slice, a sequence parameter set, a picture parameter set.
_NAL_TYPE_MASK = 0x1F
NAL_SLICE_IDR = 5
NAL_SPS = 7
NAL_PPS = 8

# The profiles whose SPS carries the chroma format and bit-depth fields before
# the frame fields (H.264 7.3.2.1.1); every other profile implies 4:2:0.
_PROFILES_WITH_CHROMA_INFO = frozenset(
    (100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135)
)


def pack_header(flags, frame, pts_us, sent_us):
    """The header that goes before an access unit, per PROTOCOL.md v1.

    flags is FLAG_KEYFRAME and/or FLAG_DISCONTINUITY, frame counts every frame
    the encoder made so a receiver sees gaps, pts_us is the buffer's running
    time in microseconds and sent_us the host's wall clock in microseconds.
    """
    return HEADER.pack(MAGIC, VERSION, flags, 0, frame, pts_us, sent_us)


def avc_to_annexb(data):
    """The access unit with start codes: an AVC length prefix becomes one.

    nvautogpuh264enc's output is AVC, each NAL prefixed with its four-byte
    length, unless a caps filter asks for byte-stream; on this driver a
    byte-stream caps filter stalls the session's pipeline (opt2-1 report), so
    the tap branch's parser keeps AVC and the runner converts each unit here,
    which keeps the Annex B PROTOCOL.md promises.
    """
    if data[:4] == b"\x00\x00\x00\x01" or data[:3] == b"\x00\x00\x01":
        return data
    out = bytearray()
    offset = 0
    while offset + 4 <= len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        end = offset + 4 + length
        if length < 1 or end > len(data):
            raise ValueError("a NAL's length runs past the end of the access unit")
        out += b"\x00\x00\x00\x01"
        out += data[offset + 4 : end]
        offset = end
    if offset != len(data):
        raise ValueError("the access unit ends in a partial NAL length")
    return bytes(out)


def split_nalus(annexb):
    """The NAL units of an Annex B buffer, each without its start code.

    A 3-byte start code (00 00 01) and a 4-byte one (00 00 00 01) both count.
    The zero bytes before a start code are dropped, which H.264's
    trailing_zero_8bits allows and the encoder writes between access units.
    """
    nalus = []
    start = None
    i = 0
    limit = len(annexb) - 3
    while i <= limit:
        if annexb[i] == 0 and annexb[i + 1] == 0 and annexb[i + 2] == 1:
            if start is not None:
                nalus.append(_strip_trailing_zeros(annexb, start, i))
            i += 3
            start = i
            continue
        i += 1
    if start is not None:
        nalus.append(_strip_trailing_zeros(annexb, start, len(annexb)))
    return [nalu for nalu in nalus if nalu]


def is_keyframe(annexb):
    """Whether an access unit holds an IDR slice, which makes it a keyframe."""
    for nalu in split_nalus(annexb):
        if nalu[0] & _NAL_TYPE_MASK == NAL_SLICE_IDR:
            return True
    return False


def has_sps_and_pps(annexb):
    """Whether an access unit repeats both parameter sets, as a join needs."""
    sps, pps = extract_sps_pps(annexb)
    return sps is not None and pps is not None


def extract_sps_pps(annexb):
    """The SPS and the PPS units an access unit carries, None for one it lacks."""
    sps = None
    pps = None
    for nalu in split_nalus(annexb):
        kind = nalu[0] & _NAL_TYPE_MASK
        if kind == NAL_SPS and sps is None:
            sps = nalu
        elif kind == NAL_PPS and pps is None:
            pps = nalu
    return sps, pps


def profile_string(sps):
    """The WebCodecs name of an SPS: avc1.PPCCLL, profile, constraints, level.

    The four bytes after the NAL header are profile_idc, the constraint flags
    and level_idc (H.264 7.3.2.1.1), which is exactly what the codec string
    spells in hexadecimal, e.g. avc1.42C01F.
    """
    if sps is None or len(sps) < 4:
        raise ValueError("an SPS is at least four bytes past its NAL header")
    return "avc1.%02X%02X%02X" % (sps[1], sps[2], sps[3])


def is_chroma_420(sps):
    """Whether the SPS says 4:2:0, the only chroma format a browser decoder takes.

    NVENC encoded whatever chroma format the capture handed it, 4:4:4 among
    them (avc1.F4002A, opt2-1 report), so the tap reads the format back from
    the SPS and says when the stream is one Safari will refuse.
    """
    return _sps_fields(sps)["chroma_format_idc"] == 1


def frame_size(sps):
    """The encoded picture's size in pixels, cropping included (H.264 7.4.2.1).

    The SPS counts whole macroblocks; the frame-cropping fields take the
    padding back off, in chroma samples, so the answer is the 1920x1080 the
    encoder was given rather than its 1920x1088 macroblock count.
    """
    fields = _sps_fields(sps)
    crop_left, crop_right, crop_top, crop_bottom = fields["crop"]
    # SubWidthC and SubHeightC of table 6-1: 2 for 4:2:0, 1 for 4:2:2 and
    # 4:4:4, and 1 for monochrome, whose SPS has no chroma format field.
    sub_width = 2 if fields["chroma_format_idc"] in (1, 2) else 1
    sub_height = 2 if fields["chroma_format_idc"] == 1 else 1
    frame_mbs_only = fields["frame_mbs_only_flag"]
    width = fields["width_mbs"] * 16 - (crop_left + crop_right) * sub_width
    height = (2 - frame_mbs_only) * fields["height_map_units"] * 16
    height -= (crop_top + crop_bottom) * sub_height * (2 - frame_mbs_only)
    return width, height


def _strip_trailing_zeros(data, start, end):
    while end > start and data[end - 1] == 0:
        end -= 1
    return data[start:end]


def _rbsp(nal):
    """A NAL's RBSP: the byte after 00 00 03 is emulation prevention, dropped."""
    out = bytearray()
    zeros = 0
    for byte in nal:
        if zeros >= 2 and byte == 3:
            zeros = 0
            continue
        out.append(byte)
        zeros = zeros + 1 if byte == 0 else 0
    return bytes(out)


def _skip_scaling_list(bits, size):
    last_scale = 8
    next_scale = 8
    for _ in range(size):
        if next_scale != 0:
            next_scale = (last_scale + bits.se() + 256) % 256
        if next_scale != 0:
            last_scale = next_scale


def _sps_fields(sps):
    """The SPS fields frame_size needs, read in the order H.264 7.3.2.1.1 has them."""
    if sps is None or len(sps) < 4:
        raise ValueError("an SPS is at least four bytes past its NAL header")
    # The NAL header byte is not part of the RBSP.
    bits = _Bits(_rbsp(sps[1:]))
    profile_idc = bits.u(8)
    bits.u(8)  # constraint flags
    bits.u(8)  # level_idc
    bits.ue()  # seq_parameter_set_id
    chroma_format_idc = 1
    if profile_idc in _PROFILES_WITH_CHROMA_INFO:
        chroma_format_idc = bits.ue()
        if chroma_format_idc == 3:
            bits.u(1)  # separate_colour_plane_flag
        bits.ue()  # bit_depth_luma_minus8
        bits.ue()  # bit_depth_chroma_minus8
        bits.u(1)  # qpprime_y_zero_transform_bypass_flag
        if bits.u(1):  # seq_scaling_matrix_present_flag
            for index in range(8 if chroma_format_idc != 3 else 12):
                if bits.u(1):
                    _skip_scaling_list(bits, 16 if index < 6 else 64)
    bits.ue()  # log2_max_frame_num_minus4
    pic_order_cnt_type = bits.ue()
    if pic_order_cnt_type == 0:
        bits.ue()  # log2_max_pic_order_cnt_lsb_minus4
    elif pic_order_cnt_type == 1:
        bits.u(1)  # delta_pic_order_always_zero_flag
        bits.se()  # offset_for_non_ref_pic
        bits.se()  # offset_for_top_to_bottom_field
        for _ in range(bits.ue()):  # num_ref_frames_in_pic_order_cnt_cycle
            bits.se()
    bits.ue()  # max_num_ref_frames
    bits.u(1)  # gaps_in_frame_num_value_allowed_flag
    width_mbs = bits.ue() + 1
    height_map_units = bits.ue() + 1
    frame_mbs_only = bits.u(1)
    if not frame_mbs_only:
        bits.u(1)  # mb_adaptive_frame_field_flag
    bits.u(1)  # direct_8x8_inference_flag
    crop = (0, 0, 0, 0)
    if bits.u(1):  # frame_cropping_flag
        crop = (bits.ue(), bits.ue(), bits.ue(), bits.ue())
    return {
        "chroma_format_idc": chroma_format_idc,
        "width_mbs": width_mbs,
        "height_map_units": height_map_units,
        "frame_mbs_only_flag": frame_mbs_only,
        "crop": crop,
    }


class _Bits:
    """Reads an RBSP's bit fields: fixed width, signed and unsigned Exp-Golomb."""

    def __init__(self, data):
        self.data = data
        self.pos = 0

    def u(self, count):
        value = 0
        for _ in range(count):
            byte_index = self.pos >> 3
            if byte_index >= len(self.data):
                raise ValueError("the SPS ended before its last field")
            bit = (self.data[byte_index] >> (7 - (self.pos & 7))) & 1
            value = (value << 1) | bit
            self.pos += 1
        return value

    def ue(self):
        zeros = 0
        while self.u(1) == 0:
            zeros += 1
            if zeros > 31:
                raise ValueError("an Exp-Golomb code longer than 32 bits")
        return (1 << zeros) - 1 + self.u(zeros)

    def se(self):
        code = self.ue()
        return (code + 1) // 2 if code & 1 else -(code // 2)
