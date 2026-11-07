import 'package:connection/connection.dart';
import 'package:controller/src/device_status.dart';
import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/fakes.dart';
import 'support/host_app.dart';
import 'support/pump_app.dart';

/// Opens Diagnostics and copies its report, with the clipboard mocked: the
/// copied text is what "Copy report" shares.
Future<String> copiedReport(WidgetTester tester) async {
  String? copied;
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      final args = call.arguments as Map<Object?, Object?>;
      copied = args['text']?.toString();
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  await tester.tap(find.byTooltip('Diagnostics'));
  await settle(tester);
  await tester.tap(find.byTooltip('Copy report'));
  await settle(tester);
  return copied ?? fail('Nothing was copied');
}

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

  group('the host log in the report (s5c)', () {
    testWidgets('a hosting phone puts the host log after its own', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester);
      final container = hostContainer(tester);
      container.read(logProvider).add('test', 'A line the phone logged');
      container.read(party.logProvider).add('host', 'A line the host logged');

      final report = await copiedReport(tester);

      final header = report.indexOf('Host log (this phone is the host):');
      expect(header, greaterThan(report.indexOf('A line the phone logged')), reason: "after the phone's own log");
      expect(report.indexOf('A line the host logged'), greaterThan(header));
      await tester.runAsync(host.dispose);
    });

    testWidgets('a phone that is not hosting has no host log in its report', (tester) async {
      await pumpApp(tester, paired: true);
      final report = await copiedReport(tester);
      expect(report, isNot(contains('Host log (this phone is the host):')));
    });
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

  group('the game view (m12-joined-view §5)', () {
    /// Feeds the client's own stats a session at 60 Hz and then one at 30.
    void measure(ViewerStats stats) {
      // 60 Hz: inputs reach the screen 20, 41 and 58 ms after they were sent,
      // four frames arrive 1, 2, 3 and 9 ms late, no draw is late (16 ms
      // apart, the limit is 25).
      stats.inputSent(1, 980);
      stats.frameArrived(0, jitterMs: 1);
      stats.frameDrawn(1, 1000);
      stats.inputSent(2, 975);
      stats.frameArrived(1, jitterMs: 2);
      stats.frameDrawn(2, 1016);
      stats.inputSent(3, 974);
      stats.frameArrived(2, jitterMs: 3);
      stats.frameDrawn(3, 1032);
      stats.frameArrived(3, jitterMs: 9);
      stats.frameDrawn(null, 1048);

      // 30 Hz after a new game: 100, 120 and 150 ms to the frame, the draws
      // 33 and 67 ms apart (the limit is 50, so the second is late), and a
      // jump of 6 steps (more than 3, so a gap).
      stats.reset(hz: 30);
      stats.inputSent(4, 1900);
      stats.frameArrived(0, jitterMs: 5);
      stats.frameDrawn(4, 2000);
      stats.inputSent(5, 1913);
      stats.frameArrived(2, jitterMs: 10);
      stats.frameDrawn(5, 2033);
      stats.inputSent(6, 1950);
      stats.frameArrived(8, jitterMs: 20);
      stats.frameDrawn(6, 2100);
    }

    const line60 =
        '60 Hz: touch-to-frame 41 ms median, 58 ms p95 (3 samples) · jitter 3/9 ms · frames 4, late 0, gaps 0';
    const line30 =
        '30 Hz: touch-to-frame 120 ms median, 150 ms p95 (3 samples) · jitter 10/20 ms · frames 3, late 1, gaps 1';

    testWidgets('Diagnostics and the report both show one line per frame rate', (tester) async {
      final app = await pumpApp(tester, paired: true);
      measure(app.client.viewerStats);

      final report = await copiedReport(tester);
      await scrollTo(tester, find.text('Game view'));
      expect(find.text(line60), findsOneWidget);
      expect(find.text(line30), findsOneWidget);
      expect(report, contains('Game view:'));
      expect(report, contains(line60));
      expect(report, contains(line30));
    });

    testWidgets('a phone that was shown no game has no Game view', (tester) async {
      await pumpApp(tester, paired: true);
      final report = await copiedReport(tester);
      await scrollTo(tester, find.textContaining('Log (newest last'));
      expect(find.text('Game view'), findsNothing);
      expect(report, isNot(contains('Game view')));
    });
  });
}
