# M14 bugs11: the run's review (b020-solo-card, b020-next-map)

Read as one change, `b8638dd..f9cacfb`: `f11c4b1` (a night's one player keeps the Arena's card: two lib
files, five test files, party-night.md) and `d187a5b` (a report only). Both per-job reviews, both job
reports, run.log (13 lines) and the tips of the changed files were read. Verdict: **one fix batch**.

## Summary

**Verdict: one fix batch.** 0 must, 5 should, 5 could. The fix in `f11c4b1` is sound: `_alone`, its
`when` branch and `SoloRoundStart` are gone, the card shows for a night's one player, `skipsLobby` is
Shape Race's alone, N6 and section 8 say so, and the rewritten pins keep their intent; 23 tests green at
the tip, nothing dead or weakened. The batch is docs and tests.

The five that matter most:
1. the one setup whose press flow changed — a lone night player on a phone that **plays here** (a Ready
   tap now starts the round) — still has no test (`arena_touch_ready_test.dart:110`, p2 at `:56`).
2. `docs/code-health.md` keeps two notes on code this run deleted (`_alone` `:109`, the empty-box solo
   start `:102`) and a `game_screen.dart` size that is 373 now, not 379 (`:99`).
3. the next-map proposal's sizes (`:32-34`, `:136-142`) predate `f11c4b1`: 373 / 381 / 370, not
   379 / 387 / 376 — the `_debugKeys` split is still needed, by one line.
4. the proposal misses that a button placed second (`:68`) moves `menu_press_test.dart:61-64`'s Right
   press off Change mode.
5. its hand-over (`:223`) has no step for `docs/design/party-night.md:107`, the results' three-button line.

Hand-fixes: none in run.log; tests-first proof is the solo-card red run (claimed, not reproducible here)
and the next-map proposal (exempt, text only). One wave, three jobs, no shared files, none phone-pinned:
A = `b020-next-map-report.md` (3, 4, 5, with 7 folded in); B = the party_host tests (1, 6, 8); C = docs
and a comment (2, 9, 10).

## Findings

- **should** packages/party_host/test/arena_touch_ready_test.dart:110 the phone host's night card is only tested with a second phone added (`:56`), so the setup whose behaviour changed — a lone night player on a phone that plays here, where the round now waits for that player's Ready tap — has no test → add a one-player variant of `openTouchNightCard` (`:49`, whose `ownPhoneOverrides` helper at `:23` lives only in this file) expecting the card, one Ready tap and the round started. (from: b020-solo-card review)
- **should** docs/code-health.md:109 the `_alone` note describes the field `f11c4b1` deleted, and `:102`'s "a night's solo Bumper start draws an empty box" describes the deleted `SoloRoundStart`; `:99`'s `game_screen.dart 379/380` is 373 now → drop `:102` and `:109` and correct `:99` in the same job as the next Arena change. (from: across jobs)
- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:32 the size arithmetic (`:32-34`, `:136-142`) is the pre-b020 file (379 / 387 / 376), while at HEAD `game_screen.dart` is 373 lines, 381 with `onNextMap` + `_nextMap` and 370 with the `_debugKeys` move, so the split is still required but by one line → carry 373 / 381 / 370 into the next brief. (from: b020-next-map review)
- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:187 the test list gives `menu_press_test.dart` only the new argument, but with the button second (`:68`) that harness's `dpadRight` walk (`menu_press_test.dart:61-64`, expects `['again','again','mode','mode']`) lands on Next map → list that expectation's change beside the placement, or place the button after Change mode. (from: b020-next-map review)
- **should** docs/briefs/m14/bugs11/b020-next-map-report.md:223 the hand-over job has no doc step, while `docs/design/party-night.md:107` names the results' "Play again / Change mode / Back, or Next" → add that line to the follow-up job, as b020-solo-card updated N6 and section 8 itself. (from: b020-next-map review)
- **could** packages/party_host/test/solo_arena_card_test.dart:52 "opens on Surprise me" is proved only by the absent `chosenMap-pinball` key and the test never reads the map the round played (`:63` reads the mode only) → also assert `arenaSnapshot(tester).mapId` is not `'pinball'` after `roundStarted`. (from: b020-solo-card review)
- **could** docs/briefs/m14/bugs11/b020-next-map-report.md:143 the seam is rejected for needing nine constructor arguments while the chosen change gives a tenth to `_ResultsBody` (`arena_results.dart:136-146`, nine today), and `:68` calls that `Wrap` `ArenaResults`' though it is `_ResultsBody`'s (`arena_results.dart:174`) → say how the body's callbacks are carried (a value object or a `_ResultsButtons` widget) and count the pass-through. (from: b020-next-map review, across jobs)
- **could** packages/party_host/test/solo_arena_card_test.dart:17 `openNightBumperCard` is used by test 2 only and repeats test 1's setup (lines 36-45) → give it the `setMap` case as a parameter and let test 1 use it, or inline it into test 2. (from: b020-solo-card review)
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:74 "as Shape Race's join screen does for two" reads as exactly two, while that join screen shows for two or more → say "for two or more". (from: b020-solo-card review)
- **could** docs/briefs/m14/bugs11/b020-solo-card-report.md:19 the run base's `game_screen.dart` was 379 lines, not 380, so the change is 6 lines shorter, not 7 (`:10` and `:61` repeat 380) → use 379 → 373 wherever the next brief or the report quotes it. (from: across jobs)

