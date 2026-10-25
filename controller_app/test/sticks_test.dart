import 'dart:math';
import 'dart:ui';

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
      expect([s.deadZone, s.sensitivity, s.floating], [0.1, 1.0, false]);
    });
  });

  group('layout', () {
    // Landscape body sizes (safe area and the top bar taken off) for common
    // phones: iPhone SE, iPhone 15, iPhone 15 Pro Max, Pixel 7, Galaxy S24.
    const sizes = {
      'iPhone SE': Size(667, 300),
      'iPhone 15': Size(734, 318),
      'iPhone 15 Pro Max': Size(814, 355),
      'Pixel 7': Size(869, 352),
      'Galaxy S24': Size(780, 330),
    };

    for (final MapEntry(key: phone, value: size) in sizes.entries) {
      test('$phone: every control is on screen and none overlap', () {
        final layout = stickLayout(size);
        final screen = Offset.zero & size;
        final controls = layout.controls.entries.toList();
        for (final MapEntry(key: name, value: rect) in controls) {
          expect(
            screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
            reason: '$name $rect is outside $size',
          );
        }
        for (var i = 0; i < controls.length; i++) {
          for (var j = i + 1; j < controls.length; j++) {
            final overlap = controls[i].value.intersect(controls[j].value);
            expect(
              overlap.width <= 0 || overlap.height <= 0,
              isTrue,
              reason: '${controls[i].key} overlaps ${controls[j].key}',
            );
          }
        }
      });

      test('$phone: thumb-sized controls (sticks at least 110, buttons at least 90)', () {
        final layout = stickLayout(size);
        expect(layout.leftStick.width, greaterThanOrEqualTo(110));
        expect(layout.rightStick.width, greaterThanOrEqualTo(110));
        expect(layout.dpad.width, greaterThanOrEqualTo(90));
        expect(layout.faceButtons.width, greaterThanOrEqualTo(90));
      });
    }

    test('Xbox arrangement: left stick above the D-pad, A/B/X/Y above the right stick, Select left of Start', () {
      final l = stickLayout(const Size(734, 318));
      expect(l.leftStick.center.dy, lessThan(l.dpad.center.dy));
      expect(l.leftStick.center.dx, lessThan(l.dpad.center.dx));
      expect(l.faceButtons.center.dy, lessThan(l.rightStick.center.dy));
      expect(l.faceButtons.center.dx, greaterThan(l.rightStick.center.dx));
      expect(l.select.center.dx, lessThan(l.start.center.dx));
      expect(l.lb.center.dx, lessThan(l.rb.center.dx));
    });
  });
}
