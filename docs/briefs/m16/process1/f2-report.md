# M16 process1 f2 — report

## Summary

The all-looks helper's `...overrides` spread is now pinned by a test. `all_looks_support_test.dart`
declares a test-local `final _marker = Provider<String>((ref) => _defaultMarker)`, and `_Probe` reads it
alongside the TV flag and the look's clock. The third test pumps both looks through `forEachLook` with
`overrides: [_marker.overrideWithValue(_callerMarker)]` (no `clock:` argument any more) and expects the exact
probe text for each look: `tv:false hour:12 marker:caller` in the menu look, `tv:true hour:12 marker:caller`
in the TV look. So one test shows the caller's override kept *and* the look's own TV flag still applied.

Measured: the file runs `+3` green. With the `...overrides` spread removed by hand from `all_looks.dart`
(once; restored straight after) the same file runs `+2 -1`, the failing test finding
`Found 0 widgets with text "tv:false hour:12 marker:caller"` — the marker fell back to `default` because the
caller's override never reached `pumpHost`. `git status --short` shows `test/support/all_looks.dart` unchanged
at the end (the only party_host entry is `M test/all_looks_support_test.dart`, plus the runner's pre-existing
`M docs/briefs/m16/process1/run.log` and the generated `tv_test_app/windows` registrant files, which I did not
touch).

Checks: `tools/check.sh format analyze host` → PASS format (7s), PASS analyze (13s), PASS host (90s).

Decisions:

1. The marker's default is a named `_defaultMarker` constant and `_probeText` takes it as a defaulted
   parameter, so no literal `'default'` is repeated and the first two tests keep their old call shape.
2. The probe still reads the look's clock, so the first test's "the helper's default clock holds in both
   looks" coverage stays; the third test now checks the hour as `harnessNow.hour` (12) rather than a caller
   clock, because a caller cannot override `lookClockProvider` through the helper (f1's finding, by design).
3. `_callerHour` / `_callerClock` were removed with the clock argument: nothing else used them.
4. The test keeps one name and one body for both looks (via `forEachLook`), matching the brief's "both looks
   covered by the same test".

## Computed test values

- `harnessNow` = 2026-11-08 12:00 (`test/support/host_harness.dart`), so `harnessNow.hour` = 12.
- `_defaultMarker` = `'default'`; `_callerMarker` = `'caller'`.
- Probe text format `tv:$isTv hour:$hour marker:$marker`.
- Menu look expected: `tv:false hour:12 marker:caller` (look does not add the TV flag; caller's marker kept).
- TV look expected: `tv:true hour:12 marker:caller` (look adds `toyTvProvider` on; caller's marker kept).

## Break-and-restore

1. Baseline: `flutter test test/all_looks_support_test.dart` → `+3: All tests passed!`
2. Hand edit in `all_looks.dart:50`:
   `overrides: [...overrides, if (...) ...]` → `overrides: [if (...) ...]`
   (the caller's overrides no longer reach `pumpHost`).
   `flutter test test/all_looks_support_test.dart` → `+2 -1: Some tests failed.`
   Failure: "the helper keeps the caller's own overrides in both looks", at line 82,
   `Found 0 widgets with text "tv:false hour:12 marker:caller"` (the probe mounted with `marker:default`).
3. Restored the exact original line; `git status --short` confirms `all_looks.dart` is unmodified
   (see Summary), and the file is green again in the full host suite.

Why this failure is the right one: only the spread's loss makes the marker fall back to its default; the TV
flag assertion in the same expected string would still hold, so the failure isolates the caller's override.

## Self-check (review-rules part A)

1. Host setups: test-only change; the helper mounts `pumpHost`'s fake host service, no device, phone, joined phone or older build is involved — both looks cover the TV/provider difference this test cares about.
2. Kept state: none added; `_marker` is a compile-time provider object and each `pumpHostLook` mounts a fresh `ProviderScope`; `forEachLook` takes the previous tree down between looks (`all_looks.dart:65`), so the caller override cannot leak from the menu look to the TV look (the test would see `marker:default` otherwise).
3. Combined states: the one combination this job is about — the look's own `toyTvProvider` override plus the caller's override — is what the third test mounts in the TV look, and it passes; no pause/away/ready state is touched.
4. Folder: wrote only `packages/party_host/test/all_looks_support_test.dart` and this report; `all_looks.dart` was edited only for the measured break and is byte-identical again (`git status --short`).
5. Stop rather than overstep: nothing outside `allow:` was needed; f1's merge idea stays unimplemented, as the brief says it should.
6. Every look: the test itself runs in both looks through `forEachLook`, and the file's first two tests still cover each look's TV flag and default clock.

## Questions / suggestions

1. Suggest (not acted on): if a future job ever wants a caller to override `toyTvProvider` or
   `lookClockProvider` through `pumpHostLook`, f1's merge-by-origin in `host_harness.dart` is still the shape
   to build; this test intentionally uses a provider nothing else overrides so it stays valid either way.
2. Suggest (not acted on): the probe's hour read is now only a default-clock check; if `lookClockProvider`
   ever stops being part of `pumpHost`, the third test's expected string drops the hour and gains nothing else.

## Hand-over

Test-only, no behaviour change. The helper's `...overrides` merge is pinned by a test that fails without it
(measured). Nothing open in this job.

## Commit message

test: pin the all-looks helper's overrides merge with a marker provider

The all-looks helper test now declares a test-local Provider<String> marker
that nothing else overrides, has the probe read it, and passes the caller's
override through pumpHostLook in both looks. It asserts the exact probe text
per look: the caller's marker is kept and the TV look still sets its own flag.
Dropping the "...overrides" spread from all_looks.dart makes it fail (measured,
then restored); all_looks.dart is unchanged.

## Status row

M16 process1 f2: done — the helper's overrides merge is pinned by the marker-provider test (menu `tv:false`, TV `tv:true`, both `marker:caller`); break-and-restore measured; all_looks.dart unchanged; format/analyze/host green. Open: nothing.

## Delete

- none
