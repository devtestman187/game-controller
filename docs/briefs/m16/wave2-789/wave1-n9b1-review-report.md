## Summary

small fixes
Counts: must 1 · should 5 · could 3
- The test's last check depends on the earlier tests having run (`seenBelow48`), so run alone it reports the chip as fixed.
- The report's self-check says "every look, in every test" and "scratch files remain"; the code skips 568x320 TV and the two files are not in the tree.
- A bare `0.01` tolerance breaks the no-magic-numbers rule.

## Findings

- **must** controller_app/test/touch_targets_test.dart:94 `_below` uses a bare `0.01` tolerance, which §2 does not allow → name it as a documented constant (for example `touchRoundingSlackDp`) with its reason.
- **should** controller_app/test/touch_targets_test.dart:28 and :89 the global `seenBelow48` is filled by the widget tests, so the last test passes or fails depending on run order; with `--plain-name` on that test alone it reports the chip as fixed → make the check not depend on the other tests (measure the listed keys in the test itself, or assert it in a `tearDownAll` of the group).
- **should** controller_app/test/touch_targets_test.dart:67-69, :105 and :145 Settings is pushed over Connect, so `find.byType(Scrollable).first` and `measureTargets` may see Connect's widgets (the comment at :145 says offstage routes are measured) and label them `settings` → scope the finders to the Settings route, or confirm by a run that they do not.
- **should** controller_app/test/touch_targets_test.dart:71-72 the portrait pad at 375x667 and 320x640 asserts nothing (zero targets is accepted), so 2 of the 8 pad cases can never fail → keep the exemption but add an assertion that the portrait pad shows the "turn the phone" text, or drop those two cases.
- **should** docs/briefs/m16/wave2-789/n9b1-report.md:25 the self-check says `tt.log` and `tt_backup.dart` remain in the repo root; `ls` shows neither file exists → correct the line (or confirm it was removed).
- **should** docs/briefs/m16/wave2-789/n9b1-report.md:27 "Every look: menu and TV, in every test" is untrue: line 48 of the test skips 568x320 in the TV look for all three screens → name the exclusion in the self-check line.
- **could** docs/briefs/m16/wave2-789/n9b1-report.md:11 "The chip ... `Flexible` in an `Expanded` row, controller_top_bar.dart:92" → line 92 is an `Expanded`, not a `Flexible`; fix the word.
- **could** controller_app/test/touch_targets_test.dart:47 the overflow is cited as controller_top_bar.dart:89, but line 89 is the `Padding` that starts `build`; the overflow is in the `Expanded` row at :92 → cite :92 or the overflow's real line.
- **could** controller_app/test/touch_targets_test.dart:42-92 `main()` is about 51 lines, over the about-40 limit in §3 → move the loop body into a named helper (for example `_registerTargetTest`).

## Decisions to confirm

- The 568x320 TV exclusion (test :48) covers Connect and Settings as well as the pad. The brief asked to leave out "that one size/look/screen", i.e. the pad only; confirm the wider scope.
- The chip offender (`knownBelow48`, test :24) is its `ActionChip`'s render box, not a verified hit area (report :19). If the chip's tap area is padded like Material's, the entry is wrong and the offender may not exist. Confirm before n9b2 spends a fix on it.
- The brief's "mode control 40 dp compact" measures 48 here, and its segments were never printed separately (report :13). The brief's number is not what the test shows; confirm which one the PRD means.
- The portrait pad has no targets at 375x667 or 320x640 (report :16); confirm that is the intended screen and not a gap.
- Hosts: only the unpaired phone and the paired, connected phone are covered (report self-check line 23). Rule A1 asks for the host setups that differ (TV or PC host, "Show on this device"); confirm they are out of scope.
- `knownBelow48` compares keys only (test :94, report :18). A target that gets worse at one size and better at another still passes; accept this, or compare sizes.

## Could not check

- The run was not repeated (read-only job): the "22 tests, OK" from `tools/mine.sh` and the `dart analyze` / `dart format` results are the worker's claims only.
- Whether Settings' `find.text('Settings')` and `find.byType(Scrollable).first` pick Connect's widgets under the pushed route (see the should above) needs a run or a read of the Navigator's offstage handling.
- Whether the mode segments' and the chip's hit areas are the padded 48 dp box needs a run or a read of Material's tap-target code.
- `docs/briefs/m16/wave2-789/run-findings.md` does not exist, so there were no run-findings entries to check.
