/*
 * The page's jitter buffer target option (M15 opt1b): `jbtarget=<ms>` puts a
 * value on every receiver's `jitterBufferTarget` and reads it back, so a phone
 * run shows whether the value asked for really arrived and stayed. Safari
 * 27 is the browser this is for: it has the property, and a browser may clamp
 * or ignore the value, so the read-back — not the request — is the proof.
 *
 * Nothing here runs unless the page's options say `jbtarget=<ms>`, so a page
 * without it behaves exactly as it did, and `lowdelay=1` keeps setting the
 * property when this option is off only (see low_delay.js).
 */

// The highest value the option takes, in ms: the browser's own estimate stays
// under a few hundred; 4000 leaves room for a deliberately slow target.
const maxTargetMs = 4000;

// A whole decimal number: no sign, no decimal point, no exponent.
const wholeNumber = /^[0-9]+$/;

// How often the target is put back, in ms, as low_delay.js does: the browser
// may reset it when a track or a connection is renegotiated.
const reapplyIntervalMs = 1000;

// The host's fact rules (stream_stats.dart's maxStreamFactLength and
// _technicalPattern): a fact over 24 characters or with a character outside
// the set is dropped, so the text below is built to fit them. That is also why
// the pairs are separated by a space: `=` is not a fact character.
const factLengthLimit = 24;
const notFactCharacter = /[^A-Za-z0-9 ,._()+-]+/g;

// What the error text follows in a fact, and how many characters it costs.
const errPrefix = " err ";

/** The names every number and the fact are sent under, so a report and a test share one list. */
export const jbTargetNames = {
  requested: "jbTargetRequestedMs",
  applied: "jbTargetAppliedMs",
  fact: "jbtarget",
};

/**
 * The target `options.jbtarget` asks for, in ms, or null when the value is not
 * a whole decimal number from 0 to 4000 (4001, -1, "", "abc", "1.5", "1e2" are
 * all ignored, and the page then behaves as without the option). A bare
 * `?jbtarget` is "1" here: options.js gives every key without `=value` the
 * value "1", so that link asks for 1 ms, not for the word "on".
 */
export function jbTargetOf(options) {
  const value = options === null || options === undefined ? "" : String(options.jbtarget ?? "");
  if (!wholeNumber.test(value)) return null;
  const requestedMs = Number(value);
  return requestedMs <= maxTargetMs ? requestedMs : null;
}

/** What one receiver holds now: its number, its text, or "missing" without the property. */
function readValue(receiver) {
  if (!("jitterBufferTarget" in receiver)) return "missing";
  const value = receiver.jitterBufferTarget;
  return typeof value === "number" && Number.isFinite(value) ? value : String(value);
}

/** Whether every receiver, none, or some have the property; "none yet" before one exists. */
function supportOf(receivers) {
  if (receivers.length === 0) return "none yet";
  const withTarget = receivers.filter((receiver) => "jitterBufferTarget" in receiver).length;
  if (withTarget === receivers.length) return "yes";
  return withTarget === 0 ? "no" : "partial";
}

/** One number when the receivers agree, their values joined by "/", else "missing". */
function joinValues(values) {
  if (values.length === 0) return "missing";
  return values.every((value) => value === values[0]) ? values[0] : values.join("/");
}

/** A read-back value as the fact says it: the host's facts have no "/". */
function appliedText(applied) {
  return String(applied).split("/").join(",");
}

/** An error's text, cut to [room] characters and to the fact's characters. */
function errorText(error, room) {
  const text = String(error).replace(notFactCharacter, " ").replace(/ +/g, " ").trim();
  return text.slice(0, room).trimEnd();
}

/**
 * One state as the fact's and the overlay's text, inside the host's fact
 * limits: `req 100 has yes read 100`, with `err <text>` when an error was
 * recorded. Two pairs cannot fit beside 24 characters, so the text gives way
 * in a fixed order: the error first (it is the news, and a number the receiver
 * holds is in the gauges), then the support, which leaves the read-back — the
 * proof this option exists for — beside the value asked for.
 */
