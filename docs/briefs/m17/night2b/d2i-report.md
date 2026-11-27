# d2i report: pool honesty in the night setup

## Summary

- New `NightSetupOptions` (pure Dart, static members) in `packages/party_host/lib/src/night/night_setup_options.dart`, 96 lines.
  - `offeredGames`: `nightPlayableGames` in enum order, so shapeRace and bumperRound. Arena Race is never offered.
  - `offeredPickers`: host, director, shuffle, playlist. Rotating and Vote are not offered.
  - `offeredLengths`: `NightLength.values`, which is three and five rounds only.
  - `gamesOn(settings)`: an empty pool means every offered game; a pool entry that is a game name or a `game:…` variant id turns that game on.
  - `togglePoolGame(settings, game, mapTierLevel)`: flips one game; refused (settings returned unchanged) when the result is empty or plays no variant; stores an empty pool when every offered game is on.
  - `withDifficulty(settings, mapTierLevel, {min, max})`: the other end moves so min never exceeds max; refused when no playable variant remains.
- New tests in `packages/party_host/test/night_setup_options_test.dart`, 95 lines, 9 tests in 3 groups.
- `mine.sh` result: format OK (7 files formatted), analyze OK for `packages/party_host` after two fixes (unused import, directive order), tests OK: 112 tests in `packages/party_host`.

## Decisions

- Toggling a game off removes only that game's entries from the pool and keeps other entries, so a variant-level pool such as `{'bumperRound:pinball'}` keeps its Pinball-only setting when Shape Race is toggled.
- Toggling a game on adds its game name to the pool.
- `withDifficulty` with both `min` and `max`: `max` is applied first and `min` last, so when both are given with min above max, min wins and max moves up.
- `withDifficulty` does not look at `isKids`; the Kids preset is only the existing constant. An edited Kids night is not capped here (tested).
- The playable check uses `launchVariants` filtered to `nightPlayableGames`, so a pool of only `arenaRace` is refused.

## Self-check (review-rules part A)

1. Host setups: this is pure Dart with no host UI; the setup's use of these options is out of scope for d2i. Covered by the pure-function tests only.
2. Kept state: none; these are pure functions over `NightSettings`.
3. Combination with the other states: not applicable to this pure layer; the director, pickers and settings fields are unchanged.
4. Files: only the two named new files plus this report.
5. No stop needed.
6. Looks: no UI in this job.

## Tests

- tests-first: exempt, new type (the test cannot compile on the base).
- Computed values used in expectations:
  - Default settings with `_ratedPinballEasy` (Pinball easy, other maps medium): playable ids are non-empty.
  - Kids with the same rating: `['shapeRace:easy', 'bumperRound:pinball']`.
  - Shape Race toggled off from defaults: pool `{'bumperRound'}`, playable `bumperRound:pinball`, `bumperRound:block-castle`, `bumperRound:toy-factory`, `bumperRound:spinning-tops`.
  - Last game toggled off from pool `{'shapeRace'}`: refused, `same(settings)`.
  - Pool `{'bumperRound'}` with Shape Race toggled on: pool empty, both games on.
  - Min medium with max set to easy: min and max both easy.
  - Max easy with min set to hard: min and max both hard.
  - Pool `{'bumperRound'}` with every map rated hard, max set to easy: refused, `same(settings)`.
  - Kids copy with `chaos: Chaos.off` (isKids false), max set to hard: max is hard.
- The "fails on base" proof is not run here because the new type cannot compile on the base; the runner's check covers it.

## Questions

1. Should `withDifficulty` refuse a range that leaves only a variant the director will never play? The brief asked for playable-only, and I did that.
2. Should a pool that names only non-offered games (for example, `arenaRace` written by an older save) be cleaned on load? Not done here; the toggle refuses it.

## Hand-over

Files changed: the two new files above and this report. Nothing else touched. Analyze was run through `tools/mine.sh` for `packages/party_host` and reports no findings.

## Commit message — a draft

Setup: offer only what a night can play (d2i)

Add NightSetupOptions: offered games (Shape Race, Bumper Round), pickers
(host, director, shuffle, playlist) and lengths (three and five rounds).
Pool toggles and difficulty edits are refused when they would leave no
playable variant; min and max move together so min never exceeds max.
Pure Dart; the director, pickers and settings fields are unchanged.

## Status row

d2i pool honesty: setup options (games, pickers, lengths) and pool/difficulty edits are pure and tested; Arena Race, Rotating, Vote and the 8-round option are not offered. Open: the setup UI wiring and the owner's answers on Rotating and Vote.

## Delete

- none
