/*
 * The player's reporter (M15 c2): it measures what a viewer can measure and
 * sends it to the session's own stats ingest every few seconds, so a stream is
 * compared on the same tables as everything else.
 *
 * What it measures: the browser's WebRTC statistics, the per-frame times
 * requestVideoFrameCallback gives, a clock offset against the host's clock, and
 * the frame at which the test card's colour changed (M15 opt2: now from the
 * custom player's canvas, which reports each draw).
 *
 * Everything goes through the session's web server, which holds the token.
 */

import { ClockSync, clockIntervalMs, lowestRttOffset, medianOffset } from "./clock_sync.js";
import { sessionIdOf } from "./page_state.js";
import { LatencyProbe } from "./latency_probe.js";
import { markerBatch } from "./marker_batch.js";
import { MarkerReader, videoPicture } from "./marker_reader.js";
import {
  audioSyncMs,
  concealedPct,
  decodeMsPerFrame,
  jitterBufferMs,
  lossPct,
  networkMs,
  presentationDelayMs,
  rateKbitPerS,
  viewerCounters,
} from "./metrics.js";

/** How often a batch of measurements goes to the host. */
const reportIntervalMs = 3000;

/** How often the page asks for presses it has to time. */
const pressPollMs = 200;

/** A frame this late behind its expected display is counted as late. */
const lateFrameFraction = 1;

/** The frame rate the late-frame test falls back to before one is measured. */
const defaultFps = 60;

/**
 * Reports one viewer's stream to the host. Create it once the picture plays;
 * `start()` begins the timers and `stop()` ends them.
 */
export class StreamReporter {
  /**
   * @param {object} parts
   * @param {HTMLVideoElement} parts.video - the element the stream plays in
   * @param {RTCPeerConnection|null} [parts.peerConnection] - the TV connection,
   *   null with the custom player, whose picture has its own socket (M15 opt2)
   * @param {(text: string) => void} parts.onProblem - where a measurement problem
   *   goes: the console and the overlay, never the picture (an empty text says
   *   the measurements go through again, M15 g1)
   * @param {number} [parts.reconnects] - reconnects this page has had already
   * @param {boolean} [parts.marker] - whether the page reads the host's marker
   *   row (`marker=1`); off, no strip is read and none of its numbers is sent
   * @param {{image: () => (HTMLVideoElement|HTMLCanvasElement), widthPx: () => number,
   *   heightPx: () => number}|null} [parts.picture] - where the marker's strip and the
   *   card's patch are read: the video element by default, or the canvas (M15 opt2)
   */
  constructor({ video, peerConnection = null, onProblem, reconnects = 0, marker = false, picture = null }) {
    this._video = video;
    this._peerConnection = peerConnection;
    this._picture = picture ?? videoPicture(video);
    this._onProblem = onProblem;
    // A failure is worth showing once: the same text every 3 s would bury the
    // numbers in the overlay.
    this._lastProblem = "";
    this._viewerId = "";
    // The marker's age needs the shortest round trip's offset; a page without
    // the marker keeps the median it always used.
    this._clock = new ClockSync({ mode: marker ? lowestRttOffset : medianOffset });
    this._previous = { video: null, audio: null, pair: null };
    this._previousAtMs = 0;
    this._frames = 0;
    this._late = 0;
    this._displayMs = 0;
    this._displayFrames = 0;
    this._firstFrameMs = null;
    this._reconnects = reconnects;
    this._hostStages = {};
    this._soundGauges = [];
    this._probe = new LatencyProbe({
      picture: this._picture,
      onProblem: (text) => this._problem(text),
      toHostMs: (nowMs) => this._clock.toHostMs(nowMs),
    });
    // The marker's reader rides the same frame callback the probe does, so a
    // frame is read once and the strip costs one canvas read.
    this._marker = marker
      ? new MarkerReader({
          picture: this._picture,
          toHostMs: (nowMs) => this._clock.toHostMs(nowMs),
          onProblem: (text) => this._problem(text),
          presses: () => this._probe.presses,
        })
      : null;
    this._timers = [];
    this._animationFrame = null;
    this._videoFrame = null;
    this._stopped = false;
  }

  /**
   * Sets the gauges the page reads from the sound's own connection (M15
   * fix7), whose numbers a report tells from the picture's (`audioJitterMs`).
   */
  setSoundGauges(gauges) {
    this._soundGauges = gauges;
  }

  /** Sets the provider of extra stages, gauges, facts and a video entry a batch adds (M15 opt1b), or nothing. */
  setExtraSeries(provider) {
    this._extras = provider;
  }

  /**
   * Starts measuring: the frame callback, the batch timer and the press poll.
   * The custom player's page calls [drawnFrame] itself, as it has no connection.
   */
  start() {
    if (this._peerConnection !== null) this._watchFrames();
    this._timers.push(window.setInterval(() => this._report(), reportIntervalMs));
    this._timers.push(window.setInterval(() => this._probe.poll(), pressPollMs));
    this._timers.push(window.setInterval(() => this._clock.ping(), clockIntervalMs));
    this._clock.ping();
  }

