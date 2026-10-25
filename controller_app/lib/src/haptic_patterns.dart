import 'dart:math';

import 'package:protocol/protocol.dart';

/// One piece of a haptic pattern: a tap (a single crisp pulse, [durationMs]
/// 0) or a buzz lasting [durationMs]. Intensity and sharpness run from 0 to 1;
/// low sharpness feels round and heavy, high sharpness crisp and buzzy.
final class HapticSegment {
  const HapticSegment.tap(this.startMs, this.intensity, this.sharpness) : durationMs = 0;

  const HapticSegment.buzz(this.startMs, this.durationMs, this.intensity, this.sharpness);

  final double startMs;
  final double durationMs;
  final double intensity;
  final double sharpness;

  bool get isTap => durationMs <= 0;

  double get endMs => startMs + durationMs;

  /// What the native side receives: `[startMs, durationMs, intensity, sharpness]`.
  List<double> toWire() => [startMs, durationMs, intensity, sharpness];

  @override
  String toString() => isTap
      ? 'tap@${startMs.round()} ${intensity.toStringAsFixed(2)}/${sharpness.toStringAsFixed(2)}'
      : 'buzz@${startMs.round()}+${durationMs.round()} ${intensity.toStringAsFixed(2)}/${sharpness.toStringAsFixed(2)}';
}

/// The pattern the phone plays for a haptic event from the TV (PRD C6).
///
/// Each event has its own shape so they can be told apart without looking:
/// - **hit**: one heavy thump with a short fading tail.
/// - **success**: three rising taps, "da-da-DAA".
/// - **error**: two short, harsh buzzes, "bzz-bzz".
/// - **rumble**: a low, wobbling buzz for the whole duration.
///
/// The TV's intensity scales every segment. Its duration stretches hit,
/// success and error in time (their natural lengths are
/// [HapticEvent.defaultDurationMs]), and sets how long a rumble lasts.
/// These values are a first proposal, to be tuned on the phones.
final class HapticPattern {
  const HapticPattern(this.segments);

  factory HapticPattern.forEvent(HapticEvent event, {double intensity = 1, int? durationMs}) {
    final length = (durationMs ?? event.defaultDurationMs).toDouble();
    final stretch = length / event.defaultDurationMs;
    final shape = switch (event) {
      HapticEvent.hit => _hit,
      HapticEvent.success => _success,
      HapticEvent.error => _error,
      HapticEvent.rumble => _rumble(length),
    };
    final scale = intensity.clamp(0.0, 1.0);
    return HapticPattern([
      for (final s in shape)
        if (event == HapticEvent.rumble)
          HapticSegment.buzz(s.startMs, s.durationMs, s.intensity * scale, s.sharpness)
        else if (s.isTap)
          HapticSegment.tap(s.startMs * stretch, s.intensity * scale, s.sharpness)
        else
          HapticSegment.buzz(s.startMs * stretch, s.durationMs * stretch, s.intensity * scale, s.sharpness),
    ]);
  }

  final List<HapticSegment> segments;

  /// When the last segment ends (taps count as instant).
  double get lengthMs => segments.fold(0, (m, s) => max(m, s.endMs));

  double get peakIntensity => segments.fold(0, (m, s) => max(m, s.intensity));

  List<List<double>> toWire() => [for (final s in segments) s.toWire()];

  @override
  String toString() => segments.join(', ');
}

/// A thump: a heavy tap plus a tail that fades out over the natural length.
const _hit = [
  HapticSegment.tap(0, 1.0, 0.3),
  HapticSegment.buzz(0, 30, 0.7, 0.2),
  HapticSegment.buzz(30, 30, 0.45, 0.15),
  HapticSegment.buzz(60, 30, 0.25, 0.1),
  HapticSegment.buzz(90, 30, 0.1, 0.1),
];

/// Three taps getting stronger, the last with a short ring.
const _success = [
  HapticSegment.tap(0, 0.55, 0.8),
  HapticSegment.tap(110, 0.8, 0.85),
  HapticSegment.tap(220, 1.0, 0.9),
  HapticSegment.buzz(220, 100, 0.45, 0.7),
];

/// Two short, sharp buzzes with a gap.
const _error = [HapticSegment.buzz(0, 80, 0.9, 1.0), HapticSegment.buzz(140, 80, 0.9, 1.0)];

/// A low buzz that wobbles between two strengths every 50 ms, for [lengthMs].
List<HapticSegment> _rumble(double lengthMs) {
  const step = 50.0;
  return [
    for (var t = 0.0; t < lengthMs; t += step)
      HapticSegment.buzz(t, min(step, lengthMs - t), (t ~/ step).isEven ? 0.8 : 0.6, 0.05),
  ];
}
