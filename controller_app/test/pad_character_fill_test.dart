import 'package:connection/connection.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/tilt.dart';
import 'package:controller/src/ui/pad_drawing.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:controller/src/ui/stick_widgets.dart';
import 'package:controller/src/ui/tilt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyLook, ToyLookScope, ToyPalette;
import 'package:protocol/protocol.dart';

import 'support/pixels.dart';
import 'support/pump_app.dart';

/// The D-pad is painted on a square of this side, as pad_look_test paints it.
const _side = 200.0;

const _smallSize = Size(96, 44);
const _smallCanvas = Size(120, 70);
const _smallAt = Offset(10, 10);

const _stickCanvas = Size(120, 120);
const _stickCentre = Offset(60, 60);
const _stickRadius = 50.0;

/// This phone's player number: the fill that a character's colour must beat.
const _playerNumber = 3;

/// The colour slot of the character the host gave this phone. It is not the
/// player number's own slot, so a fill that ignores the character shows.
const _characterSlot = 5;

/// The character the host gave this phone (M16 identity, fpad).
final _character = PlayerCharacter(colourSlot: _characterSlot, accessory: PlayerAccessory.values.first);

/// The looks every fill is checked under: the menu's and the TV's, in both
/// palettes (review-rules part A item 6).
final _looks = <(String, ToyLook)>[
  ('the sunny menu', ToyLook.build(palette: ToyPalette.sunny, tv: false)),
  ('the night menu', ToyLook.build(palette: ToyPalette.night, tv: false)),
  ('the sunny TV', ToyLook.build(palette: ToyPalette.sunny, tv: true)),
  ('the night TV', ToyLook.build(palette: ToyPalette.night, tv: true)),
];

/// The D-pad with its right arm lit, painted with [character] (or none).
Future<Pixels> _dpad(ToyLook look, PlayerCharacter? character) => paintedPixels(
  const Size.square(_side),
  (canvas) => DpadPainter(
    look: look,
    dx: 1,
    dy: 0,
    fill: PadFill(player: _playerNumber, character: character),
  ).paint(canvas, const Size.square(_side)),
);

/// A pressed small button, painted with [character] (or none).
Future<Pixels> _small(ToyLook look, PlayerCharacter? character) => paintedPixels(_smallCanvas, (canvas) {
  canvas.translate(_smallAt.dx, _smallAt.dy);
  SmallButtonPainter(
    look: look,
    pressed: true,
    fill: PadFill(player: _playerNumber, character: character),
  ).paint(canvas, _smallSize);
});

/// A stick held down, so its knob is drawn in full colour, painted with
/// [character] (or none).
Future<Pixels> _stick(ToyLook look, PlayerCharacter? character) => paintedPixels(
  _stickCanvas,
  (canvas) => StickPainter(
    look: look,
    center: _stickCentre,
    radius: _stickRadius,
    value: stickCenter,
    active: true,
    faint: false,
    fill: PadFill(player: _playerNumber, character: character),
  ).paint(canvas, _stickCanvas),
);

/// The tilt dot's colour and the look it was drawn in, once the phone is in gyro
/// mode with [character] (or none) from the host.
Future<(Color, ToyLook)> _tiltDot(WidgetTester tester, PlayerCharacter? character) async {
  final app = await pumpApp(tester, paired: true);
  app.client.emit(
    ClientSnapshot(
      status: ClientStatus.connected,
      target: tv,
      hostName: 'Android TV',
      player: _playerNumber,
      character: character,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Gyro'));
  await tester.pump();
  app.motion.hold(const Vec3(1, 0, 0), samples: 50);
  await tester.pump(const Duration(milliseconds: 100));
  final look = ToyLookScope.of(tester.element(find.byType(TiltDot)));
  return (tester.widget<TiltDot>(find.byType(TiltDot)).dot, look);
}

void main() {
  for (final (name, look) in _looks) {
    group('the pad fill, in $name', () {
      test('the D-pad\'s lit arm takes the character\'s colour over the player\'s', () async {
        final pixels = await _dpad(look, _character);
        expectPixel(
          pixels,
          120,
          80,
          rgb(look.colors.player(_characterSlot)),
          reason: 'the lit arm is the character\'s colour',
        );
      });

      test('the D-pad\'s lit arm takes the player\'s colour without a character', () async {
        final pixels = await _dpad(look, null);
        expectPixel(
          pixels,
          120,
          80,
          rgb(look.colors.player(_playerNumber)),
          reason: 'no character: the player\'s colour',
        );
      });

      test('a pressed small button takes the character\'s colour over the player\'s', () async {
        final pixels = await _small(look, _character);
        expectPixel(
          pixels,
          58,
          32,
          rgb(look.colors.player(_characterSlot)),
          reason: 'the pressed pill is the character\'s colour',
        );
      });

      test('a pressed small button takes the player\'s colour without a character', () async {
        final pixels = await _small(look, null);
        expectPixel(
          pixels,
          58,
          32,
          rgb(look.colors.player(_playerNumber)),
          reason: 'no character: the player\'s colour',
        );
      });

      test('a held stick\'s knob takes the character\'s colour over the player\'s', () async {
        final pixels = await _stick(look, _character);
        expectPixel(
          pixels,
          60,
          60,
          rgb(look.colors.player(_characterSlot)),
          reason: 'the knob is the character\'s colour',
        );
      });

      test('a held stick\'s knob takes the player\'s colour without a character', () async {
        final pixels = await _stick(look, null);
        expectPixel(
          pixels,
          60,
          60,
          rgb(look.colors.player(_playerNumber)),
          reason: 'no character: the player\'s colour',
        );
      });
    });
  }

  group('the tilt dot (M16 identity, fpad)', () {
    testWidgets('the dot takes the character\'s colour over the player\'s', (tester) async {
      final (dot, look) = await _tiltDot(tester, _character);
      expect(dot, look.colors.player(_characterSlot), reason: 'the dot is the character\'s colour');
    });

    testWidgets('the dot takes the player\'s colour without a character', (tester) async {
      final (dot, look) = await _tiltDot(tester, null);
      expect(dot, look.colors.player(_playerNumber), reason: 'no character: the player\'s colour');
    });
  });
}