## Open questions

1. **Both modes in a solo night?** (b020-solo-card) Suggested: no for now — night points, the scoreboard and the awards assume the Bumper Round (N7); say Bumper-only in N7/section 8 and revisit when a race ends.
2. **A fourth results button, "Next map", on the owner-approved card, and those words?** (b020-next-map Q1) Suggested: yes to the button; keep "Next map" (B-020's own words, "Next puzzle" is taken), and let the owner see a mock-up first (`party-night.md:5`).
3. **Should Next map also appear in a night?** (Q2) Suggested: no — the night keeps its one Next (§4) and its map step is the waiting card.
4. **Should the card open on `lastMapId` instead of the saved `mapId` outside a night?** (Q3) Suggested: no — a card that remembers the host's pick has been the behaviour since M14.2.
5. **One shared "one more round" rule for every game's results before M15?** (Q4) Suggested: yes, one design line in `party-night.md` now that Shape Race has five buttons and the Arena would have four.
6. **May `_debugKeys` (`game_screen.dart:30-40`) move to `game_debug_overlay.dart`?** (b020-next-map review) Suggested: yes — they are the overlay's keys and the next job needs the 11 lines.

## Numbers against targets

- `game_screen.dart` 373 lines: inside the brief's 380 cap, over the guidelines' 300 aim (the
  `tools/review.sh` note the report quotes; not new).
- With the planned button and no split it is 381, i.e. over the cap: the `_debugKeys` move is required,
  not optional — the proposal's 379 / 387 / 376 miss the actual 373 / 381 / 370 by six.
- `arena_results.dart` 309 lines today (the proposal plans ~318): 3 buttons outside a night and 1 in a
  night (`:174-200`), so the proposal's button table is right.
- Map library checked: 5 maps (`packages/test_game/maps/index.json`), all 5 with a `bumper` section, 3
  with `race` (playroom, block-castle, toy-factory) — the proposal's table holds.
- Tests at the tip: `solo_arena_card_test` + `night_round_test` + `solo_skip_test` = 23 green (the
  report's 23). Its `host` 465 / `phone` 475 were not re-run.
- B-020's row asks for "the map and game type": only the map half is shipped; the mode half is open
  question 1, so the row stays partly open in STATUS.

## Could not check

- The red run on `b8638dd` (no git state changes): reasoning says test 1's first `arenaWaitingCard`
  expectation must fail there, since `_alone` returned `SoloRoundStart`.
- `tools/check.sh host` (465) and `phone` (475) at the tip, and `tools/review.sh` (0 fail, 1 note): not
  re-run — the working tree carries unrelated changes (`docs/design/m13-*.png`, `tv_test_app/windows/*`)
  and a full suite rewrites tracked PNGs.
- Whether the runner's tests-first gate actually ran for b020-solo-card: run.log records result 4 and the
  dropped `site/shots` churn, no gate line.
- The owner's look of the restored card (no picture in this run).
- `docs/briefs/m14/bugs11/STATUS.md` does not exist, so the targets above are the two briefs and
  `docs/briefs/m14/STATUS.md`, which has no bugs11 row yet.

## Commit message

M14 bugs11: review of the run (b020-solo-card, b020-next-map)

Reads b8638dd..f9cacfb as one change: the Arena's card coming back
for a night's one player is right and test-backed, and the Next-map
report is a proposal only. Five shoulds and five coulds: the missing
test for a lone night player on a phone that plays here, three stale
docs/code-health notes on code this run deleted, and the proposal's
pre-b020 sizes (373/381/370, not 379/387/376), its missed
menu_press_test press order and the design line at party-night.md:107
its hand-over leaves out. No code must.

## Status row

M14 bugs11 review: done — b020-solo-card is a sound, test-backed fix (23 tests green at the tip), b020-next-map is a proposal only; open: one fix batch of 5 shoulds and 5 coulds (a phone-host solo night test, stale docs/code-health notes, the proposal's sizes, press order and design-doc step) and the owner's answers on both modes in a solo night and the fourth "Next map" button.

## Delete

- none
