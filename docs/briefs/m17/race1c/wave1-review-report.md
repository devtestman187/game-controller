# Review of wave 1 (race1c r3e): golden slot rules

## Summary

needs Claude
Counts: must 1 · should 6 · could 5
1. golden_slot.dart:40: `update` takes seven named parameters; guidelines §3 cap is five, and the brief asks for seven. Guidelines §11 says stop and report such a conflict, not pick one.
2. puzzle_points.dart:48: the golden claim also doubles a wrong re-snap (`wrongSnap` = 1); this is not in the job's Decisions list.
3. golden_slot_test.dart:82: the self-check (r3e-report.md:47) cites "the disabled test" for clearing a glowing slot, but that test never has a glowing slot; no test covers it.

## Findings

- **must** packages/puzzle_game/lib/src/golden_slot.dart:40 `update` has seven named parameters, over the five-parameter cap (guidelines §3), and the job kept it on the brief's word → group the four board inputs into a value object and drop `random:` (the object already holds `_random`), or send it back to Claude as a brief/guideline conflict.
- **should** packages/puzzle_game/lib/src/golden_slot.dart:25 `slot` and :28 `claimedBy` are public mutable fields, so any caller can set the glow and break the claim rules → make both read-only getters over private fields.
- **should** packages/puzzle_game/lib/src/puzzle_points.dart:48 the golden claim pays `base`, which is `wrongSnap` (1) on a re-snap, so a wrong re-snap on the glowing target earns 2 → double only `PuzzlePoints.snap`, or list this as a decision for Claude.
- **should** packages/puzzle_game/test/golden_slot_test.dart:62 the test named "(Chaos off)" runs a two-board match, where `golden` is set (match.dart:150), so the brief's "points equal base when golden is null" case (one board, `golden` null) is not tested → add a one-board snap test expecting 2 points and rename this one.
- **should** packages/puzzle_game/test/golden_slot_test.dart:82 no test starts from a glowing slot and checks that `enabled: false` clears it (golden_slot.dart:49-51), though the self-check at r3e-report.md:47 cites this test for it → add a test: glow, then `enabled: false`, then `slot` is null and `claim` returns false.
- **should** packages/puzzle_game/lib/src/golden_slot.dart:86-93 no test checks that a claim restarts the `gapS` wait (`_restart`, :96-98) or that a claimed target never glows again (:112); both are rules the brief or the job's Decisions name → add a test for each, each failing without its rule.
- **should** docs/briefs/m17/race1c/r3e-report.md:21-23 the brief says "Run it first, then change lib" (tests first), and the report admits the tests were written with the lib and never run against the base → state it as a process miss in the next brief; there is no evidence the tests fail on the old code, beyond the compile error.
- **could** packages/puzzle_game/lib/src/golden_slot.dart:70-82 `stepBoards` builds two open-target sets every frame (`_openOn`, :101-108) even while the gate is off, which is every frame on Chaos off and Wild → return early when `enabled` is false, before building the sets.
- **could** packages/puzzle_game/lib/src/golden_slot.dart:137 `return candidates.last.target;` cannot be reached when `total > 0` (the loop always returns) → drop it and return from the loop, or throw a `StateError`.
- **could** packages/puzzle_game/lib/src/golden_slot.dart:19-20 the doc says the shared weight is for "one open only on the side that is behind on a tie", which is garbled; the constant is used for both-open targets and for a tie → reword to "a target open on both boards, or open on one board with the sides level".
- **could** packages/puzzle_game/lib/src/golden_slot.dart:28 `claimedBy` is written at :89 and read only by golden_slot_test.dart:138; nothing in the game uses it → keep as a getter if the snapshot job needs it, or drop it now.
- **could** packages/puzzle_game/lib/src/match.dart:176 `final GoldenSlot _golden;` has no doc comment, unlike its neighbours, and match.dart:194 `set settings` follows the getter at :193 with no blank line → add the doc line and the blank line.

## Decisions to confirm

- The double is paid with no sign on screen: the glow is not in the snapshot, so no player can see the golden target (the report's own suggestion defers this). Owner to confirm before the playtest, since a kid gets +2 without a cue.
- The re-snap double (puzzle_points.dart:48), not in the job's Decisions list. Claude to pick: double the base snap only, or keep it and list it.
- `stepBoards` was added outside the brief's list (golden_slot.dart:70), to keep match.dart within its 12-line cap. Confirm it stays.
- A claimed target never glows again (golden_slot.dart:112). The brief is silent; listed in the report. Confirm.
- A glowing slot cleared by the gate does not restart the gap (golden_slot.dart:49-51), so the next glow after a disable waits the first delay again. Confirm this is wanted.
- A target open on one board only, with the sides level, weighs 1 (golden_slot.dart:120), and on the leader's board weighs 0. Listed in the report; confirm.

## Could not check

- Whether a pause, "Get ready", a host away, or a dropped link stops `PuzzleMatch.update`: the only call I read is puzzle_session.dart:149; the gating in the base session was not read. The self-check at r3e-report.md:48 is unverified.
- Runner evidence: docs/briefs/m17/race1c/run-findings.md does not exist, and I ran no tests or checks, so the "551 OK" claim is unverified here.
- Test values: the 9.516 s glow time (golden_slot_test.dart:45) depends on the `drive` helper, and the 4-point expectation (:58) on the Lively pointsScale; neither helper was read.
- Each host setup (TV, phones, one build older) was not run; only the match-level rule is covered by the tests.
- The brief says "nothing else" for the report, but the job also asks for three closing sections; they follow the four review sections here.

## Commit message — a draft

Review wave1 r3e: golden slot findings (no code changed)

Review of race1c r3e against the coding guidelines, the review rules and its brief.
Findings: the seven-parameter GoldenSlot.update (guidelines cap is five), the golden
double on a wrong re-snap, public mutable slot and claimedBy, and four missing tests.
Only docs/briefs/m17/race1c/wave1-review-report.md is changed.

## Status row

wave1 review r3e: done (1 must, 6 should, 5 could, written); open: Claude to decide the parameter-count conflict, the re-snap double, and the findings.

## Delete

- none
