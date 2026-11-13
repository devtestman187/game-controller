/*
 * The custom player's own figures (M15 opt2): what the frames' arrival, decode
 * and draw times say over each reporting interval, plus the counters the
 * player keeps (drops, keyframe requests, the socket's backlog, the decoder's
 * queue, and its errors and rebuilds with the last error's text, M15 opt2b-3),
 * and where the page itself backed up (its socket's gaps, the decoder's queue
 * and its own thread's lag, from wc_diag.js: M15 opt2c-1).
 * Its counters also go as a plain `inbound-rtp` video entry (M15 opt2b-6), which
 * is what fills the host's "Streaming quality" row without a peer connection.
 * Pure and small: one player's `counters()` and `stageSamples()` in, a
 * reporter batch's gauges, facts and video entry out, the way jb_target.js
 * gives the jitter buffer target's. Nothing runs unless the page plays `player=wc`.
 */

import { medianOf } from "./metrics.js";
import { playerKindOf } from "./options.js";
import { wcSoundFactText, wcSoundStates } from "./wc_sound.js";

// The host's fact rules (stream_stats.dart's maxStreamFactLength and
// _technicalPattern): a fact over 24 characters or with a character outside
// the set is dropped, and `=` is outside it, so the pairs are separated by a
// space.
const factLengthLimit = 24;
const factPattern = /^[A-Za-z0-9 ,._()+-]+$/;

// What the fact says when its built text could not fit the host's limits.
const unknownFact = "cfg none dec no";

const bitsPerKbit = 1000;
const msPerS = 1000;

/**
 * The host's own names for the number and the two stages the custom player
 * fills without a picture connection (M15 opt2b): a bench reads a viewer from
 * them, so they are sent from the frames and the socket alone, never from the
 * marker, which a browser may fail to read.
 */
export const wcHostNames = {
  bitrate: "bitrateReceivedKbps",
  decode: "stream_decode",
  display: "stream_display",
};

/** The names every number and the fact are sent under, so a report and a test share one list. */
export const wcNames = {
  recvToDecode: "wcRecvToDecodeMs",
  decodeToDraw: "wcDecodeToDrawMs",
  dropped: "wcDropped",
  backlog: "wcBacklog",
  keyRequests: "wcKeyRequests",
  queueMax: "wcQueueMax",
  decoderErrors: "wcDecoderErrors",
  decoderRebuilds: "wcDecoderRebuilds",
  soundPlaying: "wcSoundPlaying",
  // Where the page itself backed up (M15 opt2c-1, wc_diag.js): its socket's
  // gaps and bytes, the decoder's queue and its own thread.
  gapMax: "wcGapMaxMs",
  gaps100: "wcGaps100",
  gaps250: "wcGaps250",
  recvBytes: "wcRecvBytes",
  keyBytesMax: "wcKeyBytesMax",
  keyBytesAvg: "wcKeyBytesAvg",
  deltaBytesAvg: "wcDeltaBytesAvg",
  decQueueMax: "wcDecQueueMax",
  lagMax: "wcLagMaxMs",
  lag50: "wcLag50",
  longTasks: "wcLongTasks",
  handlerMax: "wcHandlerMaxMs",
  bytesPerSecMax: "wcBytesPerSecMax",
  fact: "wc",
  errorFact: "wcerr",
  soundFact: "wcsnd",
};

/** The decoder's configuration as one short word from the player's own text. */
function configWord(decodeConfig) {
  const text = String(decodeConfig ?? "none");
  if (text.startsWith("444 ")) return "444";
  if (text.endsWith(" hardware")) return "hw";
  if (text.endsWith(" no hint")) return "nohint";
  return text.startsWith("unsupported") ? "bad" : "none";
}

/**
 * The fact one batch sends, inside the host's limits: `cfg hw dec ok` — which
 * decoder configuration the page got (`hw`, `nohint`, `bad`, or `none` when no
 * keyframe came), and whether it drew a frame. It claims nothing more than the
 * player's configuration text says (M15 opt2).
 * @param {object} counters - the player's `counters()`
 * @param {number} [limit] - the host's longest fact, in characters
 * @returns {string}
 */
export function wcFactText(counters, limit = factLengthLimit) {
  const config = configWord(counters.decodeConfig);
  const drawn = counters.framesDrawn > 0 ? "ok" : "no";
  const text = `cfg ${config} dec ${drawn}`;
  return text.length <= limit && factPattern.test(text) ? text : unknownFact;
}

