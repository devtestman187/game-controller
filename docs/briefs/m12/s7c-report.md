# M12 step 7 s7c — G4 report: cameras, painters, the viewer, the Arena's HUD on a phone

Stopped at G4 as the brief says. Contract §0.6, §2, §3 and §4 are in; §5 (the size check) was not in the
brief's read line and is not started.

## What was done

### 1. `ViewContext.wholeMatch` (`game_kit`)

- `typedef ViewContext = ({roster, String? playerId, bool wholeMatch})`, documented with m12-phone-layout §0.6;
  every literal in the repo supplies it (analyze passes).
- `FrameView` takes `wholeMatch` (default false) and passes it into the viewer's context; a new
  `frame_view_test` case proves the viewer sees `wholeMatch: true` and the phone's own `playerId` together.

### 2. `PuzzleCamera` (`puzzle_game/lib/src/camera.dart`, new, 94 lines)

- `PuzzleCamera.whole()` (`side == null`) and `PuzzleCamera.side(PuzzleSide)`; value equality on the side.
- `PuzzleCamera.scale(layout, camera, box)` → px per world unit: on a screen layout it is `fieldIn(box).scale`; on
  a phones layout it is `place(...).scale`.
- `PuzzleCamera.place(layout, camera, box, side)` → `(scale, origin)` for a phones layout: one world fitted,
  bottom-aligned (the spare height is on top); whole side by side when `box.width > wholeSideBySideAspect *
  box.height` (3.0, named and documented), else stacked with the left world on top. The two worlds are centred
  as a pair, so `right.origin` is `left.origin + (world.width * scale, 0)` or `+ (0, world.height * scale)`.
- `PuzzleCamera.forPlayer({target, teams, playerId, wholeMatch})`: screen, no player ID, an ID not in the teams,
  or `wholeMatch` → whole; else that player's side.
- `fieldIn` moved here from `view.dart` unchanged (public, and `puzzle_game.dart` exports `camera.dart`), so the
  painters and the size check share one function. `split_layout.dart` was not touched (still 384 lines).

### 3. Painters (`view.dart`, `match_painter.dart`)

- `MatchView`/`MatchPainter` take `target` (default `screen`) and `camera` (default `whole`). A screen match still
  draws `PuzzlePainter` (one board) or the old split picture; `_screen` in `MatchPainter` is the old code, body for
  body, only with `_clock`/`_barFraction` pulled out so the phone HUD reuses them.
- Phones: for each side the camera shows, `canvas` is translated/scaled by `PuzzleCamera.place`, then
  `PuzzlePainter` draws that side's board in `layout.left` and `_phoneHud` draws in `layout.hud`: clock (top,
  0.34 of the area's height, red while warning), "You 2/4" for this side's count (0.22), "Right 3/6" /
  "Left 3/6" for the other side (0.22, white70), and the time bar (0.06) along the area's bottom. The line
  positions are named fractions (`_clockLine`, `_ownLine`, `_otherLine`, `_barShare`, ...).
- A one-board phones match draws `layout.left` with the one count and no other side. Whole on phones draws each
  side's own HUD, whose count names the side ("Left 0/4").
- `phoneHud(snapshot, side, whole:)` returns the three texts (clock, own, other) as a record, so canvas text is
  testable; `shouldRepaint` compares the camera too. `play_view.dart` passes its target and camera through.

### 4. The viewer (`puzzle_module.dart`)

- `ShapeRaceViewer` gained `teams` (each player's side, built by `createViewer` from the setup's `"teams"` — a
  side name, else a `FormatException` naming the key) and builds the camera in `build` with
  `PuzzleCamera.forPlayer(target: target, teams: teams, playerId: view.playerId, wholeMatch: view.wholeMatch)`.
  The viewer uses the setup's teams, not the snapshot's boards: the setup is what the host decided at the start.
- `MatchView` is built with `target` and that camera.

### 5. party_host

- `ownPlayerIdProvider` (`Provider<String?>`, null) and `wholeMatchProvider` (`Provider<bool>`, false), both
  documented per contract §3 and §0.6. Nothing overrides them by default: the TV's screen draws the whole match as
  before.
- `PuzzleScreen._camera` is that same `forPlayer` call with `_target`, `widget.teams`, the two providers, and
  `PuzzlePlayView` gets it. Extracting it also keeps `build` at 60 lines (it was 67 with the call inline).

