# version1 appver: report

tests-first: exempt: the version constant is read from the build define; the new app_version tests pin the regex and label and pass on the code as it was too (see Hand-over).

## Summary

Both apps now read `appVersion` from `--dart-define=APP_VERSION`, default `0.0.0-dev`. Tests that pinned `0.14.0` read the constant. The pubspec `version:` lines are NOT removed (blocked, see Hand-over). `tools/mine.sh` passes.

Files changed:
- `controller_app/lib/src/app_info.dart`: `appVersion` is `String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0-dev')`; doc comment says CI passes the version from the release tag and local builds say `0.0.0-dev`; "Keep in step with pubspec.yaml" removed.
- `tv_test_app/lib/src/app_info.dart`: same change.
- `controller_app/test/identity_build_test.dart`: imports `app_info.dart`; expectations are `'$appVersion+654'`, `'$appVersion+123456789'`, `appVersion` (10-digit and local `dev` cases). Test names and comments that mention 0.14.0 are unchanged.
- `controller_app/test/store_builds_test.dart`: imports `app_info.dart`; expects `'Thumb Party $appVersion (dev)'`.
- `controller_app/test/app_version_test.dart` (new): regex `^[0-9]+\.[0-9]+\.[0-9]+(-dev)?$` on `appVersion`, non-empty; `versionLabel == '$appVersion ($buildNumber)'`.
- `tv_test_app/test/app_version_test.dart` (new): same two tests for the TV app.
- `docs/briefs/m16/version1/appver-report.md`: this report.

Not changed (on purpose):
- `controller_app/pubspec.yaml`, `tv_test_app/pubspec.yaml`: the `version:` line stays (see Hand-over).
- `tv_test_app/test/crash_setup_test.dart`: its expectation already reads `appWithBuild(appVersion, buildNumber)`; its one `0.14.0` is inside a reason string, left as is.
- `app_with_build_test.dart` files: literal arguments, left as the brief says.

Computed values (defaults, no define passed, as `tools/mine.sh` runs them):
- `appVersion` = `0.0.0-dev` (matches the regex).
- `versionLabel` = `0.0.0-dev (dev)`.
- identity: `'0.0.0-dev+654'`, `'0.0.0-dev+123456789'`, `'0.0.0-dev+1234567890'` gives `'0.0.0-dev'`, local `dev` gives `'0.0.0-dev'`.
- store label: `Thumb Party 0.0.0-dev (dev)`.

Self-check (docs/review-rules.md part A):
1. Host setups: the change is a constant and tests; no host path changed. Covered by the existing identity and store tests (`tools/mine.sh` OK 11 controller, OK 8 tv).
2. Kept state: none added.
3. Combination with other states: none; no state added.
4. Folder and allow: all edits are in the allow list. Nothing outside it.
5. Stops: the pubspec step, see Hand-over.
6. Looks: no UI geometry changed. The store-label test checks the text in Settings under the default test size.

## Hand-over

Blocked, not done: removing the `version:` line from both `pubspec.yaml` files (brief item 2).
- `codemagic.yaml:144` reads the version with `grep -m1 '^version:' controller_app/pubspec.yaml` under `set -euo pipefail`. Without that line the step fails, and the iOS release-notes step with it.
- CI does not pass `--dart-define=APP_VERSION` yet (no `APP_VERSION` in `codemagic.yaml` or `.github/`), so the released build would fall back to `0.0.0-dev`.
- `tools/release.sh` (`version_of`, line 112) and `docs/release.md` still read the pubspec version.
- `codemagic.yaml` and `tools/` are outside this job, so I did not change them.

Other points:
- Brief says the doc comment cites `tools/tag-to-version.sh`. That file does not exist in the repo (`ls` finds nothing). I wrote the comment as the brief says; either the script must be added (outside this job) or the comment should name the real source.
- The new `app_version_test.dart` files pass on the code as it was too (the old `0.14.0` also matches the regex and the label is computed). The runner's fail-first gate may reject them. I did not verify that gate; I did not revert code (no git changes allowed).
- `docs/release.md:94` and `docs/dev-tools.md:270` say both `version:` and `appVersion` must agree; they will need updating once the pubspec step is decided.

Checks run:
- `tools/mine.sh`: `OK 11 tests controller_app`, `OK 8 tests tv_test_app`, `churn: reverted 22 generated file(s)`, `RESULT: ok: 6 file(s) formatted, 2 package(s) analyzed, 2 package(s) tested`.

## Commit message — a draft

Read app version from APP_VERSION define, not a copy

Both apps' appVersion is String.fromEnvironment('APP_VERSION') with a
0.0.0-dev default, so CI can pass the release tag's version. Tests that
pinned 0.14.0 read the constant. New app_version tests check the
x.y.z shape and the version label.
The pubspec version lines stay until codemagic.yaml stops reading them.

## Status row

appver: appVersion reads APP_VERSION (default 0.0.0-dev) in both apps, tests updated, new app_version tests; mine.sh green. OPEN: pubspec `version:` lines not removed (codemagic.yaml:144 reads them; CI does not pass APP_VERSION yet); tools/tag-to-version.sh cited in the comment does not exist.

## Delete

- none
