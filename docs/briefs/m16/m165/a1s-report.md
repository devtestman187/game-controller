# m16 m165 a1s — the ⋯ More menu

tests-first: more_menu_test.dart was written first and failed on the old bar (14 of 15 tests; the controls-false one passed, as it should).

## Files changed
- controller_app/lib/src/ui/controller_top_bar.dart: `_SettingsButton` replaced by `_MoreMenuButton` (MenuAnchor, keys moreMenu / moreSettings / moreDiagnostics, 48 dp minimum); both bars use it when controls is true, else the plain Diagnostics button.
- packages/party_host/lib/src/text/phone_text.dart: `PhoneText.more = 'More'`.
- controller_app/test/more_menu_test.dart (new): 2 looks (menu, TV) x 2 palettes x 4 checks, the compact bar over a game, and "Show on this device" (no menu, plain Diagnostics).
- test/support/pump_app.dart: `openSettings` goes through the menu; new `openDiagnostics` (plain button when moreMenu is absent); `settleMenuRoute`.
- test/support/site_shots.dart: pictureIcons has `Icons.more_horiz` in place of the two bar icons.
- connection_test, diagnostics_test, haptics_test, phone_fit_test: `openDiagnostics`.
- host_mode_test, host_title_bar_test, joined_view_test, phone_look_test: count/size/colour `Key('moreMenu')`.
- host_own_player_test.dart: unchanged (its Diagnostics line is the controls-false bar).

## Checks
- `flutter test` on more_menu_test and the 9 named files (from controller_app/): 100 passed.
- `flutter test` whole controller_app: 840 passed, 2 skipped (before the last import cleanup).
- `tools/mine.sh`: ok, 13 files formatted, analyze clean, 118 + 1 tests.

## Computed values
- 48 dp minimum for moreMenu (asserted `>= 48`, no exact size). Compact bar's moreMenu equals the full bar's (read in the test).

## Notes / questions
1. Tests must run from inside controller_app/ (`flutter test` from the repo root can't find the puzzle assets).
2. After tapping a menu item the route appears only after a second settle (menu closes first), hence `settleMenuRoute`.
3. The TV look at 568x320 overflow is known and not touched.

## Commit message
m165 a1s: Settings and Diagnostics move into one ⋯ More menu

The bar shows one More button (48 dp) on every device and look when the
pad is on; Settings above Diagnostics in its menu. "Show on this device"
keeps the plain Diagnostics button. PhoneText.more added.
Tests: more_menu_test.dart; helpers openSettings/openDiagnostics; the
bar tests count and size Key('moreMenu').

## Status row
a1s done: bar's Settings and Diagnostics are one ⋯ More menu on all devices and looks; open: device check.

## Delete
- none
