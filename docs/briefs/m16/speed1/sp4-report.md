# sp4 report: the combined check runs the affected suites at -j 4 and formats the jobs' .dart files

## Summary

The combined check now runs only the suites that tools/affected.sh names for the wave's changes (RUN_CHECK_FULL=1 runs all of them), at `check.sh -j ${RUN_CHECK_JOBS:-4}`. Before it, the runner runs `dart format` on the .dart files each job's `allow:` names, and only the ones dart format says need it; it no longer stops on a format difference. The tools suite keeps its old rule. A failing or missing tools/affected.sh WARNs and skips no suite for its paths.

Tests: `bash tools/tests/run-affected-test.sh` 8 of 8 pass (new file). `check-scope-test.sh` 9 of 9 pass. `run-wave-test.sh` 4 of 4 pass. `run-jobs-split-test.sh` 13 of 13 pass. `tools/mine.sh`: RESULT ok (0 Dart files formatted, 0 packages analyzed, 0 Dart tests: the change is shell only).

Decisions:
- The tools rule is a floor in every path: the tools suite is skipped only when no job changed a file under tools/, even when affected.sh fails. "Every suite" in the brief was read as "every suite the tools rule allows" so that the existing tools test keeps its pin.
- One log line per combined check, in three forms: the old tools-skipped line, the old tools-runs line, or `combined check: skips <list> (no job's change reaches them)`. A failing affected.sh adds one WARN line before it.
- `format_one` runs `dart format --output=none --set-exit-if-changed` first and formats only when that exits 1; any other exit code (a file dart cannot parse) is left for the format check to fail.
- A `dir` entry in `allow:` expands to the .dart files under it (`find`).

Tests-first (run before any code change, the FAIL lines it printed):
- FAIL a wave changing only packages/a skips b and tools, runs check.sh -j 4, and logs one combined-check line (got `skip=tools args=`)
- FAIL RUN_CHECK_FULL=1 skips no suite but the tools suite (got `skip=tools args=`)
- FAIL a wave touching tools/check.sh runs every suite, the tools suite included, with one log line (got `skip= args=`)
- FAIL a failing tools/affected.sh WARNs and runs every suite (only the tools rule skips one) (got no WARN)
- FAIL a missing tools/affected.sh WARNs and runs every suite (only the tools rule skips one) (got no WARN)
- FAIL an allowed .dart file that dart format wants changed is formatted and logged for its job (nothing formatted)
- PASS a .dart file outside every allow: is not touched (guard: old code formats nothing)
- PASS turn_cap accepts an over-cap job with result 0 and its report, with a WARN (guard: existing behaviour)
Result: `RESULT: FAILED: 6 of 8 case(s) failed`.

Values computed for the expectations (run-affected-test.sh, after the change):
- case 1 (packages/a/lib/x.dart changed, job j1): affected --not gives `b tools`; CHECK_SKIP=`b tools`; check.sh args `-j 4`.
- case 2 (same change, RUN_CHECK_FULL=1): CHECK_SKIP=`tools`.
- case 3 (tools/check.sh changed): CHECK_SKIP empty; note "the tools suite runs".
- cases 4 and 5 (affected.sh exits 2 / removed, committed in the base so the tools rule sees no change): CHECK_SKIP=`tools`; WARN logged.
- cases 6 and 7 (jobs j1 and j2, dart stubbed): `dart format packages/a/lib/x.dart` and `dart format packages/b/lib/z.dart` run, both logged `formatted <file> for <job>`; packages/b/lib/y.dart (allowed by no job) is not passed to dart at all.
- case 8 (fake usage row: 40 turns; brief `turns: 30`): result 0 with a report gives `WARN: job j1 used 40 turns, over its cap of 30 (its own checks passed; accepted)` and return 0.

Self-check (docs/review-rules.md part A):
1. Host setups: not applicable (shell runner change; no host, phone or TV). Runner paths covered by case 1 and the run-wave and run-jobs-split tests.
2. Kept state: RUN_CHECK_SKIP is set on every call of check_scope and read by check_once; it is not kept between checks. A combined check with no jobs still runs affected.sh; not separately tested.
3. Combination with the pause menu, host away, player away, Get ready, dropped link, results, leaving: not applicable.
4. Folder and allow: only the files below were changed. tools/tests/check-scope-test.sh is in allow:; the change is a fixture only (see Questions).
5. Stops: none. The turn cap is unchanged (tools/run-wave.sh not touched).
6. Looks: not applicable.

