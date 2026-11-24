# Run review: m16 version1 (tagver, appver, aggcost; commits 833b178f, e2e67f54, 67defc6f)

## Summary

Verdict: **needs Claude's design**. Counts: 2 must, 9 should, 1 could.

The five that matter most:
1. `tools/release.sh:115-116`: the release script now dies at its own check. It greps `app_info.dart` for `appVersion = '<pubspec version>'`, and the new line is `String.fromEnvironment(...)`, so no release can finish.
2. `codemagic.yaml:162`: CI passes only `BUILD_NUMBER`, never `APP_VERSION`. Every release build reports `0.0.0-dev` while the store name still comes from `pubspec.yaml` (`0.14.0`). Workers may not edit this file.
3. `pubspec.yaml` `version:` lines (`controller_app/pubspec.yaml:6`, `tv_test_app/pubspec.yaml:5`) were kept, so two version sources now disagree. Removing them needs a decision (`codemagic.yaml:144` reads them).
4. `controller_app/test/app_version_test.dart:8` and the TV twin: the "x.y.z" test only compares the constant with the same `fromEnvironment` default. The regex the appver brief asked for is missing, though `appver-report.md` says it is there.
5. `tools/churn.sh:58`: the `mine.sh` churn step ran `git checkout --` on 22 paths, including three `tv_test_app/windows` files that were already modified at session start.

Hand-fixes: `run.log` has no `HAND-FIX` lines. Three "applied by hand" resume lines exist (`run.log:30-32`, `41-43`). Tests-first proof: tagver in `tagver-report.md` (16 FAIL before the script, 16 PASS after); appver in `run.log:44-45`; aggcost is exempt. No `*-review-report.md` exists for any job.

Carried over: the four tests-first lines in `run-findings.md` were resolved at the gate (`run.log:44-45`), but the proof is weak (findings 6 and 7).

