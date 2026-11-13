job: M15 opt2b-4 (sound): sound in wc mode plays after a tap and says so in the stats
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2b/CONTEXT.md (whole, first) · docs/briefs/m15/opt2b/f3-decoder-report.md (Hand-over) · streaming/player/player.js (playSoundOnly, startSound, startPlayback, soundButton, sound handlers) · playback.js · streams.js · overlay.js (wireSoundButton) · index.html · page_state.js · wc_stats.js · packages/metrics/lib/src/report_stream_wc.dart · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Context specific to this job: in the sitting, `player=wc` with SESSION_AUDIO=separate played no sound on the iPhone (tapped the picture, mute switch checked). Safari needs sound to start from a user gesture (a tap on an element), and a muted element may start by itself. In wc mode the picture element is hidden and the only media is the sound-only WebRTC connection's audio stream (`playSoundOnly`).

Design (read the code first and find which of these is the real cause; say proved or suspected):
1. Does wc mode ever make the audio-only WebRTC connection when the sound is separate? Check links/StreamLinks (`picture: !wcMode`), that the sound consumer is created, and that an audio element is attached and play() is called.
2. Autoplay: if play() rejects (NotAllowedError) or the sound has not started, show a visible "tap for sound" control (reuse the existing sound button), make a tap ANYWHERE on the page (the canvas too: pointerdown/touchend, once) call play() and unmute within that gesture. The tap must also work when the stream reconnects.
3. Sound state in the stats: fact `wcsnd` with a short word (`none` no sound stream, `blocked` tap needed, `playing`), a gauge `wcSoundPlaying` 0/1, shown in the "Custom player (wc)" table of packages/metrics/lib/src/report_stream_wc.dart (rows with tests) and in the overlay line.
4. Tests first: page tests with fake audio element/play() (reject, then accept after the tap) and the pure stats functions; Dart test for the new rows. No change to the current player (player=webrtc) behaviour.
5. If the real cause is host-side (no audio in the sound-only offer), say so in the report with the evidence, do not fix host files (not in allow).

in the report: `## Summary` first (see CONTEXT.md), `## Hand-over` last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first; `dart format` clean; run the metrics test file you touch.
allow: streaming/player/player.js · streaming/player/playback.js · streaming/player/streams.js · streaming/player/overlay.js · streaming/player/index.html · streaming/player/page_state.js · streaming/player/wc_stats.js · streaming/player/wc_selftest.html · streaming/player/wc_stats_selftest.html · streaming/player/wc_sound.js · packages/metrics/lib/src/report_stream_wc.dart · packages/metrics/test/report_stream_wc_test.dart · docs/briefs/m15/opt2b/f4-sound-report.md · docs/briefs/m15/opt2b/f4-sound
check: format
report: docs/briefs/m15/opt2b/f4-sound-report.md
