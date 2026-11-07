# M12 step 7 s7b — G3 report: the phones world, the rules, the setup key, the host's choice

Stopped at G3: contract §1 and the setup's `layout` key are in, §2–§5 (cameras, painters, the viewer's
drawing, the size check) are not started.

## What was done

### 1. The `phones` world (`puzzle_game/lib/src/split_layout.dart`)

- `enum LayoutTarget { screen, phones }`, documented per contract §1: `screen` is the PRD v2 split screen,
  `phones` is one side per phone (tray on top, clock at its right end, the crop below).
- `SplitLayout.of(puzzle, seed, {LayoutTarget target = LayoutTarget.screen})`; the memo is now
  `Expando<Map<(int, LayoutTarget), SplitLayout>>` with `_keep` 8 unchanged, so `of(p, s)` and
  `of(p, s, target: phones)` are different layouts (tested).
- The old `_compute` became `_computeScreen` (contract §1: verbatim) except for two renames the contract's
  §2–§5 need: `_margin` → public `margin`, and the literal `6` in `startX` → `_dotInset`.
- New `_computePhones`, with the named constants (unit and why):

  | constant | value | unit | why |
  | --- | --- | --- | --- |
  | `margin` | 2.0 | world units | around a world and between its panels (§1); was `_margin` |
  | `hudWidth` | 40.0 | world units | the clock, the two sides' counts and the time bar at the right end of the tray row, in the same row: no separate strip band (§1) |
  | `phoneMaxAspect` | 2.2 | width / height | wider than any landscape phone; past it the tray packs in two rows instead (§1) |
  | `_dotInset` | 6.0 | world units | where the players' dots start along the board's edge; was a literal `6` in both layouts |
  | `trayGap` (`tray.dart`) | 2.0 | world units | the packing's gap at a tray's edges and between rows; was `packTray`'s private `gap`, and the phone world adds it to the pieces' extent |

- The world is sized to its content: `W = max(crop + 2 margin, tray row + hudWidth + 2 margin)`,
  `H = margin + tray height + margin + crop height + margin`; the board is the crop, centred; both sides are the
  same world and the same angles (`compactStartAngles(..., flat: true)`).
- New `SplitLayout.hud` (`Rect?`, world units): the phones' clock area; null on `screen`. The screen-only members
  (`scale`, `leftBox`, `rightBox`, `hudStrip`, `trayBelow`) keep the plan's placeholders and each doc says
  screen-only.
- The tray is packed without a width limit to measure its one row, then the tray's width is the measured right
  edge + `trayGap`, so the rules' `packTray` at that width reproduces the same row (the width takes each piece's
  full-overlap start into account, or a piece would wrap at the tray's own width). If the world would be wider
  than `phoneMaxAspect`, `_twoRowTray` searches upward from the widest piece for the narrowest width that packs
  in two rows and keeps that width, so the rules pack it identically there too.

### 2. `PuzzleMatch` takes the target (`match.dart`, `snapshot.dart`)

- `PuzzleMatch(..., this.target = LayoutTarget.screen)`; the layout is built when `format.split || target ==
  LayoutTarget.phones`, so a solo/team `phones` match plays the layout's `left` world with its angles, and a solo
  `screen` match is untouched (no layout, its own angles).
- `snapshot()` sends `seed` whenever the sides came from a layout: a race, and now a one-board `phones` match
  (additive key `sd`, version stays 1). `MatchSnapshot.seed`'s doc says both.

### 3. The setup key (`puzzle_module.dart`, `puzzle_session.dart`, `play_view.dart`)

- `const phonesLayoutName = 'phones'`; `shapeRaceSetup` adds `'layout': 'phones'` only for a `phones` match, so an
  app that doesn't know the key reads the setup as before.
