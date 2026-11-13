/*
 * The custom player (M15 opt2): the host's H.264 arrives as access units on the
 * player relay's `/tap` WebSocket (PROTOCOL.md), the browser's VideoDecoder
 * decodes it (wc_decoder.js) and each frame is drawn on a canvas. It is the
 * page's second picture path, behind `player=wc`, and only the phone sitting
 * keeps it.
 *
 * Delay is the whole point, so nothing here queues: frames after a gap, or
 * while the decoder is behind, are dropped and a keyframe is asked for.
 */

import { annexbToAvcc, parseHeader } from "./wc_annexb.js";
import { bytesOf, emptyCounters, FrameCanvas, FrameStages, frameTimestampUs, noteDrawnAt } from "./wc_counters.js";
import { WcDecoder } from "./wc_decoder.js";

/** The most frames the decoder may hold queued: more is backlog, not saved delay. */
const maxQueueDepth = 2;

/** The shortest gap between two keyframe requests, in ms (PROTOCOL.md: at most one per 500 ms). */
const keyRequestMinMs = 500;

/** How long after a loss the socket is opened again, in ms: 200 at first, doubling to 2000. */
const reconnectMinMs = 200;
const reconnectMaxMs = 2000;

/** A WebSocket whose readyState is this accepts a send (the WebSocket.OPEN value). */
const socketOpen = 1;

/** The relay's tap socket on the page's own host: the player port tunnels `/tap` (PROTOCOL.md). */
function defaultTapUrl() {
  const scheme = globalThis.location?.protocol === "https:" ? "wss" : "ws";
  return `${scheme}://${globalThis.location?.host ?? ""}/tap`;
}

/**
 * One custom-player connection: `start()` opens the socket and `stop()` ends
 * every timer, socket and decoder. The browser's own classes are injected so a
 * page test drives the whole player without a stream.
 */
export class WcPlayer {
  /**
   * @param {object} parts
   * @param {string} [parts.url] - the tap socket's url; the page's own host by default
   * @param {HTMLCanvasElement} parts.canvas - where the decoded frames are drawn
   * @param {(event: {type: string, text?: string}) => void} [parts.onEvent] - the
   *   page's events: "status" with a text, "lost" when the socket dropped, "end"
   * @param {(frameNo: number, drawnAtMs: number) => void} [parts.onDrawn] - after
   *   each frame is on the canvas
   * @param {(text: string) => void} [parts.onMissing] - where a browser class
   *   the player cannot run without is reported to the host (M15 opt2b)
   * @param {boolean} [parts.annexb] - ask the decoder for Annex B in band
   *   (`wcmode=annexb`) instead of AVCC with a description
   * @param {() => number} [parts.now] - the page's clock, in ms
   * @param {Function} [parts.WebSocketImpl] - the browser's WebSocket, VideoDecoder and
   *   EncodedVideoChunk, and a timer: injected so a page test drives the player
   * @param {Function} [parts.VideoDecoderImpl]
   * @param {Function} [parts.EncodedVideoChunkImpl]
   * @param {(run: () => void, delayMs: number) => number} [parts.setTimeoutImpl]
   */
  constructor({
    url = defaultTapUrl(), canvas, onEvent = () => {}, onDrawn = () => {}, onMissing = () => {}, annexb = false,
    now = () => performance.now(),
    WebSocketImpl = globalThis.WebSocket, VideoDecoderImpl = globalThis.VideoDecoder,
    EncodedVideoChunkImpl = globalThis.EncodedVideoChunk,
    setTimeoutImpl = (run, delayMs) => globalThis.setTimeout(run, delayMs),
  }) {
    this._url = url;
    this._picture = new FrameCanvas(canvas);
    this._onEvent = onEvent;
    this._onDrawn = onDrawn;
    this._onMissing = onMissing;
    this._annexb = annexb;
    this._now = now;
    this._WebSocket = WebSocketImpl;
    this._Decoder = VideoDecoderImpl;
    this._Chunk = EncodedVideoChunkImpl;
    this._setTimeout = setTimeoutImpl;
    this._socket = null;
    this._stopped = false;
    this._timer = null;
    this._reconnectDelayMs = reconnectMinMs;
    // Frames are handled one after another: configuring the decoder is
    // asynchronous and a chunk must never overtake the configuration it needs.
    this._chain = Promise.resolve();
    this._needKey = true;
    this._lastFrame = null;
    this._lastKeyRequestAtMs = -Infinity;
    this._stages = new FrameStages();
    this._counters = emptyCounters();
    // The decoder keeps its own errors and rebuilds (wc_decoder.js), and says
    // when its message is stale; the player still owns the keyframe requests.
    this._decoder = new WcDecoder({
      decoderClass: VideoDecoderImpl,
      chunkClass: EncodedVideoChunkImpl,
      annexb,
      now,
      setTimeoutImpl,
      onFrame: (frame) => this._drew(frame),
      onStatus: (text) => this._onEvent({ type: "status", text }),
      onNeedsKey: () => this._needsKeyframe(),
    });
  }

