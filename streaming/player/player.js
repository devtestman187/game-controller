/*
 * The Thumb Party TV player page (M15 c1): plain JavaScript, no build step.
 * It connects to the session's signalling server with gst-plugins-rs' own
 * gstwebrtc-api, plays the stream full screen with the lowest delay the
 * browser allows, and reconnects when the stream drops.
 */

import { markerEnabled, parseOptions, optionsLine, playerKindOf } from "./options.js";
import { JbTarget, jbTargetOf } from "./jb_target.js";
import { LowDelay, lowDelayEnabled } from "./low_delay.js";
import { Overlay } from "./overlay.js";
import { audioMode, identifyPlayer, msidFacts, reportPlayerState, setStaleHandler } from "./page_state.js";
import { Playback, pictureOf, soundOf } from "./playback.js";
import { StreamReporter } from "./reporter.js";
import { createSessionWatch, endedText } from "./session_end.js";
import { StatsMeter } from "./stats.js";
import { signallingUrl, StreamLinks, tuneForLowDelay } from "./streams.js";
import { WcPlayer } from "./wc_player.js";

const GstWebRTCAPI = window.GstWebRTCAPI;

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

// Who this page tells the relay it is (M15 fix8): the name it reports as, and
// the session whose page it loaded. A page left open from an earlier session
// keeps that session's id, so the next session's relay can tell it apart and
// ignore it instead of counting it as a viewer.
const playerName = `ThumbPartyPlayer-${Date.now()}`;
const joinedSession = (window.THUMB_PARTY && window.THUMB_PARTY.sessionId) || "";
identifyPlayer({ pageId: playerName, sessionId: joinedSession });
// The relay saying this page belongs to an earlier session ends it, as its own
// session ending does: it never joins a session it was not served by.
setStaleHandler(endSession);

const screen = document.getElementById("screen");
// The custom player's picture (M15 opt2): with `player=wc` the canvas takes the
// video element's place, decoded by the browser's WebCodecs, and the WebRTC
// connection carries the sound only (SESSION_AUDIO=separate's TP-Sound).
const wcMode = playerKindOf(options) === "wc";
// `wcmode=annexb`: the decoder reads Annex B in band instead of AVCC (M15 opt2).
const wcAnnexb = options.wcmode === "annexb";
const wcCanvas = document.getElementById("wc-canvas");
let wcPlayer = null;
const soundTrack = document.getElementById("sound-track");
const playback = new Playback({ screen, sound: soundTrack });
const statsBox = document.getElementById("stats");
const statusBox = document.getElementById("status");
const toggleButton = document.getElementById("toggle");
const soundButton = document.getElementById("sound");
// The jitter buffer target option (M15 opt1b), null unless `jbtarget=<ms>`: it
// sets the receiver's target and reads it back. It is built before LowDelay,
// which leaves that one property to it when both options are on.
const jbTargetMs = jbTargetOf(options);
const jbTarget = jbTargetMs === null ? null : new JbTarget({ requested: jbTargetMs });
// The zero-delay option (M15 fix7, technique 2), null unless `lowdelay=1`.
const lowDelay = lowDelayEnabled(options) ? new LowDelay({ screen, jitterBuffer: jbTarget === null }) : null;

let reporter = null;
// The page's connections, kept so an ended session can stop them, and whether
// it has ended: an ended page asks for nothing more and joins nothing until it
// is reloaded (M15 fix8).
let links = null;
let ended = false;
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

// The page's own text: its status line, the tab's title that carries the same
// line (how the bench reads a state off a page a run left open, M15 fix8), and
// the numbers the "i" key opens.
const overlay = new Overlay({
  line: statusBox,
  box: statsBox,
  switchesLine,
  lowDelayLine: () => (lowDelay === null ? "" : lowDelay.line()),
  jbTargetLine: () => (jbTarget === null ? "" : jbTarget.line()),
  facts: () => ({ hasSoundStream: soundStream !== null, pictureHasAudio }),
  soundMeter: () => soundMeter,
  onSoundSample: sendSoundJitter,
  onProblem: (text) => overlay.noteProblem(text),
});

// The session is over: say so plainly and stop asking for anything, so a tab
// left open never joins the next session by itself — only a reload does
// (M15 fix8).
function endSession() {
  if (ended) return;
  ended = true;
  overlay.stop();
  stopReporting();
  links?.stop();
  wcPlayer?.stop();
  playback.clear();
  overlay.show(endedText);
}

// The page's session, timed (M15 fix8): a picture that played and has been gone
// longer than a hiccup means the session ended.
const sessionWatch = createSessionWatch({ nowMs: () => performance.now(), onEnded: endSession });

// The custom player's page (M15 opt2): the canvas takes the video element's
// place, with the sound still on the WebRTC path.
function startWcPlayer() {
  screen.hidden = true;
  wcCanvas.classList.add("visible");
  wcPlayer = new WcPlayer({ canvas: wcCanvas, onEvent: wcEvent, onDrawn: wcPlaying, annexb: wcAnnexb });
  wcPlayer.start();
  reportPlayerState("streaming");
}

// What the player's events mean to the page: its end is the session's end, and
// its lost socket is the session watch's lost picture.
function wcEvent(event) {
  if (event.type === "end") return endSession();
  if (event.type !== "lost") return overlay.show(event.text);
  sessionWatch.pictureLost();
  overlay.show("lost the TV, reconnecting…");
}

