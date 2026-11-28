job: map2b m2d — frame-time sampler, draw-call budget test, on-screen measure hook
stop: no wiring into any game or screen, no "Try the map" entry (owner 6B), no rule or tuning change. Do not edit existing files. The 60 fps check on a TV box is an owner device check, not this job.
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/city/art/city_overlay_painter.dart:19-60 · packages/party_host/lib/src/city/art/city_painter.dart:34-70 · packages/party_host/test/city/art/city_painter_test.dart:55-75,165-195 (the counting canvas pattern, cached frame test) · packages/party_host/test/city/art/city_scene_test.dart:1-60 (board and scene helpers) · owner 5A: carry on past the device check; the owner checks at the next release
changes: FrameProbe · FrameStats · CityFrameHook (all new, city/art/frame_probe.dart)
model: haiku
turns: 60
expected-min: 25
tests-first: exempt new files only; tests fail on an empty stub by construction
do:
1 New city/art/frame_probe.dart (pure Dart apart from the hook): `FrameStats` (count, average Duration, p95 Duration, dropped int) and `FrameProbe({Duration window = 10s, Duration budget = ~16.7 ms * 1.5 dropped threshold})` with `add(Duration frameTime)` (keeps frames of the last `window` of summed frame time) and `FrameStats get stats`. Injected times only: no clock inside.
2 In the same file `CityFrameHook` widget: wraps a child, feeds a FrameProbe from SchedulerBinding.instance.addTimingsCallback (remove it in dispose, FrameTiming.totalSpan), shows avg ms, p95 ms and dropped count as small text in a corner via Stack. Takes an optional `Stream<Duration>? frames` for tests instead of the binding. Nothing mounts it.
3 Tests (write first, run first) test/city/art/city_frame_test.dart: sampler unit test with injected times (average, p95 index rule on 20 known values, dropped count, window drops old frames, empty gives zeros); hook widget test with an injected stream shows the numbers; budget test with a counting canvas (copy the pattern from city_painter_test.dart into this file): 8 tokens on the standard board at 1920x1080: after the first frame a CityPainter paint with a built cache calls drawImage once and nothing else; the overlay painter makes at most a named const `overlayDrawCallBudget` canvas calls per frame (measure it, set the const with about 25% headroom, comment how it was measured). The test must fail for a painter that redraws the static layer (add a case with a stub painter that calls paintStatic every frame and expect the budget check to flag it).
4 Each file under 380 lines. Run `dart analyze` on changed files and fix every info, warning and error.
allow: packages/party_host/lib/src/city/art/frame_probe.dart · packages/party_host/test/city/art/city_frame_test.dart
check: format analyze
report: docs/briefs/m17/map2b/m2d-report.md
