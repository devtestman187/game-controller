# map2a wave 3 review (f2, f1)

## Summary

- **Verdict:** small fixes
- **Counts:** must 3, should 3, could 4
- **Top 1:** the dispose test (`city_painter_test.dart:218`) and the size-change test (`:231`) pass on the old code: the guard they test (`city_painter.dart:182`) predates the job.
- **Top 2:** f2 did not run its new tests against the old code, which its brief required (`f2-report.md:15`).
- **Top 3:** the `paint` doc says a mismatched layout is "refused" (`city_painter.dart:52-53`), but the assert is debug-only, so a release build draws it wrong.
- **Format:** `dart format --set-exit-if-changed` on the four changed files: 0 changed.
- **Not run:** `dart analyze` and all tests (see Could not check).

## Findings

- **must** packages/party_host/test/city/art/city_painter_test.dart:218 The dispose test passes on the old code: `build` already returned early when `_isDisposed` (`city_painter.dart:182`, not changed by the job) → state in the report that it covers existing behaviour, so the brief's tests-first step does not apply to it.
- **must** packages/party_host/test/city/art/city_painter_test.dart:231 The size-change test passes on the old code for the same reason (`_wantedSize != size` guard at `city_painter.dart:182`) → same fix: record it as existing behaviour, not a new check.
- **must** docs/briefs/m17/map2a/f2-report.md:15 The report says the tests "were written alongside the code, not run against the old code first", which breaks the f2 brief's tests-first step ("must fail there") → run the new tests against the base commit and list which fail, or record that the step was not done.
- **should** packages/party_host/lib/src/city/art/city_painter.dart:52 The doc says a mismatched layout is "refused rather than drawn wrong", but the assert at `:56` is debug-only; in release `paint` draws the layout-size image and the tiles at the wrong size → say "checked in debug builds only; a release build does not refuse it".
- **should** packages/party_host/test/city/art/city_painter_test.dart:212 The failure test does not do what the brief asks ("a later paint retries and succeeds"): it calls `cache.request` (the retry build is unawaited, `city_painter.dart:159`), waits 50 ms of real time, then builds at `small`, not at the failed size → call `painter.paint` after the failure and await the retry through `cache.build`, with no real-time delay.
- **should** packages/party_host/test/city/art/city_overlay_painter_test.dart:44 The TV and menu looks are hand-built with `ToyLook.build(palette: ToyPalette.sunny, …)`, not from `toyLookProvider` (`look_providers.dart:91-97`), so the test may not use the look the TV runs → build both looks through the provider path, or say in the report that the palette is assumed.
- **could** packages/party_host/lib/src/city/art/city_painter.dart:158 A failing size is retried on every `paint` and logs every time, with no back-off → log once per size, or leave as is and say so.
- **could** packages/party_host/lib/src/city/art/city_painter.dart:176 The log line has no short tag, which `docs/coding-guidelines.md:73` asks for (the precedent `advertiser.dart:91` has none either) → add a tag such as `city-map:`.
- **could** packages/party_host/test/city/art/city_overlay_painter_test.dart:236 `shouldRepaint` still uses the menu look only (f1 question 4) → loop over `HostLook.values` as the other tests do.
- **could** docs/briefs/m17/map2a/f2-report.md:1 The report has no Summary block (runner finding, `run-findings.md:1`) → add one.

## Decisions to confirm

- f1: built tiles use `star`, not `good` as `REVIEW.md:58` suggested; the brief asked for `star`, so the owner should confirm it.
- f2: the catch at `city_painter.dart:174` is `on Object`, so every error is caught, not only the engine's; the report does not say so.
- f2: `CityStaticCache({LogSink? log})` defaults to a no-op (`city_painter.dart:140`, same as `advertiser.dart:66`). No lib code constructs `CityStaticCache` yet, so a real failure would not be logged; the report does not say this.
- f2: a failed build clears the wanted size (`city_painter.dart:177`), so every paint retries with no limit; not in the report.
- f2: the paint assert is debug-only (`city_painter.dart:56`); the report does not say so.

## Could not check

- `dart analyze` and the test suites were not run; only `dart format` was run (0 changed).
- Whether `Picture.toImage(0, 0)` throws (f2 report's basis for the failure test), and the test counts (33 and 51): `run.log:69-77` has no test output.
- The night palette sharing the sunny `star` and `paper` values (f1 report line 33).
- f2 ran 15 turns against an expected minimum of 25 (`run.log:69`); the diff alone does not show whether work was missed.
- Docs: the jobs touched no document other than their reports.

## Commit message — a draft

No commit: this review changes only its report.

## Status row

map2a wave 3 review: f1 and f2 reviewed; open: 3 must findings (two tests pass on old code, f2 skipped the tests-first run) and 3 should findings (release-mode doc, failure test does not paint, hand-built TV look).

## Delete

- none