/**
 * The decoder's last error as its own fact, inside the host's limits: the error
 * name first, cut at [factLengthLimit] (`EncodingError Cannot dec`), because the
 * name says more than a message's first words. Empty before the first error and
 * for a text the host would drop: the host keeps the last fact it was sent, so
 * a page with no error says nothing (M15 opt2b-3).
 * @param {string} lastDecoderError - the player's own error text (wc_decoder.js)
 * @param {number} [limit] - the host's longest fact, in characters
 * @returns {string}
 */
export function wcErrorFactText(lastDecoderError, limit = factLengthLimit) {
  const text = String(lastDecoderError ?? "").slice(0, limit);
  return factPattern.test(text) ? text : "";
}

/**
 * Where the page itself backed up, as the gauges a run reads (M15 opt2c-1):
 * the socket's gaps and bytes, the decoder's queue and the page's own thread,
 * each a running figure so its gauge's max is the run's worst.
 * @param {object} diag - the player's `diagSnapshot()`
 * @returns {object[]}
 */
function diagGauges(diag) {
  return [
    { name: wcNames.gapMax, value: diag.gapMaxMs },
    { name: wcNames.gaps100, value: diag.gapsOver100 },
    { name: wcNames.gaps250, value: diag.gapsOver250 },
    { name: wcNames.recvBytes, value: diag.recvBytes },
    { name: wcNames.keyBytesMax, value: diag.keyBytesMax },
    { name: wcNames.keyBytesAvg, value: diag.keyBytesAvg },
    { name: wcNames.deltaBytesAvg, value: diag.deltaBytesAvg },
    { name: wcNames.decQueueMax, value: diag.decQueueMax },
    { name: wcNames.lagMax, value: diag.mainLagMaxMs },
    { name: wcNames.lag50, value: diag.mainLagOver50 },
    { name: wcNames.longTasks, value: diag.longTasks },
    { name: wcNames.handlerMax, value: diag.msgHandlerMaxMs },
    { name: wcNames.bytesPerSecMax, value: diag.bytesPerSecMax },
  ];
}

/** A millisecond figure for the overlay, to a tenth, or `-` with no sample. */
function msText(value) {
  return value === null ? "-" : String(Math.round(value * 10) / 10);
}

/** The mean of [values], or null when there is none. */
function meanOf(values) {
  return values.length === 0 ? null : values.reduce((sum, value) => sum + value, 0) / values.length;
}

/**
 * The custom player's figures (M15 opt2): the stage times of the frames it
 * finished since the last batch, the counters it keeps and, when the page
 * measures them, its own diagnostics (M15 opt2c-1). The page makes one with
 * [wcStatsOf] and gives its `batch` to the reporter's extra series.
 */
export class WcStats {
  /**
   * @param {object} parts
   * @param {object} parts.player - the page's WcPlayer: its `counters()` and
   *   `stageSamples()`
   * @param {() => number} [parts.now] - the page's clock, in ms: the interval
   *   the socket's rate is measured over
   * @param {() => string} [parts.soundState] - the page's wc sound state (M15
   *   opt2b-4), or null for a page whose sound is not measured
   * @param {(() => object)|null} [parts.diag] - the page's own diagnostics
   *   (M15 opt2c-1), or null for a page that measures none
   */
  constructor({ player, now = () => performance.now(), soundState = null, diag = null }) {
    this._player = player;
    this._now = now;
    this._soundState = soundState;
    this._diag = diag;
    this._lastFrame = -1;
    this._receiveGapMaxMs = 0;
    this._recvToDecodeMs = null;
    this._decodeToDrawMs = null;
    // The socket's bytes and the frames on the canvas at the last batch, and
    // when it was: the interval starts with the player, so even the first batch
    // carries a rate and a frame rate (M15 opt2b).
    this._bytesBefore = 0;
    this._drawnBefore = 0;
    this._batchAtMs = now();
  }

