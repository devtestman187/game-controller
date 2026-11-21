# m16 process1 wave 1 review — looks-helper, runner-lean

## Summary

Verdict: **small fixes** — 5 findings: 2 must, 1 should, 2 could.

- must: the test named for the caller's overrides passes `clock:`, so the helper's `overrides:` merge is untested and could be deleted with every test still green.
- must: runner-lean's brief item 4 was not done, and the `.dart_tool/lint-scratch/` batch the report cites does not exist, so the lint's dry-run and STOP output were never produced.
- should: the looks report says the menu look was not checked at these devices; `award_explanation_size_test.dart` already checks it there, so the new 138-line test adds no assertion.

## Findings

- **must** packages/party_host/test/all_looks_support_test.dart:75 the test "the helper keeps the caller's own overrides in both looks" passes `clock:` (which `pumpHost` turns into its own `lookClockProvider` override, host_harness.dart:85), and no test passes a non-empty `overrides:` list, so the helper's `[...overrides, tv]` merge at all_looks.dart:50 is untested → also pass an override in that test (e.g. `overrides: [lookClockProvider.overrideWithValue(_callerClock)]` with `clock:` dropped), so deleting the spread fails a test.
- **must** docs/briefs/m16/process1/runner-lean-report.md:39 the folder it names, `.dart_tool/lint-scratch/`, does not exist (`.dart_tool` holds only package_config.json, package_graph.json, pub, version), and brief item 4's dry-run, LINT FAIL and STOP outputs were never produced → re-create the batch, run both dry-run cases plus a real-lint stop, paste the outputs and correct the report.
- **should** docs/briefs/m16/process1/looks-helper-report.md:90 "The menu look had not been checked at these devices before" is false: award_explanation_size_test.dart:109-150 runs all twelve awards at the same five devices with the same title/line/OK-inside, maxScrollExtent 0 and OK-closes checks, and award_explanation_tv_test.dart:105-134 is the TV half, so the new test asserts nothing those two do not → say the file repeats them to prove the helper's path, or drop one look per device.
- **could** packages/party_host/test/support/all_looks.dart:32 `pumpHostLook` has 11 parameters against the guidelines' limit of 5 (§3) → keep the brief-mandated copy but record it, or introduce a mount-options value object shared with `pumpHost` when either next changes.
- **could** docs/briefs/m16/process1/runner-lean-report.md:24 "The header gained one line per change" — the diff adds three header lines (tools/run-jobs.sh:36, :57-58) → reword.

## Decisions to confirm

- all_looks.dart:63 `forEachLook` unmounts the previous look's tree with `pumpWidget(const SizedBox.shrink())`: extra behaviour the brief did not name, and the only use of its `tester` argument (needed for the TV look's extra override) — safe if confirmed.
- all_looks.dart:50 the TV flag is appended after the caller's overrides, so a caller cannot ask for the TV look with it off, and passing its own `toyTvProvider` override duplicates that provider; screen_fit_test.dart:46 uses the opposite order — pick one order for both helpers.
- tools/run-jobs.sh:141 the lint reads only column-0 `report:` lines and skips done/dropped jobs, so it runs after `start at` and pub get, and reports an indented `report:` line as "no report: line" (the report's decision 2) — confirm both.

## Could not check

- The jobs' own `flutter test` runs were not re-run here; run.log (13:50-13:51) confirms only that both new test files fail on the old code.
- The lint's LINT FAIL and STOP output and the one-wave skip were not executed here either: `tools/run-jobs.sh ... --dry-run` needs approval in this session too; `bash -n tools/run-jobs.sh` passes and 485 lines.
- Whether the worker's sandbox really refused the dry run (its report says so; the allow-list in docs/flash-digest.md batch rule 14 makes it plausible).

## Commit message

```
Review m16 process1 wave 1: looks-helper, runner-lean

Two musts: the helper's overrides: merge has no test (the test named
for it passes clock:), and runner-lean's dry-run verification was
never run — the .dart_tool/lint-scratch batch does not exist.
Should: the looks report's "menu look not checked before" claim, as
award_explanation_size_test.dart already checks it at the five
devices. Could: the helper's 11 parameters and the report's
header-line count.
```

## Status row

m16 process1 wave 1 reviewed (looks-helper, runner-lean): 5 findings (2 must, 1 should, 2 could) in docs/briefs/m16/process1/wave1-review-report.md; open: the helper's `overrides:` test, the runner lint's dry-run/STOP verification, and two report claims to correct.

## Delete

- none
