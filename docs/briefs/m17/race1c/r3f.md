job: race1c r3f — host UI: pop confetti and the "who held it" line
stop: no puzzle_game change, no snapshot or wire change, no phone UI, no golden slot drawing; no loser callout wording
read: docs/briefs/templates/COMMON.md · packages/party_host/lib/src/ui/puzzle_screen.dart:54-135, :269-380 (state, build, Stack, where _Results mounts) · puzzle_results_widgets.dart:20-80 (_Results head) · packages/puzzle_game/lib/src/present.dart:1-30 (PresentState: holder, popped) · present_rules.dart (popMs) · packages/party_host/test/support/all_looks.dart · an existing puzzle_screen widget test (grep `PuzzleScreen(` in packages/party_host/test) · plan: "pop confetti, results text 'who held it' (no loser callouts)"
changes: PresentTracker (new) · PresentConfetti (new widget) · PresentHeldLine (new widget) · _PuzzleScreenState (hooks only) · _Results (one-line hook only)
model: sonnet
turns: 80
expected-min: 40
tests-first: exempt new widgets, no behaviour on the base to pin
touch-target: exempt no new tappable control
do:
1 New party_host file ui/present_pop_widgets.dart. `PresentTracker`: plain class fed each frame with `match.present`; remembers the side that held the present at its last pop and when. `PresentConfetti`: a short confetti burst over the board for the pop time (PresentRules.popMs) when the present pops, CustomPaint, no assets, works under every look and TV. `PresentHeldLine`: results text with neutral wording, never a loser callout ("popped on X" is NOT allowed). Use: "The present was with the <side name> side last. Everyone batted it around!" with the side names the results already show; nothing when no present popped. State the final wording in the report.
2 Hooks only: puzzle_screen.dart at most 3 added lines (feed the tracker, mount PresentConfetti in the Stack); puzzle_results_widgets.dart at most 2 (mount PresentHeldLine). Both files are at the 380-line gate: if a hook adds lines, move the same number of lines into the new file, net growth 0.
3 New test file present_pop_widgets_test.dart: confetti appears on the frame the present pops and is gone after the pop time; the held line shows the holder at the last pop and nothing when none popped; under every look (all_looks.dart) and TV (`toyTvProvider.overrideWithValue(true)`); no fixed pixel height for content holding a look-sized widget. Run it first.
4 Before finishing run `dart analyze` on your changed files and fix every info.
allow: packages/party_host/lib/src/ui/puzzle_pick.dart · packages/party_host/lib/src/ui/puzzle_screen_results.dart · packages/party_host/lib/src/ui/present_pop_widgets.dart · packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/ui/puzzle_results_widgets.dart · packages/party_host/test/present_pop_widgets_test.dart
check: format analyze
report: docs/briefs/m17/race1c/r3f-report.md
