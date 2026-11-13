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
 */
export function emptyCounters() {
  return {
    framesReceived: 0, framesDecoded: 0, framesDrawn: 0, dropsQueue: 0, dropsGap: 0, keyRequests: 0,
    reconnects: 0, queueMax: 0, lastFrame: -1, bytesReceived: 0,
  };
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
