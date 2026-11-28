## Summary

Verdict: needs Claude's design. Three calls first (re-snap double, a snap lifting the fuse, the pause rule); the rest is one fix batch.
Counts: must 2 · should 22 · could 11 (35 findings over r3e, r3f, r3g, read as one change).
Top five:
1. golden_slot.dart:40 `update` has eight parameters (dt and seven named), over the five-parameter cap.
2. present_pop_widgets.dart:120 bare `0.4`, `0.6`, `5`, `4` in the confetti depth (the wave2 report cites :126, which is wrong).
3. puzzle_points.dart:48 a wrong re-snap on the glowing target also pays double and uses up the slot.
4. present_rules.dart:76 a snap lifts a 600 ms fuse to 4000 ms; the bot sim relies on it.
5. Across jobs: the "fails on the old code" proofs are compile errors (r3e, r3g; r3f inferred), and `gapS` means 10.0 in golden_slot.dart:17 and 15.0 in present_rules.dart:32.
Questions only the owner can answer: the +2 golden points with no cue before the Nov 28 playtest; whether the confetti runs over the pause menu while the golden wait freezes (see Open questions).
Sizing: phone-pinned = packages/puzzle_game lib and test files (23 controller_app files reference puzzle_game names; which of them pin the rules was not checked). Host-only = party_host/lib/src/ui present_pop_widgets*, puzzle_screen*, puzzle_results_widgets. Most of the phone-pinned findings are in golden_slot.dart, so give that file one job and split the host-only files into a second.
Hand-fixes: none (run.log has no HAND-FIX line). Fixes without a measured cause: none. No REVIEW-VERDICTS.md or STATUS.md exists; the carry-over is the three wave reports and run-findings.md (one line: r3f has no Summary).

## Findings

