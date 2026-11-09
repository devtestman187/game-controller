job: M13 device fixes 9: a placed piece always looks placed (owner, Nov 9, 2026, the rocket: "No checkmark when placing the circle in the rocket map" and "It's not easy to see if the rectangle in the rocket was placed. There's not much contrast between where to place the piece and the piece itself in some cases. We should aim for higher contrast so players know when the piece is down.")
pub: no
stop: after it.
read: packages/puzzle_game/lib/src/puzzle_painter.dart (`_outline`, `_piece`, `_mark`, `_insideOpenTarget`, `_targetFill`, the picture order), piece_moments.dart, the toy look (packages/toy_look: `toyShape`, the shade, `ToyColors` board/ink/paper, `paintDashedEdge`) · docs/design/look-and-sound.md section 4/5 (Shape Race: targets "dashed ink outlines with a faint fill (Easy: in the piece's colour)", locked pieces "boing and a ✓ sparkle"), D9 · the painter tests in packages/puzzle_game/test · docs/review-rules.md · docs/coding-guidelines.md

The causes (Claude, from the code):
- **The ✓:** `_piece` hides a locked piece's ✓ when its middle is inside any target still open (`_insideOpenTarget`). That was for the house, where a wall's ✓ would sit in the empty door outline drawn over it. But the rocket's window sits on the rocket's body, whose target is drawn *under* it; with the body still open, the window's ✓ is hidden too.
- **Placed or not:** an empty target is the piece's own colour at 25% on the board (Easy), and a placed piece is the piece's colour. A pale piece (the rocket body, `#D5DBDB`, on the cream board) looks almost the same either way. (Another job, s17, is recolouring pale pieces and adding puzzles; this job is the drawing, so it must hold for any colour.)

Claude's rules:
1. **The ✓ hides only under an open target drawn on top of the piece**: one later in the picture's order (a door over a wall). A target under it (the body under the window) never hides it.
2. **A hidden ✓ moves rather than goes**: to the first point of the piece that is inside the piece and outside every open target above it (try its centroid, then points part-way to each corner, or round a circle). Only if there is none is it drawn at the centroid anyway: a ✓ is never dropped.
3. **An empty target is a sunken slot; a placed piece sits up in it.** The empty target becomes a recess in the mat: the board's colour a little darker (Sunny) or lighter (Night) inside it, a soft inner shadow on the edges facing the look's light, and the dashed outline. On Easy it keeps a faint tint of the piece's colour (at most 15%, against today's 25%), so the shape still hints at its piece. A placed piece is drawn as a raised piece: its full colour, the toy shading, its drop shadow and a solid ink edge, never dashed. So a placed piece and its empty slot always differ in fill, edge and shadow, whatever the colour.
4. Keep `look.effects` off meaning still (no animation); the recess is drawing, not motion. Keep the phone's mirror (the other side's small board) readable: it may use the plain outline if the recess doesn't read at its size; say what you chose.
5. Design section 4/5: replace the faint-fill line with these rules, "Decided at device test 3" (owner, Nov 9).

tests (each failing first):
- The rocket with only the window locked: the window's ✓ is drawn (fails today).
- The house with only the walls locked: the walls' ✓ is drawn on the walls but not inside the empty door outline (fails today: it is not drawn at all).
- Every piece of every puzzle, in Sunny and Night: the mean colour of the piece's area when it is placed and when its target is empty differ by at least OKLab 0.12 (measured off rendered frames; fails today for the rocket body). Use whatever puzzles the library has when you run; s17 adds more.
- An empty target has no solid ink edge; a placed piece has no dashed one.
- All existing tests pass (look, puzzle, arena, host, phone, tv, kit). The m12 mirror PNGs will change (targets are in them): keep the new ones and say so.
- Pictures: `docs/design/m13-placed-look.png`, the rocket and the house half-done (some pieces placed, some slots empty), Sunny and Night side by side. Deterministic.

in the report: test counts before and after; the files changed; the slot's colours and shadow values, and the measured placed-vs-empty distance for every piece (before and after); what you chose for the mirror.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch packages/party_host, the puzzle files, camera.dart or match_painter.dart (other jobs are working there).
allow: docs/briefs/m13/s19-placed-look-report.md · docs/design/look-and-sound.md · docs/design/m13-placed-look.png · docs/design/m12-mirror-169.png · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-iphone-stick.png · packages/puzzle_game/lib/src/puzzle_painter.dart · packages/puzzle_game/lib/src/piece_moments.dart · packages/puzzle_game/lib/src/mirror_painter.dart · packages/puzzle_game/test · packages/toy_look
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s19-placed-look-report.md
