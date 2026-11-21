# m16 process1 run review — looks-helper, runner-lean

## Summary

Verdict: **one fix batch** — 2 must, 1 should, 6 could (the wave review's 5 all still hold; 4 are new from the run view).

- must: the helper's `overrides:` merge has no test — the test named for it passes `clock:`, so deleting the spread leaves every test green.
- must: the runner lint and the one-wave skip were never executed; the `.dart_tool/lint-scratch/` batch the report says is waiting does not exist.
- should: the looks report says the menu look had never been checked at those devices; `award_explanation_size_test.dart` checks all twelve awards there with the same assertions.
- The two new test files pass (3 + 5 = 8, 120 explanations, re-run here); no test pins the spread, the lint or the skip.
- Sizing: f1 = findings 1, 3, 9 (party_host test files + the looks report); f2 = 2, 7, 8 (`tools/run-jobs.sh` + the runner report); f3 = 4, 5, 6 (`all_looks.dart`, `screen_fit_test.dart`, `docs/flash-digest.md`). Three jobs, no shared files; none is pinned by controller_app phone tests, so no `phone` in `check:`.
- Owner only: whether the brief's 520-line limit replaces the guideline's 400 for `tools/run-jobs.sh`, and whether the TV-look override goes first or last (the two helpers disagree).

## Findings

- **must** packages/party_host/test/all_looks_support_test.dart:75 "the helper keeps the caller's own overrides in both looks" passes `clock: _callerClock`, which `pumpHost` turns into its own `lookClockProvider` override (host_harness.dart:85) and no test passes a non-empty `overrides:`, so the `[...overrides, …]` merge at all_looks.dart:50 is never exercised → pass an override in that test (e.g. `overrides: [lookClockProvider.overrideWithValue(_callerClock)]`, `clock:` dropped) so removing the spread fails a test. (from: wave1 review)
- **must** docs/briefs/m16/process1/runner-lean-report.md:37 the dry run was never executed (it is not the "first thing next batch" any more: `.dart_tool/` holds only `package_config.json`, `package_graph.json`, `pub`, `version`, so the scratch batch at :39 is gone), and `tools/run-jobs.sh:381` (the lint) and :262 (the skip) therefore have no runtime proof at all → rebuild a one-wave scratch batch with a good, a `report: a.md b.md`, a no-`report:` and a two-`report:` brief, run `--dry-run` (LINT FAIL lines, exit 0) and a real run that stops before wave 1, paste both outputs, and drop the claim that the folder still exists. (from: wave1 review)
- **should** docs/briefs/m16/process1/looks-helper-report.md:90 "The menu look had not been checked at these devices before" is false: award_explanation_size_test.dart:103-150 opens all twelve awards at the same five devices with the same title/line/OK-inside, `maxScrollExtent` 0 and OK-closes checks (and adds the font floor and equal-size checks), while award_explanation_looks_test.dart:85-135 repeats them and adds only the TV column of the same device list → say the file repeats the menu checks to prove the helper's path, or drop the menu look from it and keep the TV half. (from: wave1 review)
- **could** packages/party_host/test/support/all_looks.dart:50 appends the TV flag after the caller's `overrides`, while the older TV pump at packages/party_host/test/screen_fit_test.dart:46 puts `toyTvProvider` first and the caller's overrides after it, so two helpers answer "who wins" oppositely → pick one order for both (screen_fit_test's, which lets a caller override, or this one, with the reason written down). (from: across jobs)
- **could** packages/party_host/test/support/all_looks.dart:32 `pumpHostLook` takes 10 named parameters plus `tester` and `look` against the guidelines' limit of 5 (§3) → keep it as the brief mandated but add it to `docs/code-health.md`, or give `pumpHost` and it one mount-options value object when either next changes. (from: wave1 review)
- **could** docs/flash-digest.md:16 "Worker review is one per wave (`wave<N>-review-report.md`)" is now false for a one-wave plan, and the same file's Run section does not name the skip either → add "a single-wave plan has no per-wave review; the run review covers it" there; the runner-lean job could not edit this file (`allow:`), so it needs a fix job. (from: across jobs)
- **could** tools/run-jobs.sh:131 the file is 485 lines against the guidelines' 400 hard limit (§3), and this job added 33 of them to a brief that set its own limit of 520 → decide whether the brief's number replaces the guideline (and say so in the header) or split the reviewer/commit half into a second script before the next job adds to it. (from: across jobs)
- **could** docs/briefs/m16/process1/runner-lean-report.md:24 "The header gained one line per change" — the diff adds three header lines (tools/run-jobs.sh:36 and :57-58) → reword to "one or two lines per change" or name the three. (from: wave1 review)
- **could** packages/party_host/test/award_explanation_looks_test.dart:14 `_Case`, `_cases`, `_tileWidthPx`, `_TileUnderTest`, `_expectInside`, `_cardKey` and `_closeKey` now stand in three award tests (this file, award_explanation_size_test.dart:14-31, award_explanation_tv_test.dart:14-31) → move them to one support file in a brief that allows editing the two existing tests. (from: across jobs)

## Open questions

1. looks-helper Q1, 11 parameters: keep and record as health debt (safest: keep, brief mandated the mirror).
2. looks-helper Q2, `forEachLook`'s `tester` only unmounts: keep; the reason is in its doc comment (safest: keep).
3. looks-helper Q3, share the `_Case`/device/`_expectInside` copies: yes, but only in a brief that allows editing the two existing award tests.
4. runner-lean Q1, dry run unverified: run it on a fresh scratch batch at the start of the next real batch (safest: do not ship another runner change before it).
5. runner-lean Q2, `docs/flash-digest.md` missing the skip: correct line 16 and the Run section in a docs job (safest: one line each).
6. runner-lean Q3, lint on the `--drop` path: no; a dropped brief never runs (safest: leave it out).
7. wave1 review decisions: the `forEachLook` unmount is safe to confirm; the override order should be unified (finding 4); the column-0-only `report:` read matches `tools/flash.sh:124`'s `field`, so an indented `report:` giving "no report: line" is acceptable.

## Numbers against targets

- Tests: 3 (`all_looks_support_test.dart`) + 5 (`award_explanation_looks_test.dart`) = 8 passed, re-run here; 5 × 2 looks × 12 awards = 120 explanations, matching the report.
- `packages/party_host/test/support/all_looks.dart` 68 lines against the brief's under-150: met.
- `tools/run-jobs.sh` 485 lines against the brief's 520: met; against the guideline's 400 hard limit: over by 85 (finding 7).
- `pumpHostLook` 12 parameters against the guideline's 5: over (finding 5).
- `.dart_tool/lint-scratch/` the report says exists: absent; the lint's LINT FAIL and STOPPED lines have no measured output.
- This run's plan is one wave, yet a wave review ran (run.log 14:02:17) because the runner process started at 13:36, before the skip was committed: the skip is still unmeasured.

## Could not check

- The lint's dry-run and STOPPED output: a temp scratch batch under `/tmp` could not be created here either (Bash approval refused `mkdir`/`printf` on it), and a real run would commit `run.log`, so it was not attempted.
- The whole `party_host` suite and `tools/check.sh format analyze host`: only the two new test files were re-run.
- Whether `.dart_tool/lint-scratch/` existed and was removed by a later `flutter pub get`, or was never there.

## Commit message

```
Review m16 process1 run: looks-helper, runner-lean

Two musts: the helper's overrides: merge has no test (the test named
for it passes clock:), and the runner's brief lint and one-wave skip
were never executed, the scratch batch they name being gone. Should:
the looks report's "menu look not checked before" claim, already
covered by award_explanation_size_test.dart. Could: two opposite
TV-look override orders, the 12-parameter helper, flash-digest's
per-wave review line, run-jobs.sh at 485 lines, and the report's
header-line count.
```

## Status row

m16 process1 run reviewed: 9 findings (2 must, 1 should, 6 could) in docs/briefs/m16/process1/REVIEW.md; open: the helper's `overrides:` test, the runner lint/skip dry-run and stop output, the looks report's menu-look claim, and three docs/consistency fixes.

## Delete

- none


## Verdicts (Claude, Nov 21)
- must 1 (overrides merge untested): real; f1 was blocked (Riverpod refuses two overrides of one provider, so the order change is not possible by design); f2 pinned the merge with a test-local marker provider, break-and-restore shown in f2-report.md. Fixed.
- must 2 (lint and skip never run): verified by hand: dry run on a scratch batch printed LINT FAIL for a two-token, a missing and a doubled report: line (exit 0); a real run stopped before wave 1 with "STOPPED: brief lint: b: ..." (exit 1). The f1/f2 runs logged "wave review skipped: wave 1 is the whole run". Fixed.
- should (menu-look claim): true as noted; kept the menu half, noted in code-health.
- could: override order withdrawn (impossible, see above); 10 parameters, test dedup, 485-line runner: code-health; docs/flash-digest.md line 16 fixed by hand; report wording nits ignored.
