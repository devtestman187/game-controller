# M12 step 7 s7d — G4 report: the compact top bar, the piece-size check, the emulator's code entry

Stopped at G4 as the brief says. Contract §0.7b and §5 are in, and `tools/emulator.sh connect` taps the code
box before typing.

## What was done

### 1. The compact top bar (contract §0.7b)

- `controller_app/lib/src/ui/controller_top_bar.dart` — `_TopBar.build` branches on `showsGameProvider`:
  `_GameTopBar` while a game shows, `_ControllerTopBar` (the old bar, body for body) otherwise. Both use the
  same `_barPadding` (12, 4, 8, 0) and the same `_SettingsButton`/`_DiagnosticsButton`, so the two bars' touch
  sizes can't drift.
- `_GameTopBar` is `Padding` → `Opacity(controlsSettingsProvider.opacity)` → `Row`:
  `CompactConnection`, `Spacer`, then (only when `controls`) `ModeMenuButton` and `_SettingsButton`, then
  `_DiagnosticsButton`. Nothing in the middle: no host name, no ping text, no status panel. With no pad
  ("Show on this device", C34) the mode and Settings are left out, as in the full bar.
- `controller_app/lib/src/ui/bar_connection.dart` — `CompactConnection` (the own player's `PlayerBadge` when
  there is one, a 6 px gap, the dot) and `ConnectionDot` (the chip's avatar pulled out: `Icons.circle`, 12 px,
  the same status colour; key `connectionDot`). The chip's avatar is now that same `ConnectionDot`, so the two
  can't disagree. `_statusColor` takes a `ClientStatus` instead of the chip's state.
- `controller_app/lib/src/ui/bar_modes.dart` — `ModeMenuButton`: a `MenuAnchor` over an `IconButton` keyed
  `modeMenu` (tooltip "Pad mode") that draws the mode in use and opens three `MenuItemButton`s keyed
  `pickMode-dpad` / `pickMode-gyro` / `pickMode-sticks`, labelled "D-pad" / "Gyro" / "Sticks". The menu's
  entries are enabled by the same rule as the labelled bar (the game allows the mode; gyro needs a usable
  gyro), and picking one calls the same `setMode` and shows the same refusal snackbar. The three labels,
  icons and tooltips are extracted into `_modeLabel`, `_modeIcon`, `_canPick` and `_pickMode`, shared with
  `BarModes`; controller mode's bar is unchanged in what it shows and does.

What the bar shows over a game at 852×393, from left to right: "P1" badge, dot, spacer, mode icon, Settings,
Diagnostics — all inside one `Opacity` at the saved `controlsOpacity` (0.6 in the test). The bar still takes
52 px, so the pad keeps the 341 px body (C14–C16); the mode icon measures 48×48 (the `MenuAnchor`'s
`IconButton` inside a 48-high row) against Settings'/Diagnostics' 40×40, so no target got smaller.

