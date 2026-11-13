/*
 * The page's latency probe (M15 c2, split out in fix7): it watches the small
 * patch of picture the latency card flips in and times the presses the
 * benchmark sends against the flip it sees, so a press has a number that ends
 * on the screen. The reporter keeps the numbers; this keeps the watch.
 */

import { FlipWatcher, luminanceOf } from "./metrics.js";

/**
 * How long the latency card holds a colour (`LatencyTestCard.flipMs`): it
 * flips on its own clock as well as on a press, so a change a whole cadence or
 * more after the press could be either, and is not counted as the press's.
 */
const cardFlipMs = 500;

/** Pixels the flip is watched at, in the picture's own coordinates. */
const patchSizePx = 8;

/** The brightness the light and dark card are (the look's paper and ink). */
const lightAbove = 120;

/** The brightness below which the card is the dark one. */
const darkBelow = 80;

/** Sample the patch every frame while a press waits, and less often after. */
const patchEveryNthFrame = 8;

/** Give up on a press whose flip was not seen in this long. */
const pressTimeoutMs = 2000;

/**
 * Watches for the card's flips and times the presses waiting for one. The
 * reporter creates it with the connection's own helpers: where a problem goes,
 * and how a page time becomes a host time.
 */
export class LatencyProbe {
  /**
   * @param {object} parts
   * @param {{image: () => (HTMLVideoElement|HTMLCanvasElement), widthPx: () => number,
   *   heightPx: () => number}} parts.picture - the picture the card is watched in:
   *   the video element, or the custom player's canvas (M15 opt2)
   * @param {(text: string) => void} parts.onProblem - where a problem goes
   * @param {(nowMs: number) => (number|null)} parts.toHostMs - page to host time
   */
  constructor({ picture, onProblem, toHostMs }) {
    this._picture = picture;
    this._onProblem = onProblem;
    this._toHostMs = toHostMs;
    this._canvas = null;
    this._watcher = new FlipWatcher({ lightAbove, darkBelow });
    /** The presses still worth timing, and how many the host has sent. */
    this.pressesSeen = 0;
    this.presses = [];
    /** How many flips the page saw, for a run to read afterwards. */
    this.flipsSeen = 0;
  }

  /**
   * Reads the patch and, on a flip, sends the time it was presented on the
   * host's clock so the benchmark can time a press. [frames] is how many the
   * page has shown: with no press waiting, the patch is read now and then.
   */
  watch(nowMs, frames) {
    const waiting = this.presses.some((press) => !press.seen && !press.expired);
    if (!waiting && frames % patchEveryNthFrame !== 0) return;
    const luminance = this._patchLuminance();
    if (luminance === null) return;
    const flip = this._watcher.observe(luminance);
    if (flip === null) return;
    this._noteFlip(nowMs);
    this._matchPresses(nowMs);
  }

  /** Forgets the presses already sent, which the reporter calls after a batch. */
  forgetSent() {
    this.presses = this.presses.filter((press) => !press.sent);
  }

  /** Asks for the presses the benchmark sent, and forgets the ones timed out. */
  async poll() {
    try {
      const response = await fetch(`/presses?since=${this.pressesSeen}`);
      if (!response.ok) return;
      const body = await response.json();
      for (const press of body.presses ?? []) {
        this.pressesSeen = press.id;
        this.presses.push({ hostMs: press.hostMs, receivedAtMs: performance.now(), seen: false, expired: false });
      }
    } catch (error) {
      this._onProblem(`cannot read the press probe: ${error.message}`);
    }
    const deadline = performance.now() - pressTimeoutMs;
    this.presses = this.presses.filter((press) => {
      if (press.sent || press.expired) return false;
      return press.seen || press.receivedAtMs >= deadline;
    });
  }

  /** The mean brightness of a small patch of the picture, or null. */
  _patchLuminance() {
    const width = this._picture.widthPx();
    const height = this._picture.heightPx();
    if (!width || !height) return null;
    this._canvas ??= document.createElement("canvas");
    const canvas = this._canvas;
    canvas.width = 1;
    canvas.height = 1;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context) return null;
    // A quarter in, where the card's block has no text over it.
    const x = Math.floor(width / 4);
    const y = Math.floor(height / 4);
    try {
      context.drawImage(this._picture.image(), x, y, patchSizePx, patchSizePx, 0, 0, 1, 1);
      const pixel = context.getImageData(0, 0, 1, 1).data;
      return luminanceOf(pixel[0], pixel[1], pixel[2]);
    } catch (error) {
      this._onProblem(`cannot watch the picture: ${error.message}`);
      return null;
    }
  }

  /** Sends one flip's host time so the benchmark can time its presses. */
  _noteFlip(nowMs) {
    const hostMs = this._toHostMs(nowMs);
    if (hostMs === null) return;
    this.flipsSeen++;
    postJson("/flips", { hostMs }).catch(() => {});
  }

  /** Times every waiting press against the first flip after it. */
  _matchPresses(nowMs) {
    const hostAtFlip = this._toHostMs(nowMs);
    if (hostAtFlip === null) return;
    for (const press of this.presses) {
      if (press.seen) continue;
      // A press whose flip came before the card could show it belongs to the
      // card's own 500 ms cadence, not to the press.
      if (hostAtFlip < press.hostMs) continue;
      const sampleMs = Math.round(hostAtFlip - press.hostMs);
      press.seen = true;
      // A whole cadence after the press, the change could be the card's own
      // flip rather than the press's: it is dropped, not counted as slow.
      if (sampleMs >= cardFlipMs) {
        press.expired = true;
        continue;
      }
      press.sampleMs = sampleMs;
    }
    // A timed press stays in the list until the next batch has sent it: the
    // poll is what forgets the ones that timed out or were ambiguous.
  }
}

/** One JSON POST to the session's own web server. */
async function postJson(path, body) {
  await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}