Checked by reading (not run here):
- checks() gets the job names as ONE space-joined argument: run-jobs.sh:341 `checks "${ok[*]}"`. check_scope "$@" passes that one string on, and format_job_files splits it with `$*`.
- check.sh already takes `-j N` (check.sh:137, 145; check-par.sh). The change adds no line to run-steps.sh's cap: 249 lines (cap 250).
- turn_cap at result 1: it returns 1 and finished_job parks the job (run-wave.sh:58-66, run-jobs.sh:341-ff.); the run-wave test case "over its cap with result 1 is parked" passes.

## Questions

1. check-scope-test.sh: its temp repo had no tools/affected.sh, so check_scope's new WARN made its one-line assertion fail. I gave the fixture an affected.sh that prints an empty line (every suite selected) instead of loosening the one-line check. Is that acceptable?
2. Fallback: "falls back to every suite" is implemented as "no suite skipped for its paths, the tools rule still applies". A literal "every suite" would also run the tools suite on an untouched tools/. Confirm the tools-rule reading.
3. Real combined check with `-j 4`: not run here (tools/check.sh is outside allow:, and the brief bars running it). The flag is passed as `check.sh -j 4` with CHECK_SKIP as before; check.sh's own -j handling is covered by its own tests, not by this job.
4. mine.sh reverted three files that were already modified in the worktree before this job began: tv_test_app/windows/flutter/generated_plugin_registrant.cc, generated_plugin_registrant.h and generated_plugins.cmake (its churn step). They are not in allow:, and git commands are not allowed, so I could not restore them. Please check they are still wanted.
5. The turn-cap test case uses a POSIX temp path: awk -v reads the backslashes of a Windows temp path as escapes, and the usage row then did not match. A test that builds its usage row from a Windows temp folder would fail silently.

## Suggestions

- run-jobs.sh:341 could pass the job names as separate arguments (`checks "${ok[@]}"`). check_scope and format_job_files would then not need the `$*` split. Not done: run-jobs.sh is outside allow:.
- The combined check's dart format runs before the job's checks, so a file that dart cannot parse still fails at the format check with no retry. That is the existing behaviour for format failures.

Files changed:
- tools/run-scope.sh: check_scope (takes the job names, RUN_CHECK_FULL, affected.sh --not, the tools rule, one log line, WARN on affected.sh failure); format_job_files and format_one (dart format on the allowed .dart files that need it).
- tools/run-steps.sh: check_once passes `-j "${RUN_CHECK_JOBS:-4}"`; checks() calls `check_scope "$@"`. Two lines changed in place, no lines added.
- tools/tests/run-affected-test.sh: new, 8 cases (see Summary).
- tools/tests/check-scope-test.sh: steps_repo gets a tools/affected.sh that prints an empty line (see Questions 1).
- docs/briefs/m16/speed1/sp4-report.md: this report.

## Commit message

runner: combined check runs affected suites, -j 4, formats job files

The combined check now runs only the suites tools/affected.sh names for
the wave's changes, with check.sh -j ${RUN_CHECK_JOBS:-4}. RUN_CHECK_FULL=1
runs every suite. The tools suite keeps its rule: it runs only when a job
changed a file under tools/. A failing or missing affected.sh WARNs and
skips no suite for its paths.

Before the check, the runner runs dart format on the .dart files each
job's allow: names that dart format says need it, instead of stopping on a
format difference. The change is in tools/run-scope.sh, with two lines in
tools/run-steps.sh.

## Status row

sp4 done: the combined check runs the affected suites at -j 4 (RUN_CHECK_FULL=1 runs all), and formats the jobs' allowed .dart files before it; open: a real combined check with -j 4 not run here, and mine.sh reverted three generated tv_test_app/windows files that were modified before this job.

## Delete

- none
