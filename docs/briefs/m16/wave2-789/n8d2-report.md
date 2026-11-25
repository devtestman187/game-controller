# n8d2: the Show tips switch in Settings

## Summary

- Added `ShowTipsRow`, a SwitchListTile (key `showTipsSwitch`, title `HomeText.showTips`) bound to the existing `showTipsProvider`. It reads and saves the `showTips` key; a missing key means on.
- Added it to the Settings list in `settings_screen.dart`, after the stats section and before About.
- Tests in a new file, `settings_tips_test.dart`: default on, off saved as false, on saved as true, and a relaunch reading a saved off. The first three run in the menu look and the TV look (`toyTvProvider` overridden).
- `tools/mine.sh`: format OK (3 files), analyze OK, touched tests OK (29 tests in controller_app, including the settings tests that the touched `settings_screen.dart` pulls in). No test pins needed changing.
- The new row is at least 48 dp tall: asserted as `height >= 48.0` in the menu-look default test.

Decisions:
- Used the existing `showTipsProvider` in `home/home_prefs.dart` rather than adding a second store; its build and `set` already match the brief (missing key is on, set saves).
- The switch sits in the motion column between stats and About, with a SizedBox before it and after it so the gap matches the other sections. That is two lines in `settings_screen.dart`, not one, plus the import.
- `settings_test.dart`, `settings_consent_test.dart`, `settings_stats_row_test.dart` are unchanged: nothing they pin moved.

## Self-check (review-rules part A)

1. Host setups: this is the phone controller's Settings only; no TV or PC host screen changes. Shown on the phone build; checked by `settings_tips_test.dart` (phone). Peer one build older: n/a, no protocol change.
2. Kept state: `showTips` is saved on each change and read on build; nothing else is kept. Start and end shown by "with no saved key" and "a fresh launch reads a saved off" tests.
3. Combinations with the pause menu, host away, player away, Get ready, dropped link, results, leaving: not exercised. The switch only writes a flag; Home reads it later. No test here covers Home, which the brief leaves out.
4. Files: all inside `allow:`, plus this report.
5. Stop: see Questions 1 and 2 (the row is not in a toy card).
6. Looks: menu look and TV look both tested for default, off-save and on-save. No fixed pixel height; the 48 dp check is a minimum.

## Hand-over

Changed files:
- `controller_app/lib/src/ui/settings_tips_row.dart`: new, `ShowTipsRow` (ConsumerWidget, SwitchListTile).
- `controller_app/lib/src/ui/settings_screen.dart`: import and the ShowTipsRow line with its spacing (3 lines added; file now about 373 lines).
- `controller_app/test/settings_tips_test.dart`: new, 7 tests (3 rules x 2 looks + relaunch).
- `docs/briefs/m16/wave2-789/n8d2-report.md`: this report.

Checks:
- `tools/mine.sh`: RESULT ok (format, analyze, touched tests: 29 passing in controller_app).
- The churn step of mine.sh reverted 3 generated files under `tv_test_app/windows/flutter/` (generated_plugin_registrant.cc/.h, generated_plugins.cmake). They already showed as modified in the starting git status. The script reverted them itself; I did not touch them. Their local changes, if any, are gone from the working tree.

## Questions

1. The row is a bare SwitchListTile, not inside a toy card like every other Settings section (`_Section` is private to `settings_screen.dart`). Should it get a card header (for example `HomeText.showTips`) or a new section text? The brief named no header, so I did not invent one.
2. Placement: between stats and About in the motion column. Owner to confirm, or move it to the controls column.
3. The brief said "one line" in `settings_screen.dart`; I added two body lines (the row and its spacer) plus the import, for the gap. Say if you want the spacer dropped.

## Commit message — a draft

settings: a Show tips switch saves the coach-marks choice

Adds ShowTipsRow to the Settings, a switch bound to showTipsProvider
(saved as showTips). A missing key means on, as before. The switch
only saves the flag; Home reads it the next time it is idle.
Tests in a new file cover the default, saving off and on, and a
relaunch, in the menu look and the TV look.
Not in a toy card yet: the row's card and placement are open.

## Status row

n8d2: Settings has a Show tips switch saved as showTips (on when unset), tested in the menu and TV looks. Open: the row is not yet in a toy card and its placement is for the owner to confirm; Home does not yet read a changed flag in this job.

## Delete

- none
