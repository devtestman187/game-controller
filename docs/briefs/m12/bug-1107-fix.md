job: m12 bug 1107 fix G4 — the dot reaches the tray on phones; the advertising log tag
stop: after G4.
read: docs/briefs/m12/bug-1107-triage-report.md (your triage: Claude approves Bug 1's fix; Bugs 2 and 3 need none) · packages/puzzle_game/lib/src/{split_layout,puzzle,puzzle_carry,puzzle_drop,game}.dart · packages/puzzle_game/test/{split_layout_test,tray_pile_test}.dart · packages/puzzle_game/test/support/match_helpers.dart · packages/party_host/lib/src/host_advertising.dart (and wherever its log sink is named)

Claude's answers: Q1 not needed: after the fix `contains` decides, whatever `pickupRange` is · Q2 not needed · Q3 accept the dot over the HUD area and the top margin; accept a carried full-size piece clipped at the world's top for now (note it in the report as tech debt) · Q4 the fix alone, no size-debt work.

do:
1 `split_layout.dart` `_computePhones`: `top: margin` (contract §1's world; the screen layout unchanged). `puzzle.dart`'s doc for `top` says what it is on phones.
2 The advertising log: the sink that prints `[tv] Advertising "…"` on a phone host logs under `host`, like `LiveHostService` since s9b. Check no tool or test matches the old text (smoke.sh reads `[host]` and `Listening on port`).
tests (puzzle_game, failing before item 1):
- for each of the four puzzles at seed 1, a phones solo game (the layout's left field and angles): for every tray piece, drive the dot to that piece's drawn centre (or to a point inside its drawn shape that's on the top layer there), press A, and the held piece is that one. Also the same for one split phones match on both sides.
- the dot can reach `y ≤ tray.bottom − dotRadius` with the stick held up (it couldn't: 29.6 for the tree).
- existing tests: none should change; list any old → new.
in the report: test counts before and after, the files changed.
rules: no lib file over 400 · the screen layout's numbers unchanged · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/bug-1107-fix-report.md · packages/puzzle_game · packages/party_host/lib · packages/party_host/test
check: format analyze puzzle host phone tv
report: docs/briefs/m12/bug-1107-fix-report.md
