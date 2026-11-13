/*
 * The page's marker reader (M15 fix8): it reads the host's marker row out of
 * the picture every frame the reporter already watches, and keeps the frame's
 * age, the raw video-frame metadata and the press flips a probe press makes.
 * Nothing here runs unless the page's options say `marker=1`.
 *
 * The read is one small canvas draw of the strip's middle rows — never the
 * whole picture — and one getImageData for it, so a frame costs the strip and
 * no more. The latencies probe's card patch is read from the same canvas in the
 * same turn (FrameReadback, M15 opt2c-5), so the card and the marker read one
 * drawn frame for one readback. The picture is the video element, or the custom
 * player's canvas with `player=wc` (M15 opt2). A canvas the browser will not
 * let the page read (a tainted one on some Safari builds) is counted, not
 * thrown.
 */

import { decodeMarker, luminanceRows, markerCellCount, markerGapMs } from "./marker_decode.js";
import { metadataFields } from "./marker_batch.js";
import { luminanceOf, medianOf } from "./metrics.js";

/** One cell's side at the reference picture width, in px. */
const referenceCellPx = 16;

/** The picture width the cell size is given at, in px (docs/streaming-marker.md). */
const referenceWidthPx = 1920;

/** The most samples one figure keeps between two batches: a 3 s batch is ~180 frames. */
const maxSamples = 2000;

/** The latency card's patch, as the host draws it: 8 px square, a quarter into the picture. */
export const cardPatchPx = 8;

/** The rows of a cell the decoder reads: the middle ones of its 3x3 centre mean. */
const cellRowsRead = 3;

/** The page's readbacks, one per picture: the card and the marker share the one of their picture. */
const readbacks = new WeakMap();

/** The pair decoded-to-display is read from: the plan minus the frame's arrival. */
const displayFromExpected = "expected-receive";

/** The same when the browser gives no expected display time: the picture's stamp minus arrival. */
const displayFromPresentation = "presentation-receive";

/**
 * The picture a crop is read from, as the three readings the video element
 * gives: the video element itself (the page's usual picture), or the canvas
 * the custom player draws on (`player=wc`, M15 opt2).
 * @param {HTMLVideoElement} video
 * @returns {{image: () => HTMLVideoElement, widthPx: () => number, heightPx: () => number}}
 */
export function videoPicture(video) {
  return { image: () => video, widthPx: () => video.videoWidth, heightPx: () => video.videoHeight };
}

/** The same shape for a canvas the page draws on (M15 opt2). */
export function canvasPicture(canvas) {
  return { image: () => canvas, widthPx: () => canvas.width, heightPx: () => canvas.height };
}

/**
 * The page's one readback for [picture] (M15 opt2c-5): the card and the marker
 * both read the frame the page has just drawn, and share it.
 * @param {{image: () => (HTMLVideoElement|HTMLCanvasElement), widthPx: () => number,
 *   heightPx: () => number}} picture
 * @returns {FrameReadback}
 */
export function sharedReadback(picture) {
  let readback = readbacks.get(picture);
  if (readback === undefined) {
    readback = new FrameReadback(picture);
    readbacks.set(picture, readback);
  }
  return readback;
}

/**
 * One picture's readback: the frame the page has just drawn, read once for
 * every reader that asks for it (M15 opt2c-5). A reader says at its making
 * which part it reads (`watchStrip`, `watchCard`); the first of them to read a
 * frame does the work and the rest share its answer. It also counts what
 * reading costs (the wc batch's `wcReadMeanMs` and `wcReadMaxMs`).
 */
export class FrameReadback {
  /** @param {{image: () => (HTMLVideoElement|HTMLCanvasElement), widthPx: () => number,
   *   heightPx: () => number}} picture */
  constructor(picture) {
    this._picture = picture;
    this._strip = false;
    this._card = false;
    this._canvas = null;
    this._context = null;
    this._rows = [];
    this._frame = null;
    this._reads = 0;
    this._sumMs = 0;
    this._maxMs = 0;
  }

