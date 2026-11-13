# M15 opt2c-5 (card vs marker): both readers read the frame that was just drawn

## Summary

- **Cause.** `streaming/player/latency_probe.js:66` read the card's patch only
  every 8th frame when no press waited, kept no flip, and only timed presses it
  already knew; `reporter.js:126` polls `/presses` every 200 ms, so a press's
  own flip was usually drawn before the page learned of it and the press
  matched the card's next 500 ms cadence flip (the brief's p95 392-471 ms; the
  marker's small). The marker kept its flips and matched retroactively.
- **Fix.** One `FrameReadback` per picture (`sharedReadback()`,
  `marker_reader.js:84`): the strip's middle three rows and the card's 8 px
  patch in two `drawImage`s, one `getImageData`, cached by the draw's own stamp
  that `drawnFrame(drawnAtMs, ...)` gives both readers. Every drawn frame is
  read (no 8th-frame sampling, no second 1x1 canvas), 3 of 16 rows (the same
  3x3 centre mean for every cell).
- **Flips kept.** The probe keeps the card's flip host times (`_flipsMs`, 200)
  and times a press against the first flip at or after it — the marker's rule —
  still dropping a flip a whole cadence late. One difference stays, pinned: the
  card's own cadence flip can be the first change after a press (100 ms against
  the marker's 300 in the test).
- **Cost.** The readback times itself; `wcReadMeanMs`, `wcReadMaxMs`, and
  `wcDrawMeanMs` (decode output → drawn) go as stages in "Custom player (wc)".
  Fake canvas: 0.04 ms mean / 0.20 ms longest against 0.09 ms for the old
  full-height strip read plus a separate card read.
- **Tests.** `wc_card_selftest.html` 8/8 (new; the old code failed it 3/5), all
  nine page self-tests, `report_stream_wc_test.dart` 8/8, format PASS.

## Cause and fix

- `streaming/player/latency_probe.js:64-73` (old): the patch was read on every
  frame only while a press waited; otherwise every 8th, and a flip seen was
  used at once and forgotten.
- `streaming/player/reporter.js:126` polls the presses every 200 ms, so a press
  is known at least one poll after it happened; its frame is usually already
  drawn. `latency_probe.js:132-153` (old) then matched the next change it saw —
  the card's own cadence — and dropped it as expired if it was 500 ms or more.
- The marker (`marker_reader.js`, `_noteFlip`/`_timePresses`) keeps the flip
  host times and matches a press to the first flip at or after it, so the late
  poll costs it nothing.
- Now both read `sharedReadback(picture)` in the same `drawnFrame` callback with
  the draw's own time; the probe reads every drawn frame and matches presses
  retroactively (called from `watch()` and at the end of `poll()`); the
  marker's decode time is added to the readback's read for `markerReadMs`.

## Decisions

- The three read figures are **stages**, not counters: a wc page's extras
  cannot carry counters (`combinedSeries` in `wc_stats.js` forwards stages,
  gauges, facts and video only, and `reporter.js` was outside `allow:`), and a
  wc viewer's 16 gauge slots are full. So `wcReadMeanMs`/`wcDrawMeanMs` are the
  median of the interval means and `wcReadMaxMs` the run's longest read, which
  the table prints as "read ms", "read max ms", "draw ms".
- One readback canvas and one `getImageData` for both regions (the brief allows
  a union region or two small regions in the same turn): the strip's middle
  three rows at the top, the card's pixel as one more row under them.
- The marker reads the strip locally (video mode) with no card watcher, so it
  pays for nothing it does not use; the card alone reads a 1 x 1 region.
- The card's cadence-flip ambiguity is not removed but pinned in the test,
  because the card's two states cannot tell a press's flip from its own.

## Files changed

- `streaming/player/marker_reader.js` (376): `cardPatchPx`, `cellRowsRead`,
  the readback WeakMap, `sharedReadback()`, `FrameReadback`
  (`watchStrip`/`watchCard`/`read`/`totals`, one scratch canvas, strip's middle
  rows + card patch, cache by stamp); `MarkerReader` uses it and adds the
  read's time to the decode; `metadataFields` and the pixel loop moved out.
- `streaming/player/marker_batch.js` (136): owns `metadataFields` (moved).
- `streaming/player/marker_decode.js` (201): `luminanceRows()` (moved loop).
- `streaming/player/latency_probe.js` (152): reads the shared readback's card
  patch on every drawn frame, keeps flip host times, matches presses
  retroactively; 1x1 canvas, `patchSizePx`, `patchEveryNthFrame` and the
  `luminanceOf` import removed.
- `streaming/player/wc_counters.js` (230): `readCostNames`, `ReadCost`
  (interval mean read, the readback's longest, the draw's mean).
- `streaming/player/wc_stats.js` (379): `wcNames.readMean/readMax/drawMean`,
  `reads` part and `this._cost`, the three stages in `batch()`, `wcStatsOf`
  4th argument.
- `streaming/player/player.js` (380): imports `sharedReadback`, passes
  `() => sharedReadback(wcPicture).totals()` to `wcStatsOf`.
