/*
 * The page's clock offset against the host's (M15 c2, NTP-style in M15 fix8):
 * how far this page's clock is from the host's, measured through the small ping
 * the reporter already makes — `GET /clock`, which the relay answers from the
 * host's own `GET /status`. Each round trip gives one sample: the host's stamp
 * against the middle of the page's send and receive times, the round trip and
 * half of it as the uncertainty.
 *
 * Two ways to combine the samples: the median of the last few, which is what
 * the page always used, and the offset of the sample with the smallest round
 * trip, which is the NTP choice — the shortest trip is the one least blurred by
 * queueing, so its offset is the truest. The marker's age needs the second.
 */

/** How often the offset is re-measured, in ms: now and then through the run. */
export const clockIntervalMs = 10000;

/** How many samples are kept: the best of the last few. */
export const clockSamples = 5;

/** The offset that is the median of the kept samples' (the page's old choice). */
export const medianOffset = "median";

/**
 * The middle sample of [values]' order: an odd count's middle, an even count's
 * upper middle. This is exactly how the page chose its offset before the
 * marker, so a page without the option keeps the numbers it had.
 */
function middleOf(values) {
  return [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
}

/** The offset of the kept sample with the smallest round trip. */
export const lowestRttOffset = "minRtt";

/** The offset [samples] say, in [mode]'s way, or null without samples. */
export function chooseSample(samples, mode = medianOffset) {
  if (samples.length === 0) return null;
  if (mode === lowestRttOffset) {
    return samples.reduce((best, sample) => (sample.rttMs < best.rttMs ? sample : best));
  }
  const rttMs = middleOf(samples.map((sample) => sample.rttMs));
  const offsetMs = middleOf(samples.map((sample) => sample.offsetMs));
  return { offsetMs, rttMs, uncertaintyMs: rttMs / 2 };
}

/**
 * One round trip's sample from the relay's answer, or null when it carries no
 * host clock: the host's stamp against the middle of the page's times, the
 * round trip, and half of it as the uncertainty.
 * @param {{hostMs?: unknown}} body - what `GET /clock` answered
 * @param {number} sentAtMs - the page's clock before the call
 * @param {number} receivedAtMs - the page's clock after the answer
 * @returns {{offsetMs: number, rttMs: number, uncertaintyMs: number}|null}
 */
export function parseClockAnswer(body, sentAtMs, receivedAtMs) {
  const hostMs = body?.hostMs;
  if (typeof hostMs !== "number" || !Number.isFinite(hostMs)) return null;
  const rttMs = receivedAtMs - sentAtMs;
  if (!(rttMs >= 0)) return null;
  return { offsetMs: hostMs - (sentAtMs + receivedAtMs) / 2, rttMs, uncertaintyMs: rttMs / 2 };
}

/** Keeps the offset samples and answers this page's times as the host's. */
export class ClockSync {
  /**
   * @param {object} [parts]
   * @param {string} [parts.mode] - [medianOffset] or [lowestRttOffset]
   * @param {string} [parts.path] - the relay's clock call
   */
  constructor({ mode = medianOffset, path = "/clock" } = {}) {
    this._mode = mode;
    this._path = path;
    this._samples = [];
    this._chosen = null;
  }

  /** The samples kept, oldest first. */
  get samples() {
    return this._samples;
  }

  /** Measures one round trip and keeps it; a host that isn't up yet answers nothing. */
  async ping() {
    const sentAtMs = performance.now();
    try {
      const response = await fetch(this._path);
      if (!response.ok) return;
      const body = await response.json();
      const sample = parseClockAnswer(body, sentAtMs, performance.now());
      if (sample === null) return;
      this._samples.push(sample);
      if (this._samples.length > clockSamples) this._samples.shift();
      // Chosen here, not in `state()`: the page asks this once a frame.
      this._chosen = chooseSample(this._samples, this._mode);
    } catch {
      // A host that isn't up yet answers nothing; the next ping tries again.
    }
  }

  /** The offset in use: `{offsetMs, rttMs, uncertaintyMs}`, or null before one answered. */
  state() {
    return this._chosen;
  }

  /** This page's clock as the host's, or null before the first ping answered. */
  toHostMs(localMs) {
    return this._chosen === null ? null : localMs + this._chosen.offsetMs;
  }
}