export function jbTargetText(state, limit = factLengthLimit) {
  const head = `req ${state.requested} has ${state.supported}`;
  const withRead = `${head} read ${appliedText(state.applied)}`;
  if (state.error !== "") {
    const room = limit - withRead.length - errPrefix.length;
    if (room > 0) return `${withRead}${errPrefix}${errorText(state.error, room)}`;
    const headRoom = limit - head.length - errPrefix.length;
    if (headRoom > 0) return `${head}${errPrefix}${errorText(state.error, headRoom)}`;
    return head;
  }
  if (withRead.length <= limit) return withRead;
  // Nothing read back is no proof either, so the support pair stays; receivers
  // that disagree name several values, and there the read-back is the proof.
  const applied = appliedText(state.applied);
  if (applied === "missing") return head;
  const readOnly = `req ${state.requested} read ${applied}`;
  return readOnly.length <= limit ? readOnly : head;
}

/**
 * Keeps the target applied to every receiver of the page's two connections,
 * and says what they hold: `watch` applies at once and every
 * `reapplyIntervalMs` until `stop`, as LowDelay does, so a receiver is set as
 * soon as it exists and again after any reconnect.
 */
export class JbTarget {
  /**
   * @param {object} parts
   * @param {number} parts.requested - the ms the page's `jbtarget` asks for
   */
  constructor({ requested }) {
    this._requested = requested;
    this._picture = null;
    this._sound = null;
    this._timer = null;
    this._error = "";
  }

  /** Applies now, then keeps applying every second; safe to call repeatedly. */
  watch(pictureConnection, soundConnection) {
    this._picture = pictureConnection ?? null;
    this._sound = soundConnection ?? null;
    this._apply();
    if (this._timer === null) this._timer = window.setInterval(() => this._apply(), reapplyIntervalMs);
  }

  /**
   * Applies to a connection's receivers and again for each track it adds
   * later, which is how the page's pictureReady and soundReady take it, so a
   * receiver is set as soon as it exists (M15 opt1b).
   */
  watchConnection(peerConnection, pictureConnection, soundConnection) {
    this.watch(pictureConnection, soundConnection);
    peerConnection.addEventListener("track", () => this.watch(pictureConnection, soundConnection));
  }

  /** Ends the timer; the next `watch` starts it again. */
  stop() {
    if (this._timer === null) return;
    window.clearInterval(this._timer);
    this._timer = null;
  }

  /** One reapply, which the timer calls each second; the page's test calls it too. */
  tick() {
    this._apply();
  }

  /**
   * What the receivers hold at this moment, read back every call and never
   * cached: the value asked for, whether the receivers have the property, the
   * value read from them, and the first error a setter threw.
   */
  state() {
    const receivers = this._receivers();
    return {
      requested: this._requested,
      supported: supportOf(receivers),
      applied: joinValues(receivers.map(readValue)),
      error: this._error,
    };
  }

  /** The overlay's line, shown only when the option is on. */
  line() {
    return `jbtarget: ${jbTargetText(this.state())}`;
  }

  /** The gauges and the fact one reporter batch adds; none when nothing is set. */
  batch() {
    const state = this.state();
    const gauges = [{ name: jbTargetNames.requested, value: state.requested }];
    if (typeof state.applied === "number") gauges.push({ name: jbTargetNames.applied, value: state.applied });
    return { gauges, facts: [{ name: jbTargetNames.fact, value: jbTargetText(state) }] };
  }

  /** Every receiver of both connections, an absent connection skipped. */
  _receivers() {
    const receivers = [];
    for (const connection of [this._picture, this._sound]) {
      if (connection === null) continue;
      receivers.push(...connection.getReceivers());
    }
    return receivers;
  }

  /** Puts the target on every receiver that has it; a throwing setter is recorded, never thrown. */
  _apply() {
    for (const receiver of this._receivers()) {
      if (!("jitterBufferTarget" in receiver)) continue;
      try {
        receiver.jitterBufferTarget = this._requested;
      } catch (error) {
        // A browser that refuses the value (a clamp, a closed receiver) is a
        // number the report must still explain, so the first text is kept.
        if (this._error === "") this._error = String(error && error.message ? error.message : error);
      }
    }
  }
}
