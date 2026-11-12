/*
 * The player's reporter (M15 c2): it measures what a viewer can measure and
 * sends it to the session's own stats ingest every few seconds, so a stream is
 * compared on the same tables as everything else.
 *
 * What it measures: the browser's own WebRTC statistics (jitter buffer, decode,
 * bitrate, loss, round trip, jitter, frames, freezes, codec, relay), the
 * per-frame times requestVideoFrameCallback gives, a clock offset against the
 * host's clock (a small ping through the same web server, as the controller
 * protocol keeps one), and — for the latency probe — the frame at which the
 * test card's colour changed, timed against the press's host time.
 *
 * Everything goes through the session's web server, which holds the token;
 * this page never sees it.
 */

import {
  FlipWatcher,
  audioSyncMs,
  concealedPct,
  decodeMsPerFrame,
  jitterBufferMs,
  lossPct,
  luminanceOf,
  networkMs,
  presentationDelayMs,
  rateKbitPerS,
} from "./metrics.js";

/** How often a batch of measurements goes to the host. */
const reportIntervalMs = 3000;

/** How often the page asks for presses it has to time. */
const pressPollMs = 200;

/**
 * How long the latency card holds a colour (`LatencyTestCard.flipMs`): it
 * flips on its own clock as well as on a press, so a change a whole cadence or
 * more after the press could be either, and is not counted as the press's.
 */
const cardFlipMs = 500;

/** How often the clock offset is re-measured. */
const clockIntervalMs = 10000;

/** How many clock offsets are kept; the median of them is used. */
const clockPings = 5;

/** A frame this late behind its expected display is counted as late. */
const lateFrameFraction = 1;

/** Pixels the flip is watched at, in the picture's own coordinates. */
const patchSizePx = 8;

/** The brightness the light and dark card are (the look's paper and ink). */
const lightAbove = 120;

/** The brightness below which the card is the dark one. */
const darkBelow = 80;

/** Sample the patch every frame while a press waits, and less often after. */
const patchEveryNthFrame = 8;

/** The frame rate the late-frame test falls back to before one is measured. */
const defaultFps = 60;

/** Give up on a press whose flip was not seen in this long. */
const pressTimeoutMs = 2000;

/**
 * Reports one viewer's stream to the host. Create it once the picture plays;
 * `start()` begins the timers and `stop()` ends them.
 */
export class StreamReporter {
  /**
   * @param {object} parts
   * @param {HTMLVideoElement} parts.video - the element the stream plays in
   * @param {RTCPeerConnection} parts.peerConnection - the connection to the TV
   * @param {(text: string) => void} parts.onProblem - where a measurement
   *   problem goes: the console and the stats overlay, never the picture. An
   *   empty text means the measurements are going through again (M15 g1).
   * @param {number} [parts.reconnects] - reconnects this page has had already
   */
  constructor({ video, peerConnection, onProblem, reconnects = 0 }) {
    this._video = video;
    this._peerConnection = peerConnection;
    this._onProblem = onProblem;
    // A batch of measurements is worth showing once: the same failure every
    // 3 s would bury the numbers in the overlay.
    this._lastProblem = "";
    this._viewerId = "";
    this._offsets = [];
    this._previous = { video: null, audio: null, pair: null };
    this._previousAtMs = 0;
    this._frames = 0;
    this._late = 0;
    this._displayMs = 0;
    this._displayFrames = 0;
    this._firstFrameMs = null;
    this._reconnects = reconnects;
    this._pressesSeen = 0;
    this._presses = [];
    this._flipsSeen = 0;
    this._hostStages = {};
    this._watcher = new FlipWatcher({ lightAbove, darkBelow });
    this._canvas = null;
    this._timers = [];
  }

  /** Starts measuring: the frame callback, the batch timer and the press poll. */
  start() {
    this._watchFrames();
    this._timers.push(window.setInterval(() => this._report(), reportIntervalMs));
    this._timers.push(window.setInterval(() => this._pollPresses(), pressPollMs));
    this._timers.push(window.setInterval(() => this._pingClock(), clockIntervalMs));
    this._pingClock();
  }

