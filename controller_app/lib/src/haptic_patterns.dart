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
/// Each event has its own shape so they can be told apart without looking.
/// They differ in how many pulses they have, their rhythm and their length,
/// not just in strength (the M5 device test found the first versions "a
/// little hard to differentiate"):
/// - **hit**: one short, deep thud (one pulse, 100 ms).
/// - **success**: three crisp taps, clearly apart and rising, then a ring,
///   "ti-ti-TIING" (three pulses, 450 ms).
/// - **error**: two long, harsh buzzes, "BZZT-BZZT" (two pulses, 300 ms).
/// - **rumble**: a deep throb, strong and weak in turns, for the whole
///   duration.
/// - The puzzle (M10): **snap** "ka-CHUNK", **wrong** a low falling "uh-oh",
///   **dropReady** one light tap, **help** two gentle knocks (M11), and
///   **tick** the lightest tap.
///
/// The TV's intensity scales every segment. Its duration stretches hit,
/// success and error in time (their natural lengths are
/// [HapticEvent.defaultDurationMs]), and sets how long a rumble lasts.
/// Each event's strength can also be set on its own in Settings.
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
      HapticEvent.snap => _snap,
      HapticEvent.wrong => _wrong,
      HapticEvent.dropReady => _dropReady,
      HapticEvent.help => _help,
      HapticEvent.tick => _tick,
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

/// A thud: a deep, heavy tap with a short tail, at full strength.
const _hit = [
  HapticSegment.tap(0, 1.0, 0.1),
  HapticSegment.buzz(0, 60, 1.0, 0.0),
  HapticSegment.buzz(60, 40, 0.45, 0.0),
];

/// Three crisp taps getting stronger, 130 ms apart, the last one ringing out.
const _success = [
  HapticSegment.tap(0, 0.5, 1.0),
  HapticSegment.tap(130, 0.75, 1.0),
  HapticSegment.tap(260, 1.0, 1.0),
  HapticSegment.buzz(260, 100, 0.7, 0.9),
  HapticSegment.buzz(360, 90, 0.35, 0.9),
];

/// Two long, harsh buzzes with a clear gap.
const _error = [HapticSegment.buzz(0, 110, 1.0, 1.0), HapticSegment.buzz(190, 110, 1.0, 1.0)];

/// The puzzle (M10): a crisp click, then a firm lock, "ka-CHUNK".
const _snap = [
  HapticSegment.tap(0, 0.6, 1.0),
  HapticSegment.tap(70, 1.0, 0.6),
  HapticSegment.buzz(70, 90, 0.8, 0.3),
];

/// A low, falling "uh-oh": round and soft, so it never feels like [_error]'s
/// harsh buzzes.
const _wrong = [HapticSegment.buzz(0, 100, 0.85, 0.0), HapticSegment.buzz(150, 110, 0.45, 0.0)];

/// One light, crisp tap: close enough to drop.
const _dropReady = [HapticSegment.tap(0, 0.5, 0.9), HapticSegment.buzz(0, 40, 0.3, 0.9)];

/// Two gentle knocks and a soft hum: a teammate needs help (M11).
const _help = [
  HapticSegment.tap(0, 0.6, 0.4),
  HapticSegment.tap(120, 0.6, 0.4),
  HapticSegment.buzz(200, 120, 0.5, 0.2),
];

/// The lightest tap, once a second at the end of a round.
const _tick = [HapticSegment.buzz(0, 30, 0.5, 1.0)];

/// How long each strong or weak part of a rumble lasts.
const rumbleStepMs = 70.0;

/// A deep buzz that throbs between strong and weak, for [lengthMs].
List<HapticSegment> _rumble(double lengthMs) => [
  for (var t = 0.0; t < lengthMs; t += rumbleStepMs)
    HapticSegment.buzz(t, min(rumbleStepMs, lengthMs - t), (t ~/ rumbleStepMs).isEven ? 1.0 : 0.45, 0.0),
];