  /**
   * Opens the tap socket and starts decoding. A browser without WebCodecs or
   * WebSocket is told which class it lacks, on the page and to the host (M15 opt2b).
   */
  start() {
    const missing = [
      ["WebSocket", this._WebSocket], ["VideoDecoder", this._Decoder], ["EncodedVideoChunk", this._Chunk],
    ].filter((part) => typeof part[1] !== "function").map((part) => part[0]);
    if (missing.length > 0) {
      const text = `this browser cannot play the video: no ${missing.join(", ")}`;
      this._onEvent({ type: "status", text });
      this._onMissing(text);
      return;
    }
    this._stopped = false;
    // The first frame is timed from here, the moment the page asked for the picture.
    this._counters.startedAtMs = this._now();
    this._decoder.start();
    this._openSocket();
  }

  /** Ends the socket, the timer and the decoder: nothing is left running. */
  stop() {
    this._stopped = true;
    this._clearTimer();
    this._closeSocket();
    this._decoder.close();
  }

  /** The player's plain numbers, for the page's overlay and a run's report. */
  counters() {
    return { ...this._counters, ...this._decoder.counters() };
  }

  /** The last frames' stage times, in arrival order, for the figures (job 4). */
  stageSamples() {
    return this._stages.samples();
  }

  _openSocket() {
    let socket;
    try {
      socket = new this._WebSocket(this._url);
    } catch (error) {
      this._onEvent({ type: "status", text: `the tap socket did not open: ${error.message}` });
      this._scheduleReconnect();
      return;
    }
    socket.binaryType = "arraybuffer";
    socket.onopen = () => {
      this._reconnectDelayMs = reconnectMinMs;
      this._onEvent({ type: "status", text: "connected to the TV" });
    };
    socket.onmessage = (message) => this._receive(message.data);
    socket.onclose = () => this._socketLost();
    socket.onerror = () => this._socketLost();
    this._socket = socket;
  }

  _closeSocket() {
    const socket = this._socket;
    this._socket = null;
    if (socket === null) return;
    socket.onopen = null;
    socket.onmessage = null;
    socket.onclose = null;
    socket.onerror = null;
    socket.close();
  }

  // One lost socket is one reconnect, however many events the browser sends
  // for it: the next open puts the socket back and the delay up.
  _socketLost() {
    if (this._stopped || this._socket === null) return;
    this._socket = null;
    this._counters.reconnects++;
    this._needKey = true;
    this._lastFrame = null;
    this._onEvent({ type: "lost" });
    this._scheduleReconnect();
  }

  _scheduleReconnect() {
    if (this._stopped || this._timer !== null) return;
    const delayMs = this._reconnectDelayMs;
    this._reconnectDelayMs = Math.min(reconnectMaxMs, delayMs * 2);
    this._timer = this._setTimeout(() => {
      this._timer = null;
      this._openSocket();
    }, delayMs);
  }

  _clearTimer() {
    if (this._timer === null) return;
    globalThis.clearTimeout(this._timer);
    this._timer = null;
  }

  _send(message) {
    if (this._socket === null || this._socket.readyState !== socketOpen) return;
    this._socket.send(JSON.stringify(message));
  }

