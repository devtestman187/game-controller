job: race1b r3d — present painter with a fuse warning, visible before any pop, also with Effects off
stop: no rules, no match.dart, no cat_chaos.dart, no host UI; touch puzzle_painter.dart by ONE call plus one constructor field
read: docs/briefs/templates/COMMON.md · packages/puzzle_game/lib/src/present.dart (from r3a: PresentState) · packages/puzzle_game/lib/src/puzzle_painter.dart:14-35 and :84-92 (ctor, cat field) and :124-155 (paint, the cat call to copy) · packages/puzzle_game/lib/src/cat_paint.dart:1-60 (painter taking look, style, effects) · packages/puzzle_game/lib/src/match_painter.dart:128-148, :176-195 (where cat is passed to PuzzlePainter) · packages/puzzle_game/test/cat_paint_test.dart:1-60 (painter test pattern, all looks) · owner plan: "Present painter and fuse warning (visible before any pop), under Effects off"
changes: paintPresent (new function) · PuzzlePainter.present · MatchPainter passes present
model: haiku
turns: 55
expected-min: 30
tests-first: exempt new painter; the test needs the new function first
touch-target: exempt a painted decoration, not a control; the fuse bar shrinks as a timer, not for layout
do:
1 New packages/puzzle_game/lib/src/present_paint.dart: `void paintPresent(Canvas canvas, PresentState present, {required PuzzleField field, required ToyLook look, required PuzzleSide side})`: draws a gift box (rounded square, ribbon cross, bow, colours from look.colors, ink outline) near the top centre of the board's field, only when `present.holder == side`. Fuse warning: a thin fuse bar under the box shrinks with fuseMs/fuseTotalMs, always drawn, also with look.effects false; when fuseMs <= 3000 the bar and box outline use the look's warning or accent colour and, only when look.effects is true, the box wiggles (small sine rotation by fuseMs). popped: draw only a burst of 8 short rays when look.effects is true (the host UI confetti is B11). Stay under 90 lines.
2 puzzle_painter.dart: add `this.present` (PresentState?) next to cat in the constructor and field (:88) and ONE call after the cat block (after line 150, before the comment at :151): `if (present case final p?) paintPresent(canvas, p, field: field, look: look, side: s.side ?? PuzzleSide.left);`. Import present_paint.dart and present.dart. No other change there.
3 match_painter.dart: at the two PuzzlePainter sites (about :132 and :178) pass `present: s.present`; the holder test inside paintPresent picks the side. Keep the mirror painter unchanged.
4 New test packages/puzzle_game/test/present_paint_test.dart, written and run first: paints on the holder's board and nothing on the other; the fuse bar is drawn with effects off and on; the warning colour appears at fuseMs 3000 and not at 8000; popped draws rays only with effects on; run under every look in the pattern of cat_paint_test.dart.
5 Before finishing run `dart analyze` on the files you changed and fix every info, warning and error.
allow: packages/puzzle_game/lib/src/present_paint.dart · packages/puzzle_game/lib/src/puzzle_painter.dart · packages/puzzle_game/lib/src/match_painter.dart · packages/puzzle_game/test/present_paint_test.dart · packages/puzzle_game/test/cat_paint_test.dart
check: format analyze
report: docs/briefs/m17/race1b/r3d-report.md
