/*
 * Where the custom player's page itself backs up (M15 opt2c-1): the socket's
 * gaps and bytes, the decoder's queue, and the page's own thread — a 20 ms
 * timer's lateness, its long tasks and the time its onmessage takes. Measuring
 * only: the draw, the drops and the keyframe requests are unchanged. A run that
 * collapses can then say which of the three fell behind: the network, the
 * decoder or the page's thread.
 *
 * Kept apart from the player in wc_player.js, which feeds it and starts its
 * tick, and from the figures in wc_stats.js, which send its snapshot.
 */

/** The page's own heartbeat, in ms: a timer this late says the thread was busy. */
export const diagTickMs = 20;

/** A tick later than its period by more than this is main-thread lag, in ms. */
const lagMinMs = 30;

/** A lag longer than this is counted too, in ms: the lag a person can see. */
const lagOverMs = 50;

/** A gap between two messages longer than this is counted, in ms: a visible stall. */
const gapWarnMs = 100;

/** A gap longer than this is the picture stopping, in ms. */
const gapBadMs = 250;

/** The window a byte rate is measured over, in ms. */
const rateWindowMs = 1000;

/** The mean size of a kind of message in whole bytes, or 0 before one came. */
function meanBytes(kind) {
  return kind.count === 0 ? 0 : Math.round(kind.bytes / kind.count);
}

/**
 * The custom player's diagnostics (M15 opt2c-1): what the page can tell about
 * its own side of a stall. The player calls [noteMessage] for each frame off
 * the socket, [noteDecoderQueue] at each decode, [noteHandlerMs] after each
 * onmessage and [tick] from its 20 ms timer; [start] and [stop] own the long
 * task observer. [snapshot] gives every figure as one plain object.
 */
export class WcDiag {
  /** @param {object} parts
   * @param {Function|null} [parts.observerClass] - the browser's PerformanceObserver,
   *   or null for a browser (or a test) that watches no long tasks
   */
  constructor({ observerClass = globalThis.PerformanceObserver } = {}) {
    this._Observer = observerClass;
    this._observer = null;
    this._lastMessageAtMs = null;
    this._gapMaxMs = 0;
    this._gapsWarn = 0;
    this._gapsBad = 0;
    this._recvBytes = 0;
    this._keys = { count: 0, bytes: 0, max: 0 };
    this._deltas = { count: 0, bytes: 0, max: 0 };
    this._decQueueMax = 0;
    this._lastTickAtMs = null;
    this._lagMaxMs = 0;
    this._lagsOver = 0;
    this._longTasks = 0;
    this._handlerMaxMs = 0;
    this._second = [];
    this._secondBytes = 0;
    this._bytesPerSecMax = 0;
  }

  /**
   * Watches the page's long tasks where the browser has the observer: a page
   * without one counts none, and one whose observer refuses is no error.
   */
  start() {
    if (typeof this._Observer !== "function") return;
    try {
      this._observer = new this._Observer((entries) => {
        this._longTasks += entries.getEntries().length;
      });
      this._observer.observe({ type: "longtask" });
    } catch (error) {
      console.warn(`player: no long task observer: ${error.message}`);
      this._observer = null;
    }
  }

  /** Stops watching long tasks: nothing is left running. */
  stop() {
    if (this._observer === null) return;
    this._observer.disconnect();
    this._observer = null;
  }

  /**
   * One message off the socket, as it arrived: the gap since the last one (the
   * first has none), its size, and whether it was a keyframe.
   * @param {number} nowMs - the page time the message reached the socket
   * @param {number} bytes - the message's size
   * @param {boolean} isKey - a keyframe, not a delta
   */
  noteMessage(nowMs, bytes, isKey) {
    if (this._lastMessageAtMs !== null) {
      const gapMs = nowMs - this._lastMessageAtMs;
      this._gapMaxMs = Math.max(this._gapMaxMs, gapMs);
      if (gapMs > gapWarnMs) this._gapsWarn++;
      if (gapMs > gapBadMs) this._gapsBad++;
    }
    this._lastMessageAtMs = nowMs;
    this._recvBytes += bytes;
    const kind = isKey ? this._keys : this._deltas;
    kind.count++;
    kind.bytes += bytes;
    kind.max = Math.max(kind.max, bytes);
    this._noteRate(nowMs, bytes);
  }

  /**
   * A socket that was lost and is opened again: the wait across a reconnect is
   * its own delay, not a gap in a stream, so the next message starts afresh.
   */
  noteReconnect() {
    this._lastMessageAtMs = null;
    this._second = [];
    this._secondBytes = 0;
  }

  /**
   * How long the page's own onmessage took, in ms, up to handing the frame to
   * the decoder: the page's cost is what a slow phone adds to every frame.
   * @param {number} ms
   */
  noteHandlerMs(ms) {
    this._handlerMaxMs = Math.max(this._handlerMaxMs, ms);
  }

  /**
   * The decoder's queue at one decode call, in frames: what it still had to
   * chew on when the next frame came.
   * @param {number} size - the decoder's decodeQueueSize
   */
  noteDecoderQueue(size) {
    this._decQueueMax = Math.max(this._decQueueMax, size);
  }

  /**
   * One beat of the 20 ms timer: a beat that came late by more than [lagMinMs]
   * is lag on the page's own thread, and one over [lagOverMs] is counted too.
   * @param {number} nowMs - the page time the beat ran
   */
  tick(nowMs) {
    const beforeMs = this._lastTickAtMs;
    this._lastTickAtMs = nowMs;
    if (beforeMs === null) return;
    const lateMs = nowMs - beforeMs - diagTickMs;
    if (lateMs <= lagMinMs) return;
    this._lagMaxMs = Math.max(this._lagMaxMs, lateMs);
    if (lateMs > lagOverMs) this._lagsOver++;
  }

  /**
   * Every figure, as the gauges send them: the gaps' longest and their counts,
   * the bytes received and the sizes of both kinds of frame, the decoder's
   * queue, the page's lag with its count and its long tasks, its longest
   * handler, and the most bytes one second took.
   * @returns {object}
   */
  snapshot() {
    return {
      gapMaxMs: Math.round(this._gapMaxMs),
      gapsOver100: this._gapsWarn,
      gapsOver250: this._gapsBad,
      recvBytes: this._recvBytes,
      keyBytesMax: this._keys.max,
      keyBytesAvg: meanBytes(this._keys),
      deltaBytesAvg: meanBytes(this._deltas),
      deltaBytesMax: this._deltas.max,
      decQueueMax: this._decQueueMax,
      mainLagMaxMs: Math.round(this._lagMaxMs),
      mainLagOver50: this._lagsOver,
      longTasks: this._longTasks,
      msgHandlerMaxMs: Math.round(this._handlerMaxMs),
      bytesPerSecMax: this._bytesPerSecMax,
    };
  }

  // The bytes of the last second and the largest such sum: one window, pruned
  // as each message comes, so a burst after a stall reads as the burst it was.
  _noteRate(nowMs, bytes) {
    this._second.push({ atMs: nowMs, bytes });
    this._secondBytes += bytes;
    while (this._second.length > 0 && nowMs - this._second[0].atMs >= rateWindowMs) {
      this._secondBytes -= this._second.shift().bytes;
    }
    this._bytesPerSecMax = Math.max(this._bytesPerSecMax, this._secondBytes);
  }
}
