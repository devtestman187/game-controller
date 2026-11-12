/*
 * The Thumb Party TV player page (M15 c1): plain JavaScript, no build step.
 * It connects to the session's signalling server with gst-plugins-rs' own
 * gstwebrtc-api, plays the stream full screen with the lowest delay the
 * browser allows, and reconnects when the stream drops.
 */

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

const screen = document.getElementById("screen");
const statsBox = document.getElementById("stats");
const statusBox = document.getElementById("status");
const toggleButton = document.getElementById("toggle");
const soundButton = document.getElementById("sound");

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

function setStatus(text) {
  statusBox.textContent = text;
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

// Starts the picture, then tries to start the sound with it. Browsers that
// only start sound after a tap show the button instead.
async function startPlayback() {
  screen.muted = true;
  try {
    await screen.play();
    hasPlayed = true;
    reportPlayerState("playing");
  } catch (error) {
    setStatus(`cannot start the picture: ${error.message}`);
    return;
  }
  try {
    screen.muted = false;
    await screen.play();
    soundButton.classList.remove("visible");
    setStatus("playing");
  } catch {
    soundButton.classList.add("visible");
    setStatus("tap the screen to start the sound");
  }
}

function showStats(stats) {
  statsBox.textContent = [
    `picture   ${stats.widthPx}x${stats.heightPx} at ${stats.framesPerSecond.toFixed(0)} fps`,
    `video     ${stats.videoKbitPerS} kbit/s   sound ${stats.audioKbitPerS} kbit/s`,
    `round trip ${stats.roundTripMs} ms   jitter buffer ${stats.jitterBufferMs} ms`,
    `decode    ${stats.decodeMsPerFrame} ms a frame   dropped ${stats.droppedFrames}`,
  ].join("\n");
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
      setStatus(`statistics stopped: ${error.message}`);
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
  reporter = new StreamReporter({ video: screen, peerConnection, onStatus: setStatus, reconnects });
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
  if (consumer !== null) {
    const closing = consumer;
    consumer = null;
    closing.close();
  }
  screen.pause();
  screen.srcObject = null;
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
    if (consumer === session && streams.length > 0 && screen.srcObject !== streams[0]) {
      screen.srcObject = streams[0];
      startPlayback();
      reportPlayerState("streaming");
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
  try {
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
