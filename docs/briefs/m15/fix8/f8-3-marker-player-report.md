# f8-3: the player reads the marker row

## Summary

The player's half of the streaming marker is in. A page option `marker=1`
(`--player-query marker=1`, or `SESSION_PLAYER_OPTIONS=marker=1`; off by default)
makes the page read the host's 57-cell row out of the video element every frame
and time it against the host's clock:

- `streaming/player/marker_decode.js` (177 lines) — the pure decoder,
  `decodeMarker(rows)` → `{ok, counter, hostMs, pressFlip}` or
  `{ok: false, kind, reason}`, the rule in `docs/streaming-marker.md`, plus the
  wrap-safe 32-bit clock gap.
- `streaming/player/marker_reader.js` (263 lines) — one `getImageData` of the
  strip's region per `requestVideoFrameCallback` (rAF fallback), the frame's age,
  the callback's lateness, decoded-to-display, every rVFC field raw, and the flip
  cell's frame for a press; unreadable frames are counted by reason.
- `streaming/player/clock_sync.js` (110 lines) — the NTP-style offset over the
  reporter's existing `/clock` call, shortest round trip of the last five,
  uncertainty = RTT/2, re-measured every 10 s; the off path keeps the old
  middle-sample rule exactly.
- `streaming/player/marker_batch.js` (116 lines) — the per-batch aggregates as
  the sampler's own names (stages/gauges/counters/facts; no Dart reading yet).

Proven by one 20 s probe run (`SESSION_MARKER=on --player-query marker=1`, kept
in `bench-results/f8-3-marker/`): `markerFrames` 1205, `markerReadable` 1205 (no
unreadable frame), `marker_glass` median 368 ms, the independent
`press_to_marker` median 372 (n=39) against the card's `press_to_screen` 238,
offset 3666.5 ms with RTT 20 and uncertainty 10, `stream_display` now 274
(decoded-to-display), the read 5.1 ms a frame. A run with everything off has no
marker key and `stream_display` 0 as before; `SELFTEST PASS 50/50`, the relay's
16 checks pass, `check.sh` is green. One finding to hand over: on this headless
Chrome the marker's press figure is 134 ms above the card's (Hand-over).

## Files changed

- `streaming/player/marker_decode.js` (new): the pure decoder and the row
  constants (57 cells, the thresholds, the checksum, the 16-bit counter and
  32-bit clock wraps).
- `streaming/player/marker_reader.js` (new): the per-frame read, the times, the
  metadata, the count of unreadable frames and the press from the flip cell.
- `streaming/player/clock_sync.js` (new): `parseClockAnswer`, `chooseSample`
  (`median` and `minRtt`), `ClockSync` with `ping`/`state`/`toHostMs`.
- `streaming/player/marker_batch.js` (new): the names, units and containers a
  batch carries, and the facts' "min median max" text.
- `streaming/player/metrics.js`: `medianOf`, `percentileOf` and `viewerCounters`
  moved here out of the reporter (which stays under its 380-line limit: 366).
- `streaming/player/options.js`: `markerEnabled(options)` (`1`, `true`, `on`,
  `yes`); unknown keys are still kept for later.
- `streaming/player/reporter.js`: builds the clock (mode by the marker flag) and
  the reader, gives the reader the frame callback and the probe's press list,
  adds the marker's names to every batch, clears the reader's samples after a
  batch, and takes `stream_display` from decoded-to-display when it exists.
- `streaming/player/player.js`: passes `marker: markerEnabled(options)`.
- `streaming/player/serve.py`, `streaming/player/relay_test.py`: serve and check
  the four new modules (`marker_selftest.html` is deliberately not served: it is
  not part of the app).
- `streaming/player/marker_selftest.html` (new): 50 checks — the six spec
  vectors, the same rows through a 3x3 blur, ±25 of noise and 16-level
  quantisation, every reason a row is refused, `markerGapMs` across the wrap,
  the options, and the clock estimate's selection and arithmetic.
- `streaming/bench.sh`: `--selftest` serves the player folder to the headless
  Chrome in the image and reads the page's verdict back with `--dump-dom`.
- `tools/stream.sh`: `selftest` also runs the page's checks.
- `streaming/README.md`, `docs/streaming-marker.md`, `docs/dev-tools.md`: the
  switch, the names and units, the self-test.
- `docs/briefs/m15/bench-results/f8-3-marker/marker0.json`, `switches.txt`: the
  probe run kept as evidence.

## Decisions