  /** Stops every timer and the frame loop; a reconnect starts a new reporter. */
  stop() {
    this._stopped = true;
    for (const timer of this._timers) window.clearInterval(timer);
    this._timers = [];
    // A browser without the frame callback is counted from animation frames,
    // and that loop asks for the next frame by itself: left alone it keeps
    // running after a reconnect replaced this reporter, one loop per reconnect.
    if (this._animationFrame !== null) {
      window.cancelAnimationFrame(this._animationFrame);
      this._animationFrame = null;
    }
    // The frame callback's loop re-registers itself too; the handle from the
    // last registration ends it where the browser has the cancel, and the
    // stopped check in `onFrame` ends it there for one that has not (M15 fix3).
    if (this._videoFrame !== null && typeof this._video.cancelVideoFrameCallback === "function") {
      this._video.cancelVideoFrameCallback(this._videoFrame);
    }
    this._videoFrame = null;
  }

  /**
   * One frame as this page saw it: counted, given to the press probe and read
   * for the marker (the custom player calls it after each draw, M15 opt2).
   * @param {number} drawnAtMs - the page time the frame reached the screen
   * @param {object|null} [metadata] - requestVideoFrameCallback's fields, if any
   */
  drawnFrame(drawnAtMs, metadata = null) {
    if (this._stopped) return;
    this._frames++;
    if (this._firstFrameMs === null) this._firstFrameMs = Math.round(drawnAtMs);
    this._probe.watch(drawnAtMs, this._frames);
    this._marker?.readFrame(drawnAtMs, metadata);
  }

  /** Reads one frame's metadata and the patch of picture the card flips in. */
  _watchFrames() {
    // Safari has this too; a TV's browser or an old WebView may not. The frame
    // count and the probe then come from animation frames, with the display
    // stage reported as missing rather than as 0 (M15 g1).
    if (typeof this._video.requestVideoFrameCallback !== "function") {
      // No metadata without the frame callback: the marker's raw fields are
      // then recorded as missing, which is what this browser says.
      const onAnimationFrame = (nowMs) => {
        this.drawnFrame(nowMs);
        this._animationFrame = window.requestAnimationFrame(onAnimationFrame);
      };
      this._animationFrame = window.requestAnimationFrame(onAnimationFrame);
      return;
    }
    const onFrame = (nowMs, metadata) => {
      // One frame may already be queued when `stop()` runs: it ends the loop
      // rather than counting a frame for a reporter a reconnect replaced.
      if (this._stopped) return;
      const delay = presentationDelayMs(metadata);
      this._displayMs += delay;
      this._displayFrames++;
      const budget = 1000 / Math.max(this._previous.video?.framesPerSecond || defaultFps, 1);
      if (delay > budget * lateFrameFraction) this._late++;
      this.drawnFrame(nowMs, metadata);
      this._videoFrame = this._video.requestVideoFrameCallback(onFrame);
    };
    this._videoFrame = this._video.requestVideoFrameCallback(onFrame);
  }

  /**
   * Notes a measurement problem where the viewer is not looking: the console and
   * the overlay. Watching the picture matters more, so it never covers it (M15 t1).
   */
  _problem(text) {
    if (text === this._lastProblem) return;
    this._lastProblem = text;
    console.warn(`player: ${text}`);
    this._onProblem(text);
  }

  /** Builds one batch and sends it to the session's ingest. */
  async _report() {
    const nowMs = performance.now();
    const elapsedS = this._previousAtMs === 0 ? 0 : (nowMs - this._previousAtMs) / 1000;
    let report = null;
    try {
      // The custom player has no picture connection: its own figures fill the batch.
      report = this._peerConnection === null ? null : await this._peerConnection.getStats();
    } catch (error) {
      this._problem(`statistics stopped: ${error.message}`);
      return;
    }
    const current = { video: null, audio: null, pair: null, codec: null, relay: null };
    // `mediaType` is what Safari and older browsers call the track's `kind`.
    const kindOf = (entry) => entry.kind ?? entry.mediaType;
    report?.forEach((entry) => {
      if (entry.type === "inbound-rtp" && kindOf(entry) === "video") current.video = entry;
      else if (entry.type === "inbound-rtp" && kindOf(entry) === "audio") current.audio = entry;
      else if (entry.type === "candidate-pair" && entry.state === "succeeded" && entry.nominated) current.pair = entry;
      else if (entry.type === "codec" && entry.mimeType?.startsWith("video/")) current.codec = entry;
    });
    if (current.codec === null && current.video?.codecId) current.codec = report.get(current.video.codecId) ?? null;
    const local = report?.get(current.pair?.localCandidateId ?? "");
    if (local) current.relay = local.candidateType === "relay" ? "yes" : "no";
    this._hostStages = await readHostStages();

    const before = this._previous;
    const batch = this._batch(current, before, elapsedS);
    this._previous = current;
    this._previousAtMs = nowMs;
    if (Object.keys(batch).length === 0) return;
    // A page that got a connection but no picture has decoded nothing, and its
    // batch would only list the host's stages (M15 fix5). The custom player has
    // no connection, so its batch always goes.
    if (this._peerConnection !== null && !((current.video?.framesDecoded ?? 0) > 0)) return;
    await this._send(batch);
  }

