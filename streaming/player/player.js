/*
 * The Thumb Party TV player page (M15 c1): plain JavaScript, no build step.
 * It connects to the session's signalling server with gst-plugins-rs' own
 * gstwebrtc-api, plays the stream full screen with the lowest delay the
 * browser allows, and reconnects when the stream drops.
 */

import { markerEnabled, parseOptions, optionsLine } from "./options.js";
import { LowDelay, lowDelayEnabled } from "./low_delay.js";
import { audioMode, msidsOf, reportPlayerState } from "./page_state.js";
import { Playback, pictureOf, soundOf } from "./playback.js";
import { StreamReporter } from "./reporter.js";
import { StatsMeter } from "./stats.js";
import { StreamLinks } from "./streams.js";

const GstWebRTCAPI = window.GstWebRTCAPI;

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
const playback = new Playback({ screen, sound: soundTrack });
const statsBox = document.getElementById("stats");
const statusBox = document.getElementById("status");
const toggleButton = document.getElementById("toggle");
const soundButton = document.getElementById("sound");
// The zero-delay option (M15 fix7, technique 2), null unless `lowdelay=1`.
const lowDelay = lowDelayEnabled(options) ? new LowDelay({ screen }) : null;

// The overlay carries the switches from the start, so a look at the page — or a
// DOM dump of it — shows what it runs with even before a stream arrives.
if (switchesLine !== "") statsBox.textContent = switchesLine;

let meter = null;
let reporter = null;
let statsTimer = null;
// The two peer connections, for the streams their SDPs name.
let pictureConnection = null;
let soundConnection = null;
// The sound's own connection, when the session sends one (SESSION_AUDIO=
// separate): it has a meter of its own, and its loss never touches the
// picture's.
let soundMeter = null;
// How many times this page asked for the stream again (M15 c2's quality
// table), counted across connections. Only a drop after the picture has played
// counts: a page that opens before the TV has a producer waits once, and that
// wait is a start, not a reconnect.
let reconnects = 0;
let hasPlayed = false;
// The picture's stream from the TV, what the video element was given
// (`pictureOf` may copy it), and the sound producer's stream when there is one.
let playingStream = null;
let playingPicture = null;
let soundStream = null;
// Whether the picture's own stream carries sound (the modes that send one
// stream), which the overlay needs to tell "sound none" from a number.
let pictureHasAudio = false;
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

// Starts the picture, then tries to start the sound with it. Browsers that
// only start sound after a tap show the button instead.
async function startPlayback() {
  soundButton.classList.remove("visible");
  try {
    await playback.startMuted();
    hasPlayed = true;
    reportPlayerState("playing");
  } catch (error) {
    setStatus(`cannot start the picture: ${error.message}`);
    // The benchmark is waiting for "playing" and would only see "streaming":
    // say why the picture did not start, so a run's failure has a reason.
    reportPlayerState("cannot play", { reason: error.message });
    return;
  }
  await startSound();
}

// Unmutes the picture and starts the sound, which a late or reconnected sound
// stream needs again. A stream without sound needs no tap, so no button.
async function startSound() {
  try {
    await playback.unmute();
    soundButton.classList.remove("visible");
    setStatus("playing");
  } catch {
    soundButton.classList.add("visible");
    setStatus("tap the screen to start the sound");
  }
}

// The overlay's sound: the bitrate of the connection it arrives on, or "none"
// for a session that sends no sound at all (SESSION_AUDIO=off).
function soundText(stats, soundStats) {
  if (soundStream !== null) return soundStats === null ? "sound none" : `sound ${soundStats.audioKbitPerS} kbit/s`;
  return pictureHasAudio ? `sound ${stats.audioKbitPerS} kbit/s` : "sound none";
}

