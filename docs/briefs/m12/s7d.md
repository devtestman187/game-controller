job: m12 step7 s7d G4 — the compact top bar over a game, the piece-size check, the emulator's code entry
stop: after G4.
read: docs/design/m12-phone-layout.md (contract §0.1–§0.3, §0.7b, §5) · docs/briefs/m12/s7c-report.md · docs/coding-guidelines.md · controller_app/lib/src/ui/{controller_screen,controller_top_bar,controller_parts,bar_connection,bar_modes,host_chip}.dart · controller_app/lib/src/layout.dart · controller_app/test/{layout_test,joined_view_test,host_mode_test}.dart · packages/puzzle_game/lib/src/{camera,split_layout,puzzle}.dart · packages/puzzle_game/puzzles · tools/emulator.sh

do:
1 Compact top bar (contract §0.7b): while `showsGameProvider` is true the top bar shows only the player badge with the connection dot on the left, and the mode switch, Settings and Diagnostics as icon buttons on the right (the mode switch as one icon that opens the same three choices; keep its keys reachable for tests), nothing in the middle (no host name, no latency text, no status panel). Its items draw at the controls' opacity (`controlsSettingsProvider`). The full bar comes back when no game is shown. Every touch target stays at least its current minimum size (C14–C16).
2 The size check (contract §5): `controller_app/test/puzzle_size_test.dart`. For every puzzle file, the `phones` target and the `side` camera (both sides, seed 1 and 20 seeds), on every non-tablet phone screen in the layout table drawn as the full safe area: the smallest piece's circumscribed diameter on the board in mm (`PuzzleCamera.scale` × diameter ÷ the iOS phone px/mm from layout.dart). Easy and Medium under `minPieceMm` (8.5; a named constant in puzzle_game, documented with contract §0.3) fail with the puzzle, piece, screen and size; Hard prints its size (none today: print "no Hard puzzle"). Print a table of the smallest piece per puzzle per screen; put it in the report. If the layout table lists screens by body size, derive the safe area from the same table's numbers and say how.
3 tools/emulator.sh `connect`: after "Enter the code" shows, tap the code box (the first EditText then on screen, per `tools/emulator.sh ui`) before typing; keep the rest.

tests:
- top bar: at 852×393, with a fake view running (as `joined_view_test`) → the badge, the dot and three icons; no host name, no latency text; the icons' opacity is the saved `controlsOpacity`; the mode icon opens the three modes and picking one switches mode; the view ends → the full bar. The host route (`HostGames`) gets the compact bar too.
- the size check as item 2.
- existing tests: list any expected value that changes, old → new.

in the report: line counts (flag > 300), test counts per check before and after, item 2's table.
rules: no lib file over 400 (tests 500); every party_host import is `as party` · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s7d-report.md · controller_app/lib · controller_app/test · packages/puzzle_game/lib · tools/emulator.sh
check: format analyze puzzle phone
report: docs/briefs/m12/s7d-report.md
