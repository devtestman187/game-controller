import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';

void main() {
  const identity = HostIdentity(
    appVersion: '0.11.0',
    versionLabel: '0.11.0 (123)',
    hostType: HostType.androidTv,
    kind: HostKind.tv,
    hostOs: 'android',
    defaultHostName: 'Android TV',
    serviceName: 'Thumb Party TV (Android TV)',
  );

  test('an identity equals another with the same values, and hashes the same', () {
    const same = HostIdentity(
      appVersion: '0.11.0',
      versionLabel: '0.11.0 (123)',
      hostType: HostType.androidTv,
      kind: HostKind.tv,
      hostOs: 'android',
      defaultHostName: 'Android TV',
      serviceName: 'Thumb Party TV (Android TV)',
    );
    expect(same, identity);
    expect(same.hashCode, identity.hashCode);
  });

  test('a different version, label, type, kind, OS or name makes the identity unequal', () {
    const others = <(String, HostIdentity)>[
      (
        'appVersion',
        HostIdentity(
          appVersion: '0.12.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          kind: HostKind.tv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'versionLabel',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (124)',
          hostType: HostType.androidTv,
          kind: HostKind.tv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'hostType',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.windows,
          kind: HostKind.tv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'kind',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          kind: HostKind.phone,
          hostOs: 'android',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'hostOs',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          kind: HostKind.tv,
          hostOs: 'windows',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'defaultHostName',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          kind: HostKind.tv,
          hostOs: 'android',
          defaultHostName: 'Windows PC',
          serviceName: 'Thumb Party TV (Android TV)',
        ),
      ),
      (
        'serviceName',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          kind: HostKind.tv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
          serviceName: 'Thumb Party on Pixel 8',
        ),
      ),
    ];
    for (final (field, other) in others) {
      expect(other, isNot(identity), reason: 'a different $field makes a different identity');
    }
  });
}
