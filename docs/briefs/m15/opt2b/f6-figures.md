job: M15 opt2b-6 (figures): the wc page reports delivered fps, received/decoded/dropped frames, freezes and first-frame time in the "Streaming quality" table
pub: no
wsl: tp-stream
stop: after it.
read: docs/briefs/m15/opt2b/CONTEXT.md (whole, first) · docs/briefs/m15/opt2b/f1-register-report.md (Hand-over) · streaming/player/reporter.js (_batch, viewerCounters use) · metrics.js (viewerCounters, rateKbitPerS, what it reads from the `video` object) · wc_counters.js · wc_stats.js · wc_player.js (counters, stageSamples) · wc_stats_selftest.html · docs/coding-guidelines.md
decide: low-usage mode: never stop for a question; safest choice, list each under "Decisions"; stop only if truly impossible ("Blocked").

Finding from a real bench summary (headless, player=wc): the "Streaming quality" row shows recv kbps (3375.7) but `-` for fps, sent, recv, decoded, dropped, late, freezes, first frame ms, because without a peer connection the reporter has no inbound-rtp `video` entry to read them from. The wc player knows all of them.

Design (tests first, in wc_stats_selftest.html and wherever reporter batch tests live):
1. Per reporting interval the wc batch carries: gauge `deliveredFps` (frames drawn / interval seconds, one decimal); the viewer counters that `viewerCounters` names for framesReceived, framesDecoded, framesDropped (= received - drawn, never negative; or the player's own drop counters if clearer: say which), freezes and freezeMs, firstFrameMs, using the SAME names the host's stats and the Dart report already read (see viewerCounters in metrics.js and the Dart stream_names.dart / report_stream_rows.dart). Easiest route: build a plain object shaped like the inbound-rtp video entry (`framesReceived`, `framesDecoded`, `framesPerSecond`, `freezeCount`, `totalFreezesDuration`, `frameWidth`, `frameHeight`) from the player's counters and let the existing reporter code read it when there is no peer connection; do that if it keeps the reporter small, else add counters directly.
2. A freeze is a gap of more than 150 ms between two consecutive draws (a named constant); the player's draw path records freezeCount and total frozen ms (gap length) in wc_counters.js. Test with fake clocks: gaps of 100, 151 and 400 ms give 2 freezes and the right total; the first frame is no freeze.
3. First frame: ms from start() to the first draw, as firstFrameMs (the same field the current page sends).
4. Resolution fact from the canvas size if the existing code sends it from `video` (frameWidth/Height).
5. Nothing changes with a peer connection (the WebRTC page): existing reporter tests stay green and unchanged.
6. Keep every file at most 380 lines.

in the report: `## Summary` first (see CONTEXT.md; say which figures now show and which still cannot), `## Hand-over` last.
self-check: docs/review-rules.md part A, items 1-5, one line each.
rules: as CONTEXT.md; tests first; `dart format` clean if you touch Dart (only if a Dart name must change; Dart changes need a test).
allow: streaming/player/reporter.js · streaming/player/metrics.js · streaming/player/wc_counters.js · streaming/player/wc_stats.js · streaming/player/wc_player.js · streaming/player/wc_decoder.js · streaming/player/player.js · streaming/player/wc_selftest.html · streaming/player/wc_stats_selftest.html · packages/metrics/lib/src/stream_names.dart · packages/metrics/lib/src/report_stream_rows.dart · packages/metrics/test/report_stream_wc_test.dart · docs/briefs/m15/opt2b/f6-figures-report.md · docs/briefs/m15/opt2b/f6-figures
check: format
report: docs/briefs/m15/opt2b/f6-figures-report.md
