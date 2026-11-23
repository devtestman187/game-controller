job: M16 identity1-clean cp: StickPainter takes player and character as one PadFill value (limit 5 named parameters)
pub: no
turns: 60
expected-min: 25
tests-first: exempt (pure refactor: behaviour unchanged; the existing pad tests are the proof, updated to the new constructor)
stop: after it. No behaviour, colour or layout change; TiltDot and padPlayerColour keep their signatures.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/ui/pad_drawing.dart:1-10 (padPlayerColour) · controller_app/lib/src/ui/stick_widgets.dart:165-281 (the stick widget build and StickPainter) · controller_app/lib/src/ui/pad_widgets.dart:150-195 and 268-360 (D-pad widget, DpadPainter, SmallButton and its painter; find the small button's own `player`/`character` reads with grep) · controller_app/test/pad_character_fill_test.dart:45-100 (painter constructions) · controller_app/test/pad_look_test.dart:60-115 (paintDpad, paintStick, paintSmall) · docs/coding-guidelines.md (5 named parameters at most)
changes: PadFill · StickPainter · DpadPainter · SmallButtonPainter
decisions (owner, Nov 23): StickPainter has 8 named parameters (limit 5): pass player and character as one fill value; DpadPainter and SmallButtonPainter the same so the three painters stay consistent; TiltDot is untouched (it already takes a colour).
do:
1 In pad_drawing.dart add `class PadFill`: const constructor `PadFill({this.player, this.character})`, final `int? player` and `PlayerCharacter? character`, a method `Color colour(ToyColors colors)` that returns `padPlayerColour(colors, player, character: character)`, and `==` / `hashCode` over both fields. Doc comment: what a pad part is filled with.
2 StickPainter, DpadPainter and SmallButtonPainter: replace their `player` and `character` fields by one `final PadFill fill` (constructor `this.fill = const PadFill()`); paint with `fill.colour(look.colors)`; `shouldRepaint` compares `old.fill != fill`. Update the three widgets that build them: `fill: PadFill(player: player, character: character)`.
3 Update the existing tests' painter constructions to `fill: PadFill(player: ..., character: ...)` in pad_character_fill_test.dart and pad_look_test.dart. Keep every assertion and test name; add no test.
4 Run `flutter test controller_app/test/pad_character_fill_test.dart` and `flutter test controller_app/test/pad_look_test.dart`, then `tools/mine.sh`. Report the pass counts and each painter's named-parameter count.
allow: controller_app/lib/src/ui/pad_drawing.dart · controller_app/lib/src/ui/pad_widgets.dart · controller_app/lib/src/ui/stick_widgets.dart · controller_app/test/pad_character_fill_test.dart · controller_app/test/pad_look_test.dart · docs/briefs/m16/identity1-clean/cp-report.md
check: format analyze phone
report: docs/briefs/m16/identity1-clean/cp-report.md
