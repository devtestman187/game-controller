/*
 * The Thumb Party TV player page (M15 c1): plain JavaScript, no build step.
 * It connects to the session's signalling server with gst-plugins-rs' own
 * gstwebrtc-api, plays the stream full screen with the lowest delay the
 * browser allows, and reconnects when the stream drops.
 */

import { parseOptions, optionsLine } from "./options.js";
import { StreamReporter } from "./reporter.js";
import { StatsMeter } from "./stats.js";

const GstWebRTCAPI = window.GstWebRTCAPI;

// How long to wait before asking for the stream again after it or the
// signalling server dropped: short enough that a person sees a blink, long
// enough that a server still starting up is not hammered.
const reconnectDelayMs = 1000;

// How often the overlay and the status line are refreshed.
const statsIntervalMs = 1000;

const signalPort = (window.THUMB_PARTY && window.THUMB_PARTY.signalingPort) || 8443;

// Whether the picture and the sound play from two separate media elements.
// Chrome holds video back to stay in sync with the audio's larger buffer; each
// element with its own track keeps its own (M15 t1 experiment 1, off unless
// `SESSION_SPLIT_TRACKS` is on: see streaming/README.md).
const splitTracks = Boolean(window.THUMB_PARTY && window.THUMB_PARTY.splitTracks);

// The switches this page runs with (M15 fix7), read once: the session's defaults
// from config.js, overridden key by key by this page's own URL query. Exposed on
// the window so a run can see what the page saw, and shown in the overlay.
const options = parseOptions(window.location.search, (window.THUMB_PARTY && window.THUMB_PARTY.options) || {});
window.THUMB_PARTY_OPTIONS = options;
const switchesLine = optionsLine(options);

const screen = document.getElementById("screen");
const soundTrack = document.getElementById("sound-track");
const statsBox = document.getElementById("stats");
const statusBox = document.getElementById("status");
const toggleButton = document.getElementById("toggle");
const soundButton = document.getElementById("sound");

// The overlay carries the switches from the start, so a look at the page — or a
// DOM dump of it — shows what it runs with even before a stream arrives.
if (switchesLine !== "") statsBox.textContent = switchesLine;

let api = null;
let consumer = null;
let meter = null;
let reporter = null;
let statsTimer = null;
let reconnectTimer = null;
// How many times this page asked for the stream again (M15 c2's quality
// table), counted across connections. Only a drop after the picture has played
// counts: a page that opens before the TV has a producer waits once, and that
// wait is a start, not a reconnect.
let reconnects = 0;
let hasPlayed = false;
// The stream the two elements are playing, so the same one is not set twice.
let playingStream = null;
// The last measurement problem, shown in the stats overlay only. Watching the
// picture is what a viewer is here for, so a failed measurement never covers
// it (M15 t1: the owner saw "the host did not take the measurements" across
// the picture on a phone).
let problem = "";

function setStatus(text) {
  statusBox.textContent = text;
}

// Where the reporter's problems go: the console always, the stats overlay too.
// An empty text is the reporter saying nothing is wrong any more (M15 g1).
function noteProblem(text) {
  problem = text;
}

function signallingUrl() {
  const scheme = window.location.protocol === "https:" ? "wss" : "ws";
  return `${scheme}://${window.location.hostname}:${signalPort}`;
}

// The lowest delay the browser offers: no growable jitter buffer and no
// playout delay on top of it (WebRTC buffers by default; M15 step 3 tunes it).
function tuneForLowDelay(peerConnection) {
  for (const receiver of peerConnection.getReceivers()) {
    if ("jitterBufferTarget" in receiver) {
      receiver.jitterBufferTarget = 0;
    }
    if ("playoutDelayHint" in receiver) {
      receiver.playoutDelayHint = 0;
    }
  }
}

// The stream's picture on its own when the tracks are split, so the video
// element's buffer holds no audio to wait for.
function pictureOf(stream) {
  if (!splitTracks) return stream;
  const tracks = stream.getVideoTracks();
  return tracks.length === 0 ? stream : new MediaStream(tracks);
}

// The stream's sound on its own, or null when one element plays both.
function soundOf(stream) {
  if (!splitTracks) return null;
  const tracks = stream.getAudioTracks();
  return tracks.length === 0 ? null : new MediaStream(tracks);
}

// Starts the picture, then tries to start the sound with it. Browsers that
// only start sound after a tap show the button instead.
async function startPlayback() {
  screen.muted = true;
  soundTrack.muted = true;
  try {
    await screen.play();
    hasPlayed = true;
    reportPlayerState("playing");
  } catch (error) {
    setStatus(`cannot start the picture: ${error.message}`);
    // The benchmark is waiting for "playing" and would only see "streaming":
    // say why the picture did not start, so a run's failure has a reason.
    reportPlayerState("cannot play", { reason: error.message });
    return;
  }
  try {
    screen.muted = false;
    soundTrack.muted = false;
    if (splitTracks) await soundTrack.play();
    await screen.play();
    soundButton.classList.remove("visible");
    setStatus("playing");
  } catch {
    soundButton.classList.add("visible");
    setStatus("tap the screen to start the sound");
  }
}

function showStats(stats) {
  const lines = [
    `picture   ${stats.widthPx}x${stats.heightPx} at ${stats.framesPerSecond.toFixed(0)} fps`,
    `video     ${stats.videoKbitPerS} kbit/s   sound ${stats.audioKbitPerS} kbit/s`,
    `round trip ${stats.roundTripMs} ms   jitter buffer ${stats.jitterBufferMs} ms`,
    `decode    ${stats.decodeMsPerFrame} ms a frame   dropped ${stats.droppedFrames}`,
  ];
  if (switchesLine !== "") lines.push(switchesLine);
  if (problem !== "") lines.push(`measurement: ${problem}`);
  statsBox.textContent = lines.join("\n");
}

