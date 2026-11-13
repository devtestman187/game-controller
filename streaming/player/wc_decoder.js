/*
 * The custom player's decoder (M15 opt2b-3): the browser's VideoDecoder, the
 * configuration it takes from the stream's SPS and PPS, and what a decoder
 * error costs — one rebuild, gated so a stream the browser cannot decode never
 * loops. Kept apart from the socket in wc_player.js, which hands each
 * keyframe's parameter sets and each sample in and draws what comes out.
 */

import { buildAvcc, codecString, isFourFourFour, parameterSets } from "./wc_annexb.js";
import { frameTimestampUs } from "./wc_counters.js";

/** The shortest gap between two rebuilds, in ms: a failing decoder is tried again, not hammered. */
const rebuildMinMs = 500;

/** How many rebuilds make a burst: from then on the gap grows. */
const rebuildBurst = 5;

/** The window a burst is counted over, in ms: ten seconds of retrying. */
const burstWindowMs = 10000;

/** The gap once the burst is reached, in ms: one rebuild a second, which keeps a picture coming back. */
const rebuildSlowMs = 1000;

/** The longest decoder error text kept for the counters and a report, in characters. */
const errorTextLimit = 60;

/** The characters the host's fact rule allows (wc_stats.js's factPattern): the rest go. */
const outsideFact = /[^A-Za-z0-9 ,._()+-]/g;

/** What the page says while a rebuilt decoder waits for its keyframe. */
const restartText = "decoder error, restarting";

/** What the page says when the stream is 4:4:4 and the browser refuses it. */
const fourFourFourText = "the host sends 4:4:4; Safari cannot decode it";

/**
 * One decoder error as the counters keep it: the error's name first, then its
 * message, with only the characters a report's fact rule allows and cut to
 * [errorTextLimit]. The two are joined by a space because that rule has no
 * colon, and a colon cannot be smuggled back in by a message. A decoder may
 * throw anything, so a missing name or message is no hole in the text.
 * @param {*} error - a DOMException, an Error, or whatever a decoder threw
 * @returns {string}
 */
export function decoderErrorText(error) {
  const name = typeof error?.name === "string" && error.name !== "" ? error.name : "Error";
  const message = typeof error?.message === "string" ? error.message : String(error ?? "");
  const text = `${name} ${message}`.replace(outsideFact, "").replace(/\s+/g, " ").trim();
  return text.slice(0, errorTextLimit);
}

/**
 * The custom player's VideoDecoder and its errors. `configureFor` gives it the
 * stream a keyframe carries, `decode` hands it one sample, and an error —
 * the decoder's own, a `configure` that throws or a static check that rejects —
 * closes it, makes a new one and says so. The new decoder's first sample must
 * be a keyframe, and no rebuild comes sooner than [rebuildMinMs], or
 * [rebuildSlowMs] once five came in ten seconds.
 */
export class WcDecoder {
  /**
   * @param {object} parts
   * @param {Function} parts.decoderClass - the browser's VideoDecoder
   * @param {Function} parts.chunkClass - the browser's EncodedVideoChunk
   * @param {boolean} [parts.annexb] - ask for Annex B in band (`wcmode=annexb`) instead of AVCC
   * @param {() => number} parts.now - the page's clock, in ms
   * @param {(run: () => void, delayMs: number) => number} parts.setTimeoutImpl - the browser's timer
   * @param {(frame: VideoFrame) => void} parts.onFrame - one decoded frame, for the canvas
   * @param {(text: string) => void} [parts.onStatus] - what the page shows the player's viewer
   * @param {() => void} [parts.onNeedsKey] - a keyframe is needed: the player asks the host
   */
  constructor({
    decoderClass, chunkClass, annexb = false, now, setTimeoutImpl, onFrame, onStatus = () => {}, onNeedsKey = () => {},
  }) {
    this._Decoder = decoderClass;
    this._Chunk = chunkClass;
    this._annexb = annexb;
    this._now = now;
    this._setTimeout = setTimeoutImpl;
    this._onFrame = onFrame;
    this._onStatus = onStatus;
    this._onNeedsKey = onNeedsKey;
    this._decoder = null;
    this._stopped = false;
    this._configured = false;
    this._configKey = "";
    // The first sample after a configuration or a rebuild must be a keyframe.
    this._awaitingKey = true;
    this._refused = false;
    this._configText = "none";
    this._errorText = "";
    this._errors = 0;
    this._rebuilds = 0;
    this._rebuildAtMs = [];
    this._lastRebuildAtMs = -Infinity;
    this._rebuildTimer = null;
    this._message = "";
  }

  /** Makes the browser's decoder: once, before the first frame. */
  start() {
    this._decoder = this._make();
  }

  /** Ends the decoder and any rebuild still waiting: nothing is left running. */
  close() {
    this._stopped = true;
    if (this._rebuildTimer !== null) {
      globalThis.clearTimeout(this._rebuildTimer);
      this._rebuildTimer = null;
    }
    this._closeInstance();
  }

  /** How many frames the decoder holds queued: what the player reads as its backlog. */
  get queueSize() {
    return this._decoder === null ? 0 : this._decoder.decodeQueueSize;
  }

  /**
   * Whether this browser refused the stream for good: a 4:4:4 profile. The
   * player then drops every frame without asking the host for another.
   */
  get refused() {
    return this._refused;
  }

  /** The decoder's own numbers, for the player's counters and a run's report. */
  counters() {
    return {
      decoderErrors: this._errors,
      decoderRebuilds: this._rebuilds,
      lastDecoderError: this._errorText,
      decodeConfig: this._configText,
    };
  }