Unverified: no job measured anything. The version change has no device check: "Fixed, unverified: needs device check" (finding 2, a release build's version on the phone and TV).

Fix batches (at most 3 findings, no shared files): Job 1, tools, after `tools/release.sh` is allowed: findings 1, 4, 10. Job 2, phone-pinned: 3 (controller half), 6, 8. Job 3, TV: 3 (TV half), 7, 12. Owner only: 2, 5, 11.

## Findings

- **must** `tools/release.sh:115` the release script dies at its `app_info.dart` check, because the new line has no `appVersion = '…'` literal → delete the `app_info` loop (`:115-117`), drop the `tv_version` check, and add `phone_version="$(bash tools/tag-to-version.sh "$tag")"` after the tag check (tagver-report "Still to do" 1-3); needs `tools/release.sh` allowed, not phone-pinned (from: across jobs, appver + tagver)
- **must** `codemagic.yaml:162` CI passes only `BUILD_NUMBER`, so release builds report `0.0.0-dev` while the store name comes from the pubspec → add `--dart-define=APP_VERSION=` from `tools/tag-to-version.sh` in the release step; owner only, workers may not edit codemagic.yaml (from: across jobs, appver)
- **should** `controller_app/lib/src/app_info.dart:1` the doc comment says CI passes the version from the tag via `tools/tag-to-version.sh`, which no CI step does → reword to "local builds say 0.0.0-dev" until finding 2 is done; phone-pinned (from: appver)
- **should** `tools/tag-to-version.sh:8` the comment says `tools/release.sh` uses the script, and `:2` says both apps take their version from the tag; neither is true yet → reword, or wire with finding 1; not phone-pinned (from: tagver)
- **should** `controller_app/pubspec.yaml:6` (and `tv_test_app/pubspec.yaml:5`) the `version: 0.14.0+14` line stays while `appVersion` no longer follows it, and `docs/release.md:94`, `docs/dev-tools.md:270` and `:294` still say both must match → owner decides: delete the `version:` lines once `codemagic.yaml:144` and `release.sh` read the tag, then fix the three docs (from: across jobs, appver brief item 2 not done)
- **should** `controller_app/test/app_version_test.dart:8` the test "appVersion is a x.y.z version" only checks non-empty and equality with the same `fromEnvironment` default; no regex, and a hard-coded `'0.0.0-dev'` passes; it fails on the old code only because `0.14.0` ≠ `0.0.0-dev` → assert the regex `^[0-9]+\.[0-9]+\.[0-9]+(-dev)?$` the brief asked for, and rename the test to match; phone-pinned (from: appver)
- **should** `tv_test_app/test/app_version_test.dart:8` same defect as the controller test → same fix; TV-pinned (from: appver)
- **should** `controller_app/test/identity_build_test.dart:8` the test name still says `"0.14.0+654"` and `:11` the comment says `0.14.0 is the app's version`, while the expectations now use `appVersion` → rename both to name `appVersion`; phone-pinned (from: appver)
- **should** `tools/tests/agent-cost-test.sh:59` and `:67` the check lines print 2 decimals, and opus and total print the same at 0.1x, so no check fails on the old price; `tools/agent_cost.py:23` is the change with no test that sees it → add a direct assertion on the cache-read multiplier or more decimals (from: aggcost)
- **should** `tools/tests/tag-to-version-test.sh:6` no script runs the two shell tests (`tools/mine.sh` runs Dart only, and `tools/check.sh` lists none), so they run only when someone remembers → wire `tools/tests/*-test.sh` into `tools/check.sh` or `tools/mine.sh` (from: across jobs, tagver Q3 and aggcost)
- **should** `tools/churn.sh:58` `churn_revert` runs `git checkout --` on every dirty generated path, which reverted three `tv_test_app/windows` files that were modified at session start and 19 PNGs whose state is unknown (called from `tools/mine.sh:286`) → skip paths that were dirty before the run, or snapshot them first; owner decides (from: across jobs, aggcost Q1)
- **could** `tv_test_app/test/crash_setup_test.dart:34` the expectation reason still reads `the phone's "0.14.0+654" format`, which is now stale → say `the phone's version+build format`; TV-pinned (from: appver, left on purpose)

## Open questions

1. Allow `tools/release.sh` for one job (the tagver permission block)? Suggest yes, using the tagver "Still to do" list.
2. Who adds `--dart-define=APP_VERSION` to `codemagic.yaml:162`? Suggest the owner, from `tools/tag-to-version.sh`, in the release step.
3. Delete the pubspec `version:` lines now, or after CI reads the tag? Suggest after: keep them until `codemagic.yaml:144` and `release.sh` read the tag.
4. Were the 22 reverted paths needed? Suggest no: they are generated; check the three `tv_test_app/windows` files come back on the next build.
5. Add a precise cache-read check (finding 9)? Suggest yes.
6. Wire the shell tests into `check.sh` (finding 10)? Suggest yes.
7. `tools/agent_cost.py:11` says "Fable 5.2" and the environment lists Fable 5.1. Which is the priced model? Suggest the owner confirms against the price list.
8. Does the stats side accept `0.0.0-dev` as the app version? Suggest a check once CI passes the define; not checkable here.
9. Commit `833b178f` says "Release version comes from the tag", which is not true yet. Suggest leave history alone and finish the wiring (finding 1).

## Numbers against targets

- No target is stated in the m16 version1 briefs, and no `STATUS.md` exists, so nothing misses a target.
- Recomputed: `opus m1` 0.004 + 0.04 + 0.002 + 0.032 = 0.078 (from the comment's components; the fixture is not read); `sonnet s1` 0.125 + 0.001 + 0.00002 = 0.12602, `s2` 0.08 + 0.001 + 0.00002 = 0.08102, `s3` 0.12, sum 0.32704 (checked against the fixture: input 10, output 100); `haiku` 0.0131; `fable` 0.168; total with fable 0.58614, without 0.41814 (sums checked).
- tagver: 5 success and 11 exit-2 cases = 16 (counted in `tools/tests/tag-to-version-test.sh`), matching the report.
- appver: `OK 11 tests controller_app`, `OK 8 tests tv_test_app` (from `appver-report.md`); not re-run.

## Could not check

- `docs/coding-guidelines.md` and `docs/review-rules.md` were not read in full; I judged against the worker extract in the brief.
- No tests were run (read-only job). The "fails on old code" and "passes" claims come from the reports and `run.log`.
- The first combined check failed (`run.log:47`, "checks failed; fetching packages and trying once more") and its failure was not recorded.
- Whether the 22 reverted files held uncommitted content was not checked.
- Whether the stats reader accepts `0.0.0-dev` (`packages/metrics/lib/src/session_clean.dart`) was not traced.
- `controller_app/ios/Flutter/flutter_export_environment.sh:9` (`FLUTTER_BUILD_NAME=0.14.0`) was not checked for being generated or tracked.

## Commit message — a draft

Review the m16 version1 run: findings for Claude

Read as one change: the version commits (833b178f, e2e67f54, 67defc6f).
Two must findings: tools/release.sh dies at its app_info check, and CI
passes no APP_VERSION, so release builds report 0.0.0-dev. Nine should
and one could: pubspec versions still kept, weak version tests, stale
0.14.0 names, unwired shell tests, and a churn revert of dirty paths.
No code changed in this review.

## Status row

version1 run review: 12 findings (2 must, 9 should, 1 could); open: release.sh and CI do not yet use the tag-derived APP_VERSION, pubspec version lines kept, version tests weak, shell tests unwired, churn revert of dirty paths (owner decisions in open questions 1-4).

## Delete

- none

## Driver verdicts (Nov 24)

- must 1 release.sh: fixed by hand (tag-derived version, app_info loop removed).
- must 2 codemagic.yaml: fixed by hand (diff below); release.yml too.
- pubspec version lines: deleted (one source: the tag). Docs release.md and dev-tools.md updated.
- should 4 comment, 6/7 regex assertions, 8 test name, 12 stale reason: fixed. 3 (doc comment) now true.
- should 9 (agent-cost 2-decimal checks cannot see the multiplier), 10 (shell tests not wired into check.sh), 11 (churn_revert reverts paths dirty at start): deferred to docs/code-health.md.
- Open questions 7 (Fable 5.2 vs 5.1 price row) and 8 (stats accept 0.0.0-dev: technicalPattern allows it): owner/none.
- Fixed, unverified: needs device check: a release build shows 0.16.4 (TestFlight, Play, TV) after the next tag.

## job-metrics
JOB        WORKER MODEL            TURNS IN   OUT  CACHE MINUTES WALL RESULT
aggcost    claude claude-haiku-5-5    12 22  9312 247478     0.8    - 4 (subtype=success, terminal_reason=completed)
appver     claude claude-haiku-5-5    21 24 11360 319276     2.8    - 4 (subtype=success, terminal_reason=completed)
run-review claude claude-haiku-5-5    26 28 38369 600016     3.0    - 0 (subtype=success, terminal_reason=completed)
tagver     claude claude-haiku-5-5    17 20 11247 248687     0.9    - 4 (subtype=success, terminal_reason=completed)

## agent-cost
agent-cost since 2026-11-24 15:35: haiku $0.01 (cw5m 0.00M cw1h 0.02M), sonnet $0.67 (cw5m 0.00M cw1h 0.05M); total $0.68; sonnet resumes >5m 2 (0.00M written), >60m 0 (0.00M written)

Corrected bugs4 window (11:30-13:30, Opus/Sonnet reads at 0.05x): opus 4.72 + sonnet 5.32 + haiku 0.08 = 10.12 over 9 jobs = about $1.12/job (old figure $1.48 = 13.29/9 at 0.1x). Fable excluded (not in the old figure).

## CI diff (hand edits)
```diff
--- a/.github/workflows/release.yml
+++ b/.github/workflows/release.yml
-# Version name: from pubspec.yaml. Build number: the commit count, so every tag gets a higher one
+# Version name: from the tag (tools/tag-to-version.sh: m16.4 -> 0.16.4), passed as --build-name and --dart-define=APP_VERSION. Build number: the commit count, so every tag gets a higher one
-          echo "name=$(grep -m1 '^version:' controller_app/pubspec.yaml | sed 's/version: *//; s/+.*//')" >> "$GITHUB_OUTPUT"
+          # A manual start (workflow_dispatch) runs on a branch: take the newest release tag then.
+          TAG="$GITHUB_REF_NAME"
+          bash tools/tag-to-version.sh "$TAG" > /dev/null 2>&1 || TAG="$(git describe --tags --abbrev=0 --match "m*" --match "v*")"
+          echo "name=$(bash tools/tag-to-version.sh "$TAG")" >> "$GITHUB_OUTPUT"
+          --build-name=${{ steps.version.outputs.name }}
+          --dart-define=APP_VERSION=${{ steps.version.outputs.name }}
+          --build-name=${{ steps.version.outputs.name }}
+          --dart-define=APP_VERSION=${{ steps.version.outputs.name }}
-          echo "name=$(grep -m1 '^version:' tv_test_app/pubspec.yaml | sed 's/version: *//; s/+.*//')" >> "$GITHUB_OUTPUT"
+          # A manual start (workflow_dispatch) runs on a branch: take the newest release tag then.
+          TAG="$GITHUB_REF_NAME"
+          bash tools/tag-to-version.sh "$TAG" > /dev/null 2>&1 || TAG="$(git describe --tags --abbrev=0 --match "m*" --match "v*")"
+          echo "name=$(bash tools/tag-to-version.sh "$TAG")" >> "$GITHUB_OUTPUT"
+          --build-name=${{ steps.version.outputs.name }}
+          --dart-define=APP_VERSION=${{ steps.version.outputs.name }}
--- a/codemagic.yaml
+++ b/codemagic.yaml
-          VERSION=$(grep -m1 '^version:' controller_app/pubspec.yaml | sed 's/version: *//; s/+.*//')
+          TAG="${CM_TAG:-$(git describe --tags --abbrev=0 --match 'm*' --match 'v*')}"
+          VERSION=$(bash tools/tag-to-version.sh "$TAG")
+          TAG="${CM_TAG:-$(git describe --tags --abbrev=0 --match 'm*' --match 'v*')}"
+          VERSION=$(bash tools/tag-to-version.sh "$TAG")
+          echo "App version $VERSION"
-          DEFINES=(--dart-define=BUILD_NUMBER="$BUILD")
+          DEFINES=(--dart-define=BUILD_NUMBER="$BUILD" --dart-define=APP_VERSION="$VERSION")
+            --build-name="$VERSION" \
```
