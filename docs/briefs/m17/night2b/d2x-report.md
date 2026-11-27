# d2x report: a night's next round opens the game the pick chose

## Summary

A night's next round now opens the game its pick chose: Shape Race's puzzle at the pick's tier (solo or the join
screen, as the round always did), or the Bumper Round on the pick's map in bumper mode. Arena Race opens nothing.
The scoreboard's own buttons are unchanged.

Files changed:
- `packages/party_host/lib/src/night/night_variant.dart`: `NightVariant` removed; `nightNextVariantProvider` is now
  `Provider<NightPick?>` and watches `nightPickProvider`.
- `packages/party_host/lib/src/ui/games_screen.dart`: `ShapeRaceScreen._play` moved out of the class as the public
  `openShapeRacePuzzle(context, ref, choice)`, same body; the level card calls it.
- `packages/party_host/lib/src/ui/night_pick_open.dart` (new): `openNightPick(context, ref, pick)`; shape race calls
  `openShapeRacePuzzle` with `PuzzleChoice(level: tier)`; bumper round sets mode bumper and the pick's map, then pushes
  `GameScreen`; arena race returns null.
- `packages/party_host/lib/src/ui/night_scoreboard_screen.dart`: `startRound` calls `pickFor(round)`, reads the pick,
  returns false when there is no pick for this round, the screen is unmounted or a dialog is on top, else
  `openNightPick(...) != null`. The old switch is gone; `_open` stays because `_startRound` (the buttons) uses it.
- `packages/party_host/test/night_round_hook_test.dart`: both overrides are now a `NightPick` for round 2
  (bumper round, pinball, easy).
- `packages/party_host/test/night_pick_open_test.dart` (new): six tests, each run under the menu and the TV look.
- `docs/briefs/m17/night2b/d2x-report.md` (new): this report.

Test counts: `tools/mine.sh` → format OK (6 files), analyze OK (party_host), 12 tests OK (the touched tests, as the script counts them).
Expected values computed in the new tests: round 2 pick comes from the seeded `Random(1)`; the pick's map is compared
with `arenaSettingsProvider.mapId` (the test compares the two, it does not hard-code a map).

## Self-check (review-rules part A)

1. Host setups: TV and phone look both run in every test (`forEachLook`); joined-phone case is the two- and one-player
   tests; "Play on this phone" / "Show on this device" / peer-one-build-older are not touched by this job.
2. Kept state: the played list gets one id per started round (test "keeps its one variant"); nothing new ends.
3. Combinations: a dialog on top (existing hook test 5), the host picker (new test), Arena Race pick (new test). Pause
   menu, host away, "Get ready", dropped link, results and leaving: not changed by this job.
4. Stayed inside `allow:`.
5. Stop: none needed.
6. Every look: menu (960x540 default) and TV (1920x1080 for the join test) via `forEachLook`.

## Decisions

- The settings in the new test are set with `nightSettingsProvider.notifier.update(...)` after mounting, not with a
  `nightSettingsProvider` override (the notifier is a plain setter there; the existing pick tests do the same).
- The two-player join test is mounted at 1920x1080 (see Questions 1).
- `startRound` calls `pickFor(round)` before the mounted/dialog checks, as the brief's order says. Idempotent for the
  same round, so a dialog case does not re-pick.
- `openNightPick` returns `Future<void>?`; the bumper round returns the push future, so it is non-null when opened.
- `openShapeRacePuzzle` is a `Future<void>` returning the push future; the level card ignores it, as before.

## Questions

1. At the default 960x540 size, the join screen's player card overflows by 9 px (`toy_card.dart:129`, a Column in a
   135 px slot) when two phones join; this is existing layout, not changed here. The two-player test runs at 1920x1080
   to avoid it. Should someone own that overflow (a job for the join screen), and should a test pin it?
2. `pickFor` records the pick (and saves the played list) before the mounted and dialog checks, so a round whose game
   never opens (a dialog on top) still counts as played. Is that the intent, or should the pick be recorded only when
   something opens?
3. `startRound(int round, bool lastRound)`: `lastRound` is unused (it was unused before this job too).

## Line counts

- `packages/party_host/lib/src/ui/game_screen.dart`: 366 lines, untouched (limit 380).
- `games_screen.dart` 165, `night_scoreboard_screen.dart` 179, `night_pick_open.dart` 28, `night_variant.dart` 8.

## Hand-over

- Nothing deleted. Changes are in the seven files above; `docs/briefs/m17/night2b/run.log` was already modified before
  this job and is not mine.
- Not run: `tools/check.sh` (the script runs it after this job). One diagnostic `flutter test` run was used to read the
  join-screen overflow exception; it is not a check.

## Commit message — a draft

party_host: a night's next round opens the game its pick chose

A night's next round now opens the game its pick chose, at the pick's tier or map, instead of waiting for a
game button. Shape Race opens the puzzle of the pick's tier (join screen or solo, as before); the Bumper Round
sets the Arena to the pick's map in bumper mode and opens; Arena Race opens nothing, as the night never plays it.
The scoreboard's buttons are unchanged. NightVariant is removed; nightNextVariantProvider is the pick.

## Status row

d2x done: a night's next round opens the picked game (Shape Race puzzle at tier, Bumper Round on the pick's map); open: the setup screen, start-card change, caption (d2h), skip/reroll, and the join screen's 9 px overflow at 960x540.

## Delete

- none