  _receive(data) {
    if (this._stopped) return;
    this._counters.bytesReceived += bytesOf(data);
    if (typeof data === "string") return this._receiveText(data);
    // A browser that hands a Blob over instead of bytes (a socket whose
    // binaryType it ignored) would throw in the header read (M15 opt2b).
    if (!(data instanceof ArrayBuffer) && !ArrayBuffer.isView(data)) {
      this._onEvent({ type: "status", text: "the TV sent a message this page cannot read" });
      return;
    }
    const receivedAtMs = this._now();
    const message = parseHeader(data);
    if (message === null) return;
    const stage = this._stages.note(message.frame, receivedAtMs);
    this._counters.framesReceived++;
    this._counters.lastFrame = message.frame;
    this._chain = this._chain
      .then(() => this._handleFrame(message, stage))
      .catch((error) => this._decoder.failed(error));
  }

  _receiveText(text) {
    let message = null;
    try {
      message = JSON.parse(text);
    } catch (error) {
      this._onEvent({ type: "status", text: `the host sent text that is not JSON: ${error.message}` });
      return;
    }
    if (message === null || typeof message !== "object") return;
    // A "hello" only repeats what the SPS says; "end" is the session's own end,
    // and nothing may reconnect after it.
    if (message.type !== "end") return;
    this._stopped = true;
    this._clearTimer();
    this._closeSocket();
    this._onEvent({ type: "end" });
  }

  async _handleFrame(message, stage) {
    if (this._stopped) return;
    // A stream the browser refused for good is dropped without asking for a
    // keyframe: nothing this page can say would make it decode 4:4:4 (M15 opt2b-3).
    if (this._decoder.refused) return;
    const queue = this._decoder.queueSize;
    this._counters.queueMax = Math.max(this._counters.queueMax, queue);
    if (queue > maxQueueDepth) {
      this._counters.dropsQueue++;
      this._needsKeyframe();
      return;
    }
    if (message.keyframe) {
      // The decoder takes the SPS and PPS here, and says whether this keyframe
      // may be decoded at all (wc_decoder.js).
      const configured = await this._decoder.configureFor(message.payload);
      if (this._stopped) return;
      if (!configured) {
        this._counters.dropsGap++;
        return;
      }
    } else if (this._needKey || this._lastFrame === null || message.frame !== this._lastFrame + 1) {
      // A delta before the first keyframe or after a dropped one: the picture
      // cannot be built from it, so it goes and a keyframe is asked for.
      this._counters.dropsGap++;
      this._needsKeyframe();
      return;
    }
    const data = this._annexb ? message.payload : annexbToAvcc(message.payload);
    const type = message.keyframe ? "key" : "delta";
    if (!this._decoder.decode(data, type, message.frame)) return;
    this._lastFrame = message.frame;
    this._needKey = false;
    this._counters.queueMax = Math.max(this._counters.queueMax, this._decoder.queueSize);
  }

  // The decoder's own reason to ask again: an error, a rebuild or a stream
  // whose SPS and PPS it cannot use.
  _needsKeyframe() {
    this._needKey = true;
    this._requestKeyframe();
  }

  _requestKeyframe() {
    const nowMs = this._now();
    if (nowMs - this._lastKeyRequestAtMs < keyRequestMinMs) return;
    this._lastKeyRequestAtMs = nowMs;
    this._counters.keyRequests++;
    this._send({ type: "key" });
  }

  // The decoder's output: one frame on the canvas, then closed whatever the
  // draw did — an open VideoFrame holds a decoder buffer back.
  _drew(frame) {
    const frameNo = Math.round(frame.timestamp / frameTimestampUs);
    this._counters.framesDecoded++;
    const stage = this._stages.get(frameNo);
    if (stage !== undefined) stage.decodeOutputAt = this._now();
    try {
      const problem = this._picture.draw(frame);
      if (problem !== "") throw new Error(problem);
      this._counters.framesDrawn++;
      const drawnAtMs = this._now();
      noteDrawnAt(this._counters, drawnAtMs);
      this._counters.frameWidthPx = Math.round(frame.displayWidth);
      this._counters.frameHeightPx = Math.round(frame.displayHeight);
      if (stage !== undefined) stage.drawnAt = drawnAtMs;
      this._onDrawn(frameNo, drawnAtMs);
      // A frame drawn after a decoder error ends that error's message: an empty
      // status is the page's line back to normal (M15 opt2b-3).
      if (this._decoder.noteDrawn() !== "") this._onEvent({ type: "status", text: "" });
    } catch (error) {
      this._onEvent({ type: "status", text: `cannot draw the picture: ${error.message}` });
    } finally {
      frame.close();
    }
  }
}
