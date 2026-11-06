import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';

void main() {
  const identity = HostIdentity(
    appVersion: '0.11.0',
    versionLabel: '0.11.0 (123)',
    hostType: HostType.androidTv,
    hostOs: 'android',
    defaultHostName: 'Android TV',
  );

  test('an identity equals another with the same values, and hashes the same', () {
    const same = HostIdentity(
      appVersion: '0.11.0',
      versionLabel: '0.11.0 (123)',
      hostType: HostType.androidTv,
      hostOs: 'android',
      defaultHostName: 'Android TV',
    );
    expect(same, identity);
    expect(same.hashCode, identity.hashCode);
  });

  test('a different version, label, type, OS or name makes the identity unequal', () {
    const others = <(String, HostIdentity)>[
      (
        'appVersion',
        HostIdentity(
          appVersion: '0.12.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
        ),
      ),
      (
        'versionLabel',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (124)',
          hostType: HostType.androidTv,
          hostOs: 'android',
          defaultHostName: 'Android TV',
        ),
      ),
      (
        'hostType',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.windows,
          hostOs: 'android',
          defaultHostName: 'Android TV',
        ),
      ),
      (
        'hostOs',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          hostOs: 'windows',
          defaultHostName: 'Android TV',
        ),
      ),
      (
        'defaultHostName',
        HostIdentity(
          appVersion: '0.11.0',
          versionLabel: '0.11.0 (123)',
          hostType: HostType.androidTv,
          hostOs: 'android',
          defaultHostName: 'Windows PC',
        ),
      ),
    ];
    for (final (field, other) in others) {
      expect(other, isNot(identity), reason: 'a different $field makes a different identity');
    }
  });
}