function stopStats() {
  if (statsTimer !== null) {
    window.clearInterval(statsTimer);
    statsTimer = null;
  }
  meter = null;
}

function startStats(peerConnection) {
  stopStats();
  meter = new StatsMeter(peerConnection);
  const tick = async () => {
    try {
      showStats(await meter.sample());
    } catch (error) {
      noteProblem(`statistics stopped: ${error.message}`);
      // The timer stops here, so the next tick that would draw the line never
      // comes: add it once to what the overlay already says (M15 g1).
      statsBox.textContent += `\nmeasurement: ${problem}`;
      console.warn(`player: statistics stopped: ${error.message}`);
      stopStats();
    }
  };
  statsTimer = window.setInterval(tick, statsIntervalMs);
}

// Tells the session's web server what this page is doing, so a benchmark can
// wait for the picture instead of guessing (M15 c2).
function reportPlayerState(state, extra = {}) {
  fetch("/player", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ state, ...extra }),
  }).catch(() => {});
}

// Starts sending the measurements the host's stats record keeps; the reporter
// reads the same connection's numbers and the frame times the browser gives.
function startReporting(peerConnection) {
  stopReporting();
  reporter = new StreamReporter({ video: screen, peerConnection, onProblem: noteProblem, reconnects });
  reporter.start();
}

function stopReporting() {
  if (reporter !== null) {
    reporter.stop();
    reporter = null;
  }
}

function closeConsumer() {
  stopStats();
  stopReporting();
  reportPlayerState("closed");
  playingStream = null;
  // A problem belongs to the stream that had it: the next one starts clean
  // (M15 g1, as `playingStream` does).
  problem = "";
  if (consumer !== null) {
    const closing = consumer;
    consumer = null;
    closing.close();
  }
  screen.pause();
  screen.srcObject = null;
  soundTrack.pause();
  soundTrack.srcObject = null;
}

function scheduleReconnect() {
  if (reconnectTimer !== null) {
    return;
  }
  closeConsumer();
  if (hasPlayed) {
    reconnects++;
  }
  reportPlayerState("reconnecting", { reconnects });
  reconnectTimer = window.setTimeout(() => {
    reconnectTimer = null;
    connectToFirstProducer();
  }, reconnectDelayMs);
}

function connectTo(producerId) {
  closeConsumer();
  const session = api.createConsumerSession(producerId);
  if (session === null) {
    scheduleReconnect();
    return;
  }
  consumer = session;

  session.addEventListener("error", (event) => {
    if (consumer === session) {
      setStatus(`error: ${event.message}`);
      scheduleReconnect();
    }
  });
  session.addEventListener("closed", () => {
    if (consumer === session) {
      setStatus("the session closed");
      scheduleReconnect();
    }
  });
  session.addEventListener("streamsChanged", () => {
    const streams = session.streams;
    if (consumer === session && streams.length > 0 && playingStream !== streams[0]) {
      playingStream = streams[0];
      screen.srcObject = pictureOf(streams[0]);
      soundTrack.srcObject = soundOf(streams[0]);
      // "streaming" goes first and "playing" lands when the picture starts, so
      // a benchmark that waits for either sees them in that order however fast
      // the browser's play() answers (M15 t1: the two raced).
      reportPlayerState("streaming");
      startPlayback();
    }
  });
  session.addEventListener("stateChanged", () => {
    const peerConnection = session.rtcPeerConnection;
    if (consumer !== session || peerConnection === null) {
      return;
    }
    if (meter === null) {
      tuneForLowDelay(peerConnection);
      startStats(peerConnection);
    }
    if (reporter === null) startReporting(peerConnection);
  });

  setStatus("connecting to the TV…");
  session.connect();
}

function connectToFirstProducer() {
  if (api === null) {
    return;
  }
  const producers = api.getAvailableProducers();
  if (producers.length === 0) {
    setStatus("waiting for the TV…");
    scheduleReconnect();
    return;
  }
  connectTo(producers[0].id);
}

function start() {
  api = new GstWebRTCAPI({
    meta: { name: `ThumbPartyPlayer-${Date.now()}` },
    signalingServerUrl: signallingUrl(),
    // No STUN here: a session on the same machine or the same Wi-Fi needs none,
    // and asking an outside server would only add delay.
    webrtcConfig: { iceServers: [] },
  });

  api.registerConnectionListener({
    connected: () => {
      setStatus("connected to the TV");
      connectToFirstProducer();
    },
    disconnected: () => {
      setStatus("lost the TV, reconnecting…");
      scheduleReconnect();
    },
  });

  api.registerProducersListener({
    producerAdded: () => connectToFirstProducer(),
    producerRemoved: () => scheduleReconnect(),
  });
}

// The button and the keyboard both show or hide the numbers.
function toggleStats() {
  statsBox.classList.toggle("visible");
}

toggleButton.addEventListener("click", (event) => {
  event.preventDefault();
  toggleStats();
});

soundButton.addEventListener("click", async (event) => {
  event.preventDefault();
  soundButton.classList.remove("visible");
  screen.muted = false;
  soundTrack.muted = false;
  try {
    if (splitTracks) await soundTrack.play();
    await screen.play();
  } catch (error) {
    setStatus(`cannot start the sound: ${error.message}`);
  }
  // A tap is the one moment a browser allows full screen.
  document.documentElement.requestFullscreen?.().catch(() => {});
});

window.addEventListener("keydown", (event) => {
  if (event.key === "s" || event.key === "i") {
    toggleStats();
  }
});

start();