### 6. controller_app (the app wiring §0.6 needs)

- `JoinedView` passes `wholeMatch: ref.watch(isTabletProvider)` to `FrameView`.
- `phoneHostOverrides` adds `ownPlayerIdProvider` (this phone's `identityProvider.controllerId`) and
  `wholeMatchProvider` (`isTabletProvider`), beside the other party_host overrides.

### 7. The Arena's bar on a phone (`test_game/lib/src/arena_view_widgets.dart`)

- `ArenaHud.oneLineBelow = 480.0` (px, documented: phones are 375–393 high, the TV and tablets 540 and up).
  `ArenaBoard` reads its box with a `LayoutBuilder` and passes `oneLine: maxHeight < ArenaHud.oneLineBelow`.
- In the one-line form everything is one `Wrap` with small text (`bodySmall`), tight padding (12 × 2 px), 12 px
  item gap, 10 px counter gap and a 10 px dot; on a tall box the old `Column` with `titleMedium`/`titleSmall` is
  kept, now via `_RoundRow`/`_PlayerRow` (named widgets, per the guidelines) with the gaps as named constants.
  All the texts and keys are unchanged (`Round N`, `roundTime`, `P1 Name`, `wins-$id`, `hits-$id`, `dashes-$id`,
  `Dash ready (A)`).

## The camera's numbers

`PuzzleCamera.scale` with the `side` camera at seed 1, the G3 table's values (the same ones `camera_test` pins):

| puzzle | phones world (units) | 667×375 px/unit | 734×372 px/unit |
| --- | --- | --- | --- |
| house | 90.88 × 88.50 | 4.2373 | 4.2034 |
| rocket | 89.19 × 79.50 | 4.7170 | 4.6792 |
| tree | 91.06 × 102.00 | 3.6765 | 3.6471 |
| boat | 111.59 × 80.52 | 4.6574 | 4.6202 |

- At 734×372 the phone's height decides for every puzzle, so the world's bottom edge is the box's bottom
  (house: `88.5 × 4.2034 = 372`), and the spare width is split evenly (house: `(734 − 382.0) / 2 = 176.0` px).
- `whole` on phones, house at 1600×400 (4:1 > 3:1): scale `min(1600 / 181.76, 400 / 88.5) = 4.5198`; the left
  world at (389.24, 0) and the right at (800.00, 0), each 410.76 × 400 px, centred at x 800.
- `whole` on phones at 1024×768 (4:3): scale `min(1024 / 90.88, 768 / 177) = 4.3390`; left at (314.84, 0), right at
  (314.84, 384.00), each 394.33 × 384 px: stacked, left on top, touching.
- `whole` on the screen at 667×375: `fieldIn` = 4.16667 (the height decides: 375 / 90; the width would give
  4.16875), origin (0.17, 0), the 160 × 90 field.

## What a phone side shows at 734×372 (house, seed 1, left side)

World drawn from (176.0, 0) to (558.0, 372.0) — 382.0 × 372.0 px — on the phone's dark background (the
remaining 176 px each side is background). Top to bottom:

1. **Tray row, y 8.4 to 94.6 (86.2 px high):** the four house pieces at 0.75 of their size, packed in one row
   from x 184.4 to 381.5 (197.1 px wide).
2. **The HUD, same band, x 381.5 to 549.6 (168.1 px wide):**
   - clock "2:00", left-aligned at x 381.5, centred on y 27.4, 29.3 px high, bold white;
   - this side's count "You 0/4" at x 381.5, centred on y 55.8, 19.0 px high, white;
   - the other side's "Right 0/4" at x 381.5, centred on y 77.4, 19.0 px high, white70;
   - the time bar along the bottom, x 381.5 to 549.6 (full at the start), y 89.4 to 94.6 (5.2 px high), white24
     or red while the clock warns.
3. **The board, y 103.0 to 363.6 (260.6 px high), x 240.9 to 493.1 (252.2 px wide):** the crop of the picture,
   centred under the tray row and the HUD, with the pieces' outlines and the players' dots.
4. **Bottom margin:** 8.4 px of world (372 − 363.6), then nothing — the world ends at the box's bottom edge.

The 667×375 SE draws the same order at 4.2373 px/unit (the HUD area is 169.5 × 86.9 px there).

## The Arena's bar