- **must** packages/puzzle_game/lib/src/golden_slot.dart:40 `update` takes dt plus seven named parameters (cap is five), and `random:` at :47 repeats the `_random` held at :10-11 → group openLeft, openRight, placedLeft, placedRight into a value object and drop `random:`, or send the conflict back to Claude (from: r3e; phone)
- **must** packages/party_host/lib/src/ui/present_pop_widgets.dart:120 bare `0.4`, `0.6`, `5` and `4` in `final depth = 0.4 + 0.6 * ((i % 5) / 4)` break the magic-number rule → name them as documented constants at the top of the file (from: r3f; host)
- **should** packages/puzzle_game/lib/src/golden_slot.dart:25 and :28 `slot` and `claimedBy` are public mutable fields, so any caller can break the claim rules → make both read-only getters over private fields; `claimedBy` is read only by golden_slot_test.dart:138 (from: r3e; phone)
- **should** packages/puzzle_game/lib/src/puzzle_points.dart:48 the golden claim runs on a wrong re-snap too: `base` is `wrongSnap`, so the re-snap pays 2 and consumes the slot → Claude picks: skip the claim when `again`, or list it as a decision (from: r3e; phone)
- **should** packages/puzzle_game/lib/src/present_rules.dart:76 `_fuseMs = max(minFuseMs.toDouble(), _fuseMs - snapCutMs)` lifts a near-spent fuse to the floor; the sim in fuse_skill_test.dart relies on it → Claude decides; if a snap should only shorten, use `min(_fuseMs, max(minFuseMs.toDouble(), _fuseMs - snapCutMs))` (from: r3g; phone)
- **should** packages/puzzle_game/lib/src/golden_slot.dart:17 `gapS = 10.0` and packages/puzzle_game/lib/src/present_rules.dart:32 `gapS = 15.0` share one name for two waits → rename the golden one (e.g. `glowGapS`) and say so in its doc (from: across jobs; phone)
- **should** packages/puzzle_game/lib/src/golden_slot.dart:38 a doc line runs past 120 columns → rewrap (from: r3e; phone)
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:42 `_goldenAngle` has no unit in its name → rename to `_goldenAngleRad` (its uses are at :118) (from: r3f; host)
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:13 `pops` (a ValueNotifier) is never disposed; `PresentTracker` has no `dispose()`, and packages/party_host/lib/src/ui/puzzle_screen.dart:178-183 does not release it → add `dispose()` to the tracker and call it from `_PuzzleScreenState.dispose()` (from: r3f; host)
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:154 `PresentHeldLine` reads `tracker.heldAtPop` once at build and does not listen to `pops`, so the line is right only if the results mount after the last feed → rebuild on `pops` (a ListenableBuilder), or add a test for a results mount after a pop (from: r3f; host)
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:25 `present!.holder` has a `!` the line before does not prove (:24 tests a local bool) → write `if (present != null && present.popped && !_wasPopped)` and read `present.holder` (from: r3f; host)
- **should** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:39,72,134 +3 lines against the brief's "at most 2, net 0"; the file is now 380, the gate → move at least 3 lines out along a seam, or Claude accepts the overrun (from: r3f; host)
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:37,100,353,371 +4 lines against the brief's "at most 3" (net -1 after `_clocked` moved) → Claude accepts the fourth line, or one is cut (from: r3f; host)
- **should** packages/puzzle_game/test/golden_slot_test.dart:62 the test named "(Chaos off)" uses a two-board match, so "points equal base when no slot is golden" on one board is not tested → add a one-board test expecting 2 points, and rename this one (from: r3e; phone)
- **should** packages/puzzle_game/test/golden_slot_test.dart:82 the disabled test never starts from a glowing slot, but r3e-report.md:47 cites it for clearing a glow → add: glow, then `enabled: false`, then `slot` is null and `claim` returns false (from: r3e; phone)
- **should** packages/puzzle_game/lib/src/golden_slot.dart:86-98 no test checks that a claim restarts the gap (`_restart`, :95-98) or that a claimed target never glows again (:112) → one test for each, each failing without its rule (from: r3e; phone)
- **should** packages/puzzle_game/test/fuse_skill_test.dart:32 and :53-54 `capped` is set and read nowhere, so the 50-bat cap that ends a present is invisible → assert the capped count is 0 for both bots, or remove the field (from: r3g; phone)
- **should** packages/puzzle_game/lib/src/settings.dart:163 the FuseParams doc says the fuse numbers are "in one place", but `popMs` (present_rules.dart:28) and `gapS` (:32) stay outside it; docs/briefs/m17/race1c/r3g-report.md:72 ("edit FuseParams only") is wrong for them → name the two outside constants in the doc and fix the hand-over (from: r3g; phone)
- **should** packages/party_host/test/present_pop_widgets_test.dart:80 no test shows that unmounting `PresentConfetti` releases its listener and its controller (guideline §5 and §9 ask for a dispose test) → add a test that disposes the stage and checks no listener or animation remains (from: r3f; host)
- **should** docs/briefs/m17/race1c/r3f-report.md:23-29 the self-check's first line answers only the looks; host setups (A1) and pause, host away, "Get ready", dropped link and leaving (A3) are not answered, and no format, analyze or test result is reported → add one line per item with its test, or "not affected" with the reason, and the command output (from: r3f; host)
- **should** docs/briefs/m17/race1c/r3g-report.md:11 says `OK 5 tests packages/puzzle_game`; `fuse_skill_test.dart` holds 4 tests, and nothing else is shown to make up 5 → re-run the touched tests and record the real count (from: r3g; phone)
- **should** docs/briefs/m17/race1c/r3e-report.md:21-23 the tests were written with the lib and never run against the base; the "fails on base" proof is by reading only → state it as a process miss in the next brief (from: r3e; phone)
- **should** packages/puzzle_game/test/fuse_skill_test.dart:50 the "tests-first ok ... fails on the old code" lines in run.log are a compile error on base (`FuseParams` is missing; `GoldenSlot` for golden_slot_test.dart, `PresentTracker` for present_pop_widgets_test.dart, inferred), not a behaviour failure; r3g-report.md:12 records the job as exempt while run.log says "tests-first ok" → say compile-level in the reports, or write tests that fail on behaviour (from: across jobs; phone)
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:353 the confetti is mounted outside the `Pausable` paused state and runs over the pause menu (r3f-report.md:27), while the golden wait freezes on pause because `update` is not called (r3e-report.md:74) → one pause rule for both; owner or Claude picks (from: across jobs; host)

