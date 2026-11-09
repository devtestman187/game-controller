job: M13 device fixes 9b: an empty target is a sunken slot (finishing s19; owner, Nov 9, 2026: "It's not easy to see if the rectangle in the rocket was placed ... We should aim for higher contrast so players know when the piece is down.")
pub: no
stop: after it.
read: docs/briefs/m13/s19-placed-look.md (rule 3, 4, 5) and its report (your sweep, the per-piece table, the mirror choice, Claude's review) · docs/briefs/m13/s17-puzzles-report.md (the recoloured palette: every piece now at least 0.15 OKLab from the board in Sunny and Night) · packages/puzzle_game/lib/src/puzzle_painter.dart, mirror_painter.dart, packages/toy_look · docs/design/look-and-sound.md · docs/review-rules.md · docs/coding-guidelines.md

Claude's decision on s19's question 1: **(b), a mat-toned slot.** s17 has removed the pale pieces that made the deep recess necessary.
1. The empty target: the board's colour a little darker in Sunny (lighter in Night), the soft inner shadow on the edges facing the look's light, the dashed edge (s19's square caps); on Easy a tint of the piece's colour of at most 10%. Pick the darkening from your sweep so rule 2 below holds with some margin; say what you picked.
2. Test: every piece of every puzzle in the library, in Sunny and Night, has a placed-vs-empty mean colour distance of at least **0.10** OKLab (measured as s19 planned). If a piece misses it, say which and by how much rather than lowering it; I'll decide.
3. A placed piece stays as it is: raised, full colour, shadow, solid ink edge, its ✓.
4. Mirror: as your s19 report chose.
5. Design section 4/5: replace the faint-fill line with s19's rules 1–3 as decided, "Decided at device test 3" (owner, Nov 9).
6. Picture: `docs/design/m13-placed-look.png`, the rocket and the house half-done, Sunny and Night side by side. Deterministic.

tests (each failing first): the distance test above; the slot's edges are dashed and darker than the board inside (Sunny) / lighter (Night); all existing tests pass. The m12 mirror PNGs may change if targets are in them: keep them and say so.
in the report: test counts before and after; the files changed; the slot's values; the per-piece distance table (Sunny and Night).
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing · don't touch the puzzle files, camera.dart or match_painter.dart.
allow: docs/briefs/m13/s19b-sunken-slot-report.md · docs/design/look-and-sound.md · docs/design/m13-placed-look.png · docs/design/m12-mirror-169.png · docs/design/m12-mirror-iphone.png · docs/design/m12-mirror-iphone-stick.png · packages/puzzle_game/lib/src/puzzle_painter.dart · packages/puzzle_game/lib/src/mirror_painter.dart · packages/puzzle_game/test · packages/toy_look
check: format analyze look puzzle phone tv
report: docs/briefs/m13/s19b-sunken-slot-report.md
