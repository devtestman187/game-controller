# n9d2 report: "Round N of M" in the HUD, clock red in the last 15 s

## Summary

- The arena bar reads "Round N of M" when the match names both its round and its count, else "Round N" as before.
- The Bumper Round's clock turns the look's `bad` colour when 0 < time left <= 15000 ms; above that, and at 0, it stays ink. A race has no clock (`timeLeftMs` null), so it stays ink.
- HUD only: no protocol, snapshot-wire or map change. `arena_map.dart` untouched (n9d3 stop respected).
- Tests first: `arena_hud_round_test.dart` is new and fails on the code as it was (compile error: `ArenaHud` had no `round`/`rounds` parameters). After the change it passes: 4 of 4.
- Pinned tests checked: `arena_hud_test.dart` and `arena_view_test.dart` pass (18 tests in the two files), `party_host/test/arena_night_test.dart` passes (8 tests). No literal needed changing: `arena_view_test.dart:106` finds `'Round 1'` and no `rounds` is passed there, so the bare form still shows; `arena_night_test.dart:85` checks `'Round 1 of 3'` on the scoreboard, which the HUD is not on.
- `tools/mine.sh`: RESULT ok (4 files formatted, test_game analyzed and tested, touched tests OK). Not run by me: `tools/check.sh`, per the brief.

## Files changed

- `packages/test_game/lib/src/arena_hud_widgets.dart`: `ArenaHud` takes optional `round` and `rounds`; `_RoundRow` builds the "Round N of M" label and colours the clock `bad` in its last 15 s (`_hurryLeftMs = 15000`, with its reason in the doc comment). 363 lines (under 380).
- `packages/test_game/lib/src/arena_view_widgets.dart`: `ArenaBoard` takes optional `round` and `rounds` and passes them to `ArenaHud`. 206 lines.
- `packages/test_game/lib/src/arena_view.dart`: `ArenaView` passes its `round` and `rounds` to `ArenaBoard`. 159 lines.
- `packages/test_game/test/arena_hud_round_test.dart` (new): 4 tests, each on the menu look (Sunny, phone) and the TV look (`ToyLook.build(... tv: true)`).

## Computed test values

- Round label with round 2 and rounds 3: `'Round 2 of 3'`; with no rounds: `'Round 2'`.
- Clock colour by `timeLeftMs`: 15000 → `bad`; 15001 → `ink`; 1 → `bad`; 0 → `ink`; race (null) → `ink`.
- `bad` is `Color(0xFFFF4D5E)` in both palettes (toy_colors.dart:60, :87); the test asserts `bad != ink` first so the colour check means something.

## Self-check (docs/review-rules.md part A)

1. Host setups: the bar is drawn by `ArenaBoard` for every host view (TV, phone, joined phone); the night's round passes `round`/`rounds` through `ArenaView` (`arena_night_test` "hands the phones its number and count", passes).
2. Kept state: none added. The colour and label are computed from each frame's snapshot, so nothing starts or ends; with no round running, the HUD is not drawn (`showHud`), as before.
3. Combinations: the pause menu freezes the frame, so the colour freezes with it; results hide the bar via `showHud` (space kept), as before; the race keeps its clock out of the warning. Leaving the round needs no change. Covered by the existing `arena_view_test` and `arena_night_test` runs, which pass.
4. Stayed inside `allow:`; no other file edited.
5. Nothing stopped.
6. Looks: menu (Sunny phone) and TV look tested for both the label and the clock colour. No fixed pixel heights added.

## Questions and suggestions

1. The label uses `round` when both `round` and `rounds` are set, and `snapshot.round` otherwise. They normally agree; say if the label should always use `snapshot.round` and drop the `round` parameter.
2. The "Round N of M" label now appears in every ArenaView that receives `rounds` (not only the night). The brief asked for this, but the owner may want it limited to a night.
3. The new test file is expected to fail by compile error before the change, not an assertion. That is the first failure the runner will see; if it needs an assertion failure, the test would have to avoid the new parameters.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
arena: HUD shows Round N of M and warns the clock in its last 15 s

The bar reads "Round N of M" when the match names its round and count,
and the Bumper Round's clock turns the look's bad colour at 15 s or less
left (owner decision, Nov 24, item 9). The round and rounds pass from
ArenaView through ArenaBoard to ArenaHud as optional parameters. HUD only:
no protocol, snapshot or map change. A race has no clock and is unchanged.
New arena_hud_round_test.dart checks both looks (menu and TV) and fails
before the change.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

n9d2 done: the arena HUD shows "Round N of M" when the match names its count, and the Bumper clock turns bad in its last 15 s, on both looks (4 new tests; pinned tests pass). Open: n9d3 (map name) is a stop, not in this job; whether the label should be limited to a night (question 2 in the report).

## Delete

- none
