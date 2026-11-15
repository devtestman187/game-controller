# M14 bugs6 — the run read as one change

## Summary

Verdict: **one fix batch**. 3 must · 14 should · 12 could. No STATUS.md exists for this milestone, so no row was checked against it.
1. A test was loosened to pass: `controller_app/test/mirror_pad_test.dart:264` now skips its assertion when the D-pad leaves no mirror, so the car's lost opponent mirror (on an iPhone-sized phone) passes silently; no job's report lists that file or the car.
2. The six redone Medium renders were never committed: `docs/design/puzzles/{boat,car,robot,train,castle,butterfly}.png` are unchanged, though b012b-2's report says the render test wrote them.
3. The six Hard puzzles run in none of the shared-id tests: `packages/puzzle_game/test/support/match_helpers.dart:12` still lists twelve ids, and the design contact sheet (`puzzles_png_test.dart:43`) still draws 12 of 18.
4. The cat loses about half its planned visits when one side leads (`cat_chaos.dart:208`), so the owner's 8-minute round sees ~8 of 16; the PRD (169, 762) and party-night (68) still say once/twice a round.
5. The run's two biggest screens are at their stop: `puzzle_screen.dart` 380/380 and `game_screen.dart` 379/380, and `_Results` takes nine parameters against the five limit.
Owner-only: the cat's skipped-visit rule, clearing the old Medium best times, the Block Castle timing finish, and Back's destination from the results card.

## Findings

