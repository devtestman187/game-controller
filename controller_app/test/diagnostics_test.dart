import 'package:connection/connection.dart';
import 'package:controller/src/device_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('Diagnostics shows the connection, permission, haptics and log', (tester) async {
    final log = LogBuffer()..add('client', 'Connecting to ws://192.168.1.50:45780/ws');
    final app = await pumpApp(tester, isIOS: true, log: log);
    app.client.emit(
      ClientSnapshot(
        status: ClientStatus.failed,
        target: tv,
        problem: ClientProblem.unreachable,
        detail: 'No route to host (OS error 65)',
        osErrorCode: 65,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Diagnostics'));
    await settle(tester);

    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Probably denied'), findsOneWidget);
    expect(find.text('tv-1'), findsOneWidget);
    final pageList = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Ticks played'), 200, scrollable: pageList);
    expect(find.text('fake'), findsOneWidget);
    // Each SelectableText is scrollable too, so name the page's list.
    final logLine = find.textContaining('[client] Connecting to ws://192.168.1.50');
    await tester.scrollUntilVisible(logLine, 300, scrollable: pageList);
    expect(logLine, findsOneWidget);
  });

  group('session readout (M6)', () {
    testWidgets('Diagnostics shows CPU, battery and heat', (tester) async {
      final device = FakeDeviceStatus();
      await pumpApp(tester, paired: true, device: device);
      // 10 s later the app has used 0.8 s of CPU: 8 % of one core.
      device.next = const DeviceStatus(battery: 0.79, thermal: 'fair', cpuMs: 800);
      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byTooltip('Diagnostics'));
      await settle(tester);
      await scrollTo(tester, find.text('Heat'));
      expect(find.textContaining('of one core'), findsOneWidget);
      expect(find.text('fair'), findsOneWidget);
      expect(find.textContaining('79%'), findsOneWidget);
    });

    test('CPU, battery drain and send rate from the samples', () {
      DeviceSample s(int seconds, double battery, double cpuMs, int sent) => (
        at: DateTime(2026).add(Duration(seconds: seconds)),
        status: DeviceStatus(battery: battery, cpuMs: cpuMs),
        inputsSent: sent,
      );
      final stats = SessionStats(
        first: s(0, 0.9, 0, 0),
        latest: s(1800, 0.85, 180000, 108000),
        recent: s(1740, 0.851, 174000, 104400),
      );
      expect(stats.cpuPercent, closeTo(10, 1e-9));
      expect(stats.recentCpuPercent, closeTo(10, 1e-9));
      expect(stats.batteryPerHour, closeTo(10, 1e-6), reason: '5 % in half an hour');
      expect(stats.sendRate, closeTo(60, 1e-9));
      final charging = SessionStats(
        first: s(0, 0.5, 0, 0),
        latest: (
          at: DateTime(2026).add(const Duration(hours: 1)),
          status: const DeviceStatus(battery: 0.6, charging: true),
          inputsSent: 0,
        ),
      );
      expect(charging.batteryPerHour, isNull);
    });
  });
}
