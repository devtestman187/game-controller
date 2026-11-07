import 'package:controller/src/device_status.dart';
import 'package:controller/src/host/host_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group("the phone's host device monitor (m12 §0.1)", () {
    test('a reading becomes the sample the summary records', () async {
      final device = FakeDeviceStatus()
        ..next = const DeviceStatus(battery: 0.79, charging: true, thermal: 'fair', lowPower: true);
      final sample = await PhoneHostMonitor(device).sample();
      expect(sample!.battery, 0.79);
      expect(sample.charging, isTrue);
      expect(sample.thermal, 'fair');
      expect(sample.lowPower, isTrue);
    });

    test('a battery of -1, which means unreadable, and an unknown heat are no values', () async {
      final device = FakeDeviceStatus()..next = const DeviceStatus(battery: -1);
      final sample = await PhoneHostMonitor(device).sample();
      expect(sample!.battery, isNull);
      expect(sample.thermal, isNull);
      expect(sample.charging, isFalse);
      expect(sample.lowPower, isFalse);
    });

    test('a phone that cannot answer gives no sample', () async {
      final device = FakeDeviceStatus()..next = null;
      expect(await PhoneHostMonitor(device).sample(), isNull);
    });
  });
}
