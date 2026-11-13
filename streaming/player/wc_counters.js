/*
 * The custom player's own bookkeeping (M15 opt2): the plain counters it keeps,
 * the stage times of the frames it received, and the canvas its frames are
 * drawn on. Kept apart from the socket and the decoder in wc_player.js, which
 * reads all three.
 */

/** How many frames' stage times are kept for the figures: about four seconds at 60 fps. */
const stageSampleCount = 256;

/** The chunk timestamp one frame number is worth, in microseconds: unique and always rising. */
export const frameTimestampUs = 1000;

/** A gap between two draws longer than this is a freeze, in ms (M15 opt2b-6). */
export const freezeGapMs = 150;

/** The shortest gap between two keyframe requests, in ms: one at a time, 1.5 s apart (M15 opt2c-3). */
const keyRequestMinMs = 1500;

/** How long a keyframe request stays outstanding before another may go, in ms (M15 opt2c-3). */
const keyOutstandingTimeoutMs = 2500;

/**
 * The page's keyframe requests, one at a time (M15 opt2c-3): an ask is
 * outstanding until a keyframe message arrives or 2.5 s pass, and two asks are
 * never closer than 1.5 s. The player asks through `allows()` and tells the
 * rule of every keyframe it receives, so a burst of gaps is one request.
 */
export class KeyRequests {
  /** @param {() => number} now - the page's clock, in ms */
  constructor(now) {
    this._now = now;
    this._lastAskMs = -Infinity;
    this._outstandingSinceMs = null;
  }

  /** True when an ask may go now; it counts as made, starting the spacing and the wait. */
  allows() {
    const nowMs = this._now();
    if (this._outstandingSinceMs !== null && nowMs - this._outstandingSinceMs < keyOutstandingTimeoutMs) {
      return false;
    }
    if (nowMs - this._lastAskMs < keyRequestMinMs) return false;
    this._lastAskMs = nowMs;
    this._outstandingSinceMs = nowMs;
    return true;
  }

  /** A keyframe arrived: the request that asked for it is answered. */
  noteKeyframe() {
    this._outstandingSinceMs = null;
  }
}

/**
 * One socket read's size, in bytes: the payload's own length, or a text
 * message's characters, which is what the tap sends besides frames.
 * @param {ArrayBuffer|ArrayBufferView|string|null|undefined} data
 * @returns {number}
 */
export function bytesOf(data) {
  if (typeof data === "string") return data.length;
  return typeof data?.byteLength === "number" ? data.byteLength : 0;
}

/**
 * The player's own counters at zero: one plain number each, for the overlay and
 * a run's report. The decoder's numbers — its errors, its rebuilds, its last
 * error and the configuration it ran — come from wc_decoder.js and join these.
 * The draw figures (when the player started, its first frame, its freezes and
 * the drawn size) are filled in by noteDrawnAt (M15 opt2b-6).
 */
export function emptyCounters() {
  return {
    framesReceived: 0, framesDecoded: 0, framesDrawn: 0, dropsQueue: 0, dropsGap: 0, keyRequests: 0,
    keyRequestsSuppressed: 0, skippedDraws: 0,
    reconnects: 0, queueMax: 0, lastFrame: -1, bytesReceived: 0,
    freezeCount: 0, freezeMs: 0, firstFrameMs: null, lastDrawnAtMs: null, startedAtMs: null,
    frameWidthPx: 0, frameHeightPx: 0,
  };
}

/**
 * Notes one frame on the canvas: the first draw's time from the player's start
 * (`firstFrameMs`), and each gap between two draws longer than `freezeGapMs` as
 * one freeze with its length in ms. The first frame is never a freeze (M15 opt2b-6).
 * @param {object} counters - the player's counters, as emptyCounters makes them
 * @param {number} drawnAtMs - the page time the frame reached the canvas
 */
export function noteDrawnAt(counters, drawnAtMs) {
  if (counters.firstFrameMs === null && counters.startedAtMs !== null) {
    counters.firstFrameMs = Math.round(drawnAtMs - counters.startedAtMs);
  }
  const previous = counters.lastDrawnAtMs;
  if (previous !== null && drawnAtMs - previous > freezeGapMs) {
    counters.freezeCount++;
    counters.freezeMs += Math.round(drawnAtMs - previous);
  }
  counters.lastDrawnAtMs = drawnAtMs;
}

/**
 * The stage times of the frames that arrived (M15 opt2 job 4): one record each,
 * filled in as the decoder and the canvas report, the oldest dropped past the
 * cap so a long run keeps a fixed amount.
 */
export class FrameStages {
  constructor() {
    this._stages = new Map();
  }

  /**
   * Keeps one frame's arrival time and gives back the record to fill in.
   * @param {number} frameNo
   * @param {number} receivedAtMs - the page time the frame reached the socket
   * @returns {{frame: number, receiveAt: number, decodeOutputAt: number|null, drawnAt: number|null}}
   */
  note(frameNo, receivedAtMs) {
    const stage = { frame: frameNo, receiveAt: receivedAtMs, decodeOutputAt: null, drawnAt: null };
    this._stages.set(frameNo, stage);
    if (this._stages.size > stageSampleCount) this._stages.delete(this._stages.keys().next().value);
    return stage;
  }

  /**
   * The record one frame number keeps.
   * @param {number} frameNo
   * @returns {{frame: number, receiveAt: number, decodeOutputAt: number|null, drawnAt: number|null}|undefined}
   */
  get(frameNo) {
    return this._stages.get(frameNo);
  }

  /** The records in arrival order, as the figures read them. */
  samples() {
    return [...this._stages.values()];
  }
}

/**
 * Where the decoded frames are shown: a canvas sized to each frame, drawn on
 * with the low-latency context. The place a browser's canvas differs most, so
 * it is watched here: a browser that refuses the context option gets the plain
 * one, and a canvas that has neither is a problem the page reports rather than
 * a throw on every frame (M15 opt2b).
 */
export class FrameCanvas {
  /** @param {HTMLCanvasElement} canvas - where the frames are drawn */
  constructor(canvas) {
    this._canvas = canvas;
    this._context = null;
  }

  /**
   * Draws one decoded frame at its own size.
   * @param {VideoFrame} frame
   * @returns {string} why it could not be drawn, or "" when it was
   */
  draw(frame) {
    const widthPx = frame.displayWidth;
    const heightPx = frame.displayHeight;
    if (!(widthPx > 0 && heightPx > 0)) return "the frame has no size";
    if (this._canvas.width !== widthPx || this._canvas.height !== heightPx) {
      this._canvas.width = widthPx;
      this._canvas.height = heightPx;
    }
    const context = (this._context ??= this._openContext());
    if (context === null) return "the page has no 2D canvas";
    context.drawImage(frame, 0, 0, widthPx, heightPx);
    return "";
  }

  // The low-latency hint first, the plain context second: Safari builds that
  // refuse `desynchronized` still draw with the plain one (M15 opt2b).
  _openContext() {
    try {
      return this._canvas.getContext("2d", { desynchronized: true }) ?? this._canvas.getContext("2d");
    } catch (error) {
      console.warn(`player: no low-latency canvas: ${error.message}`);
      return this._canvas.getContext("2d");
    }
  }
}