- **could** packages/puzzle_game/lib/src/golden_slot.dart:70-82 `stepBoards` builds the two open sets (:76-77) every frame, even while the gate is off → return early when `enabled` is false, before building them (from: r3e; phone)
- **could** packages/puzzle_game/lib/src/golden_slot.dart:137 `return candidates.last.target;` cannot be reached when `total > 0` → return from the loop and drop it, or throw a `StateError` (from: r3e; phone)
- **could** packages/puzzle_game/lib/src/golden_slot.dart:19-20 the doc of the shared weight is garbled → reword: "a target open on both boards, or open on one board with the sides level" (from: r3e; phone)
- **could** packages/puzzle_game/lib/src/match.dart:176 `final GoldenSlot _golden;` has no doc comment; `set settings` at :194 follows the getter at :193 with no blank line → add the doc line and the blank line (from: r3e; phone)
- **could** packages/party_host/lib/src/ui/present_pop_widgets.dart:72-77 the `didUpdateWidget` swapped-tracker branch has no caller and no test → drop it, or pin it with a test (from: r3f; host)
- **could** packages/party_host/lib/src/ui/present_pop_widgets.dart:36 the piece is a fixed 14 px, not sized from the box or `pxPerMm`, and the doc's "three metres on the TV" is not checked anywhere → size it from the box, or reword the doc to the reason (from: r3f; host)
- **could** packages/party_host/test/present_pop_widgets_test.dart:63 the held-line test checks only the Right wording → add the Left case in the same test (from: r3f; host)
- **could** packages/puzzle_game/lib/puzzle_game.dart:31 `export 'src/settings.dart'` makes `FuseParams` public, which the brief did not ask for → keep it (the test uses it) or export it from a narrower library (from: r3g; phone)
- **could** packages/puzzle_game/lib/src/present_rules.dart:11 is over 120 columns (pre-existing, in a touched file), and docs/briefs/m17/race1c/r3g-report.md:67 says lines 11–12; only :11 is over → wrap :11 and correct the report's line range (from: r3g; phone)
- **could** packages/puzzle_game/lib/src/golden_slot.dart:6 and packages/party_host/lib/src/ui/present_pop_widgets.dart:9,44 code comments carry job tags ("M17 race1c r3e", "M17 r3f"), which mean nothing once the run is gone → keep the why, drop the tag (from: across jobs; phone)
- **could** packages/puzzle_game/lib/src/match.dart:339 the file is now 339 lines (328 at the base) and packages/puzzle_game/lib/src/game.dart:325 (320 at the base); both are over the about-300 guide → note for the next job that touches them; no split needed now (from: across jobs; phone)

## Open questions