  /**
   * One frame on the canvas: how old the newest frame the socket had was when
   * it was drawn, kept as the interval's largest. That is the backlog in time,
   * where the gauge counts it in frames.
   * @param {number} drawnAtMs - the page time the frame reached the canvas
   */
  noteDrawn(drawnAtMs) {
    const lastReceiveAtMs = this._lastReceiveAt();
    if (lastReceiveAtMs === null) return;
    this._receiveGapMaxMs = Math.max(this._receiveGapMaxMs, drawnAtMs - lastReceiveAtMs);
  }

  /**
   * The stages, gauges, facts and the video entry one reporter batch adds. A
   * figure with no sample is left out, never sent as a 0.
   * @returns {{stages: object[], gauges: object[], facts: object[], video: object|null}}
   */
  batch() {
    const elapsedMs = this._intervalMs();
    const fresh = this._freshSamples();
    const counters = this._player.counters();
    // The frames on the canvas over the interval's seconds, to a tenth: the
    // picture this page actually showed (M15 opt2b-6).
    const drawn = counters.framesDrawn - this._drawnBefore;
    this._drawnBefore = counters.framesDrawn;
    const deliveredFps = elapsedMs > 0 && drawn > 0 ? Math.round(drawn * msPerS * 10 / elapsedMs) / 10 : null;
    const recvToDecodeMs = medianOf(fresh.map((stage) => stage.decodeOutputAt - stage.receiveAt));
    const decodeToDrawMs = medianOf(fresh.map((stage) => stage.drawnAt - stage.decodeOutputAt));
    // The overlay keeps the last interval that had a finished frame: an empty
    // interval sends no gauge, and the line is not blanked for it.
    if (fresh.length > 0) {
      this._recvToDecodeMs = recvToDecodeMs;
      this._decodeToDrawMs = decodeToDrawMs;
    }
    const decodeMs = Math.round(meanOf(fresh.map((stage) => stage.decodeOutputAt - stage.receiveAt)));
    const stages = fresh.length === 0 ? [] : [
      { name: wcHostNames.decode, ms: decodeMs },
      { name: wcHostNames.display, ms: Math.round(decodeToDrawMs) },
    ];
    const gauges = [
      { name: wcHostNames.bitrate, value: this._rateKbitPerS(counters, elapsedMs) },
      { name: wcNames.recvToDecode, value: recvToDecodeMs },
      { name: wcNames.decodeToDraw, value: decodeToDrawMs },
      { name: wcNames.dropped, value: counters.dropsQueue + counters.dropsGap },
      { name: wcNames.backlog, value: Math.max(0, counters.framesReceived - counters.framesDrawn) },
      { name: wcNames.keyRequests, value: counters.keyRequests },
      { name: wcNames.queueMax, value: counters.queueMax },
      { name: wcNames.decoderErrors, value: counters.decoderErrors },
      { name: wcNames.decoderRebuilds, value: counters.decoderRebuilds },
    ];
    // The page's own side of a stall (M15 opt2c-1), when it measures one.
    if (this._diag !== null) gauges.push(...diagGauges(this._diag()));
    const facts = [{ name: wcNames.fact, value: wcFactText(counters) }];
    const errorText = wcErrorFactText(counters.lastDecoderError);
    if (errorText !== "") facts.push({ name: wcNames.errorFact, value: errorText });
    // The sound's own state (M15 opt2b-4): a gauge a run summarises, and the
    // word a person reads. A page that measures no sound sends neither.
    if (this._soundState !== null) {
      const state = this._soundState();
      gauges.push({ name: wcNames.soundPlaying, value: state === wcSoundStates.playing ? 1 : 0 });
      facts.push({ name: wcNames.soundFact, value: wcSoundFactText(state) });
    }
    const numbers = gauges.filter((gauge) => typeof gauge.value === "number" && Number.isFinite(gauge.value));
    return { stages, gauges: numbers, facts, video: wcVideoEntry(counters, deliveredFps) };
  }

  /** The overlay's one line, shown only with `player=wc` (M15 opt2). */
  line() {
    const counters = this._player.counters();
    const backlog = Math.max(0, counters.framesReceived - counters.framesDrawn);
    const times = `recv-dec ${msText(this._recvToDecodeMs)} ms dec-draw ${msText(this._decodeToDrawMs)} ms`;
    const frames = `drop ${counters.dropsQueue + counters.dropsGap} backlog ${backlog}`;
    const socket = `age ${Math.round(this._receiveGapMaxMs)} ms keys ${counters.keyRequests} q ${counters.queueMax}`;
    const sound = this._soundState === null ? "" : ` snd ${wcSoundFactText(this._soundState())}`;
    return `wc ${times} ${frames} ${socket}${sound} ${wcFactText(counters)}`;
  }

