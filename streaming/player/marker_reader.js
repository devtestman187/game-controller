/*
 * The page's marker reader (M15 fix8): it reads the host's marker row out of
 * the picture every frame the reporter already watches, and keeps the frame's
 * age, the raw video-frame metadata and the press flips a probe press makes.
 * Nothing here runs unless the page's options say `marker=1`.
 *
 * The read is one small canvas draw of the strip's own region of the picture —
 * never the whole picture — and one getImageData for it, so a frame costs the
 * strip and no more. The picture is the video element, or the custom player's
 * canvas with `player=wc` (M15 opt2). A canvas the browser will not let the
 * page read (a tainted one on some Safari builds) is counted, not thrown.
 */

import { decodeMarker, markerCellCount, markerGapMs } from "./marker_decode.js";
import { luminanceOf, medianOf } from "./metrics.js";

/** One cell's side at the reference picture width, in px. */
const referenceCellPx = 16;

/** The picture width the cell size is given at, in px (docs/streaming-marker.md). */
const referenceWidthPx = 1920;

/** The most samples one figure keeps between two batches: a 3 s batch is ~180 frames. */
const maxSamples = 2000;

/**
 * Every requestVideoFrameCallback metadata field the page records, raw, by the
 * name the browser gives it. A field this browser does not fill in is recorded
 * as missing — the batch then has no fact for it — never as a 0. They are the
 * browser's whole statement about a frame's timing, and only the phone's Safari
 * says which of them it fills in.
 */
export const metadataFields = [
  "presentationTime",
  "expectedDisplayTime",
  "captureTime",
  "receiveTime",
  "processingDuration",
  "presentedFrames",
  "width",
  "height",
  "mediaTime",
  "rtpTimestamp",
];

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
    this._picture = picture;
    this._toHostMs = toHostMs;
    this._onProblem = onProblem;
    this._presses = presses;
    this._canvas = null;
    this._context = null;
    this._rows = [];
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
   * picture's display time — converted to the host's clock with the offset.
   * The animation-frame fallback passes no metadata.
   */
  readFrame(callbackMs, metadata) {
    const startedAtMs = performance.now();
    const reading = this._readStrip();
    this._readMs.push(performance.now() - startedAtMs);
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
  _readStrip() {
    const widthPx = this._picture.widthPx();
    const heightPx = this._picture.heightPx();
    if (!widthPx || !heightPx) return { ok: false, kind: "crop", reason: "the picture has no size yet" };
    // A cell is 16 px at a 1920 px picture, and the row is 57 of them wide and
    // one tall: the crop is the strip, never the whole picture.
    const cellPx = Math.max(1, Math.round(referenceCellPx * widthPx / referenceWidthPx));
    const stripWidthPx = cellPx * markerCellCount;
    const canvas = (this._canvas ??= document.createElement("canvas"));
    if (canvas.width !== stripWidthPx || canvas.height !== cellPx) {
      canvas.width = stripWidthPx;
      canvas.height = cellPx;
    }
    const context = (this._context ??= canvas.getContext("2d", { willReadFrequently: true }));
    if (context === null) return { ok: false, kind: "canvas", reason: "the page has no 2D canvas" };
    try {
      context.drawImage(this._picture.image(), 0, 0, stripWidthPx, cellPx, 0, 0, stripWidthPx, cellPx);
      const pixels = context.getImageData(0, 0, stripWidthPx, cellPx).data;
      return decodeMarker(this._luminances(pixels, stripWidthPx, cellPx));
    } catch (error) {
      return { ok: false, kind: "canvas", reason: `cannot read the picture: ${error.message}` };
    }
  }

  /**
   * The pixels as rows of luminance, 0–255. The rows are kept between frames
   * and refilled: a read every frame must not make garbage.
   */
  _luminances(pixels, widthPx, heightPx) {
    const fresh = this._rows.length !== heightPx || this._rows[0].length !== widthPx;
    if (fresh) this._rows = Array.from({ length: heightPx }, () => new Float64Array(widthPx));
    for (let y = 0; y < heightPx; y++) {
      const row = this._rows[y];
      for (let x = 0; x < widthPx; x++) {
        const at = (y * widthPx + x) * 4;
        row[x] = luminanceOf(pixels[at], pixels[at + 1], pixels[at + 2]);
      }
    }
    return this._rows;
  }

  /** Notes an unreadable strip where the viewer is not looking, once per text. */
  _noteProblem(text) {
    if (text === this._lastProblem) return;
    this._lastProblem = text;
    this._onProblem(text);
  }
}
