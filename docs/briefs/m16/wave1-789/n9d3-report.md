# n9d3 — the Arena HUD names the map

## Summary

The round bar in `ArenaHud` now shows the map's name beside the round text ("Pinball  Round 1 of 3  30.0 s …"). The HUD reads the id the snapshot already carries (`snapshot.mapId`) and looks the name up in a new small file, `arena_map_names.dart`. No view or session holds the loaded `ArenaMap`, so the name comes from that table. `arena_map.dart` is untouched and there is no wire change.

Test counts seen: `tools/mine.sh` on the new test file first failed to compile (no `arena_map_names.dart`), as intended. After the fix: `OK 4 tests packages/test_game` (the tool printed the count; the new file has 3 tests, and I did not check which the fourth is), `1 package(s) analyzed`, no analyzer errors. I also ran `arena_hud_round_test.dart`, `arena_hud_test.dart` and `arena_hud_coins_test.dart` directly with `flutter test`: `All tests passed!` (+18).

Decisions:
- The name is looked up from `snapshot.mapId` in the HUD itself, so `ArenaHud` takes no new parameter and `arena_view_widgets.dart` needs no change.
- The name widget is a `Text` with key `mapName`, placed first in the bar's Wrap, in the same style as the round label. For an unknown id the widget is not built, so the bar is unchanged.
- The drift test compares `arenaMapNames` with `{id: loadMap(id).name}` for every id in `maps/index.json`. The 5 listed maps are playroom, pinball, block-castle, toy-factory and spinning-tops. `_template.json`, `untitled` and the schema are not in the index, so they are not in the table.

## Files changed

- `packages/test_game/lib/src/arena_map_names.dart` (new): `arenaMapNames`, a const id-to-name map for the 5 bundled maps.
- `packages/test_game/lib/src/arena_hud_widgets.dart`: imports `arena_map_names.dart`; `_RoundRow.build` adds the `mapName` text first in the Wrap when the id is listed (+4 lines, 367 lines total, under 380).
- `packages/test_game/test/arena_hud_map_test.dart` (new, 3 tests):
  1. Each of the 5 bundled ids shows its name on the TV look and the phone look (`sunny`), in 3 boxes: 960x540 two-line, 812x375 one-line, 390x844 two-line. That is 5 × 3 × 2 = 30 checks, each `find.text(name)` finds one widget.
  2. The id `no-such-map` shows no `mapName` widget, keeps `Round 1 of 3`, and throws nothing, in the same 3 boxes on both looks (3 × 2 pumps).
  3. `arenaMapNames` equals the names read from the 5 map files: Playroom, Pinball, Block Castle, Toy Factory, Spinning Tops.

## Self-check (review-rules part A)

1. Host setups: the bar is the same widget on a TV (960x540) and a phone (812x375, 390x844); the test covers those boxes. Not covered: the "Play on this phone" and "Show on this device" entry points themselves. They pass the same snapshot.
2. Kept state: none. The HUD is a pure widget of the snapshot. With no snapshot in play it draws nothing new.
3. Combinations: the pause menu, host away, player away, "Get ready", dropped link, results and leaving are not changed by this edit, and no test covers them. The name comes from `snapshot.mapId`, which every frame carries; no state is added.
4. Stayed in the job's folder and inside `allow:`: yes for my edits. See the note on the churn revert below.
5. Stops: none. `arena_map.dart` was not needed.
6. Looks: the menu look (`sunny`) and the TV look (`tvLook`) are both tested. No fixed pixel height is set on the name; it sits in the Wrap.

## Notes on the check run

`tools/mine.sh` printed `churn: reverted 3 generated file(s)`. The three files were `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h` and `generated_plugins.cmake`. They were modified before this job started (listed in the session's git status), and after the run `git status` no longer lists them. I did not revert them myself, and I cannot restore them (I may not run git commands that change anything). Someone should check whether those uncommitted changes were lost.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

test_game: the Arena HUD names the map in the round (n9d3)

The round bar shows the bundled map's name beside the round text, on the
menu and TV looks, one-line and two-line. The snapshot already carries the
map id, so the name is looked up in arena_map_names.dart; no view or session
holds the loaded ArenaMap, and arena_map.dart is unchanged. An unknown id
shows no name. A test reads each name from its map file so the table cannot
drift. No wire change.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n9d3: done — the Arena HUD names the bundled map beside the round (menu and TV, one- and two-line); unknown ids show nothing. Open: lib/test_game.dart does not export arena_map_names.dart (its file is outside allow:), and the churn revert of the three tv_test_app generated files needs a look.

## Hand-over

- Question 1: may `lib/test_game.dart` get `export 'src/arena_map_names.dart';`? It is outside `allow:`, so I did not add it. The HUD and the test import the file directly.
- Question 2: the three generated files that `mine.sh` reverted were already modified at the start of this job. Please check whether their changes need restoring.

## Delete

- none