  /** The frames that finished since the last batch: received, decoded and drawn. */
  _freshSamples() {
    const fresh = this._player.stageSamples().filter((stage) =>
      stage.frame > this._lastFrame && stage.decodeOutputAt !== null && stage.drawnAt !== null);
    if (fresh.length > 0) this._lastFrame = Math.max(...fresh.map((stage) => stage.frame));
    return fresh;
  }

  /** The time since the last batch in ms, which this batch's figures are over; starts the next one. */
  _intervalMs() {
    const nowMs = this._now();
    const elapsedMs = nowMs - this._batchAtMs;
    this._batchAtMs = nowMs;
    return elapsedMs;
  }

  /**
   * The bits a second the tap socket took over [elapsedMs], in kbit/s: the
   * gauge the host counts a viewer by, from the bytes the player counted. Null
   * until something arrived, so an idle socket never reads as a viewer.
   */
  _rateKbitPerS(counters, elapsedMs) {
    const bytes = counters.bytesReceived;
    const before = this._bytesBefore;
    this._bytesBefore = bytes;
    const fresh = bytes - before;
    if (!(elapsedMs > 0) || !(fresh > 0)) return null;
    return Math.round((fresh * 8) / (bitsPerKbit * elapsedMs / msPerS));
  }

  /** The newest arrival's page time, or null before one. */
  _lastReceiveAt() {
    const samples = this._player.stageSamples();
    if (samples.length === 0) return null;
    return Math.max(...samples.map((stage) => stage.receiveAt));
  }
}

/**
 * The player's counters as the `inbound-rtp` video entry the host's own names
 * come from (M15 opt2b-6): one plain object with the fields a WebRTC track
 * gives, so the reporter's viewerCounters fills framesReceived, framesDecoded,
 * framesDropped, freezes, freezeMs and firstFrameMs, and deliveredFps and the
 * resolution fact come with them. Null until a frame arrived: a page that got
 * no picture sends no counters, not zeros.
 * @param {object} counters - the player's counters()
 * @param {number|null} framesPerSecond - the frames drawn over the interval, one decimal
 * @returns {object|null}
 */
export function wcVideoEntry(counters, framesPerSecond) {
  if (!(counters.framesReceived > 0)) return null;
  return {
    framesReceived: counters.framesReceived,
    framesDecoded: counters.framesDecoded,
    framesPerSecond,
    freezeCount: counters.freezeCount,
    totalFreezesDuration: counters.freezeMs / msPerS,
    frameWidth: counters.frameWidthPx,
    frameHeight: counters.frameHeightPx,
    firstFrameMs: counters.firstFrameMs,
  };
}

/**
 * Several extra-series providers as one, which is what the reporter takes: the
 * jitter buffer target's and the custom player's stages, gauges and facts add
 * up, and the first video entry one of them has is the batch's. A provider
 * without stages (the jitter buffer target's) adds none.
 * @param {...(null|(() => ({stages?: object[], gauges: object[], facts: object[], video?: object|null})))} providers
 * @returns {() => ({stages: object[], gauges: object[], facts: object[], video: object|null})}
 */
export function combinedSeries(...providers) {
  return () => {
    const batches = providers.map((provider) => provider?.() ?? {});
    return {
      stages: batches.flatMap((batch) => batch.stages ?? []),
      gauges: batches.flatMap((batch) => batch.gauges ?? []),
      facts: batches.flatMap((batch) => batch.facts ?? []),
      video: batches.find((batch) => batch.video)?.video ?? null,
    };
  };
}

/**
 * The custom player's figures when the page plays `player=wc`, or null: with
 * any other value none of them is made and no number is sent on (M15 opt2).
 * @param {object|null|undefined} options - the page's options
 * @param {object|null|undefined} player - the page's WcPlayer
 * @param {(() => string)|null} [soundState] - the page's wc sound state (M15 opt2b-4)
 * @returns {WcStats|null}
 */
export function wcStatsOf(options, player, soundState = null) {
  if (playerKindOf(options) !== "wc" || !player) return null;
  return new WcStats({ player, soundState, diag: () => player.diagSnapshot() });
}
