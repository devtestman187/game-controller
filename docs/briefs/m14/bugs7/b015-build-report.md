# b015 build: the race landed on Block Castle and Toy Factory

## Summary

**Fixed, unverified: needs device check.** The two race sections the owner approved in bugs6 are in the map files,
numbers unchanged, and nothing else in either map changed (no wall, hazard, coin, Bumper or piece). Both maps still
pass the rule book and the schema (4 tests each) and still play the Bumper Round.

| | Block Castle | Toy Factory |
| --- | --- | --- |
| `start` | `[0.075, 0.5]` | `[0.1, 0.5]` |
| `goal` | `[0.4625, 0.444, 0.5375, 0.556]` (12.0 × 10.1 units) | `[0.88, 0.14, 0.97, 0.24]` (14.4 × 9.0 units) |
| `swapSides` | `true` | `true` |
| sheet | 42,793 bytes, was 35,793 | 57,540 bytes, was 49,034 |

- **Tests first.** New `race_maps_test.dart` (4 tests) failed on the old maps for the right reason ("block-castle has
  a race section: Expected not null, actual null") before either map changed; it passes now.
- **`four_maps_test.dart`** "Bumper Round only" is renamed and now says: all four keep the Bumper Round, and only
  pinball and spinning-tops have `race == null`.
- **The picker** now offers three race maps (playroom, block-castle, toy-factory) instead of one. `arena_waiting_test`
  asserts the new set; `arena_phone_card_test` no longer passes, because with three map cards the down arrow lands on
  Block Castle, so it now walks down to that card and left to the Playroom (same pick, same expectations).
- **`docs/levels.md`** said "A map with only `bumper` is a Bumper Round arena with no finish (M14 k2's four)"; it now
  names Pinball and Spinning Tops, and says the Playroom, Block Castle and Toy Factory play either mode.
- **The sheets** are re-rendered by the kit's render test (the render is a pure function of the map), so they now show
  the start column and the goal pad.
- **The risk:** Block Castle's goal is inside the keep, whose west and east gates never admit a marble (bugs6); the
  finish is a timing gate that opens to 1.8 marbles for about a third of a 3 s cycle.
- **Not done:** a device play test (none exists over map files); and the steering runs in bugs6 (1.82 s, 2.23 s) were
  over the same numbers, not repeated here.

What the owner should try on a device: race Block Castle with 2–4 players and judge the keep gate (fair gap or lucky
one), then Toy Factory, to see whether the open floor reads as a race or a straight line.

## Kit used

`tools/level.sh` itself is refused by the sandbox (as in bugs6), so I ran the commands its own table runs, from
`packages/test_game`:

- `flutter test --dart-define=mapId=block-castle test/map_check_test.dart test/map_schema_test.dart` → `+4: All tests passed!`
- `flutter test --dart-define=mapId=toy-factory test/map_check_test.dart test/map_schema_test.dart` → `+4: All tests passed!`
- `flutter test --dart-define=mapId=block-castle test/map_render_test.dart` → `wrote ../../docs/design/maps/block-castle.png (42793 bytes)`, `+1: All tests passed!`
- `flutter test --dart-define=mapId=toy-factory test/map_render_test.dart` → `wrote ../../docs/design/maps/toy-factory.png (57540 bytes)`, `+1: All tests passed!`

No Dart code produces a map: the race sections are the `.race.json` objects pasted into the two map files, and every
check and picture comes from the kit.

## Files changed

- `packages/test_game/test/race_maps_test.dart` (new): the two approved races end to end, both maps' Bumper sections,
  the rule book over each, and pinball/spinning-tops with no race.
- `packages/test_game/maps/block-castle.json`: the approved `race` line before `bumper`, and the `notes` sentence
  "No race section." replaced by one true clause on the race. No other change.
- `packages/test_game/maps/toy-factory.json`: the same for Toy Factory.
- `packages/test_game/test/four_maps_test.dart`: the "Bumper Round only" test renamed and changed to the real set of
  maps without a race; its Bumper assertion kept.
- `packages/party_host/test/arena_waiting_test.dart`: the race-mode map assertions now name the three race maps and
  the two without one.
- `packages/party_host/test/arena_phone_card_test.dart`: the card walk to the Playroom goes down to Block Castle and
  left, since the map row has three cards now.
- `docs/levels.md`: the one sentence saying which maps have a finish.
- `docs/design/maps/block-castle.png`, `docs/design/maps/toy-factory.png`: re-rendered by the kit.

## Computed test values

- Block Castle goal: `(0.5375 − 0.4625) × 160 = 12.0` units across, `(0.556 − 0.444) × 90 = 10.08 ≈ 10.1` down.
- Toy Factory goal: `(0.97 − 0.88) × 160 = 14.4` units across, `(0.24 − 0.14) × 90 = 9.0` down.
- Starting spots are `RaceSpec.startOf(slot)` at `startSpacing = 0.14`: 0.5 ± 0.14 and ± 0.28, all inside the field.
- The picker's race list is the index order filtered by `map.race != null`: playroom, block-castle, toy-factory (3);
  bumper mode still lists all 5.
- With three map cards in the Wrap the down arrow from the player rows lands on `arenaMap-block-castle` (measured
  with a temporary print, reverted) and one left press reaches `arenaMap-playroom`.
- Test counts on the final tree: arena 226, host 447, phone 464.

## Decisions

1. **The expected values are constants in the new test, not read from the bugs6 files.** The bugs6 brief folder is
   deleted after a release, so a test reading it would break then; the numbers are copied unchanged and the test
   names their source.
2. **`race` sits before `bumper`, after `decor`.** That is `playroom.json`'s and the `docs/levels.md` example's order,
   and it keeps each file's style.
3. **The kit's own commands stand in for `tools/level.sh`**, as the brief allows for `render` and as bugs6 did for
   `check`; nothing in the kit was worked around.
4. **`site/shots/*.png` are back at the committed bytes.** The required `phone` check rewrites them; `git show
   HEAD:…` wrote them back, so the tree has no diff outside `allow:`. (`docs/design/m13-*.png` and the Windows
   generated plugin files were already dirty when the job started, at 21:09; not mine.)

## Questions

1. Block Castle's finish is the keep's timing gate (opens about a third of a 3 s cycle). Is that the intended
   difficulty for the shipped race, or should a later job move the goal to the courtyard?
2. The race's four starts sit 0.14 apart (about 2.2 marbles), under the Bumper Round's 3-marble rule. Should the
   rule book gain a start-spacing check for the race? (bugs6 Q3, still open.)

## Self-check (review-rules.md part A)

1. **Every host setup** — not affected: no app, rules or protocol code changed, only map data read by the shared
   picker; the picker is one code path for TV and phone, tested by `arena_waiting_test` ("the card shows … the maps it
   can play") and `arena_phone_card_test` (a phone walks the card). Not run on a device.
2. **When kept state starts and ends** — not affected: no timer, flag or cache is added; the race section is read once
   when the map loads, as `race_maps_test`'s four tests show.
3. **How a new state combines with the others** — the race section adds no pause, wait or input block; it only makes
   the two maps offer the race mode, tested by `arena_waiting_test`'s mode switch and by `checkMap` over both maps
   (`map_check_test.dart` with `mapId`, 4 tests each).
4. **Stay in the job's folder** — `git status --porcelain` shows only files in `allow:` (plus the pre-existing dirty
   files noted in Decision 4); the regenerated `site/shots` are restored byte-for-byte, so they show no change.
5. **Stop rather than overstep** — nothing needed was outside `allow:`; `tools/level.sh` is refused by the sandbox, so
   its exact commands were run instead (the brief names this for `render`); no design decision was taken silently.

## Commit message

Land the approved race on Block Castle and Toy Factory (B-015)

Both maps now carry the race the owner approved in bugs6: Block Castle
starts on the west lawn and finishes on a pad inside the keep, Toy Factory
runs across the open floor to the top-east bay; both swap sides every round.
The numbers are pasted unchanged and both keep their Bumper Round.
A new race_maps_test holds the values; four_maps_test, the host picker
tests and docs/levels.md now say which maps have a race, and both design
sheets are re-rendered. Needs a device check: the keep gate opens only a
third of its cycle.

## Status row

B-015 done: race landed on Block Castle and Toy Factory (data, tests, sheets, docs), all checks pass; fixed, unverified — needs a device check; open: the keep-gate timing and race start spacing.

## Delete

- none
