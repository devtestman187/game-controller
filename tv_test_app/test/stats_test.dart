import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/src/analytics.dart';

class FakeUploader implements SessionUploader {
  final uploaded = <Map<String, Object?>>[];
  String? failWith;

  @override
  Future<String?> upload(Map<String, Object?> summary) async {
    if (failWith != null) return failWith;
    uploaded.add(summary);
    return null;
  }
}

const _caps = [Capability.metrics, Capability.rating];

Future<T> until<T>(Stream<T> s, bool Function(T) test) => s.firstWhere(test).timeout(const Duration(seconds: 5));

Future<void> waitFor(bool Function() test, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory dir;
  late HostServer server;
  late ServerGameHost host;
  late SharedPreferences prefs;
  late FakeUploader uploader;

  Future<LiveStats> startStats({bool? consent}) async {
    SharedPreferences.setMockInitialValues({'statsConsent': ?consent});
    prefs = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('tp-stats-');
    addTearDown(() => dir.delete(recursive: true));
    server = HostServer(
      hostId: 'tv',
      hostName: 'Test TV',
      appVersion: '0.9.0',
      preferredPort: 0,
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
      hostApp: '0.9.0',
      sessionGap: const Duration(milliseconds: 400),
      uploader: uploader,
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

  ControllerClient phone(String id) {
    final c = ControllerClient(
      identity: ControllerIdentity(
        controllerId: id,
        name: 'Bob\'s phone',
        platform: 'android',
        appVersion: '0.9.0',
        capabilities: _caps,
        device: const DeviceInfo(
          kind: DeviceInfo.phone,
          model: 'Pixel 8',
          os: 'Android 15',
          widthMm: 150,
          heightMm: 70,
        ),
      ),
      heartbeatInterval: const Duration(milliseconds: 100),
      heartbeatTimeout: const Duration(milliseconds: 1500),
      retryDelays: const [Duration(milliseconds: 50)],
    );
    addTearDown(c.dispose);
    return c;
  }

  MetricsMessage batch(
    String seg,
    int i, {
    required String mode,
    required int ms,
    bool ended = false,
    Map<String, Object?> data = const {},
  }) => MetricsMessage(segment: seg, index: i, mode: mode, durationMs: ms, ended: ended, data: data);

  test(
    'a simulated session, with a Wi-Fi drop, produces the known summary; nothing is uploaded without consent',
    () async {
      final stats = await startStats();
      expect(stats.state.consent, isNull);
      final p = phone('phone-a');
      // Answers every rating prompt with "good".
      p.ratingAsks.listen(
        (ask) => p.sendRating(RatingMessage(id: ask.id, face: RatingFace.good, tags: [RatingTag.laggy])),
      );
      p.connect(
        HostAddress(addresses: ['127.0.0.1'], port: server.port!),
        code: server.pairingCode,
      );
      await until(p.changes, (s) => s.isConnected);
      await waitFor(() => stats.session != null && host.players.isNotEmpty);

      // D-pad for 40 s with near misses next to B, then sticks.
      p.sendInput({ControllerButton.a}, dx: 1);
      p.sendMetrics(
        batch(
          'a-1',
          0,
          mode: 'dpad',
          ms: 20000,
          data: {
            'start': 0,
            'touches': 10,
            'near': {'b': 1},
          },
        ),
      );
      await waitFor(() => p.metricsWaiting == 1);

      // Wi-Fi off: the TV drops the phone; batches made meanwhile wait.
      server.dropAllConnections();
      await until(p.changes, (s) => s.status == ClientStatus.reconnecting);
      p.sendMetrics(
        batch(
          'a-1',
          1,
          mode: 'dpad',
          ms: 40000,
          ended: true,
          data: {
            'start': 0,
            'touches': 30,
            'near': {'b': 3},
            'empty': {'5,1': 3},
          },
        ),
      );
      p.sendMetrics(
        batch(
          'a-2',
          0,
          mode: 'sticks',
          ms: 5000,
          data: {
            'start': 40000,
            'touches': 4,
            'presses': {'ls': 2},
          },
        ),
      );
      await until(p.changes, (s) => s.isConnected);
      await waitFor(() => p.metricsWaiting == 1, timeout: const Duration(seconds: 3)); // a-2 is still open.

      // Now in stick mode, as the segments say.
      p.sendInput(const {}, left: (x: 0.5, y: 0), right: (x: 0, y: 0));
      await waitFor(() => host.players.single.mode == InputMode.sticks);

      // Three arena rounds: the rating prompt comes after the third.
      for (var i = 0; i < 3; i++) {
        host.record(const GameRecord(game: 'arena', name: 'round_start'));
        host.record(const GameRecord(game: 'arena', name: 'wall_hit', playerId: 'phone-a'));
        host.record(
          const GameRecord(
            game: 'arena',
            name: 'round_end',
            data: {
              'timeS': 10.0,
              'modes': {'phone-a': 'sticks'},
              'winner': 'phone-a',
            },
          ),
        );
      }
      host.reportStage('phone-a', LatencyStage.receivedToDrawn, 7);
      await waitFor(
        () =>
            (stats.session!.summary(host.nowMs)['players'] as List).isNotEmpty &&
            ((stats.session!.summary(host.nowMs)['players'] as List).first as Map)['ratings'].isNotEmpty,
      );

      // The phone leaves; the session ends after the gap and is saved.
      p.disconnect();
      await waitFor(() => stats.session == null);
      final files = await stats.sessions();
      expect(files, hasLength(1));
      final s = files.single.summary;
      expect(s['host'], {'type': 'windows', 'app': '0.9.0'});
      expect(s['rounds'], hasLength(3));
      final player = (s['players'] as List).single as Map;
      expect(player['player'], 1);
      expect(player['device'], {'kind': 'phone', 'model': 'Pixel 8', 'os': 'Android 15', 'wMm': 150, 'hMm': 70});
      expect(player['disconnects'], 1, reason: 'the Wi-Fi drop; the final leave is not a drop');
      final segments = {for (final seg in player['segments'] as List) (seg as Map)['id']: seg};
      expect((segments['a-1'] as Map)['ended'], isTrue);
      expect(((segments['a-1'] as Map)['data'] as Map)['near'], {'b': 3});
      expect(((segments['a-2'] as Map)['data'] as Map)['presses'], {'ls': 2});
      expect(player['switches'], [
        {'from': 'dpad', 'to': 'sticks', 'atS': 40},
      ]);
      expect(player['ratings'], [
        {
          'game': 'arena',
          'face': 'good',
          'tags': ['laggy'],
          'mode': 'sticks',
        },
      ]);
      expect((player['games'] as Map)['arena'], {'wall_hit': 3, 'wins': 3, 'rounds': 3});
      expect((player['stages'] as Map)['received_to_drawn'], {'n': 1, 'median': 7, 'p95': 7, 'max': 7});
      expect(player['inputs'], greaterThan(0));

      // No names or network details in the file.
      final text = jsonEncode(s);
      expect(text, isNot(contains('Bob')));
      expect(text, isNot(contains('127.0.0.1')));
      expect(text, isNot(contains('Test TV')));

      // No consent: nothing goes out.
      await stats.uploadNow();
      expect(uploader.uploaded, isEmpty);

      // Consent: the finished session is uploaded, once.
      stats.setConsent(true);
      await waitFor(() => uploader.uploaded.length == 1);
      await stats.uploadNow();
      expect(uploader.uploaded, hasLength(1));
      expect(stats.state.uploaded, 1);
      expect(prefs.getBool('statsConsent'), isTrue);
    },
  );

  test('with consent, a failed upload waits in the queue and goes later', () async {
    final stats = await startStats(consent: true);
    final p = phone('phone-b');
    p.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port!),
      code: server.pairingCode,
    );
    await until(p.changes, (s) => s.isConnected);
    await waitFor(() => stats.session != null);
    uploader.failWith = 'offline';
    p.disconnect();
    await waitFor(() => stats.session == null);
    await waitFor(() => stats.state.lastError != null);
    expect(uploader.uploaded, isEmpty);
    expect(stats.state.waiting, 1);

    uploader.failWith = null;
    await stats.uploadNow();
    expect(uploader.uploaded, hasLength(1));
    expect(stats.state.waiting, 0);
  });

  test('turning consent off stops uploads', () async {
    final stats = await startStats(consent: false);
    final p = phone('phone-c');
    p.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port!),
      code: server.pairingCode,
    );
    await until(p.changes, (s) => s.isConnected);
    await waitFor(() => stats.session != null);
    p.disconnect();
    await waitFor(() => stats.session == null);
    await stats.uploadNow();
    expect(uploader.uploaded, isEmpty);
    expect((await stats.sessions()), hasLength(1), reason: 'still kept on the TV');
  });

  test('Export copies every session file', () async {
    final stats = await startStats();
    final p = phone('phone-d');
    p.connect(
      HostAddress(addresses: ['127.0.0.1'], port: server.port!),
      code: server.pairingCode,
    );
    await until(p.changes, (s) => s.isConnected);
    await waitFor(() => stats.session != null);
    p.disconnect();
    await waitFor(() => stats.session == null);
    final path = await stats.exportAll();
    final copied = Directory(path).listSync().whereType<File>().toList();
    expect(copied, hasLength(1));
    expect(jsonDecode(copied.single.readAsStringSync())['schema'], summarySchema);
  });

  test('the Firestore upload sends the summary as JSON text with the checked fields', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    Map<String, Object?>? got;
    Uri? uri;
    server.listen((r) async {
      uri = r.uri;
      got = jsonDecode(await utf8.decodeStream(r)) as Map<String, Object?>;
      r.response.statusCode = 200;
      await r.response.close();
    });
    // Points the uploader at the local server instead of Google.
    final up = FirestoreUploader(project: 'p', client: () => _Redirect(server.port));
    final error = await up.upload({
      'schema': 1,
      'id': 'abc',
      'date': '2026-10-31',
      'host': {'type': 'windows', 'app': '0.9.0'},
    });
    expect(error, isNull);
    expect(uri!.path, '/v1/projects/p/databases/(default)/documents/sessions');
    expect(uri!.queryParameters['documentId'], 'abc');
    final fields = got!['fields'] as Map;
    expect(fields.keys.toSet(), {'json', 'schema', 'date', 'app', 'host'});
    expect(jsonDecode((fields['json'] as Map)['stringValue'] as String)['id'], 'abc');
  });
}

/// An HttpClient that sends every request to localhost:[port] over plain HTTP.
class _Redirect implements HttpClient {
  _Redirect(this.port);

  final int port;
  final _inner = HttpClient();

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _inner.postUrl(url.replace(scheme: 'http', host: '127.0.0.1', port: port));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
