# M16 wave1-789 n9a: Connect screen manual-address row at 320 px

## Summary

STATUS: stopped. The manual address row now fits every size in both looks except one case: the TV look at 568x320 still overflows by 12 px. The source of that overflow is not identified, and the app bar is not proven to be it.

What changed:
- `_ManualEntry` moved to a new public `ManualEntry` in `connect_manual_entry.dart`, same behaviour and keys. A `LayoutBuilder` puts Connect under the field when the row is narrower than `manualRowSideBySideMinDp` (360 dp); otherwise the Row stays.
- App bar: the title is one line with an ellipsis. The status chip is wrapped in `Flexible`, and its label is one line with an ellipsis.
- The new test file `connect_narrow_test.dart` was written first and failed on the old code (7 of 9 cases failed there).

Tests (`connect_narrow_test.dart`, 9 cases; run with `tools/mine.sh`):
- Sizes tested in both looks (menu, TV): 320x640, 375x667, 568x320, 640x360.
- Text scale 1.3 at 320x640, in both looks.
- Passing now: 8 of 9. Failing: "...568x320 in the TV look" (RenderFlex overflow by 12 px).
- Before the change: failing were 320x640 menu and TV, 375x667 menu and TV, 568x320 TV, and 320x640 at 1.3 menu and TV (7). Passing on the old code were 568x320 menu, 640x360 menu and 640x360 TV (3).
- The manual field and Connect were inside the screen in every size I measured, in both looks.

Measured values at the TV look, 320x640 (before the chip change): chip 0 to 309.3 dp, diagnostics icon at 321.3 to 345.3, so the overflow of 45 px is the app bar's actions (309.3 + 8 + 48 - 320 = 45). After the chip became `Flexible` the 320x640 TV case passes.

`connect_screen.dart` is 332 lines (was 378). `connect_manual_entry.dart` is 86 lines.

Decisions:
- Threshold 360 dp for "side by side" (the brief's figure), as a named constant with a unit.
- App bar: the chip's `Flexible` is what fixed 320 in both looks. The title ellipsis alone did not, because the actions row is laid out before the title gets its room.
- I removed the chip's `mainAxisSize: MainAxisSize.min` for one experiment and restored it. Left as it was.

## Hand-over

**Stopped, not done.** One test still fails: `the address field and Connect sit inside 568x320 in the TV look` (RenderFlex overflows by 12 px on the right). The overflow is in the app bar's actions row: at 568 the status label in the TV look is about 290 dp wide, and `Flexible` did not shrink it. My last experiment (dropping `mainAxisSize.min` on the chip's Row) moved the chip to 0 to 512 dp and still overflowed by 12 px, so the chip is not the whole story. I did not identify which widget overflows (the test framework kept only the first line of the error). What would settle it: print the `RenderFlex` diagnostics (`FlutterError.onError`, or `debugDumpRenderTree` at the failure) for 568x320 in the TV look.

## Changed files

- `controller_app/lib/src/ui/connect_manual_entry.dart` (new): `ManualEntry` (was `_ManualEntry`), with the `LayoutBuilder` column/row split.
- `controller_app/lib/src/ui/connect_screen.dart`: `_ManualEntry` removed (now `ManualEntry`); `ToyButton` import dropped; app bar title one line with ellipsis; `StatusChip` in `Flexible`; label one line with ellipsis. 332 lines.
- `controller_app/test/connect_narrow_test.dart` (new): 9 cases, sizes and text scale as above.

Not changed: `connect_identity_gap_test.dart` and `connect_consent_pop_test.dart` (allowed, but no edit needed). `connect_identity_gap_test.dart` has a comment at lines ~ 80-83 that says the manual row and app bar overflow at 320x640 and cites `connect_screen.dart:348` and `:102`. Those lines are stale; the comment should be updated in a follow-up (I did not change it).

## Checks

- `tools/mine.sh` (last run): format formatted 3 files, analyze PASS, touched tests: 8 of 9 pass, 1 fails (568x320 TV look, see above).
- `flutter test test/connect_narrow_test.dart`: run several times during diagnosis; same result.

## Warning: working-tree side effect

`tools/mine.sh` printed `churn: reverted 22 generated file(s)`. After it, `git status` no longer lists the 22 files that were modified when this job started: `docs/design/m13-placed-look.png`, `docs/design/puzzles/*.png` (12), `site/shots/*.png` (6), and `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`. I did not touch those files. Whether those edits can be recovered is for the owner to check; I can't run git to restore them.

Also: my first `flutter test` run in `controller_app` ran `pub get` ("Got dependencies"). I did not check whether `pubspec.lock` changed; `git status` shows it unchanged.

## Commit message — a draft

Connect: manual address row and app bar fit 320 px

Move the manual address entry to ManualEntry (connect_manual_entry.dart).
Put Connect under the field when the row is under 360 dp.
Cut the app bar's title and status label short with an ellipsis, and let
the status chip give way so the diagnostics button keeps its room.
Tests: connect_narrow_test.dart, 4 sizes in both looks plus text scale 1.3.
568x320 in the TV look still overflows by 12 px; open.

## Status row

Done: manual address row in ManualEntry with a 360 dp column/row split; app bar chip and title cut short with an ellipsis; 8 of 9 narrow-screen cases pass in both looks at 320x640, 375x667, 568x320 (menu), 640x360. Open: TV look at 568x320 overflows 12 px (source not found); the stale line references in connect_identity_gap_test.dart; the 22 working-tree files reverted by mine.sh.

## Delete

- none
