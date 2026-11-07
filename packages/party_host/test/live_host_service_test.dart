import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The identity a desktop build supplies.
const _identity = HostIdentity(
  appVersion: '0.12.0',
  versionLabel: '0.12.0 (1)',
  hostType: HostType.windows,
  kind: HostKind.pc,
  hostOs: 'windows',
  defaultHostName: 'PC',
  serviceName: 'Thumb Party TV (PC)',
);

/// A started host service with a fake advertiser and the folders in a temp
/// folder. [inProcess] is the link to the host device's own player.
Future<LiveHostService> startService({required FakeAdvertiser advertiser, InProcessListener? inProcess}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dir = await Directory.systemTemp.createTemp('party-host-test');
  addTearDown(() => dir.delete(recursive: true));
  final service = LiveHostService(
    prefs: prefs,
    log: LogBuffer(),
    identity: _identity,
    directories: FakeHostDirectories(dir),
    advertiser: advertiser,
    inProcess: inProcess,
  );
  addTearDown(service.dispose);
  await service.start();
  return service;
}

/// The server the service runs: the stats record its messages, so they hold
/// the same one (a test stops it to act out the OS closing it).
HostServer serverOf(LiveHostService service) => (service.stats as LiveStats).server;

/// A phone that pairs on its own and stays paired for the test.
ControllerClient phone(String id, Connector connector) {
  final client = ControllerClient(
    identity: ControllerIdentity(controllerId: id, name: 'Phone $id', platform: 'test', appVersion: '0.12.0'),
    connector: connector,
  );
  addTearDown(client.dispose);
  return client;
}

/// Waits for [client] to say it is paired.
Future<void> paired(ControllerClient client) async {
  if (client.snapshot.isConnected) return;
  await client.changes
      .firstWhere((s) => s.isConnected)
      .timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('Stuck at ${client.snapshot}'));
}

void main() {
  test('the TXT record reaches the advertiser with id, v and kind', () async {
    final advertiser = FakeAdvertiser();
    final service = await startService(advertiser: advertiser);

    final start = advertiser.starts.single;
    expect(start.serviceName, _identity.serviceName);
    expect(start.port, service.state.host.port);
    expect(start.txt.keys, containsAll(<String>['id', 'v', HostKind.txtKey]));
    expect(start.txt[txtProtocolVersion], '$protocolVersion');
    expect(start.txt[HostKind.txtKey], HostKind.pc);
    expect(start.txt[txtHostId], hasLength(32), reason: '16 random bytes, as the TV sends');
  });

  test('the own player over the in-process link and a phone on the LAN are both players', () async {
    final inProcess = InProcessListener();
    final service = await startService(advertiser: FakeAdvertiser(), inProcess: inProcess);
    final code = service.state.host.pairingCode;
    final port = service.state.host.port;
    expect(port, isNotNull);

    final own = phone('own', InProcessConnector(inProcess));
    own.connect(
      HostAddress.local(hostId: 'this-device', name: _identity.serviceName),
      code: code,
    );
    final lan = phone('lan', WebSocketConnector());
    lan.connect(
      HostAddress(addresses: ['127.0.0.1'], port: port!),
      code: code,
    );

    await paired(own);
    await paired(lan);
    if (service.gameHost.players.length != 2) {
      await service.gameHost.playersChanged
          .firstWhere((p) => p.length == 2)
          .timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('Not both players yet'));
    }
    expect(service.gameHost.players, hasLength(2));
  });

  test('resume listens again on the port it had after the server stopped', () async {
    final advertiser = FakeAdvertiser();
    final service = await startService(advertiser: advertiser);
    final port = service.state.host.port;
    expect(port, isNotNull);
    advertiser.status = const AdvertiserStatus(
      state: AdvertiseState.advertising,
      advertisedName: 'Thumb Party TV (PC)',
    );

    await serverOf(service).stop();
    expect(service.state.host.running, isFalse);

    await service.resume();
    expect(service.state.host.running, isTrue);
    expect(service.state.host.port, port);
    expect(advertiser.starts, hasLength(1), reason: 'the advertisement still names a running host');
  });

  test('shareView is off by default, and what the service sets reaches its game host', () async {
    final service = await startService(advertiser: FakeAdvertiser());
    expect(service.shareView, isFalse, reason: 'the TV shows its own game');
    expect(service.gameHost.hasViewers, isFalse, reason: 'nobody has joined');

    service.shareView = true;
    expect(service.shareView, isTrue);
    expect(
      service.gameHost,
      isA<ServerGameHost>().having((h) => h.shareView, 'shareView', isTrue),
      reason: 'the game host is the one that sends the frames',
    );
  });

  test('resume does nothing while the server listens and advertising runs', () async {
    final advertiser = FakeAdvertiser();
    final service = await startService(advertiser: advertiser);
    advertiser.status = const AdvertiserStatus(
      state: AdvertiseState.advertising,
      advertisedName: 'Thumb Party TV (PC)',
    );
    final port = service.state.host.port;

    await service.resume();
    expect(service.state.host.port, port);
    expect(advertiser.starts, hasLength(1), reason: 'no second advertise call');
  });
}
