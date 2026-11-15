import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An identity from a build whose number has the most digits the stats keep.
const _nineDigit = HostIdentity(
  appVersion: '0.11.0',
  versionLabel: '0.11.0 (123456789)',
  hostType: HostType.windows,
  kind: HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

/// The same one digit longer: a build the stats' reader drops.
const _tenDigit = HostIdentity(
  appVersion: '0.11.0',
  versionLabel: '0.11.0 (1234567890)',
  hostType: HostType.windows,
  kind: HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

/// A started host service with [identity], a fake advertiser and the folders in
/// a temp folder.
Future<LiveHostService> startService(HostIdentity identity) async {
  SharedPreferences.setMockInitialValues({});
  final dir = await Directory.systemTemp.createTemp('party-host-build-cap-test');
  addTearDown(() => dir.delete(recursive: true));
  final service = LiveHostService(
    prefs: await SharedPreferences.getInstance(),
    log: LogBuffer(),
    identity: identity,
    directories: FakeHostDirectories(dir),
    advertiser: FakeAdvertiser(),
  );
  addTearDown(service.dispose);
  await service.start();
  return service;
}

void main() {
  test('a nine-digit build number joins the version', () {
    expect(_nineDigit.appWithBuild, '0.11.0+123456789');
  });

  test('a ten-digit build number gives the bare version', () {
    // The stats' splitAppBuild keeps 1 to 9 digits; a tenth would be read as no
    // build, so the host sends none (M14 stats).
    expect(_tenDigit.appWithBuild, '0.11.0');
  });

  test('the host service gives the stats no build when the label\'s is too long', () async {
    final service = await startService(_tenDigit);
    expect((service.stats as LiveStats).hostApp, '0.11.0');
  });

  test('the welcome to a phone keeps the bare version, with a nine-digit build in the label', () async {
    final service = await startService(_nineDigit);
    expect((service.stats as LiveStats).server.appVersion, '0.11.0');
  });

  test('a simulated controller says hello with the bare version', () async {
    final service = await startService(_nineDigit);
    service.addSimulatedController();
    // The sim's hello is what the controller list shows; it names the app, not
    // the stats' "version+build" (M14 stats).
    final sim = await service.changes
        .expand((s) => s.host.controllers.where((c) => c.platform == 'sim' && c.state == ControllerState.connected))
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('No simulated controller connected'),
        );
    expect(sim.appVersion, '0.11.0');
  });
}
