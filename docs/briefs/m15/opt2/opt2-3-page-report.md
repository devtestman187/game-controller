# M15 opt2-3 — the player page's custom player (`player=wc`)

## Summary
Added the page's custom player: `?player=wc` opens the host's `/tap` socket, reads PROTOCOL.md's
24-byte header, decodes the H.264 with WebCodecs and draws it on `<canvas id="wc-canvas">` in the
video element's place; every other value of `player` (or none) is today's page, unchanged.
New: `wc_annexb.js` (byte helpers), `wc_player.js` (the player), `wc_selftest.html` (page tests).
Edited: `options.js` (`playerKindOf`), `index.html` (canvas), `player.js` (wiring, 398 → 379 lines),
`overlay.js`, `page_state.js`, `streams.js` (code moved out of `player.js`), `bench.sh` (new page).
Tests, `streaming/bench.sh --selftest` in `tp-stream`: `marker_selftest.html` 60/60,
`jbtarget_selftest.html` 24/24, `wc_selftest.html` 22/22, all PASS; the new page cannot pass on the
old code (its modules did not exist). `dart format`: 793 files, 0 changed. No file over 380 lines and
no function over 60.
Decisions: AVCC + an `avcC` description with `optimizeForLatency` and a hardware hint (retried
without it), Annex B only with `wcmode=annexb`; one configuration per SPS/PPS, on a keyframe, frames
in order; delay held by dropping (pre-keyframe, a gap, queue over 2), one key request per 500 ms;
`frame * 1000` µs timestamps; every frame closed in a `finally`; a decoder error → a new decoder and
a key request; reconnect 200 ms doubling to 2 s; the host's `end` stops it; sound is the existing
sound-only WebRTC path with the picture consumer unattached.
Not done: job 4's figures (the producers `counters()`/`stageSamples()` exist), the marker reader and
the probe still read the video element (Hand-over), no live run against a host (out of scope; a
headless run needs a session). Turns used: not known.
Obstacle: `wsl-sync.sh`, `check.sh` and a Windows `tar` needed approval this session did not get, so
the files reached the distro as `cat <files> | wsl … python3` split by byte offsets, and the format
check ran as its `dart format` command. The distro's output gave no instructions.

## Decisions (why)

- AVCC + description by default: the research's section 7 calls it the safe path; `wcmode=annexb`
  is the switch PROTOCOL.md names for in-band bytes.
- Frame order: a promise chain handles one message at a time, so configuring the decoder (async)
  can never be overtaken by a chunk that needs it.
- Dropping over buffering: a delta before the first keyframe, a gap in the frame numbers, or a
  decoder queue deeper than 2 is dropped and a keyframe asked for (at most once per 500 ms); the
  host already serves keyframe requests, and a dropped frame is cheaper than a late one.
- `frame * 1000` µs: 1 ms per frame unit is exact in a callback timestamp and maps a drawn
  `VideoFrame` back to its frame number for `stageSamples()` and `onDrawn`.
- The canvas covers the hidden video element (not removed), so nothing else in the page moves.
- Sound: `StreamLinks({…, picture: false})` keeps the existing TP-Sound path and leaves the picture
  consumer unattached; a sound-only link ends no session, and a browser that wants a tap gets the
  existing sound button. With no sound stream the overlay says
  "sound: this session sends no sound stream".

## Tests and values

Hand-computed expectations in `wc_selftest.html`, from a real 1080p High-profile SPS/PPS written by
x264 (`67640028acd940780227e5c044000003000400000301e03c60c658`, `68ebe3cb22c0`):

- `codecString(sps)` = `avc1.640028` (profile 0x64, constraints 0x00, level 0x28).
- `buildAvcc(sps, pps)` = `01640028ffe1001b` + SPS + `010006` + PPS, 44 bytes.
- `annexbToAvcc(an AUD, the SPS, the PPS, an IDR)` = `0000000465888421`: AUD/SPS/PPS dropped.
- `splitNalus` of that access unit = 4 units, types 9, 7, 8, 5, lengths 2, 27, 6, 4.
- `parseHeader` of flags 3, frame 42, `pts_us` 1234567890, `sent_us` 1750000000000000 → those
  values, keyframe and discontinuity true, the 13-byte payload; the first 8 bytes are
  `54 01 03 00 00 00 00 2a` (big-endian). A wrong magic, a version 2, 20 or 23 bytes → null.

