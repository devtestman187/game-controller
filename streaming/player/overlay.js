/*
 * The page's own text (M15 fix8): the status line at the bottom, the tab's title
 * (which carries the same line, so a run can read a state off a page it left
 * open) and the numbers box the "i" key opens. The page keeps the connections and
 * reads what it knows for this; this keeps what the page says.
 */

import { StatsMeter } from "./stats.js";

/** How often the numbers are sampled while a stream plays, in milliseconds. */
const sampleIntervalMs = 1000;

/**
 * The page's status line and its numbers. One instance per page: `show()` sets
 * the line, `start()` samples one connection's numbers every second, and
 * `stop()` ends the sampling.
 */
export class Overlay {
  /**
   * @param {object} parts
   * @param {HTMLElement} parts.line - where the status line is shown
   * @param {HTMLElement} parts.box - where the numbers are shown
   * @param {string} parts.switchesLine - the switches this page runs with, or ""
   * @param {() => string} parts.lowDelayLine - the zero-delay option's line, or ""
   * @param {() => string} parts.jbTargetLine - the jitter buffer target option's
   *   line (M15 opt1b), or ""
   * @param {() => string} [parts.wcLine] - the custom player's one line (M15
   *   opt2), or "" with the WebRTC picture
   * @param {() => object} parts.facts - what the page knows: `hasSoundStream`
   *   and `pictureHasAudio`
   * @param {() => object|null} parts.soundMeter - the sound's own connection's
   *   meter, or null when it has no connection
   * @param {(sample: object|null) => void} parts.onSoundSample - what the page
   *   keeps of that sample (the sound's jitter gauge)
   * @param {(text: string) => void} parts.onProblem - where a measurement
   *   problem goes
   */
  constructor({
    line, box, switchesLine, lowDelayLine, jbTargetLine, wcLine = () => "", facts, soundMeter, onSoundSample, onProblem,
  }) {
    this._line = line;
    this._box = box;
    this._switchesLine = switchesLine;
    this._lowDelayLine = lowDelayLine;
    this._jbTargetLine = jbTargetLine;
    this._wcLine = wcLine;
    this._facts = facts;
    this._soundMeter = soundMeter;
    this._onSoundSample = onSoundSample;
    this._onProblem = onProblem;
    // The last measurement problem: watching the picture is what a viewer is
    // here for, so a failed measurement goes in the numbers only, never across
    // the picture (M15 t1: the owner saw it on a phone). An empty text is the
    // reporter saying nothing is wrong any more (M15 g1).
    this._problem = "";
    this._meter = null;
    this._timer = null;
    // The overlay carries the switches from the start, so a look at the page —
    // or a DOM dump of it — shows what it runs with even before a stream arrives.
    if (switchesLine !== "") box.textContent = switchesLine;
  }

  /** Whether the numbers are being sampled. */
  get isSampling() {
    return this._timer !== null;
  }

  /**
   * Makes [button] and the keyboard's "s" and "i" show or hide the numbers, as
   * the page always has: the box is this overlay's, so its switch is too.
   * @param {HTMLButtonElement} button
   */
  wireToggle(button) {
    button.addEventListener("click", (event) => {
      event.preventDefault();
      this._box.classList.toggle("visible");
    });
    window.addEventListener("keydown", (event) => {
      if (event.key === "s" || event.key === "i") this._box.classList.toggle("visible");
    });
  }

  /**
   * Makes [button] start the sound after the tap browsers want first, and ask
   * for full screen with it (the one moment a browser allows full screen). A
   * start the browser still refuses is the overlay's own line to show.
   * @param {HTMLButtonElement} button - the page's "tap to start sound" button
   * @param {() => Promise<void>} unmute - the page's unmute action
   */
  wireSoundButton(button, unmute) {
    button.addEventListener("click", async (event) => {
      event.preventDefault();
      button.classList.remove("visible");
      try {
        await unmute();
      } catch (error) {
        this.show(`cannot start the sound: ${error.message}`);
      }
      document.documentElement.requestFullscreen?.().catch(() => {});
    });
  }

