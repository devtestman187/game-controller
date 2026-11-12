import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The streaming session tool (M15) is a developer script, but it is the only
/// way a person starts a stream, and it runs commands as root inside a Linux
/// distro: its guard rails are tested here like any other rule. The player's
/// relay (M15 t1) is the session's one door to the host's API, so the paths it
/// answers, and the size it refuses, are tested here too.
void main() {
  // `flutter test` runs in tv_test_app, where the tests live.
  const script = '../tools/stream.sh';

  Future<ProcessResult> run(List<String> arguments, {Map<String, String>? environment}) =>
      Process.run('bash', [script, ...arguments], environment: environment);

  test('the tool refuses a distro whose name does not start with tp-', () async {
    final result = await run(['--distro', 'minecraft', 'up']);

    expect(result.exitCode, 2, reason: 'a bad distro is bad use, and nothing runs');
    expect(result.stderr, contains('the distro name must start with "tp-"'));
  });

  test('the tool prints its usage when it is not told what to do', () async {
    final result = await run([]);

    expect(result.exitCode, 2);
    expect(result.stdout, contains('tools/stream.sh build'));
    expect(result.stdout, contains('tools/stream.sh up'));
    expect(result.stdout, contains('tools/stream.sh bench'), reason: 'the benchmark is one of its commands');
    expect(result.stdout, contains('tools/stream.sh stats'), reason: 'and the report it prints');
  });

  test('a benchmark refuses a label that is not lower-case', () async {
    final result = await run(['bench', '--label', 'BAD']);

    expect(result.exitCode, 1, reason: 'the label names files in docs/, so it is checked first');
    expect(result.stderr, contains('the label is lower-case letters, digits and dashes'));
  });

  test('the report refuses a folder that is not there', () async {
    final result = await run(['stats', '--results', 'docs/nope']);

    expect(result.exitCode, 1);
    expect(result.stderr, contains('no results at docs/nope'));
  });

  test('the streaming scripts are valid bash', () async {
    for (final file in ['../streaming/entrypoint.sh', '../streaming/bench.sh', '../tools/stream.sh']) {
      final result = await Process.run('bash', ['-n', file]);

      expect(result.exitCode, 0, reason: '$file: ${result.stderr}');
    }
  });

  test('a stale keep-alive pid file is reported, not acted on', () async {
    final folder = Directory.systemTemp.createTempSync('tp-stream-test');
    addTearDown(() => folder.deleteSync(recursive: true));
    final pidFile = File('${folder.path}/keepalive.pid')..writeAsStringSync('999999\n');
    final environment = {'STREAM_KEEPALIVE_FILE': pidFile.path};

    final result = await run(['keep-alive'], environment: environment);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('keep-alive: not running (a stale pid file'));
    final stopped = await run(['keep-alive', '--stop'], environment: environment);
    expect(stopped.exitCode, 0);
    expect(pidFile.existsSync(), isFalse, reason: 'stopping clears the file, whatever it held');
  });

  test('the keep-alive never ends a process that is not its own', () async {
    final folder = Directory.systemTemp.createTempSync('tp-stream-test');
    addTearDown(() => folder.deleteSync(recursive: true));
    // This test process is alive but its command line is not the keep-alive's
    // `sleep infinity`, so the pid check must refuse it.
    final pidFile = File('${folder.path}/keepalive.pid')..writeAsStringSync('$pid\n');

    final result = await run(['keep-alive', '--stop'], environment: {'STREAM_KEEPALIVE_FILE': pidFile.path});

    expect(result.exitCode, 0);
    expect(result.stdout, isNot(contains('keep-alive: stopped')), reason: 'that pid is not the keep-alive');
    expect(pidFile.existsSync(), isFalse);
  });

  test('a benchmark refuses a setting that is not KEY=VALUE', () async {
    for (final setting in ['nope', 'lower=x', 'KEY=two words']) {
      final result = await run(['bench', '--set', setting]);

      expect(result.exitCode, 2, reason: '"$setting" would reach docker run as -e');
      expect(result.stderr, contains('a setting is KEY=VALUE (upper-case name, a plain value)'));
    }
  });

  final python = findPython();

  group('the player relay', () {
    late Process server;
    late int port;
    late int hostPort;

    setUpAll(() async {
      port = await freePort();
      hostPort = await freePort();
      server = await Process.start(python!, [
        '../streaming/player/serve.py',
        '--port',
        '$port',
        '--directory',
        Directory('../streaming/player').absolute.path,
        '--automation-port',
        '$hostPort',
        '--state',
        Directory.systemTemp.path,
      ]);
      // The relay says little, but an undrained pipe would hold it up.
      server.stdout.listen((_) {});
      server.stderr.listen((_) {});
      await waitForRelay(port);
    });

    tearDownAll(() async {
      server.kill();
      await server.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
    });

    test('serves the page and the files it loads', () async {
      final page = await get(port, '/');
      expect(page.$1, 200, reason: 'the page itself is `/`');
      expect(page.$2.toLowerCase(), contains('<!doctype html'));

      final player = await get(port, '/player.js');
      expect(player.$1, 200, reason: 'the page loads it');
    });

    test('answers 404 for every path it does not list, the host\'s own included', () async {
      final automation = await get(port, '/automation/v1/status');
      expect(automation.$1, 404, reason: 'the relay is not a door to the automation interface');
      expect(automation.$2, contains('no file at /automation/v1/status'));

      final players = await post(port, '/players', '{}');
      expect(players.$1, 404, reason: 'a POST may only go to the four calls the page makes');
      expect(players.$2, contains('no call at /players'));
    });

    test('forwards a measurement to the host, and says so when it cannot', () async {
      final answer = await post(port, '/stats/stream', '{"viewers": [], "host": {}}');

      expect(answer.$1, 502, reason: 'nothing listens on the automation port in this test');
      expect(answer.$2, contains('the host is not answering'));
    });

    test('refuses a body over 64 KB before it reads it', () async {
      // A body promised but not sent: the relay checks the length first, so it
      // answers without waiting for it (and the socket is never reset).
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write(
        'POST /stats/stream HTTP/1.1\r\nHost: 127.0.0.1\r\n'
        'Content-Type: application/json\r\nContent-Length: 65537\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();
      final answer = await utf8.decoder.bind(socket).join().timeout(const Duration(seconds: 10));
      socket.destroy();

      expect(answer, contains('413'));
      expect(answer, contains('over 65536 bytes'));
    });
  }, skip: python == null ? 'no python to run the relay' : false);
}