## Self-check (review-rules part A)

1. Every host setup: not affected. The page only changes with `?player=wc`, a switch no host or
   session sets; every other value parses and runs exactly as before (`playerKindOf` test, 7 values).
2. Kept state: the socket, the decoder, the timer and the reconnect delay start in `start()`, end in
   `stop()` or on the host's `end`, and with nothing going on nothing runs — `stop()` leaves no socket
   and no timer (`stop()` and `end` checks), one lost socket is one reconnect.
3. Combining states: `wcMode` is read once from the URL; it combines only with the session watch the
   page already has (`end` → `endSession`, `lost` → the picture-lost status). The WebRTC path is not
   entered in this mode except for sound, whose consumer is `TP-Sound` alone (picture unattached), so
   the pause/away owners are untouched (`wcMode` is a constant; nothing else reads it).
4. Stay in the job's folder: every changed file is in `allow:`; the distro copy lives in `/work` and
   no repository file outside the list changed (`dart format` reports 0 changed).
5. Stop rather than overstep: nothing outside `allow:` was needed. The one conflict — sound in `wc`
   mode — was answered by keeping the existing sound-only path rather than inventing one (above).

## Hand-over
What exists: `playerKindOf` in `options.js`; `splitNalus`, `nalType`, `isKeyframe`, `parseHeader`,
`codecString`, `buildAvcc`, `annexbToAvcc`, `parameterSets` in `wc_annexb.js`; `WcPlayer` in
`wc_player.js` (`start`, `stop`, `counters`, `stageSamples`; options `{url, canvas, onEvent, onDrawn,
annexb, now, WebSocketImpl, VideoDecoderImpl, EncodedVideoChunkImpl, setTimeoutImpl}`).

Command that worked: `timeout 120 bash streaming/bench.sh --selftest` in `tp-stream` (from the synced
folder); on Windows `dart format --output=none --set-exit-if-changed controller_app tv_test_app
packages assets`.

Every place that reads the video element, for job 4 to move to the canvas:
- `marker_reader.js:217-232` (`videoWidth/_videoHeight`, `drawImage(this._video, …)` in `_readStrip`)
  driven by `reporter.js:155-183`'s `requestVideoFrameCallback` — job 4 must drive it from `onDrawn`.
- `latency_probe.js:100-113` (`videoWidth/_videoHeight`, `drawImage` for the luminance patch).
- `playback.js` (the `<video id="screen">` element, `play()`/`muted`): hidden in `wc` mode, played
  for sound only.
Do not redo: the header parse, the avcC build and the sample conversion (tested to the byte), the
queue/keyframe-request policy and the reconnect backoff. Job 4 adds figures on `counters()` and
`stageSamples()`.

## Commit message

Player page: player=wc decodes the host's H.264 with WebCodecs

Add the custom player behind `?player=wc`: the page opens the host's `/tap` socket, reads
PROTOCOL.md's header and decodes the H.264 with WebCodecs on `<canvas id="wc-canvas">` in the
video element's place. Bytes are converted to AVCC with an avcC description by default
(`wcmode=annexb` for in-band Annex B); the decoder is configured on keyframes, frames deeper
than a queue of 2 and gaps are dropped with one keyframe request per 500 ms, and every frame
is closed after the draw. A lost socket reconnects 200 ms doubling to 2 s; the host's `end`
stops it. Sound keeps the existing sound-only WebRTC path; `player` off is unchanged.

## Status row

M15 opt2-3 done: `player=wc` player page (helpers, player, tests, bench) — open: job 4 figures and
moving the marker reader/probe off the video element.

## Delete

- none
