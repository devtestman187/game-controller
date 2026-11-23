# fm2 report: host_chip build under the length limit, MatchView re-export removed

## Summary

Refactor only; behaviour unchanged. `HostChip.build` drops from 63 lines to 31 (lines 31-61). The menu (code, join hint, "New code", "Stop hosting") moved into a private `_HostMenu` widget with the same keys, widgets and style. `play_view.dart` no longer re-exports `MatchView`; `puzzle_module.dart` imports `match_view.dart` directly.

Files changed:
- `controller_app/lib/src/ui/host_chip.dart`: `build` keeps the badge row and the `Flexible` wrapper and hands the menu to `_HostMenu(code, address, compact, onNewCode, onStop)`, 5 parameters. `_HostMenu.build` is about 30 lines. `_OwnBadge` was not extracted; `build` is under 40 lines without it, so it was not needed.
- `packages/puzzle_game/lib/src/play_view.dart`: removed the `export 'match_view.dart';` line and its comment. The file still imports `match_view.dart` for its own use of `MatchView`.
- `packages/puzzle_game/lib/src/puzzle_module.dart`: added `import 'match_view.dart';`, and removed `import 'play_view.dart';`. The analyzer flagged that import as unused once the re-export was gone (`unused_import`), so it had to go.

Not changed: `packages/puzzle_game/test/coverage_all_test.dart`, `packages/puzzle_game/test/puzzle_module_test.dart`, `controller_app/test/host_chip_test.dart`. Nothing in them referenced `MatchView` through `play_view.dart`, so none needed an edit.

Checks:
- `tools/check.sh format analyze phone puzzle`: PASS, all four. First run: format failed on `host_chip.dart` (fixed with `dart format`), analyze failed on the unused `play_view.dart` import (fixed). Second run: format PASS, analyze PASS, puzzle PASS (450 tests), phone PASS.
- Line counts: `host_chip.dart` is 180 lines (limit 380). `play_view.dart` and `puzzle_module.dart` are short and shorter than before.

Self-check (docs/review-rules.md part A):
1. Host setups: a TV or PC host, a phone on "Play on this phone", a phone on "Show on this device", a joined phone, a peer one build older. Not re-run per setup: the change is a widget extraction with no change to what is shown. Covered by `host_mode_test.dart` (newCode, stopHosting) and `host_chip_test.dart` (hostChip, hostNoWifi, hostAddress, playerBadge), both in the phone suite, which passed.
2. Kept state: none added or removed.
3. Combinations: nothing new; the menu's behaviour is unchanged.
4. Only the files listed above were touched.
5. Nothing stopped.
6. Every look: refactor only. The menu and the compact bar keep the same widgets and styles (`look.colors.ink` on the rows, `compact` passed through to `_CodeChip`). `host_chip_test.dart` covers the menu and the compact bar. I did not run a visual check on a device.

Tests-first: exempt, refactor, behaviour unchanged (the brief's header).

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

M16 identity1-fix fm2: host_chip build under the limit, MatchView re-export removed

Move the host menu (code, join hint, New code, Stop hosting) from HostChip.build
into a private _HostMenu widget, with the same keys and style, so build is 31 lines
(review.sh FAILed it at 63). play_view.dart no longer re-exports MatchView;
puzzle_module.dart imports match_view.dart directly and drops the now unused
play_view import. Refactor only, no behaviour change.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 identity1-fix fm2: done (HostChip.build 31 lines via _HostMenu; MatchView re-export removed, puzzle_module imports match_view.dart; check format analyze phone puzzle PASS). Open: none for fm2; the own-player badge was not extracted (not needed).

## Delete

- none

## Questions and suggestions

1. The brief says `host_chip_test.dart` pins the keys `hostCode`, `newCode` and `stopHosting`. It pins `hostChip`, `hostNoWifi`, `hostAddress` and `playerBadge`. `newCode` and `stopHosting` are pinned in `host_mode_test.dart`. Nothing I found pins `hostCode`. Suggest a test for it in a new file, which is a separate job.
2. The brief lists `coverage_all_test.dart` and `puzzle_module_test.dart` as allowed. I did not need to change them. Suggest removing them from the allow-list in the next brief, or leaving them as they are.
