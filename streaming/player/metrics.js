/*
 * The player's measurements as small pure functions (M15 c2). The reporter
 * turns WebRTC's statistics and requestVideoFrameCallback's metadata into the
 * batches `stats/stream` takes with these, and the overlay shows the same
 * numbers, so one definition serves both. Every name carries its unit.
 *
 * The batch format itself is `docs/protocol.md` §13; the field → where it is
 * measured → how table is in docs/briefs/m15/c2-stream-stats-report.md.
 */

const msPerS = 1000;
const bitsPerKbit = 1000;
const pctScale = 100;

/** A/V playout gaps further apart than this are a timestamp reset, not drift. */
const syncResetMs = 1000;

/**
 * The bits a second a track carried since the previous sample, or null when
 * there is nothing to compare with.
 * @param {{bytesReceived: number}|null} entry - inbound-rtp now
 * @param {{bytesReceived: number}|null} before - inbound-rtp at the last sample
 * @param {number} elapsedS - seconds between the two samples
 * @returns {number|null}
 */
export function rateKbitPerS(entry, before, elapsedS) {
  if (!entry || !before || !(elapsedS > 0)) return null;
  const bits = (entry.bytesReceived - before.bytesReceived) * 8;
  return Math.round(bits / bitsPerKbit / elapsedS);
}

/**
 * The share of the packets that never arrived, in percent: lost / (received +
 * lost). Null until the track has received something.
 * @param {{packetsReceived?: number, packetsLost?: number}|null} entry
 * @returns {number|null}
 */
export function lossPct(entry) {
  if (!entry) return null;
  const received = entry.packetsReceived ?? 0;
  const lost = entry.packetsLost ?? 0;
  if (received + lost <= 0) return null;
  return round2(lost / (received + lost) * pctScale);
}

/**
 * The mean time a frame waited in the jitter buffer, in ms:
 * jitterBufferDelay / jitterBufferEmittedCount over the last window.
 * @param {{jitterBufferDelay?: number, jitterBufferEmittedCount?: number}|null} entry
 * @param {{jitterBufferDelay?: number, jitterBufferEmittedCount?: number}|null} before
 * @returns {number|null}
 */
export function jitterBufferMs(entry, before) {
  if (!entry || !before) return null;
  const frames = (entry.jitterBufferEmittedCount ?? 0) - (before.jitterBufferEmittedCount ?? 0);
  if (frames <= 0) return null;
  const seconds = (entry.jitterBufferDelay ?? 0) - (before.jitterBufferDelay ?? 0);
  return round1(seconds / frames * msPerS);
}

/**
 * The mean time one frame took to decode, in ms: totalDecodeTime / the frames
 * decoded over the last window.
 * @param {{totalDecodeTime?: number, framesDecoded?: number}|null} entry
 * @param {{totalDecodeTime?: number, framesDecoded?: number}|null} before
 * @returns {number|null}
 */
export function decodeMsPerFrame(entry, before) {
  if (!entry || !before) return null;
  const frames = (entry.framesDecoded ?? 0) - (before.framesDecoded ?? 0);
  if (frames <= 0) return null;
  const seconds = (entry.totalDecodeTime ?? 0) - (before.totalDecodeTime ?? 0);
  return round1(seconds / frames * msPerS);
}

/**
 * How much later than the display it was expected for a frame was presented,
 * in ms: requestVideoFrameCallback's presentationTime against its
 * expectedDisplayTime. A frame shown at the moment the browser planned is 0;
 * the browser never says when decoding finished, so this is the display
 * stage's own delay, not decoded → shown.
 * @param {{presentationTime: number, expectedDisplayTime: number}} metadata
 * @returns {number}
 */
export function presentationDelayMs(metadata) {
  const delay = metadata.presentationTime - metadata.expectedDisplayTime;
  return delay > 0 ? round1(delay) : 0;
}

/**
 * The one-way network time the reference stack measures without a capture
 * timestamp: the selected candidate pair's round trip, halved. Null until a
 * pair reports one.
 * @param {{currentRoundTripTime?: number}|null} pair
 * @returns {number|null}
 */
export function networkMs(pair) {
  if (!pair || !(pair.currentRoundTripTime > 0)) return null;
  return round1(pair.currentRoundTripTime * msPerS / 2);
}

/**
 * How far ahead of the picture the sound was played, in ms: the audio track's
 * estimated playout timestamp against the video track's. A positive number
 * means sound runs ahead. Null unless both tracks report one, which Chrome
 * only does for some builds, and null for a gap beyond [syncResetMs]: the two
 * tracks keep their own timestamp bases, and a renegotiation that restarts one
 * is a reset, not a sound that is seconds out of step.
 * @param {{estimatedPlayoutTimestamp?: number}|null} audio
 * @param {{estimatedPlayoutTimestamp?: number}|null} video
 * @returns {number|null}
 */
export function audioSyncMs(audio, video) {
  if (!audio || !video) return null;
  const a = audio.estimatedPlayoutTimestamp;
  const v = video.estimatedPlayoutTimestamp;
  if (typeof a !== "number" || typeof v !== "number") return null;
  const ms = round1((a - v) * msPerS);
  return Math.abs(ms) <= syncResetMs ? ms : null;
}

/**
 * The share of the sound that had to be made up for, in percent:
 * concealedSamples / totalSamples. Null until the track has played something.
 * @param {{concealedSamples?: number, totalSamples?: number}|null} audio
 * @returns {number|null}
 */
export function concealedPct(audio) {
  if (!audio) return null;
  const total = audio.totalSamples ?? 0;
  const concealed = audio.concealedSamples ?? 0;
  if (total <= 0) return null;
  return round2(concealed / total * pctScale);
}

/**
 * One pixel's brightness, 0–255, as the flip watcher reads the picture:
 * Rec. 709's weights, which is what a display's own luminance follows.
 * @param {number} r - red, 0–255
 * @param {number} g - green, 0–255
 * @param {number} b - blue, 0–255
 * @returns {number}
 */
export function luminanceOf(r, g, b) {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/**
 * Watches one small patch of the picture for the latency card's flip (M15
 * c2): a brightness above `lightAbove` is the light card, below `darkBelow`
 * the dark one, and anything between is the blur between frames and is
 * ignored. Each crossing is one flip with the time it was seen.
 */
export class FlipWatcher {
  /**
   * @param {{lightAbove?: number, darkBelow?: number}} [thresholds] - the
   *   brightnesses that count as light and dark, 0–255
   */
  constructor({ lightAbove = 200, darkBelow = 60 } = {}) {
    this._lightAbove = lightAbove;
    this._darkBelow = darkBelow;
    this._light = null;
  }

  /**
   * Takes one reading of the patch and answers whether it is a flip, with the
   * state it flipped to (null for neither).
   * @param {number} luminance - the patch's brightness, 0–255
   * @returns {{light: boolean}|null}
   */
  observe(luminance) {
    const light = luminance >= this._lightAbove ? true : luminance <= this._darkBelow ? false : null;
    if (light === null || light === this._light) return null;
    const first = this._light === null;
    this._light = light;
    // The card coming up is not a flip: the first reading only says which
    // colour is showing.
    return first ? null : { light };
  }

  /** What the patch shows now: true light, false dark, null not seen yet. */
  get light() {
    return this._light;
  }
}

const round1 = (value) => Math.round(value * 10) / 10;
const round2 = (value) => Math.round(value * 100) / 100;
