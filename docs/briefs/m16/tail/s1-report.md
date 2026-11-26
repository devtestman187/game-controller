# m16 tail s1 report

## Files changed
- controller_app/lib/src/ui/controller_screen.dart: imports for `ControllerButton` (protocol) and `SmallButton` (pad_widgets), as the part file needs them.
- controller_app/lib/src/ui/controller_top_bar.dart: `_GameTopBar` adds `_StartButton` (new, private) before the mode menu when `controls`; it hides when the layout hides Start, else a `SmallButton` keyed `barStart` (default 96x44) plus an 8 dp gap.
- controller_app/lib/src/ui/pad_mode_view.dart, stick_widgets.dart: no Start pill while `showsGameProvider` is true; Select stays.
- controller_app/test/bar_start_test.dart (new): 14 tests (label Pause, hidden layout, menuLayout, no game, press sends START, three pad modes, three sizes x menu/TV look: height >= 44, width >= 96, no overflow). It passed first run with the lib change in.
- controller_app/test/host_frame_wiring_test.dart: Start's pin is now the bar's rect (644, 6, 740, 50), a value read off the failing run; unused imports removed.
- controller_app/test/controls_layer_test.dart: `Start` leaves the pad rects that must not move (it moves to the bar over a game).

## Checks
tools/mine.sh: ok, 138 tests, analyze clean.

## Notes / questions
- The rule text "Start stays on screen in every mode" was not found by grep in controller_app; nothing to reword.
- Other pin tests (game_controls, tablet_and_feedback, haptics, gyro, stick_mode) passed unchanged: they run without a game shown.
- Tests-first was exempt per the brief; the lib change was done first as the repair note asked.

## Commit message
m16 tail s1: Start/Pause moves into the compact game bar

The compact bar over a game shows Start (the game's Pause label) as a
96x44 button before the mode menu; it stays hidden when the layout hides
Start (watchers, menus, away card). The pad's Start pill is not built
while a game shows; in the lobby and controller mode it stays. Tests:
bar_start_test.dart, host_frame_wiring pin, controls_layer rects.

## Status row
m16 tail s1: Start/Pause is in the compact game bar and off the pad over a game; open: rightPadRects (s2), mirror code.

## Delete
- none

## Summary
Start/Pause now lives in the compact game bar (follows the host layout: label, hidden for watchers, menus and the away card); the pad drops its Start pill while a game shows; lobby/join pad unchanged. 14 new tests, pins updated. Part A self-check: hosting phone in the lobby has no pad (controller_parts.dart:32, phase none), so no Start is lost there (driver verified, Nov 26); "Show on this device", pause menu, dropped link and "Get ready" pairs are not tested (code-health).
