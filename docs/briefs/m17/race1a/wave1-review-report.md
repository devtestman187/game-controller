## Summary

small fixes
Counts: must 0 · should 3 · could 5
1. No test pins Hard's cap of 5: per_side_rule_test.dart:25 ("Hard 4 → 4") passes for any cap of 4 or more.
2. match.dart:50 labels an equal split above 4 (5v5, 6v6) as "uneven sides"; no test covers it.
3. Neither worker report has the review-rules part A self-check lines (f1a-report.md:31, f1d-report.md:25).

## Findings

- **should** packages/puzzle_game/test/per_side_rule_test.dart:25 The Hard test only proves a cap of at least 4; the code's cap of 5 (puzzle_rule_levels.dart:49) is pinned by nothing, so a Hard cap of 6 would still pass → add `expect(maxPerSideFor(Level.hard, 9), 5)` once the owner confirms 4 or 5 (see Decisions).
- **should** packages/puzzle_game/lib/src/match.dart:50 Equal splits above 4 a side (5v5, 6v6) fall through to `uneven`, so "uneven sides" is shown for an even match → return a format or label for equal sides (or a documented fallback) and add a 5v5 case to the test at match_test.dart:351-365. Not reachable from the join screen today (join_screen.dart:59 `maxPerSide = 2`).
- **should** docs/briefs/m17/race1a/f1a-report.md:31 The `## Checks` section has no part A self-check (host setups, kept state, combinations, folder, looks) → add the six one-line answers, e.g. "Not affected: join and screens unchanged; checked by host_text_test.dart".
- **should** docs/briefs/m17/race1a/f1d-report.md:25 The `## Checks` section has no part A self-check lines → add them; for a pure rule, "Not affected" is the answer for each host setup and for kept state.
- **could** docs/briefs/m17/race1a/f1d-report.md:28 The brief asked to see the new test fail to compile before the code; the worker did not run that (the report says so) → run it once against the base, or record the exemption as the brief's own wording.
- **could** packages/puzzle_game/lib/src/puzzle_rule_levels.dart:45-47 The doc mixes "pieces" and "seat" for the same number, and `wanted` has no unit (pieces or players?) → say "players" or "pieces" once and rename `wanted` to match (e.g. `wantedPerSide`).
- **could** docs/briefs/m17/race1a/f1a-report.md:43 Question 1 (split layout at 3v3/4v4 on TV and phone) is moot until the join seat cap moves: join_screen.dart:59 still seats two a side → state that in the report so the look check is scheduled with the seat-cap change.
- **could** docs/architecture.md:177 Says "at most two a side" for the join, while the new doc at packages/puzzle_game/lib/src/match.dart:39-40 says "A side holds up to four players" → reword the match.dart doc to describe `of`'s input only (not touched by this wave; fix in the next docs pass).
- **could** docs/briefs/m17/race1a/run-findings.md:1 Says f1d's report has no Summary block in its first 40 lines; confirmed (f1d-report.md starts at `## Files changed`, line 3) → add a Summary block, or record that the template does not require one.

## Decisions to confirm

- **Hard cap 5, not 4.** f1d's brief says "Medium and Hard 4" in the doc and also "wanted limited to min ~/ 2" (Hard min 10 gives 5). The worker chose the formula (puzzle_rule_levels.dart:49) and disclosed it. Why: the two instructions conflict; the owner plan ("4 a side means Medium/Hard only") does not settle Hard. Owner to say 4 or 5.
- **Hidden: equal splits above 4 are "uneven".** match.dart:50 returns `uneven` for any split not listed, including equal ones. Not in the f1a report's decisions. Why: the brief only defined unequal splits. Fix or confirm (see the should finding above).
- **Reflowed four comments in host_text.dart** (f1a-report.md:21-24) to hold the file at exactly 380 lines, where the brief said "shorten a nearby comment". Why: the gate is met with no slack (380 of 380), so the next edit to this file will break it; a split of the file may be the better fix. Confirm the method, or plan the split.
- **"uneven sides" wording** (f1a-report.md:45). Why: shown to players on the join screen; plain, but it does not say what to do next (review-rules B.8). Owner to confirm wording.
- **Hard cap 5 allows 5 a side on Hard** once the seat cap moves: the owner plan does not mention a 5-a-side game. Confirm before seating code calls `maxPerSideFor`.

## Could not check

- The test counts reported by mine.sh (10 in puzzle_game, 20 and 6 in f1a) and the base failure of the new f1a cases: I did not run tests (read-only review); I checked the code and diff only.
- That `puzzle_rule_levels.dart` is linked into `puzzle_rules.dart` (its `part` line): the test calls `maxPerSideFor` through `puzzle_game.dart`, and the export list includes `puzzle_rules.dart`; the `part` line itself was not opened.
- Whether the split layout at 3v3, 4v4 or uneven looks right on a TV or a phone (needs a look; not possible here).
- Guidelines and review rules beyond the worker extract: I used the extract and review-rules.md A and B only; I did not read the full coding-guidelines.md.
- run.log and the other wave jobs' reports (f1b, f1c) were not read; they are outside this review.

## Commit message — a draft

Review wave1 (f1a, f1d): record findings only

Read-only review of the f1a and f1d commits against their briefs, the
coding guidelines and review rules part A and B. No code or document
changed except this report. Findings: Hard's per-side cap of 5 is not
pinned by a test; equal splits above 4 a side are labelled "uneven
sides"; neither worker report has the part A self-check lines. The
Hard cap value (4 or 5) is for the owner to confirm.

## Status row

race1a wave1 review (f1a, f1d): done, verdict small fixes (0 must, 3 should, 5 could); open: owner to confirm Hard cap 4 or 5, and the should fixes (Hard test, 5v5 label, part A self-check lines).

## Delete

- none
