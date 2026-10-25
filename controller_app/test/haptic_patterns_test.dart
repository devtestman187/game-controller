import 'package:controller/src/haptic_patterns.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

void main() {
  test('every event has a pattern at its natural length', () {
    for (final e in HapticEvent.values) {
      final p = HapticPattern.forEvent(e);
      expect(p.segments, isNotEmpty, reason: e.name);
      expect(p.lengthMs, closeTo(e.defaultDurationMs, 1), reason: e.name);
      expect(p.peakIntensity, inInclusiveRange(0.5, 1.0), reason: e.name);
    }
  });

  test('the four patterns differ in shape, not just strength', () {
    String shape(HapticEvent e) =>
        HapticPattern.forEvent(e).segments
            .map((s) => '${s.isTap ? 'tap' : 'buzz'}${s.sharpness >= 0.5 ? '+' : '-'}')
            .join();
    final shapes = {for (final e in HapticEvent.values) shape(e)};
    expect(shapes, hasLength(HapticEvent.values.length));
  });

  test('success rises, error is two separate buzzes, hit starts with a tap', () {
    final success = HapticPattern.forEvent(HapticEvent.success).segments.where((s) => s.isTap).toList();
    expect(success.map((s) => s.intensity), orderedEquals([...success.map((s) => s.intensity)]..sort()));
    final error = HapticPattern.forEvent(HapticEvent.error).segments;
    expect(error, hasLength(2));
    expect(error[1].startMs, greaterThan(error[0].endMs), reason: 'a gap between the buzzes');
    expect(HapticPattern.forEvent(HapticEvent.hit).segments.first.isTap, isTrue);
  });

  test('intensity scales every segment', () {
    final full = HapticPattern.forEvent(HapticEvent.hit);
    final half = HapticPattern.forEvent(HapticEvent.hit, intensity: 0.5);
    for (var i = 0; i < full.segments.length; i++) {
      expect(half.segments[i].intensity, closeTo(full.segments[i].intensity / 2, 1e-9));
      expect(half.segments[i].sharpness, full.segments[i].sharpness);
    }
    expect(HapticPattern.forEvent(HapticEvent.hit, intensity: 0).peakIntensity, 0);
  });

  test('duration stretches hit, success and error in time', () {
    final normal = HapticPattern.forEvent(HapticEvent.success);
    final slow = HapticPattern.forEvent(HapticEvent.success, durationMs: 900);
    expect(slow.lengthMs, closeTo(900, 1));
    expect(slow.segments[1].startMs, closeTo(normal.segments[1].startMs * 2, 1e-9));
  });

  test('a rumble fills exactly its duration with a steady wobble', () {
    for (final ms in [20, 75, 300, 3000]) {
      final p = HapticPattern.forEvent(HapticEvent.rumble, durationMs: ms);
      expect(p.lengthMs, closeTo(ms, 1e-9), reason: '$ms ms');
      expect(p.segments.every((s) => !s.isTap && s.durationMs <= rumbleStepMs), isTrue);
      for (var i = 1; i < p.segments.length; i++) {
        expect(p.segments[i].startMs, closeTo(p.segments[i - 1].endMs, 1e-9), reason: 'no gaps');
      }
    }
  });

  test('they differ in pulses and length: 1 short thud, 3 taps, 2 buzzes, a long throb', () {
    // Separate pulses: segments (taps count as 15 ms) with a gap of 40 ms or more between them.
    int pulses(HapticEvent e) {
      final spans = [
        for (final s in HapticPattern.forEvent(e).segments) (s.startMs, s.isTap ? s.startMs + 15 : s.endMs),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      var count = 0;
      var end = -1000.0;
      for (final (start, stop) in spans) {
        if (start - end >= 40) count++;
        if (stop > end) end = stop;
      }
      return count;
    }

    expect(pulses(HapticEvent.hit), 1);
    expect(pulses(HapticEvent.success), 3);
    expect(pulses(HapticEvent.error), 2);
    expect(pulses(HapticEvent.rumble), 1);
    expect(HapticPattern.forEvent(HapticEvent.hit).lengthMs, lessThanOrEqualTo(100));
    expect(HapticPattern.forEvent(HapticEvent.rumble).lengthMs, greaterThanOrEqualTo(300));
    // The rumble throbs: strong and weak parts clearly apart.
    final levels = HapticPattern.forEvent(HapticEvent.rumble).segments.map((s) => s.intensity).toSet();
    expect(levels.reduce((a, b) => a > b ? a : b) - levels.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(0.4));
  });

  test('the wire format is [start, duration, intensity, sharpness] per segment', () {
    final wire = HapticPattern.forEvent(HapticEvent.error).toWire();
    expect(wire.first, [0, 110, 1.0, 1.0]);
    expect(wire.every((s) => s.length == 4), isTrue);
  });
}