1. Should the golden double pay +2 with no cue before the Nov 28 playtest? Suggested: keep it, but the owner confirms it before the playtest (r3e Decisions).
2. Should a wrong re-snap on the golden target pay double and use the slot (puzzle_points.dart:48)? Suggested: no; only a correct snap claims.
3. Should a snap lift a near-spent fuse to the floor (present_rules.dart:76, r3g Question 1)? Suggested: no; a snap only shortens, so use the `min` form.
4. Should the pause freeze the confetti too, as it freezes the golden wait? Suggested: one rule for both; freeze both, since the pause menu is a freeze.
5. Should a claimed target stay closed for good (golden_slot.dart:112)? Suggested: yes, as built (r3e Question 2).
6. Should a glowing slot cleared by the gate restart the gap (golden_slot.dart:49-51)? Suggested: keep as built, and confirm.
7. Should `GoldenInputs` (a value object) be made now, or after the playtest? Suggested: now, for the five-parameter cap (r3e Question 1).
8. Should the bot sim assert the 50-bat cap is never hit (fuse_skill_test.dart:32)? Suggested: yes (r3g Question 2).
9. Does the sim keep one `PresentRules` per present, so the gap after a pop is never exercised? Suggested: accept for now (r3g Decisions).
10. Are the bot pace numbers and the 50-bat cap to be replaced at the playtest? Suggested: yes; record the simulated means first (r3g Question 5).
11. Is the 14 px confetti piece right on the phone and TV, unscaled by `pxPerMm`? Suggested: confirm on a device.
12. Accept the 380-line `puzzle_results_widgets.dart` (+3 lines) and `_clocked` moved to puzzle_screen_results.dart? Suggested: accept both; the move is the only way to fit.
13. May a package test import `tools/sim/bots.dart` (fuse_skill_test.dart:6)? Suggested: check the rule; if not, move the bot to the package's test support.

## Numbers against targets

- Brief caps missed: puzzle_results_widgets.dart +3 lines added, net +3 (cap: at most 2, net 0); puzzle_screen.dart +4 added (cap: at most 3), net -1.
- Brief caps met: match.dart 12 lines added (cap 12); golden_slot.dart 139 lines, present_pop_widgets.dart 166, golden_slot_test.dart 162, fuse_skill_test.dart 106.
- Line limits: puzzle_results_widgets.dart 380 (the gate, not over); puzzle_screen.dart 379; game.dart 325 and match.dart 339 are over the about-300 guide (both were already over at the base, 320 and 328).
- Glow: null at 9.516 s, set by 10.516 s, against the 10 s first delay (golden_slot_test.dart:45, r3e report): met.
- Golden double: 4 points = 2 × 2 (snap 2, golden claim pays it again): met, as reported.
- Pop: 1500 ms (`PresentRules.popMs`); pumped at +750 ms still bursting, at +1500 ms gone: met.
- Fuse floor: tests say the lowest fuse stays at or above 4000 ms; that holds by test, but finding 5 shows the rule lifts a fuse to the floor.
- Golden picks: 3000 picks, seed 7: left placed 2, right placed 1; expected share 10/15 = 2/3, asserted within 0.05; the observed share was not printed (the assertion passed).
- Bot sim: child mean at least 1 bat per present (target 1): reported as passing, means not recorded; adult above child: passing; the 50-bat cap counts are not recorded.
- Test counts: r3e `551 OK` (mine.sh, not re-run here); r3g `OK 5 tests` against 4 new tests (finding above).

## Could not check

- No tests, analyzer or format run here (read-only job): "551 OK" and "OK 5 tests" are unverified.
- The "fails on the old code" results were not reproduced; the compile-error reading is inferred from the missing symbols.
- Whether a pause, a host away or a dropped link stops `PuzzleMatch.update`: puzzle_session.dart's gating was not read.
- Looks on TV and phone: no screenshot exists; confetti and the held line were not seen.
- Which controller_app tests pin the golden and fuse rules: only that 23 files reference puzzle_game was checked.
- `(1 - progress).clamp(0, 1)` as the `alpha:` argument (present_pop_widgets.dart:122): its type is confirmed only by the run.log check result.

## Commit message — a draft

review: race1c run findings (no code changed)

Read the r3e, r3f and r3g changes as one run against the coding guidelines
and review rules. Two must items (an eight-parameter GoldenSlot.update, bare
magic numbers in the confetti), 22 should and 11 could.
Three design calls need Claude first: the double on a wrong re-snap, the snap
that lifts a fuse to the floor, and the pause rule for confetti and the golden wait.
Only docs/briefs/m17/race1c/REVIEW.md is changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

race1c run review: done (needs Claude's design: 2 must, 22 should, 11 could); open: the three design calls, the golden gapS name, the two line-cap overruns, the compile-level tests-first proofs.

## Delete

- none
