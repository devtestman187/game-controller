job: m12 bug triage — on a phone-hosted Shape Race the player's dot can't reach the tray; read-only
stop: after the triage. Change no file but the report; fix nothing.
read: packages/puzzle_game/lib/src/{split_layout,puzzle,game,puzzle_carry,puzzle_drop,match,camera,view,match_painter,puzzle_painter}.dart · packages/puzzle_game/test/split_layout_test.dart · docs/design/m12-phone-layout.md §1 · docs/briefs/m12/s7-g1-plan.md §2 · docs/briefs/m12/s7b-g3-report.md · docs/coding-guidelines.md · the owner's screenshot docs/briefs/m12/bug1-shot.png (read it as an image)

the owner's report:
- did: iPhone hosting, "Play on this phone", Shape Race solo (tree puzzle: crown, sun, trunk, mountain), sticks mode · expected: move the dot into the tray along the top, over a piece, press A to pick it up · happened: "My player cannot go into the area to pick up a pieces. It can only go to the edge of the box. If I tap A a piece appears randomly." The screenshot shows dot 1 stuck on the board's top edge, just under the tray row; the tray's pieces overlap each other at the top left; the HUD ("1:31", "You 0/4") at the tray row's right end.
- log lines: none point at it (the host log shows a normal start; 719 input states).
- build: m12.3, 0.12.0 (179), iPhone, phones layout target (solo), host's own player.

questions:
1 What stops the dot at the board's top edge? `PuzzleField.top`, `_inField`, the board/tray rects, `startX` — find the line and the value it has in a phones world (work the numbers for the tree at seed 1). Is it the same for a split phones match?
2 "A piece appears randomly": what A does there — `_pickUp`'s reach from the dot to the nearest tray piece, and which piece it takes and why it looks random.
3 The tray pieces overlap in the screenshot (crown, mountain, sun, trunk drawn on top of each other): is that the packing (0.5 overlap at 0.75 in one row, by design) or a bug (the tray narrower than its packed row, or drawn at a different scale than packed)?
4 For each: cause (file:line), confidence (sure / likely / guess) and what proves it, the fix (files, lines, what it could break — the screen layout must not change), and the failing test you'd write first.

format (the report, at most 20 lines per question block): `## Bug N — <name>` with Cause, Confidence, Fix, Test, Risk. Mark anything inferred "unsure". No code longer than 5 lines.

allow: docs/briefs/m12/bug-1107-triage-report.md
check:
report: docs/briefs/m12/bug-1107-triage-report.md
