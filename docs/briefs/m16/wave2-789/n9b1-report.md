## Summary

- New `controller_app/test/touch_targets_test.dart`: 21 measuring tests (pad, Connect, Settings × 568x320, 640x360, 375x667, 320x640 × menu and TV look, minus 568x320 TV) plus one test that every `knownBelow48` entry is still below 48 dp. `tools/mine.sh`: OK, 22 tests.
- Measured: IconButton, ButtonStyleButton (also the mode control's segments), ToyButton, Switch, Slider, DropdownButton, PopupMenuButton, chips, ListTile, bare InkWell. An InkWell inside one of those is not counted again. Settings is scrolled to its end in 200 dp drags so its lazy rows are measured. The pad is paired and has emitted `connected`, because an unlinked pad has no mode control.
- Offenders found: one (below).

| Screen | Widget | Size found | Definition |
|---|---|---|---|
| pad | `ActionChip` key `connectionChip` | 47x48 at 568x320 menu look; 26x49 at 640x360 TV look | lib/src/ui/bar_connection.dart:35 |

The chip shrinks to what the bar leaves it (`Flexible` in an `Expanded` row, controller_top_bar.dart:92). The cause is the bar's width, not the chip's own padding.

- Not offenders at the sizes tried: the mode control's segments, Settings, Diagnostics, ToyButtons, sliders. Each measures at least 48 dp because Material pads the tap target. The "40 dp compact" mode control in the brief measures 48 here. I did not print each segment's size separately.
- Decisions:
  - 568x320 in the TV look is left out for Connect and Settings too, not only the pad. The same 12 px top-bar overflow shows there (Connect and Settings were run and overflowed, as did the pad). There is a comment and no skip flag.
  - The portrait pad (375x667, 320x640) finds no control (zero targets, a measured result). Only that case may find none.
  - Settings opens through Connect's "Settings" button, because the portrait pad has no Settings button.
  - `knownBelow48` values are the smallest size seen. Only the key is compared.
- Not verified: whether `ActionChip`'s hit area is the padded 48 high box. I treated its box as the hit area, per the brief.

## Self-check

1. Hosts: only the unpaired phone and the paired, connected phone are covered; no host or joined phone (not in the brief).
2. No kept state. 3. Pause menu, host away and the like: not in scope.
4. Only the allowed files changed. Two scratch files of mine, `tt.log` and `tt_backup.dart`, remain in the repo root; `rm` was denied. `tt_backup.dart` is emptied.
5. No stop needed.
6. Every look: menu and TV, in every test.

## Hand-over

n9b2: fix the chip (bar_connection.dart:35, or the bar width at 568x320 menu / 640x360 TV) and remove the `knownBelow48` entry. The test then fails until the entry is removed.

## Commit message

Add 48 dp touch-target measuring test for controller_app

Measures the hit area of every tappable on the pad, Connect and
Settings at four phone sizes in the menu and TV looks.
Records today's offender (the connected pad's connection chip) in
knownBelow48; the test fails once it is fixed and the entry stays.
568x320 in the TV look is left out (known 12 px bar overflow).

## Status row

n9b1 done: 48 dp measuring test (touch_targets_test.dart) lands with one known offender, the pad's connection chip; open: n9b2 fixes it and empties knownBelow48.

## Delete

- none