function showStats(stats, soundStats) {
  const soundJitter = soundStats === null ? "" : `  sound jitter ${soundStats.audioJitterBufferMs} ms`;
  const lines = [
    `picture   ${stats.widthPx}x${stats.heightPx} at ${stats.framesPerSecond.toFixed(0)} fps`,
    `video     ${stats.videoKbitPerS} kbit/s   ${soundText(stats, soundStats)}`,
    `round trip ${stats.roundTripMs} ms   jitter buffer ${stats.jitterBufferMs} ms${soundJitter}`,
    `decode    ${stats.decodeMsPerFrame} ms a frame   dropped ${stats.droppedFrames}`,
  ];
  if (switchesLine !== "") lines.push(switchesLine);
  if (lowDelay !== null) lines.push(lowDelay.line());
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

// The sound's own numbers, or null when it has no connection. A reconnect
// replaces the sound's connection under this timer, and a sample of the old
// one failing is a missing number for that second, never a reason to stop the
// picture's numbers with it.
async function sampleSound() {
  if (soundMeter === null) return null;
  try {
    return await soundMeter.sample();
  } catch (error) {
    console.warn(`player: the sound's statistics stopped: ${error.message}`);
    return null;
  }
}

function startStats(peerConnection) {
  stopStats();
  meter = new StatsMeter(peerConnection);
  const tick = async () => {
    try {
      const soundStats = await sampleSound();
      showStats(await meter.sample(), soundStats);
      sendSoundJitter(soundStats);
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

// What the page is playing, for the state it reports.
function audioModeNow() {
  return audioMode(soundStream !== null, pictureHasAudio);
}

// The stream ids a connection's SDP names, for the state the page reports: a
// run reads them to see whether the sound arrived on a stream of its own. No
// ids yet means the connection has not answered, so nothing is reported and a
// later report keeps whatever an earlier one found.
function msidFacts(key, peerConnection) {
  const ids = msidsOf(peerConnection);
  return ids.length === 0 ? {} : { [key]: ids };
}

// Starts sending the measurements the host's stats record keeps; the reporter
// reads the same connection's numbers and the frame times the browser gives.
function startReporting(peerConnection) {
  stopReporting();
  reporter = new StreamReporter({
    video: screen,
    peerConnection,
    onProblem: noteProblem,
    reconnects,
    marker: markerEnabled(options),
  });
  reporter.start();
}

function stopReporting() {
  if (reporter !== null) {
    reporter.stop();
    reporter = null;
  }
}

// The sound connection's own jitter buffer, on the page's row in the host's
// record (`audioJitterMs`): with the sound on its own connection the row's
// `stream_jitter_buffer` stage is the picture's, so this is the only place the
// sound's wait is written down (M15 fix7, phase 2 reads it).
function sendSoundJitter(soundStats) {
  if (reporter === null || soundStats === null) return;
  reporter.setSoundGauges([{ name: "audioJitterMs", value: soundStats.audioJitterBufferMs }]);
}

// A closed connection takes everything with it: the numbers, the overlay's
// problem and both elements. The next stream starts clean (M15 g1: a problem
// belongs to the stream that had it).
function connectionClosed() {
  stopStats();
  stopReporting();
  lowDelay?.stop();
  playback.clear();
  playingStream = null;
  playingPicture = null;
  pictureConnection = null;
  soundConnection = null;
  soundMeter = null;
  problem = "";
  reportPlayerState("closed");
}

// A stream arrived on the sound's own connection, or null when it is gone:
// the picture is already playing and is not touched (SESSION_AUDIO=separate).
function showSound(stream) {
  soundStream = stream;
  if (stream === null) {
    soundMeter = null;
    soundConnection = null;
  }
  if (playingPicture === null) return;
  playback.show(playingPicture, soundOf(playingStream, splitTracks, soundStream));
  lowDelay?.watch(pictureConnection, soundConnection);
  reportPlayerState(hasPlayed ? "playing" : "streaming", {
    audio: audioModeNow(),
    ...msidFacts("soundMsids", soundConnection),
  });
  if (hasPlayed) startSound();
}

// Plays the picture's stream; a repeated `streamsChanged` for the same stream
// must not restart it.
function showPicture(stream) {
  if (playingStream === stream) return;
  playingStream = stream;
  pictureHasAudio = stream.getAudioTracks().length > 0;
  playingPicture = pictureOf(stream, splitTracks);
  playback.show(playingPicture, soundOf(stream, splitTracks, soundStream));
  lowDelay?.watch(pictureConnection, soundConnection);
  // "streaming" goes first and "playing" lands when the picture starts, so
  // a benchmark that waits for either sees them in that order however fast
  // the browser's play() answers (M15 t1: the two raced).
  reportPlayerState("streaming", { audio: audioModeNow(), ...msidFacts("msids", pictureConnection) });
  startPlayback();
}

// What the two connections call; the picture's numbers are the viewer's, and
// the sound's own connection only feeds the overlay and one gauge.
const linkHandlers = {
  pictureStream: showPicture,
  soundStream: showSound,
  pictureReady: (peerConnection) => {
    pictureConnection = peerConnection;
    // The ids the SDP names only exist once the connection has answered, so
    // they are reported here too, not only when a stream arrives.
    reportPlayerState(hasPlayed ? "playing" : "streaming", msidFacts("msids", peerConnection));
    if (meter === null) {
      tuneForLowDelay(peerConnection);
      startStats(peerConnection);
    }
    if (reporter === null) startReporting(peerConnection);
  },
  soundReady: (peerConnection) => {
    soundConnection = peerConnection;
    reportPlayerState(hasPlayed ? "playing" : "streaming", msidFacts("soundMsids", peerConnection));
    if (soundMeter !== null) return;
    tuneForLowDelay(peerConnection);
    soundMeter = new StatsMeter(peerConnection);
  },
  status: setStatus,
  problem: noteProblem,
  reconnecting: () => {
    if (hasPlayed) reconnects++;
    reportPlayerState("reconnecting", { reconnects });
  },
  closed: connectionClosed,
};

function start() {
  const api = new GstWebRTCAPI({
    meta: { name: `ThumbPartyPlayer-${Date.now()}` },
    signalingServerUrl: signallingUrl(),
    // No STUN here: a session on the same machine or the same Wi-Fi needs none,
    // and asking an outside server would only add delay.
    webrtcConfig: { iceServers: [] },
  });
  const links = new StreamLinks({ api, handlers: linkHandlers });

  api.registerConnectionListener({
    connected: () => {
      setStatus("connected to the TV");
      links.connect();
    },
    disconnected: () => {
      setStatus("lost the TV, reconnecting…");
      links.reconnect();
    },
  });

  api.registerProducersListener({
    producerAdded: () => links.connect(),
    producerRemoved: () => links.reconnect(),
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
  try {
    await playback.unmute();
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
