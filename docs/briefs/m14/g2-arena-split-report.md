# M14 g2: split `arena.dart` by a pure move, for the Bumper Round (G9)

`packages/test_game/lib/src/arena.dart` (487) is split into three files along the design's seams (`party-night` §7 and
§13): the events, the field and the marbles with their shared movement, and the race. Every public name the rest of the
repo reads is still there; the session, the snapshot, the painters and all 69 existing arena tests compile and pass
unchanged. One test is added for the movement's new public seam. `tools/review.sh`'s one size FAIL at HEAD is gone.

## 1. Files and their line counts

| File | Before | After | What it holds now |
| --- | --- | --- | --- |
| `packages/test_game/lib/src/arena.dart` | 487 | 115 | `ArenaPhase`, `ArenaGame` (the race) |
| `packages/test_game/lib/src/arena_events.dart` | — | 63 | `GameInput`, `GameEventCause`, `GameEvent` |
| `packages/test_game/lib/src/arena_field.dart` | — | 391 | `WallSpec`, `HazardSpec`, `ArenaPlayer`, `ArenaFieldRules` |
| `packages/test_game/lib/src/arena_session.dart` | 156 | 157 | one import line (`arena_events.dart`) |
| `packages/test_game/lib/src/arena_view.dart` | 96 | 97 | one import line (`arena_events.dart`) |
| `packages/test_game/lib/test_game.dart` | 14 | 16 | two export lines (`arena_events.dart`, `arena_field.dart`) |
| `packages/test_game/test/arena_field_test.dart` | — | 56 | the one new test |

No existing test file was edited. The three parts hold 569 lines against the old 487: the difference is the blank
lines between files, the new dartdoc on the public seams and `ArenaGame`'s five const aliases.

## 2. What moved where

- **`arena_events.dart`** — `GameInput` (with its factories and the private `_unit` helper), `GameEventCause` and
  `GameEvent`, moved verbatim (`arena.dart:8-64` before). Imports `dart:ui` (Offset), `connection` (GamepadState,
  GamepadButton) and `protocol` (InputStateMessage, HapticEvent, HapticEventMessage).
- **`arena_field.dart`** — moved verbatim: `WallSpec` (`:66-73`), `HazardSpec` (`:75-106`), `ArenaPlayer`
  (`:116-168`), and into `ArenaFieldRules`: the constants (`:183-206`), the walls and hazards (`:208-221`), the field's
  size, walls, hazards and goal (`:226-299`), `resize` (`:301-305`), `join`/`leave`/`players`/`player`
  (`:309-322`), the hazards' clock (`:335`), the marble timers (`:336-341`), the movement (`:360-475`) and the goal-rect
  test (`:385`). The only edits inside moved code are references: `_game` → `_field`, `ArenaGame.x` → `ArenaFieldRules.x`,
  and `_move`/`_resolve`/`_checkHazards` called by their new public names. `ArenaPlayer._reset` stays private.
- **`arena.dart`** — `ArenaPhase` and `ArenaGame` with the round, the winner, the round break and `_newRound`
  (`:107-114`), i.e. what the design keeps on the race; `update()` (`:66-86`) and `_updatePlayer`'s goal block
  (`:88-105`) are unchanged apart from calling the shared movement.
