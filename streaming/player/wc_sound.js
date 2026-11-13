/*
 * The custom player's sound (M15 opt2b-4): with `player=wc` the picture is the
 * page's own canvas, and the sound-only WebRTC stream is the only media the page
 * plays, on the audio element by itself. A browser starts no sound without a tap
 * on the page, so a play() it refuses leaves the sound waiting for one: a tap
 * anywhere starts it inside that gesture, and a stream that reconnects asks for
 * another tap only when the browser wants one.
 */

// The three states the page reports: no sound stream, a tap needed, playing.
export const wcSoundStates = { none: "none", blocked: "blocked", playing: "playing" };

// What the page says while the sound waits for its tap: the same words the
// WebRTC picture's own path shows, so a viewer reads one line either way.
const tapStatus = "tap the screen to start the sound";

// The events a browser counts as the gesture that may start a sound: a mouse or
// a finger going down, and the end of a touch for the browsers that credit only
// that one. The whole page is the target, so the canvas and the button both work.
const gestureEvents = ["pointerdown", "touchend"];

/**
 * The sound's state as the one short word the report's fact carries (M15
 * opt2b-4): `none`, `blocked` or `playing`, and `none` for anything else, since
 * a state the report cannot name is better said as no sound at all.
 * @param {string} state - one of [wcSoundStates]
 * @returns {string}
 */
export function wcSoundFactText(state) {
  const known = state === wcSoundStates.playing || state === wcSoundStates.blocked;
  return known ? state : wcSoundStates.none;
}

/**
 * The sound-only stream on the page's audio element, and the tap that starts it
 * where the browser insists on one: `play()` for each stream the page is given,
 * `state` for the report, and `stop()` for a session that has ended.
 */
export class WcSound {
  /**
   * @param {object} parts
   * @param {HTMLAudioElement} parts.element - the page's audio element
   * @param {EventTarget} [parts.tapTarget] - where a tap counts: the whole page
   * @param {object|null} [parts.button] - the page's "tap to start sound" button,
   *   shown while the sound waits for one
   * @param {(text: string) => void} [parts.onStatus] - where the page's line goes
   */
  constructor({ element, tapTarget = document, button = null, onStatus = () => {} }) {
    this._element = element;
    this._tapTarget = tapTarget;
    this._button = button;
    this._onStatus = onStatus;
    this._state = wcSoundStates.none;
    // Whether the page is listening for the tap, and which play() attempt is the
    // last one asked for: an older stream's answer must not decide this one's.
    this._watchingTap = false;
    this._generation = 0;
    this._onTap = () => this.tap();
  }

  /** Which of [wcSoundStates] the sound is in. */
  get state() {
    return this._state;
  }

  /**
   * Plays [stream], or waits for a tap when the browser will not start it; a
   * null stream is a sound that is gone (a reconnect gives it a new one).
   * @param {MediaStream|null} stream
   */
  play(stream) {
    this._element.srcObject = stream;
    if (stream === null) {
      this._setState(wcSoundStates.none);
      return;
    }
    this._start(false);
  }

  /** Starts the sound from a tap: the page's button, or a tap anywhere on it. */
  tap() {
    if (this._state !== wcSoundStates.blocked) return;
    this._watchTap(false);
    this._start(true);
  }

  /** Ends the sound and every wait for a tap: its session is over. */
  stop() {
    this._element.pause();
    this._element.srcObject = null;
    this._setState(wcSoundStates.none);
  }

  // One attempt at the element. A tap calls it inside the gesture's own tick,
  // which is the only moment a browser that refused the first play() lets the
  // next one through. The refusal is not an error to report: it is the tap.
  async _start(announce) {
    const generation = ++this._generation;
    this._element.muted = false;
    let played = false;
    try {
      await this._element.play();
      // A browser may answer play() and still leave the element paused.
      played = !this._element.paused;
    } catch (error) {
      console.warn(`player: the sound did not start: ${error.message}`);
    }
    if (generation !== this._generation) return;
    if (!played) {
      this._setState(wcSoundStates.blocked);
      this._watchTap(true);
      return;
    }
    this._watchTap(false);
    this._setState(wcSoundStates.playing);
    if (announce) this._onStatus("playing");
  }

  // Shows the page's button while a tap is needed, and says what to do once.
  _setState(state) {
    this._state = state;
    if (state !== wcSoundStates.blocked) this._watchTap(false);
    if (this._button !== null) this._button.classList.toggle("visible", state === wcSoundStates.blocked);
    if (state === wcSoundStates.blocked) this._onStatus(tapStatus);
  }

  // Listens for the tap only while the sound waits for one, so the tap is asked
  // for once per refusal and never again after the sound plays.
  _watchTap(watch) {
    if (watch === this._watchingTap) return;
    this._watchingTap = watch;
    for (const type of gestureEvents) {
      if (watch) this._tapTarget.addEventListener(type, this._onTap, { passive: true });
      else this._tapTarget.removeEventListener(type, this._onTap);
    }
  }
}
