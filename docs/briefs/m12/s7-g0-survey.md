# M12 step 7 G0 survey — the puzzle and the Arena on phones

Read-only survey; the only file changed is this report. Facts read from the code unless marked **unsure**.
Shorthand: `SL` = `packages/puzzle_game/lib/src/split_layout.dart`, `V` = `.../src/view.dart`, `P` = `.../src/puzzle.dart`,
`G` = `.../src/game.dart`.

## Answers

**1. `SplitLayout`.** Private ctor `SL:12-21`; the only way in is `SplitLayout.of(puzzle, seed)` `SL:81-88` (memoised per `Puzzle` object and seed, 8 kept, `SL:77-90`), which calls `_compute(puzzle, seed)` `SL:92-211`. Inputs: a `Puzzle` and an `int seed`, nothing else. Outputs: `left`/`right` `PuzzleField` `SL:24-27` (each a whole side's world: `size`, `board`, `tray`, `origin`, `top`, `startX`, `trayOverlap`, `trayScale`, `P:23-65`), the shared start `angles` `SL:31`, `leftBox`/`rightBox` (where each world is drawn, in the 160×90 field's units) `SL:34-38`, `hudStrip` `SL:42`, `trayBelow` `SL:45`, `scale` (screen units per world unit) `SL:49`. It packs two trays (`compactStartAngles` flat/not, `SL:96-97`), tries tray widths from widest+4 to 120 in 1-unit steps for both arrangements (`SL:111-143`), scores by `_fit` (`SL:227-231`: strip = min(80/w, 84/h), gap = min(148/2/w, 90/h)), then puts the boards together in the middle (`SL:192-206`). **No `LayoutTarget` and no layout choice exist** (grep `LayoutTarget`: 0 hits in `packages/`, `controller_app`, `tv_test_app`). The layout is chosen once, in `PuzzleMatch`'s ctor, from `format.split` alone: `match.dart:92` (`format.split ? SplitLayout.of(puzzle, seed) : null`), feeding both sides at `:103,:107`. Call chain: `party_host/lib/src/ui/puzzle_screen.dart:155` (`PuzzlePlayView`) → `play_view.dart:80-88` → `puzzle_session.dart:59-67` → `match.dart:92`. There is no `GameSetup` type; the puzzle's setup is a plain map from `shapeRaceSetup` (`puzzle_module.dart:12-17`: `puzzle`, `level`, `timeLimitS`, `teams`) sent as `ViewStartMessage.setup` (`game_session.dart:24-38`; `packages/protocol/lib/src/view.dart:20-22`). No layout key anywhere in it.

**2. World vs screen.** Positions are each side's **world (field) units**, never pixels: `PuzzleGame.speed` is 48 field units a second (`G:158`), `PieceRuntime.pos`/`PuzzlePlayer.pos` (`G:55,81`), and the snapshot keeps those units (`PieceView.x/y` `snapshot.dart:8-31`, encoded ×10 at `:106`/`:194`). `MatchSnapshot` is boards + `seed` only (`snapshot.dart:206-216`); nothing in either snapshot depends on a screen size. World → screen is one chain of transforms: `fieldIn(box)` fits the 160×90 field into the widget box (`V:54-58`), `PuzzlePainter.paint` translates/scales by it (`V:205-212`), and `MatchPainter.paint` does that, then each side by `leftBox`/`rightBox` (`V:79-96`). So a piece's px = shape units × `layout.scale` × `fieldIn.scale` (× `trayScale` in the tray). The Arena is the same idea: snapshot positions are fractions of the field and sizes fractions of its shorter side (`arena_snapshot.dart:5-20`, `arena_painter.dart:20-23`, `arena.dart:184-185,261`); the host's rules do resize with the box (`ArenaSession.resize` → `arena.dart:302`), but the snapshot carries no size.

