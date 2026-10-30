import 'dart:math';

import 'package:controller/src/sticks.dart';
import 'package:flutter_test/flutter_test.dart';

double length(Stick s) => sqrt(s.x * s.x + s.y * s.y);

void main() {
  const plain = StickSettings(deadZone: 0, sensitivity: 1);

  group('stick values', () {
    test('half the travel is half deflection; up is negative y', () {
      final v = stickValue(const Offset(0, -25), 50, plain);
      expect(v.x, 0);
      expect(v.y, closeTo(-0.5, 1e-9));
    });

    test('a diagonal never exceeds full scale (unit circle)', () {
      final v = stickValue(const Offset(50, 50), 50, plain); // Corner of the square: length 1.41.
      expect(length(v), closeTo(1, 1e-9));
      expect(v.x, closeTo(v.y, 1e-9));
      expect(length(stickValue(const Offset(500, -300), 50, plain)), closeTo(1, 1e-9));
    });

    test('the dead zone removes small jitter and rescales the rest', () {
      const s = StickSettings(deadZone: 0.1, sensitivity: 1);
      for (final jitter in [const Offset(2, -1), const Offset(-3, 3), const Offset(0, 4.9)]) {
        expect(stickValue(jitter, 50, s), (x: 0.0, y: 0.0));
      }
      expect(stickValue(const Offset(50, 0), 50, s).x, closeTo(1, 1e-9));
      expect(stickValue(const Offset(27.5, 0), 50, s).x, closeTo(0.5, 1e-9));
    });

    test('higher sensitivity reaches full scale with less travel', () {
      const s = StickSettings(deadZone: 0, sensitivity: 2);
      expect(stickValue(const Offset(25, 0), 50, s).x, closeTo(1, 1e-9));
      expect(stickValue(const Offset(10, 0), 50, s).x, closeTo(0.4, 1e-9));
    });

    test('settings defaults', () {
      const s = StickSettings();
      expect([s.deadZone, s.sensitivity, s.floating, s.buttonSize], [0.1, 1.0, false, 0.75]);
    });
  });
}
