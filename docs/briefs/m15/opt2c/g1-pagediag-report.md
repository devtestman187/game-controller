# M15 opt2c-1 (page diagnostics): the wc page measures where its own side backs up, and the figures reach the report

## Summary

The custom player measures its own side of a stall and sends the figures with
its batch, so a collapsed phone run can say whether the page's thread, the
decoder or the network fell behind. Measuring only: the draw, drops and keyframe
requests are unchanged.

- `wc_diag.js` (new, 195 lines): `WcDiag` — gaps and their counts, bytes
  received, key and delta sizes, the largest second, the decoder's queue at each
  decode, the 20 ms timer's lateness, its long tasks (PerformanceObserver,
  try/catch, 0 where absent) and the longest onmessage; `noteMessage`,
  `noteDecoderQueue`, `tick`, `snapshot`, plus `noteReconnect`/`noteHandlerMs`.
- `wc_player.js` (361) feeds it, resets gaps on a lost socket and runs the tick;
  `wc_stats.js` (353) sends the 13 gauges; `serve.py` and `bench.sh` carry the
  file and its page test; `metrics` gains the names, the table "Custom player
  diagnostics (wc)" after "Custom player (wc)" and 3 tests.

Checks: page 13/13, all seven pages (60/24/30/29/13/8/13), relay 39, metrics
`dart test` 171, format PASS. Not done: `deltaBytesMax` measured but unsent
(Decisions), and no phone run, so the table is backed by fixtures only.
Obstacles: none blocking; two first-run page-test expectations were wrong and
were fixed in the tests, not the code.

## Computed test values

Page tests (`wc_diag_selftest.html`, fake clock and fake browser classes):

- gaps at 0/40/200/560/600 ms → 40, 160, 360, 40: max 360, >100 = 2, >250 = 1.
- a gap of 700 ms before a reconnect counts (max 700, >250 = 1); the 3300 ms
  wait after it does not; recvBytes 300.
- sizes key 120000 + 80000, delta 3000 + 3240 → recv 206240, key max 120000,
  key avg 100000, delta avg 3120, delta max 3240, largest second 206240.
- largest second: 1000 B at 0, 2000 at 500 (3000), 500 at 1000 (the first
  entry is pruned at 500 ms+ offset) → 3000.
- queue 2/5/3 → 5; handler 4/41/7 → 41.
- ticks 0, 50 (late 30, not counted), 101 (late 31 → max 31), 181 (60), 281 (80)
  → after three ticks max 31, over 50 = 0; after five, max 80, over 50 = 2.
- observer callbacks with 2 and 1 entries → 3 long tasks; no observer and a
  throwing observer → 0.
- wiring: key at 0 and delta at 110 → gapMax 110, >100 = 1, recv 77 + 37 = 114,
  key avg/max 77, delta avg/max 37, largest second 114; gap max 700 across a
  reconnect; decodeQueueSize 2 at a key → decQueueMax 2; ticks at 0 and 120 →
  mainLagMaxMs 100.
- the batch carries the 13 gauges with the fixture's values, and none without a
  diag provider.

Report test (`report_stream_wc_test.dart`): gauges 480, 4, 2, 3500000, 120000,
96400, 3240, 5, 220, 3, 7, 41, 1800000 → row `diag v1 480 4 2 3.5 120/96 3 14.4
5 220 3 7 41`, where 3500000/1000000 = 3.5 MB, 120000/1000 = 120 and
96400/1000 = 96 (rounded), 3240/1000 = 3, 1800000/125000 = 14.4 Mbit/s.

## Decisions

- `serve.py` is at its 381-line ceiling: `wc_diag.js` went into the existing
  `page_files` frozenset line, so the file's line count is unchanged.
- Two members beyond the brief's four: `noteReconnect()` (a gap must not count
  the reconnect wait) and `noteHandlerMs(ms)` (only the player knows the
  onmessage span).
- `deltaBytesMax` is in `snapshot()` but not sent: the brief's gauge list leaves
  it out and the table has no column for it; it is asserted by the page test.
- The figures go as gauges, not counters: a viewer's gauges keep `max`, which is
  what the cumulative figures mean; counters would need a new summary shape.
- Decimal units (1000 B kB, 1e6 B MB, 125000 B/s per Mbit/s) because these are
  network sizes, not memory.
- The diagnostics table shows only viewers that sent `wcGapMaxMs`, so a report
  of an older page is exactly what it was.
- `mainLagMaxMs` records lateness over 30 ms only (the brief's threshold): a
  page that is never late reads 0, not the few ms it drifts.
- A reconnect clears the bytes-per-second window too: the burst after a
  reconnect is measured afresh rather than against a stale second.

## Self-check (review-rules.md part A, items 1-5)

1. Every host setup: nothing outside the `player=wc` page changes (host apps, TV page, WebRTC page), and the untouched `wc_selftest.html` 30/30 and `wc_stats_selftest.html` 29/29 still pass.
2. Kept state starts and ends: counters start at `start()` (observer + interval), end at `stop()` and on the host's `end` (`_stopDiag`), and the gaps restart at each reconnect — tests "the player runs the diagnostics' 20 ms tick and stops it with the page" and "a lost socket starts the gaps again…".
3. Combining with other states: it only measures, so no pause, away, results or link state can pair with it.
4. In the folder: only `allow:` files were written; no scratch file is left anywhere.
5. Stop rather than overstep: no contradiction found; serve.py's ceiling was met without adding a line.

## Hand-over

- Nothing in the repository was run except the selftests: the numbers above are
  fixtures, not a phone's. A real reading needs a `player=wc` run on a phone
  (bench or manual) and `grep -A4 "Custom player diagnostics (wc)"` in the
  report.
- `wc_stats.js` grew from 307 to 353 lines: the next job that adds to it should
  consider splitting the diag gauges into `wc_diag.js`.
- The figures are cumulative per run; if a later job wants per-interval numbers
  (a trace rather than a summary), `WcDiag` needs a reset and the gauges a
  different summary.
- Read the new row as: gap max and the gap counts are the network's, dec queue
  and the sizes are the decoder's input, lag/long tasks/handler max are the
  page's thread.

## Commit message

    Measure where the wc page's own side backs up (M15 opt2c-1)

    Add wc_diag.js: socket gaps and their counts, the bytes received and the
    sizes of key and delta frames, the largest second of bytes, the decoder's
    queue at each decode, the 20 ms timer's lateness, its long tasks and the
    page's longest onmessage. wc_player.js feeds it and runs the tick;
    wc_stats.js sends the 13 figures as wc gauges; serve.py and bench.sh carry
    the file and its page tests. metrics gains the StreamWc names and the
    "Custom player diagnostics (wc)" table, so a collapsed phone run can say
    which side fell behind. Measuring only: draw, drops and key requests unchanged.

## Status row

M15 opt2c-1 done: the wc page measures its own gaps, bytes, decoder queue and thread lag and the report prints "Custom player diagnostics (wc)" (page 13/13, metrics 171); open: a phone run to read real numbers, `deltaBytesMax` unsent.

## Delete

- none