- `streaming/player/wc_card_selftest.html` (new, 262): eight fake-canvas checks
  (press/flip timing, shared readback, both readers' fields, the cadence
  difference, empty picture, decode, `ReadCost` stages) and the `COST` line.
- `streaming/bench.sh`: `wc_card_selftest.html` in `run_page_selftest`.
- `packages/metrics/lib/src/stream_names.dart`: `StreamWc.readMeanMs`,
  `readMaxMs`, `drawMeanMs`.
- `packages/metrics/lib/src/report_stream_wc.dart` (165): three columns
  ("read ms", "read max ms", "draw ms") and `_stageNumber`.
- `packages/metrics/test/report_stream_wc_test.dart` (325): stages in
  `wcSession()` (read 4/8, max 5/9, draw 2/4), new header and row cells,
  `sublist(8, 14)` for the sound-blocked row.
- `docs/streaming-marker.md` (180): "The card and the marker on one frame",
  the player's half's read description and cost, the cadence difference.

## Tests and numbers

- `wc_card_selftest.html` PASS 8/8. Computed: press at 1000, frame at 1150 →
  card 150 and marker `[150]`; 8 frames after the flip → 30; cadence flip at
  1510 → expired, `flipsSeen` 1; shared readback `reads` 1 for two readers,
  `rows` 3 × 912, card 255, decoded counter 6 / host 5150; `ReadCost` stages
  `wcReadMeanMs` 3, `wcReadMaxMs` 6, `wcDrawMeanMs` 3 (round(10/4) = 3) and
  none without a read; cadence difference 100 vs `[300]`.
- Old code on the same first five checks: SELFTEST FAIL 3/5.
- All page self-tests in tp-stream: marker 60/60, jbtarget 24/24, wc 30/30,
  wc_stats 29/29, wc_diag 13/13, wc_keys 6/6, secure 8/8, wc_sound 13/13,
  wc_card 8/8.
- `COST frames=40 readMeanMs=0.04 readMaxMs=0.20 oldMeanMs=0.09` (twice).
- `packages/metrics`: `/opt/flutter/bin/flutter test
  test/report_stream_wc_test.dart` → 8/8. The host's stage median of two
  samples is the upper one, so read 4/8 → `8.0` and draw 2/4 → `4.0` (first
  expected 6 and 3 and was corrected).
- `tools/check.sh format` PASS (2 s), after the last Dart change.

## Self-check (docs/review-rules.md part A)

1. Host setups: only the browser page's player changed; no app, phone, TV or
   old-build path touches this code, and the page's own tests cover it.
2. Kept state: the readback's frame cache is one frame, replaced on a new
   stamp; totals run for the page's life (sent as deltas/max); flip times are
   capped at 200; presses still end on sent, expired or 2 s; no frames → no
   read and no figure.
3. Combinations: reading does not pause, hide or block; a hidden page draws
   nothing and so reads nothing; the card and marker share no switch, and each
   reader works alone (card only reads a 1 x 1 region).
4. Folder: only files in `allow:` were changed. `tv_test_app/**/generated_*`
   were already modified in the working tree when I started and were not
   touched (see Hand-over).
5. Overstep: none needed; the phone-run comparison is named as the caller's.

## Hand-over

- The real-run split (reading on and off) is the caller's after the image is
  rebuilt: two runs, comparing "read ms" and "draw ms"; the read runs after
  `drawnAtMs` (`wc_player.js:361-366`), so a read that slows the page shows in
  the next frames' lateness and the frame rate, not inside `wcDrawMeanMs`.
- The card's residual ambiguity is unchanged in kind and pinned: its own 500 ms
  cadence flip can be the first change after a press; fixing it needs a card
  state the reader can identify, which the host's card does not draw.
- `wcReadMeanMs` counts one read per drawn frame (cached reads are free).
- The figures are stages (a wc viewer's gauge slots are taken and
  `combinedSeries` forwards no counters); a counter would need a host change.
- `streaming/player/player.js` stays at exactly 380 lines.
- Not run: any real session or phone; `tv_test_app/**/generated_*` were dirty
  before this job and were left alone.

## Commit message

M15 opt2c: the card and the marker read one drawn frame

Both readers now share one FrameReadback per picture: the strip's middle three
rows and the card's 8 px patch in one canvas, one getImageData, cached by the
draw's own timestamp, read on every drawn frame. The latency probe keeps the
card's flip times and times a press against the first flip at or after it — the
marker's rule — so the 200 ms press poll no longer makes a press match the
card's own cadence flip. The readback times itself; wcReadMeanMs, wcReadMaxMs
and wcDrawMeanMs go as stages and show in "Custom player (wc)".

## Status row

M15 opt2c-5 card vs marker: both readers read the frame that was just drawn from one shared readback and the card's flips are timed retroactively (wc_card_selftest 8/8, all nine page self-tests PASS, metrics 8/8, format PASS; fake-canvas read 0.04/0.20 ms against the old 0.09); open: the caller's real-run reading-on/off comparison and the card's cadence-flip ambiguity, pinned in the test.

## Delete

- none
