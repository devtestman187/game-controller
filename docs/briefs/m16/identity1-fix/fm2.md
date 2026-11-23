job: M16 identity1-fix fm2: host_chip build under the length limit, MatchView re-export removed
expected-min: 20
turns: 35
tests-first: exempt refactor, behaviour unchanged (host_chip_test.dart and the puzzle tests pin it)
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/identity1/MILESTONE-VERDICTS.md (fm2) · controller_app/lib/src/ui/host_chip.dart:1-100 · packages/puzzle_game/lib/src/play_view.dart:1-20 · packages/puzzle_game/lib/src/puzzle_module.dart:1-12 · controller_app/test/host_chip_test.dart (pins the keys hostCode, newCode, stopHosting) · docs/review-rules.md (function length) · docs/coding-guidelines.md
changes: _HostMenu · _OwnBadge · export 'match_view.dart'
decisions (review of identity1, Nov 23): review.sh FAILs `HostChip.build` at 63 lines; play_view.dart re-exports MatchView only for puzzle_module.dart.
do:
1 host_chip.dart: extract the `menuChildren` list (code, _JoinHint, New code, Stop hosting) into a private widget or method `_HostMenu`, and the own-player badge row part into `_OwnBadge` if it helps, so `build` is under 40 lines. Same keys, same widgets, same layout; no behaviour change.
2 play_view.dart: remove the `export 'match_view.dart';` line and its comment. puzzle_module.dart: add `import 'match_view.dart';`. (puzzle_game.dart already exports both files; tests use the barrel.)
3 Run `bash tools/review.sh` is done by the runner; just keep both files' functions short. Report the new build line count.
Every-look rule: refactor only; host_chip_test.dart covers the menu and the compact bar; say so in the self-check.
allow: controller_app/lib/src/ui/host_chip.dart · packages/puzzle_game/lib/src/play_view.dart · packages/puzzle_game/lib/src/puzzle_module.dart · packages/puzzle_game/test/coverage_all_test.dart · packages/puzzle_game/test/puzzle_module_test.dart · controller_app/test/host_chip_test.dart
check: format analyze phone puzzle
report: docs/briefs/m16/identity1-fix/fm2-report.md
