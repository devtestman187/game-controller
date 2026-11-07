job: m12 step3 s3d G4 — two corrections to the viewer's measurements
stop: after G4. Only `ViewerStats`, its tests, and the contract text below.
read: packages/connection/lib/src/viewer_stats.dart · packages/connection/test/{viewer_stats_test,client_view_test}.dart · packages/game_kit/test/frame_view_test.dart · docs/design/m12-sessions.md §4 · docs/coding-guidelines.md

why: Claude's PC measurement (dev TV app + `sim_controller --view --stream` at 60, 30 and 20 Hz) gave touch-to-frame 31 ms median at every rate and counted almost every draw "late" at 30 and 20 Hz. Both are rules in Claude's contract, not bugs in the code:
1 touch_to_frame records one sample per drawn frame, for the newest input it acknowledges. With inputs streaming at 60 a second that's always the freshest one, so the wait for the next frame is never measured.
2 `late` is a draw more than a fixed 25 ms after the previous one, which only fits 60 Hz.

the new rules (they replace §4's "Measurements" bullets; edit docs/design/m12-sessions.md §4 to say so, dated Nov 7):
- touch_to_frame: when a drawn frame first acknowledges inputs above the last acknowledged seq, record one sample per remembered input in (last acked, ack seq]: draw time − that input's send time. So every input sent gets its trip to the screen, and the samples show the wait for the frame. Inputs the viewer no longer remembers are skipped. The cap per batch stays `MetricsMessage.maxStageSamples` (the existing even thinning in `drain`).
- late: a drawn frame more than `lateFactor` × (1000 / hz) ms after the previous drawn frame, with `lateFactor = 1.5` (a named constant with its reason, like `gapStrideFactor`). `lateDrawMs` goes.

tests (update the existing ones to the new rules, old → new listed in the report):
- inputs 5, 6, 7 sent at 0, 16, 33; a frame acking 7 drawn at 60 → samples [60, 44, 27]; then a frame acking 7 again → nothing new; a frame acking 9 with only 8 remembered → one sample.
- at 60 Hz the limit is 25 ms: a draw 26 ms after the previous is late, 24 isn't; at 20 Hz a draw 60 ms after isn't late and 80 ms after is (limit 75 ms); at 30 Hz the limit is 50 ms.
- `reset(hz:)` changes the late limit.
- FrameView's and the client's tests still pass (adjust their expected sample lists if a case now yields more samples; list them).

report: line counts, test counts before and after, every old → new expectation.
rules: no file over 400 (tests 500); no wire change · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s3d-report.md · docs/design/m12-sessions.md · packages/connection/lib/src/viewer_stats.dart · packages/connection/test · packages/game_kit/test/frame_view_test.dart
check: format analyze connection kit
report: docs/briefs/m12/s3d-report.md
