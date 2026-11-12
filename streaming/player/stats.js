/*
 * The player's numbers, in one small module (M15 c1): the overlay shows them
 * and job c2 sends the same values to the host. Every name carries its unit.
 */

/**
 * One sample of what the browser can say about the stream. Numbers are 0 when
 * the report does not carry them yet.
 * @typedef {object} StreamStats
 * @property {number} widthPx - width of the decoded picture
 * @property {number} heightPx - height of the decoded picture
 * @property {number} framesPerSecond - frames decoded a second
 * @property {number} videoKbitPerS - video bits received a second
 * @property {number} audioKbitPerS - sound bits received a second
 * @property {number} roundTripMs - the connection's round trip, in milliseconds
 * @property {number} jitterBufferMs - mean time a frame waits in the jitter buffer
 * @property {number} decodeMsPerFrame - mean time to decode a frame
 * @property {number} droppedFrames - frames the browser threw away since it started
 */

import { decodeMsPerFrame, jitterBufferMs, rateKbitPerS } from "./metrics.js";

const msPerS = 1000;

/**
 * Reads the WebRTC statistics of one connection and turns them into the
 * numbers the player shows; the reporter measures the same window for the
 * host (`reporter.js`), with the same functions. Rates are worked out from the
 * previous sample, so the first sample reports 0 for them.
 */
export class StatsMeter {
  /**
   * @param {RTCPeerConnection} peerConnection - the connection to the producer
   */
  constructor(peerConnection) {
    this._peerConnection = peerConnection;
    this._previous = null;
    this._previousAtMs = 0;
  }

  /**
   * Takes a sample and returns it.
   * @returns {Promise<StreamStats>}
   */
  async sample() {
    const report = await this._peerConnection.getStats();
    const nowMs = performance.now();
    const elapsedS = this._previousAtMs === 0 ? 0 : (nowMs - this._previousAtMs) / msPerS;
    const current = { video: null, audio: null, pair: null };
    // `mediaType` is what Safari and older browsers call the track's `kind`.
    const kindOf = (entry) => entry.kind ?? entry.mediaType;
    report.forEach((entry) => {
      if (entry.type === "inbound-rtp" && kindOf(entry) === "video") {
        current.video = entry;
      } else if (entry.type === "inbound-rtp" && kindOf(entry) === "audio") {
        current.audio = entry;
      } else if (entry.type === "candidate-pair" && entry.state === "succeeded" && entry.nominated) {
        current.pair = entry;
      }
    });

    const before = this._previous;
    const stats = {
      widthPx: current.video?.frameWidth ?? 0,
      heightPx: current.video?.frameHeight ?? 0,
      framesPerSecond: current.video?.framesPerSecond ?? 0,
      videoKbitPerS: rateKbitPerS(current.video, before?.video, elapsedS) ?? 0,
      audioKbitPerS: rateKbitPerS(current.audio, before?.audio, elapsedS) ?? 0,
      roundTripMs: Math.round((current.pair?.currentRoundTripTime ?? 0) * msPerS),
      jitterBufferMs: jitterBufferMs(current.video, before?.video) ?? 0,
      decodeMsPerFrame: decodeMsPerFrame(current.video, before?.video) ?? 0,
      droppedFrames: current.video?.framesDropped ?? 0,
    };

    this._previous = current;
    this._previousAtMs = nowMs;
    return stats;
  }
}
