import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An identity whose label carries a store build number.
const _withBuild = HostIdentity(
  appVersion: '0.11.0',
  versionLabel: '0.11.0 (123)',
  hostType: HostType.windows,
  kind: HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

/// An identity from a local build, whose label says "dev".
const _devBuild = HostIdentity(
  appVersion: '0.11.0',
  versionLabel: '0.11.0 (dev)',
  hostType: HostType.windows,
  kind: HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

void main() {
  test('an identity\'s appWithBuild is its version plus the label\'s build number', () {
    expect(_withBuild.appWithBuild, '0.11.0+123');
  });

  test('a label without a build number, e.g. "(dev)", gives the bare version', () {
    expect(_devBuild.appWithBuild, '0.11.0');
  });

  test('the host service gives the stats the version with its build number', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('party-host-build-test');
    addTearDown(() => dir.delete(recursive: true));
    final service = LiveHostService(
      prefs: await SharedPreferences.getInstance(),
      log: LogBuffer(),
      identity: _withBuild,
      directories: FakeHostDirectories(dir),
      advertiser: FakeAdvertiser(),
    );
    addTearDown(service.dispose);
    expect((service.stats as LiveStats).hostApp, '0.11.0+123');
  });
}