| box | bar height | share of the height | form |
| --- | --- | --- | --- |
| 667×375 | 52 px | 13.87 % | one line: three runs of 16 px text + 2 px padding above and below |
| 852×393 | 52 px | 13.23 % | one line, same |
| 960×540 | 88 px | 16.30 % | round above one row per player (the old form) |

The 52 px is three runs (round, player 1, player 2) of `bodySmall` text; the test font draws every glyph as a
square of the font size, so a real font fits more per run than the test. No overflow at either phone box: the
field keeps 323 of 375 and 341 of 393 px.

## Tests added (17, and 1 extended)

- `game_kit/test/frame_view_test.dart` (1): the viewer is told to draw the whole match when this phone has the
  room for it (and still gets the phone's own player ID).
- `puzzle_game/test/camera_test.dart` (8): the side camera at 667×375 and 734×372 gives the G3 px/unit for all
  four puzzles at seed 1, with the world's bottom on the box's bottom and the spare width even; both sides of the
  side camera place alike; whole at 1600×400 (scale, origins, no overlap, inside the box); whole at 1024×768
  (stacked, left above right, touching); whole on the screen = `fieldIn` = 4.16667; `forPlayer` picks each side,
  and whole for no player, an unknown player, `wholeMatch`, and the screen.
- `puzzle_game/test/view_test.dart` (3): the HUD texts for each side ("You 0/4", "Right 2/4", "You 2/4",
  "Left 0/4") and the clock "1:05" at a 65 s limit; a one-board match's count alone; a phones match draws side
  left, side right and whole in a 667×375 box without an exception and not blank, and on the screen the camera
  makes no difference (pixels identical, difference 0.0).
- `puzzle_game/test/puzzle_module_test.dart`: the one load test (the files load once per process, Q1) now also
  pumps phones views and checks the drawn camera: p1 → side(left), p2 → side(right), no player → whole,
  `wholeMatch` → whole, a screen setup → whole.
- `party_host/test/puzzle_screen_test.dart` (3): a phones round with `ownPlayerIdProvider` p2 → side(right); no own
  player → whole; own player plus `wholeMatchProvider` → whole. The harness's `pumpHost` gained an `overrides`
  list.
- `test_game/test/arena_view_test.dart` (2): at 667×375 and 852×393 no overflow, the bar ≤ 15 % of the height and
  the runs abut; at 960×540 the bar keeps the round above the players and takes > 15 %.

## Test counts

| check | before | after |
| --- | --- | --- |
| kit | 32 | **33** (the `wholeMatch` pass-through) |
| arena | 40 | **42** (the two bar tests) |
| puzzle | 86 | **97** (8 camera + 3 view + the extended module test) |
| host | 62 | **65** (own side, no own player, `wholeMatch`) |
| phone | 311 | 311 |
| tv | 28 | 28 |

The before column is the last job's count for puzzle/host/tv and this suite minus the tests added here (1 kit, 2
arena, 11 puzzle, 3 host) for the rest; no test was removed or renamed.

## Existing expectations

None changed. Old → new: **none**. The screen pictures are drawn by the same code (`_screen`), the split-screen
captures keep their values, and the new screen test compares whole and side cameras pixel for pixel (0.0).

## Line counts

| file | lines | |
| --- | --- | --- |
| `puzzle_game/lib/src/camera.dart` | 94 | new |
| `puzzle_game/lib/src/match_painter.dart` | 254 | touched |
| `puzzle_game/lib/src/view.dart` | 75 | touched (`fieldIn` left) |
| `puzzle_game/lib/src/puzzle_module.dart` | 163 | touched |
| `puzzle_game/lib/src/play_view.dart` | 141 | touched |
| `puzzle_game/lib/puzzle_game.dart` | 22 | touched (exports `camera.dart`) |
| `puzzle_game/test/camera_test.dart` | 130 | new |
| `puzzle_game/test/view_test.dart` | 364 | touched |
| `puzzle_game/test/puzzle_module_test.dart` | 154 | touched |
| `test_game/lib/src/arena_view_widgets.dart` | 263 | touched |
| `test_game/test/arena_view_test.dart` | 251 | touched |
| `party_host/lib/src/providers.dart` | 302 | touched, **flagged: over the 300 aim** (under the 400 limit) |
| `party_host/lib/src/ui/puzzle_screen.dart` | 205 | touched |
| `party_host/test/support/host_harness.dart` | 177 | touched |
| `party_host/test/puzzle_screen_test.dart` | 160 | touched |
| `game_kit/lib/src/game_module.dart` | 46 | touched |
| `game_kit/lib/src/frame_view.dart` | 279 | touched |
| `game_kit/test/frame_view_test.dart` | 356 | touched (test, under 500) |
| `controller_app/lib/src/ui/joined_view.dart` | 89 | touched |
| `controller_app/lib/src/host/host_overrides.dart` | 33 | touched |