- `createViewer` reads it in a new `_layoutTarget`: absent → `screen`, `'phones'` → `phones`, anything else →
  `FormatException('view setup "layout": … is not "phones"')`, naming the key. `ShapeRaceViewer` stores the target
  for s7c (it draws nothing new yet).
- `PuzzleSession` and `PuzzlePlayView` take `target` (default `screen`) and pass it to the match.

### 4. The host's choice (`party_host/lib/src/ui/puzzle_screen.dart`)

- `_target` is read once in `initState` from `HostService.shareView`: `phones` when the host shares its view,
  else `screen`; it is fixed for the round and passed to `PuzzlePlayView`. A change of `shareView` waits for the
  next round (a rematch builds a new screen).

### 5. `rocket.json`: the window's radius 4 → 6 (diameter 8 → 12 units)

No test expectation changed: the suite's rocket checks are properties, not numbers, and all 80 existing tests
pass with the new window. The numbers that do change (seed 1, the `screen` target, computed by printing both):

| value | old (r 4) | new (r 6) |
| --- | --- | --- |
| window's box at its start angle | 8 × 8 units | 12 × 12 units |
| the crop (both worlds) | 20,7–60,66 | unchanged: the window stays inside the body |
| screen world (`left.size`) | 63.5 × 63.0 | 66.5 × 63.0 |
| screen tray rect | 2,2–17.5,61 (15.5 × 59) | 2,2–20.5,61 (18.5 × 59) |
| screen board rect | 21.5,2–61.5,61 | 24.5,2–64.5,61 |
| `layout.scale` | 1.2441 | 1.1880 |
| window on the screen (field units, of 160 wide) | 9.95 (6.2 %) | 14.26 (8.9 %) |
| `hudStrip` | true | true |

The window is 2 units bigger on each side and the screen's board is 4 % smaller as a result; the TV shows the
window 43 % wider. That is what the contract's §0.3 asks for.

### 6. The printing test (no mm assertion yet)

`split_layout_test.dart`, *prints every puzzle's phone world and its smallest piece at two phone sizes*: for each
puzzle at seed 1, the phones world W × H, `min(boxW / W, boxH / H)` for 667×375 and 734×372, and the smallest
circumscribed diameter in px and in mm (`160 / 25.4` px per mm), all with `debugPrint`.

| puzzle | phones world (units) | smallest piece (units) | 667×375 px/unit, px, mm | 734×372 px/unit, px, mm |
| --- | --- | --- | --- | --- |
| house | 90.88 × 88.50 | sun, 14.00 | 4.2373, 59.3, **9.42 mm** | 4.2034, 58.8, **9.34 mm** |
| rocket | 89.19 × 79.50 | window, 12.00 | 4.7170, 56.6, **8.99 mm** | 4.6792, 56.2, **8.91 mm** |
| tree | 91.06 × 102.00 | sun, 16.00 | 3.6765, 58.8, **9.34 mm** | 3.6471, 58.4, **9.26 mm** |
| boat | 111.59 × 80.52 | flag, 14.00 | 4.6574, 65.2, **10.35 mm** | 4.6202, 64.7, **10.27 mm** |

Every value is above `minPieceMm` 7.5, so s7c's size check should pass on the SE. These supersede the s7-g1
plan's §4 table (4.30–8.16 mm), which assumed the 2:1 world the owner replaced with the content-sized one.

## Tests added (8)

- `split_layout_test.dart`, group `phones layout` (4): the rules over 4 puzzles × 20 seeds (both sides the same
  world, memoised per target, tray above the crop board and inside the world, the board is the crop and centred,
  `hud` at the world's right end and `hudWidth` wide, the tray stops before it, `packTray` at the tray's width
  fits in one row and its boxes sit in the tray and out of the `hud`, world within `phoneMaxAspect`); a `phones`
  split match starts every piece where `packTray` put it, on both sides, with the same angles; the two-row tray
  on a synthetic long world; the printing test above.