- **must** `controller_app/test/mirror_pad_test.dart:264` the D-pad case now asserts only when `mirrorOf` is not null, so any picture that loses its mirror passes, and the Medium car has already lost it (code-health.md:106), which no job's report lists → assert the absent case by name (or fix the layout) and report the change; mark it "Fixed, unverified: needs device check" (from: across jobs, b012b-2's follow-up).
- **must** `docs/design/puzzles/boat.png` (also car, robot, train, castle, butterfly) the six redone Medium renders were never committed, so the design folder still shows 6–7-piece pictures while `b012b-2-medium-report.md:115` says `test/puzzle_render_test.dart` wrote them, against brief item 2 and `docs/levels.md:44` → run the puzzle suite and commit the six renders it writes (from: b012b-2 review).
- **must** `packages/puzzle_game/test/support/match_helpers.dart:12` `puzzleIds` still holds the twelve Easy and Medium ids (its doc says "six Easy, then six Medium"), so the six Hard puzzles run in none of the eleven sites that use it, against the brief's "any test that lists puzzle ids" → add the six ids, the Hard bag in `puzzle_pick_test.dart:44`, the split-layout overlap pins and the sheet grid (`puzzles_png_test.dart:43`) in one change (from: b012b-3 review).
- **should** `packages/puzzle_game/lib/src/puzzle_rule_levels.dart:199` `_turned` still returns early for Hard, though b012b-1's Decision 3 and its Files-changed line say the skip is gone and Hard's own rule already needs six turned → delete the line (from: b012b-1 review).
- **should** `docs/PRD-v2.md:169` (and the acceptance bullet at `:762`) still says the cat comes at most once/twice a round, and `docs/design/party-night.md:68` still says "The PRD's rules stand as written" while `:72` counts by round length and preset → paste the text under b006's Blocked and reword line 68 (from: b006).
- **should** `docs/design/party-night.md:72` promises "one visit at least in a round", but the window is limit − 30 s and a 30 s round (the minimum, `settings.dart:86`) plans none → say "one visit where the window fits one" (from: b006 review).
- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:208` `_next++` runs before `_leader()`, which returns null for the side just visited, so a one-sided lead throws the visit away (~8 of 16 at 480 s) → visit the other side when the leader is `_lastSide` (from: b006).
- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:186` `room = share − visitS` reserves the visit but no quiet, so two visits can start 4.8 s apart while `cat_tuning.dart:13` claims `visitS + minQuietS` → subtract `minQuietS` too (from: b006 review).
- **should** `packages/puzzle_game/lib/src/cat_chaos.dart:261` `_mayKnock` no longer reads `settings.chaos == Chaos.party`, so a mid-round change from Party to A little still lets a placed piece be knocked, and no test covers it → restore the live check (from: b006 review).
- **should** `packages/party_host/lib/src/puzzle_bag.dart:147` `fromJson` restores only the waiting ids, so after a restart a refill can open with the puzzle just finished and an id a build adds waits a cycle, both against brief item 1 → save the last-played (or the cycle's) ids beside the waiting ones (from: b009 review).
- **should** `docs/briefs/m14/bugs6/b012b-2-medium-report.md:13` says old Medium best times no longer compare, but nothing clears them (`best_times.dart:110` keeps them by board), so every redone Medium board shows a record that cannot be beaten → clear the six Medium boards once, or say in the report why not (from: across jobs, b012b-2/3).
- **should** `packages/test_game/lib/src/arena_coin.dart:48` `ArenaCoin.dropper`'s doc still says a dropped coin is "takable at once, by anyone but its dropper", the rule B-005 removed → reword it to "out of its dropper's reach for `dropLockS`, then anyone's" (from: b005 review).
- **should** `packages/party_host/lib/src/ui/puzzle_pick.dart:170` (and `:190`) every series Next and Continue passes a `puzzleId`, so `_picked` (`:33`) records it in the shared `any` bag, against b011b's decision at `b011b-continue-report.md:67` → record the id only for a pick made on the picker (from: b011b review).
- **should** `docs/code-health.md:106` records the car's missing mirror under "## Done" although it is open and needs a device look, with no area, risk or recommendation, and the change it describes is in no job's report → move it to "When touched" under puzzle_game (mirror) with risk and rec. (from: across jobs).
- **should** `packages/puzzle_game/test/hard_library_test.dart:13` repeats the rules `puzzle_check_test.dart:11` already runs on every file (`checkLibrary` → `checkPuzzle`) and the count and order `library_test.dart:24` pins → keep one count-and-order test and drop the rule copies (from: b012b-3 review).
- **should** `docs/briefs/m14/bugs6/b015-routes-report.md:60` says the top and bottom keep gates "travel 24.0"; the movers in `packages/test_game/maps/block-castle.json:39-40` move 0.075 × 160 = 12.0 units → write "travel 12.0" (from: b015 review).
- **should** `controller_app/test/tablet_board_test.dart:85` pins the small iPad boat at 8.930715 with world left 238.081, while `packages/puzzle_game/test/tablet_board_test.dart:90` pins 8.930159 and 238.103 for the same board and box, so one harness measures a different board and neither is explained → find the difference before either is re-pinned (from: across jobs).
- **could** `packages/puzzle_game/lib/src/puzzle_rule_levels.dart:136` Medium's big-piece message now reads `Mark 1 or 2 pieces "big".` where it read "Mark one or two", an unmentioned change to a level the brief keeps → carry the phrase in `_PieceCounts` or restore the words (from: b012b-1 review).
- **could** `packages/puzzle_game/lib/src/puzzle_rule_levels.dart:17` (and `:25`) say a pair shares "a shape", while `_repeatedShapes` groups on `shape.key` (shape and size) as its own message at `:191` says → write "a shape and size" (from: b012b-1 review).
- **could** `packages/party_host/lib/src/ui/puzzle_continue.dart:141` the Shuffle switch disappears at the level-done prompt (`puzzle_pick.dart:104` passes `shuffle: null`) but no test asserts it → add `expect(find.byKey(const Key('shuffle')), findsNothing)` to the Continue test (from: b011b review).
- **could** `packages/party_host/lib/src/ui/puzzle_results_widgets.dart:9` `_Results` takes nine parameters against guidelines §3's five → fold the card's menu options into one value object with the other inputs (from: b011b review).
- **could** `packages/party_host/lib/src/puzzle_settings_provider.dart:58` `reset()` sets `hostPuzzleDefaults` without `withCatPresetDefine`, so Reset drops a device test's `CAT_PRESET` → wrap the reset value too, or say in the doc that Reset clears the define (from: b006 review).
- **could** `packages/party_host/lib/src/ui/puzzle_pick.dart:47` a night's chosen round still creates a series (its one Next can never advance it), and `_changeTeams` (`:227`) restarts the series on the same pick, losing the played ids, a choice `b011b-continue-report.md:44` calls "leaves it behind" → gate `_startedSeries` on no night and list the team-change choice (from: b011b review).
- **could** `packages/party_host/lib/src/puzzle_bag.dart:57` says a shuffle that puts `avoidId` first "moves it behind one other id", but `:90-92` remove it and append it, i.e. move it to the end of the bag → say "to the end of the bag" (from: b009 review).
- **could** `packages/party_host/lib/src/ui/solo_skip.dart:52` while `arenaMapLibraryProvider` loads, the waiting stage draws an empty box, so the screen has no title and no Back for those frames → keep the round's frame or a one-line "starting" placeholder (from: b002 review).
- **could** `packages/party_host/test/games_screen_levels_test.dart:31` `expect(hard.label, isNotEmpty)` passes for any non-empty label, so the Hard card's text is unchecked → assert the label the picker's text gives (from: b012b-3 review).
- **could** `packages/party_host/test/controller_menus_test.dart:143` the bare `24` is a magic press count (22 buttons today), against guidelines §2 → name it with its reason, or count the pressable buttons from the tree (from: b012b-3 review).
- **could** `packages/puzzle_game/lib/src/puzzle_carry.dart:92` `_isPlacing` scans every piece (with `_fitAngle` and an `Iterable.generate`) for every carrier every step, so per-frame work grows with the piece count; mark it "Fixed, unverified: needs device check" as the 60 fps budget is not measured → reuse one buffer and skip filled pieces early (from: b012a, no review was written).
- **could** `packages/party_host/lib/src/ui/game_screen.dart:379` ends at 379 lines and `puzzle_screen.dart:380` at 380 the run's two largest screens are both at the brief's 380 stop after this run (B-002 trimmed comments to fit, B-011b added to the cap) → split each along its waiting/pick seam as the next change to either (from: across jobs).

## Open questions

1. The cat's skipped visit: requeue it, or visit the other side? Safest: visit the other side, so 16 stays 16.
2. Are the Calm/Lively/Wild intervals (43/28/21 s) the keepers? Safest: keep them until a device play says otherwise.
3. Should Calm be rarer on A little (all three presets are 85 s)? Safest: leave as the brief said.
4. Should `CatTuning` be exported from `puzzle_game` so its test stops importing `src/`? Safest: yes, one export line.
5. Paste b006's Blocked text into PRD G3 and line 762? Safest: yes, as written there.
6. Should the saved bag keep the last-played and cycle ids (a second key)? Safest: yes, it closes both restart cases.
7. What should a round say when the puzzle files fail to load? Safest: keep the spinner and the log line.
8. Should Shuffle reset the level's bag? Safest: no — it only changes the series' order.
9. Where should the results card's Back go: the games picker (today) or the puzzle list? Safest: the picker, as built.
10. Should the series survive Change teams? Safest: no — restart it, and write that down.
11. Clear the saved Medium best times once, or let mixed comparisons stand? Safest: clear the six Medium boards once.
12. In a night, should a chosen round start a series at all? Safest: no.
13. Does `moveS` including time before a rejoin matter? Safest: accept it; the side's clock is the round.
14. Is the recorder's `player_result` path accepted untested (party_host outside every allow list)? Safest: one party_host test before the next metrics change.
15. Block Castle's goal behind the keep's timing gate: keep, or move to the courtyard? Safest: keep for the owner's device play.
16. Toy Factory's open floor: sprint or shaped? Safest: leave it open.
17. Race starts 0.14 apart against the Bumper Round's 3-marble rule: rule-book check or a written exception? Safest: a written exception now, a check when a second race lands.
18. Do the tractor and dragon read as their subjects? Safest: the owner's eye before the next build.

## Numbers against targets

- The cat at 480 s on Lively plans 16 visits and 10 knocks (b006 report), but `cat_chaos.dart:208` drops every second one when a side leads → ~8 visits, half the brief's promise.
- "One visit at least in a round" (`party-night.md:72`) is 0 for a 30 s round; the time limit's minimum is 30 (`settings.dart:86`).
- The six Medium renders: 0 of 6 updated, against brief item 2.
- The shared id list covers 12 of 18 puzzles; the design sheet draws 12 of 18.
- The take-back is proved at 2.117 s, not 2.0 s, so the `ageS == dropLockS` boundary is untested (b005 review).
- The small iPad boat: committed 8.930715 (`controller_app`) vs 8.930159 (`puzzle_game`) for one box; b012b-2's report quotes 8.930159.
- Frame budget: the 8-piece boat frame is 678 bytes against 2 KB (b012b-2) — fine.
- Hard's six puzzles: smallest pieces 8.76–11.07 mm against the 8.5 mm floor, split 0.87–1.07 against 0.85 (b012b-3) — fine.
- Sizes: `game_screen.dart` 379/380, `puzzle_screen.dart` 380/380 (brief stop); `_Results` 9 parameters against 5.

## Could not check

- The full suites, `dart format` and `dart analyze`: I ran only `hard_library_test` + `library_test` (6 pass), `arena_night_test` + `arena_touch_ready_test` (14 pass) and `mirror_pad_test` (9 pass).
- Whether the car's mirror is really absent on a device: the code-health note says so; no measurement here.
- The b015 play figures (1.82 s, 2.23 s, arrows 97.5/139.4): no saved transcript.
- Which of the two tablet harnesses measures the boat differently: not investigated.
- The pictures themselves: I opened no PNG, so the six Hard subjects are unchecked by eye.
- Every report's "fails on the old code" claim: the old tree is not available here.

## Commit message

Review M14 bugs6 as one change: three musts, one fix batch

Read the run from 8e17f32 to f45a885 as one change against the guidelines and
review-rules A–C. Three musts: a mirror test loosened so a lost mirror passes,
the six Medium design renders never committed, and the six Hard puzzles missing
from the shared test ids and the design sheet. Shoulds: the cat loses half its
visits on a one-sided lead and reserves no quiet, the PRD and party-night still
say once/twice a round, the bag forgets played ids across a restart, old Medium
best times cannot be beaten, and the coin doc is stale. Coulds: nine parameters
on `_Results`, an untested hidden Shuffle, a Reset that drops the define, and
two screens at their 380-line stop.

## Status row

M14 bugs6 run reviewed (3 must, 14 should, 12 could): the b002, b011b, b012a and b012b code is green in the tests re-run here; open — the loosened mirror test and the car's lost mirror, the six Medium renders, the Hard ids in the shared test list and sheet, the cat's skipped visits and quiet, the stale PRD/party-night cat text, the bag's restart gap, and clearing the old Medium best times.

## Delete

- none