**3. The tray.** Today the tray is **beside** the board at the outer edge, or **below** it — never on top: `trayBelow` `SL:45`, world candidates `SL:111-143`, `panels()` `SL:149-171`, one-board tray `P.trayRect` at x=102 of 160 (`P:14,58-65`). Pieces are packed by `packTray` (`tray.dart:16-126`): rows from the left at a given tray *width*, tallest box first, 2-unit gaps, rows overlapping 0.5 of a box, stopping when a box would pass width−2; it returns positions, layer order and the **height used**. The rules pack again at start time with the same function and the tray's width (`G:225-262`, overflow = packed height − tray height `:247`). Drawing only uses `field.tray` as a rect (`V:241-247`). A top-edge tray would touch: the world candidates and `_fit` scoring (`SL:111-143,227-231`), `panels()` (`SL:149-171`), `packTray` and `_trayLayout` (a fixed height, not a fixed width: `tray.dart:16`, `G:225-262`), `PuzzleField` incl. `single` (`P:19-66`), `startX`/`top` and the dot start (`P:44-47`, `G:282-286`).

**4. The puzzle viewer.** `ShapeRaceViewer.build` ignores its `ViewContext` completely (no `roster`, no `playerId`) and returns `MatchView` (`puzzle_module.dart:77-85`); `MatchView` picks `MatchPainter` for a split snapshot (`V:43-49`), which draws **both** sides through `fieldIn` — the whole TV screen letterboxed into the phone's box. On a 852×393 box that is a 4.367 px/unit fit and 76.7 px bars each side (computed). There is **no camera, zoom or viewport concept** anywhere (grep `camera|zoom|viewport` in `packages/`, `controller_app/lib`: 0). `ViewContext` is `(roster, playerId)` (`game_module.dart:44`); `FrameView` makes it from the frame's roster and its own `playerId` (`frame_view.dart:216`).

**5. Clock and the other side's progress.** Drawn by `MatchPainter._stripHud` `V:114-154`: divider `:125-131`, `'LEFT  x/total'` `:132-138`, the clock at the middle `:139` (from `left.timeLeftMs` `:98-99`), `'RIGHT  x/total'` `:140-146`, the bar under the clock `:147-153` (`_stripBar` 40 `:75`). `_gapHud` `V:158-178` does the stacked variant (`'L x/total'` `:169`, `'R x/total'` `:170`, `_gapBar` 10 `:76`). The one-board HUD is `V:391-411`. Data needed: each board's `timeLeftMs`, `warning`, `phase`, `placed` (`snapshot.dart:69-87`), `puzzle.pieces.length` for the total, and `timeLimitS` from the setup for the bar (`puzzle_module.dart:37,71`). No roster or name is involved.

**6. Piece sizes.** A piece's size is its shape in **board units** (`PieceShape` `P:79-197`; its own `size` is the circumscribed diameter, 2×radius, `P:109-110`); board units are field units 1:1 (board 80×72, `P:12-14`, `targetAt` `P:268`). On screen: × `SplitLayout.scale` (`SL:196-206`) × `fieldIn.scale` (`V:55`), and × 0.75 while in the tray (`SL:72`, drawn `V:300`, reach `G:499-506`). Piece **count** does not set the size; the widest piece sets the minimum tray width (`SL:113`) and the count adds tray rows, which sets the world's shape. **No test measures a piece in mm** (grep `minPieceMm`, `mm` in `puzzle_game`: 0); the closest is `match_test.dart:690-727` (0.75 pickup reach). There is **no M7 device table in `docs/`**: the screen table is `controller_app/test/layout_test.dart:9-34` (typedef `Screen` = body points + px/mm + tablet), named in `docs/checklists/m7.md:51` as the 15 screens. Smallest phone there: **`iPhone SE`, body 667×300 pt** (`:15`), whole screen 667×375 (`settings_test.dart:93`); the also-supported `smallest window` is 540×250 (`:21`, `minBodySize` `controller_app/lib/src/layout.dart:43`). px per mm: `phonePxPerMm = 160/25.4 = 6.299` (`layout.dart:18`; no DPI is stated). So SE = 105.9×47.6 mm body, and **9 mm = 56.7 px**. Computed, today's whole-field split on a 667×375 SE (4.167 px/unit): house's sun (14 units) = 14 × ≥0.85 × 4.167 = **49.6 px = 7.9 mm** at the test's minimum scale (`match_test.dart:469`); 58.3 px = 9.3 mm at scale 1.0.

