import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A 3D vector in the phone's sensor coordinates: x to the right and y to the
/// top of the phone held upright in portrait, z out of the screen. Android
/// and iOS (through sensors_plus) use the same axes.
final class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(dot(this));
  Vec3 get normalized => this * (1 / length);

  @override
  String toString() => '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

const double standardGravity = 9.81;

/// Tracks which way is up, in phone coordinates, by combining both sensors
/// (a complementary filter): the gyroscope follows rotation quickly and
/// smoothly but drifts, and the accelerometer knows where gravity is but is
/// noisy and also feels hand movement. Each gyro step rotates the estimate,
/// then nudges it a little toward the accelerometer.
class UpEstimator {
  UpEstimator({this.accelWeight = 0.02});

  /// How strongly each sample pulls toward the accelerometer. At ~100 Hz,
  /// 0.02 removes drift within about half a second.
  final double accelWeight;

  /// The current estimate (unit length), or null before the first sample.
  Vec3? up;
  Vec3? _accel;
  DateTime? _lastGyro;

  /// Accelerometer sample in m/s², including gravity (pointing up at rest).
  void accelerometer(Vec3 a) {
    if (a.length < 0.5) return; // Free fall: no direction to use.
    _accel = a;
    up ??= a.normalized;
  }

  /// Gyroscope sample in rad/s.
  void gyroscope(Vec3 rate, DateTime time) {
    final last = _lastGyro;
    _lastGyro = time;
    final current = up;
    if (current == null || last == null) return;
    final dt = time.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.25) return; // A gap (app paused): skip the step.

    // A direction fixed in the world turns the opposite way to the phone:
    // dv/dt = v × ω in phone coordinates.
    var next = (current + current.cross(rate) * dt).normalized;
    final a = _accel;
    // Trust the accelerometer only when it reads about 1 g (not shaking).
    if (a != null && (a.length - standardGravity).abs() < 0.2 * standardGravity) {
      next = (next * (1 - accelWeight) + a.normalized * accelWeight).normalized;
    }
    up = next;
  }
}

/// Which way the phone is turned in landscape, as Flutter names it:
/// [left] is portrait turned 90° counter-clockwise (top of the phone on the
/// left), [right] is 90° clockwise.
enum LandscapeSide { left, right }

/// The side the phone is held in, from the up direction, or null when it's
/// too flat to tell.
LandscapeSide? landscapeSideOf(Vec3 up) {
  final u = up.normalized;
  if (u.x > 0.6) return LandscapeSide.left;
  if (u.x < -0.6) return LandscapeSide.right;
  return null;
}

/// The phone's tilt as two angles in degrees, in screen terms for the
/// landscape [side].
///
/// [roll] grows when the phone tilts (or turns like a steering wheel) to the
/// right. [pitch] is how far the screen faces the sky: 0 lying flat, 90
/// upright. Both work whether the phone is held flat or upright.
typedef Tilt = ({double roll, double pitch});

Tilt tiltOf(Vec3 up, LandscapeSide side) {
  final u = up.normalized;
  final s = side == LandscapeSide.left ? 1.0 : -1.0;
  // The up direction in screen axes: right, up (towards the top of the
  // screen) and out of the screen.
  final right = -s * u.y;
  final top = s * u.x;
  final out = u.z;
  // Tilting right lowers the right edge, so "up" leans towards the left.
  final roll = -asin(right.clamp(-1.0, 1.0)) * 180 / pi;
  final pitch = atan2(top, out) * 180 / pi;
  return (roll: roll, pitch: pitch);
}

/// The difference between two angles, kept within -180..180.
double angleDelta(double a, double b) {
  var d = a - b;
  while (d > 180) {
    d -= 360;
  }
  while (d < -180) {
    d += 360;
  }
  return d;
}

/// Tilt that gives full deflection at sensitivity 1.
const double fullTiltDegrees = 30;

/// The user's gyro choices.
final class GyroSettings {
  const GyroSettings({this.sensitivity = 1.0, this.deadZone = 0.05, this.smoothing = 0.5});

  /// 0.5 to 2: full deflection at 60° down to 15° of tilt.
  final double sensitivity;

  /// 0 to 0.3 of full deflection, ignored around the center.
  final double deadZone;

  /// 0 (none) to 0.9 (heavy).
  final double smoothing;

  GyroSettings copyWith({double? sensitivity, double? deadZone, double? smoothing}) => GyroSettings(
    sensitivity: sensitivity ?? this.sensitivity,
    deadZone: deadZone ?? this.deadZone,
    smoothing: smoothing ?? this.smoothing,
  );

  static GyroSettings load(SharedPreferences prefs) => GyroSettings(
    sensitivity: (prefs.getDouble('gyroSensitivity') ?? 1.0).clamp(0.5, 2.0),
    deadZone: (prefs.getDouble('gyroDeadZone') ?? 0.05).clamp(0.0, 0.3),
    smoothing: (prefs.getDouble('gyroSmoothing') ?? 0.5).clamp(0.0, 0.9),
  );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble('gyroSensitivity', sensitivity);
    await prefs.setDouble('gyroDeadZone', deadZone);
    await prefs.setDouble('gyroSmoothing', smoothing);
  }
}

/// Tilt angles relative to neutral → stick values from -1 to 1 for each axis.
/// x is positive to the right; y is negative forward (the top tipping away),
/// like "up" on the D-pad.
({double x, double y}) normalizeTilt(double rollDelta, double pitchDelta, double sensitivity) => (
  x: (rollDelta * sensitivity / fullTiltDegrees).clamp(-1.0, 1.0),
  y: (pitchDelta * sensitivity / fullTiltDegrees).clamp(-1.0, 1.0),
);

/// A round dead zone that rescales what's outside it, so values still start
/// at 0 at its edge and reach 1 at full tilt.
({double x, double y}) applyDeadZone(double x, double y, double deadZone) {
  final magnitude = sqrt(x * x + y * y);
  if (magnitude <= deadZone || magnitude == 0) return (x: 0, y: 0);
  final scale = ((magnitude - deadZone) / (1 - deadZone)).clamp(0.0, 1.0) / magnitude;
  return (x: (x * scale).clamp(-1.0, 1.0), y: (y * scale).clamp(-1.0, 1.0));
}

/// Calibration, sensitivity, smoothing and dead zone, applied in that order.
class TiltProcessor {
  TiltProcessor({this.settings = const GyroSettings()});

  GyroSettings settings;

  /// The tilt that counts as centered. Set by [calibrate].
  Tilt? neutral;
  double _x = 0;
  double _y = 0;

  bool get calibrated => neutral != null;

  void calibrate(Tilt current) {
    neutral = current;
    _x = 0;
    _y = 0;
  }

  /// One output step (about 60 per second). Calibrates on the first call if
  /// not calibrated yet.
  ({double x, double y}) process(Tilt current) {
    final n = neutral ?? (neutral = current);
    final raw = normalizeTilt(
      angleDelta(current.roll, n.roll),
      angleDelta(current.pitch, n.pitch),
      settings.sensitivity,
    );
    // Exponential smoothing: each step moves part of the way to the new value.
    final k = 1 - settings.smoothing;
    _x += k * (raw.x - _x);
    _y += k * (raw.y - _y);
    return applyDeadZone(_x, _y, settings.deadZone);
  }
}
