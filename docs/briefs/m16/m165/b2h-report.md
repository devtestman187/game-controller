# m165 b2h report: connection chip readable at 568x320 and 667x375

## Summary

- New `controller_app/test/chip_readable_test.dart`: 568x320 and 667x375, menu and TV looks, paired and connected. Checks the chip exists, lies inside the screen, is at least 48 dp square, no layout error is thrown, and the label is not cut.
- Removed the four skips the brief names: `knownTopBarOverflow` (connect_narrow), the `if (tv) return` label skip and the 568 TV skip (connection_chip), the 568 TV `continue` (touch_targets). The brief's title says three; its list names four, so I removed four.
- Six test cases fail on the code as it is, covering four chip findings. They are marked `skip` (per the stop rule), and the measures are below under Open. No lib code was touched.
- `tools/mine.sh` is green after the skips: format 4 files, analyze controller_app, tests OK.

## Files changed

- `controller_app/test/chip_readable_test.dart` (new): the readable check at both sizes and both looks; skips the three failing cases (568 menu, 568 TV, 667 TV) with a `_skipped` map that holds the measures.
- `controller_app/test/connect_narrow_test.dart`: removed `knownTopBarOverflow`; every overflow is now recorded.
- `controller_app/test/connection_chip_test.dart`: removed the `if (tv) return` label skip and the 568 TV skip; the 667 TV label case and the 568 TV size case are now `skip:` with the measures in a comment.
- `controller_app/test/touch_targets_test.dart`: removed the 568 TV `continue`; the pad at 568 TV case is `skip:` with its measure in a comment.

## Measured values (from `flutter test` runs, before the skips)

| Case | Chip rect | Size | Result |
|---|---|---|---|
| 568x320 menu | Rect.fromLTRB(12.0, 4.0, 161.9, 52.0) | 149.9x48 | label "Android TV" cut (didExceedMaxLines true) |
| 568x320 TV | Size(35.9, 48.0) | 35.9x48 | below 48 dp wide; label not reached |
| 667x375 TV | Rect.fromLTRB(12.0, 4.0, 146.9, 52.0) | 134.9x48 | label "Android TV" cut |
| 667x375 menu | — | — | passes |
| 568x320 menu, size only | — | 149.9x48 | passes |
| touch_targets pad 568x320 TV | ActionChip connectionChip | 35.9x48 | below 48 dp (the only unlisted target) |

No layout error was thrown at 568x320 TV or 667x375 TV: the `takeException` check ran before the size checks and passed.

## Self-check (review-rules part A)

1. Host setups: covered only the joined phone (paired and connected). TV host, "Play on this phone", "Show on this device", and the older peer are not covered by this job.
2. Kept state: none added; tests only.
3. Combinations with the pause menu, away states, Get ready, dropped link, results, leaving: not covered.
4. Files: only the allow list.
5. Stopped rather than overstep: the four failing cases are skipped and listed under Open; no lib change.
6. Every look: menu and TV, both sizes, in the new file.

## Decisions

- `flutter_test` here takes `skip` as a bool, not a string. The brief's `skip: 'B-044 control: ...'` form does not compile, so the measures sit in comments next to each `skip:` (and in the `_skipped` map keys).
- A skip skips the whole case. The 667 TV connection_chip case skips its size check too, which passed; the 568 TV case in chip_readable skips its label check, which was never reached.
- Flagged by the brief: its line numbers were stale, so I edited by content.

## Open

1. 568x320 TV: the connected chip is 35.9 dp wide, under 48 dp. Its label is not measured. Not redesigned.
2. 568x320 menu: the label "Android TV" is cut in a 149.9 dp chip. Only the new file checks the label at 568; connection_chip_test never did.
3. 667x375 TV: the label "Android TV" is cut in a 134.9 dp chip (the bar is narrower in the TV look; BarModes is outside this job).
4. touch_targets pad 568x320 TV: the same chip (ActionChip connectionChip, 35.9x48) is the only target below 48 dp there.

## Questions

1. Owner: is a fix for the chip size and label at 568 and 667 TV in scope for the next job? The skips should be removed when it lands.
2. Should the menu look's 568 label be wrapped, ellipsized with a tooltip, or given a wider chip?
3. Should the brief's "three skips" be corrected in the milestone notes (four were removed)?

## Suggestions

- When a case is fixed, remove its entry from `_skipped` (chip_readable) and its `skip:` (the other three files) in the same change.

## Hand-over

Tests-first exempt: tests only, no lib change. `tools/mine.sh` passes after the skips. The skipped cases are the open chip findings above.

## Commit message

m165 b2h: control tests that the connection chip is readable at 568x320 and 667x375

Add chip_readable_test.dart: at 568x320 and 667x375, in the menu and TV looks,
a paired and connected phone's connection chip must lie inside the screen, be at
least 48 dp square, throw no layout error and show its label uncut.
Remove the skips that hid the chip from connection_chip_test, touch_targets_test
and connect_narrow_test (knownTopBarOverflow).
Four measured cases fail on the base (568 TV width 35.9 dp; label cut at 568 menu
and 667 TV); they are skipped with their measures, not redesigned.
Tests only: no lib change.

## Status row

m165 b2h: chip-readable control added and the TV/568 skips removed; open: the connection chip is 35.9 dp wide at 568x320 TV, its label is cut at 568x320 menu and 667x375 TV (skipped as B-044 control until a lib fix lands).

## Delete

- none
