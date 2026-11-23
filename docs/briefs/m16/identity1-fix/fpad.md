job: M16 identity1-fix fpad: the phone pad fill takes the chosen character's colour
expected-min: 35
turns: 50
pub: no
stop: after it. No other change.
read: docs/briefs/templates/COMMON.md · controller_app/lib/src/ui/pad_drawing.dart:1-10 · controller_app/lib/src/ui/pad_widgets.dart:145-200 and :225-235 and :280-350 · controller_app/lib/src/ui/stick_widgets.dart:165-275 · controller_app/lib/src/ui/tilt_view.dart:15-110 · controller_app/test/pad_look_test.dart:1-120 (how painters are painted to pixels per look) · controller_app/test/support/pixels.dart · packages/party_host/test/support/all_looks.dart (the every-look helper) · packages/connection/lib/src/client_types.dart:105-115 (snapshot.character)
changes: padPlayerColour · DpadPainter · SmallButtonPainter · StickPainter · _TiltPainter
decision (owner, Nov 23, Q2): the phone's own pad fill takes the chosen character's colour (colourSlot), falling back to the number's colour without a character.
do:
1 pad_drawing.dart: `padPlayerColour(ToyColors colors, int? player, {PlayerCharacter? character})` returns `colors.player(character?.colourSlot ?? player ?? 1)` (PlayerCharacter from package:protocol).
2 DpadPainter (pad_widgets.dart:187), SmallButtonPainter (:325), StickPainter (stick_widgets.dart:200), TiltDot/_TiltPainter (tilt_view.dart): add an optional `character` field next to `player`, pass it to padPlayerColour, and include it in shouldRepaint. Their widgets read it with `ref.watch(clientStateProvider.select((s) => s.character))` next to the existing player watch.
3 New test file controller_app/test/pad_character_fill_test.dart: paint each of DpadPainter (lit arm), SmallButtonPainter (pressed), StickPainter (knob) to pixels under every look (menu looks and TV: `ToyLook.build(palette:..., tv: true)` as pad_look_test does) with a character of colour slot 5: the fill pixel equals `look.colors.player(5)`; with no character it equals `look.colors.player(number)`. Must fail on the old code. TiltDot: one widget test that the dot takes the character's colour.
allow: controller_app/lib/src/ui/pad_drawing.dart · controller_app/lib/src/ui/pad_widgets.dart · controller_app/lib/src/ui/stick_widgets.dart · controller_app/lib/src/ui/tilt_view.dart · controller_app/test/pad_character_fill_test.dart · controller_app/test/pad_look_test.dart · controller_app/test/pad_test.dart · controller_app/test/pad_badge_test.dart · controller_app/test/phone_look_test.dart · controller_app/test/mirror_pad_test.dart
check: format analyze phone
report: docs/briefs/m16/identity1-fix/fpad-report.md
