job: m12 step7 s7b G3 — the phones world, the rules, the setup key, the host's choice
stop: after G3. Nothing from contract §2–§5 (cameras, painters, viewer, size check).
read: docs/design/m12-phone-layout.md (contract; §0.3 has the owner's decision, §1 is this job) · docs/briefs/m12/s7-g1-plan.md (your plan: §2–§3 hold except where the answers below change them) · docs/coding-guidelines.md · packages/puzzle_game/lib (split_layout, puzzle, game + parts, tray, match, puzzle_module, puzzle_session, snapshot, start_angles) · packages/puzzle_game/test (split_layout_test, match_test, support/match_helpers, puzzle_module_test) · packages/party_host/lib/src/ui/puzzle_screen.dart · packages/party_host/lib/src/host_service.dart

Claude's answers to the plan's questions: Q1 owner decision — tray on top, `minPieceMm` 7.5 (contract §0.3) · Q2 no 2:1 aim: the world is sized to its content (contract §1), one tray row unless the world would pass 2.2:1 · Q3 the crop, as the screen layout uses · Q4 yes, `seed` in a one-board phones snapshot · Q5 your placeholders, each documented as screen-only · Q6, Q9 done in s7a · Q7 keep 0.75 and 0.5 · Q8 no strip band: a `hudWidth` (40 units) area at the right end of the tray row · Q10 yes, `compactStartAngles(flat: true)`.

do:
1 `LayoutTarget`, `SplitLayout.of(..., target:)`, `_computePhones` per contract §1 (named constants with units and reasons: `hudWidth`, the margins, `phoneMaxAspect` 2.2).
2 `PuzzleMatch` takes the target, for every format (solo and team use `layout.left`); the one-board phones snapshot carries `seed`.
3 Setup: `shapeRaceSetup` gains `layout` (`"phones"`, absent = screen); `createViewer` reads it; an unknown value throws a FormatException naming the key. `PuzzleSession` / `PuzzlePlayView` pass it to the match.
4 Host's choice: party_host's puzzle screen picks `phones` when `HostService.shareView` is true, else `screen`, when the round is created (a change mid-round waits for the next round).
5 `rocket.json`: window `{"circle": 4}` → `{"circle": 6}`. Say which existing expected values that changes (screen layout numbers for the rocket), old → new.
6 A printing test (no assertion on mm yet) in `split_layout_test.dart`: for each puzzle and seed 1, the phones side world (W × H units) and `min(boxW / W, boxH / H)` for boxes 667×375 and 734×372, and the smallest circumscribed diameter on the board in px and in mm at 160/25.4 px per mm. Put the printed table in the report.

tests (puzzle_game, party_host):
- every puzzle × 20 seeds, phones: the tray is above the board and spans no wider than the world minus `hudWidth` and margins; the HUD area is free of tray boxes; the board is the crop, centred; packing at the tray's width fits (`overflow ≤ 0`); one row unless the 2.2 rule applies; both sides identical; memoised per (puzzle, seed, target); `of(p, s)` and `of(p, s, target: phones)` differ.
- a phones split match starts every piece where `packTray` at the field's tray width puts it, on both sides; a solo phones match uses `layout.left` and its snapshot has `seed`.
- setup: `layout: 'phones'` round-trips; missing → screen; `'diagonal'` → FormatException naming `layout`.
- party_host: with `shareView` true the round's setup has `layout: 'phones'`, false → no `layout` key.
- existing: no expected value changes for `screen` except the rocket's (item 5), listed old → new.

in the report: line counts (flag > 300), test counts per check before and after, item 6's table, and the s7c plan (cameras, painters, viewer, own view, Arena, size check) in at most 20 lines.
rules: no lib file over 400 (tests 500); screen layout behaviour unchanged · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s7b-g3-report.md · packages/puzzle_game · packages/party_host/lib · packages/party_host/test
check: format analyze puzzle host tv
report: docs/briefs/m12/s7b-g3-report.md