- **The seams the move forced** (a second library cannot see a `_` member; the brief asks that the movement be
  callable by a second mode without copying). Each replaces one statement or loop of the old `ArenaGame` verbatim:
  `syncPlayers` (leavers then joiners, `update`'s first two statements), `advanceTime` (`_time += dt` and the four
  marble timers), `stepMarble` (`_updatePlayer`'s movement and dash), `moveMarble` (`_move`), `resolvePoint`
  (`_resolve`), `checkHazards` (`_checkHazards`), `reachedGoal` (the goal rect test), `stopDashes` (the loop that ends
  every dash when the round is won), `resetMarbles` (`_newRound`'s loop) and `noteDashHeld` (the break's loop that
  keeps A's press state current). The order of operations is the old one, statement for statement: `syncPlayers`,
  clamp, `advanceTime`, break or play, `stepMarble`, goal test.
- **Why the class is `ArenaFieldRules`** — `ArenaField` is already the field *widget* (`arena_view_widgets.dart:54`),
  and both are exported from `test_game.dart`; two `ArenaField`s would not compile.
- **The public tuning names** — the snapshot, the HUD and the tests read `ArenaGame.playerRadius`, `hazardRadius`,
  `speed`, `dashS`, `dashCooldownS`; they stay on `ArenaGame` as const aliases of `ArenaFieldRules`'s values
  (`arena.dart:36-40`). `roundBreakS` (`:32`) stays on the race. The other shared constants (`wallThickness`,
  `aimRange`, `dashSpeed`, `hazardGraceS`, `hitGapS`, `bumpThreshold`, `startPoint`, `startSpacing`, `goalArea`,
  `defaultWalls`, `defaultHazards`) now have their public home on `ArenaFieldRules`; nothing outside `test_game`
  read them (checked with grep over `controller_app`, `tv_test_app` and `packages`).

## 3. The shared movement's signature

```dart
// on ArenaFieldRules
void stepMarble(ArenaPlayer pl, double dt, GameInput input, List<GameEvent> events)
void moveMarble(ArenaPlayer pl, Offset delta, Offset velocity, List<GameEvent> events)
(Offset, bool) resolvePoint(Offset p, double r)
void checkHazards(ArenaPlayer pl, List<GameEvent> events)
bool reachedGoal(ArenaPlayer pl)
```

`stepMarble` is "a marble's step from its input" — aim, the dash on A's press, the walk or the dash, `moveMarble` and
`checkHazards` — and appends its events to the caller's list, as the race did. `ArenaGame._updatePlayer` is now
`stepMarble(p, dt, input, events)` and then `if (reachedGoal(p))`. `moveMarble` and `resolvePoint` are public because
G9's shove is a sub-stepped move that must not pass through a wall (`party-night` §7).

## 4. Tests

- **Before the job** (at `79ce8fb`, before any edit): `tools/check.sh arena` → 69 tests, PASS.
- **After**: 70 tests, PASS — the same 69, unchanged, plus the one new test.
- **The one new test**: "the shared movement moves a marble the same on its own as in the race"
  (`test/arena_field_test.dart`). A fixed 90-frame run (1/60 s) on a 1000×500 field with one wall at x = 0.6 and no
  hazards: A held for frames 0–9 (a dash), a press on frame 20 (still cooling down), walking right after that. Each
  frame it calls `ArenaFieldRules.stepMarble` on its own and `ArenaGame.update`, and compares the events
  (player, haptic, cause, intensity, duration), the place, dashing/recovering/cooldown and the three counters.
  Computed values, which the test also states on its own: shortest side 500; the wall's rect is
  x 600 ± 0.035×500/2 = 591.25..608.75; the marble is 0.032×500 = 16 px, so it rests at 591.25 − 16 = **575.25**,
  y = 0.5×500 = **250**; the dash is 0.55×2.6×500 = **715 px/s** for 0.3 s = 214.5 px, the walk 275 px/s, so the
  505.25 px to the wall take 0.3 + 290.75/275 = **1.357 s** (frame 82); the events are therefore exactly
  `[dash, cooldown, wall]` and the counters `[hits 1, dashes 1, failedDashes 1]`, with `phase` still `playing`.
  The test passed on its first run with those values, which is the equality it is there for.

## 5. Checks

```
tools/check.sh format analyze arena host tv
PASS  format      (3s)
PASS  analyze     (9s)
PASS  arena       (70 tests, 8s)
PASS  host        (270 tests, 25s)
PASS  tv          (11s)
All checks passed.
```

`tools/review.sh` (the job's diff):

```
NOTE size     packages/test_game/lib/src/arena_field.dart:1 391 lines (lib limit 400, aim 300)
review: 0 fail, 31 note
```

The size FAIL is gone: `arena.dart` is 115 lines and draws no size line at all (it drew `FAIL size ... 487 lines` at
HEAD). `tools/review.sh --all` has the same single arena size line and **8 FAILs, all pre-existing in files this job
does not touch**: `_stickLayout` 92, two `debugPrint(` in `providers.dart`, a `Color` in `packages/protocol`, two
`// ignore` in `tv_test_app/integration_test/sound_test.dart`, `_computeScreen` 120 and `packTray` 104. The 30 other
NOTEs are the moved tuning literals (`0.032`, `0.55`, …) and the 0.05 input dead zone, which the move carried into
`arena_field.dart`'s added lines; they were in `arena.dart` before and are unchanged.

## 6. Self-check: docs/review-rules.md part A

1. **Every host setup**: not affected — the split changes no behaviour; a TV/PC host, a phone host ("Play on this
   phone"/"Show on this device") and a joined phone all run the same `ArenaGame.update`, and the host and tv suites pass
   (270 and a full tv run). No protocol, snapshot or layout change, so a phone or host one build older is unaffected.
2. **When kept state starts and ends**: unchanged — the hazard clock (`_time`), the dash/cooldown/grace timers, the
   round time, the break and the dash-held flag start and end exactly where they did; only their home class moved
   (`advanceTime`, `noteDashHeld`), and `test/arena_test.dart`'s round-break and cooldown tests still pass.
3. **How a new state combines with the others**: not affected — no new state; `phase`, pause, away and ready are the
   same values with the same owner, and the race's `update` keeps the same break branch.
4. **Stay in the job's folder**: only `docs/briefs/m14/g2-arena-split-report.md`, `packages/test_game/lib` and
   `packages/test_game/test` were written (`git status` shows no other file of mine).
5. **Stop rather than overstep**: nothing outside `allow:` was needed and no rule was broken; the one judgement call
   (the field file over the 300 aim) is in Questions, not fixed by me.

## 7. Questions and suggestions

1. **The field file is 391 lines, over the 300 aim** (under the 400 hard limit). The seam by content is the one the
   design names, and a further split of "field + marbles + movement" is not possible inside plain libraries: the
   movement reads `ArenaPlayer`'s private place, facing, dash and timer fields, so a second file would mean either
   making nine marble fields public (a rewrite) or a `part` (the repo uses those for widgets, and a part would not help
   b1, which is another library). Asked: is 391 acceptable for g2, or should a follow-up split the marbles out?
2. **The class name**: `ArenaField` is the field widget (`arena_view_widgets.dart:54`), so the rules class is
   `ArenaFieldRules`. If you would rather the widget be `ArenaFieldView` (as the puzzle has `PuzzleField` for the
   rules and `PuzzlePlayView` for the view), that is a rename for a later brief; I did not touch the widget.
3. **The private members made public**: `stepMarble`, `moveMarble`, `resolvePoint`, `checkHazards` (from
   `_updatePlayer`'s movement, `_move`, `_resolve`, `_checkHazards`) and the small loops `syncPlayers`, `advanceTime`,
   `stopDashes`, `resetMarbles`, `noteDashHeld`, `reachedGoal`. The brief asks for exactly this ("callable by a second
   mode without copying"), but it does grow the public surface, and `resolvePoint`/`moveMarble` take pixel deltas; b1
   may want a friendlier "shove" entry on top of them.
4. **The tuning names**: only the five the snapshot, HUD and tests read are aliased on `ArenaGame`. If b1 or the HUD
   later reads `ArenaGame.wallThickness` or `ArenaGame.startPoint`, those names are on `ArenaFieldRules` now. Asked:
   alias the rest too, or leave the public home on the field?
5. **Suggestion for b1**: `syncPlayers` joins a controller as soon as it appears, which is the race's rule; the
   Bumper Round's "joins next round" (`party-night` §8) is a filter above it in the bumper's own update, not a change
   to the field.

## Commit message

refactor(test_game): split the Arena rules into events, field and race

`arena.dart` (487, the one size FAIL) is split by a pure move into
`arena_events.dart` (63), `arena_field.dart` (391) and `arena.dart` (115).
The field and marble movement (`stepMarble`, `moveMarble`, `resolvePoint`,
`checkHazards`, `advanceTime`, `resetMarbles`) are public on the new
`ArenaFieldRules` so the Bumper Round (G9) can share them; the race keeps
`ArenaGame`, its phase, winner and break. No behaviour change: all 69 arena,
270 host and the tv tests pass unchanged, plus one new test proving the shared
movement matches `ArenaGame.update` for a fixed 90-frame run. Size FAIL gone.

## Status row

M14 g2 done: `arena.dart` 487 → 115, split into `arena_events.dart` (63) and `arena_field.dart` (391, the shared
marble movement), all tests unchanged plus one seam test, the size FAIL gone; open: the field file is over the 300
aim (question 1) and b1 (Bumper rules) is next.

## Delete

- none

## Claude's review (Nov 9, 2026)

Accepted. Checked: outside the moved code only two imports and two exports changed; no existing test was edited; 69
tests plus the new same-movement test pass (`tools/check.sh format analyze arena`), host and tv passed in g3's gate
run on the same tree; `review.sh` has no FAIL, and `arena.dart` (115) no longer draws the size FAIL. The name
`ArenaFieldRules` (not `ArenaField`, the widget) and the const aliases on `ArenaGame` are right.
- **Question (the field file at 391)**: accepted for now. k1 (the level kit) takes the walls, hazards, start and goal
  out of `arena_field.dart` into `playroom.json` and its map type, and must leave `arena_field.dart` under 300 lines
  so k2's springs and belts have room; that goes in k1's brief.
