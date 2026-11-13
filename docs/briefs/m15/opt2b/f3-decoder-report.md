# M15 opt2b-3 (decoder) — report

## Summary

A decoder error now closes the decoder, makes a new one, asks for a keyframe and carries on; the
page says "decoder error, restarting" (never "stopped") and the line goes back to normal on the
first frame drawn afterwards. Errors are counted, sent and reported. Root cause of the owner's
"the decoder stopped: Decoder failure": **suspected** — the old path left the page's message up for
good and asked for a keyframe on every error with no limit, so a stream a browser cannot decode
(the tap is 4:4:4, avc1.F4002A) never settled.

- `wc_decoder.js` (new, 317): the VideoDecoder, its configuration from the SPS/PPS, the error and
  rebuild policy, the last error's text. `wc_player.js` 380 → 318 and owns only the socket, the
  drops and the canvas.
- `wc_annexb.js`: `isFourFourFour(sps)` — profile 244/110/122/44.
- Rebuild policy: one rebuild per 500 ms, and once five came in ten seconds, one per second; every
  error still counts and the message stays up until a frame is drawn.
- `configure` throwing and `isConfigSupported` rejecting are errors the same way.
- 4:4:4 the browser refuses: the page says "the host sends 4:4:4; Safari cannot decode it", the
  fact says `cfg 444`, and no frame is decoded and no keyframe asked again.
- The first sample after a configuration or a rebuild is always a keyframe, refused otherwise.
- `wc_stats.js`: `wcDecoderErrors` / `wcDecoderRebuilds` as gauges, `wcerr` as a second fact
  (name first, 24 characters, none before the first error), `cfg 444` in the `wc` fact.
- `report_stream_wc.dart`: three new columns (errors, rebuilds, error).
- Tests: `wc_stats_selftest.html` 16 → **28/28** (12 new), `wc_selftest.html` 30/30,
  `marker_selftest.html` 60/60, `jbtarget_selftest.html` 24/24; metrics package **167 tests pass**,
  `dart format` 0 changed, `tools/check.sh format` PASS.
- Not done: the overlay's own wc line does not show the errors (not asked); `player.js` and
  `overlay.js` needed no change (see decision 4).

## Decisions (why)

1. The decoder's code went into `wc_decoder.js` because `wc_player.js` was at the 380-line cap; what
   stayed is the socket, the frame drops and the canvas, and the decoder is handed each keyframe's
   payload and each sample.
2. The new checks are in `wc_stats_selftest.html`, not `wc_selftest.html`: that page is at its
   500-line test cap, a new page file is outside `allow:`, and the figures these checks read
   (`wcDecoderErrors`, `wcerr`) are that page's subject anyway. The page went 490 → **500** lines
   exactly: the fakes and one payload were written compactly to stay inside the cap.
3. Errors are sent as **gauges**, not counters: `reporter.js` (outside `allow:`) takes only stages,
   gauges and facts from an extra series, and a gauge's max is the last value a growing total had —
   the same way `wcDropped` and `wcKeyRequests` are sent and printed.
4. The page's line is cleared with an empty `status` event, so `player.js` and `overlay.js` stay
   untouched (both were at 380 and 197 lines): `wcEvent` already shows any status text, and the
   empty text only goes out when the decoder had a message up, so no other message is blanked.
