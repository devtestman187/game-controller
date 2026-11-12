job: M14 bug p1: Shape Race puzzles with near-identical pieces (owner's device test, Nov 12, 2026)
pub: no
stop: after it.
read: docs/coding-guidelines.md · docs/review-rules.md part A · packages/puzzle_game/lib/src: puzzle.dart, library.dart, piece_shape.dart, piece_size.dart, puzzle_rule_fit.dart, puzzle_rule_pieces.dart, puzzle_drop.dart, puzzle_painter.dart, piece_colors.dart (find the rest from these) · the puzzle level files the library loads
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

The owner's report, in their words: "Some puzzles have shapes that are nearly or are identical in size (eg the triangle wings on the butterfly) but the puzzle pieces are not interchangeable and it's not clear to the player which or should go where. This needs to be fixed. Either the pieces can go in either slot or there needs to be an indication to the player which piece should go where. ... scan all puzzles for this issue." In the screenshot the butterfly has two large triangle wings (a brown piece and a purple piece) whose dashed slots look the same, and two small triangles likewise.

Claude's design:
1. **Twins are interchangeable.** Two pieces of one puzzle are *twins* when one outline can be laid on the other by rotation alone (the game lets a player rotate, not flip), with every matching side and corner within 3 % of the piece's size. A twin piece fits any of its twins' slots, at any rotation that makes the outlines coincide, and the puzzle is solved when every slot holds a piece that fits it. Do this in the fit rule, computed from the outlines when the puzzle loads, not by hand-editing levels. Scoring, the "N of M placed" count, the carry/drop rules, Robo's piece choice and the mirror view must all keep working when a piece sits in its twin's slot.
2. **Look-alikes get a colour hint.** Two pieces that are not twins but that a player cannot tell apart at a glance (mirror images of each other, or the same shape with sizes within 15 %) are *look-alikes*. For every look-alike piece, its slot's dashed outline is drawn in that piece's own colour (readable in both the sunny and the night look) instead of the plain outline colour; all other slots stay as they are. The same on the joined phone's view and the mirror view if they draw slots.
3. **Scan every puzzle.** A test walks every puzzle in the library and lists each twin group and each look-alike pair; it fails if a pair of look-alike or twin pieces exists that the rule above does not cover (so a new puzzle cannot bring the bug back). Put the list (puzzle, pieces, twin or look-alike) in the report.
4. A slot never accepts a piece that does not coincide with it: no loosening of the fit tolerance for other pieces.

tests (each failing first): twins fit each other's slots and the puzzle completes; a mirror pair does not swap and its slots carry the hint colour; a rotated twin fit; the library scan; Robo completes a puzzle with twins. All existing suites pass.

in the report: start with `## Summary` (at most 20 lines): what a player now sees, the files changed, decisions, anything not done, and what the owner should try on a device (one line each). Then the scan's list, and Self-check: docs/review-rules.md part A, items 1–5, one line each.
rules: aim for under 150 turns · no lib file you touch may end over 380 lines: split it (the runner stops the run otherwise) · no function over 60 lines · tests first: each new test file must fail on the code as it was (the runner checks this) · every text a player sees goes through the text files, never a literal in a widget · write only inside this job's folder · leave no scratch file behind in the repository
allow: docs/briefs/m14/bugs1/p1-puzzle-twins-report.md · packages/puzzle_game · assets
check: format analyze puzzle host phone
report: docs/briefs/m14/bugs1/p1-puzzle-twins-report.md
