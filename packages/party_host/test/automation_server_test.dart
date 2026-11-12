import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// A call as the wire carries it: the code, and the JSON body when there is
/// one.
typedef _Reply = ({int code, Map<String, Object?> body, List<int> bytes, String type});

/// An [AutomationApi] that writes down what it was asked, so a test sees a
/// route reach the action it names (M15 a2).
final class _FakeApi implements AutomationApi {
  /// Each call's name, in order.
  final calls = <String>[];

  /// The body of the last call that took one.
  Map<String, Object?>? lastBody;

  /// The last answer to `POST probe/flash`, or null for none yet.
  bool? flashed;

  /// What `GET screenshot` returns; null says the host has no frame.
  List<int>? png = const [1, 2, 3];

  /// The message [input] throws, when a test has it refuse.
  String? refuseInput;

  @override
  Map<String, Object?> status() {
    calls.add('status');
    return {'version': '0.1.0'};
  }

  @override
  Map<String, Object?> players(Map<String, Object?> body) {
    calls.add('players');
    lastBody = body;
    return {
      'player': {'id': 'local-1'},
    };
  }

  @override
  Map<String, Object?> input(Map<String, Object?> body) {
    calls.add('input');
    lastBody = body;
    final refusal = refuseInput;
    if (refusal != null) throw AutomationError(refusal);
    return {'hostMs': 100};
  }

  @override
  Map<String, Object?> startGame(Map<String, Object?> body) {
    calls.add('game/start');
    lastBody = body;
    return {
      'round': {'game': 'arena'},
    };
  }

  @override
  Map<String, Object?> stopGame() {
    calls.add('game/stop');
    return const {};
  }

  @override
  Map<String, Object?> settings(Map<String, Object?> body) {
    calls.add('settings');
    lastBody = body;
    return {'settings': body};
  }

  @override
  Map<String, Object?> state() {
    calls.add('state');
    return {'round': null};
  }

  @override
  void flashProbe({required bool on}) {
    calls.add('probe/flash');
    flashed = on;
  }

  @override
  Map<String, Object?> pressProbe(Map<String, Object?> body) {
    calls.add('probe/press');
    lastBody = body;
    return {'hostMs': 1234};
  }

  @override
  Map<String, Object?> ingestStream(Map<String, Object?> body) {
    calls.add('stats/stream');
    lastBody = body;
    return {'viewer': 'v1'};
  }

  @override
  Map<String, Object?> session() {
    calls.add('stats/session');
    return {'running': false};
  }

  @override
  Future<List<int>?> screenshotPng() async {
    calls.add('screenshot');
    return png;
  }
}

/// A server on a free loopback port, started and stopped around the test.
Future<AutomationServer> _started(AutomationSettings settings, AutomationApi api) async {
  final server = AutomationServer(settings: settings, api: api);
  addTearDown(server.stop);
  await server.start();
  return server;
}

/// One request to [server], as a script makes it.
Future<_Reply> _call(
  AutomationServer server,
  String method,
  String call, {
  Map<String, Object?>? body,
  String? token,
  String? raw,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}${AutomationServer.prefix}$call'),
    );
    if (token != null) request.headers.set(AutomationServer.tokenHeader, token);
    final text = raw ?? (body == null ? null : jsonEncode(body));
    if (text != null) {
      request.headers.contentType = ContentType.json;
      request.write(text);
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    final type = response.headers.contentType?.mimeType ?? '';
    final decoded = type == 'application/json'
        ? jsonDecode(utf8.decode(bytes)) as Map<String, Object?>
        : const <String, Object?>{};
    return (code: response.statusCode, body: decoded, bytes: bytes, type: type);
  } finally {
    client.close(force: true);
  }
}

/// One request that declares [length] bytes of body, as a script sending a
/// `Content-Length` does: unlike [_callChunked] the server is told the size in
/// the header, so it can refuse from that number.
Future<_Reply> _callDeclaring(AutomationServer server, String call, int length) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      'POST',
      Uri.parse('http://127.0.0.1:${server.port}${AutomationServer.prefix}$call'),
    );
    request.headers.contentType = ContentType.json;
    request.contentLength = length;
    request.add(List<int>.filled(length, 0x78));
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    final type = response.headers.contentType?.mimeType ?? '';
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    return (code: response.statusCode, body: decoded, bytes: bytes, type: type);
  } finally {
    client.close(force: true);
  }
}

