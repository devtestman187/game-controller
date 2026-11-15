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

/// The gap these tests wait out: short, so a session that should end ends
/// while the test watches (B-019).
const _gap = Duration(milliseconds: 400);

/// No heartbeat traffic: a pong reaches the server as a change, and these
/// tests change who is here only through the call they check (B-019).
const _quietLink = Duration(minutes: 1);

Future<T> until<T>(Stream<T> s, bool Function(T) test) => s.firstWhere(test).timeout(const Duration(seconds: 5));

Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Lets the changes that pairing made arrive, so the test starts from a quiet
/// host: the call under test is then the only thing that changes presence.
Future<void> settle() async {
  for (var turn = 0; turn < 4; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Runs [body] with every timer it creates recorded in [created], so a test
/// can prove that nothing it started is still running (B-019 fix 5).
Future<void> watchingTimers(List<Timer> created, Future<void> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) {
      final timer = parent.createTimer(zone, duration, callback);
      created.add(timer);
      return timer;
    },
    createPeriodicTimer: (self, parent, zone, period, callback) {
      final timer = parent.createPeriodicTimer(zone, period, callback);
      created.add(timer);
      return timer;
    },
  ),
);

/// An uploader the test releases itself: every upload waits at a gate, so the
/// test decides when it fails and can see what the failure left behind.
class _GatedUploader implements SessionUploader {
  /// Completes when the first upload has been asked for.
  final started = Completer<void>();

  /// Every summary handed over, in order.
  final offered = <Map<String, Object?>>[];

  /// While set, the uploads the test releases fail with this message.
  String? failWith;
  final _gate = Completer<void>();

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    offered.add(summary);
    if (!started.isCompleted) started.complete();
    await _gate.future;
    return failWith;
  }

  /// Lets every waiting upload finish.
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }
}

/// What `state.current` was right after each session's file was written: the
/// "saved" log line comes just before the session's summary is cleared, so a
/// microtask from there reads the state the clear left (B-019 fix 8).
class _SaveWatch {
  /// One (session ID, the ID `current` showed once it was written) per save.
  final states = <(String, Object?)>[];

  /// The stats whose state the saves are read from.
  LiveStats? stats;

  void log(String line) {
    final id = RegExp(r'^Stats: session (\w+) saved').firstMatch(line)?.group(1);
    if (id == null) return;
    scheduleMicrotask(() => states.add((id, stats?.state.current?['id'])));
  }
}

void main() {
  late Directory dir;
  late HostServer server;
  late ServerGameHost host;
  late SharedPreferences prefs;

  /// The clock the sessions are stamped with; injected, so a summary's start
  /// time is the same in every run.
  final now = DateTime(2026, 11, 15, 10, 30);

  /// A phone host playing its own player over [link], with [uploader] when the
  /// test needs to hold an upload.
  Future<LiveStats> startStats({
    bool? consent,
    InProcessListener? ownPlayer,
    SessionUploader? uploader,
    _SaveWatch? watch,
  }) async {
    SharedPreferences.setMockInitialValues({'statsConsent': ?consent});
    prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-fix-');
    final folder = dir;
    addTearDown(() => deleteTempFolder(folder));
    final listener = ownPlayer ?? WebSocketListener(preferredPort: 0, hostName: 'Test host');
    server = HostServer(
      hostId: ownPlayer == null ? 'tv' : 'phone',
      hostName: 'Test host',
      appVersion: '0.11.0',
      listeners: [listener],
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
      hostType: ownPlayer == null ? HostType.windows : HostType.phone,
      hostApp: '0.11.0',
      sessionGap: _gap,
      uploader: uploader,
      clock: () => now,
      log: watch?.log,
    );
    watch?.stats = stats;
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
      heartbeatInterval: _quietLink,
      heartbeatTimeout: _quietLink,
    );
    addTearDown(client.dispose);
    client.connect(
      HostAddress.local(hostId: server.hostId, name: 'Test phone'),
      code: server.pairingCode,
    );
    await until(client.changes, (s) => s.isConnected);
    return client;
  }

  test('resume() starts a new session for the own player who stayed paired, with no join or leave', () async {
    final link = InProcessListener();
    final stats = await startStats(ownPlayer: link);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);
    await settle();
    final paused = stats.session!.id;

    await stats.pause();
    expect(stats.session, isNull, reason: 'nobody joined or left, so pause() leaves no session');

    await stats.resume();

    final resumed = stats.session;
    expect(resumed, isNotNull, reason: 'the own player is still here, so resume() starts a new session');
    expect(resumed!.id, isNot(paused), reason: 'the paused session is saved, never reopened');
    final players = resumed.summary(host.nowMs)['players'] as List;
    expect(players, hasLength(1), reason: 'the still-paired player joins the new session once, not twice');
    expect(players.single, containsPair('install', 'own-player'));
    expect(players.single, containsPair('watched', 'host_phone'));
    expect(server.snapshot.connected, hasLength(1), reason: 'no join or leave happened: the link never dropped');
  });

  test('a failing upload that the end of dispose() started leaves no retry timer running', () async {
    final uploader = _GatedUploader();
    final link = InProcessListener();
    final stats = await startStats(consent: true, ownPlayer: link, uploader: uploader);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);

    final created = <Timer>[];
    await watchingTimers(created, () async {
      final disposing = stats.dispose();
      await uploader.started.future; // the ended session's upload is in flight
      await disposing; // dispose() has cancelled its timer and closed the streams
      uploader.failWith = 'offline';
      uploader.release(); // the upload fails after dispose(), where the retry used to be armed
      await Future<void>.delayed(Duration.zero);
    });

    expect(uploader.offered, hasLength(1), reason: 'the ended session was queued for upload');
    expect(stats.state.lastError, 'offline', reason: 'the upload did run and fail after dispose()');
    expect(created.where((t) => t.isActive), isEmpty, reason: 'no timer outlives dispose()');
  });

  test('a save that lands keeps the summary of the session that is still being written', () async {
    final link = InProcessListener();
    final watch = _SaveWatch();
    final stats = await startStats(ownPlayer: link, watch: watch);
    await connectOwnPlayer(link);
    await waitFor(() => stats.session != null);

    // Each session is saved by writing its file, and the two files are written
    // in whichever order the disk finishes them. The case the fix is for is the
    // older file written first, while the newer session is still being written,
    // so the pair is repeated until that order comes up (B-019).
    var seen = 0;
    for (var attempt = 0; attempt < 10 && seen == 0; attempt++) {
      // A player joins: a session runs for the players who are here.
      host.addLocalPlayer();
      await Future<void>.microtask(() {});
      final running = stats.session;
      expect(running, isNotNull, reason: 'the player who joined has a session');
      final first = running!.id;

      final firstEnd = stats.pause();
      host.addLocalPlayer();
      await Future<void>.microtask(() {});
      final second = stats.session;
      expect(second, isNotNull, reason: 'the player who joined starts a new session');
      expect(second!.id, isNot(first));
      final secondEnd = stats.pause();

      await firstEnd;
      await secondEnd;

      final firstAt = watch.states.indexWhere((s) => s.$1 == first);
      final secondAt = watch.states.indexWhere((s) => s.$1 == second.id);
      if (firstAt < 0 || secondAt < 0 || secondAt < firstAt) continue; // the newer file was written first
      seen++;
      expect(
        watch.states[firstAt].$2,
        second.id,
        reason: 'the summary of the session that is still being written stays when the older save lands',
      );
    }
    expect(seen, 1, reason: 'one attempt wrote the older file first, which is the case under test');
  });
}
