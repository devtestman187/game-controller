"""Tests for the tap's access-unit helpers (M15 opt2).

Run with `python3 streaming/tap/tap_frames_test.py`. The sample in
testdata/sample_h264.bin is one IDR carrying its SPS and PPS plus three P
frames, captured from nvautogpuh264enc at 1920x1080 in the tp-stream distro
(the report says how); testdata/sample_h264.json records each access unit's
offset and length in it.
"""

import json
import os
import struct
import unittest

import tap_frames

_HERE = os.path.dirname(os.path.abspath(__file__))
_TESTDATA = os.path.join(_HERE, "testdata")


def _load_sample():
    with open(os.path.join(_TESTDATA, "sample_h264.bin"), "rb") as handle:
        data = handle.read()
    with open(os.path.join(_TESTDATA, "sample_h264.json"), encoding="utf-8") as handle:
        doc = json.load(handle)
    return data, doc


class HeaderTest(unittest.TestCase):
    def test_a_frame_header_is_the_24_bytes_protocol_md_fixes(self):
        header = tap_frames.pack_header(tap_frames.FLAG_KEYFRAME, 7, 123456, 1700000000000000)
        self.assertEqual(len(header), 24)
        self.assertEqual(header[:4], b"T\x01\x01\x00")
        self.assertEqual(
            struct.unpack(">BBBBIQQ", header), (0x54, 1, 1, 0, 7, 123456, 1700000000000000)
        )

    def test_both_flags_share_one_byte(self):
        flags = tap_frames.FLAG_KEYFRAME | tap_frames.FLAG_DISCONTINUITY
        self.assertEqual(tap_frames.pack_header(flags, 0, 0, 0)[2], 0x03)

    def test_the_reserved_byte_stays_zero(self):
        self.assertEqual(tap_frames.pack_header(0, 1, 2, 3)[3], 0)


class SplitTest(unittest.TestCase):
    def test_both_start_code_lengths_split_and_no_zeros_are_kept(self):
        annexb = b"\x00\x00\x00\x01\x09\xf0\x00\x00\x01\x07\x10\x00\x00\x00\x00\x01\x05\x20"
        self.assertEqual(
            tap_frames.split_nalus(annexb), [b"\x09\xf0", b"\x07\x10", b"\x05\x20"]
        )

    def test_a_buffer_without_a_start_code_has_no_units(self):
        self.assertEqual(tap_frames.split_nalus(b"\x09\xf0\x07\x10"), [])

    def test_the_sample_splits_into_the_access_units_the_json_records(self):
        data, doc = _load_sample()
        units = tap_frames.split_nalus(data)
        # An access unit starts with its AUD (type 9); the sample has four.
        starts = [index for index, unit in enumerate(units) if unit[0] & 0x1F == 9]
        self.assertEqual(len(starts), len(doc["frames"]))
        # Each frame's slice of the sample holds the same units the whole
        # buffer does, so the json's boundaries agree with the split.
        for frame, start in zip(doc["frames"], starts):
            piece = data[frame["offset"] : frame["offset"] + frame["length"]]
            self.assertEqual(
                b"".join(b"\x00\x00\x00\x01" + unit for unit in tap_frames.split_nalus(piece)),
                piece,
            )


class AvcToAnnexBTest(unittest.TestCase):
    def test_each_length_prefix_becomes_a_start_code(self):
        # An AUD of 2 bytes and an IDR of 3, as nvautogpuh264enc lays them out.
        avc = b"\x00\x00\x00\x02\x09\xf0\x00\x00\x00\x03\x65\x88\x84"
        self.assertEqual(
            tap_frames.avc_to_annexb(avc), b"\x00\x00\x00\x01\x09\xf0\x00\x00\x00\x01\x65\x88\x84"
        )

    def test_annex_b_is_left_as_it_is(self):
        annexb = b"\x00\x00\x00\x01\x09\xf0\x00\x00\x01\x65\x88\x84"
        self.assertEqual(tap_frames.avc_to_annexb(annexb), annexb)

    def test_a_length_past_the_buffer_is_refused(self):
        with self.assertRaises(ValueError):
            tap_frames.avc_to_annexb(b"\x00\x00\x00\x09\x09\xf0")

    def test_a_partial_length_is_refused(self):
        # Two bytes left over after the AUD: not a start code, not a length.
        # (The buffer may not open with 00 00 00 01, which is Annex B already.)
        with self.assertRaises(ValueError):
            tap_frames.avc_to_annexb(b"\x00\x00\x00\x02\x09\xf0\x00\x00")

    def test_the_converted_sample_splits_into_the_recorded_units(self):
        data, doc = _load_sample()
        avc = bytearray()
        for frame in doc["frames"]:
            piece = data[frame["offset"] : frame["offset"] + frame["length"]]
            for nalu in tap_frames.split_nalus(piece):
                avc += len(nalu).to_bytes(4, "big") + nalu
        self.assertEqual(tap_frames.avc_to_annexb(bytes(avc)), data)


class KeyframeTest(unittest.TestCase):
    def test_the_idr_access_unit_is_the_keyframe(self):
        data, doc = _load_sample()
        for frame in doc["frames"]:
            piece = data[frame["offset"] : frame["offset"] + frame["length"]]
            self.assertEqual(tap_frames.is_keyframe(piece), frame["is_key"])

    def test_an_access_unit_with_only_a_sps_is_not_a_keyframe(self):
        self.assertFalse(tap_frames.is_keyframe(b"\x00\x00\x00\x01\x67\x42\xc0\x1f"))

    def test_the_sample_carries_sps_and_pps_with_its_idr_only(self):
        data, doc = _load_sample()
        first = data[: doc["frames"][0]["length"]]
        second = data[doc["frames"][1]["offset"] : doc["frames"][1]["offset"] + doc["frames"][1]["length"]]
        self.assertTrue(tap_frames.has_sps_and_pps(first))
        self.assertFalse(tap_frames.has_sps_and_pps(second))
        sps, pps = tap_frames.extract_sps_pps(first)
        self.assertEqual(sps[0] & 0x1F, 7)
        self.assertEqual(pps[0] & 0x1F, 8)
        self.assertEqual(tap_frames.extract_sps_pps(second), (None, None))


class SpsTest(unittest.TestCase):
    def test_the_codec_name_is_the_samples_profile_and_level(self):
        data, doc = _load_sample()
        sps, _ = tap_frames.extract_sps_pps(data[: doc["frames"][0]["length"]])
        self.assertEqual(tap_frames.profile_string(sps), doc["profile"])
        self.assertEqual(tap_frames.profile_string(sps), "avc1.F4002A")

    def test_the_picture_size_takes_the_sps_cropping_off(self):
        data, doc = _load_sample()
        sps, _ = tap_frames.extract_sps_pps(data[: doc["frames"][0]["length"]])
        # The SPS counts 120x68 macroblocks, 1920x1088; the cropping fields
        # take the last 8 lines off, which is the 1080 the encoder was given.
        self.assertEqual(tap_frames.frame_size(sps), (doc["width"], doc["height"]))
        self.assertEqual(tap_frames.frame_size(sps), (1920, 1080))

    def test_an_sps_too_short_for_its_profile_bytes_is_refused(self):
        with self.assertRaises(ValueError):
            tap_frames.profile_string(None)
        with self.assertRaises(ValueError):
            tap_frames.frame_size(b"\x67\x42")


if __name__ == "__main__":
    unittest.main()
