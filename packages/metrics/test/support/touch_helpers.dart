import 'package:metrics/metrics.dart';

/// A 120 x 60 mm controller: the D-pad on the left, B as a 10 mm circle on
/// the right, and Start in the middle.
TouchMap testMap() => TouchMap(
  [
    const TouchShape.rect(Controls.dpad, 10, 20, 30, 30),
    const TouchShape.rect('start', 55, 25, 12, 6),
    TouchShape.circle('b', 100, 30, 5),
  ],
  widthMm: 120,
  heightMm: 60,
);

SegmentRecorder recorder({String mode = 'dpad'}) =>
    SegmentRecorder(id: 's1', mode: mode, startMs: 1000, map: testMap(), settings: const {'buttonSize': 0.75});
