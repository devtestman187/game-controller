import 'dart:math';

import 'package:controller/src/layout.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/pad_drawing.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:controller/src/ui/stick_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyLook, ToyLookScope, ToyPalette, ToySizes, toyShadowAlpha;
import 'package:protocol/protocol.dart';

import 'support/pixels.dart';
import 'support/pump_app.dart';

/// The painters are painted on a square of this side, as the pad draws them:
/// big enough for the shadow's offset to show.
const _side = 200.0;

final _sunny = ToyLook.build(palette: ToyPalette.sunny, tv: false);
final _night = ToyLook.build(palette: ToyPalette.night, tv: false);

const _geometry = FaceGeometry.classic;
final _faceRadius = _geometry.radius * _side;
const _buttons = [ControllerButton.a, ControllerButton.b, ControllerButton.x, ControllerButton.y];

/// The look's hard shadow as a test's pixels read it over white: ink at
/// [toyShadowAlpha] on the white behind.
(int, int, int) shadowOf(ToyLook look) => blend(rgb(look.colors.ink), whiteRgb, toyShadowAlpha);

Offset centreOf(ControllerButton button) => _geometry.centers[button]! * _side;

/// A pixel inside a face button's disc but clear of its letter.
Offset fillProbe(ControllerButton button) => centreOf(button) + Offset(_faceRadius * 0.6, 0);

/// A pixel the disc's shadow shows in, and its moved body covers when it's
/// pressed: half the shadow's offset beyond the disc along the offset's way.
Offset squishProbe(ControllerButton button) {
  final offset = ToySizes.shadowOffset;
  return centreOf(button) + offset / offset.distance * (_faceRadius + offset.distance / 2);
}

/// The pixel at [where], as the painters' pixels are indexed.
void expectAt(Pixels pixels, Offset where, (int, int, int) expected, {String? reason}) =>
    expectPixel(pixels, where.dx.floor(), where.dy.floor(), expected, reason: reason);

Future<Pixels> paintFaces(
  ToyLook look, {
  Set<ControllerButton> pressed = const {},
  Set<ControllerButton> hidden = const {},
  Map<ControllerButton, String> labels = const {},
}) => paintedPixels(
  const Size.square(_side),
  (canvas) => FaceButtonsPainter(
    look: look,
    side: _side,
    pressed: pressed,
    geometry: _geometry,
    labels: labels,
    hidden: hidden,
  ).paint(canvas, const Size.square(_side)),
);

Future<Pixels> paintDpad(ToyLook look, {int dx = 0, int dy = 0, int? player}) => paintedPixels(
  const Size.square(_side),
  (canvas) => DpadPainter(look: look, dx: dx, dy: dy, player: player).paint(canvas, const Size.square(_side)),
);

const _stickCanvas = Size(120, 120);
const _stickCentre = Offset(60, 60);
const _stickRadius = 50.0;

/// A pixel in the knob's shadow's crescent, which the held knob's body covers
/// instead: half the shadow's offset beyond the knob along the offset's way.
Offset knobShadowProbe() {
  final offset = ToySizes.shadowOffset;
  final knob = max(14.0, _stickRadius * 0.42);
  return _stickCentre + offset / offset.distance * (knob + offset.distance / 2);
}

Future<Pixels> paintStick(ToyLook look, {bool active = false, bool faint = false, int? player}) => paintedPixels(
  _stickCanvas,
  (canvas) => StickPainter(
    look: look,
    center: _stickCentre,
    radius: _stickRadius,
    value: stickCenter,
    active: active,
    faint: faint,
    player: player,
  ).paint(canvas, _stickCanvas),
);

/// Where the knob's outline starts down the stick's middle: the knob's edge in
/// the pixels, in the column the knob's own centre is on.
int? knobEdgeRow(Pixels pixels) {
  final paper = rgb(_sunny.colors.paper);
  for (var y = 30; y <= 60; y++) {
    final p = pixels.at(60, y);
    if ((p.$1 - paper.$1).abs() > 8 || (p.$2 - paper.$2).abs() > 8 || (p.$3 - paper.$3).abs() > 8) return y;
  }
  return null;
}

const _smallSize = Size(96, 44);
const _smallAt = Offset(10, 10);
const _smallCanvas = Size(120, 70);

Future<Pixels> paintSmall(ToyLook look, {bool pressed = false, int? player}) => paintedPixels(_smallCanvas, (canvas) {
  canvas.translate(_smallAt.dx, _smallAt.dy);
  SmallButtonPainter(look: look, pressed: pressed, player: player).paint(canvas, _smallSize);
});

