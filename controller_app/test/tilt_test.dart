import 'dart:math';

import 'package:controller/src/tilt.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Up" in phone coordinates for a phone held in landscape-left (top of the
/// phone on the left), upright in front of you (screen facing you), then
/// turned like a steering wheel by [steer] degrees (positive = clockwise,
/// to the right).
Vec3 uprightLandscapeLeft({double steer = 0}) {
  final a = steer * pi / 180;
  // Upright: up is the screen's top, which is the phone's +x. Turning the
  // phone clockwise makes up lean towards the screen's left, the phone's +y.
  return Vec3(cos(a), sin(a), 0);
}

/// Landscape-left lying flat (screen to the sky), tipped forward (top edge
/// down) by [forward] degrees and right edge down by [right] degrees.
Vec3 flatLandscapeLeft({double forward = 0, double right = 0}) {
  final f = forward * pi / 180;
  final r = right * pi / 180;
  // Flat: up is +z. Right edge down leans up towards screen-left (+y).
  // Top edge down leans up away from the top (-x).
  return Vec3(-sin(f), sin(r), cos(f) * cos(r)).normalized;
}

void main() {
  group('tilt angles', () {
    test('upright: steering right gives positive roll, pitch stays upright', () {
      final t = tiltOf(uprightLandscapeLeft(steer: 20), LandscapeSide.left);
      expect(t.roll, closeTo(20, 1e-6));
      expect(t.pitch, closeTo(90, 1e-6));
    });

    test('flat: right edge down gives positive roll', () {
      expect(tiltOf(flatLandscapeLeft(right: 15), LandscapeSide.left).roll, closeTo(15, 1e-6));
    });

    test('flat: tipping forward lowers the pitch', () {
      expect(tiltOf(flatLandscapeLeft(forward: 10), LandscapeSide.left).pitch, closeTo(-10, 1e-6));
    });

    test('the other landscape side mirrors the axes', () {
      // Landscape-right is the same physical pose with the phone's x and y negated.
      final left = uprightLandscapeLeft(steer: 25);
      final right = Vec3(-left.x, -left.y, left.z);
      expect(tiltOf(right, LandscapeSide.right).roll, closeTo(25, 1e-6));
    });

    test('tells the landscape side from the up direction', () {
      expect(landscapeSideOf(uprightLandscapeLeft()), LandscapeSide.left);
      expect(landscapeSideOf(const Vec3(-1, 0, 0)), LandscapeSide.right);
      expect(landscapeSideOf(const Vec3(0, 0, 1)), isNull, reason: 'too flat to tell');
    });

    test('angle differences wrap around', () {
      expect(angleDelta(179, -179), closeTo(-2, 1e-9));
      expect(angleDelta(-170, 170), closeTo(20, 1e-9));
    });
  });

  group('up estimator', () {
    final t0 = DateTime(2026);

    test('starts from the accelerometer', () {
      final e = UpEstimator()..accelerometer(const Vec3(0, 9.81, 0));
      expect(e.up!.y, closeTo(1, 1e-9));
    });

    test('follows the gyroscope: turning the phone left makes up lean right', () {
      final e = UpEstimator(accelWeight: 0)..accelerometer(const Vec3(0, 9.81, 0));
      // 1 rad/s counter-clockwise around the screen normal for 0.5 s.
      for (var i = 0; i <= 50; i++) {
        e.gyroscope(const Vec3(0, 0, 1), t0.add(Duration(milliseconds: i * 10)));
      }
      expect(e.up!.x, closeTo(sin(0.5), 0.01));
      expect(e.up!.y, closeTo(cos(0.5), 0.01));
    });

    test('the accelerometer removes gyro drift', () {
      final e = UpEstimator()..accelerometer(const Vec3(0, 9.81, 0));
      // A biased gyro (0.05 rad/s) while the phone really stays still.
      for (var i = 0; i <= 1000; i++) {
        e.gyroscope(const Vec3(0, 0, 0.05), t0.add(Duration(milliseconds: i * 10)));
      }
      // Without correction it would have drifted 0.5 rad (29°); now it stays within ~2°.
      expect(asin(e.up!.x) * 180 / pi, lessThan(2.5));
    });

    test('ignores the accelerometer while the phone is shaken', () {
      final e = UpEstimator(accelWeight: 0.5)..accelerometer(const Vec3(0, 9.81, 0));
      e.gyroscope(const Vec3(0, 0, 0), t0);
      e.accelerometer(const Vec3(30, 9.81, 0)); // About 3 g sideways.
      e.gyroscope(const Vec3(0, 0, 0), t0.add(const Duration(milliseconds: 10)));
      expect(e.up!.y, closeTo(1, 1e-9));
    });

    test('skips a long gap instead of jumping', () {
      final e = UpEstimator(accelWeight: 0)..accelerometer(const Vec3(0, 9.81, 0));
      e.gyroscope(const Vec3(0, 0, 3), t0);
      e.gyroscope(const Vec3(0, 0, 3), t0.add(const Duration(seconds: 2)));
      expect(e.up!.y, closeTo(1, 1e-9));
    });
  });

  group('stick values', () {
    test('normalization: 30° is full deflection at sensitivity 1, 15° at 2', () {
      expect(normalizeTilt(15, -30, 1), (x: 0.5, y: -1.0));
      expect(normalizeTilt(15, 0, 2).x, 1.0);
      expect(normalizeTilt(90, 0, 1).x, 1.0, reason: 'clamped');
    });

    test('dead zone: nothing inside, rescaled outside', () {
      expect(applyDeadZone(0.04, 0.02, 0.1), (x: 0.0, y: 0.0));
      final v = applyDeadZone(0.55, 0, 0.1);
      expect(v.x, closeTo(0.5, 1e-9));
      expect(applyDeadZone(1, 0, 0.1).x, closeTo(1, 1e-9));
    });

    test('a bigger dead zone removes small jitter', () {
      final jitter = [0.02, -0.03, 0.04, -0.01];
      expect(jitter.map((j) => applyDeadZone(j, j, 0.0).x).any((v) => v != 0), isTrue);
      expect(jitter.map((j) => applyDeadZone(j, j, 0.1).x).every((v) => v == 0), isTrue);
    });
  });

  group('TiltProcessor', () {
    test('the first reading becomes neutral, so holding still reads zero', () {
      final p = TiltProcessor();
      const pose = (roll: 12.0, pitch: 55.0);
      for (var i = 0; i < 20; i++) {
        expect(p.process(pose), (x: 0.0, y: 0.0));
      }
      expect(p.calibrated, isTrue);
    });

    test('calibrate sets a new neutral', () {
      final p = TiltProcessor(settings: const GyroSettings(smoothing: 0, deadZone: 0));
      p.calibrate((roll: 0, pitch: 40));
      expect(p.process((roll: 15, pitch: 40)).x, closeTo(0.5, 1e-9));
      p.calibrate((roll: 15, pitch: 40));
      expect(p.process((roll: 15, pitch: 40)).x, 0);
    });

    test('tipping forward gives negative y (like up on the D-pad)', () {
      final p = TiltProcessor(settings: const GyroSettings(smoothing: 0, deadZone: 0))..calibrate((roll: 0, pitch: 60));
      expect(p.process((roll: 0, pitch: 45)).y, closeTo(-0.5, 1e-9));
    });

    test('higher sensitivity makes the same tilt larger', () {
      double at(double sensitivity) {
        final p = TiltProcessor(settings: GyroSettings(sensitivity: sensitivity, smoothing: 0, deadZone: 0))
          ..calibrate((roll: 0, pitch: 0));
        return p.process((roll: 10, pitch: 0)).x;
      }

      expect(at(2), greaterThan(at(1)));
    });

    test('smoothing eases towards a sudden change', () {
      final p = TiltProcessor(settings: const GyroSettings(smoothing: 0.5, deadZone: 0))
        ..calibrate((roll: 0, pitch: 0));
      final first = p.process((roll: 30, pitch: 0)).x;
      final second = p.process((roll: 30, pitch: 0)).x;
      expect(first, closeTo(0.5, 1e-9));
      expect(second, closeTo(0.75, 1e-9));
    });
  });
}