  /** Says a marker reader reads the strip out of this picture. */
  watchStrip() {
    this._strip = true;
  }

  /** Says the card's patch is read out of this picture too. */
  watchCard() {
    this._card = true;
  }

  /**
   * The frame drawn at [stampMs], the draw's own time and the frame's name
   * here: `{stampMs, rows, card, kind, problem, readMs}`, [rows] the strip's
   * luminance rows and [card] the patch's brightness, null for a part the
   * readback was not asked for. The same [stampMs] twice is one read; [kind]
   * and [problem] say why a part could not be read (`crop` for a picture with
   * no size, `canvas` for one the browser will not read).
   * @param {number} stampMs
   */
  read(stampMs) {
    if (this._frame !== null && this._frame.stampMs === stampMs) return this._frame;
    const startedAtMs = performance.now();
    const frame = this._readFrame(stampMs);
    const readMs = performance.now() - startedAtMs;
    frame.readMs = readMs;
    this._reads++;
    this._sumMs += readMs;
    this._maxMs = Math.max(this._maxMs, readMs);
    this._frame = frame;
    return frame;
  }

  /** What reading has cost so far: the reads made, their total and their longest, in ms. */
  totals() {
    return { reads: this._reads, sumMs: this._sumMs, maxMs: this._maxMs };
  }

  /** One frame's regions drawn into the scratch canvas and read back. */
  _readFrame(stampMs) {
    const widthPx = this._picture.widthPx();
    const heightPx = this._picture.heightPx();
    if (!widthPx || !heightPx) return unreadable(stampMs, "crop", "the picture has no size yet");
    // A cell is 16 px at a 1920 px picture, and the row is 57 of them wide.
    const cellPx = Math.max(1, Math.round(referenceCellPx * widthPx / referenceWidthPx));
    const stripWidthPx = cellPx * markerCellCount;
    // The decoder reads a cell's centre 3x3, so three of its rows are drawn and
    // read: 3 of 16 rows at 1080p, and the middle ones, where it looks.
    const firstRowY = Math.max(0, Math.floor(cellPx / 2) - 1);
    const rowsRead = Math.min(cellRowsRead, cellPx);
    const cardRow = this._strip ? rowsRead : 0;
    const canvasWidthPx = this._strip ? stripWidthPx : 1;
    const canvasHeightPx = cardRow + (this._card ? 1 : 0);
    const canvas = (this._canvas ??= document.createElement("canvas"));
    if (canvas.width !== canvasWidthPx || canvas.height !== canvasHeightPx) {
      canvas.width = canvasWidthPx;
      canvas.height = canvasHeightPx;
    }
    const context = (this._context ??= canvas.getContext("2d", { willReadFrequently: true }));
    if (context === null) return unreadable(stampMs, "canvas", "the page has no 2D canvas");
    const image = this._picture.image();
    try {
      // Both regions in one turn, then one getImageData for the two of them.
      if (this._strip) context.drawImage(image, 0, firstRowY, stripWidthPx, rowsRead, 0, 0, stripWidthPx, rowsRead);
      if (this._card) {
        const patchX = Math.floor(widthPx / 4);
        const patchY = Math.floor(heightPx / 4);
        context.drawImage(image, patchX, patchY, cardPatchPx, cardPatchPx, 0, cardRow, 1, 1);
      }
      const pixels = context.getImageData(0, 0, canvasWidthPx, canvasHeightPx).data;
      const cardAt = (cardRow * canvasWidthPx) * 4;
      return {
        stampMs,
        rows: this._strip ? this._stripRows(pixels, stripWidthPx, rowsRead) : null,
        card: this._card ? luminanceOf(pixels[cardAt], pixels[cardAt + 1], pixels[cardAt + 2]) : null,
        kind: "",
        problem: "",
        readMs: 0,
      };
    } catch (error) {
      return unreadable(stampMs, "canvas", `cannot read the picture: ${error.message}`);
    }
  }

