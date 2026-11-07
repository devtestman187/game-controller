# M12 step 7 s7d2 — G4 report: the host's code in the compact bar, the mode menu's settings

Stopped after G4 as the brief says. Q1 (the host's code stays reachable over its own game) and Q4 (the
mode in use's settings in the mode menu) are in.

## What was done

### Q1 — the compact host chip

- `controller_app/lib/src/ui/controller_top_bar.dart` — `_TopBar` now hands `hosting` to `_GameTopBar` too.
  `_GameTopBar` draws `CompactConnection`, then (on the host route only) an 8 px gap and
  `HostChip(compact: true)`, then the `Spacer`, the mode, Settings and Diagnostics as before. The chip is
  outside `if (controls)`, so "Show on this device" (C34) has it as well: a host alone with its game must
  still show its code and stop.
- `controller_app/lib/src/ui/host_chip.dart` — `HostChip` takes `compact` (default false):
  - the `PlayerBadge` and its 6 px gap are drawn only when not compact (the compact bar draws its badge
    before the dot already), so the chip follows the dot;
  - the chip itself moved into a new private `_CodeChip`, which keeps the key `hostChip`, the avatar dot,
    the menu open/close and the shared tooltip `Hosting · <code>`; its label is the code alone when compact,
    `Hosting · <code>` otherwise;
  - in the compact bar it is wrapped in a `SizedBox(height: HostChip.compactHeight)`, and `compactHeight` is
    `kMinInteractiveDimension` (48): the bar's Settings button is 48×48 (C14), so the code's target is at
    least as high (the test below pins it).
  - the menu (`hostCode`, `hostAddress`, `newCode`, `stopHosting`) is unchanged, so the compact chip opens
    exactly today's menu.

### Q4 — the mode menu's settings

- `controller_app/lib/src/ui/bar_modes.dart` — `ModeMenuButton` adds, when the mode in use isn't D-pad, a
  `Divider` and one `MenuItemButton` keyed `tune-gyro` / `tune-sticks`: "Gyro settings" opens
  `showGyroDialog`, "Stick settings" opens `showStickDialog` — the same calls the full bar's tune buttons
  make. Picking a mode closes the menu (Flutter's `MenuItemButton`), so the tune entry appears the next time
  the menu is opened; that is the brief's wording.
- The labels are now the constants `_gyroSettingsLabel` / `_stickSettingsLabel`, used both by the full bar's
  tooltips (same text as before, so `find.byTooltip('Stick settings')` still works) and by the menu entries.

## Tests added and changed

New (2):

- `joined_view_test` — "the mode menu holds the mode in use's settings, which open the full bar's dialog":
  in D-pad the menu has no "Gyro settings"/"Stick settings"; after picking Sticks the menu has
  "Stick settings" and one `Divider`; tapping it opens the stick dialog (`stickFloating` found); "Done"
  closes it and the pad is still on the sticks (`leftStick` found).
- `host_mode_test` — back to the s6b test "Stop hosting in the chip stops the host, and a second
  \"Host a game\" works" (see below), which is a new test in this file's current count (+1).

Extended (2):

- `host_mode_test` "the host route gets the compact bar too": `hostChip` found, the code shown, the chip's
  left edge is right of the dot's right edge, and the chip's height is ≥ the Settings button's height
  (the chip is pinned to `kMinInteractiveDimension`, 48, by its `SizedBox`; Settings' `IconButton` is
  48×48 by Material 3's default) — the check passes.
- `host_mode_test` "a phone hosting plays its own game…": `hostChip` and the code over the picker.

## Existing expectations, old → new

The restored expectations are back to their s6b values (s7d's value in the middle; the brief's three chip
and stop tests, plus the `host_lifecycle_test` check that depends on the chip being there):

| test | s6b (old) | s7d (now reverted) | s7d2 (this job) |
| --- | --- | --- | --- |
| `host_mode_test` "a phone hosting plays its own game…" | `hostChip` found, the pairing code shown | `hostChip` absent, no code; `modeMenu`, Settings, Diagnostics | `hostChip` found, the code shown, **and** `modeMenu`, Settings, Diagnostics kept |
| `host_mode_test` "\"Show on this device\" shows the game alone…" | `hostChip` found, the code shown | `hostChip` absent; `playerBadge`, `connectionDot`, Diagnostics | `hostChip` found, the code shown, the s7d checks kept |
| `host_mode_test` "Stop hosting in the chip stops the host, and a second \"Host a game\" works" | tap `hostChip`, then `stopHosting` | renamed "a stopped host lets a second \"Host a game\" start…", stopped by the system back press | the old name and the chip path again: `hostChip` → `newCode` + `stopHosting` present → `stopHosting` → the rest unchanged; the back-press test kept beside it as the extra test |
| `host_lifecycle_test` "hiding the app pauses the round…" | `hostChip` found after the app is shown again | `hostChip` absent (`modeMenu` instead) | `hostChip` found again, `modeMenu` check kept |

No other expected value changed. `host_lifecycle_test` keeps its s7d `modeMenu` check (it still holds); the
whole file has no other change.

## Test counts

| check | before (s7d) | after |
| --- | --- | --- |
| format | PASS | PASS |
| analyze | PASS | PASS |
| phone | 318 | **320** (+1 `host_mode_test`, +1 `joined_view_test`) |

Per file: `host_mode_test` 8 → 9, `joined_view_test` 18 → 19, `host_lifecycle_test` 5 → 5 (one expectation
back). The `puzzle` check is untouched by this job.

## Line counts

| file | lines | |
| --- | --- | --- |
| `controller_app/lib/src/ui/controller_top_bar.dart` | 111 | touched (+6: the hosting branch) |
| `controller_app/lib/src/ui/host_chip.dart` | 110 | touched (+37: `compact`, `_CodeChip`) |
| `controller_app/lib/src/ui/bar_modes.dart` | 172 | touched (+21: the tune entry, the labels) |
| `controller_app/test/host_mode_test.dart` | 245 | touched (+41) |
| `controller_app/test/host_lifecycle_test.dart` | 138 | touched (one expectation) |
| `controller_app/test/joined_view_test.dart` | 408 | touched (+27 from s7d's 381), **flagged: over the 300 aim** (under the 500 limit) |

No lib file is over 400 (`controller_top_bar.dart` is a part of `controller_screen.dart`, 199; each part
file is counted on its own, the largest of the three being 199). No test over 500.

## Checks

- `tools/check.sh format analyze phone` — **PASS** all three: format (3s), analyze (6s), phone (320 tests,
  18s).
- `tools/review.sh` — **0 fail**, 5 notes, one of them new: the numeric literal `8` at
  `controller_top_bar.dart:48` (the gap before the chip, the same gap the full bar uses at its own
  `SizedBox(width: 8)`). The other four were there before (the badge gaps `6`, the avatar's `12`, the
  `minPieceMm` 8.5). None is a fail.
- **One flake, seen once:** the first full `phone` run failed `host_lifecycle_test` "a round hidden longer
  than the grace is abandoned" (`Found 0 widgets with type "PuzzleScreen"` after the four A presses). That
  file passed alone (`flutter test test/host_lifecycle_test.dart`, 5 tests) and two further full runs
  passed 320/320. The host widget tests start a real server on port 45780 and wait on real time while
  `flutter test` runs files in parallel, so a loaded or port-colliding run can lose a press; I did not change
  that test.
- `party_host` is still imported `as party` everywhere it was (no import changed); no lib file over 400.

## Questions and suggestions

1. **"The same tooltip":** the full chip had no tooltip before this job, so there was none to copy. I gave
   both chips one shared string, `Hosting · <code>`, in `_CodeChip` — the compact chip's tooltip says what
   the full chip's label says. The side effect is that the full chip now has a tooltip repeating its own
   label. If you meant "no tooltip either", it is one line.
2. **The compact chip is a 48-high pill.** The brief's touch-size test (no smaller than Settings) made the
   chip's render height 48 (`SizedBox(height: kMinInteractiveDimension)`), so it is taller than the full
   bar's 32-high chip. If the look should stay a small pill with a transparent 48-high hit area instead,
   that is a wrapper change; I did not do it because the target would then be invisible.
3. **The mode menu's tune entry is one tap further than the full bar's**, since choosing a mode closes the
   menu: a player who has just switched to Sticks must open the menu again for "Stick settings". That
   matches the brief's wording; say if it should instead stay open after a mode pick.
4. **`tune-gyro` / `tune-sticks` keys** are new and only the Sticks one is asserted (through its text) in
   the tests; the D-pad case is asserted as "no settings entry". I did not test the Gyro entry's dialog,
   since the fake phone has no usable gyro and gyro mode can't be switched on in that test.
5. Suggestions, not acted on: `joined_view_test` is 408 lines (over the 300 aim and growing with every
   compact-bar change) — the three `§0.7b` tests could move to a `top_bar_test.dart` of their own. And the
   compact bar's 8 px gap is a bare number like the bar's existing ones; a spacing constant would clear the
   `review.sh` note.

## Commit message

Keep the host's code in the compact bar, and tune from its menu

Over its own game a hosting phone keeps the code to join it: the compact bar
draws the pairing code alone right after the link's dot, at the bar's 48-high
touch size, opening the full chip's menu (New code, Stop hosting), so a host
can share the code and stop without leaving its game (§0.7b; s7d2 Q1). The
mode menu adds a divider and the mode in use's settings (s7d2 Q4): "Gyro
settings" or "Stick settings", opening the full bar's tune dialogs; D-pad
adds none. The chip expectations go back to their s6b values, the back press
stays as an extra test. Phone 318 → 320; host_mode 8 → 9, joined_view 18 → 19.

## Status row

| 7 Puzzle on phones | s7d G4 done (compact bar §0.7b, the §5 size check, `emulator.sh connect`), s7d2 G4 done ([s7d2-report.md](s7d2-report.md)): the host's code back in the compact bar (the code alone right after the dot, at the bar's 48-high touch size, opening the same New code / Stop hosting menu) and the mode menu's divider + the mode in use's settings ("Stick settings" opens the stick dialog, D-pad adds none); the three chip expectations back to their s6b values, the back-press test kept as an extra; phone 318 → 320. Open: the emulator and device checks (Claude's / the owner's) |

## Delete

- none