1. **No node in the distro, so the tests are a page.** The distro's PATH has no
   `node`, and nothing may be installed: `marker_selftest.html` runs the pure
   modules in the image's own headless Chrome, and `streaming/bench.sh
   --selftest` reads its verdict out of `--dump-dom` (with a local HTTP server,
   because module scripts need an origin). `tools/stream.sh selftest` runs it
   after the relay's checks, so the page's tests ride the existing command.
2. **The new numbers ride the four containers the sampler already carries.**
   `ingestStream` accepts only a viewer's `stages`, `gauges`, `counters` and
   `facts` (each capped at 16 per viewer, names ≤32 chars, facts ≤24 chars
   matching `^[A-Za-z0-9 ,._()+-]+$`), so every figure is one of those: row ages
   and the press as stages, the offset and the per-frame figures as gauges, the
   frame counts as counters, and one `rvfc.<field>` fact per metadata field with
   its min, median and max in the field's unit. The probe run fills 14 of the 16
   stage slots, 10 gauges, 13 counters and 10 facts.
3. **Decoded to display is `expectedDisplayTime − receiveTime` where the browser
   has it**, and `presentationTime − receiveTime` where it doesn't, with
   `markerDisplayFrom` (a fact) saying which: `expectedDisplayTime` is the
   browser's own estimate of the frame's display, so the figure ends at the
   display rather than at the frame's media timestamp. Both are read from one
   frame's metadata, so the difference is a duration whatever origin that build
   uses (`presentationTime` read 22.25–25.20 s here while the host's uptime was
   minutes: this Chrome's timestamps are not the page's clock, so only the
   difference between two of them is used). `stream_display` now carries it, and
   keeps the old callback figure on a browser that gives no metadata. The
   callback's lateness against `expectedDisplayTime` is kept as a second gauge.
4. **The press list is the latency probe's, not the relay's record.** The
   reporter already polls `GET presses` for the card's measurement and each
   entry carries the host's own `hostMs`; the reader reuses that list and never
   fetches anything itself, so one press has one host time and the two figures
   can be compared.
5. **The offset is measured, not assumed.** The row carries the host's own
   clock, but the callback's time is the page's; the reader needs the
   difference. The reporter's existing `/clock` round trip is reused with the
   NTP estimate (offset = host − midpoint, RTT = the round trip), and the marker
   keeps the shortest-RTT sample of the last five (uncertainty = RTT/2) while the
   card keeps the middle sample, so an off run's numbers are bit-for-bit what
   they were.
6. **Unreadable frames are counted, never guessed.** The decode returns a reason
   (`checksum`, `sync`, `level`, `border`, `crop`) and the reader keeps them as
   counters, with `canvas` for a `getImageData` a tainted canvas refuses; a
   frame with no reading contributes no time.
7. **The reader touches only the strip.** Its canvas is `57 × cellPx` by
   `cellPx` at the element's own width, and it draws only that rectangle out of
   the video element, so the per-frame cost does not grow with the picture.
8. **A missing metadata field is missing.** Each rVFC field is recorded only
   when it is a finite number; the run's facts have nine `rvfc.*` entries and no
   `captureTime`, which this Chrome does not give. Nothing is written as 0.
9. **The clock gap is read modulo 2^32.** The row carries the low 32 bits, so
   `markerGapMs` takes the signed 32-bit difference; the self-test covers a gap
   across the wrap (and a negative one).

## Checks run

- `bash -n streaming/bench.sh streaming/entrypoint.sh tools/stream.sh`: OK.
- `streaming/bench.sh --selftest` in the distro: `SELFTEST PASS 50/50`.
- `streaming/player/relay_test.py` in the distro: `relay test: 16 checks passed`.
- `tools/check.sh format analyze metrics tv`: format PASS, analyze PASS, metrics
  PASS (157 tests), tv PASS (93 s in all).
- One 20 s probe run in the distro, `--probe --seconds 20 --set
  SESSION_MARKER=on --player-query marker=1 --label f8-3-marker` (`switches:
  SESSION_MARKER=on, player-query marker=1, player-options none`); ready after
  6 s, the window ended after 33 s, one viewer `browser/chrome-headless`, 2096
  kbit/s against the 10000 ceiling, game 21.3 ms/frame, build 0.9 + raster
  6.2 ms, summary 5719 bytes. Its viewer read:
  - stages `marker_glass` n=8 median 368 p95 379 max 379; `marker_glass_p95`
    n=8 median 386 (the batch's own p95, so a run can read both); the row's
    `press_to_marker` n=39 median 372 p95 400 max 407; `stream_display` n=8
    median 274 p95 292 (decoded to display); beside them the run's
    `press_to_screen` n=38 median 238 p95 386 and `stream_total` 567.
  - gauges `markerOffsetMs` 3666.5 (n=8), `markerOffsetRttMs` 20.0,
    `markerOffsetUncertaintyMs` 10.0, `markerCallbackLateMs` mean −4.18 (the
    callback runs ~4 ms before the frame's expected display), `markerDecodeDisplayMs`
    mean 186.56 p95 292.2, `markerReadMs` mean 5.1 p95 7.29.
  - counters `markerFrames` 1205, `markerReadable` 1205, `markerChecksumBad` 0,
    `markerSyncBad` 0, `markerCanvasBad` 0, `markerOtherBad` 0 — every frame the
    page read decoded, at 1920×1080 and 10 Mbit/s.
  - facts `rvfc.presentationTime` `22.25 23.75 25.20`, `rvfc.expectedDisplayTime`
    `22.25 23.76 25.20`, `rvfc.receiveTime` `21.97 23.47 24.91`,
    `rvfc.processingDuration` `0.9 2.4 8.3`, `rvfc.presentedFrames`
    `1117 1199 1275`, `rvfc.width` `1920 1920 1920`, `rvfc.height`
    `1080 1080 1080`, `rvfc.mediaTime` `20.84 22.35 23.81`, `rvfc.rtpTimestamp`
    `0 135301 265009` (90 kHz ticks, relative), `markerDisplayFrom`
    `expected-receive`; no `rvfc.captureTime` (absent, not 0).
  - the read's cost inside the run: 5.1 ms a frame on average, 7.3 at p95, in
    the page's own timer around the strip's `getImageData` and decode, against
    the game's 21.3 ms/frame and 56 delivered fps.
- One 20 s probe run with everything off (`--label f8-3-off`, `switches: none`):
  no `marker*` name in any container, `stream_display` n=8 median 0 as before,
  8 counters and 3 facts (the pre-fix set), `press_to_screen` n=37 median 174,
  game 20.9 ms/frame. Off, the page reads nothing new.

## Self-check (review-rules, part A)

1. **Every host setup:** not affected — the reader exists only in the browser
   page, and the host's picture already carries the row; a phone viewer with
   `marker=1` reads the same row and needs no host change or rebuild (the page is
   served by the session, so an older host and a newer page still work, and an
   unknown option key is kept). Only headless Chrome was run here; a phone is
   the owner's to run.
2. **When kept state starts and ends:** the clock's ping timer lives in the
   reporter's timer list and starts on `start()`, is cleared by `stop()`, and a
   reconnect builds a new clock and reader; each batch clears the reader's
   samples and the probe's sent presses. With no offset yet (the first second,
   or a host that doesn't answer) `toHostMs` is null and no row time is recorded
   — shown by `marker_glass` n=8 in 8 batches only after the first ping, and by
   the empty-summary check in the self-test.
3. **How a new state combines with the others:** the reader is read-only and
   never touches game, pause or input state; it holds no timer of its own beyond
   the frame callback the reporter already runs, and that callback is the same
   two paths (rVFC and the rAF fallback) the page had.
4. **Stay in the job's folder:** every written file is in `allow:` (checked
   against the brief's list; the two new evidence files are under
   `docs/briefs/m15/bench-results/`). `git status` also lists six
   `tv_test_app/*/flutter/generated_plugin*` files and an untracked
   `docs/briefs/m15/c2/results/bench/`: they were already dirty when this run
   started (their mtimes are before the first edit here, and `git diff` on them
   is empty — line endings only), and nothing here touched them.
5. **Stop rather than overstep:** nothing needed outside `allow:`; the one open
   question (the 134 ms gap) is reported, not acted on.

## Hand-over

- The player's half is complete and off by default; `marker=1` needs the
  session's `SESSION_MARKER=on` row to read something, and says so by counting
  every frame unreadable.
- The marker's press figure (372 ms, ±10 from the offset) and the card's
  `press_to_screen` (238 ms) are the same press read from one picture, and
  they disagree by ~134 ms on this headless Chrome. The evidence points at the
  card side: the flip frame's own row stamp lands 4 ms after the press
  (`marker_glass` 368 against `press_to_marker` 372), so the press's own flip is
  in the frame right after it, while the card's samples are bimodal (median 238,
  p95 386) — consistent with the probe sometimes matching the card's own 500 ms
  cadence flip, because it starts sampling every frame only after its 200 ms
  press poll. Worth a look in f8-4/f8-6 before the milestone quotes a
  press-to-screen number; not changed here.
- A probe run now uses 14 of the 16 stage slots per viewer, 13 counters and 10
  facts: the next addition to either may overflow the cap.
- `stream_display` is now decoded-to-display when the marker is on and the old
  callback figure when it is off, so a run's `stream_display` means two things
  depending on the switch; the `markerDisplayFrom` fact says which on the marker
  side.
- The self-test page is not served by `serve.py`; it is read only by
  `bench.sh --selftest` and `tools/stream.sh selftest`.

## Commit message

marker=1: the player reads the host's row out of the video

The page's half of the streaming marker (M15 fix8): a new decoder, a per-frame
reader of the strip's region, an NTP-style page-to-host offset over the
existing /clock call, and per-batch names the sampler carries (row age, offset
and RTT, every rVFC field raw, decoded-to-display, and an independent
press-to-marker from the flip cell). Off by default; `marker=1` switches it on.
Tests: 50 page checks run by bench.sh --selftest (no node in the image), the
relay's 16, and one 20 s probe run that read 1205 of 1205 frames with a 10 ms
offset uncertainty.

## Status row

f8-3 done: the player's marker half (decode, reader, clock offset, batch names,
50-check page self-test, one 20 s probe run) is in and off by default; open: the
134 ms gap between `press_to_marker` and `press_to_screen`, and a phone run.

## Delete

- none