  /** The strip's pixels as luminance rows, in the rows kept between frames. */
  _stripRows(pixels, widthPx, heightPx) {
    const fresh = this._rows.length !== heightPx || this._rows[0].length !== widthPx;
    if (fresh) this._rows = Array.from({ length: heightPx }, () => new Float64Array(widthPx));
    return luminanceRows(pixels, widthPx, heightPx, this._rows);
  }
}

/** One frame with nothing in it but the reason. */
function unreadable(stampMs, kind, problem) {
  return { stampMs, rows: null, card: null, kind, problem, readMs: 0 };
}

/**
 * Reads the marker row and times the frames it is in. The reporter creates it
 * with the page's helpers: where a problem goes, how a page time becomes a host
 * time, and the probe's press list.
 */
export class MarkerReader {
  /**
   * @param {object} parts
   * @param {{image: () => (HTMLVideoElement|HTMLCanvasElement), widthPx: () => number,
   *   heightPx: () => number}} parts.picture - the picture the strip is read from
   * @param {(nowMs: number) => (number|null)} parts.toHostMs - page to host time
   * @param {(text: string) => void} parts.onProblem - where an unreadable strip goes
   * @param {() => {hostMs: number}[]} parts.presses - the probe's presses still worth timing
   */
  constructor({ picture, toHostMs, onProblem, presses }) {
    // The strip is read from the picture's one readback, in the same turn the
    // latency probe reads the card's patch from it (M15 opt2c-5).
    this._readback = sharedReadback(picture);
    this._readback.watchStrip();
    this._toHostMs = toHostMs;
    this._onProblem = onProblem;
    this._presses = presses;
    this._lastProblem = "";
    // Totals since the reader started, which the batch sends as counters.
    this._frames = 0;
    this._readable = 0;
    this._reasons = { checksum: 0, sync: 0, level: 0, border: 0, crop: 0, canvas: 0 };
    // One batch's samples, which the batch sends as its medians.
    this._glassMs = [];
    this._decodedDisplayMs = [];
    this._callbackLateMs = [];
    this._readMs = [];
    this._raw = {};
    this._displayFrom = "";
    // The flips seen and the newest press already timed, across batches: a
    // press is polled for up to 2 s after the page reads its flip.
    this._flipMs = [];
    this._timedPressMs = -Infinity;
    this._pressMs = [];
    this._pressFlip = null;
  }

  /**
   * Reads one frame: the strip, the frame's age against its stamp, the frame
   * metadata within [metadata], and the press flip. [callbackMs] is when the
   * callback ran — on Safari the moment the browser called back, not the
   * picture's display time — converted to the host's clock with the offset; it
   * is also the frame's name in the picture's readback, so the card reads the
   * same drawn frame. The animation-frame fallback passes no metadata.
   */
  readFrame(callbackMs, metadata) {
    const reading = this._readStrip(callbackMs);
    this._readMs.push(reading.readMs);
    this._frames++;
    if (!reading.ok) {
      this._reasons[reading.kind] = (this._reasons[reading.kind] ?? 0) + 1;
      this._noteProblem(reading.reason);
      return;
    }
    this._readable++;
    const hostAtMs = this._toHostMs(callbackMs);
    if (hostAtMs !== null) this._glass(hostAtMs, reading.hostMs);
    this._noteFlip(reading.pressFlip, hostAtMs);
    this._noteMetadata(callbackMs, metadata);
  }

  /** The time decoded→display the batch has, in ms, or null when the browser gives none. */
  decodedDisplayMs() {
    return medianOf(this._decodedDisplayMs);
  }