  /**
   * Gives the decoder the stream a keyframe carries, when it has not been given
   * that SPS and PPS yet. False means no sample of this keyframe may be
   * decoded: the page waits for the next one.
   * @param {Uint8Array} payload - one access unit in Annex B
   * @returns {Promise<boolean>}
   */
  async configureFor(payload) {
    if (this._stopped || this._refused) return false;
    if (this._decoder === null) {
      this._onNeedsKey();
      return false;
    }
    const sets = parameterSets(payload);
    if (sets === null && this._configured) return true;
    if (sets === null) {
      this._onNeedsKey();
      return false;
    }
    const key = `${Array.from(sets.sps).join(",")}|${Array.from(sets.pps).join(",")}`;
    if (this._configured && key === this._configKey) return true;
    let config;
    try {
      config = await this._configFor(sets);
    } catch (error) {
      this.failed(error);
      return false;
    }
    if (config === null) return false;
    try {
      this._decoder.configure(config);
    } catch (error) {
      this.failed(error);
      return false;
    }
    this._configured = true;
    this._configKey = key;
    this._awaitingKey = true;
    return true;
  }

  /**
   * Hands the decoder one sample. False means it was not decoded: it was a
   * delta where a keyframe must come first, or the decoder refused it.
   * @param {Uint8Array} data - the sample, in the form the configuration asked for
   * @param {string} type - "key" or "delta"
   * @param {number} frameNo - the stream's frame number, the chunk's timestamp
   * @returns {boolean}
   */
  decode(data, type, frameNo) {
    if (this._decoder === null || this._refused || this._stopped) return false;
    if (this._awaitingKey && type !== "key") return false;
    try {
      this._decoder.decode(new this._Chunk({ type, timestamp: frameNo * frameTimestampUs, data }));
    } catch (error) {
      this.failed(error);
      return false;
    }
    this._awaitingKey = false;
    return true;
  }

  /**
   * One decoder error: the instance goes, a new one takes its place after the
   * gap, and the page is told. Every error is counted, however soon it comes.
   * @param {*} error - what the decoder, `configure` or the static check threw
   */
  failed(error) {
    this._errors++;
    this._errorText = decoderErrorText(error);
    this._closeInstance();
    this._say(restartText);
    this._onNeedsKey();
    this._rebuild();
  }

  /**
   * One frame on the canvas: a message about a decoder that has just worked is
   * stale, and the page clears it.
   * @returns {string} the text to clear, or "" when no message was showing
   */
  noteDrawn() {
    const text = this._message;
    this._message = "";
    return text;
  }

  // The configuration for one SPS and PPS: the study's safe choice first, AVCC
  // with a description and the hardware hint, then the same without the hint.
  // Null is no configuration this browser takes — and for a 4:4:4 profile that
  // refusal is final, because asking for keyframes cannot change it.
  async _configFor(sets) {
    const codec = codecString(sets.sps);
    const wanted = { codec, optimizeForLatency: true, hardwareAcceleration: "prefer-hardware" };
    const plain = { codec, optimizeForLatency: true };
    if (!this._annexb) {
      wanted.description = buildAvcc(sets.sps, sets.pps);
      plain.description = wanted.description;
    }
    if (await this._isSupported(wanted)) {
      this._configText = `${codec} hardware`;
      return wanted;
    }
    if (await this._isSupported(plain)) {
      this._configText = `${codec} no hint`;
      return plain;
    }
    if (isFourFourFour(sets.sps)) {
      this._refused = true;
      this._configText = `444 ${codec}`;
      this._say(fourFourFourText);
      return null;
    }
    this._configText = `unsupported ${codec}`;
    this._onNeedsKey();
    return null;
  }

  // A WebCodecs implementation without the static check (some builds) takes
  // the configuration as it is: a decoder that refuses it says so itself. A
  // check that rejects is an error the rebuild path counts.
  async _isSupported(config) {
    if (typeof this._Decoder.isConfigSupported !== "function") return true;
    const answer = await this._Decoder.isConfigSupported(config);
    return answer !== null && answer.supported === true;
  }

  // One rebuild, no sooner than the gap allows: an error before it only counts,
  // and the page's message stays until a frame comes back.
  _rebuild() {
    if (this._stopped || this._refused || this._rebuildTimer !== null) return;
    const nowMs = this._now();
    const readyAtMs = this._lastRebuildAtMs + this._gapMs(nowMs);
    if (nowMs >= readyAtMs) {
      this._makeAgain();
      return;
    }
    this._rebuildTimer = this._setTimeout(() => {
      this._rebuildTimer = null;
      if (this._stopped || this._refused) return;
      this._makeAgain();
    }, readyAtMs - nowMs);
  }

  _gapMs(nowMs) {
    const inBurst = this._rebuildAtMs.filter((at) => nowMs - at < burstWindowMs).length;
    return inBurst >= rebuildBurst ? rebuildSlowMs : rebuildMinMs;
  }

  _makeAgain() {
    const nowMs = this._now();
    this._decoder = this._make();
    this._configured = false;
    this._configKey = "";
    this._awaitingKey = true;
    this._rebuilds++;
    this._lastRebuildAtMs = nowMs;
    this._rebuildAtMs = [...this._rebuildAtMs.filter((at) => nowMs - at < burstWindowMs), nowMs];
    this._onNeedsKey();
  }

  _make() {
    return new this._Decoder({ output: (frame) => this._onFrame(frame), error: (error) => this.failed(error) });
  }

  _closeInstance() {
    const decoder = this._decoder;
    this._decoder = null;
    this._configured = false;
    this._configKey = "";
    this._awaitingKey = true;
    if (decoder !== null && decoder.state !== "closed") decoder.close();
  }

  // One message on the page, kept until a frame takes it away.
  _say(text) {
    this._message = text;
    this._onStatus(text);
  }
}
