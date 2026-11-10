job: M14 a1: points in Shape Race (G1): counted by the rules, popped up in a party night, carried in the snapshot (version 2), handed to the night as a `RoundResult` (docs/design/party-night.md sections 2 N1–N4, N11, N12, and 3)
pub: no
stop: after it.
read: docs/design/party-night.md (sections 2, 3, 13) · docs/PRD-v2.md G1, G2 and G5 · docs/briefs/m14/scan-m14-refresh-report.md (sections 2, 4) · packages/game_kit/lib/src/round_result.dart (`RoundResult`, `RoundLine`, `RoundOutcome`; g3) · packages/puzzle_game/lib/src: game.dart, puzzle_player.dart, puzzle_tick.dart, puzzle_drop.dart, puzzle_carry.dart, puzzle_events.dart, match.dart, settings.dart, snapshot.dart, puzzle_session.dart, puzzle_report.dart, match_hud.dart, board_hud.dart, match_painter.dart, piece_moments.dart, text_paint.dart · packages/game_kit/lib/src/frame_view.dart (the update text on a version mismatch) · docs/protocol.md (the puzzle snapshot) · docs/design/look-and-sound.md sections 3–5 (tokens, Fredoka) · docs/coding-guidelines.md · docs/review-rules.md

Points are the night's currency (G1, G2). Claude's design:
1. **The rules count points per side.** A piece snapped on the first try +2; snapped after a wrong drop of that piece +1; a big piece snapped while two players carry it +1; finishing first +5 (a race: the side that completes its picture first; one board: completing it before time-up). Shooing the cat (+1) comes with the cat (job a2): leave a clearly named place for it. Each value × `PuzzleSettings.pointsScale` (new, default 1; a night's last round sets 2). Points never go down.
2. **Credited per player**: a side's points go to every player on it, so a side of two and a side of one earn the same for the same play. The per-player total is what the night reads.
3. **Pop-ups**: each award adds a pop-up (side, where: the piece's target or the finish, amount, icon) that lives 1.2 s. Kept in the rules' state with its age so a joined phone draws the same rise and fade.
4. **Snapshot version 2** (`PuzzleSnapshot.version = 2`, `MatchSnapshot` too if it carries its own): top-level `pts` (each side's points) and `pop` (the live pop-ups, each with its age in ms), and `nt` (true in a night round: `PuzzleSettings.night`, new, default false). Stay inside the 2048-byte budget with four players and the most pop-ups a frame can have (test it). A phone with version 1 already shows the update text (`frame_view.dart`): check that it does for a version-2 frame. Update docs/protocol.md.
5. **Drawing, only when `nt` is true**: a big "+2" in Fredoka with a star icon, rising 24 px and fading over 1.2 s, at the pop-up's place; each side's points beside its badges in the HUD with a star icon. With effects off the pop-up appears and goes without moving (G5). Never colour alone: the number and the icon carry it. Outside a night nothing new is drawn and the screen is exactly as today.
6. **The night's result**: `MatchResult` gains `round`, a `RoundResult` (game `puzzle`): `winners` and `draw` as the match decides them today; `points` per player; `stats` per player `snaps`, `wrongDrops`, `carries` (big pieces snapped carried by two), `catsShooed` (0 until a2), `tryAgains` (snaps after a wrong drop, for the Try Again award); `lines` per player (outcome `win`/`loss`/`draw`, or `done` with the time on one board; the count of pieces placed). Built by the match, so `party_host` needs no change in this job.
7. Points change nothing else: no rule of play moves. Every existing rules test passes unchanged.

tests (each failing first):
- One test per scoring action, with its value at scale 1 and at scale 2; a wrong drop then a snap gives +1, not +2; the finish +5 to the right side in a race and on one board, and not at time-up.
- A 2-vs-1 race: the same play earns the same points for the side of two and the side of one, and each player of the two is credited in full.
- Pop-ups: one per award, gone after 1.2 s; in the snapshot with their age; the snapshot with four players and the most pop-ups stays under 2048 bytes; `nt` false draws nothing new (a paint test or golden-free check of the HUD), true draws the pop-up and the points; effects off draws it without the rise.
- Version 2: a frame round-trips; a version-1 reader shows the update text.
- `MatchResult.round`: winners, draw, points, stats and lines for a 1v1 win, a draw, a 2v2 and a solo finish and time-up.
- All existing tests pass unchanged (puzzle, phone, tv, host); the mirror pictures come out unchanged (outside a night nothing new is drawn).

in the report: the scoring table as built; the snapshot's new keys with a sample frame and its size; where the cat's +1 goes in a2; test counts before and after; the mirror pictures unchanged.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it (item 2: when a pop-up starts and ends, and that it does not age while the round stands still).
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch the rule book (`puzzle_rules*.dart`, `puzzle.dart`, `piece_shape.dart`), `puzzles/`, `packages/game_kit`, `packages/party_host` or `tools` (another job is working there)
allow: docs/briefs/m14/a1-points-report.md · docs/protocol.md · packages/puzzle_game/lib · packages/puzzle_game/test
check: format analyze puzzle phone tv host
report: docs/briefs/m14/a1-points-report.md
