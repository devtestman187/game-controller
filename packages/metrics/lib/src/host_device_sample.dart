/// One reading of the host device's battery and heat (m12 §0.8), as the host
/// app's battery adapter reports it: plain values, so `metrics` stays free of
/// Flutter and the platform.
final class HostDeviceSample {
  const HostDeviceSample({this.battery, this.charging = false, this.thermal, this.lowPower = false});

  /// The battery level, 0 to 1, or null when the device doesn't say.
  final double? battery;

  /// True while the device is charging.
  final bool charging;

  /// The system's thermal state, e.g. `nominal` or `serious`, or null.
  final String? thermal;

  /// True while the system asks apps to do less work (Android's battery
  /// saver, iOS's Low Power Mode).
  final bool lowPower;
}
