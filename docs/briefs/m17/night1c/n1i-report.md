# n1i report: round-start hook

## Summary

Stopped at one blocked step: `puzzle_pick.dart` (step 4, puzzle's Next) is not changed. Every other step is done.

Blocked: `puzzle_pick.dart` is `part of 'puzzle_screen.dart'`. A part file cannot add an import, and the provider
`nightFlowControllerProvider` is only reachable through an import in `puzzle_screen.dart`, which is not in `allow:`.
I did not edit `puzzle_screen.dart`. Until this is resolved, a puzzle round does not advance the controller; with no
variant chosen nothing else changes, so the app behaves as before.

Changes:
- `lib/src/night/night_variant.dart` (new): `enum NightVariant { shapeRace, bumperRound }` and
  `nightNextVariantProvider`, a `Provider<NightVariant?>` that returns null.
- `lib/src/ui/night_scoreboard_screen.dart`: the state implements `NightRoundHooks`. `initState` hooks the controller
  (kept in `_controller`), `dispose` clears the hook only when it is still this one. `startRound` returns false when no
  variant is chosen or the screen is unmounted; otherwise it pushes `ShapeRaceScreen` or `GameScreen` with `_open` and
  returns true. `replaceRound` is empty. The two footer picks call `startNow()` before opening their screen. The
  scoreboard shows nothing new.
- `lib/src/ui/night_start_screen.dart`: `_startNight` calls `startNow()` after `night.start` and before the first
  screen opens.
- `lib/src/ui/game_screen.dart`: `_next` calls `roundEnded()` then `next()` before `recordRound`. `_endNight` is
  unchanged. Added the provider import.
- `test/night_round_hook_test.dart` (new): four tests.

Test values (all four fail on the code as it was, then pass):
- (a) scoreboard after round 1 (controller at `scoreboard`, round 1); the scoreboard's Shape Race pick opens
  `ShapeRaceScreen`, and the flow goes to `round`, round 2.
- (b) variant `bumperRound`, pacing `setup` 1 ms, `howTo` 5 s (`NightPacing.minHowTo`), `results` 1 ms,
  `scoreboard` 1 ms (gap 5.001 s, under the 15 s cap); pump 10 s (`maxHowTo`) then 500 ms: `GameScreen` opens, the
  flow is at `round`, round 2.
- (c) variant null, same pacing: after 10 s the scoreboard stays on top, neither game opens, the flow waits at
  `howTo`, round 2.
- (d) pop the scoreboard: `controller.hooks` is null afterwards.

Checks:
- `tools/mine.sh`: OK, 5 tests run and passing (format, analyze of the package, the touched test).
- `flutter test` on the six existing night test files (`night_scoreboard_card_test`, `arena_night_test`,
  `end_night_arena_test`, `end_night_puzzle_test`, `night_start_frame_test`, `night_flow_provider_test`): all 72 pass.
- `dart analyze` on the five changed Dart files: no issues.
- `tools/check.sh host` was not run, as the brief says the script runs it.

Self-check (review-rules part A):
1. Host setups: TV host only in the new test (pumpHost default); phone hosts and the peer build not covered. Not verified.
2. Kept state: the hook is set in initState and cleared in dispose: test (d). Nothing set when no night runs (controller null).
3. Combination with pause menu, host away, player away, Get ready, dropped link, results, leaving: not covered by new tests.
4. Files inside `allow:`: yes; `puzzle_pick.dart` not changed (see Summary).
5. Stop: `puzzle_pick.dart`, named above, with the reason.
6. Looks: no new look and no fixed pixel height; the scoreboard renders the same.

Decisions:
- The hooks are implemented on the scoreboard state itself, not a separate class; the brief allowed either.
- The controller is stored in a field so `dispose` does not call `ref`.
- `startRound`'s `round` and `lastRound` are unused, because the interface defines them.
- The new test mounts the scoreboard on top of `StubHome`, because the scoreboard reads the controller in `initState`
  and the night must exist before it mounts.
- "Short pacing" in milliseconds cannot apply to the how-to card: `NightPacing` asserts a 5 s minimum there. Every other
  card is 1 ms.

## Commit message — a draft

night: the controller starts the next round from the night's screens

The start card and the scoreboard start the round in the night flow controller when the host picks a game, and game
screens report their round end to it. The scoreboard also takes the controller's round hook: with a variant chosen
(nightNextVariantProvider, null for now) it opens that game by itself after the how-to card. Puzzle's Next is not
hooked yet: puzzle_pick.dart needs an import in puzzle_screen.dart, which is outside this job.

## Status row

n1i: round-start hook done (variant provider, scoreboard hook, start card, game Next); open: puzzle's Next
(puzzle_pick.dart, needs an import in puzzle_screen.dart) and any director to set the variant.

## Delete

- none

## Hand-over

Questions:
1. Add `packages/party_host/lib/src/ui/puzzle_screen.dart` to `allow:`, so the import of `night_flow_provider.dart` can
   go in it? Then the step-4 lines go into `puzzle_pick.dart`'s `_next` exactly as the brief says.
2. `game_screen.dart` is 366 lines, close to the 380 limit. The next batch that touches it should split it first.
