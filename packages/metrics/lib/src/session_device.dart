import 'host_device_sample.dart';

/// The session's picture of the host device (m12 §0.8): the battery at the
/// start and at the end, whether it charged at all, whether the system asked
/// for less work, and the seconds spent in each thermal state.
///
/// It becomes the summary's `host.device`, and is left out when no sample said
/// anything (a host without a monitor, as on the TV).
class HostDeviceTally {
  /// The first battery level read, 0 to 1: null until a sample has one.
  double? batteryStart;

  /// The last battery level read, 0 to 1.
  double? batteryEnd;

  /// True once any sample said the device was charging.
  bool charging = false;

  /// True once any sample said the system asked for less work.
  bool lowPower = false;

  /// Seconds spent in each thermal state, by the state's name.
  final thermalS = <String, int>{};

  /// Adds one reading. [forS] is how many seconds passed in the sample's
  /// thermal state: 0 for a sample taken at a round's edge, which says the
  /// state but not for how long.
  void add(HostDeviceSample sample, {int forS = 0}) {
    if (sample.charging) charging = true;
    if (sample.lowPower) lowPower = true;
    final battery = sample.battery;
    // A reading outside 0 to 1 is a broken adapter, not a level: skip it.
    if (battery != null && battery >= 0 && battery <= 1) {
      batteryStart ??= battery;
      batteryEnd = battery;
    }
    final thermal = sample.thermal;
    if (forS > 0 && thermal != null) thermalS[thermal] = (thermalS[thermal] ?? 0) + forS;
  }

  /// The summary's `host.device`, or null when no sample said anything.
  Map<String, Object?>? toJson() {
    if (batteryStart == null && !charging && !lowPower && thermalS.isEmpty) return null;
    return {
      'batteryStart': ?batteryLevel(batteryStart),
      'batteryEnd': ?batteryLevel(batteryEnd),
      if (charging) 'charging': true,
      if (lowPower) 'lowPower': true,
      if (thermalS.isNotEmpty) 'thermalS': {for (final MapEntry(:key, :value) in thermalS.entries) key: value},
    };
  }
}

/// A battery level with two decimals, or null: 0.8765 is 0.88 (m12 §0.8
/// keeps the levels to two decimals).
double? batteryLevel(double? level) => level == null ? null : double.parse(level.toStringAsFixed(2));
