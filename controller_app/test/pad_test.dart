import 'package:controller/src/haptics.dart';
import 'package:controller/src/pad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  group('D-pad direction (pad of side 200, center 100,100)', () {
    (int, int) at(double x, double y) => dpadDirection(Offset(x, y), 200);

    test('the middle is a dead zone', () => expect(at(105, 95), (0, 0)));
    test('straight directions', () {
      expect(at(190, 100), (1, 0));
      expect(at(10, 100), (-1, 0));
      expect(at(100, 10), (0, -1));
      expect(at(100, 190), (0, 1));
    });
    test('diagonals', () {
      expect(at(180, 20), (1, -1));
      expect(at(20, 180), (-1, 1));
    });
    test('straight directions get the wider share (60° vs 30°)', () {
      // 25° below "right" still counts as right; 40° counts as down-right.
      expect(at(100 + 80 * 0.906, 100 + 80 * 0.423), (1, 0));
      expect(at(100 + 80 * 0.766, 100 + 80 * 0.643), (1, 1));
    });
    test('a thumb that slides past the edge keeps its direction', () => expect(at(260, 100), (1, 0)));
  });

  group('face buttons (square of side 200)', () {
    test('each button is hit at its center', () {
      for (final MapEntry(key: button, value: center) in faceButtonCenters.entries) {
        expect(faceButtonAt(center * 200, 200), button);
      }
    });
    test('the middle and the corners hit nothing', () {
      expect(faceButtonAt(const Offset(100, 100), 200), isNull);
      expect(faceButtonAt(const Offset(5, 5), 200), isNull);
    });
  });

  group('PadTracker', () {
    test('a direction and two buttons are held at once (multi-touch)', () {
      final t = PadTracker();
      t.dpad(1, (1, 0));
      t.button(2, ControllerButton.a);
      final c = t.button(3, ControllerButton.b);
      expect(c.after, const PadInput(buttons: {ControllerButton.a, ControllerButton.b}, dx: 1));
      expect(c.presses, 1);
    });

    test('sliding a thumb from A to B releases A and presses B', () {
      final t = PadTracker()..button(1, ControllerButton.a);
      final c = t.button(1, ControllerButton.b);
      expect(c.after.buttons, {ControllerButton.b});
      expect([c.presses, c.releases], [1, 1]);
    });

    test('sliding off every button releases', () {
      final t = PadTracker()..button(1, ControllerButton.x);
      expect(t.button(1, null).after.isNeutral, isTrue);
    });

    test('lifting one finger keeps the others', () {
      final t = PadTracker()
        ..dpad(1, (0, -1))
        ..button(2, ControllerButton.y);
      final c = t.up(1);
      expect(c.after, const PadInput(buttons: {ControllerButton.y}));
      expect(c.directionChanged, isTrue);
    });

    test('release all clears everything', () {
      final t = PadTracker()
        ..dpad(1, (1, 1))
        ..button(2, ControllerButton.start);
      expect(t.releaseAll().after.isNeutral, isTrue);
      expect(t.current.isNeutral, isTrue);
    });

    test('the same direction again is not a change', () {
      final t = PadTracker()..dpad(1, (1, 0));
      expect(t.dpad(1, (1, 0)).changed, isFalse);
    });
  });

  group('tick strength', () {
    const none = PadInput();
    test('press and new direction: full', () {
      expect(const PadChange(none, PadInput(buttons: {ControllerButton.a})).tickStrength, 1);
      expect(const PadChange(none, PadInput(dx: 1)).tickStrength, 1);
    });
    test('release and re-centering: lighter', () {
      expect(const PadChange(PadInput(buttons: {ControllerButton.a}), none).tickStrength, 0.6);
      expect(const PadChange(PadInput(dx: 1), none).tickStrength, 0.6);
    });
    test('no change: no tick', () => expect(const PadChange(none, none).tickStrength, 0));
  });

  group('HapticsPlayer', () {
    Future<(HapticsPlayer, FakeHaptics)> loaded({HapticsCapabilities? caps}) async {
      final fake = FakeHaptics(
        caps: caps ?? const HapticsCapabilities(supported: true, intensityControl: true, engine: 'fake'),
      );
      final player = HapticsPlayer(fake);
      await player.load();
      return (player, fake);
    }

    test('scales ticks by the intensity setting', () async {
      final (player, fake) = await loaded();
      player.settings = const HapticSettings(intensity: 0.5);
      await player.tick();
      await player.tick(strength: 0.6);
      expect(fake.ticks, [0.5, closeTo(0.3, 1e-9)]);
    });

    test('plays nothing when turned off', () async {
      final (player, fake) = await loaded();
      player.settings = const HapticSettings(enabled: false);
      await player.tick();
      expect(fake.ticks, isEmpty);
    });

    test('plays nothing on hardware without haptics', () async {
      final (player, fake) = await loaded(caps: HapticsCapabilities.none);
      await player.tick();
      expect(fake.ticks, isEmpty);
    });

    test('keeps going when the native side fails', () async {
      final (player, fake) = await loaded();
      fake.failWith = Exception('engine gone');
      await player.tick();
      await player.tick();
      expect(player.lastError, contains('engine gone'));
    });
  });

  test('describes the input for the screen', () {
    expect(const PadInput(buttons: {ControllerButton.a}, dx: 1, dy: -1).toString(), 'A · D-pad up-right');
    expect(const PadInput().toString(), 'D-pad centered');
  });
}
