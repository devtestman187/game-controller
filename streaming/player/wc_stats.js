/*
 * The custom player's own figures (M15 opt2): what the frames' arrival, decode
 * and draw times say over each reporting interval, plus the counters the
 * player keeps (drops, keyframe requests, the socket's backlog and the
 * decoder's queue). Pure and small: one player's `counters()` and
 * `stageSamples()` in, a reporter batch's gauges and one fact out, the way
 * jb_target.js gives the jitter buffer target's. Nothing runs unless the page
 * plays `player=wc`.
 */

import { medianOf } from "./metrics.js";
import { playerKindOf } from "./options.js";

// The host's fact rules (stream_stats.dart's maxStreamFactLength and
// _technicalPattern): a fact over 24 characters or with a character outside
// the set is dropped, and `=` is outside it, so the pairs are separated by a
// space.
const factLengthLimit = 24;
const factPattern = /^[A-Za-z0-9 ,._()+-]+$/;

// What the fact says when its built text could not fit the host's limits.
const unknownFact = "cfg none dec no";

/** The names every number and the fact are sent under, so a report and a test share one list. */
export const wcNames = {
  recvToDecode: "wcRecvToDecodeMs",
  decodeToDraw: "wcDecodeToDrawMs",
  dropped: "wcDropped",
  backlog: "wcBacklog",
  keyRequests: "wcKeyRequests",
  queueMax: "wcQueueMax",
  fact: "wc",
};

/** The decoder's configuration as one short word from the player's own text. */
function configWord(decodeConfig) {
  const text = String(decodeConfig ?? "none");
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

/** A millisecond figure for the overlay, to a tenth, or `-` with no sample. */
function msText(value) {
  return value === null ? "-" : String(Math.round(value * 10) / 10);
}

/**
 * The custom player's figures (M15 opt2): the stage times of the frames it
 * finished since the last batch, and the counters it keeps. The page makes one
 * with [wcStatsOf] and gives its `batch` to the reporter's extra series.
 */
export class WcStats {
  /**
   * @param {object} parts
   * @param {object} parts.player - the page's WcPlayer: its `counters()` and
   *   `stageSamples()`
   */
  constructor({ player }) {
    this._player = player;
    this._lastFrame = -1;
    this._receiveGapMaxMs = 0;
    this._recvToDecodeMs = null;
    this._decodeToDrawMs = null;
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
   * The gauges and the fact one reporter batch adds. A figure with no sample
   * is left out, never sent as a 0.
   * @returns {{gauges: object[], facts: object[]}}
   */
  batch() {
    const fresh = this._freshSamples();
    const counters = this._player.counters();
    const recvToDecodeMs = medianOf(fresh.map((stage) => stage.decodeOutputAt - stage.receiveAt));
    const decodeToDrawMs = medianOf(fresh.map((stage) => stage.drawnAt - stage.decodeOutputAt));
    // The overlay keeps the last interval that had a finished frame: an empty
    // interval sends no gauge, and the line is not blanked for it.
    if (fresh.length > 0) {
      this._recvToDecodeMs = recvToDecodeMs;
      this._decodeToDrawMs = decodeToDrawMs;
    }
    const gauges = [
      { name: wcNames.recvToDecode, value: recvToDecodeMs },
      { name: wcNames.decodeToDraw, value: decodeToDrawMs },
      { name: wcNames.dropped, value: counters.dropsQueue + counters.dropsGap },
      { name: wcNames.backlog, value: Math.max(0, counters.framesReceived - counters.framesDrawn) },
      { name: wcNames.keyRequests, value: counters.keyRequests },
      { name: wcNames.queueMax, value: counters.queueMax },
    ].filter((gauge) => typeof gauge.value === "number" && Number.isFinite(gauge.value));
    return { gauges, facts: [{ name: wcNames.fact, value: wcFactText(counters) }] };
  }

  /** The overlay's one line, shown only with `player=wc` (M15 opt2). */
  line() {
    const counters = this._player.counters();
    const backlog = Math.max(0, counters.framesReceived - counters.framesDrawn);
    const times = `recv-dec ${msText(this._recvToDecodeMs)} ms dec-draw ${msText(this._decodeToDrawMs)} ms`;
    const frames = `drop ${counters.dropsQueue + counters.dropsGap} backlog ${backlog}`;
    const socket = `age ${Math.round(this._receiveGapMaxMs)} ms keys ${counters.keyRequests} q ${counters.queueMax}`;
    return `wc ${times} ${frames} ${socket} ${wcFactText(counters)}`;
  }

  /** The frames that finished since the last batch: received, decoded and drawn. */
  _freshSamples() {
    const fresh = this._player.stageSamples().filter((stage) =>
      stage.frame > this._lastFrame && stage.decodeOutputAt !== null && stage.drawnAt !== null);
    if (fresh.length > 0) this._lastFrame = Math.max(...fresh.map((stage) => stage.frame));
    return fresh;
  }

  /** The newest arrival's page time, or null before one. */
  _lastReceiveAt() {
    const samples = this._player.stageSamples();
    if (samples.length === 0) return null;
    return Math.max(...samples.map((stage) => stage.receiveAt));
  }
}

/**
 * Several extra-series providers as one, which is what the reporter takes: the
 * jitter buffer target's and the custom player's gauges and facts add up.
 * @param {...(null|(() => ({gauges: object[], facts: object[]})))} providers
 * @returns {() => ({gauges: object[], facts: object[]})}
 */
export function combinedSeries(...providers) {
  return () => {
    const batches = providers.map((provider) => provider?.() ?? { gauges: [], facts: [] });
    return { gauges: batches.flatMap((batch) => batch.gauges), facts: batches.flatMap((batch) => batch.facts) };
  };
}

/**
 * The custom player's figures when the page plays `player=wc`, or null: with
 * any other value none of them is made and no number is sent on (M15 opt2).
 * @param {object|null|undefined} options - the page's options
 * @param {object|null|undefined} player - the page's WcPlayer
 * @returns {WcStats|null}
 */
export function wcStatsOf(options, player) {
  if (playerKindOf(options) !== "wc" || !player) return null;
  return new WcStats({ player });
}
