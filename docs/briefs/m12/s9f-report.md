# s9f report — CI's TV tests fail on Linux: a Windows-only test (G4)

**Done.** One file changed: `tv_test_app/test/tv_host_setup_test.dart` (test only; `tv_host_setup.dart`
untouched). `tools/check.sh format analyze tv` passes.

## 1. What was wrong

`tv_host_setup_test.dart`'s single test asserted `Platform.isWindows` and expected
`HostKind.pc` with this PC's hostname. `analyze-test-android` (`.github/workflows/ci.yml`, runs on
`ubuntu-latest`, `flutter test` in `tv_test_app`) therefore failed from `f42d305` on. The
`windows-desktop` job never runs the tests, so nothing else caught it.

## 2. What runs where

| OS | "on this PC…" (existing) | "off Windows…" (new) |
| --- | --- | --- |
| Windows (this PC, `windows-desktop` does not test) | **runs, 1 test** | skipped |
| Linux (`analyze-test-android` on CI) | skipped | **runs, 1 test** |
| macOS | skipped | **runs, 1 test** |

Both are `test(...)` with a `skip:` argument, so each OS declares 2 tests, runs 1 and skips 1.

- The existing test is **not changed** (name, body, expectations): only `skip:` was added, for off
  Windows: `'needs this Windows PC; CI runs the TV tests on Linux'`.
- The new test is `'off Windows the TV app hosts as a pc with this OS name'`, skipped on Windows with
  `'this PC is Windows: the case above checks it'`.

## 3. What the new test expects, and why (values computed from the code)

`tvHostIdentity()` (`tv_test_app/lib/src/tv_host_setup.dart:22-34`) reads four things: `Platform.isAndroid`,
`Platform.isWindows`, `Platform.operatingSystem` and `Platform.localHostname`. On CI's Linux runner:

- `Platform.isAndroid` is false → `hostType` is `HostType.other` (`'other'`), not `'windows'` and not
  `'android_tv'`. **The brief's guess of `HostKind.tv` does not hold off Android**: `kind` is
  `HostKind.tv` only when `Platform.isAndroid` (`tv_host_setup.dart:30`), so on Linux it is
  `HostKind.pc` — the same kind as on Windows.
- `kind` → `HostKind.pc` (`'pc'`).
- `hostOs` → `Platform.operatingSystem`, i.e. `'linux'` on the runner (the test compares against
  `Platform.operatingSystem`, so it stays true on macOS too).
- `defaultHostName` → `Platform.localHostname` (the `Android TV` branch needs `isAndroid`), so
  `serviceName` is `'Thumb Party TV (<hostname>)'`.

(`flutter test` runs on the host Dart VM, so `Platform.isAndroid` is false in every `test/` file; the
Android branch cannot be reached from a unit test without a parameter.)

## 4. Test counts

- `tv_host_setup_test.dart`: **2 declared, 1 run, 1 skipped** on every OS (it was 1 declared, 1 run).
- Whole TV app, this Windows run: `flutter test` → **28 passed, 1 skipped** (`+28 ~1`, before the
  change 27 passed). File count is unchanged: `tv_test_app/test` has no new file.
- On Linux CI the same numbers appear (`+28 ~1`), with the skipped name being the Windows one.

## 5. Why not the parameter variant

The brief allowed: make `tvHostIdentity` take the platform, then test both cases on every OS. I did
not, for two reasons:

1. "Keep the Windows test as it is" and "test both cases on every OS" cannot both hold: the existing
   test's first line asserts `Platform.isWindows` (the environment), which is false on Linux, so it
   would have to be rewritten — contrary to "keep the Windows test as it is" and to "tests: as above;
   nothing else changes".
2. It is feasible otherwise: an optional named parameter (e.g. a small record of `isAndroid`,
   `isWindows`, `operatingSystem`, `localHostname`, defaulting to the real `Platform` values when
   omitted) leaves `main.dart:21` and `test/support/pump_app.dart:64` unchanged. It would need
   `tvDefaultHostName` and `tvServiceName` to take the same facts (they are the ones using the
   hostname), so the lib side changes in three functions. Suggested for a later brief if skips on CI
   are unwanted.

## What I ran

- `flutter test test/tv_host_setup_test.dart` in `tv_test_app` — `+1 ~1: All tests passed!`
  (Windows: the existing test ran, the new one was skipped with its reason).
- `flutter test` in `tv_test_app` — `+28 ~1: All tests passed!`.
- `tools/check.sh format analyze tv` — `PASS format (2s)`, `PASS analyze (9s)`, `PASS tv (9s)`,
  `All checks passed (20s)`.

The Linux branch could not be executed here (this PC is Windows); its expectation was checked against
`tv_host_setup.dart:22-44` line by line, as written in §3.

## Questions and suggestions

1. **Question — the brief's `HostKind.tv` guess:** off Android, `kind` is `HostKind.pc`, so the new
   test asserts `pc` and `HostType.other`. If you wanted the Android branch covered by a test, that
   needs the platform parameter (suggestion 2 below) — say so and it is a small follow-up.
2. **Suggestion — parameterise `tvHostIdentity`:** as in §5.2, it removes the skip and tests all three
   branches (Android TV, Windows, other) on every OS.
3. **Note — `ci.yml` itself needs no change.** `analyze-test-android` (ubuntu-latest) is the only job
   that runs `flutter test` in `tv_test_app`; `windows-desktop` only builds the Windows app, so the
   Linux run is the only TV test run on CI, and it now has a test that can pass there.
4. **Note — the skip is reported both in `flutter test` output and in `check.sh tv`'s log** as
   `~1`, so the count stays visible instead of hiding a test silently.

## Files changed

- `tv_test_app/test/tv_host_setup_test.dart` — existing Windows test gets a `skip:` off Windows
  (body unchanged); new test for the non-Windows identity (`HostType.other`, `HostKind.pc`,
  `Platform.operatingSystem`, `'Thumb Party TV (<hostname>)'`), skipped on Windows; `metrics` import
  for `HostType`.

## Commit message

test: run the TV host identity test off Windows too (s9f)

tv_host_setup_test asserts Platform.isWindows, so CI's Linux
analyze-test-android job has failed on it since step 5 f42d305.
The test is unchanged and now skipped off Windows with a reason.
A second test covers the other branch (hostType other, kind pc,
service name from the OS hostname) and is skipped on Windows.
Every OS now runs one of the two: 28 TV tests pass with 1 skipped
here, and CI runs the mirror image on Linux.

## Status row

| 9 Docs and device tests | … **s9f done** (`s9f.md`): `tv_host_setup_test.dart` keeps its Windows-only test (skipped off Windows with a reason) and adds the non-Windows case (`hostType` other, `kind` pc, `hostOs`, `'Thumb Party TV (<hostname>)'`), skipped on Windows, so Linux CI runs one and Windows runs the other (TV app 28 tests, 1 skipped, on both). Open: the m12.3 CI rerun, the skipped-test question (parameterise `tvHostIdentity`?), s8c's device check, the PRD M12 acceptance tests in the checklist |

## Delete

- none