void main() {
  group('the face buttons (M13 step 8, rule 2)', () {
    for (final (name, look) in [('Sunny', _sunny), ('Night', _night)]) {
      test('$name: each is its face colour, with the look\'s shadow under it', () async {
        final pixels = await paintFaces(look);
        final face = faceFills(look.colors);
        for (final button in _buttons) {
          expectAt(pixels, fillProbe(button), rgb(face[button]!), reason: '${button.name} is filled');
          expectAt(pixels, squishProbe(button), shadowOf(look), reason: '${button.name} casts the shadow');
        }
      });
    }

    test('the face colours are the look\'s, the same in both palettes', () {
      expect(faceFills(_night.colors), faceFills(_sunny.colors));
      expect(faceFills(_sunny.colors).values, containsAll([_sunny.colors.faceA, _sunny.colors.faceB]));
    });

    test('pressed, the body moves by the shadow\'s offset and the shadow goes', () async {
      const button = ControllerButton.a;
      final face = faceFills(_sunny.colors)[button]!;
      final rest = await paintFaces(_sunny);
      final pressed = await paintFaces(_sunny, pressed: {button});
      final column = centreOf(button).dx.floor();
      // The crescent was the shadow; now the moved body covers it instead.
      expectAt(pressed, squishProbe(button), rgb(face), reason: 'the body covers its own shadow');
      // The disc's top edge moved down by the shadow's offset.
      final top = firstRow(rest, column, 120, 160, rgb(face))!;
      final moved = firstRow(pressed, column, 120, 160, rgb(face))!;
      expect(moved - top, inInclusiveRange(3, 5), reason: 'by the shadow\'s 4 px down, to a pixel of antialiasing');
      expectAt(pressed, fillProbe(ControllerButton.b), rgb(faceFills(_sunny.colors)[ControllerButton.b]!));
    });

    test('a hidden button has no fill where its disc was, and no shadow', () async {
      final pixels = await paintFaces(_sunny, hidden: {ControllerButton.y});
      expectAt(pixels, fillProbe(ControllerButton.y), rgb(white), reason: 'no fill');
      expectAt(pixels, squishProbe(ControllerButton.y), rgb(white), reason: 'no shadow');
      expectAt(pixels, fillProbe(ControllerButton.x), rgb(_sunny.colors.faceX), reason: 'the others stay');
    });

    // Claude's step 8 review: ink at the shadow's strength all but vanished on
    // Night's grape. The outline sits on the background, not on paper, so it
    // takes the background's text colour, faint.
    test("a hidden button's outline is the background's text colour, faint, in both palettes", () {
      for (final look in [_sunny, _night]) {
        expect(padHiddenOutline(look), look.colors.onBackground.withValues(alpha: toyShadowAlpha));
      }
    });

    test('letters are ink in the button family and labels ink in the body', () {
      final letter = padLetter('A', _sunny, 20);
      final label = padLabel('Jump', _sunny, 9);
      final letterStyle = (letter.text! as TextSpan).style!;
      final labelStyle = (label.text! as TextSpan).style!;
      expect(letterStyle.color, _sunny.colors.ink, reason: 'text on a face colour is ink (D12)');
      expect(letterStyle.fontFamily, _sunny.type.button.fontFamily);
      expect(labelStyle.color, _sunny.colors.ink);
      expect(labelStyle.fontFamily, _sunny.type.body.fontFamily);
      letter.dispose();
      label.dispose();
    });
  });

  group('the D-pad (M13 step 8, rule 4)', () {
    test('the plus is paper and its lit arm this phone\'s player\'s colour', () async {
      final player3 = await paintDpad(_sunny, dx: 1, player: 3);
      expectAt(player3, const Offset(120, 80), rgb(_sunny.colors.player(3)), reason: 'the right arm is lit');
      expectAt(player3, const Offset(80, 80), rgb(_sunny.colors.paper), reason: 'the up arm stays paper');
      final unknown = await paintDpad(_sunny, dx: 1);
      expectAt(unknown, const Offset(120, 80), rgb(_sunny.colors.player(1)), reason: 'player 1 before one is known');
    });

    test('a diagonal lights and squishes both of its arms', () async {
      final pixels = await paintDpad(_sunny, dx: 1, dy: 1, player: 3);
      final colour = rgb(_sunny.colors.player(3));
      expectAt(pixels, const Offset(120, 80), colour, reason: 'the right arm');
      expectAt(pixels, const Offset(80, 120), colour, reason: 'the down arm');
      // Each lit arm's fill starts the shadow's offset inside its outline.
      expect(firstRow(pixels, 120, 60, 100, colour), 70, reason: 'the right arm\'s top is moved down');
      expect(firstColumn(pixels, 120, 60, 100, colour), 69, reason: 'the down arm\'s left is moved right');
    });

    test('one shadow under the whole plus, and no seam where the arms meet', () async {
      final pixels = await paintDpad(_sunny);
      expectAt(pixels, const Offset(50, 136), shadowOf(_sunny), reason: 'the shadow under the left arm');
      for (final seam in const [Offset(66, 100), Offset(134, 100), Offset(100, 66), Offset(100, 134)]) {
        expectAt(pixels, seam, rgb(_sunny.colors.paper), reason: 'no ink line where the arms meet at $seam');
      }
    });

    test('the centre dot is ink at toyShadowAlpha and paper lies beside it', () async {
      final pixels = await paintDpad(_sunny);
      final dot = blend(rgb(_sunny.colors.ink), rgb(_sunny.colors.paper), toyShadowAlpha);
      expectAt(pixels, const Offset(100, 100), dot, reason: 'the centre dot');
      for (final beside in const [Offset(75, 100), Offset(125, 100), Offset(100, 75), Offset(100, 125)]) {
        expectAt(pixels, beside, rgb(_sunny.colors.paper), reason: 'paper beside the dot at $beside');
      }
    });
  });

  group('the sticks (M13 step 8, rule 5)', () {
    test('held, the knob is the player\'s colour and pushed in out of its shadow', () async {
      final pixels = await paintStick(_sunny, active: true, player: 3);
      final colour = rgb(_sunny.colors.player(3));
      expectAt(pixels, _stickCentre, colour, reason: 'the knob is player 3\'s');
      expectAt(pixels, knobShadowProbe(), colour, reason: 'the moved knob covers where the shadow was');
      expect(knobEdgeRow(pixels), 41, reason: 'the held knob\'s edge is the shadow\'s offset lower (37 + 4)');
    });

    test('not held, the knob keeps its faded colour and casts the look\'s shadow', () async {
      final pixels = await paintStick(_sunny, player: 3);
      // The faded knob lets its own shadow show through it, as the look's
      // translucent fills do.
      final under = blend(rgb(_sunny.colors.ink), rgb(_sunny.colors.paper), toyShadowAlpha);
      final faded = blend(rgb(_sunny.colors.player(3)), under, StickPainter.idleAlpha);
      expectAt(pixels, _stickCentre, faded);
      expectAt(
        pixels,
        knobShadowProbe(),
        blend(rgb(_sunny.colors.ink), rgb(_sunny.colors.paper), toyShadowAlpha),
        reason: 'the shadow beside the knob',
      );
      expect(knobEdgeRow(pixels), 37, reason: 'the knob\'s edge at rest, where it was before the look');
    });

    test('a faint stick multiplies everything as it did', () async {
      final pixels = await paintStick(_sunny, faint: true, player: 3);
      final base = blend(rgb(_sunny.colors.paper), whiteRgb, StickPainter.faintAlpha);
      expectAt(pixels, const Offset(60, 13), base, reason: 'the base is paper at the faint alpha');
      final under = blend(rgb(_sunny.colors.ink), base, toyShadowAlpha);
      final knob = blend(rgb(_sunny.colors.player(3)), under, StickPainter.idleAlpha * StickPainter.faintAlpha);
      expectAt(pixels, _stickCentre, knob, reason: 'the knob fades with the stick');
    });
  });

  group('a small button (M13 step 8, rule 6)', () {
    test('unpressed it is a paper pill with the look\'s shadow', () async {
      final pixels = await paintSmall(_sunny);
      expectAt(pixels, const Offset(58, 32), rgb(_sunny.colors.paper));
      expectAt(pixels, const Offset(50, 57), shadowOf(_sunny), reason: 'the shadow below the pill');
    });

    test('pressed it fills with the player\'s colour and is pushed in', () async {
      final pixels = await paintSmall(_sunny, pressed: true, player: 3);
      expectAt(pixels, const Offset(58, 32), rgb(_sunny.colors.player(3)));
      expectAt(pixels, const Offset(50, 57), rgb(_sunny.colors.ink), reason: 'its edge is where its shadow was');
    });
  });

  group('PressFlash (M13 step 8, rule 3)', () {
    testWidgets('a press flashes the look\'s paper, not white', (tester) async {
      final app = await pumpApp(tester, paired: true, extra: [flashOnPressProvider.overrideWithValue(true)]);
      app.client.emit(connected.copyWith(player: 1));
      await settle(tester);
      final faceButtons = find.byKey(const Key('faceButtons'));
      final look = ToyLookScope.of(tester.element(faceButtons));
      final square = tester.getSize(faceButtons).width;
      final onA = tester.getTopLeft(faceButtons) + _geometry.centers[ControllerButton.a]! * square;
      final gesture = await tester.startGesture(onA);
      await tester.pump();
      final frame = find.byKey(const Key('pressFlash'));
      final painter = tester.widget<CustomPaint>(find.descendant(of: faceButtons, matching: frame)).foregroundPainter!;
      final pixels = await tester.runAsync(
        () => paintedPixels(Size.square(square), (canvas) => painter.paint(canvas, Size.square(square))),
      );
      final centre = _geometry.centers[ControllerButton.a]! * square + Offset(_geometry.radius * square * 0.5, 0);
      expectAt(pixels!, centre, blend(rgb(look.colors.paper), whiteRgb, PressFlash.alpha), reason: 'paper at 75%');
      await gesture.up();
    });
  });
}
