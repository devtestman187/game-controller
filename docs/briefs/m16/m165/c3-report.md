# m165 c3 report: connection chip icon-only below a room threshold (B-044)

## Summary

- The connection chip in `BarConnection` now shows the dot alone when its room is under `iconOnlyChipBelowDp` (170 dp). The dot-only chip keeps the same `ActionChip` (key `connectionChip`, `ConnectionDot` avatar, `openConnect`), has no label padding, and sits in a `Tooltip` whose message is the label text.
- The chip's box is at least 48 x 48 dp (`BoxConstraints` minWidth and minHeight `minTouchTargetDp`) in both forms. At or above the threshold the chip is unchanged.
- Tests: three skips are removed (568x320 menu in chip_readable, 667x375 TV in chip_readable, 667x375 TV in connection_chip_test). Two stay skipped with their measures: 568x320 TV in chip_readable and connection_chip_test, and 568x320 TV pad in touch_targets_test.
- One new test in chip_readable_test: the dot-only chip's tooltip at 568x320 menu equals the label the full chip shows at 700x400 menu.
- The label check in chip_readable_test and connection_chip_test accepts a chip with no label Text when a Tooltip stands in for it.
- Test counts seen: `tools/mine.sh` OK on the final code (format, analyze with fatal infos, the touched tests; no count printed). `flutter test` on the seven named files: 76 passed, 0 failed (`+76: All tests passed!`).
- Lib file `bar_connection.dart` ends at 274 lines (under 380).

## Decisions

- **Threshold 170 dp.** Measured on the base: the menu chip at 568x320 has 149.9 dp and its label is cut; the TV chip at 667x375 has 134.9 dp and is cut; the existing comment says the menu look's whole name needs about 195 dp. 170 sits between cut and whole. It is a named const, not a TextPainter measure (the brief allowed either). A text-scale change would not move it.
- **Tooltip text = the chip's own text at its layout.** The tooltip uses the same host-only flag as the label would, so the tooltip equals what the full chip shows at that layout. First try used the ping form; the new test caught it (at 700x400 the full chip shows only "Android TV", the tooltip read "Android TV · 9 ms"). Fixed by passing `hostOnly` through.
- **Minimum box in both forms.** `ConstrainedBox` now sets `minHeight` too. The full chip's measured height was already 48, so this adds no change at 48.
- **Room comes from the chip's own `LayoutBuilder`** inside the `Flexible`, so it is the room the chip is given, not the bar's width.
- **568x320 TV pad and chip stay skipped.** Their room is 35.9 dp, below the 48 dp dot-only chip, so the row cannot fit it. The brief says not to change the badge or the row; not changed.

## Files changed

- `controller_app/lib/src/ui/bar_connection.dart`: new const `iconOnlyChipBelowDp`; `_chip` now wraps the chip in a `LayoutBuilder` and shows the dot alone below the threshold with a tooltip; new static `_chipText` gives the label text the chip shows (host name, host with ping, demo or tap-to-connect prompt).
- `controller_app/test/chip_readable_test.dart`: `_skipped` keeps only 568x320 TV (with its 35.9x48 measure); the label check accepts a dot-only chip with a tooltip; new test for the tooltip equal to the 700x400 label.
- `controller_app/test/connection_chip_test.dart`: the 667x375 TV skip is removed; the label check accepts a dot-only chip; the 568x320 TV skip and its measure stay.
- `controller_app/test/touch_targets_test.dart`: comment only on the 568x320 TV pad skip, which stays (room 35.9 dp).
- `docs/briefs/m16/m165/c3-report.md`: this report.

No other file was changed. The other named test files (joined_view, pad_badge, phone_look, waiting_card, connect_screen, paired_launch_consent, connect_narrow) needed no edit: all 76 tests in them passed, including pad_badge's chip-height check.

## Self-check (review-rules part A)

1. Host setups: covered only the joined phone (paired, connected, in the chip tests). TV host, "Play on this phone", "Show on this device" and the older peer are not covered by this job.
2. Kept state: none added. The chip has no state of its own; the tooltip is built from the client snapshot each build.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: not covered. The chip is built the same way in each, but not run there.
4. Files: only the allow list; see above.
5. Stopped rather than overstepped: the 568x320 TV chip and pad stay skipped, and the badge and row are untouched.
6. Every look: menu and TV at 568x320 and 667x375 in chip_readable_test; the connection chip test at 667x375 menu and TV; touch_targets_test at 568x320 (menu and TV, the pad) and the other target sizes.

## Measured values

| Case | Before (base) | After this change |
|---|---|---|
| 568x320 menu chip | 149.9x48, "Android TV" cut | dot-only, 48 dp square, tooltip "Android TV" (test passes) |
| 568x320 TV chip | 35.9x48 | not re-measured (the case stays skipped); the room is still 35.9 dp |
| 667x375 TV chip | 134.9x48, "Android TV" cut | dot-only (test passes; the skip is removed) |
| 667x375 menu chip | passes | passes; the label check now accepts a dot-only chip, so this run does not prove the label stayed whole |
| 700x400 menu full chip label | "Android TV" (host only) | unchanged; the tooltip test compares to it and passes |

## Open

- **568x320 TV, chip_readable and connection_chip_test**: the chip's room is 35.9 dp, below the dot-only chip's 48 dp. Stays skipped with its measure. Needs a badge or row change, which this job does not allow.
- **568x320 TV pad, touch_targets_test** (`skip: screen == TargetScreen.pad && tv && entry.key == '568x320'`): same cause. Stays skipped.
- **667x375 menu label**: not asserted to stay whole after the change. The threshold 170 assumes the menu room there is at least 170 dp (the existing comment says about 195). Not measured.

## Hand-over

- A device or screenshot check of the menu look at 667x375 would confirm the label is still whole there. Not run here: no devices.
- Question: is 170 dp the right threshold, or should the chip measure the label with a TextPainter so it follows text scale?
- Question: should the 568x320 TV row case get its own job (badge or row change)?

## Commit message

m165 c3: connection chip goes icon-only below 170 dp room (B-044)

- BarConnection's chip shows the dot alone when its room is under
  iconOnlyChipBelowDp (170 dp), with the label in a tooltip.
- The chip is at least 48 x 48 dp in both forms.
- Un-skips the 568x320 menu and 667x375 TV chip cases.
- The 568x320 TV chip and pad stay skipped: their room is 35.9 dp,
  which the row cannot fit beside the badge.
- Tooltip shows the chip's own label at its layout.

## Status row

m165 C3 (connection chip icon-only under 170 dp, 48 dp minimum): done for the menu 568x320 and TV 667x375 cases; open: TV 568x320 chip and pad (35.9 dp room, needs a badge/row change), menu 667x375 label not asserted.

## Delete

- none