/// The Python that can run `serve.py`: `python` on Windows, `python3` (or
/// `python`) elsewhere. Null when there is none, which skips the relay's tests.
String? findPython() {
  for (final candidate in Platform.isWindows ? ['python'] : ['python3', 'python']) {
    try {
      if (Process.runSync(candidate, ['--version']).exitCode == 0) {
        return candidate;
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

/// One port nothing is listening on: bound, read, and given back.
Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// GETs `path` from the relay, answering (status, body).
///
/// A raw socket, not `HttpClient`: a widget test replaces every HTTP request
/// with a 400 and never lets one out, and this one has to reach a real process.
Future<(int, String)> get(int port, String path) => exchange(port, 'GET', path);

/// POSTs one JSON `body` to the relay, answering (status, body).
Future<(int, String)> post(int port, String path, String body) => exchange(port, 'POST', path, body: body);

/// One request to the relay over a socket of its own, answering (status, body).
Future<(int, String)> exchange(int port, String method, String path, {String? body}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final payload = utf8.encode(body ?? '');
  final head = StringBuffer('$method $path HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n');
  if (body != null) {
    head.write('Content-Type: application/json\r\nContent-Length: ${payload.length}\r\n');
  }
  head.write('\r\n');
  socket.add(utf8.encode(head.toString()));
  socket.add(payload);
  await socket.flush();
  final raw = await utf8.decoder.bind(socket).join().timeout(const Duration(seconds: 10));
  socket.destroy();
  final status = int.parse(raw.split(' ')[1]);
  final bodyStart = raw.indexOf('\r\n\r\n');
  return (status, bodyStart < 0 ? raw : raw.substring(bodyStart + 4));
}

/// Waits until the relay answers on `port`, up to ten seconds.
Future<void> waitForRelay(int port) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    try {
      final answer = await exchange(port, 'GET', '/player');
      if (answer.$1 == 200) {
        return;
      }
    } on SocketException {
      // Not listening yet.
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('the relay did not answer within ten seconds');
}
