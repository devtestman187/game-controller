/*
 * The custom player's Annex B helpers (M15 opt2): the host sends one access
 * unit per message — Annex B start codes, an AUD first, SPS and PPS before
 * every IDR (streaming/briefs PROTOCOL.md) — behind a 24-byte header. The
 * decoder is given it either as AVCC with an avcC description built from the
 * SPS and PPS (the study's safe mode, the default) or as Annex B unchanged
 * (`wcmode=annexb`). Pure: nothing here reads the page, and a message it cannot
 * read is a null, never a throw.
 */

/** The message header's magic ('T') and version (PROTOCOL.md). */
const headerMagic = 0x54;
const headerVersion = 1;

/** The header's length in bytes: magic, version, flags, reserved, frame, pts, sent. */
const headerBytes = 24;

/** Where each field starts in the header, in bytes. */
const frameAt = 4;
const ptsUsAt = 8;
const sentUsAt = 16;

/** The flag bits: bit0 a keyframe, bit1 frames were dropped before this one. */
const keyframeBit = 1;
const discontinuityBit = 2;

/** NAL unit types this player names: an IDR slice, SPS, PPS and the AUD. */
const idrType = 5;
const spsType = 7;
const ppsType = 8;
const audType = 9;

/** The NAL types left out of an AVCC sample: the decoder gets SPS and PPS in its description. */
const droppedTypes = [audType, spsType, ppsType];

/** avcC's version byte and the length field it uses: 4-byte NAL lengths (lengthSizeMinusOne 3). */
const avccVersion = 1;
const avccLengthSizeMinusOne = 3;

/** The reserved bits avcC keeps set in its two configuration bytes. */
const avccReservedSix = 0xfc;
const avccReservedThree = 0xe0;

/** Two hex digits, upper case: the way an avc1 codec string names a byte. */
function hexByte(value) {
  return value.toString(16).padStart(2, "0").toUpperCase();
}

/** [unit] without the trailing zero bytes an Annex B start code may leave in front of it. */
function withoutTrailingZeros(unit) {
  let end = unit.length;
  while (end > 0 && unit[end - 1] === 0) end--;
  return unit.subarray(0, end);
}

/**
 * The NAL units of one Annex B buffer, start codes and the zeros in front of
 * them left out. A buffer with no start code has no units.
 * @param {Uint8Array} bytes
 * @returns {Uint8Array[]}
 */
export function splitNalus(bytes) {
  const units = [];
  let from = -1;
  for (let at = 0; at + 3 <= bytes.length; at++) {
    if (bytes[at] !== 0 || bytes[at + 1] !== 0 || bytes[at + 2] !== 1) continue;
    if (from >= 0) units.push(withoutTrailingZeros(bytes.subarray(from, at)));
    from = at + 3;
    at += 2;
  }
  if (from >= 0) units.push(withoutTrailingZeros(bytes.subarray(from)));
  return units.filter((unit) => unit.length > 0);
}

/**
 * A NAL unit's type, the low 5 bits of its first byte (0 for an empty unit).
 * @param {Uint8Array} nal
 * @returns {number}
 */
export function nalType(nal) {
  return nal.length === 0 ? 0 : nal[0] & 0x1f;
}

/**
 * Whether one access unit holds an IDR slice, which is what makes it a
 * keyframe: the host sets the header's flag from the same fact, so this is the
 * check on bytes alone.
 * @param {Uint8Array} bytes - one access unit in Annex B
 * @returns {boolean}
 */
export function isKeyframe(bytes) {
  return splitNalus(bytes).some((nal) => nalType(nal) === idrType);
}

/**
 * The first SPS and PPS in one access unit, which is what the decoder's
 * description is built from, or null when it carries neither.
 * @param {Uint8Array} bytes - one access unit in Annex B
 * @returns {{sps: Uint8Array, pps: Uint8Array}|null}
 */
export function parameterSets(bytes) {
  const units = splitNalus(bytes);
  const sps = units.find((nal) => nalType(nal) === spsType);
  const pps = units.find((nal) => nalType(nal) === ppsType);
  return sps === undefined || pps === undefined ? null : { sps, pps };
}

/**
 * The codec string an SPS names, `avc1.PPCCLL`: its profile, the constraint
 * flags and its level, as hex (avc1.640028 is High profile, level 4.0).
 * @param {Uint8Array} sps - the SPS's NAL unit, header included
 * @returns {string}
 */
export function codecString(sps) {
  return `avc1.${hexByte(sps[1])}${hexByte(sps[2])}${hexByte(sps[3])}`;
}

/**
 * The AVCDecoderConfigurationRecord for one SPS and PPS: what a decoder given
 * AVCC needs to know the codec, and where the sample's NAL lengths are 4 bytes.
 * @param {Uint8Array} sps - the SPS's NAL unit, header included
 * @param {Uint8Array} pps - the PPS's NAL unit, header included
 * @returns {Uint8Array}
 */
export function buildAvcc(sps, pps) {
  const record = new Uint8Array(11 + sps.length + pps.length);
  const view = new DataView(record.buffer);
  record[0] = avccVersion;
  record[1] = sps[1];
  record[2] = sps[2];
  record[3] = sps[3];
  record[4] = avccReservedSix | avccLengthSizeMinusOne;
  record[5] = avccReservedThree | 1;
  view.setUint16(6, sps.length);
  record.set(sps, 8);
  const ppsAt = 8 + sps.length;
  record[ppsAt] = 1;
  view.setUint16(ppsAt + 1, pps.length);
  record.set(pps, ppsAt + 3);
  return record;
}

/**
 * One access unit changed from Annex B to a decodable AVCC sample: each kept
 * NAL unit behind a 4-byte length, in the same order. The AUD, SPS and PPS go
 * to the description instead, so the sample has slices only.
 * @param {Uint8Array} bytes - one access unit in Annex B
 * @returns {Uint8Array}
 */
export function annexbToAvcc(bytes) {
  const kept = splitNalus(bytes).filter((nal) => !droppedTypes.includes(nalType(nal)));
  const sample = new Uint8Array(kept.reduce((total, nal) => total + 4 + nal.length, 0));
  const view = new DataView(sample.buffer);
  let at = 0;
  for (const nal of kept) {
    view.setUint32(at, nal.length);
    sample.set(nal, at + 4);
    at += 4 + nal.length;
  }
  return sample;
}

/**
 * One binary message's header and payload (PROTOCOL.md's 24 bytes, big-endian),
 * or null for anything else — a text frame, a message from a server whose
 * version this page does not know, or one too short to hold a header.
 * @param {ArrayBuffer} buffer
 * @returns {{flags: number, keyframe: boolean, discontinuity: boolean, frame: number,
 *   ptsUs: number, sentUs: number, payload: Uint8Array}|null}
 */
export function parseHeader(buffer) {
  if (!(buffer instanceof ArrayBuffer) || buffer.byteLength < headerBytes) return null;
  const view = new DataView(buffer);
  if (view.getUint8(0) !== headerMagic || view.getUint8(1) !== headerVersion) return null;
  const flags = view.getUint8(2);
  return {
    flags,
    keyframe: (flags & keyframeBit) !== 0,
    discontinuity: (flags & discontinuityBit) !== 0,
    frame: view.getUint32(frameAt),
    ptsUs: Number(view.getBigUint64(ptsUsAt)),
    sentUs: Number(view.getBigUint64(sentUsAt)),
    payload: new Uint8Array(buffer, headerBytes),
  };
}
