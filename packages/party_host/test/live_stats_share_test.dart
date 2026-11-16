import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_test_support.dart';

const _caps = [Capability.metrics, Capability.rating];

/// Waits until [test] holds; a host that never gets there fails the test.
Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// The objects in a summary list such as `players` or `rounds`.
List<Map<String, Object?>> mapsOf(Object? list) => [
  if (list is List<Object?>)
    for (final entry in list)
      if (entry is Map<String, Object?>) entry,
];

void main() {
  late Directory dir;
  late HostServer server;
  late ServerGameHost host;
  late FakeUploader uploader;

  Future<LiveStats> startStats() async {
    SharedPreferences.setMockInitialValues({'statsConsent': true});
    final prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-share-');
    final folder = dir;
    addTearDown(() => deleteTempFolder(folder));
    server = HostServer(
      hostId: 'tv',
      hostName: 'Test TV',
      appVersion: '0.14.0',
      listeners: [WebSocketListener(preferredPort: 0, hostName: 'Test TV')],
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
      capabilities: _caps,
    );
    host = ServerGameHost(server);
    uploader = FakeUploader();
    final stats = LiveStats(
      server: server,
      host: host,
      prefs: prefs,
      exportDirectory: () async => Directory('${dir.path}/export'),
      hostType: HostType.windows,
      hostApp: '0.14.0',
      sessionGap: const Duration(milliseconds: 400),
      uploader: uploader,
    );
    await stats.start(Directory('${dir.path}/sessions'));
    await server.start();
    addTearDown(() async {
      await stats.dispose();
      await host.dispose();
      await server.dispose();
      await settleUploads(stats);
    });
    return stats;
  }

  ControllerClient phone(String id) {
    final c = ControllerClient(
      identity: ControllerIdentity(
        controllerId: id,
        name: 'Phone $id',
        platform: 'android',
        appVersion: '0.14.0',
        capabilities: _caps,
      ),
      connector: WebSocketConnector(),
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
      retryDelays: const [Duration(milliseconds: 50)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a phone that said no is left out of the upload, while the saved file keeps both', () async {
    final stats = await startStats();
    final yes = phone('phone-yes')..setStatsShare(true);
    // phone-no never calls setStatsShare: the host counts it as not sharing.
    final no = phone('phone-no');
    for (final p in [yes, no]) {
      p.connect(
        HostAddress(addresses: ['127.0.0.1'], port: server.port!),
        code: server.pairingCode,
      );
    }
    await waitFor(() => host.players.length == 2);

    Map<String, Object?>? playerOf(String install) {
      for (final p in mapsOf(stats.session?.summary(host.nowMs)['players'])) {
        if (p['install'] == install) return p;
      }
      return null;
    }

    await waitFor(() => playerOf('phone-yes')?['share'] == true);
    expect(playerOf('phone-no')?['share'], isFalse, reason: 'a player the host never heard from does not share');

    host.record(const GameRecord(game: 'arena', name: 'round_start'));
    host.record(
      const GameRecord(
        game: 'arena',
        name: 'round_end',
        data: {
          'timeS': 10.0,
          'modes': {'phone-yes': 'dpad', 'phone-no': 'dpad'},
          'winner': 'phone-no',
        },
      ),
    );
    await waitFor(() => mapsOf(stats.session?.summary(host.nowMs)['rounds']).isNotEmpty);

    yes.disconnect();
    no.disconnect();
    await waitFor(() => stats.session == null);
    await waitFor(() => uploader.uploaded.isNotEmpty);

    // What went up: one player, and a round with its totals only.
    final uploaded = uploader.uploaded.single;
    expect([for (final p in mapsOf(uploaded['players'])) p['install']], ['phone-yes']);
    expect(mapsOf(uploaded['players']).single['share'], isTrue);
    final round = mapsOf(uploaded['rounds']).single;
    expect(round['game'], 'arena');
    expect(round['timeS'], 10.0);
    expect(round['players'], 2, reason: 'the round happened, and two players took part');
    expect(round.containsKey('winner'), isFalse, reason: 'the winner said no');

    // What the TV keeps: both players, each with their answer.
    final saved = (await stats.sessions()).single.summary;
    expect([for (final p in mapsOf(saved['players'])) p['install']], ['phone-yes', 'phone-no']);
    expect([for (final p in mapsOf(saved['players'])) p['share']], [true, false]);
    expect(mapsOf(saved['rounds']).single['winner'], isNotNull);
  });
}
