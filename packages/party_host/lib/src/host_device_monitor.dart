import 'package:metrics/metrics.dart';

/// Reads the host device's battery and heat for the session summary (m12
/// §0.1). The phone app implements it over its `DeviceStatusSource`; the TV
/// keeps [NoHostDeviceMonitor], so it records nothing.
///
/// It's an interface with a fake for tests, like every platform adapter
/// (S-a): `metrics` gets plain values and never sees a platform channel.
abstract class HostDeviceMonitor {
  /// The device's state now, or null when this reading can't be taken.
  Future<HostDeviceSample?> sample();
}

/// The monitor of a host that has none, as the TV has: every reading says
/// nothing, so the summary records no battery and no heat.
class NoHostDeviceMonitor implements HostDeviceMonitor {
  const NoHostDeviceMonitor();

  @override
  Future<HostDeviceSample?> sample() async => null;
}
