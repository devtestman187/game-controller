# Wave 1 of M16 items 7-9, re-cut per FABLE-REVIEW.md (Nov 24)

Base 2dfe1378 (m16.3 tagged; B-040 and the Q8 `night_end` message are in bugs4). Owner answers Q1-Q8 are in plan789/QUESTIONS.md; no new owner decision is needed.

Applied from the review:
- 7a shrinks to the host-side pinning test (Q8 moved the phone's final card to bugs4): start-card names -> reveal order -> final totals with a tie, TV host and phone host.
- 9c has no shared helper: `semanticFormatterCallback` is set at the four sites.
- 9d is cut in three: n9d1 behaviour-free extract from `game_screen.dart` (379), n9d2 Arena HUD "Round N of M" + clock red at 15 s, n9d3 map name. Q6 B (400, no 9f): `arena_map.dart` (395) is NOT edited; n9d3 uses a new names file or the already loaded map.
- 9a keeps its plan scope; moving the manual row to a new file also takes `connect_screen.dart` below 380.
- Contract-first order: n9d1 (wave 1) before n9d2 (wave 2) before n9d3 (wave 3); n9d2 and n9d3 share `arena_hud_widgets.dart`.

| Job | Wave | What |
|---|---|---|
| n9a | 1 | connect row at 320 px, both looks (controller_app) |
| n9c | 1 | slider semantics at four sites (controller_app + party_host) |
| n9d1 | 1 | extract the build shell from `game_screen.dart` (party_host) |
| n7a | 2 | awards flow pinning test (party_host, tests only) |
| n9d2 | 2 | Arena HUD night round "N of M", clock red at 15 s (test_game) |
| n9d3 | 3 | map name in the Arena HUD (test_game) |

Not in this batch, named so they are not lost: Shape Race HUD night round (needs an inventory of what `puzzle_screen.dart` and `board_hud.dart` show; `puzzle_screen.dart` is 377), 9b (inventory test first, then offenders), 9e Resume colour, all of item 8 (contract with navigation, Home inputs, anchors; 8b0/8b1/8b2; 8e inventory first), the TV-word guard test, party_host 48 dp, coverage baseline. Owner questions from the re-cut: none.