  /**
   * One batch's aggregates: the totals and the samples since the last
   * [clear]. A figure with no sample is an empty list, never a 0.
   */
  summary() {
    this._timePresses();
    return {
      frames: this._frames,
      readable: this._readable,
      reasons: { ...this._reasons },
      glassMs: this._glassMs,
      decodedDisplayMs: this._decodedDisplayMs,
      callbackLateMs: this._callbackLateMs,
      readMs: this._readMs,
      raw: this._raw,
      displayFrom: this._displayFrom,
      pressesMs: this._pressMs,
    };
  }

  /** Forgets the batch's samples; the totals and the timed presses stay. */
  clear() {
    this._glassMs = [];
    this._decodedDisplayMs = [];
    this._callbackLateMs = [];
    this._readMs = [];
    this._raw = {};
    this._pressMs = [];
  }

  /** Records one frame's age: the callback's host time minus the row's stamp. */
  _glass(hostAtMs, markerHostMs) {
    if (this._glassMs.length >= maxSamples) return;
    this._glassMs.push(markerGapMs(hostAtMs, markerHostMs));
  }

  /**
   * Notes a press flip. The flip cell changes on the frame a probe press was
   * applied in and on nothing else — the card's own 500 ms cadence does not
   * touch it — so every change is one press's; the first reading only says
   * which colour is showing.
   */
  _noteFlip(pressFlip, hostAtMs) {
    if (this._pressFlip === null) {
      this._pressFlip = pressFlip;
      return;
    }
    if (pressFlip === this._pressFlip || hostAtMs === null) return;
    this._pressFlip = pressFlip;
    this._flipMs.push(hostAtMs);
    if (this._flipMs.length > maxSamples) this._flipMs.shift();
  }

  /**
   * Times the presses whose flip the page has read: the host time of the first
   * callback that read the changed cell, minus the press's own host time. A
   * press whose flip has not been read yet waits for the next batch.
   */
  _timePresses() {
    const waiting = this._presses()
      .filter((press) => press.hostMs > this._timedPressMs)
      .sort((a, b) => a.hostMs - b.hostMs);
    for (const press of waiting) {
      const flipAtMs = this._flipMs.find((atMs) => atMs >= press.hostMs);
      if (flipAtMs === undefined) break;
      this._pressMs.push(Math.round(flipAtMs - press.hostMs));
      this._timedPressMs = press.hostMs;
    }
  }

  /** Records the metadata's own figures: the two derived ones and every raw field. */
  _noteMetadata(callbackMs, metadata) {
    if (metadata === null || metadata === undefined) return;
    const expected = metadata.expectedDisplayTime;
    if (typeof expected === "number") this._keep(this._callbackLateMs, callbackMs - expected);
    const plan = typeof expected === "number" ? expected : metadata.presentationTime;
    const received = metadata.receiveTime;
    if (typeof plan === "number" && typeof received === "number") {
      this._displayFrom = typeof expected === "number" ? displayFromExpected : displayFromPresentation;
      this._keep(this._decodedDisplayMs, Math.max(0, plan - received));
    }
    for (const field of metadataFields) {
      const value = metadata[field];
      if (typeof value !== "number" || !Number.isFinite(value)) continue;
      const samples = (this._raw[field] ??= []);
      if (samples.length < maxSamples) samples.push(value);
    }
  }

  /** One sample into [samples], up to the cap. */
  _keep(samples, value) {
    if (samples.length < maxSamples) samples.push(value);
  }

  /** The strip's crop of the picture, decoded: the row or why it could not be read. */
  _readStrip(stampMs) {
    const frame = this._readback.read(stampMs);
    if (frame.rows === null) return { ok: false, kind: frame.kind, reason: frame.problem, readMs: frame.readMs };
    const startedAtMs = performance.now();
    const reading = decodeMarker(frame.rows);
    return { ...reading, readMs: frame.readMs + (performance.now() - startedAtMs) };
  }

  /** Notes an unreadable strip where the viewer is not looking, once per text. */
  _noteProblem(text) {
    if (text === this._lastProblem) return;
    this._lastProblem = text;
    this._onProblem(text);
  }
}