**7. The puzzle files.** `packages/puzzle_game/puzzles/*.json` (4 + `index.json` listing ids `house, rocket, tree, boat`). Format is `Puzzle.fromJson` `P:270-296`: `id`, `name`, `level` (`easy|medium|hard` `P:68-76`), `pieces[]` of `{id, kind?, shape, color "#RRGGBB", at [x, y] (board units), angle?, rotated?, big?}`; shapes are `{"circle": r}`, `{"rect": [w, h]}`, `{"regular": [sides, r]}`, `{"polygon": [[x, y], …]}` (`P:172-196`). Levels today: **house, rocket, tree easy; boat medium; no Hard puzzle exists**. Pieces: house 4, rocket 5, tree 4, boat 6. A test loads them all two ways: `File('puzzles/index.json')` then each `puzzles/<id>.json` (`view_test.dart:13`, `puzzle_module_test.dart:11`), or through the asset mock + `PuzzleLibrary.load()` (`puzzle_module_test.dart:22-30`, `library.dart:15-23`).

**8. The Arena on a phone.** `ArenaViewer.build` → `ArenaBoard(snapshot, roster: view.roster)` (`arena_module.dart:38-43`); `ArenaBoard` is `Column[ArenaHud, Expanded(ArenaField)]` (`arena_view_widgets.dart:24-32`); `ArenaField` is `LayoutBuilder` + `ClipRect` + `CustomPaint` (`:44-61`, painter `arena_painter.dart`). `ArenaPainter` maps fractions onto the box and sizes as fractions of `shortestSide` (`arena_painter.dart:20-23`): **no aspect ratio and no letterbox** — it stretches to any box (960×540 today, 500×700 at `arena_view_test.dart:92`). The HUD is a `Column` of `Wrap`s with fixed 16/8 padding and `titleMedium`/`displaySmall` text (`arena_view_widgets.dart:86-119,177-201`), so it keeps a fixed height share on a phone. A viewer passes no `onResize` (`:21`, `arena_module.dart:42`), so the rules never see the phone's box.

**9. Tablet vs phone.** Only in `controller_app`: `isTabletScreen(screen)` = shortest side ≥ 600 and `pxPerMmFor(isIOS, isTablet)` (`layout.dart:23-26`), `isTabletProvider` from the display (`providers/device.dart:24-28`), `pxPerMmProvider` (`:31-33`). In the packages: nothing measures a device (grep: 0); only labels — `HostType.phone/tablet` (`metrics/lib/src/session.dart:9-16`) and `HostKind.phone/tablet` for the TXT record (`party_host/lib/src/host_identity.dart:2-7`). `ViewContext` has no px/mm, and guidelines §6 forbids `MediaQuery` in games.

