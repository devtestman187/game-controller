import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_test_support.dart';

const _caps = [Capability.metrics, Capability.rating];

/// No heartbeat traffic: a ping or a pong is a change, and these tests change
/// a player's answer only through the call they check.
const _quietLink = Duration(minutes: 1);

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

  Future<LiveStats> startStats() async {
    SharedPreferences.setMockInitialValues({'statsConsent': true});
    final prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-answer-');
    final folder = dir;
    addTearDown(() => deleteTempFolder(folder));
    server = HostServer(
      hostId: 'tv',
      hostName: 'Test TV',
      appVersion: '0.14.0',
      listeners: [WebSocketListener(preferredPort: 0, hostName: 'Test TV')],
      heartbeatInterval: _quietLink,
      heartbeatTimeout: _quietLink,
      capabilities: _caps,
    );
    host = ServerGameHost(server);
    final stats = LiveStats(
      server: server,
      host: host,
      prefs: prefs,
      exportDirectory: () async => Directory('${dir.path}/export'),
      hostType: HostType.windows,
      hostApp: '0.14.0',
      sessionGap: const Duration(seconds: 30),
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
      heartbeatInterval: _quietLink,
      heartbeatTimeout: _quietLink,
      retryDelays: const [Duration(milliseconds: 50)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The running session's entry for [install], or null when it has none.
  Map<String, Object?>? playerOf(LiveStats stats, String install) {
    for (final p in mapsOf(stats.session?.summary(host.nowMs)['players'])) {
      if (p['install'] == install) return p;
    }
    return null;
  }

  /// Pauses and resumes the host as the phone's app does when it is hidden
  /// and shown again: the players stay paired and send nothing new.
  Future<void> pauseAndResume(LiveStats stats) async {
    final paused = stats.session?.id;
    await stats.pause();
    expect(stats.session, isNull, reason: 'the pause saves the session and leaves none running');
    await stats.resume();
    expect(stats.session, isNotNull, reason: 'the players who stayed paired have a session again');
    expect(stats.session!.id, isNot(paused), reason: 'the paused session is saved, never reopened');
  }

  test('a yes given before the pause still shares in the resumed session, and a no stays no', () async {
    final stats = await startStats();
    final yes = phone('phone-yes')..setStatsShare(true);
    final no = phone('phone-no')..setStatsShare(false);
    for (final p in [yes, no]) {
      p.connect(
        HostAddress(addresses: ['127.0.0.1'], port: server.port!),
        code: server.pairingCode,
      );
    }
    await waitFor(() => host.players.length == 2);
    await waitFor(() => playerOf(stats, 'phone-yes')?['share'] == true);

    await pauseAndResume(stats);

    expect(
      playerOf(stats, 'phone-yes')?['share'],
      isTrue,
      reason: 'nothing was sent on resume: the answer from before the pause still holds',
    );
    expect(playerOf(stats, 'phone-no')?['share'], isFalse, reason: 'a no stays a no after the pause');
  });

  test('the last answer a phone gave is the one that holds after the pause', () async {
    final stats = await startStats();
    final changed = phone('phone-changed')..setStatsShare(false);
    changed.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port!),
      code: server.pairingCode,
    );
    await waitFor(() => host.players.length == 1);
    await waitFor(() => playerOf(stats, 'phone-changed')?['share'] == false);

    changed.setStatsShare(true);
    await waitFor(() => playerOf(stats, 'phone-changed')?['share'] == true);
    await pauseAndResume(stats);

    expect(
      playerOf(stats, 'phone-changed')?['share'],
      isTrue,
      reason: 'the yes replaced the no, so the yes is what the resumed session keeps',
    );
  });
}