5. The error text joins name and message with a space, not ": ": the host's fact rule
   (`stream_stats.dart`'s `_technicalPattern`) has no colon, so `EncodingError: boom` would be
   dropped and the fact would never arrive.
6. A 4:4:4 profile is refused for good only when `isConfigSupported` says no to both
   configurations, as the brief says. A browser without that check (Safari, f1 decision 7) takes
   the configuration, fails to decode and lands in the gated rebuild loop instead — see question 1.
7. `_refused` is checked at the top of `_handleFrame`, so a refused stream costs nothing per frame:
   no drop counters, no keyframe requests, only the socket's bytes and the fact.

## Tests and values

`wc_stats_selftest.html`, 12 new checks, all on the fake VideoDecoder/chunk/socket and a fake clock:

- error at 1000 ms: 1 close, a second decoder in state `unconfigured`, `decoderErrors` 1,
  `decoderRebuilds` 1, message `decoder error, restarting`; after re-configuring, a delta is
  refused and the keyframe is the only chunk (`["key"]`), the new decoder configured once.
- second error at 1100 ms with the last rebuild at 1000: no third decoder at once, one timer of
  **400 ms** (1500 − 1100), which makes the third decoder.
- rebuilds at 0, 500, 1000, 1500, 2000 ms (five in the window): the next error waits **500 ms**
  (ready at 3000) instead of 1000, and running the timer gives the seventh decoder; `decoderRebuilds`
  5 before it.
- `configure` throwing: `configureFor` false, old decoder closed, a new one, errors 1, rebuilds 1,
  one message.
- `isConfigSupported` rejecting: `configureFor` false, errors 1, `lastDecoderError` `Error no check`,
  old decoder closed.
- 4:4:4 (SPS `67f4002a…`, codec string `avc1.F4002A`) with both configs refused: two static checks,
  **no** key request before or after a second keyframe, one message, `decodeConfig` `444 avc1.F4002A`
  and the fact `cfg 444 dec no`.
- first sample: delta false, key true, delta after the key true, chunks `["key", "delta"]`.
- `decoderErrorText`: `EncodingError Cannot decode 12` (the `<`, `>` and `#` are dropped), and a long
  message cuts at **60**.
- the batch carries `wcDecoderErrors` 3, `wcDecoderRebuilds` 2 and the fact
  `wcerr` = `EncodingError boom`; `wcErrorFactText` cuts `EncodingError Cannot decode this frame`
  to **24** = `EncodingError Cannot dec`, and "" stays "".
- the whole player: error → one status `decoder error, restarting`, then a drawn frame → one status
  "" (the line back to normal) and `decoderErrors` 1.
- the whole player on a 4:4:4 stream with both configs refused: nothing sent on the socket, no
  chunk decoded, two static checks, one message.

Dart, `report_stream_wc_test.dart`: errors 1 then 2 → `2`, rebuilds 1 then 2 → `2`,
`wcerr` `EncodingError boom` in the last column; a page with only the rate and the fact shows a dash
in all eight number columns.

Runs: `timeout 300 bash streaming/bench.sh --selftest` in `tp-stream` → 60/60, 24/24, 30/30,
**28/28**; `dart test` in `packages/metrics` → **167 tests passed**;
`dart format --output=none --set-exit-if-changed` on both Dart files → 0 changed;
`tools/check.sh format` → PASS.

Before the code, the two pages were failing for the right reason (the module `./wc_decoder.js` did
not exist, `wcErrorFactText` was not exported, the wc table had no error columns).

## Self-check (review-rules part A)

1. Every host setup: the page, not a host — nothing here runs on a TV, PC, phone host or joined
   phone; the wc path exists only in `streaming/player` behind `player=wc`, and a page one build
   older sends no decoder numbers, which the new columns show as dashes.
2. When kept state starts and ends: `decoderErrors`/`decoderRebuilds`/`lastDecoderError` start at
   0/0/"" with the player and never reset; `_rebuildAtMs` keeps only the last ten seconds;
   `_message` is cleared by the first frame drawn after it; the pending rebuild timer is cleared by
   `close()` (`stop()` and the host's "end"), and its callback also refuses to run after a stop.
3. Combining with other states: a rebuild only drops frames and asks for a keyframe; the page's line
   is cleared only when the decoder had said something, so "lost the TV, reconnecting…" and
   "tap the screen to start the sound" are untouched; a refused 4:4:4 stream changes nothing else
   (the socket keeps counting bytes and the fact reports `cfg 444`).
4. Stay in the job's folder: writes only to the files in `allow:` and this report; `git status`
   shows the six changed files plus the new `wc_decoder.js`. The six `tv_test_app/*/generated_*`
   entries it also shows are line-ending only (`git diff` has no content), and the untracked
   `run-base` folders came before this job.
5. Stop rather than overstep: nothing blocked. Left alone, outside `allow:`: `reporter.js` (no
   counters from an extra series, hence decision 3), `stream_names.dart` (the new names are private
   constants in `report_stream_wc.dart`), `bench.sh` (no new page in its list).

## Hand-over

What exists: `wc_decoder.js` (`WcDecoder`: `start`/`close`/`configureFor`/`decode`/`failed`/
`noteDrawn`/`counters`/`queueSize`/`refused`, plus `decoderErrorText`), `wc_player.js` on top of
it, `isFourFourFour` in `wc_annexb.js`, the two gauges and two facts in `wc_stats.js`, the error
columns in `report_stream_wc.dart`, and the decoder's checks at the end of the wc group in
`wc_stats_selftest.html`.

Commands that worked:
- `tools/wsl-sync.sh tp-stream`, then in `tp-stream`:
  `timeout 300 bash streaming/bench.sh --selftest`.
- `cd packages/metrics && dart test`; `dart format --output=none --set-exit-if-changed <files>`.
- `tools/check.sh format`.

Don't redo: the error path is one path — `failed()` is what every error, thrown `configure` and
rejected `isConfigSupported` goes through; don't add a second status message for it.
`wc_selftest.html` is still at 500 lines and `wc_stats_selftest.html` is now at 500 too: split
them (with a new `wc_decoder_selftest.html` and a `run_page_selftest` line) before adding a check
to either.

Open problems: on a browser without `isConfigSupported` (Safari) the 4:4:4 message never appears;
such a stream stays in the 1-rebuild-a-second loop with "decoder error, restarting" (question 1).

## Questions and suggestions

1. Safari has no `isConfigSupported` (f1 decision 7), so `cfg 444` and the 4:4:4 message only reach
   it if a *repeated* decode failure on a 4:4:4 SPS also stops the retries. The brief ties the stop
   to the static check, and Safari did show a moving picture once, so I did not add it. Should a
   stream that keeps failing on a 4:4:4 SPS stop after the burst?
2. `reporter.js` could pass an extra series' counters on, which would let `wcDecoderErrors`/
   `wcDecoderRebuilds` be counters as the brief's words suggest; today they are gauges (max = total).
3. The three new names belong in `StreamWc` (`stream_names.dart`), which is outside `allow:`; they
   are private constants in `report_stream_wc.dart` for now.
4. A later job could give the decoder's checks their own page (`wc_decoder_selftest.html`) and add it
   to `bench.sh`'s list; f5 already adds `secure_selftest.html` there.
5. The overlay's wc line could show `err N rb N` in the numbers box; not asked, so not added.

## Commit message

Player page: a decoder error rebuilds the decoder and carries on

`wc_player.js` gave its decoder to a new `wc_decoder.js` (it was at 380 lines): an error — the
decoder's own, a `configure` that throws, a rejected `isConfigSupported` — closes it, makes a new
one and asks for a keyframe, at most one rebuild per 500 ms and one a second after five in ten
seconds, and the first sample after a rebuild must be a keyframe. The page says "decoder error,
restarting" instead of "stopped" and the line clears on the next frame drawn. A 4:4:4 stream the
browser refuses is said once (`the host sends 4:4:4; Safari cannot decode it`, fact `cfg 444`) and
never asked for again. Errors, rebuilds and the last error's text ride the batch as
`wcDecoderErrors`, `wcDecoderRebuilds` and the `wcerr` fact, and the report's Custom player table
gained the three columns.

## Status row

M15 opt2b-3 done: decoder errors rebuild, are gated, counted, sent and reported, and a refused
4:4:4 stream stops asking — open: the same stop for a browser without `isConfigSupported`
(question 1), and the decoder's checks still live in `wc_stats_selftest.html`.

## Delete

- none