// The first frame on the canvas is the picture playing: the state a benchmark
// waits for, and the start of the session watch (M15 fix8).
function wcPlaying() {
  if (hasPlayed) return;
  hasPlayed = true;
  sessionWatch.picturePlaying();
  reportPlayerState("playing");
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
    overlay.show(`cannot start the picture: ${error.message}`);
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
    overlay.show("playing");
  } catch {
    soundButton.classList.add("visible");
    overlay.show("tap the screen to start the sound");
  }
}

// What the page is playing, for the state it reports.
function audioModeNow() {
  return audioMode(soundStream !== null, pictureHasAudio);
}

// Starts sending the measurements the host's stats record keeps; the reporter
// reads the same connection's numbers and the frame times the browser gives.
function startReporting(peerConnection) {
  stopReporting();
  reporter = new StreamReporter({
    video: screen,
    peerConnection,
    onProblem: (text) => overlay.noteProblem(text),
    reconnects,
    marker: markerEnabled(options),
  });
  if (jbTarget !== null) reporter.setExtraSeries(() => jbTarget.batch());
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
  sessionWatch.pictureLost();
  overlay.stop();
  stopReporting();
  lowDelay?.stop();
  jbTarget?.stop();
  playback.clear();
  playingStream = null;
  playingPicture = null;
  pictureConnection = null;
  soundConnection = null;
  soundMeter = null;
  overlay.noteProblem("");
  reportPlayerState("closed");
}

// With the picture on the canvas the session's sound is the only WebRTC media
// the page plays (M15 opt2), on the audio element by itself; the picture's own
// stream is never attached.
function playSoundOnly(stream) {
  soundTrack.srcObject = stream;
  soundTrack.muted = false;
  if (stream === null) return;
  soundTrack.play().catch(() => {
    soundButton.classList.add("visible");
    overlay.show("tap the screen to start the sound");
  });
  reportPlayerState(hasPlayed ? "playing" : "streaming", { audio: audioModeNow() });
}

// A stream arrived on the sound's own connection, or null when it is gone:
// the picture is already playing and is not touched (SESSION_AUDIO=separate).
function showSound(stream) {
  soundStream = stream;
  if (stream === null) {
    soundMeter = null;
    soundConnection = null;
  }
  if (wcMode) return playSoundOnly(stream);
  if (playingPicture === null) return;
  playback.show(playingPicture, soundOf(playingStream, splitTracks, soundStream));
  lowDelay?.watch(pictureConnection, soundConnection);
  jbTarget?.watch(pictureConnection, soundConnection);
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
  sessionWatch.picturePlaying();
  lowDelay?.watch(pictureConnection, soundConnection);
  jbTarget?.watch(pictureConnection, soundConnection);
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
    if (!overlay.isSampling) {
      tuneForLowDelay(peerConnection);
      overlay.start(peerConnection);
    }
    // After tuneForLowDelay, whose 0 this option's value must win over (M15 opt1b).
    jbTarget?.watchConnection(peerConnection, pictureConnection, soundConnection);
    if (reporter === null) startReporting(peerConnection);
  },
  soundReady: (peerConnection) => {
    soundConnection = peerConnection;
    reportPlayerState(hasPlayed ? "playing" : "streaming", msidFacts("soundMsids", peerConnection));
    if (soundMeter === null) {
      tuneForLowDelay(peerConnection);
      soundMeter = new StatsMeter(peerConnection);
    }
    jbTarget?.watchConnection(peerConnection, pictureConnection, soundConnection);
  },
  status: (text) => overlay.show(text),
  problem: (text) => overlay.noteProblem(text),
  reconnecting: () => {
    if (hasPlayed) reconnects++;
    reportPlayerState("reconnecting", { reconnects });
  },
  closed: connectionClosed,
};

function start() {
  if (wcMode) startWcPlayer();
  const api = new GstWebRTCAPI({
    meta: { name: playerName },
    signalingServerUrl: signallingUrl(signalPort),
    // No STUN here: a session on the same machine or the same Wi-Fi needs none,
    // and asking an outside server would only add delay.
    webrtcConfig: { iceServers: [] },
  });
  // The custom player's page leaves the picture's consumer unattached: the
  // connection it keeps is the sound's (M15 opt2).
  links = new StreamLinks({ api, handlers: linkHandlers, picture: !wcMode });

  // An ended page listens but no longer asks: a producer of the next session
  // must not bring it back (M15 fix8).
  api.registerConnectionListener({
    connected: () => {
      if (ended) return;
      overlay.show("connected to the TV");
      links.connect();
    },
    disconnected: () => {
      if (ended) return;
      overlay.show("lost the TV, reconnecting…");
      links.reconnect();
    },
  });

  api.registerProducersListener({
    producerAdded: () => {
      if (!ended) links.connect();
    },
    producerRemoved: () => {
      if (!ended) links.reconnect();
    },
  });

  sessionWatch.start();
}

// The button and the keyboard show or hide the numbers; the sound's button
// starts the sound after the tap a browser wants.
overlay.wireToggle(toggleButton);
overlay.wireSoundButton(soundButton, () => playback.unmute());

start();
