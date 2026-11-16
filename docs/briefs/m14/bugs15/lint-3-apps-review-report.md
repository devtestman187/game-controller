## Summary

`small fixes` — 0 must, 2 should, 4 could.
The three packages really are lint-clean (`dart analyze packages/metrics controller_app tv_test_app` → No issues found,
run now), the formatting is clean, and the type changes do not alter runtime matching.
The three that matter most: the report's Decision 4 describes a throw the code no longer has (`_throwFailure` also
rethrows `Error`s); the committed Hand-over and Status row still call `connection` (19) and `protocol` (5) open when
they were fixed by the parent commit `0c1e1eed`; three exported `addRound`/`addPlayer` signatures changed and no
Decision names them.

## Findings

- **should** docs/briefs/m14/bugs15/lint-3-apps-report.md:40 says the fake now throws `throw error is Exception ? error : Exception('$error')`, but the code is a `_throwFailure` helper that rethrows an `Error` unchanged (and that expression's static type is `Object`, so it would not pass `only_throw_errors`) → rewrite Decision 4 to describe `_throwFailure` and state that `Error`s pass through.
- **should** docs/briefs/m14/bugs15/lint-3-apps-report.md:23 (and the Status row at :127) list `connection` 19 and `protocol` 5 as still open, but the parent commit `0c1e1eed` fixed both and `dart analyze packages/connection packages/protocol` is clean at this commit (only party_host 9, puzzle_game 5, test_game 1 and toy_look 1 remained) → drop connection and protocol from the open list before it becomes the STATUS row.
- **could** packages/metrics/lib/src/report_rounds.dart:60 (also :77 and packages/metrics/lib/src/report_games.dart:104) changed the parameter type of exported `RateRow.addRound`, `RateRow.addPlayer` and `FeatureRow.addRound` from `Map` to `Map<Object?, Object?>`, which the brief counts as a public-API change and no Decision mentions; no caller breaks, since every `Map` is a subtype → add one line to Decisions saying the signatures changed and why it is safe.
- **could** controller_app/lib/src/haptics.dart:241 adds a new top-level, test-only `_throwFailure` to a shipped lib file, while guidelines §2 puts test-only code under `test/` (the file's `FakeHaptics` is the same, pre-existing debt) → make it a private method of `FakeHaptics` so the new code sits where the existing test-only code already is.
- **could** controller_app/lib/src/haptics.dart:244 the new `throw Exception('$error')` branch has no test: both tests set an `Exception`/`PlatformException`, so the wrapping path is unverified → add a test that sets `failWith = 'boom'` and expects an `Exception`, or say in the comment that the branch is unreachable today.
- **could** docs/briefs/m14/bugs15/lint-3-apps-report.md:9 counts 8 `inference_failure_on_collection_literal`, but the diff types 9 empty literals (csv_app_comma:33, csv_app_version:32, csv_build_guard:51, csv_build:51, round_tags:73 and :85, view_report:32, :43, :44) → make the table match the diff, or say which one the analyzer did not report.

## Decisions to confirm

- `Map<Object?, Object?>` for decoded summaries (report Decision 1): weaker than `Map<String, Object?>`, but the `case final Map<Object?, Object?> stats` pattern still matches every `Map`, so nothing changes at runtime — confirm this over validated casts.
- The hand-fix changed the code after the report was written (`run.log:67`, commit message "Hand-fixed"): the committed report is the worker's account of the pre-fix tree, so Decisions 4 and the open-issue list are stale by construction — decide whether to correct the report or leave it as the worker's record.
- `FakeHaptics.failWith` stays `Object?` and now wraps anything that is neither `Error` nor `Exception` — confirm no test or caller will want a raw non-Exception throw.

## Could not check

- The pre-fix analyzer output (55 by kind, and the 40 repo-wide counts) is not in the repo, so those totals cannot be recomputed; only the tip's `No issues found` can.
- `controller_app`'s full 505-test suite was not rerun by me; I ran `test/haptics_test.dart` and `test/pad_test.dart` (30 passed), and the runner records "phone pass" at `run.log:67` after the hand-fix.
- `tools/review.sh` (0 fail, 4 note claimed) was not rerun.
- The `Map<Object?, Object?>` pattern matching every `Map` is reasoned, not executed; no runtime probe was run.

## Commit message

```
review: lint-3-apps, 0 must, 2 should, 4 could

The three packages are analyzer- and format-clean (checked now), and the
type-argument changes do not alter matching or behaviour. Two report
lines are wrong: Decision 4 describes a throw expression the hand-fix
replaced with `_throwFailure` (which keeps `Error`s), and the Hand-over
and Status row still call connection and protocol open although the
parent commit fixed them. Three exported `addRound`/`addPlayer`
signatures changed without a Decision note.
```

## Status row

M14 bugs15 lint-3-apps review: 0 must, 2 should, 4 could (report Decision 4 and the open-package list are stale, three exported signatures changed silently); open: the two report corrections, the Decision line, and the untested `_throwFailure` branch.

## Delete

- none
