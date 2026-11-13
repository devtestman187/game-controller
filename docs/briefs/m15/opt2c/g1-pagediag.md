job: M15 opt2c-1 (page diagnostics): the wc page measures where its own side backs up, and the figures reach the report
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2c/CONTEXT.md (whole, first) · streaming/player/wc_player.js · wc_counters.js · wc_stats.js · wc_decoder.js · player.js (wcEvent, wcDrawn, how the wc batch is built) · packages/metrics/lib/src/report_stream_wc.dart and packages/metrics/test/report_stream_wc_test.dart · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Goal: when a phone run collapses, the figures must say whether the page's thread, the decoder or the network fell behind. Measuring only; no behaviour change (draw, keyframe requests unchanged).

Design (new file streaming/player/wc_diag.js, at most 200 lines; wc_player.js must stay under 380):
1. Tests first (page test: new streaming/player/wc_diag_selftest.html, added to run_page_selftest in bench.sh, in the style of wc_selftest.html; fake clock injected). WcDiag has: `noteMessage(nowMs, bytes, isKey)` (WebSocket message arrival), `noteDecoderQueue(size)`, `tick(nowMs)` driven by a 20 ms setInterval the player starts (and a PerformanceObserver for 'longtask' where it exists, in try/catch), `snapshot()`.
2. Figures: `gapMaxMs` (longest gap between two messages while streaming), `gapsOver100`, `gapsOver250` (counts); `recvBytes`; `keyBytesMax`, `keyBytesAvg`, `deltaBytesAvg`, `deltaBytesMax`; `decQueueMax` (decoder.decodeQueueSize at each decode call); `mainLagMaxMs` (a 20 ms timer that fires late by more than 30 ms counts; lateness = actual - 20), `mainLagOver50` (count), `longTasks` (count, 0 where unsupported); `msgHandlerMaxMs` (time spent in the page's own onmessage up to handing the frame to the decoder); `bytesPerSecMax` (largest bytes in one second). Gaps are not counted across a reconnect or before the first frame.
3. Wire them into the wc batch as counters/gauges named `wcGapMaxMs`, `wcGaps100`, `wcGaps250`, `wcRecvBytes`, `wcKeyBytesMax`, `wcKeyBytesAvg`, `wcDeltaBytesAvg`, `wcDecQueueMax`, `wcLagMaxMs`, `wcLag50`, `wcLongTasks`, `wcHandlerMaxMs`, `wcBytesPerSecMax` the way the other wc names go (see wc_stats.js, and the host's name rules in packages/metrics/lib/src/stream_names.dart if it has a whitelist: add the names there and in its test; stream_names.dart is in allow).
4. packages/metrics: `report_stream_wc.dart` (if over 330 lines, new file report_stream_wc_diag.dart) prints a table "Custom player diagnostics (wc)" with columns: gap max ms, gaps >100, gaps >250, recv MB, key KB max/avg, delta KB avg, bytes/s max (Mbit/s), dec queue max, lag max ms, lag >50, long tasks, handler max ms. Test first with a summary fixture, in the style of report_stream_wc_test.dart (new test file allowed).
5. A numbers-only grep line: the table's header starts with "Custom player diagnostics (wc)" so `grep -A4` finds it.

in the report: Summary first, Hand-over last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first; `dart format` clean; `dart test` (or flutter test) for the metrics files you touch.
allow: streaming/player/wc_diag.js · streaming/player/wc_diag_selftest.html · streaming/player/wc_player.js · streaming/player/wc_decoder.js · streaming/player/wc_counters.js · streaming/player/wc_stats.js · streaming/player/player.js · streaming/player/serve.py · streaming/player/relay_test.py · streaming/bench.sh · packages/metrics/lib/src/report_stream_wc.dart · packages/metrics/lib/src/report_stream_wc_diag.dart · packages/metrics/lib/src/stream_names.dart · packages/metrics/lib/src/report_stream.dart · packages/metrics/test/report_stream_wc_test.dart · packages/metrics/test/report_stream_wc_diag_test.dart · docs/briefs/m15/opt2c/g1-pagediag-report.md · docs/briefs/m15/opt2c/g1-pagediag
check: format
report: docs/briefs/m15/opt2c/g1-pagediag-report.md