No lib file is over 400 and no test over 500. `split_layout.dart` is 384 and gained no lines.

## Checks

- `tools/check.sh format analyze kit arena puzzle host phone tv` — **PASS** all eight: format (2s), analyze (7s), kit
  (33 tests, 5s), arena (42 tests, 6s), puzzle (97 tests, 12s), host (65 tests, 12s), phone (311 tests, 17s), tv
  (28 tests, 9s).
- `tools/review.sh` — **0 fail**, 2 notes: `party_host/lib/src/providers.dart` 302 lines (the 300 aim), and the
  pre-existing `1000` in `match_painter.dart`'s `_barFraction`. Getting to 0 fail needed two small refactors: the
  camera in `PuzzleScreen.build` became the `_camera` getter (67 → 60 lines), and `logProvider`'s body became a
  top-level `_logBuffer(Ref)` (the detector read the provider's `});` as an unclosed body and the added lines
  pushed that false positive from 53 to 66 lines).

## Questions and suggestions

1. **The HUD when the whole match is drawn:** each side's area shows its clock and its own count ("Left 0/4"), not
   the other side's. Contract §2's `side` bullet names both counts; the `whole` bullet only says each side keeps
   its own area. If both counts should stay in each area, `phoneHud`'s `whole` branch is the one line to change.
2. **The Arena's one-line form uses smaller text** (`bodySmall` instead of `titleMedium`/`titleSmall`) and tighter
   spacing. Contract §4 only asks for a one-line form; the size change is what fits three runs in 52 px with the
   test font. Say if the smaller text should not be used, and I'll fit it another way (e.g. shorter labels).
3. **`phoneHud` is public** in `puzzle_game` (it is a top-level function in the `view.dart` part, so the tests can
   read the HUD's texts without pixels). If it should stay private, the HUD texts can only be checked by pixels.
4. **controller_app wiring:** the brief's item 5 names party_host only, but contract §0.3/§0.6 need the phone app to
   set `wholeMatch` on a tablet, so `JoinedView` and `phoneHostOverrides` are wired (inside the allowed
   `controller_app/lib`). I added no controller_app test; say if one is wanted.
5. **`_clock`'s arithmetic** (`~/ 60`, `% 60`, `padLeft(2, '0')`, `/ 1000`) is the old painter's code, now a
   top-level function next to the HUD; I left its literals as they were rather than renaming them into constants
   in this job. `review.sh` notes only the `1000` in `_barFraction`.

## Commit message

Draw the puzzle and the Arena on phones

A phone draws its own side of a `phones` match through the new `PuzzleCamera`, and the whole match when it plays
no side, has `wholeMatch` set (a tablet), or shows a screen match; the screen's picture is unchanged. The viewer
picks the side from the setup's teams, the host screen from `ownPlayerIdProvider`, and both take `wholeMatch`
from `wholeMatchProvider` (the phone app sets it from `isTabletProvider`). The phone painters draw the clock area
beside the tray: the clock, "You 2/4", "Right 3/6" and the time bar. The Arena's bar folds to one line with small
text on a box under 480 px high, so it takes 52 px (13.9 %) of a 667×375 phone instead of overflowing. Camera,
viewer, host, Arena and screen-picture tests: 97 puzzle, 65 host, 42 arena, 33 kit.

## Status row

| 7 Puzzle on phones | s7c G4 done ([s7c-report.md](s7c-report.md)): `PuzzleCamera` (whole/side, `scale`/`place`, `forPlayer`), `MatchView`/`MatchPainter` through it with the phone HUD (clock, own and other counts, bar) and today's screen picture, the viewer's side/whole choice from the setup's teams and `wholeMatch`, `ownPlayerIdProvider`/`wholeMatchProvider` with the host screen and the phone app's overrides, and the Arena's one-line bar under 480 px (52 px, 13.9 % at 667×375). 97 puzzle, 65 host, 42 arena, 33 kit tests. Open: contract §5's size check (`minPieceMm` 8.5, `controller_app/test`), which uses `PuzzleCamera.scale` |

## Delete

- none