**10. Tests that pin the puzzle layout.** `puzzle_game/test/match_test.dart` (31 declarations, 1074 lines): group `split layout` `:325-540` — `scale > 0.571` and ≥ 0.6 `:333-334`, ≥ 0.85 for every seed `:469`, memoised and keyed per puzzle `:335,339-352,470`, `leftBox.right == 79` / `rightBox.left == 81` and a 2-unit gap `:429-431`, the gap variant 74/86 and 12 `:434-436`, box top ≥ strip 6 `:427-428`, box aspect = world and width = world×scale `:412-421`, boxes apart `:423`; tray below or at the outer edges `:442-462`; pieces in the tray and outlines on the board `:183-212,355-393`; tray packing `:263-323`; tray in play at 0.75 `:684-727`; tray pile `:542-628`; compact angles `:215-261`; snapshot size/seed `:1014-` `. view_test.dart` (7): same picture at 2/3 scale `:85-102`, another box shape `:104-115`, every puzzle at 1280×720 and 960×540 `:135-147`, encode round trip `:117-133`. `puzzle_module_test.dart:33-40` builds the viewer with the `(roster: const {}, playerId: null)` literal at 960×540; `:74-89` expects `MatchView`. A second target that leaves `screen` untouched changes no expected value; changing `SplitLayout.of`'s signature touches every call (`match_test.dart` :163,187,331,335,340,360,400,444,468,470,473,474,489,510; `V:87`; `match.dart:92`) and the module test's record.

## Sizes

| File | Lines |
| --- | --- |
| `puzzle_game/lib/src/game.dart` / `view.dart` | 732 ‡ / 439 ‡ |
| `puzzle_game/lib/src/puzzle.dart` / `snapshot.dart` / `split_layout.dart` / `match.dart` | 323 ⚑ / 254 / 232 / 198 |
| `puzzle_game/lib/src/puzzle_session.dart` / `tray.dart` / `play_view.dart` / `puzzle_module.dart` / `settings.dart` / `library.dart` | 176 / 165 / 125 / 112 / 97 / 37 |
| `puzzle_game/test`: `match_test` / `view_test` / `snapshot_lerp_test` / `puzzle_module_test` / `frame_size_test` | 1074 ‡ / 275 / 127 / 90 / 53 |
| `test_game/lib/src`: `arena_snapshot` / `arena_view_widgets` / `arena_painter` / `arena_session` / `arena_view` / `arena_module` | 276 / 201 / 141 / 132 / 82 / 44 |
| `game_kit/lib/src`: `game_session` / `frame_view` / `game_module` | 288 / 219 / 44 |
| `party_host/lib/src/ui`: `puzzle_screen` / `puzzle_screen_widgets` | 187 / 167 |
| `controller_app/lib/src/layout.dart` / `test/layout_test.dart` / `providers/device.dart` | 386 ⚑ / 260 / 79 |

⚑ over 300, ‡ over the 400 hard limit (500 for tests).

## Constraints

- **Exported API**: `puzzle_game.dart:9-22` exports every `src/` file — `SplitLayout`, `PuzzleField`, `MatchView`, `MatchPainter`, `PuzzlePainter`, `packTray`, `PuzzleMatch`, both snapshots — and `party_host`/`controller_app` use them; there is no `src/` hiding here.
- **Wire**: `ViewStartMessage.setup` is a free map validated by the viewer (`puzzle_module.dart:53-59`), documented only as "the module's setup JSON" (`docs/protocol.md:232`); snapshot versions stay 1 (`snapshot.dart:63,209`). Snapshot budget: under 2 KB per board (`snapshot.dart:66`), 4-player frame under 2.5 KB (`frame_size_test.dart:12-52`); step 3 measured 596 bytes.
- **Persisted**: `PuzzleSettings` JSON keys (`settings.dart:57-96`) have no layout key; `HostingSettings` has only `frameRateHz` and `maxPlayoutFrames` (`hosting_settings.dart:12-64`); `hostGraceS` lives as `HostPresence.graceS` (`party_host/lib/src/host_presence.dart:24,34`); `minPieceMm` exists nowhere.
- **Tests that pin behaviour**: the 31+7+3 puzzle tests above, `arena_view_test.dart` at 960×540, `controller_app`'s 105 layout cases, `puzzle_module_test.dart`'s `ViewContext` literal. No golden files (`matchesGoldenFile`: 0 hits).

## Conflicts

