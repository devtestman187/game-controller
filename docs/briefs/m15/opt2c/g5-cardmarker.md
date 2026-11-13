job: M15 opt2c-5 (card vs marker): in wc mode card and marker read the same drawn frame, and reading does not slow drawing
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2c/CONTEXT.md (whole, first) · streaming/player/marker_reader.js · marker_batch.js · marker_decode.js · wc_player.js (draw path, onDrawn) · player.js (how the marker reader and the card/latency probe are fed in wc mode: grep canvasPicture, onDrawn, wcDrawn, press, card) · latency_probe.js · docs/streaming-marker.md · docs/briefs/m15/bench-results/20261113-1420*, -1422*, -1424*, -1426* (the four phone runs: marker vs card rows)
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Problem: with player=wc the card press-to-screen reads 15-37 ms LATER than the marker's, and the card's p95 is 392-471 ms (marker's is small). Both should measure the same drawn frame. Also the measuring readback (a canvas draw plus getImageData per read) may slow drawing: unknown.

Design (tests first; new page test files allowed, added to run_page_selftest in streaming/bench.sh):
1. Find the cause by reading the code (not by guessing): where is the card patch read in wc mode, on which cadence (the opposite of the marker's per-drawn-frame read: the card's own 500 ms cadence?), from which canvas state (before/after the frame is drawn, a stale one, a different rAF), and what timestamp is paired with the read (draw time vs read time, performance.now vs host clock). Write the cause in the report with file:line.
2. Fix: both the card and the marker read the frame that was just drawn, driven from the same callback right after the draw (one shared readback per drawn frame when both are on: one drawImage of the union region or two small regions in the same turn), stamped with the draw's own timestamp. A test with a fake canvas: a press at t, a frame drawn at t+X carrying the card patch and the marker strip, both readers report the same frame number and the same timestamp within 1 ms; the old code fails it.
3. Readback cost: the page measures the time of its own marker/card read (ms, max and mean) and the draw time (decode-output to drawImage done) split by "reading on / off"; counters `wcReadMeanMs`, `wcReadMaxMs`, `wcDrawMeanMs` (the batch names as in wc_stats.js; add to stream_names.dart if it has a whitelist) and a row in the "Custom player (wc)" table of packages/metrics/lib/src/report_stream_wc.dart (test first in report_stream_wc_test.dart). Then measure in tp-stream with the headless bench (`bash tools/stream.sh bench` uses the installed image, which lacks your code; so instead run the page test and the numbers from the fake canvas, and say the real-run comparison is done by the caller after the image is rebuilt). Make the read cheaper if it is obviously wasteful (willReadFrequently canvas reuse, reading only the strip's cells), without changing what it reads.
4. If the card cannot be made to agree (e.g. the card's definition differs by design), say what the difference is and how large it must be, with a test pinning it.

in the report: Summary first (cause with file:line first), Hand-over last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first; `dart format` clean; run the metrics tests you touch.
allow: streaming/player/marker_reader.js · streaming/player/marker_batch.js · streaming/player/marker_decode.js · streaming/player/wc_player.js · streaming/player/wc_counters.js · streaming/player/wc_stats.js · streaming/player/player.js · streaming/player/latency_probe.js · streaming/player/marker_selftest.html · streaming/player/wc_selftest.html · streaming/player/wc_card_selftest.html · streaming/bench.sh · packages/metrics/lib/src/report_stream_wc.dart · packages/metrics/lib/src/stream_names.dart · packages/metrics/test/report_stream_wc_test.dart · docs/streaming-marker.md · docs/briefs/m15/opt2c/g5-cardmarker-report.md · docs/briefs/m15/opt2c/g5-cardmarker
check: format
report: docs/briefs/m15/opt2c/g5-cardmarker-report.md
