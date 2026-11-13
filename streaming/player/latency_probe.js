/*
 * The page's latency probe (M15 c2, split out in fix7): it watches the small
 * patch of picture the latency card flips in and times the presses the
 * benchmark sends against the flip that frame carried, so a press has a number
 * that ends on the screen. The reporter keeps the numbers; this keeps the
 * watch. The patch is read out of the picture's one readback, in the same turn
 * as the marker's strip, so the two figures are of the same drawn frame
 * (M15 opt2c-5).
 */

import { sharedReadback } from "./marker_reader.js";
import { FlipWatcher } from "./metrics.js";

/**
 * How long the latency card holds a colour (`LatencyTestCard.flipMs`): it
 * flips on its own clock as well as on a press, so a change a whole cadence or
 * more after the press could be either, and is not counted as the press's.
 */
const cardFlipMs = 500;

/** The brightness the light and dark card are (the look's paper and ink). */
const lightAbove = 120;

/** The brightness below which the card is the dark one. */
const darkBelow = 80;

/** Give up on a press whose flip was not seen in this long. */
const pressTimeoutMs = 2000;

/** The flips kept for a press the poll brings late: about a minute and a half of them. */
const maxFlipSamples = 200;

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
    this._onProblem = onProblem;
    this._toHostMs = toHostMs;
    // The patch is read from the frame the marker's strip is read from, in the
    // same turn, so both figures are of one drawn frame (M15 opt2c-5).
    this._readback = sharedReadback(picture);
    this._readback.watchCard();
    this._watcher = new FlipWatcher({ lightAbove, darkBelow });
    /** The presses still worth timing, and how many the host has sent. */
    this.pressesSeen = 0;
    this.presses = [];
    /** How many flips the page saw, for a run to read afterwards. */
    this.flipsSeen = 0;
    // The flips read, with the host time of the frame that carried each: the
    // press poll is slower than a frame, so a press is usually timed against a
    // flip that was already read when the poll brought it (M15 opt2c-5).
    this._flipsMs = [];
  }

  /**
   * Reads the card's patch of the frame just drawn — [nowMs] is that frame's
   * own page time — and, on a flip, sends the time it was presented on the
   * host's clock so the benchmark can time a press.
   */
  watch(nowMs) {
    this._readFrame(nowMs);
    // A press the poll brought after its own flip was read is timed here.
    this._matchPresses();
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
    // The poll brings a press after its own frame was drawn: it is timed now.
    this._matchPresses();
  }

  /** Reads the patch of the frame just drawn and notes a flip in it. */
  _readFrame(stampMs) {
    const frame = this._readback.read(stampMs);
    if (frame.card === null) {
      if (frame.kind === "canvas") this._onProblem(`cannot watch the picture: ${frame.problem}`);
      return;
    }
    if (this._watcher.observe(frame.card) === null) return;
    const hostMs = this._toHostMs(frame.stampMs);
    if (hostMs === null) return;
    this.flipsSeen++;
    this._flipsMs.push(hostMs);
    if (this._flipsMs.length > maxFlipSamples) this._flipsMs.shift();
    postJson("/flips", { hostMs }).catch(() => {});
  }

  /**
   * Times every waiting press against the first flip at or after it — the
   * same rule the marker reader times presses by, so the card and the marker
   * agree on which drawn frame a press belongs to.
   */
  _matchPresses() {
    for (const press of this.presses) {
      if (press.seen) continue;
      const hostAtFlip = this._flipsMs.find((atMs) => atMs >= press.hostMs);
      // A whole cadence after the press, the change could be the card's own
      // flip rather than the press's: it is dropped, not counted as slow.
      if (hostAtFlip === undefined) continue;
      const sampleMs = Math.round(hostAtFlip - press.hostMs);
      press.seen = true;
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