1. §2.8's 9 mm check needs px-per-mm, and no package has it: `ViewContext` is roster + playerId (`game_module.dart:44`), games may not read `MediaQuery` (§6), and the only px/mm is `controller_app`'s (`layout.dart:18-26`), which a game may not import.
2. Q4's "reports Hard's smallest piece" has nothing to report: no puzzle file is Hard (3 easy, 1 medium).
3. "9 mm across" is ambiguous for this geometry: the smallest piece *dimension* is the boat's mast at 3 units (waves 4); 9 mm there needs ≈18.9 px/unit on an SE, where the whole 90-unit field is 375 px (4.17 px/unit). By circumscribed diameter (`P:109`) the mast is ≈30 units and the sun 14.
4. PRD:224 "a solo player sees the whole board" and :225 "the tray along the top edge" vs D4's `phones` = "per side: board in the middle, tray along the top edge": a solo match has one side and `PuzzleField.single` (board at x=16, tray at x=102, `P:58-65`), not a split world; the design doesn't say what a solo phone screen is.
5. §2.8 says every screen shares the layout, but nothing carries it: the layout is `SplitLayout.of(puzzle, seed)` only (`SL:81`, `V:87`, `match.dart:92`), and `shapeRaceSetup` has no layout key — host rules and viewers would each pick their own.
6. PRD:229 "a tablet shows the full split screen" vs Q3 "tray-on-top for every viewer, tablets included" only agree if the device chooses a *camera* over a world; the design never separates the two, and no camera exists.
7. §4 lists `minPieceMm` and `hostGraceS` as `HostingSettings` fields; only `simStepS` (`hosting_settings.dart:41`) and its own two settings are there.
8. A joined phone can only draw through `FrameView`, and no app builds one yet (grep in `controller_app/lib`, `party_host/lib`: 0); step 6 wires it, so step 7's viewer can't be seen end to end before that.
9. Tray items are drawn and picked up at `trayScale` 0.75 (`SL:72`, `V:300`, `G:499-506`) — 25% under any 9 mm measure — and the design doesn't say whether the minimum covers them.

## Questions

1. Which measure is "9 mm across": circumscribed diameter (`PieceShape.size`), the box's shorter side, or its longer side?
2. Do tray pieces count at 0.75, or only full-size pieces?
3. Which screen is "the smallest supported phone": the SE body 667×300, the SE screen 667×375, or the supported `smallest window` 540×250?
4. Where does the check (and any viewer-side sizing) get px-per-mm: a new `ViewContext` field, a constant in `puzzle_game`, or a number passed by `controller_app`'s test?
5. On a phone solo match, is the tray on top and is the board the 160×90 field or a crop of it?
6. Where does the layout target travel — `view_start`'s setup, the match, or the snapshot (which is version 1 and size-capped)?
7. With `phones`, does a tablet show both sides (a camera choice) while sharing the same world, and who makes that choice — the host's setup or the device?
8. How does a phone decide "tablet" for C34: `isTabletScreen` in `controller_app` (≤600 dp of the display) or `HostType`/`HostKind`, which name the host?

## Commit message

```
docs(m12): survey the puzzle and Arena layouts for step 7

Survey of the code before step 7's contract: how SplitLayout works and
where it is chosen, world vs screen units, the tray's side/bottom
placement, the viewer's whole-screen draw, the HUD's clock and counts,
piece sizing in mm, the puzzle files, the Arena's stretch fit, and how
phones and tablets are told apart. Lists the tests that pin the layout,
the files and their sizes, and the places the design does not fit the
code: no px-per-mm in packages, no Hard puzzle, no layout in the setup.
```

## Status row

| 7 Puzzle on phones | G0 survey done ([s7-g0-survey.md](s7-g0-survey.md)): no `LayoutTarget`, layout fixed by seed in `puzzle_game`; tray is beside/below; viewer draws the whole screen; no camera; no px-per-mm in packages; no Hard puzzle. Open: Claude's contract |

## Delete

- none