  /**
   * The batch a window makes: the stages, gauges, counters and facts
   * `stats/stream` reads, with whatever this browser doesn't report left out.
   */
  _batch(current, before, elapsedS) {
    // An extra series' stages go first and keep a name they share: with
    // `player=wc` they are the batch's only decode and display stages, and its
    // counters come as the video entry, since the page has no track (M15 opt2b-6).
    const extras = this._extras?.() ?? null;
    const video = current.video ?? extras?.video ?? null;
    const audio = current.audio; const pair = current.pair;
    const stages = [...(extras?.stages ?? [])];
    const gauges = [];
    const counters = [];
    const facts = [];
    const addStage = (name, ms) => {
      if (ms !== null && !stages.some((stage) => stage.name === name)) stages.push({ name, ms: Math.round(ms) });
    };
    addStage("stream_jitter_buffer", jitterBufferMs(video, before.video));
    addStage("stream_decode", decodeMsPerFrame(video, before.video));
    // Decoded to display, when the browser says when the frame arrived and will
    // show it; one without those fields keeps the older lateness reading.
    const decodedDisplayMs = this._marker === null ? null : this._marker.decodedDisplayMs();
    const latenessMs = this._displayFrames === 0 ? null : this._displayMs / this._displayFrames;
    addStage("stream_display", decodedDisplayMs ?? latenessMs);
    addStage("stream_network", networkMs(pair));
    for (const press of this._probe.presses) {
      if (press.seen && press.sampleMs !== undefined && !press.sent) {
        stages.push({ name: "press_to_screen", ms: press.sampleMs });
        press.sent = true;
      }
    }
    const addGauge = (name, value) => {
      if (typeof value !== "number" || !Number.isFinite(value) || gauges.some((gauge) => gauge.name === name)) return;
      gauges.push({ name, value });
    };
    addGauge("bitrateReceivedKbps", rateKbitPerS(video, before.video, elapsedS));
    addGauge("lossPct", lossPct(video));
    addGauge("rttMs", pair?.currentRoundTripTime === undefined ? null : Math.round(pair.currentRoundTripTime * 1000));
    addGauge("jitterMs", video?.jitter === undefined ? null : Math.round(video.jitter * 1000));
    addGauge("deliveredFps", video?.framesPerSecond ?? null);
    addGauge("audioSyncMs", audioSyncMs(audio, video));
    addGauge("audioConcealedPct", concealedPct(audio));
    for (const gauge of this._soundGauges) addGauge(gauge.name, gauge.value);
    for (const gauge of extras?.gauges ?? []) addGauge(gauge.name, gauge.value);
    if (extras !== null) facts.push(...extras.facts ?? []);
    const sent = viewerCounters(video, {
      lateFrames: this._late,
      reconnects: this._reconnects,
      firstFrameMs: video?.firstFrameMs ?? this._firstFrameMs,
    });
    for (const [name, value] of Object.entries(sent)) counters.push({ name, value });
    if (current.codec?.mimeType) facts.push({ name: "codec", value: current.codec.mimeType.split("/").pop() });
    if (current.relay) facts.push({ name: "relay", value: current.relay });
    if (video?.frameWidth && video?.frameHeight) {
      facts.push({ name: "resolution", value: `${video.frameWidth}x${video.frameHeight}` });
    }
    // The host's pipeline stages come from the container's tracer, on this row.
    const host = this._hostStages ?? {};
    for (const stage of host.stages ?? []) stages.push({ name: stage.name, ms: stage.ms });
    // The marker's numbers ride the same four containers under their own names
    // (marker_batch.js), so a summary carries them as it carries the rest.
    if (this._marker !== null) {
      const marker = markerBatch(this._marker.summary(), this._clock.state());
      stages.push(...marker.stages);
      gauges.push(...marker.gauges);
      counters.push(...marker.counters);
      facts.push(...marker.facts);
    }
    return {
      ...(this._viewerId === "" ? { viewer: { kind: "browser", platform: platformOf() } } : { viewer: this._viewerId }),
      stages,
      gauges,
      counters,
      facts,
    };
  }

  /** Sends one batch, remembering the viewer id the host answered. */
  async _send(batch) {
    try {
      // The session this page loaded travels in a header, never in the batch:
      // the relay refuses a batch a page from an earlier session sends, so its
      // numbers are not counted (M15 fix8).
      const response = await fetch("/stats/stream", {
        method: "POST",
        headers: { "content-type": "application/json", "x-player-session": sessionIdOf() },
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
      this._probe.forgetSent();
      this._marker?.clear();
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
