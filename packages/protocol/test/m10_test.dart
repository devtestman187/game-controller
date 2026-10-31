import 'dart:convert';

import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

const codec = MessageCodec();

Message? roundTrip(Message m) => codec.decode(codec.encode(m));

void main() {
  group('layout (P5)', () {
    test('labels, hidden buttons and allowed modes round-trip', () {
      final m = GameLayoutMessage(
        modes: ['dpad', 'sticks'],
        defaultMode: 'sticks',
        labels: {ControllerButton.a: 'Pick up', ControllerButton.x: 'Rotate ⟳'},
        hidden: {ControllerButton.b, ControllerButton.lb},
      );
      final back = roundTrip(m) as GameLayoutMessage;
      expect(back, m);
      expect(back.labels[ControllerButton.x], 'Rotate ⟳');
      expect(back.allows('gyro'), isFalse);
      expect(back.allows('sticks'), isTrue);
    });

    test('the standard layout clears everything and allows every mode', () {
      final back = roundTrip(GameLayoutMessage.standard()) as GameLayoutMessage;
      expect(back.isStandard, isTrue);
      expect(back.allows('gyro'), isTrue);
    });

    test('long labels are cut, unknown modes and buttons are ignored', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'layout',
        'modes': ['dpad', 'hover'],
        'default': 'hover',
        'labels': {'a': 'A label that is much too long', 'zz': 'x'},
        'hidden': ['b', 'paddle'],
      });
      final m = codec.decode(frame) as GameLayoutMessage;
      expect(m.modes, ['dpad']);
      expect(m.defaultMode, isNull);
      expect(m.labels, {ControllerButton.a: 'A label that'});
      expect(m.hidden, {ControllerButton.b});
    });
  });

  group('status (P6)', () {
    test('text, a turned polygon and progress round-trip', () {
      final m = StatusMessage(
        text: 'Holding: roof',
        shape: const StatusShape.polygon([(-1, 1), (0, -1), (1, 1)], color: 0xFFE53935, angle: 33.333),
        progress: 0.4567,
        warning: true,
      );
      final back = roundTrip(m) as StatusMessage;
      expect(back.text, 'Holding: roof');
      expect(back.shape!.points, [(-1.0, 1.0), (0.0, -1.0), (1.0, 1.0)]);
      expect(back.shape!.angle, 33.33);
      expect(back.progress, 0.46);
      expect(back.warning, isTrue);
    });

    test('a circle, and an empty status hides the panel', () {
      final c = roundTrip(StatusMessage(shape: const StatusShape.circle(color: 0xFF00FF00))) as StatusMessage;
      expect(c.shape!.circle, isTrue);
      expect((roundTrip(StatusMessage.hidden()) as StatusMessage).isHidden, isTrue);
    });

    test('limits: text length, point count, values clamped', () {
      final frame = jsonEncode({
        'v': protocolVersion,
        't': 'status',
        'text': 'x' * 100,
        'progress': 3,
        'shape': {
          'color': 1,
          'points': [
            for (var i = 0; i < 40; i++) [5, -5],
          ],
        },
      });
      final m = codec.decode(frame) as StatusMessage;
      expect(m.text, hasLength(StatusMessage.maxTextLength));
      expect(m.progress, 1.0);
      expect(m.shape!.points, hasLength(StatusShape.maxPoints));
      expect(m.shape!.points.first, (1.0, -1.0));
      expect(codec.encode(m).length, lessThan(1024));
    });
  });

  test('new haptic events have natural lengths, and old phones still know the v1 four', () {
    for (final e in HapticEvent.values) {
      expect(roundTrip(HapticEventMessage(event: e)), isA<HapticEventMessage>());
      expect(e.defaultDurationMs, greaterThan(0));
    }
    expect(HapticEvent.v1, [HapticEvent.hit, HapticEvent.success, HapticEvent.error, HapticEvent.rumble]);
    expect(
      roundTrip(HapticEventMessage(event: HapticEvent.dropReady)),
      HapticEventMessage(event: HapticEvent.dropReady),
    );
  });
}
