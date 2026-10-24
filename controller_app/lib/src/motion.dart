import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'tilt.dart';

/// The phone's motion sensors. A fake replaces it in tests.
abstract class MotionSensors {
  /// Acceleration in m/s², including gravity (pointing up when still).
  Stream<Vec3> accelerometer(Duration period);

  /// Rotation rate in rad/s, with the sample time.
  Stream<(Vec3, DateTime)> gyroscope(Duration period);
}

/// sensors_plus: SensorManager on Android, Core Motion on iOS.
class PlatformMotionSensors implements MotionSensors {
  @override
  Stream<Vec3> accelerometer(Duration period) =>
      accelerometerEventStream(samplingPeriod: period).map((e) => Vec3(e.x, e.y, e.z));

  @override
  Stream<(Vec3, DateTime)> gyroscope(Duration period) =>
      gyroscopeEventStream(samplingPeriod: period).map((e) => (Vec3(e.x, e.y, e.z), e.timestamp));
}
