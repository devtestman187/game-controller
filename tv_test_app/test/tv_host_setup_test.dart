import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/tv_host_setup.dart';

void main() {
  test('on this PC the TV app hosts as a pc named as before', () {
    expect(Platform.isWindows, isTrue, reason: 'the TV app is tested on Windows here');
    final identity = tvHostIdentity();
    expect(identity.kind, HostKind.pc);
    expect(identity.serviceName, 'Thumb Party TV (${Platform.localHostname})');
  }, skip: Platform.isWindows ? null : 'needs this Windows PC; CI runs the TV tests on Linux');

  test('off Windows the TV app hosts as a pc with this OS name', () {
    expect(Platform.isWindows, isFalse, reason: 'CI runs the TV tests on Linux');
    final identity = tvHostIdentity();
    expect(identity.hostType, HostType.other, reason: 'stats record no host type off Windows and Android');
    expect(identity.kind, HostKind.pc);
    expect(identity.hostOs, Platform.operatingSystem);
    expect(identity.serviceName, 'Thumb Party TV (${Platform.localHostname})');
  }, skip: Platform.isWindows ? 'this PC is Windows: the case above checks it' : null);
}