- `match_test.dart`, `snapshots` (1): a one-board `phones` match plays the layout's left world and keeps the seed
  in its snapshot.
- `puzzle_module_test.dart` (1): the setup names the phones world only for a phones match; a viewer reads it, a
  missing key means the screen, `'diagonal'` throws a `FormatException` naming the key.
- `party_host/test/puzzle_screen_test.dart` (2): `shareView` true → the round's setup says `layout: 'phones'`;
  false → no `layout` key.

## Line counts

| file | lines | |
| --- | --- | --- |
| `lib/src/split_layout.dart` | 384 | touched, **flagged: over 300** (within the 400 limit) |
| `lib/src/match.dart` | 218 | touched |
| `lib/src/tray.dart` | 169 | touched, the `gap` → `trayGap` rename |
| `lib/src/puzzle_module.dart` | 136 | touched |
| `lib/src/puzzle_session.dart` | 178 | touched |
| `lib/src/play_view.dart` | 132 | touched |
| `lib/src/snapshot.dart` | 255 | touched, doc only |
| `lib/src/ui/puzzle_screen.dart` (party_host) | 195 | touched |
| `test/split_layout_test.dart` | 421 | touched, 225 before; **flagged: over 300** (test limit 500) |
| `test/match_test.dart` | 454 | touched, 435 before |
| `test/puzzle_module_test.dart` | 116 | touched |
| `test/support/match_helpers.dart` | 140 | touched |
| `test/puzzle_screen_test.dart` (party_host) | 108 | touched |

No lib file I touched is over 400 and no test file is over 500.

## Test counts

| check | before | after |
| --- | --- | --- |
| puzzle | 80 (match 17, split layout 7, tray pile 4, tray packing 3, rules 24, view 7, snapshot lerp 7, session 7, module 3, frame size 1) | **86** (match 18, split layout 11, module 4, the rest unchanged) |
| host | 60 | **62** (the two `shareView` tests) |
| tv | 28 | 28 |

