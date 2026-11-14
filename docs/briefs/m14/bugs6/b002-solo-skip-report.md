# b002-solo-skip — a one-player night round skips the join screen and the waiting card

Job: M14 bugs6 b002-solo-skip (owner B-002). Read for it: the brief, [party-night.md](../../../design/party-night.md) (§2 N6,
§7b, §8), [coding-guidelines.md](../../../coding-guidelines.md), [project-notes.md](../../../project-notes.md), and
[review-rules.md](../../../review-rules.md) part A.

## Summary

- One rule, in one place: `skipsLobby({required bool inNight, required int players})` in the new
  `packages/party_host/lib/src/ui/solo_skip.dart`, true only for a night with exactly one player. Shape Race and the Arena
  both call it; nothing restates the rule.
- Shape Race (`games_screen.dart` `_play`): that player's puzzle pick pushes `PuzzleScreen(choice, teams: {id:
  PuzzleSide.left})` — a solo board — instead of `JoinScreen`. Two or more players get the join screen as today, so teams
  can change; a phone joining mid-round waits for the next round, whose pick counts it and shows the join screen again.
- Bumper Round (`game_screen.dart`): a night with one player starts at once, as the card's Start would on Surprise me (a map
  the night hasn't used) with the saved Robo level; the card is not built. Two or more players get the card, and outside a
  night it always shows — `solo_skip.dart` says that is the one place to change when the Arena gets more maps.
- Numbers: `solo_skip_test.dart` 4 tests and `night_round_test.dart` 20 tests pass (6 of them new); `tools/check.sh format
  analyze host` gives format PASS and analyze PASS, host **422 passed, 3 failed** — the three in `arena_night_test.dart` and
  `arena_touch_ready_test.dart`, which the brief's `allow:` leaves out (see Open).
- Sizes: `game_screen.dart` 379 lines (cap 380), `solo_skip.dart` 54, `games_screen.dart` 159, `night_start_screen.dart`
  250; no function over 60 lines.
- Design: party-night §2 N6 now reads "…its puzzle pick; with two or more players joined, its join screen (teams may change
  there)", with the Bumper sentence the same way; §8 gained a bullet for a night's one player starting at once, and says the
  Arena outside a night always shows the card.
- On a device: start a night alone — Shape Race (tap a puzzle, the round opens, no join screen) and Bumper (no card, the
  field at once, then Next). Then pair a second phone during a solo round: it waits, and the next pick shows the join screen.
- Open: three Arena night tests assert today's waiting card for a one-player night; fixing them is outside `allow:`.

## Files changed

- `packages/party_host/lib/src/ui/solo_skip.dart` (new, 54 lines): `skipsLobby`, and `SoloRoundStart`, the card-less start.
- `packages/party_host/lib/src/ui/games_screen.dart` (159): `_play` takes the pick's roster and picks the screen.
- `packages/party_host/lib/src/ui/game_screen.dart` (379): `_alone`, and the waiting stage's card-less branch.
- `packages/party_host/lib/src/ui/night_start_screen.dart` (250): comments only, following the design amendment.
- `packages/party_host/test/night_round_test.dart`: harness without the two A presses, six new tests.
- `packages/party_host/test/night_reveal_test.dart`: the two A presses dropped (one player starts the round itself).
- `packages/party_host/test/solo_skip_test.dart` (new): the truth table.
- `docs/design/party-night.md`: §2 N6 and §8 amended.

## Decisions

- The Arena's card-less start lives in `solo_skip.dart` (`SoloRoundStart`), not in `game_screen.dart`: that file may not pass
  380 lines, and the start needs to wait for a build. The widget draws nothing and calls back.
- Start from a post-frame callback, never during the build: `_start` calls `setState`, which throws inside a build.
- Wait for `arenaMapLibraryProvider` before starting: Surprise me needs the library to pick a map the night hasn't used, and
  starting earlier would fall back to the playroom, which §7b forbids. A failed load starts anyway on the playroom, exactly as
  the card's Start does.
- Call `_start(null)`, so the round is the card's Surprise-me press and nothing else: the night's unused map, the saved Robo
  level from `arenaSettingsProvider`. The night's used-map set is therefore untouched.
- Decide the roster once, when the Arena screen opens (`late final _alone`): a phone joining while the maps load joins the
  next round, as one joining during the round already does — the brief's late-join rule, without new state.
- Count Shape Race's players at each pick with the join screen's own filter (not away; `ownPlayerIdProvider` only when the phone
  host doesn't share its view), so a phone host on "Show on this device" never starts a solo round for its viewer.
- Night round 1 is covered by the same code: the Arena screen decides, not the start card's button, so
  `night_start_screen.dart` only needed its comments to match the design.
- Trimmed two doc comments in `game_screen.dart` (`_log`, `_againFocus`) to one line each to stay at 379 lines.

## Open — the allow list leaves three tests asserting the old card

`tools/check.sh host` fails on:

- `packages/party_host/test/arena_night_test.dart:47` "the night's Bumper Round opens on the Arena's card, Bumper alone, and
  starts the night"
- `packages/party_host/test/arena_night_test.dart:85` "a night's Bumper Round notes its map on the night, and the card's pick
  is the round's"
- `packages/party_host/test/arena_touch_ready_test.dart:108` "a night's Bumper Round gives the phone host the same Ready
  button"

Each opens a one-player night Bumper round and expects the card — the behaviour B-002 removes. The fix is one line each: add a
second phone before the round opens (`fake.state = withController(fake.state, phoneInfo('p2', 2)); fake.emit();`), which also
restores the card, map pick and Ready button each test is about. I did not edit them: they are outside `allow:`.

## What the tests show, with numbers

- `skipsLobby`: `(inNight: true, players: 1)` → true; `(true, 2)` → false; `(true, 0)` → false; `(false, 1)` → false
  (`solo_skip_test.dart`, 4 tests).
- One-player Shape Race pick: `JoinScreen` finds nothing, one `PuzzleScreen`, teams `{'p1': PuzzleSide.left}`,
  `MatchFormat.solo`, `settings().night == true`.
- Two players: `JoinScreen` one, `PuzzleScreen` none; after the ready presses teams `{'p1': left, 'p2': right}`,
  `MatchFormat.oneVsOne`.
- Late join: the running round's teams stay `{'p1': left}`; the next pick shows `JoinScreen`.
- One-player Bumper round: `arenaWaitingCard` finds nothing, `arenaSnapshot(tester).mode == ArenaMode.bumper`, `roundTags ==
  ['night_1of3']`.
- Two-player Bumper round: card one, the `arena` field none. Outside a night with one player: card one, field none.
- On the old code each new test fails: the Shape Race pick finds `JoinScreen`, the Bumper round finds the card, the late-join
  round opens on a join screen, and `solo_skip_test.dart` cannot compile against the file it does not have.

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** A TV or PC host with one joined phone skips both screens ("a one-player night round skips the join
   screen and starts solo", "a one-player night Bumper round skips the waiting card and starts at once"); a joined phone
   pressing A mid-solo-round waits for the next round ("a phone joining a solo night round waits for the next round…"); a
   phone host on "Show on this device" pairs no player, so `ownPlayerIdProvider` is null and nothing changes for its viewer
   (no test: it is the join screen's own filter); "Play on this phone" adds its player, so one joined phone makes two and the
   join screen stays (no test); an older build's phone joins, readies and plays as before (no protocol change).
2. **When kept state starts and ends.** The only new held value is `_alone`, decided when the Arena screen opens and gone
   with it; the deferred start checks `mounted`, so leaving before the maps load starts nothing. While the maps load,
   `SoloRoundStart` draws an empty box; if the load fails, the round starts on the playroom. No timer, nothing counted; with
   no night or two players the card is there as today ("…with two players still gets the waiting card", "outside a night…").
3. **How it combines with the other states.** A player away lowers the count, so the card returns (the roster is
   `gamePlayersProvider`'s, not tested separately); the pause menu, Get ready and the results all belong to the round after it
   has started and are untouched; the host away changes nothing, because the start is not a ready gate. Pairs that can happen
   together: away + one player (card back), a second phone joining while the maps load (next round), leaving during the load
   (no start). Tested by the three Shape Race tests and the three Arena ones above.
4. **Stay in the job's folder.** Only `allow:` paths were written — four lib files, three test files, `party-night.md`, this
   report; no scratch file is left behind.
5. **Stop rather than overstep.** The three tests under Open are outside `allow:`; I left them unchanged and listed the exact
   edits instead, which is why `tools/check.sh … host` is red.

## Questions and suggestions

1. The three tests under Open: add those two test files to this job's `allow:` (or fix them in a follow-up), so `host` can go
   green? They are the only failure.
2. Suggestion, not acted on: N6's neighbour bullet could note that a solo round starts at the pick; the brief asked for N6 and
   §8 only, so I left it.

## Commit message

M14 bugs6: a solo night round skips the join screen and waiting card

B-002: a party night with one player starts Shape Race on a solo board
straight from the puzzle pick, and starts the Bumper Round at once on
Surprise me with the saved Robo level, with no join screen and no waiting
card. One rule (skipsLobby, solo_skip.dart) decides both; two or more
players keep both screens, a phone joining mid-round waits for the next
one, and the Arena outside a night always shows its card. Design:
party-night N6 and §8 amended. Tests: the truth table, solo and
two-player picks, a late join, and the Arena's field and card.

## Status row

M14 bugs6 b002-solo-skip: done in the lib and in the allowed tests — one rule in `solo_skip.dart`, Shape Race's solo pick, the
Arena's card-less night start, design N6/§8, 24 tests in the two allowed test files passing; open: three tests in
`arena_night_test.dart` and `arena_touch_ready_test.dart` (outside `allow:`) still assert the old waiting card for a one-player
night, so `tools/check.sh format analyze host` is format PASS, analyze PASS, host 422 passed and 3 failed.

## Delete

- none