  /** Stops every timer; a reconnect starts a new reporter. */
  stop() {
    for (const timer of this._timers) window.clearInterval(timer);
    this._timers = [];
  }

  /** Reads one frame's metadata and the patch of picture the card flips in. */
  _watchFrames() {
    // Safari has this too; a TV's browser or an old WebView may not. The frame
    // count and the press probe then come from the animation frames, and the
    // display stage is reported as missing rather than as 0 (M15 g1).
    if (typeof this._video.requestVideoFrameCallback !== "function") {
      const onAnimationFrame = (nowMs) => {
        this._frames++;
        if (this._firstFrameMs === null) this._firstFrameMs = Math.round(nowMs);
        this._watchPatch(nowMs);
        window.requestAnimationFrame(onAnimationFrame);
      };
      window.requestAnimationFrame(onAnimationFrame);
      return;
    }
    const onFrame = (nowMs, metadata) => {
      this._frames++;
      if (this._firstFrameMs === null) this._firstFrameMs = Math.round(nowMs);
      const delay = presentationDelayMs(metadata);
      this._displayMs += delay;
      this._displayFrames++;
      const budget = 1000 / Math.max(this._deliveredFps(), 1);
      if (delay > budget * lateFrameFraction) this._late++;
      this._watchPatch(nowMs);
      this._video.requestVideoFrameCallback(onFrame);
    };
    this._video.requestVideoFrameCallback(onFrame);
  }

  /**
   * Notes a measurement problem where the viewer is not looking: the console,
   * and the stats overlay the "i" key opens. Watching the picture is what a
   * viewer is here for, so a failed measurement never covers it (M15 t1).
   */
  _problem(text) {
    if (text === this._lastProblem) return;
    this._lastProblem = text;
    console.warn(`player: ${text}`);
    this._onProblem(text);
  }

  /** The delivered frame rate the last statistics sample saw. */
  _deliveredFps() {
    return this._previous.video?.framesPerSecond || defaultFps;
  }

  /**
   * Reads the patch the latency card flips in and, on a flip, sends the time
   * it was presented on the host's clock so the benchmark can time a press.
   */
  _watchPatch(nowMs) {
    const waiting = this._presses.some((press) => !press.seen && !press.expired);
    if (!waiting && this._frames % patchEveryNthFrame !== 0) return;
    const luminance = this._patchLuminance();
    if (luminance === null) return;
    const flip = this._watcher.observe(luminance);
    if (flip === null) return;
    this._noteFlip(nowMs);
    this._matchPresses(nowMs);
  }

