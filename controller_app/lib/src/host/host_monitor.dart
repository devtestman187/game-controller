import 'package:metrics/metrics.dart' show HostDeviceSample;
import 'package:party_host/party_host.dart' as party;

import '../device_status.dart';

/// Reads this phone's battery and heat for the session summary while it hosts
/// (m12 §0.1): the adapter over the app's [DeviceStatusSource], so
/// `party_host` and `metrics` see plain values and never a platform channel.
class PhoneHostMonitor implements party.HostDeviceMonitor {
  const PhoneHostMonitor(this._source);

  final DeviceStatusSource _source;

  @override
  Future<HostDeviceSample?> sample() async {
    final status = await _source.read();
    if (status == null) return null;
    final battery = status.battery;
    return HostDeviceSample(
      // The native side says -1 when it can't read the level, and "unknown"
      // when it can't name the heat: neither is a value the summary records.
      battery: battery == null || battery < 0 ? null : battery,
      charging: status.charging,
      thermal: status.thermal == _unknownThermal ? null : status.thermal,
      lowPower: status.lowPower,
    );
  }

  /// What [DeviceStatus] says when the device doesn't name its thermal state.
  static const _unknownThermal = 'unknown';
}