/// One request whose body has no declared length, so it goes out chunked and
/// the server can only see its size as it reads.
Future<_Reply> _callChunked(AutomationServer server, String call, String body) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      'POST',
      Uri.parse('http://127.0.0.1:${server.port}${AutomationServer.prefix}$call'),
    );
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(body));
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    return (
      code: response.statusCode,
      body: jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
      bytes: bytes,
      type: '',
    );
  } finally {
    client.close(force: true);
  }
}

void main() {
  test('off by default: nothing listens', () async {
    final api = _FakeApi();
    final off = await _started(const AutomationSettings(port: 0), api);
    expect(off.isListening, isFalse, reason: 'a store build and an ordinary launch listen to nothing');
    expect(off.port, isNull);
    expect(api.calls, isEmpty);
  });

  test('on by flag: it listens on this machine and answers status', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    expect(server.isListening, isTrue);
    expect(server.port, isNotNull);
    final reply = await _call(server, 'GET', '/status');
    expect(reply.code, 200);
    expect(reply.body, {'ok': true, 'version': '0.1.0'});
    expect(api.calls, ['status']);
  });

  test('a token is asked for on every request when one is set', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0, token: 'sekrit'), api);
    final bare = await _call(server, 'GET', '/status');
    expect(bare.code, 401);
    expect(bare.body['error'], contains(AutomationServer.tokenHeader));
    expect(api.calls, isEmpty, reason: 'nothing reaches the host without the token');
    expect((await _call(server, 'GET', '/status', token: 'wrong')).code, 401);
    expect((await _call(server, 'GET', '/status', token: 'sekrit')).code, 200);
    final bearer = HttpClient();
    addTearDown(bearer.close);
    final request = await bearer.openUrl(
      'GET',
      Uri.parse('http://127.0.0.1:${server.port}${AutomationServer.prefix}/status'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer sekrit');
    final response = await request.close();
    expect(response.statusCode, 200, reason: 'a Bearer header carries the token too');
    await response.drain<void>();
  });

  test('a bind beyond this machine without a token is refused, not started weakly', () async {
    final api = _FakeApi();
    final open = await _started(const AutomationSettings(enabled: true, bindAddress: '0.0.0.0', port: 0), api);
    expect(open.isListening, isFalse, reason: 'the settings problem keeps it off');

    final guarded = await _started(
      const AutomationSettings(enabled: true, bindAddress: '0.0.0.0', port: 0, token: 'sekrit'),
      api,
    );
    expect(guarded.isListening, isTrue);
  });

  test('each call reaches the action it names, with its body', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    final calls = {
      ('GET', '/status'): 'status',
      ('POST', '/players'): 'players',
      ('POST', '/input'): 'input',
      ('POST', '/game/start'): 'game/start',
      ('POST', '/game/stop'): 'game/stop',
      ('POST', '/settings'): 'settings',
      ('GET', '/state'): 'state',
      ('POST', '/probe/flash'): 'probe/flash',
      ('POST', '/probe/press'): 'probe/press',
      ('POST', '/stats/stream'): 'stats/stream',
      ('GET', '/stats/session'): 'stats/session',
      ('GET', '/screenshot'): 'screenshot',
    };
    for (final MapEntry(key: (method, call), value: name) in calls.entries) {
      final reply = await _call(
        server,
        method,
        call,
        body: method == 'POST' && call != '/probe/flash' ? {'player': 'local-1'} : null,
      );
      expect(reply.code, 200, reason: '$method $call answered ${reply.code}: ${reply.body}');
      expect(api.calls.last, name, reason: '$method $call runs $name');
      if (method == 'POST' && call != '/probe/flash' && call != '/game/stop') {
        expect(api.lastBody, {'player': 'local-1'}, reason: '$call carries its body');
      }
    }
    expect(api.flashed, isTrue, reason: 'an empty flash body shows the card');
    final hide = await _call(server, 'POST', '/probe/flash', body: {'on': false});
    expect(hide.code, 200);
    expect(api.flashed, isFalse);
  });

  test('a refusal says what to change, with the code for it', () async {
    final api = _FakeApi()..refuseInput = 'there is no simulated player yet: add one first';
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    final refused = await _call(server, 'POST', '/input', body: {'player': 'local-9'});
    expect(refused.code, 400);
    expect(refused.body, {'ok': false, 'error': 'there is no simulated player yet: add one first'});

    expect((await _call(server, 'GET', '/nope')).code, 404);
    final wrong = await _call(server, 'DELETE', '/status');
    expect(wrong.code, 405);
    expect(wrong.body['error'], 'that call is GET', reason: 'a wrong method says which is right');

    expect((await _call(server, 'POST', '/players', raw: 'not json')).code, 400);
    expect((await _call(server, 'POST', '/players', raw: '[1, 2]')).code, 400);
  });

  test('a body that declares more than the cap is refused whole, with a 400', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    // One byte over the cap, declared in the header: the answer comes from that
    // number alone, so unlike the chunked body above the script hears the line.
    final tooLong = await _callDeclaring(server, '/players', AutomationServer.maxBodyBytes + 1);
    expect(tooLong.code, 400);
    expect(tooLong.body, {'ok': false, 'error': 'the body is too long'});
    expect(api.calls, isEmpty, reason: 'nothing reaches the host');
  });

  test('a body with no length stops being read at the cap, and is refused', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    // A body that says it is over the cap is refused from that number alone: no
    // chunk is read.
    await expectLater(
      readRequestBody(const Stream<List<int>>.empty(), contentLength: AutomationServer.maxBodyBytes + 1),
      throwsA(isA<AutomationError>()),
    );
    // A chunked body has no length to read: the server stops at the cap, answers
    // and closes, so a client already writing past the cap may see the close
    // instead of the line (the body is not read further to hand it over). The
    // host is never asked either way.
    await expectLater(
      _callChunked(server, '/players', 'x' * (AutomationServer.maxBodyBytes + 1)),
      throwsA(isA<HttpException>()),
      reason: 'the connection closes rather than reading the rest',
    );
    expect(api.calls, isEmpty, reason: 'the host was never asked');

    const chunkBytes = 16 * 1024;
    final read = <int>[];
    Stream<List<int>> chunks() async* {
      for (var i = 0; ; i++) {
        read.add(i);
        yield List<int>.filled(chunkBytes, 0x78);
      }
    }

    await expectLater(readRequestBody(chunks()), throwsA(isA<AutomationError>()));
    // 64 KB is four 16 KB chunks; the fifth is the one that crosses the cap.
    expect(read, hasLength(5), reason: 'the chunk that would pass the cap is the last one read');
    expect(read.length * chunkBytes, lessThanOrEqualTo(maxAutomationBodyBytes + chunkBytes));
  });

  test('a port already in use is kept as an error and logged once', () async {
    final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(taken.close);
    final logged = <String>[];
    final api = _FakeApi();
    final server = AutomationServer(
      settings: AutomationSettings(enabled: true, port: taken.port),
      api: api,
      log: logged.add,
    );
    addTearDown(server.stop);
    await server.start();

    expect(server.isListening, isFalse, reason: 'the host keeps hosting without it');
    expect(server.startError, contains('${taken.port}'), reason: 'the reason a screen shows');
    expect(logged, hasLength(1), reason: 'one line, not one per attempt');
    expect(logged.single, startsWith('Automation could not start: '));
  });

  test('a screenshot is a PNG, or a clean refusal when the host has no frame', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    final shot = await _call(server, 'GET', '/screenshot');
    expect(shot.code, 200);
    expect(shot.type, 'image/png');
    expect(shot.bytes, api.png);

    api.png = null;
    final none = await _call(server, 'GET', '/screenshot');
    expect(none.code, 409);
    expect(none.body['error'], contains('no frame'));
  });

  test('stop closes the listener', () async {
    final api = _FakeApi();
    final server = await _started(const AutomationSettings(enabled: true, port: 0), api);
    final port = server.port!;
    await server.stop();
    expect(server.isListening, isFalse);
    expect(server.port, isNull);
    final client = HttpClient();
    addTearDown(client.close);
    await expectLater(
      client.getUrl(Uri.parse('http://127.0.0.1:$port${AutomationServer.prefix}/status')).then((r) => r.close()),
      throwsA(isA<SocketException>()),
    );
  });
}
