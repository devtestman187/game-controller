import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/local_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idle = ClientSnapshot(status: ClientStatus.idle);
  final lanTarget = HostAddress(addresses: ['192.168.1.50'], port: 45780);

  LocalNetworkAccess access({
    bool isIOS = true,
    DiscoveryState discovery = const DiscoveryState(),
    ClientSnapshot client = idle,
    bool everConnected = false,
    DateTime? now,
  }) => localNetworkStatus(
    isIOS: isIOS,
    discovery: discovery,
    client: client,
    everConnected: everConnected,
    now: now,
  ).access;

  test('Android never needs it', () => expect(access(isIOS: false), LocalNetworkAccess.notNeeded));

  test('a found TV or a connection proves it is allowed', () {
    expect(access(discovery: const DiscoveryState(everFound: true)), LocalNetworkAccess.allowed);
    expect(access(everConnected: true), LocalNetworkAccess.allowed);
  });

  test('"No route to host" to a local address means probably denied', () {
    final failed = ClientSnapshot(
      status: ClientStatus.failed,
      target: lanTarget,
      problem: ClientProblem.unreachable,
      osErrorCode: 65,
    );
    expect(access(client: failed), LocalNetworkAccess.probablyDenied);
  });

  test('"No route to host" to a public address says nothing about the permission', () {
    final failed = ClientSnapshot(
      status: ClientStatus.failed,
      target: HostAddress(addresses: ['8.8.8.8'], port: 1),
      osErrorCode: 65,
    );
    expect(access(client: failed), LocalNetworkAccess.unknown);
  });

  test('unknown before anything is found', () {
    final started = DateTime(2026, 10, 24, 12);
    final s = localNetworkStatus(
      isIOS: true,
      discovery: DiscoveryState(running: true, startedAt: started),
      client: idle,
      everConnected: false,
      now: started.add(const Duration(seconds: 15)),
    );
    expect(s.access, LocalNetworkAccess.unknown);
    expect(s.explanation, contains('Don\'t Allow'));
  });
}
