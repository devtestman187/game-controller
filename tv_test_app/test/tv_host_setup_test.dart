import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:tvtest/src/tv_host_setup.dart';

void main() {
  test('on this PC the TV app hosts as a pc named as before', () {
    expect(Platform.isWindows, isTrue, reason: 'the TV app is tested on Windows here');
    final identity = tvHostIdentity();
    expect(identity.kind, HostKind.pc);
    expect(identity.serviceName, 'Thumb Party TV (${Platform.localHostname})');
  });
}
