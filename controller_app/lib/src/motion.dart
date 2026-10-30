import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'tilt.dart';

/// The phone's motion sensors. A fake replaces it in tests.
abstract class MotionSensors {
  /// Acceleration in m/s², including gravity (pointing up when still).
  Stream<Vec3> accelerometer(Duration period);

  /// Rotation rate in rad/s, with the sample time.
  Stream<(Vec3, DateTime)> gyroscope(Duration period);
}

/// Turns a sensor reading from a device whose screen is naturally landscape
/// (the Pixel Tablet, most Android tablets) into the axes of a phone, whose
/// screen is naturally portrait: the tilt code is written for phone axes.
///
/// Android reports sensors relative to the natural orientation. Held upright
/// in its natural landscape, a tablet's top edge is +y; a phone held the same
/// way (landscape, its top on the left) has +x there. iOS always reports in
/// portrait axes, so iPads need no turning.
Vec3 fromNaturalLandscape(Vec3 v) => Vec3(v.y, -v.x, v.z);

/// sensors_plus: SensorManager on Android, Core Motion on iOS.
class PlatformMotionSensors implements MotionSensors {
  static const _channel = MethodChannel('com.thumbparty.app/haptics');

  /// Whether the readings need [fromNaturalLandscape], asked once.
  late final Future<bool> _naturalLandscape = _askNaturalLandscape();

  static Future<bool> _askNaturalLandscape() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<String>('naturalOrientation') == 'landscape';
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Stream<Vec3> accelerometer(Duration period) => Stream.fromFuture(_naturalLandscape).asyncExpand(
    (turn) => accelerometerEventStream(samplingPeriod: period).map((e) {
      final v = Vec3(e.x, e.y, e.z);
      return turn ? fromNaturalLandscape(v) : v;
    }),
  );

  @override
  Stream<(Vec3, DateTime)> gyroscope(Duration period) => Stream.fromFuture(_naturalLandscape).asyncExpand(
    (turn) => gyroscopeEventStream(samplingPeriod: period).map((e) {
      final v = Vec3(e.x, e.y, e.z);
      return (turn ? fromNaturalLandscape(v) : v, e.timestamp);
    }),
  );
}