**The consequence to decide (Q1):** `showsGameProvider` is true for the whole host route — `HostingNotifier`
sets it at `start()`, and it is what makes the host's screens hide the TV search — so a hosted phone now draws
the compact bar over its picker, join screen and match, and `HostChip` (the pairing code, "New code", "Stop
hosting") is unreachable while hosting. I implemented §0.7b as written and changed the tests that expected the
chip (see old → new below); the pairing code still shows before hosting starts, and the system back press
still stops the host.

### 2. The size check (contract §5)

- `packages/puzzle_game/lib/src/piece_size.dart` (new): `const double minPieceMm = 8.5;`, documented with
  §0.3 — the piece's circumscribed diameter (`PieceShape.size`) on the board — including §0.3's iPhone SE
  values (house sun 9.42, rocket window 8.99, tree sun 9.34, boat flag 10.35 mm) and the lowest anywhere
  (8.53 mm, the rocket's window on the small 16:9 phone). Exported from `puzzle_game.dart`.
- `controller_app/test/puzzle_size_test.dart` (new):
  - reads the shipped files from `../packages/puzzle_game/puzzles` (the index, then each file), the same four
    puzzles the app loads;
  - for each puzzle, seed, phone screen and side (`PuzzleSide.values`), computes
    `PuzzleCamera.scale(SplitLayout.of(puzzle, seed, target: LayoutTarget.phones), PuzzleCamera.side(side),
    safeArea) × smallestPiece.diameter ÷ phonePxPerMm` (`layout.dart`, 160/25.4 = 6.2992 px/mm);
  - **safe area:** the layout table (`layout_test.dart`'s `phones` map) lists each screen by its *body*, the
    area below the top bar. A shown game fills the safe area, so the safe area is `body + 52` — the bar this
    app draws (4 px top padding + 48 px row, pinned by `joined_view_test`). The iPhone SE is the exception:
    its row's body is 300 high, under a 75 px bar (667×300 + 52 = 352 would be 23 px short of the phone's
    667×375 screen and would put the rocket's window at 8.43 mm, under §0.3's 8.99), so its safe area is the
    SE's screen, 667×375 (§0.2). The 540×250 "smallest window" row is left out: it is a split-screen case,
    not a phone screen (§5). Tablets are out by construction (they are in the table's `tablets` map).
  - **seeds:** seed 1 and 20 more, 2 to 21 (Q3), because a seed sets the tray's start angles and so the world
    the pieces are drawn in.
  - the Easy/Medium test fails with the puzzle, piece, the mm, screen, size, seed and side, e.g. `rocket
    "window": 8.43 mm on iPhone SE (667 x 352, seed 1, left side) is under 8.5 mm`; the second test prints the
    table below plus each puzzle's lowest, and "no Hard puzzle" today.

Safe areas used:

| table row | body | safe area | |
| --- | --- | --- | --- |
| iPhone SE | 667×300 | 667×375 | the phone's screen (§0.2), the row is 23 px short |
| iPhone 15 | 734×318 | 734×370 | body + 52 |
| iPhone 15 Pro Max | 814×355 | 814×407 | body + 52 |
| Pixel 7 | 869×352 | 869×404 | body + 52 |
| Galaxy S24 | 780×330 | 780×382 | body + 52 |
| small 16:9 phone | 640×304 | 640×356 | body + 52 |
| smallest window | 540×250 | — | a split-screen case, left out |

The printed table (seed 1, the side camera, left side; the right side draws the same scale). Each cell is the
smallest piece's circumscribed diameter on the board, in mm:

| puzzle | piece | iPhone SE (667 x 375) | iPhone 15 (734 x 370) | iPhone 15 Pro Max (814 x 407) | Pixel 7 (869 x 404) | Galaxy S24 (780 x 382) | small 16:9 phone (640 x 356) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| house | sun | 9.42 | 9.29 | 10.22 | 10.15 | 9.59 | 8.94 |
| rocket | window | 8.99 | 8.87 | 9.75 | 9.68 | 9.15 | 8.53 |
| tree | sun | 9.34 | 9.21 | 10.14 | 10.06 | 9.51 | 8.87 |
| boat | flag | 10.35 | 10.21 | 11.23 | 11.15 | 10.54 | 9.83 |

Lowest over all 21 seeds and six screens, where: house 8.94 mm (small 16:9 phone, seed 1), rocket 8.53 mm
(small 16:9 phone, seed 1), tree 8.87 mm (small 16:9 phone, seed 1), boat 9.76 mm (small 16:9 phone, seed 8).
No Hard puzzle: the test prints "no Hard puzzle".

The SE column matches §0.3's four values exactly, which is the check that the safe-area derivation agrees with
the contract's own arithmetic.

### 3. `tools/emulator.sh connect`

After "Enter the code" appears (and a second's sleep, kept), the script finds the first `EditText` on the
screen with the existing `find_node EditText 1` helper (the same node `tools/emulator.sh ui` lists), taps it,
waits a second, then types the code and presses Enter as before. If no `EditText` is found it dies with a
point to `tools/emulator.sh ui`. `bash -n tools/emulator.sh` passes; the rest of `connect` is unchanged.

## Tests added and changed

New (7):

- `joined_view_test` (4, in a new group "the bar over a game (m12-phone-layout §0.7b)"):
  - the full bar goes compact at 852×393 with a fake view: the badge "P1", `connectionDot`, `modeMenu`,
    Settings and Diagnostics; no `connectionChip`, no host name, no `pingStats`, no `statusPanel`; the bar's
    opacity is the saved `controlsOpacity` 0.6 for the mode icon, the badge and the dot (a `barOpacity`
    helper reads the first `Opacity` above a key);
  - the one mode icon opens D-pad/Gyro/Sticks and picking Sticks switches the pad (`leftStick` in,
    `inputSummary` gone), and back to D-pad;
  - the compact bar keeps the full bar's Settings and Diagnostics sizes, the mode icon is no smaller than
    Settings in either dimension, and `ControlsLayer` is still 852×341 (the bar is 52 px);
  - the view ends (`viewEnd(finished)`) → the full bar is back: chip, host name, "D-pad" label, no
    `modeMenu`, no `connectionDot`.
- `host_mode_test` (1): the host route gets the compact bar too — badge, dot, `modeMenu`, Settings,
  Diagnostics, no `hostChip`, no pairing code on screen.
- `puzzle_size_test` (2): the §5 check and the table's print.

## Existing expectations, old → new

| test | old | new |
| --- | --- | --- |
| `host_mode_test` "a phone hosting plays its own game…" | `hostChip` and the pairing code over the picker | `modeMenu`, Settings, Diagnostics; `hostChip` absent |
| `host_mode_test` "\"Show on this device\" shows the game alone…" | `hostChip` and the pairing code | `playerBadge`, `connectionDot`, Diagnostics; no `modeMenu`, no `hostChip` |
| `host_mode_test` "Stop hosting in the chip stops the host, and a second \"Host a game\" works" | tap `hostChip`, then `stopHosting` | renamed "a stopped host lets a second \"Host a game\" start on the same providers": a system back press stops the host; the rest (Connect screen, idle client, discovery restart, a second host) unchanged |
| `host_lifecycle_test` "hiding the app pauses the round, and showing it brings the host back" | `hostChip` found after the app is shown again | `modeMenu` found, `hostChip` absent, `hostOf` still the same host |

No other expected value changed; the size check is new and nothing else asserts piece sizes on phones.

## Test counts

| check | before | after |
| --- | --- | --- |
| format | — | PASS (no tests) |
| analyze | — | PASS (no tests) |
| puzzle | 97 | 97 (no package test added) |
| phone | 311 | **318** (+4 `joined_view_test`, +1 `host_mode_test`, +2 `puzzle_size_test`) |

Per file: `joined_view_test` 14 → 18, `host_mode_test` 7 → 8, `puzzle_size_test` 0 → 2,
`host_lifecycle_test` 5 → 5 (one expectation changed).

## Line counts

| file | lines | |
| --- | --- | --- |
| `controller_app/lib/src/ui/bar_connection.dart` | 127 | touched (93) |
| `controller_app/lib/src/ui/bar_modes.dart` | 151 | touched (88) |
| `controller_app/lib/src/ui/controller_top_bar.dart` | 105 | touched (40) |
| `packages/puzzle_game/lib/src/piece_size.dart` | 16 | new |
| `packages/puzzle_game/lib/puzzle_game.dart` | 23 | touched (export) |
| `controller_app/test/puzzle_size_test.dart` | 147 | new |
| `controller_app/test/joined_view_test.dart` | 381 | touched (276), **flagged: over the 300 aim** (under the 500 limit) |
| `controller_app/test/host_mode_test.dart` | 204 | touched (180) |
| `controller_app/test/host_lifecycle_test.dart` | 138 | touched (one assertion) |
| `tools/emulator.sh` | 196 | touched (+6) |

No lib file is over 400; no test over 500. `controller_top_bar.dart` is a part of `controller_screen.dart`
(199 lines), so the library is under 400 too.

## Checks

- `tools/check.sh format analyze puzzle phone` — **PASS** all four: format (2s), analyze (9s), puzzle (97
  tests, 18s), phone (318 tests, 21s). The first run failed one test, the `host_lifecycle_test` chip
  expectation above; changed, then green.
- `tools/review.sh` — **0 fail**, 2 notes: the numeric literal `6` (the badge-to-dot gap in
  `CompactConnection`) and the numeric literal `8.5` in `piece_size.dart` (the constant itself). Neither is a
  fail.
- `dart format` applied to the new test file; `bash -n tools/emulator.sh` passes.

Not mine, seen in `git status`: `docs/briefs/m12/STATUS.md` was already modified when the job started, and
three `tv_test_app/windows/flutter/generated_*` files carry line-ending changes. I touched neither (the
STATUS.md change is outside this job's files).

## Questions and suggestions

1. **The host chip is gone over the host's own screens (§0.7b as written).** `showsGameProvider` covers the
   whole host route, so while hosting there is no pairing code, "New code" or "Stop hosting" on this phone;
   players join with the code shown before hosting starts, and stopping is the system back press. If the code
   should stay reachable, the options are: a fourth icon in the compact bar on the host route only, or
   `showsGameProvider` not covering the host route. I did not choose either.
2. **The iPhone SE's row in the layout table is 23 px short of the phone**: its body 667×300 is under a 75 px
   bar, so body + 52 gives 352, and the size check would report 8.43 mm for the rocket's window where §0.3 says
   8.99. I used the SE's 667×375 screen for that row, which reproduces §0.3's four values exactly. If the
   table's SE row should be fixed instead, the test can drop its `rowScreens` map.
3. **Seeds:** I read "seed 1 and 20 seeds" as seeds 1 to 21 (seed 1, which the camera tests pin, plus 20 more).
   The check covers 21 seeds × 6 screens × 2 sides per puzzle; say if a different set was meant.
4. **The pad's tune buttons left the bar over a game:** in controller mode, Gyro and Sticks draw "Gyro
   settings"/"Stick settings" beside the mode (C12). The compact bar's mode menu only picks the mode; the tune
   dialogs are two taps away via Settings. Say if the tune action should be in the menu.
5. **The dot fades with the controls.** §0.7b says the bar's items draw at `controlsOpacity`; a player who
   sets the controls nearly transparent also nearly hides the link's dot. If the dot should stay opaque, it
   is one `Opacity` scope in `_GameTopBar`.
6. **The compact dot does not tap through** to Connect as the chip did (it is an `Icon`, not a button). Over a
   game a dropped link already has the waiting card and Diagnostics; say if a target is wanted.
7. **The emulator's tap** could not be tried here (starting an emulator is out of this job's scope); it uses
   the helper the script's own `ui` command uses, and the script parses.

## Commit message

Compact the top bar over a game, and check piece sizes

A phone with a game behind its controls draws the compact top bar (m12-phone-layout §0.7b): the own player's
badge and the link's dot on the left, the pad's mode as one icon whose menu holds D-pad, Gyro and Sticks
(disabled as before), Settings and Diagnostics as icons on the right, nothing in the middle, all at the
controls' opacity; the full bar returns with the last view. The host route gets it too, so the host chip is out
of reach while a game shows (the back press stops hosting; Q1). `controller_app/test/puzzle_size_test.dart`
checks §5 for every puzzle, the `phones` target, the side camera, both sides, seeds 1 to 21, on every
non-tablet phone's safe area, against the new `minPieceMm` 8.5 in puzzle_game; the lowest is 8.53 mm (the
rocket's window, small 16:9 phone, seed 1) and there is no Hard puzzle. `emulator.sh connect` taps the code
box before typing. Phone tests 311 → 318, puzzle 97.

## Status row

| 7 Puzzle on phones | s7d G4 done ([s7d-report.md](s7d-report.md)): the compact top bar over a game (§0.7b: badge and dot, one mode menu with the three modes, Settings, Diagnostics, at the controls' opacity; the host route too — the host chip is unreachable while a game shows, back stops hosting, Q1), the §5 size check (`puzzle_size_test.dart`: every Easy and Medium puzzle ≥ `minPieceMm` 8.5 mm on every non-tablet phone's safe area, both sides, seeds 1–21; lowest 8.53 mm, the rocket's window on the small 16:9 phone; no Hard puzzle) and `emulator.sh connect` tapping the code box. Phone 311 → 318, puzzle 97. Open: Q1's host chip while hosting needs the owner's word |

## Delete

- none
