import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_test_support.dart';

/// Waits until [test] holds; a host that never gets there fails the test.
Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 30)}) async {
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

const _unmarkedId = 'old-unmarked';
const _markedId = 'new-marked';

/// A session saved by a build that never asked: no player has a `share` key.
Map<String, Object?> unmarkedFile() => {
  'schema': summarySchema,
  'id': _unmarkedId,
  'host': {'type': 'windows', 'app': '0.14.0'},
  'durationS': 60,
  'startedAt': '2026-11-10T10:00:00.000',
  'players': [
    {'install': 'old-a', 'player': 1},
  ],
  'rounds': [
    {'game': 'arena', 'players': 1, 'timeS': 5.0, 'winner': 1},
  ],
  'frames': {'drawn': 30, 'dropped': 1},
};

/// A session saved by this build: its one player said yes.
Map<String, Object?> markedFile() => {
  'schema': summarySchema,
  'id': _markedId,
  'host': {'type': 'windows', 'app': '0.14.0'},
  'durationS': 30,
  'startedAt': '2026-11-15T10:00:00.000',
  'players': [
    {'install': 'new-a', 'player': 1, 'share': true},
  ],
  'rounds': [
    {'game': 'arena', 'players': 1, 'timeS': 4.0, 'winner': 1},
  ],
  'frames': {'drawn': 20, 'dropped': 0},
};

void main() {
  late Directory dir;
  late SharedPreferences prefs;
  late FakeUploader uploader;

  /// Starts with both files already in the sessions folder, as a TV that ran
  /// an older build and then this one has them, and consent given.
  Future<LiveStats> startStats() async {
    SharedPreferences.setMockInitialValues({'statsConsent': true});
    prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-unmarked-');
    final folder = dir;
    addTearDown(() => deleteTempFolder(folder));
    final sessions = Directory('${dir.path}/sessions');
    await sessions.create(recursive: true);
    for (final summary in [unmarkedFile(), markedFile()]) {
      await File('${sessions.path}/session-${summary['id']}.json').writeAsString(jsonEncode(summary));
    }
    final server = HostServer(
      hostId: 'tv',
      hostName: 'Test TV',
      appVersion: '0.14.0',
      listeners: const [],
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
    );
    final host = ServerGameHost(server);
    uploader = FakeUploader();
    final stats = LiveStats(
      server: server,
      host: host,
      prefs: prefs,
      exportDirectory: () async => Directory('${dir.path}/export'),
      hostType: HostType.windows,
      hostApp: '0.14.0',
      uploader: uploader,
    );
    await stats.start(sessions);
    addTearDown(() async {
      await stats.dispose();
      await host.dispose();
      await server.dispose();
      await settleUploads(stats);
    });
    return stats;
  }

  test('a saved session with no share marks is not uploaded, while the marked one is', () async {
    final stats = await startStats();

    // Wait for the finished pass, not the first event: the marked upload, the
    // prefs write and the last count refresh all land after the unmarked skip.
    await waitFor(
      () =>
          stats.state.uploaded == 1 &&
          stats.state.waiting == 0 &&
          (prefs.getStringList('skippedSessions') ?? const []).contains(_unmarkedId),
    );

    // What went up: only the session whose player said yes.
    expect([for (final s in uploader.uploaded) s['id']], [_markedId]);
    expect([for (final p in mapsOf(uploader.uploaded.single['players'])) p['install']], ['new-a']);
    expect(prefs.getStringList('uploadedSessions'), [_markedId], reason: 'the unmarked session is not uploaded');
    expect(prefs.getStringList('skippedSessions'), [_unmarkedId], reason: 'it is dropped, and kept out of the queue');

    // Neither the queue nor the Stats screen counts it as waiting.
    expect(stats.state.waiting, 0);
    expect(stats.state.saved, 2);

    // Both files stay on the device for the Stats screen.
    final files = await stats.sessions();
    expect([for (final f in files) f.id], unorderedEquals([_unmarkedId, _markedId]));
    expect(Directory('${dir.path}/sessions').listSync().whereType<File>(), hasLength(2));

    // A later pass leaves the unmarked file alone, without uploading anything twice.
    await stats.uploadNow();
    expect(uploader.uploaded, hasLength(1));
    expect(stats.state.waiting, 0);
  });
}