No existing expectation changed (the rocket has no numeric one; item 5's numbers are only in this report).
Note: s7a's report lists 57 host tests; the tree ran 60 before my two (three arrived with other jobs since).

## Checks

- `tools/check.sh format analyze puzzle host tv` — **PASS** all five: format (3s), analyze (13s), puzzle (86
  tests, 22s), host (62 tests, 22s), tv (28 tests, 18s).
- `tools/review.sh` — 2 fail, 2 note. Both fails are body lengths that pre-date this job, in the two files the
  brief has me edit: `split_layout.dart:141` `_computeScreen` 120 lines (the old `_compute`, renamed as item 1
  says) and `tray.dart:27` `packTray` 104 lines (only its `gap` became `trayGap`). Notes: `puzzle_session.dart:23`
  57 lines (a constructor) and `split_layout.dart` 384 lines (over the 300 aim). I did not split those functions:
  the brief says stop at G3 and do exactly its items (Questions 1).

## Questions

1. `review.sh`'s two func fails are pre-existing bodies in files I had to touch (`_computeScreen`, `packTray`).
   Split them in s7c (which touches both anyway) or accept them as debt?
2. Is the viewer drawing the `screen` layout for a `'phones'` setup acceptable until s7c? The target now reaches
   `ShapeRaceViewer`, but §2–§3 draw it.
3. The two-row fallback never runs for today's puzzles (their phone worlds are 0.89–1.39:1); only the synthetic
   `flatWorld` test reaches it. Is that rule meant to be dormant, or should a puzzle be shaped for it?
4. With the crop board and the content-sized world the smallest pieces are 9.0–10.4 mm on the SE — above
   `minPieceMm` 7.5. s7c should say so in its report and retire the s7-g1 plan's 4.30–8.16 mm figures.
5. `SplitLayout.margin` became public and `_dotInset`/`hud` were added for s7c's cameras and painters. Keeping
   `scale`/`leftBox`/`rightBox`/`hudStrip`/`trayBelow` as documented placeholders (the plan's Q5) rather than
   nullable is still my preference; say if you want them nullable now.

## Not sure about

- `_computePhones` puts the `hud` at the world's right end. When the crop is wider than the tray row (house,
  rocket), there is a gap between the tray and the `hud`; the test asserts `tray.right ≤ hud.left`, not equality.
- A two-row tray's height is the height of the packing at the search width; at the returned width a piece could
  un-wrap, so the tray can be a hair taller than the rules need (the test asserts ≥).
- `_twoRowTray` takes the first width (in 1-unit steps from the widest box) that gives two rows, not the
  narrowest by height; all its inputs in the tests are synthetic.
- The working tree was already dirty when I started (`docs/briefs/m12/STATUS.md`, `docs/design/m12-phone-layout.md`
  and three `tv_test_app/windows/...` generated files); I did not touch them.

## The s7c plan (contract §2–§5)

1. `PuzzleCamera` (`whole` | `side(left|right)`) with a pure `PuzzleCamera.scale(SplitLayout, PuzzleCamera, Size)`
   returning px per world unit; `camera_test.dart` pins it: on 667×375 the `side` camera gives house 4.2373,
   rocket 4.7170, tree 3.6765, boat 4.6574 (bottom-aligned), and `screen` stays today's `fieldIn` (4.167).
2. `whole` for a `phones` match: the two worlds side by side above 3:1, else stacked with the left on top; each
   side keeps its own `hud`. `whole` for `screen` is today's picture.
3. Painters: `PuzzlePainter`/`MatchPainter` take the target and camera; on phones they draw the crop board with
   the tray at 0.75 and the `hud`: clock, this side's count, the other's ("Right 3/6"), the time bar.
4. The viewer picks `side` for the side `ViewContext.playerId` plays on, `whole` otherwise, when `wholeMatch` is
   set, or for a `screen` match; `view_test.dart` and `puzzle_module_test.dart` at 667×375 and 852×393.
5. `party_host`: `ownPlayerIdProvider` (default null) and the host phone's own side; the TV keeps null.
6. `arena_view_test.dart` at 667×375 and 852×393: no overflow.
7. `controller_app/test/puzzle_size_test.dart`: every puzzle, `phones` target, `side` camera, every non-tablet
   phone box as a full safe area, smallest piece in mm; Easy/Medium under 7.5 fail, Hard prints; the table goes
   in the s7c report (the numbers are in §6 above and already pass).
8. `tools/check.sh format analyze puzzle host tv controller` and `tools/review.sh`; the two func fails above if
   not accepted.

## Commit message

```
feat(puzzle): lay out the phones world and name it in the setup

SplitLayout takes a LayoutTarget: phones sizes each side to its
content (tray row with a 40-unit clock area on top, the crop below,
two-row tray past 2.2:1). PuzzleMatch takes the target for every
format, and a one-board phones match keeps its seed in the snapshot.
The setup names the world only when it is the phones' and a bad value
throws naming the key; the host picks phones when it shares its view.
rocket's window grows from radius 4 to 6.
```

## Status row

| 7 Puzzle on phones | s7b G3 done ([s7b-g3-report.md](s7b-g3-report.md)): the `phones` world in `SplitLayout` (content-sized, tray row + 40-unit HUD, crop board centred, 2.2:1 two-row fallback, memo per target), `PuzzleMatch`'s target, the setup's `layout` key with its `FormatException`, `party_host` picking `phones` when `shareView` (86 puzzle + 62 host tests, 8 new), rocket window 4→6. Smallest pieces 9.0–10.4 mm on the SE, above 7.5. Open: s7c — cameras, painters, the viewer's side/whole choice, `ownPlayerIdProvider`, the Arena at 667×375, the size check; and the two pre-existing `review.sh` func fails (`_computeScreen`, `packTray`) |

## Delete

- none
