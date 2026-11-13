/*
 * When a page's session has ended (M15 fix8): a picture that played and has not
 * come back inside [hiccupMaxMs] means the TV's session is over, while a
 * shorter drop is one the page recovers from. The decision is one pure function,
 * so the self-test page checks it without a session; the watch around it keeps
 * the page's two facts and calls back once, also without a clock of its own.
 */

// The longest drop the page treats as a hiccup, in milliseconds. A page asks for
// the stream again one second after a drop (streams.js), and a TV that restarts
// its pipeline comes back well inside this; a session that has ended sends no
// stream again, so fifteen seconds tells the two apart with room to spare
// (M15 fix8).
export const hiccupMaxMs = 15000;

// How often a watching page looks at its session, in milliseconds.
export const watchTickMs = 1000;

/** The line the page shows, and its tab's title, once its session has ended. */
export const endedText = "The stream has ended. Reload this page to join the next session.";

/**
 * What the page's session is doing, from the page's own facts.
 * @param {object} facts
 * @param {boolean} facts.hasPlayed - a picture has played on this page
 * @param {boolean} facts.isPlaying - a stream is connected right now
 * @param {number} facts.lostMs - milliseconds since the picture went away
 * @returns {string} "waiting", "playing", "reconnecting" or "ended"
 */
export function sessionPhase({ hasPlayed, isPlaying, lostMs }) {
  if (isPlaying) return "playing";
  // A page opened before the TV sends anything waits, however long it takes:
  // that wait is a start, never an end (M15 c1).
  if (!hasPlayed) return "waiting";
  return lostMs > hiccupMaxMs ? "ended" : "reconnecting";
}

/**
 * One page's session, timed. `picturePlaying()` and `pictureLost()` are the
 * page's two facts, `start()` looks every [tickMs] and calls `onEnded` once the
 * picture has been gone longer than a hiccup, and `stop()` ends the timer. Its
 * own `check()` is what the self-test calls, so no real time is needed.
 * @param {object} parts
 * @param {() => number} parts.nowMs - the page's clock, in milliseconds
 * @param {() => void} parts.onEnded - what the page does when the session ended
 * @param {number} [parts.tickMs] - how often `start()` looks at the session
 */
export function createSessionWatch({ nowMs, onEnded, tickMs = watchTickMs }) {
  let hasPlayed = false;
  let playing = false;
  let lostAtMs = null;
  let ended = false;
  let timer = null;

  function stop() {
    if (timer !== null) {
      window.clearInterval(timer);
      timer = null;
    }
  }

  function check() {
    if (ended) return;
    const lostMs = lostAtMs === null ? 0 : nowMs() - lostAtMs;
    if (sessionPhase({ hasPlayed, isPlaying: playing, lostMs }) !== "ended") return;
    // An ended session stays ended: a later check never calls `onEnded` again.
    ended = true;
    stop();
    onEnded();
  }

  return {
    check,
    stop,
    /** Starts looking at the session every [tickMs]. */
    start() {
      if (timer === null && !ended) timer = window.setInterval(check, tickMs);
    },
    /** The picture is there again, or for the first time. */
    picturePlaying() {
      hasPlayed = true;
      playing = true;
      lostAtMs = null;
    },
    /** The picture is gone: the drop it may recover from starts now. */
    pictureLost() {
      if (!playing) return;
      playing = false;
      lostAtMs = nowMs();
    },
  };
}
