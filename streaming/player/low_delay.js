/*
 * The page's zero-delay option (M15 fix7, technique 2): the per-receiver and
 * per-element settings that keep playout at zero, put back every second and
 * after each stream change because Chrome may reset them when a track or a
 * connection is renegotiated. Nothing here runs unless the page's options say
 * `lowdelay=1`, so a page without it behaves exactly as it did.
 */

// How often the hints are put back, in ms: the stats overlay reads them back
// once a second too, so its line always shows what the last apply set.
const reapplyIntervalMs = 1000;

// The values of the option that mean on: the URL's bare `lowdelay` becomes
// "1", and a person may write the word.
const onValues = ["1", "true", "on", "yes"];

// What the element's latency hint is set to when the browser has one (the Web
// Media Latency Hint proposal): the low-delay value. A browser without the
// property is shown as `latency=missing` instead of being guessed at.
const latencyHintLow = "interactive";

/** Whether the page's options ask for the zero-delay settings. */
export function lowDelayEnabled(options) {
  const value = options === null || options === undefined ? "" : String(options.lowdelay ?? "");
  return onValues.includes(value.toLowerCase());
}

/** A receiver property's value, or "missing" when this browser lacks it. */
function readBack(receiver, name) {
  return name in receiver ? String(receiver[name]) : "missing";
}

/** One receiver's kind and both of its hints, for the overlay line. */
function receiverFacts(receiver) {
  const kind = receiver.track === null || receiver.track === undefined ? "trackless" : receiver.track.kind;
  return `${kind} jbt=${readBack(receiver, "jitterBufferTarget")} pdh=${readBack(receiver, "playoutDelayHint")}`;
}

/** Puts one receiver's hints at zero, where the browser has them. */
function zeroReceiver(receiver, jitterBuffer) {
  if (jitterBuffer && "jitterBufferTarget" in receiver) receiver.jitterBufferTarget = 0;
  if ("playoutDelayHint" in receiver) receiver.playoutDelayHint = 0;
}

/**
 * Keeps the zero-delay settings applied to the page's two connections and its
 * video element. `watch` applies them at once and every `reapplyIntervalMs`
 * until `stop`, which the page calls when its connections are gone.
 */
export class LowDelay {
  /**
   * @param {object} parts
   * @param {HTMLVideoElement} parts.screen - the element the picture plays in
   * @param {boolean} [parts.jitterBuffer] - whether this sets
   *   `jitterBufferTarget` too: false leaves that one property to the page's
   *   `jbtarget` option, whose value wins when both are on (M15 opt1b)
   */
  constructor({ screen, jitterBuffer = true }) {
    this._screen = screen;
    this._jitterBuffer = jitterBuffer;
    this._picture = null;
    this._sound = null;
    this._timer = null;
  }

  /** Applies now, then keeps applying every second; safe to call repeatedly. */
  watch(pictureConnection, soundConnection) {
    this._picture = pictureConnection;
    this._sound = soundConnection;
    this._apply();
    if (this._timer === null) this._timer = window.setInterval(() => this._apply(), reapplyIntervalMs);
  }

  /** Ends the timer; the next `watch` starts it again. */
  stop() {
    if (this._timer === null) return;
    window.clearInterval(this._timer);
    this._timer = null;
  }

  /**
   * The overlay's line: what the element and every receiver hold now, read back
   * after the last apply, with `missing` for a property this browser lacks.
   */
  line() {
    const screen = this._screen;
    const facts = [
      `rate=${screen.playbackRate}`,
      `drp=${"disableRemotePlayback" in screen ? (screen.disableRemotePlayback ? "on" : "off") : "missing"}`,
      `latency=${"latencyHint" in screen ? screen.latencyHint : "missing"}`,
    ];
    const receivers = this._receiverFacts();
    if (receivers.length === 0) receivers.push("no receiver yet");
    return `lowdelay: ${facts.join(" ")} ${receivers.join(", ")}`;
  }

  _receiverFacts() {
    const facts = [];
    for (const connection of [this._picture, this._sound]) {
      if (connection === null) continue;
      for (const receiver of connection.getReceivers()) facts.push(receiverFacts(receiver));
    }
    return facts;
  }

  _apply() {
    const screen = this._screen;
    screen.disableRemotePlayback = true;
    screen.playbackRate = 1;
    if ("latencyHint" in screen) screen.latencyHint = latencyHintLow;
    for (const connection of [this._picture, this._sound]) {
      if (connection === null) continue;
      for (const receiver of connection.getReceivers()) zeroReceiver(receiver, this._jitterBuffer);
    }
  }
}
