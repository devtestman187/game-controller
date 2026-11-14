# b002-solo-skip review

## Summary

Verdict: **small fixes**. must 0 · should 2 · could 4.
1. The commit leaves three pinned tests asserting the one-player night's card, so `tools/check.sh host` is red
   at d4b8731 (`arena_night_test.dart:51`, `:89`, `arena_touch_ready_test.dart:110`). The uncommitted worktree
   already holds the fix.
2. `games_screen.dart:148` counts the host's own player with the inverse of the join screen's rule
   (`join_screen.dart:271`), and differently from the Arena's count (`game_screen.dart:106`).
3. Three of the six new tests (`night_round_test.dart:113`, `:174`, `:188`) pass on the old code: they guard
   behaviour the brief asked to keep, so they prove no new behaviour.
Checks I ran: `flutter test` on `solo_skip_test.dart` + `night_round_test.dart` + `night_reveal_test.dart`
25/25 pass; on the two failing files 14/14 pass **in the worktree only** (it carries an uncommitted extra
phone); `dart format --set-exit-if-changed` on the 7 changed Dart files 0 changed; `flutter analyze`
(party_host) no issues. No device was started.

## Findings

- **should** `packages/party_host/test/arena_night_test.dart:51` (also `:89` and `packages/party_host/test/arena_touch_ready_test.dart:110`) these three tests open a one-player night Bumper round and expect the waiting card the change removes, so the package's suite is red in the commit → add the two files to `allow:` and give each harness a second phone before the round opens, exactly the edit the uncommitted worktree now carries at `arena_night_test.dart:19`.
- **should** `packages/party_host/lib/src/ui/games_screen.dart:148` the own-player filter is written as `shareView ? null : ownPlayerIdProvider`, the inverse of `join_screen.dart:271`, and with today's providers `ownPlayerIdProvider` is null whenever `shareView` is false, so the condition never drops anyone while `game_screen.dart:106` counts the same list unfiltered; a host whose own player is set without a shared view (the way `arena_touch_ready_test.dart:24` sets it) gets zero players here and one there → count the players once, in a helper both screens call, and drop the filter.
- **could** `packages/party_host/lib/src/ui/solo_skip.dart:52` while `arenaMapLibraryProvider` loads the waiting stage draws nothing, so the screen is blank with no title and no Back until the round starts (one or more frames in the app) → keep the round's frame or a one-line "starting" placeholder up until `_start` runs.
- **could** `docs/briefs/m14/bugs6/b002-solo-skip-report.md:50` decision 4 says "the night's used-map set is therefore untouched", but `_start` marks the round's map used at `game_screen.dart:204` → say that the start adds only the round's own map, as the card's Start does.
- **could** `docs/briefs/m14/bugs6/b002-solo-skip-report.md:101` self-check 3 says "a player away lowers the count, so the card returns", but `_alone` is fixed when the Arena screen opens (`game_screen.dart:106`), so an away that starts while the maps load does not bring the card back → say the count is taken once, at the screen's open.
- **could** `packages/party_host/test/night_round_test.dart:113` (also `:174`, `:188`) the two-player join screen, the two-player card and the Arena outside a night pass on the old code; brief item 6 asked for them, so they are regression guards, but none of them fails without the change → keep them and rely on the other three and `solo_skip_test.dart` as the tests that fail on the old code.

## Decisions to confirm

- `SoloRoundStart` lives in `solo_skip.dart`, which brief item 1 called the pure helper: the file now imports Flutter and `arena_settings_provider`, so the rule is no longer in a pure file. Fine as disclosed; moving the widget to `game_screen.dart`'s part library would keep the helper pure.
- One `skipsLobby` serves both games, so `solo_skip.dart:16-18`'s "this is the one place to change" when the Arena gets more maps is not true alone: changing it would also drop Shape Race's join screen. A per-screen parameter is needed then.
- `_alone` is decided when the Arena screen opens, so a phone that joins during the map load waits a round. That is wider than brief item 4's "a phone that joins during a solo round".
- Trimming the doc comments at `game_screen.dart:80, 89, 92-94` leaves the file at 379 of the brief's 380 lines: the next change to it must split it.
- Finding 1's three tests: fix in this job's follow-up, or accept the red suite until the next one.

## Could not check

- That each new test fails on the old code: the parent commit cannot be checked out here, so this is the runner's evidence, not mine.
- The host suite's "422 passed, 3 failed" at d4b8731: my run of the two files used the working tree, which already holds the extra-phone edit at `arena_night_test.dart:19`.
- The phone-host and TV behaviour on a device, and the blank frame of finding 3's length: needs a device check.

## Commit message

Review b002-solo-skip: one rule holds, the suite is red on three pinned tests

Read the b002-solo-skip diff against its brief, the coding guidelines and
review-rules A and B. `skipsLobby` in `solo_skip.dart`, the Shape Race solo
pick, the Arena's card-less night start and the N6/§8 amendments match the
brief; the 25 tests in the three allowed files pass, format and analyze are
clean.
Two should findings: the commit leaves three pinned tests red, and the Shape
Race pick counts the host's own player with the inverse of the join screen's
rule.
Four coulds: a blank frame while the maps load, two wrong lines in the
report's decisions and self-check, and three new tests that are guards only.

## Status row

M14 bugs6 b002-solo-skip review (bugs6 b002-solo-skip-review) is done: verdict small fixes, no must, two shoulds (three pinned tests left red; the own-player count in `games_screen.dart:148`) and four coulds. Open: Claude's verification of both shoulds and the decision on where `SoloRoundStart` lives.

## Delete

- none
