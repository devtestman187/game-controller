# rv2 report: controller_app ui and providers (m16 milestone-end review, read-only)

Range fb2f6a5e..6300f506, `controller_app/lib/src/ui` and `controller_app/lib/src/providers`: 13 files, +248/-164.
I ran no tests. I read the diff and the files and test names around the hunks. Findings already in REVIEW-VERDICTS.md are skipped.

## Summary
Verdict: no must. The wire protocol is unchanged (`git diff --stat` on packages/protocol for the range is empty). The only provider change is dartdoc plus one log string. The UI changes are narrow-layout fixes, one extraction, semantic labels and the Show tips row.
Counts: must 0, should 3, later 3.
Top three:
1. should: nothing tests the bar's drop-the-ping rule at its 280 dp boundary or at large text.
2. should: no test covers the Connect app bar's title and StatusChip ellipsis (item 9a) at 320x640.
3. should: the Show tips row is tested in both looks but at one size only, with no large text.

## Findings
- **should** controller_app/lib/src/ui/bar_connection.dart:101 A6/G9: `pingBesideMinBarDp = 280` is a hand-measured threshold. Its doc cites the 667x375 menu bar (201 dp) and the TV bar (87 dp), so the ping is hidden in both. Nothing tests the branch where a bar of 280 dp or more shows the ping beside the chip: iPad window, a 568-wide bar after the badge, or a bar with large text. `connection_chip_test.dart` covers only the chip size and label at 667x375 and the 48 dp check at the phone sizes. A change to the threshold or to `chipFlex` passes silently. -> add a test at an iPad window (e.g. 1024x768) that expects `pingStats` and a whole host name, and one at 320x640 with text scale 1.3 that expects no overflow.
- **should** controller_app/lib/src/ui/connect_screen.dart:100 A6: the app-bar title now has `maxLines: 1` with an ellipsis, and `StatusChip` is wrapped in `Flexible` with an ellipsising label (lines 389-408). `connect_narrow_test.dart` covers only the manual row (lines 24-38). A long status at 320 dp or at scale 1.3 could still push the diagnostics button off, and no test would show it. -> add a test with a long status label at 320x640 and at scale 1.3 in both looks, expecting the diagnostics button inside the screen and no overflow.
- **should** controller_app/lib/src/ui/settings_tips_row.dart:14 A6: `settings_tips_test.dart:13-18` checks the 48 dp height in both looks at the default size only. The row's `SwitchListTile` title (`HomeText.showTips`) can wrap at 320 dp with large text, and nothing proves it fits. -> run the height and no-overflow check at 320x640 and scale 1.3 in the TV look, as the f1 fix did for the Settings overflow.
- **later** controller_app/lib/src/ui/connect_manual_entry.dart:232 G-docs: the public `ManualEntry` has a class dartdoc but no constructor dartdoc. `ShowTipsRow` (settings_tips_row.dart:701 in the diff, constructor line 7 of the file) is the same. The wave-2 verdicts called this a trivial fix for `ShellBack`. -> one line each.
- **later** controller_app/lib/src/ui/connect_manual_entry.dart:228 G2: `manualRowSideBySideMinDp = 360` and the switch to a Column are tested only at 320 and 375 (`connect_narrow_test.dart:11-14`), so the 360 edge itself is untested. Not a defect, since 320 and 375 fall on either side. -> a test at 359/360 dp if the constant is ever moved.
- **later** controller_app/lib/src/ui/settings_profile_section.dart:243 A6: the `Row` became a `Wrap`, and `textAlign: TextAlign.end` was dropped. The note is now start-aligned (the driver's decision, f1). On a wide iPad window the note sits next to the figures instead of at the right edge. The result is consistent, but no test pins the new look at an iPad window. -> accept, or add a size to the preview test.

## Combination table (A3)
Most of these combinations (pause menu, host away, "Get ready", results) live in files outside this part (host, game screens). Here only `bar_connection.dart`, the Connect screen and the dialogs matter.

| Combination | Result |
|---|---|
| Pause menu | Not in this part's files. Not tested here. |
| Host away | `BarConnection` shows the chip and `hostLabel` only while connected. The reconnect state shows `tapToConnect(statusLabel)`. Tested by `connection_chip_test.dart` for the connected case only; the reconnecting label at narrow widths is not tested. |
| Player away | Not in this part. |
| "Get ready" | Not in this part. |
| Dropped link | The ping and the panel need `client.isConnected`. The chip falls back to the status text with `minTouchTargetDp`. `returnHomeOnFailedConnect` is in controller_screen.dart:134 (first connection only, per Q7); its tests are in another part. |
| Results | Not in this part. |
| Leaving | Not in this part. |
| Phone hosting (live game) | `launchConsentDue` keeps the old rule (hosting live gives no prompt). Tested by `paired_launch_consent_test.dart` (name seen, body not read). |
| Game status panel against the ping | `panelShown` is computed first, so `pingWanted` is false while the panel shows. Tested by `joined_view_test.dart` (grep hit on pingStats; body not read). |

## Could not check
- I did not run any test or dart analyze. The claims "820+ pass" and "touch-target test green" come from REVIEW-VERDICTS.md.
- Home, launch routing and `routeLaunch` (controller_screen.dart:537) are outside this part (`../home/*`), so I did not review the consent order or the paired relaunch rule beyond the call sites.
- I read the names and sizes of the new test files, not their bodies. I could not confirm that each new test fails on the old code (A9/G9).
- I did not look at Sunny against Night palettes in the screens. The tests iterate over the menu and TV looks only.
- No device or screen-reader check for the slider semantics (`semanticFormatterCallback`). `slider_semantics_test.dart` covers the three call sites in both looks.

## Commit message
rv2: review of controller_app ui and providers (m16 close)

Read-only review of fb2f6a5e..6300f506 for controller_app ui and providers.
No must. Three should (tests at narrow, iPad and large text for the bar,
Connect app bar and Show tips row) and three later. Protocol unchanged.

## Status row
rv2 (controller_app ui and providers review) done: 0 must, 3 should, 3 later; open: narrow, iPad and large-text tests for the bar, Connect app bar and Show tips row.

## Delete
- none
