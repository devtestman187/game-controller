# Wave 1 review: g3d1s (commit 75053303)

## Summary
Verdict: small fixes
Counts: must 0, should 3, could 3
1. `tools/sim/bots_test.dart:52` the same-seed check passes even if `performance` ignores its random stream or noise; add a different-seed inequality check.
2. `tools/sim/bots.dart:97-99` greedy with no rivals and own road unavailable silently returns `self` (an unpickable road); the caller contract lives only in a doc comment.
3. `docs/briefs/m17/board3b/run.log:76` the "tests-first ok" proof is a compile failure (no `bots.dart` on the old tree), not a behaviour failure; new files are exempt, so the proof shows nothing.

## Findings
- **should** tools/sim/bots_test.dart:52 The same-seed check only compares two runs of the same stream, so a `performance` that ignores `r` or `noise` still passes → add a check that seed 43 gives a different list from seed 42.
- **should** tools/sim/bots.dart:97 Greedy returns `self` when there are no rivals and the own road is unavailable, a road the caller must not pick, and nothing enforces the guarantee → throw a `StateError` (or assert) in that case and add a check for it.
- **should** docs/briefs/m17/board3b/run.log:76 The tests-first proof says `bots_test.dart` "fails on the old code", but the old code does not exist; the failure is a missing import → state in the report that the proof is a compile check and that the exemption applies.
- **could** tools/sim/bots.dart:5 The doc line is over 120 columns (grep `.{121,}` hits only this line in `tools/sim`) → rewrap the comment to 120 columns.
- **could** tools/sim/bots_test.dart:25 `check` is a public top-level function with no dartdoc, and so is `main` at line 49 → add one-line dartdocs (guideline: every public member has one).
- **could** tools/sim/bots.dart:61 `blockGap` has no unit in its name (tiles) → rename to `blockGapTiles` in the constructor, fields and the two constants (guideline: units in names).

## Decisions to confirm
- `chooseLastPlace` and `chooseRoadworksTarget` are `BotProfile` methods, not free functions as the brief's item 3 lists them. Why: `sim-model.md:16-17` calls them as `profile.chooseLastPlace` and `profile.chooseRoadworksTarget(`, so the code matches the model doc.
- The bot numbers (`bots.dart:108`, `bots.dart:121`) are provisional and labelled as such. Why: the owner's numbers are not in the brief; the report asks the owner to confirm them.
- The greedy fallback to `self` (`bots.dart:99`) is a design choice that the worker made; see the second finding.
- The `childBot` profile uses `blockGap: 0`, which `randomAny` ignores (`bots.dart:61`). Why: harmless, but a reader may take it as a tuned value.

## Could not check
- Running `dart run tools/sim/bots_test.dart` and `dart analyze tools/sim`: the Bash tool refused both with "requires approval", so the worker's PASS lines and "No issues found" are not confirmed by this review.
- `dart format --set-exit-if-changed` on `tools/sim`: not run for the same reason.
- `tools/mine.sh`: not run (the brief says never; the worker's report notes a conflict with the task text).
- The tests-first check beyond `run.log:76`: the runner's evidence was read from the log only.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.
m17 board3b: wave 1 review of g3d1s (findings only)

Reviews commit 75053303 (bots.dart, bots_test.dart, sim-test.sh)
against the coding guidelines, review rules and its brief.
Writes docs/briefs/m17/board3b/wave1-review-report.md with the
findings (0 must, 3 should, 3 could) and the decisions to confirm.
No code changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.
wave1 review of g3d1s done (0 must, 3 should, 3 could; verdict small fixes); open: should-fixes in bots_test.dart and bots.dart, checks not run (approval refused).

## Delete
- none