  /**
   * Notes the last measurement problem, shown in the numbers only: an empty
   * text says the measurements are going through again.
   * @param {string} text
   */
  noteProblem(text) {
    this._problem = text;
  }

  /** Shows one status line, in the box at the bottom and in the tab's title. */
  show(text) {
    this._line.textContent = text;
    document.title = text;
  }

  /**
   * Starts sampling one connection's numbers every second. The custom player
   * has no picture connection: null gives it the page's own lines only (M15
   * opt2).
   */
  start(peerConnection) {
    this.stop();
    this._meter = peerConnection === null ? null : new StatsMeter(peerConnection);
    this._timer = window.setInterval(() => this._sample(), sampleIntervalMs);
  }

  /** Ends the sampler; a reconnect starts a new one. */
  stop() {
    if (this._timer !== null) {
      window.clearInterval(this._timer);
      this._timer = null;
    }
    this._meter = null;
  }

  // The sound connection's own numbers, or null. A reconnect replaces the
  // sound's connection under this timer, and a sample of the old one failing is
  // a missing number for that second, never a reason to stop the picture's.
  async _sampleSound() {
    const meter = this._soundMeter();
    if (meter === null) return null;
    try {
      return await meter.sample();
    } catch (error) {
      console.warn(`player: the sound's statistics stopped: ${error.message}`);
      return null;
    }
  }

  // One second of the numbers: the picture's, the sound's when it has its own
  // connection, and the page's own facts round them.
  async _sample() {
    try {
      const soundStats = await this._sampleSound();
      this._showNumbers(this._meter === null ? null : await this._meter.sample(), soundStats);
      this._onSoundSample(soundStats);
    } catch (error) {
      this._onProblem(`statistics stopped: ${error.message}`);
      // The timer stops here, so the next tick that would draw the line never
      // comes: add it once to what the overlay already says (M15 g1).
      this._box.textContent += `\nmeasurement: ${this._problem}`;
      console.warn(`player: statistics stopped: ${error.message}`);
      this.stop();
    }
  }

  // The overlay's sound: the bitrate of the connection it arrives on, or "none"
  // for a session that sends no sound at all (SESSION_AUDIO=off).
  _soundText(stats, soundStats) {
    if (this._facts().hasSoundStream) {
      return soundStats === null ? "sound none" : `sound ${soundStats.audioKbitPerS} kbit/s`;
    }
    return this._facts().pictureHasAudio ? `sound ${stats.audioKbitPerS} kbit/s` : "sound none";
  }

  _showNumbers(stats, soundStats) {
    const lines = [];
    if (stats !== null) {
      const soundJitter = soundStats === null ? "" : `  sound jitter ${soundStats.audioJitterBufferMs} ms`;
      lines.push(
        `picture   ${stats.widthPx}x${stats.heightPx} at ${stats.framesPerSecond.toFixed(0)} fps`,
        `video     ${stats.videoKbitPerS} kbit/s   ${this._soundText(stats, soundStats)}`,
        `round trip ${stats.roundTripMs} ms   jitter buffer ${stats.jitterBufferMs} ms${soundJitter}`,
        `decode    ${stats.decodeMsPerFrame} ms a frame   dropped ${stats.droppedFrames}`,
      );
    }
    const wc = this._wcLine();
    if (wc !== "") lines.push(wc);
    if (this._switchesLine !== "") lines.push(this._switchesLine);
    if (this._lowDelayLine() !== "") lines.push(this._lowDelayLine());
    if (this._jbTargetLine() !== "") lines.push(this._jbTargetLine());
    if (this._problem !== "") lines.push(`measurement: ${this._problem}`);
    this._box.textContent = lines.join("\n");
  }
}
