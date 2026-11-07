# M12 step 7 contract: the puzzle and the Arena on phones

Refines m12.md §2.8 (D4) for step 7, and wins where they differ. From the G0 survey ([s7-g0-survey.md](../briefs/m12/s7-g0-survey.md)); Claude's answers to its questions are §0.

## 0. Decisions on the survey's questions (Nov 7, 2026)

1. **"9 mm across" is the piece's circumscribed diameter** (`PieceShape.size`) drawn at full size on the board. Tray pieces are previews drawn at `trayScale` and aren't counted. (Pieces are moved with the controls, not touched, so the minimum is about seeing a piece, and a long thin piece like the mast is long enough to see.)
2. **The smallest supported phone is the iPhone SE screen, 667×375 pt**, with the px-per-mm `controller_app` uses for an iOS phone (`layout.dart`). A shown game fills the whole safe area, behind the top bar (see 7), so the body size isn't the measure.
3. **The check lives in `controller_app/test`**, which has the screen table and the px-per-mm; it asks `puzzle_game` for the drawn scale through a public pure function (§2). `minPieceMm = 9` is a named constant in `puzzle_game` (PRD v2 "On phones").
4. **The layout target travels in the setup.** `shapeRaceSetup` gains `layout`: `"phones"`, or absent for `screen`. The host decides when the round is created: `phones` when the host shares its view with joined phones (`HostService.shareView`, step 6), else `screen`. So the TV and "Show on this device" keep today's layout, and "Play on this phone" uses `phones`. The rules and every viewer build the same world from (puzzle, seed, target). No snapshot version change: no older app lists `view`.
5. **A solo `phones` match** is one side with the tray on top and the board below it, all of it shown.
6. **Tablets show the whole match through a camera choice, not another world.** `ViewContext` gains `wholeMatch` (bool): the phone app sets it on a tablet (`isTabletProvider`). The world stays the `phones` one.
7. **The game fills the screen behind the top bar** on a phone, for the joined view and the host route alike; the top bar draws over it with a transparent background while a game is shown. (Step 6's s6b does this, since it changes `ControllerScreen` anyway.)
8. **No Hard puzzle exists today.** The check prints "no Hard puzzle" until one does; with one, it prints its smallest piece in mm and doesn't fail.

## 1. The `phones` world (puzzle_game)
- `enum LayoutTarget { screen, phones }`. `SplitLayout.of(puzzle, seed, {LayoutTarget target = LayoutTarget.screen})`, memoised per (puzzle, seed, target). `screen` is today's layout: no existing expected value changes.
- A `phones` side: a HUD strip of `hudStrip` (6) units at the top, then the tray along the top edge across the side's whole width, then the board centred below it. The side's world aims at `phoneSideAspect` = 2.0 (width : height; landscape phones run 16:9 to 19.5:9 and the camera letterboxes the rest): the tray is packed into the width that gives that aspect, rows added as needed, and the board stays 80×72. Both sides get the same shape. The rules pack the tray at start with the same width (`packTray`, `trayLayout` in `game.dart`), so pieces start where every viewer draws them.
- `PuzzleMatch` takes the target from the setup and passes it to the layout.

## 2. Cameras (puzzle_game)
- `PuzzleCamera`: `whole` or `side(left|right)`. A pure `PuzzleCamera.scale(SplitLayout layout, PuzzleCamera camera, Size box)` returns px per world unit; the painters and the size check both use it.
- `side`: that side's world, fitted to the box and aligned to its bottom (spare height goes on top, away from the thumbs), with the strip along the top: the clock, this side's progress and the other side's ("Right 3/6"), and the time bar.
- `whole` for a `phones` match: the two sides side by side when the box is wider than 3:1, else stacked with the left side on top, and one strip on top. `whole` for `screen`: today's picture.
- The viewer picks `side` for the side `ViewContext.playerId` plays on, and `whole` when the player isn't in the match, when `wholeMatch` is set, or for a `screen` match.

## 3. The host phone's own view (party_host)
- `ownPlayerIdProvider` (party_host, default null): the phone host overrides it with its own client's controller ID. The puzzle screen draws with the same camera rule as a viewer: its own side in a `phones` match, `whole` otherwise or on a tablet. The TV leaves it null: nothing changes there.

## 4. The Arena on phones (test_game)
- The whole field on every phone (it already stretches to any box). Widget tests at 667×375 and 852×393: no overflow; if the HUD overflows, it gets a one-line form below a box height the job names.

## 5. The size check (controller_app/test)
For every puzzle file, with the `phones` target and the `side` camera, on every non-tablet screen in the layout table drawn as a full safe area: the smallest piece in mm. Easy and Medium under `minPieceMm` fail with the puzzle, piece, screen and size; Hard is printed. The test also prints a table of the smallest piece per puzzle per screen, which goes in the job report.

## 6. Jobs and gates
| Job | What | Gates |
| --- | --- | --- |
| s7-g1 | Plan: seams to split `game.dart` (732) and `view.dart` (439) before anything is added; how the tray packing changes; the expected smallest piece per puzzle on the SE and on an 852×393 phone with §1's world (arithmetic, no code) | G1 |
| s7a | The splits as pure moves | G4 (`review.sh --strings`, test counts unchanged) |
| s7b | §1, the setup key, the host's choice | G3: the world and the rules, with tests |
| s7c | §2–§5 | G4 |
