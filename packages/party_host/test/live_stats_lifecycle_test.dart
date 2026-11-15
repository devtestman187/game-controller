import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _caps = [Capability.metrics, Capability.rating];

/// The gap these tests wait out: short, so a session that should end ends
/// while the test watches, and one that should stay open outlives it (B-019).
const _gap = Duration(milliseconds: 400);

/// How long a test watches a session that must not end: two gaps, so a
/// lost timer would have fired.
const _twoGaps = Duration(milliseconds: 800);

Future<T> until<T>(Stream<T> s, bool Function(T) test) => s.firstWhere(test).timeout(const Duration(seconds: 5));

Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Deletes a test's temp folder, waiting out Windows' late release of the
/// session file the last save wrote.
Future<void> deleteTempFolder(Directory folder) async {
  for (var tries = 0; ; tries++) {
    try {
      await folder.delete(recursive: true);
      return;
    } on FileSystemException {
      if (tries >= 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

void main() {
  late Directory dir;
  late HostServer server;
  late ServerGameHost host;
  late SharedPreferences prefs;
  late FakeUploader uploader;

  /// The clock the sessions are stamped with; injected, so a summary's start
  /// time is the same in every run.
  final now = DateTime(2026, 11, 15, 10, 30);

  /// A phone host playing its own player over [ownPlayer], or, without one, a
  /// TV host with a WebSocket for phones.
  Future<LiveStats> startStats({bool? consent, InProcessListener? ownPlayer}) async {
    SharedPreferences.setMockInitialValues({'statsConsent': ?consent});
    prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-life-');
    final folder = dir;
    addTearDown(() => deleteTempFolder(folder));
    final ChannelListener listener;
    if (ownPlayer == null) {
      listener = WebSocketListener(preferredPort: 0, hostName: 'Test host');
    } else {
      listener = ownPlayer;
    }
    server = HostServer(
      hostId: ownPlayer == null ? 'tv' : 'phone',
      hostName: 'Test host',
      appVersion: '0.11.0',
      listeners: [listener],
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
      hostType: ownPlayer == null ? HostType.windows : HostType.phone,
      hostApp: '0.11.0',
      sessionGap: _gap,
      uploader: uploader,
      clock: () => now,
    );
    await stats.start(Directory('${dir.path}/sessions'));
    await server.start();
    addTearDown(() async {
      await stats.dispose();
      await host.dispose();
      await server.dispose();
    });
    return stats;
  }

  /// Pairs the host phone's own player over the in-process [link].
  Future<ControllerClient> connectOwnPlayer(InProcessListener link) async {
    final client = ControllerClient(
      identity: const ControllerIdentity(
        controllerId: 'own-player',
        name: 'This phone',
        platform: 'ios',
        appVersion: '0.11.0',
        capabilities: _caps,
      ),
      connector: InProcessConnector(link),
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
    );
    addTearDown(client.dispose);
    client.connect(
      HostAddress.local(hostId: server.hostId, name: 'Test phone'),
      code: server.pairingCode,
    );
    await until(client.changes, (s) => s.isConnected);
    return client;
  }

  ControllerClient phone(String id) {
    final c = ControllerClient(
      identity: ControllerIdentity(
        controllerId: id,
        name: 'Bob\'s phone',
        platform: 'android',
        appVersion: '0.11.0',
        capabilities: _caps,
        device: const DeviceInfo(
          kind: DeviceInfo.phone,
          model: 'Pixel 8',
          os: 'Android 15',
          widthMm: 150,
          heightMm: 70,
        ),
      ),
      connector: WebSocketConnector(),
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
      retryDelays: const [Duration(milliseconds: 50)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> connectPhone(ControllerClient p) async {
    p.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port!),
      code: server.pairingCode,
    );
    await until(p.changes, (s) => s.isConnected);
  }

  test('pause() ends and saves the session of a host playing alone, and with consent uploads it', () async {
    final link = InProcessListener();
    final stats = await startStats(consent: true, ownPlayer: link);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);
    expect(host.players.single.ownPlayer, isTrue, reason: 'the only player is the host\'s own');
    final ended = stats.session!.id;

    await stats.pause();

    // The own player is still paired, so a new session may already have
    // started; the rule is that the paused one is saved and never reopened.
    expect(stats.session?.id, isNot(ended), reason: 'a paused session is closed');
    final files = await stats.sessions();
    expect(files, hasLength(1), reason: 'pause() saves the session file');
    final saved = files.single.summary;
    expect(files.single.id, ended);
    expect(saved['host'], {'type': 'phone', 'app': '0.11.0'});
    // The host phone's own player, joined over the in-process link (m12 §0.2).
    expect((saved['players'] as List).single, containsPair('watched', 'host_phone'));
    expect(
      Directory('${dir.path}/sessions').listSync().whereType<File>(),
      hasLength(1),
      reason: 'the summary is on disk, not only queued',
    );
    await waitFor(() => uploader.uploaded.length == 1, timeout: const Duration(seconds: 3));
    expect(uploader.uploaded.single['id'], ended);
  });

  test('resume() retries the session pause() left unsent', () async {
    final link = InProcessListener();
    final stats = await startStats(consent: true, ownPlayer: link);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);
    uploader.failWith = 'offline';

    await stats.pause();
    await waitFor(() => stats.state.lastError != null);
    expect(uploader.uploaded, isEmpty);
    expect(stats.state.waiting, 1);

    uploader.failWith = null;
    await stats.resume();

    expect(uploader.uploaded, hasLength(1), reason: 'resume() uploads what is queued');
    expect(stats.state.waiting, 0);
  });

  test('a session ended by pause() starts a new one when a player changes afterwards', () async {
    final link = InProcessListener();
    final stats = await startStats(consent: false, ownPlayer: link);
    final own = await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);
    final first = stats.session!.id;

    await stats.pause();
    expect(await stats.sessions(), hasLength(1), reason: 'pause() ended and saved that session');
    final local = host.addLocalPlayer();
    await waitFor(() {
      final s = stats.session;
      return s != null && (s.summary(host.nowMs)['players'] as List).length == 2;
    });
    expect(stats.session!.id, isNot(first), reason: 'a saved session is never reopened');
    expect(host.players.map((p) => p.id), contains(local.id));
    expect(
      stats.session!.summary(host.nowMs)['players'] as List,
      hasLength(2),
      reason: 'the players still here join the new session, not the saved one',
    );

    local.remove();
    own.disconnect();
    await waitFor(() => stats.session == null);
  });

  test('a TV host stays open past sessionGap while two phones are connected and ends after they leave', () async {
    final stats = await startStats(consent: false);
    final a = phone('phone-a');
    final b = phone('phone-b');
    await connectPhone(a);
    await connectPhone(b);
    await waitFor(() => stats.session != null);
    final running = stats.session!.id;

    // No pause() on a TV host: nobody's app is hidden, so the session has to
    // wait the phones out.
    await Future<void>.delayed(_twoGaps);

    expect(stats.session?.id, running, reason: 'two phones are still playing');
    expect(await stats.sessions(), isEmpty, reason: 'nothing is saved while they play');

    a.disconnect();
    b.disconnect();
    await waitFor(() => stats.session == null);
    final files = await stats.sessions();
    expect(files, hasLength(1));
    expect(files.single.id, running);
    expect((files.single.summary['players'] as List), hasLength(2));
  });

  test('dispose still ends and saves the running session', () async {
    final link = InProcessListener();
    final stats = await startStats(consent: false, ownPlayer: link);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);
    final running = stats.session!.id;

    await stats.dispose();

    expect(stats.session, isNull);
    final files = await stats.sessions();
    expect(files, hasLength(1));
    expect(files.single.id, running);
  });
}
