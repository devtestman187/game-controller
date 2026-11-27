# night2b d2w: the night's pick (director, Shuffle, Playlist) behind one provider

## Summary

- `NightPicker` gains `director` (order host, director, shuffle, playlist, rotating, vote); the default stays `host`.
- New `NightPick` (round, variant, reason) with `nightPlayableGames` (shapeRace, bumperRound) and `mapTierLevel`.
- New `NightPickNotifier` / `nightPickProvider`: `pickFor(round)` runs the director, Shuffle or Playlist over the pool
  (`variantPool(launchVariants(tier), settings)` filtered to the playable games), keeps the played list, and gives null
  for host, rotating, vote, or an empty pool.
- New `NightPlayedStore` on `party_night_played_v1`: the ids still in the launch variants, in order; cleared when the
  night becomes null.
- No UI, hook, scoreboard or game-screen change. `nightNextVariantProvider` and `NightVariant` are untouched.
- Pool sizes (computed from `packages/test_game/maps`): default settings 7 playable variants (shapeRace easy, medium,
  hard; bumperRound pinball easy, block-castle hard, toy-factory medium, spinning-tops medium). Kids 2 (shapeRace:easy,
  bumperRound:pinball). Arena Race's 3 of the 10 launch variants are never playable.
- `mine.sh`: format, analyze and the touched tests all OK. The package's touched test run reported `OK 54 tests`.

Decisions:
1. The played list holds variant ids; `pickFor` resolves them to the current launch variants, so a map's tier comes
   from the library as loaded. Ids that are no longer launch variants are dropped on load.
2. The played store treats a save that is not JSON as broken: it removes it and returns an empty list (as the settings
   store does). A JSON value that is not a list is treated the same way.
3. `pickFor` checks the current pick's round first, so the picker is only consulted for a new round (the brief's order).
4. Playlist position is the played list's length, not the round number, so it follows the played list.
5. `mapTierLevel` takes the library as `ArenaMapLibrary?`; a missing or unrated map plays as medium.
6. Tests use the real map files through `testMaps()` (host_harness) and an unrated copy of `playroom.json` (the tier line
   removed), and read the saved list from the prefs key.

## Hand-over

Files changed:
- `packages/party_host/lib/src/night/night_settings.dart`: `director` added to `NightPicker` with its dartdoc.
- `packages/party_host/lib/src/night/night_pick.dart` (new): `nightPlayableGames`, `mapTierLevel`, `NightPick`.
- `packages/party_host/lib/src/night/night_pick_provider.dart` (new): `nightRandomProvider`, `nightPickProvider`,
  `NightPickNotifier`.
- `packages/party_host/lib/src/night/night_played_store.dart` (new): `NightPlayedStore`.
- `packages/party_host/test/night_pick_test.dart` (new): 14 tests, one per rule in the brief.
- `docs/briefs/m17/night2b/d2w-report.md` (new): this report.

`night_settings_test.dart` is unchanged: no test lists every `NightPicker` value.

Self-check (review-rules part A):
1. Host setups: no screen is wired, so no host setup changes. The picker gives null for host (test "the host picks").
2. Kept state: the played list loads on build and is cleared when the night becomes null (test "the played list is
   cleared when the night ends"). With no night, the list is empty unless a stale save exists (question 1).
3. Combination with the pause menu, host away, player away, "Get ready", dropped link, results and leaving: not covered
   here; nothing reads the pick yet (d2x wires it in). The clear-on-end path covers leaving.
4. Files: all inside `allow:`.
5. Stops: none.
6. Looks: no UI.

Checks run: `tools/mine.sh` twice; the second run was OK (5 files formatted, package analyzed with no findings, touched
tests passed). The first run had 2 infos and 2 failing tests, which I fixed (const constructor, unused import, and the
night's three awards).

Tests (all in night_pick_test.dart; they pass; I did not run them against the base to see each fail without its rule):
- a map plays at its file's tier: pinball easy, toy-factory medium, block-castle hard
- no library, no such map, or an unrated map gives medium
- the host picks: null, nothing recorded
- the director opens round 1 at easy (reason opening)
- Kids: five rounds, easy only, only shapeRace:easy and bumperRound:pinball
- the director's second pick is never the first pick's variant
- pickFor(1) twice: same pick, one saved entry
- Shuffle: the seven default variants once each, reason null
- Playlist: the seven default variants in order, reason null
- a bumper-only pool never yields a Shape Race (10 rounds)
- default pool: Arena Race never picked (10 rounds)
- a pool of only Arena Race: null, nothing recorded
- the played list survives a new container on the same prefs
- the played list is cleared when the night ends

## Questions and suggestions

1. `build()` loads the played list even when no night runs. If the app stops after a night ends but before the clear is
   saved, the next night starts with a stale list. Suggest loading an empty list when `partyNightProvider` is null.
2. The current pick is not saved, only the played list, so a night restored mid-round re-picks that round on restart.
   Is that acceptable for d2x?
3. Kids pins the picker to `host`, so the Kids preset does not use the director until the host changes the picker.
   Confirm that is intended.
4. Opening tier "at difficultyMin" is tested with the default minimum (easy) only.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

m17 night2b d2w: the night's pick behind one provider

NightPicker gains director. NightPickNotifier picks each round with the director, Shuffle or Playlist over the pool
(launch variants, the settings' pool and difficulty, playable games only), and keeps the played list on prefs
(party_night_played_v1), cleared when the night ends. A map's tier comes from its file, unrated maps play as medium.
Host, rotating and vote give no pick. No UI or hook is wired yet (d2x).

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2b d2w: done: director picker, NightPick and nightPickProvider with the Shuffle and Playlist, the played list on
  prefs; 14 tests. Open: wiring into the night (d2x), the stale-list question, Vote and Rotating.

## Delete

- none