  /** The mean brightness of a small patch of the picture, or null. */
  _patchLuminance() {
    const width = this._video.videoWidth;
    const height = this._video.videoHeight;
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
      context.drawImage(this._video, x, y, patchSizePx, patchSizePx, 0, 0, 1, 1);
      const pixel = context.getImageData(0, 0, 1, 1).data;
      return luminanceOf(pixel[0], pixel[1], pixel[2]);
    } catch (error) {
      this._problem(`cannot watch the picture: ${error.message}`);
      return null;
    }
  }

  /** Sends one flip's host time so the benchmark can time its presses. */
  _noteFlip(nowMs) {
    const hostMs = this._toHostMs(nowMs);
    if (hostMs === null) return;
    this._flipsSeen++;
    postJson("/flips", { hostMs }).catch(() => {});
  }

  /** Times every waiting press against the first flip after it. */
  _matchPresses(nowMs) {
    const hostAtFlip = this._toHostMs(nowMs);
    if (hostAtFlip === null) return;
    for (const press of this._presses) {
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

  /** Asks for the presses the benchmark sent, and forgets the ones timed out. */
  async _pollPresses() {
    try {
      const response = await fetch(`/presses?since=${this._pressesSeen}`);
      if (!response.ok) return;
      const body = await response.json();
      for (const press of body.presses ?? []) {
        this._pressesSeen = press.id;
        this._presses.push({ hostMs: press.hostMs, receivedAtMs: performance.now(), seen: false, expired: false });
      }
    } catch (error) {
      this._problem(`cannot read the press probe: ${error.message}`);
    }
    const deadline = performance.now() - pressTimeoutMs;
    this._presses = this._presses.filter((press) => {
      if (press.sent || press.expired) return false;
      return press.seen || press.receivedAtMs >= deadline;
    });
  }

  /** Measures the offset between this page's clock and the host's, and keeps it. */
  async _pingClock() {
    const sentAtMs = performance.now();
    try {
      const response = await fetch("/clock");
      if (!response.ok) return;
      const body = await response.json();
      if (typeof body.hostMs !== "number") return;
      const receivedAtMs = performance.now();
      const offset = body.hostMs - (sentAtMs + receivedAtMs) / 2;
      this._offsets.push(offset);
      if (this._offsets.length > clockPings) this._offsets.shift();
    } catch {
      // A host that isn't up yet answers nothing; the next ping tries again.
    }
  }

  /** This page's clock as the host's, or null before the first ping answered. */
  _toHostMs(localMs) {
    if (this._offsets.length === 0) return null;
    const sorted = [...this._offsets].sort((a, b) => a - b);
    return localMs + sorted[Math.floor(sorted.length / 2)];
  }

  /** Builds one batch and sends it to the session's ingest. */
  async _report() {
    const nowMs = performance.now();
    const elapsedS = this._previousAtMs === 0 ? 0 : (nowMs - this._previousAtMs) / 1000;
    let report;
    try {
      report = await this._peerConnection.getStats();
    } catch (error) {
      this._problem(`statistics stopped: ${error.message}`);
      return;
    }
    const current = { video: null, audio: null, pair: null, codec: null, relay: null };
    // `mediaType` is what Safari and older browsers call the track's `kind`.
    const kindOf = (entry) => entry.kind ?? entry.mediaType;
    report.forEach((entry) => {
      if (entry.type === "inbound-rtp" && kindOf(entry) === "video") current.video = entry;
      else if (entry.type === "inbound-rtp" && kindOf(entry) === "audio") current.audio = entry;
      else if (entry.type === "candidate-pair" && entry.state === "succeeded" && entry.nominated) current.pair = entry;
      else if (entry.type === "codec" && entry.mimeType?.startsWith("video/")) current.codec = entry;
    });
    if (current.codec === null && current.video?.codecId) current.codec = report.get(current.video.codecId) ?? null;
    const local = report.get(current.pair?.localCandidateId ?? "");
    if (local) current.relay = local.candidateType === "relay" ? "yes" : "no";
    this._hostStages = await readHostStages();

    const before = this._previous;
    const batch = this._batch(current, before, elapsedS);
    this._previous = current;
    this._previousAtMs = nowMs;
    if (Object.keys(batch).length === 0) return;
    await this._send(batch);
  }

  /**
   * The batch a window makes: the stages, gauges, counters and facts
   * `stats/stream` reads, with whatever this browser doesn't report left out.
   */
  _batch(current, before, elapsedS) {
    const video = current.video;
    const audio = current.audio;
    const pair = current.pair;
    const stages = [];
    const gauges = [];
    const counters = [];
    const facts = [];
    const addStage = (name, ms) => {
      if (ms !== null) stages.push({ name, ms: Math.round(ms) });
    };
    addStage("stream_jitter_buffer", jitterBufferMs(video, before.video));
    addStage("stream_decode", decodeMsPerFrame(video, before.video));
    addStage("stream_display", this._displayFrames === 0 ? null : this._displayMs / this._displayFrames);
    addStage("stream_network", networkMs(pair));
    for (const press of this._presses) {
      if (press.seen && press.sampleMs !== undefined && !press.sent) {
        stages.push({ name: "press_to_screen", ms: press.sampleMs });
        press.sent = true;
      }
    }
    const addGauge = (name, value) => {
      if (typeof value === "number" && Number.isFinite(value)) gauges.push({ name, value });
    };
    addGauge("bitrateReceivedKbps", rateKbitPerS(video, before.video, elapsedS));
    addGauge("lossPct", lossPct(video));
    addGauge("rttMs", pair?.currentRoundTripTime === undefined ? null : Math.round(pair.currentRoundTripTime * 1000));
    addGauge("jitterMs", video?.jitter === undefined ? null : Math.round(video.jitter * 1000));
    addGauge("deliveredFps", video?.framesPerSecond ?? null);
    addGauge("audioSyncMs", audioSyncMs(audio, video));
    addGauge("audioConcealedPct", concealedPct(audio));
    const sent = this._sentCounters(video);
    for (const [name, value] of Object.entries(sent)) counters.push({ name, value });
    if (current.codec?.mimeType) facts.push({ name: "codec", value: current.codec.mimeType.split("/").pop() });
    if (current.relay) facts.push({ name: "relay", value: current.relay });
    if (video?.frameWidth && video?.frameHeight) {
      facts.push({ name: "resolution", value: `${video.frameWidth}x${video.frameHeight}` });
    }
    // The host's pipeline stages come from the container's own tracer, and the
    // player owns the viewer id, so they land on this row.
    const host = this._hostStages ?? {};
    for (const stage of host.stages ?? []) stages.push({ name: stage.name, ms: stage.ms });
    return {
      ...(this._viewerId === "" ? { viewer: { kind: "browser", platform: platformOf() } } : { viewer: this._viewerId }),
      stages,
      gauges,
      counters,
      facts,
    };
  }

  /** The counters a viewer keeps: totals since it started. */
  _sentCounters(video) {
    if (!video) return {};
    const counters = {
      framesReceived: video.framesReceived ?? 0,
      framesDecoded: video.framesDecoded ?? 0,
      framesDropped: Math.max(0, (video.framesReceived ?? 0) - (video.framesDecoded ?? 0)),
      framesLate: this._late,
      freezes: video.freezeCount ?? 0,
      freezeMs: Math.round((video.totalFreezesDuration ?? 0) * 1000),
      reconnects: this._reconnects,
    };
    if (this._firstFrameMs !== null) counters.firstFrameMs = this._firstFrameMs;
    return counters;
  }

  /** Sends one batch, remembering the viewer id the host answered. */
  async _send(batch) {
    try {
      const response = await fetch("/stats/stream", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(batch),
      });
      const body = await response.json();
      if (!response.ok || body.ok !== true) {
        this._problem(`the host did not take the measurements: ${body.error ?? response.status}`);
        return;
      }
      // `accepted: false` is the host saying no game session is running yet, so
      // there is nothing to keep the numbers for: the home screen, which is a
      // normal state and not a failure (M15 f1).
      if (this._viewerId === "" && typeof body.viewer === "string") this._viewerId = body.viewer;
      this._presses = this._presses.filter((press) => !press.sent);
      this._late = 0;
      this._displayMs = 0;
      this._displayFrames = 0;
      // A batch the host took says the measurements work again, so the overlay
      // stops showing the last failure (M15 g1).
      if (this._lastProblem !== "") {
        this._lastProblem = "";
        this._onProblem("");
      }
    } catch (error) {
      this._problem(`cannot send the measurements: ${error.message}`);
    }
  }
}

/** The browser's name, as a technical platform string. */
function platformOf() {
  const agent = navigator.userAgent;
  if (agent.includes("Edg/")) return "edge";
  if (agent.includes("Firefox/")) return "firefox";
  if (agent.includes("HeadlessChrome/")) return "chrome-headless";
  if (agent.includes("Chrome/")) return "chrome";
  if (agent.includes("Safari/")) return "safari";
  return "browser";
}

/** One JSON POST to the session's own web server. */
async function postJson(path, body) {
  await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

/** Keeps the host's pipeline stages the sampler left for this page. */
export async function readHostStages() {
  try {
    const response = await fetch("/pipeline");
    if (!response.ok) return {};
    return await response.json();
  } catch {
    return {};
  }
}
