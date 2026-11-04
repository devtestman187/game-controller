import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/demo_live.dart';
import 'package:tvtest/src/demo/director.dart';
import 'package:tvtest/src/demo/events.dart';

/// The director's control channel (docs/demo-video-runbook.md 2.3): the
/// showrunner's side of it. Each test binds its own port, so nothing clashes
/// with a real demo run on 47900.
void main() {
  Future<(DemoDirector, WebSocket)> open() async {
    final director = DemoDirector(
      hostPort: 45780,
      code: '1234',
      live: DemoLive.instance,
      log: EventLog(take: 'test'),
      controlPort: 0,
    );
    await director.start();
    addTearDown(director.stop);
    final socket = await WebSocket.connect('ws://127.0.0.1:${director.port}/director');
    addTearDown(socket.close);
    return (director, socket);
  }

  Future<Map<String, dynamic>> ask(WebSocket socket, Map<String, Object?> message) async {
    socket.add(jsonEncode(message));
    return jsonDecode(await socket.first as String) as Map<String, dynamic>;
  }

  test('hello answers with the port, the pairing code and the screen', () async {
    final (_, socket) = await open();
    final reply = await ask(socket, {'t': 'hello'});
    expect(reply['t'], 'state');
    expect(reply['port'], 45780);
    expect(reply['code'], '1234');
    expect(reply['screen'], 'home');
  });

  test('an unknown message is answered with an error, not silence', () async {
    final (_, socket) = await open();
    final reply = await ask(socket, {'t': 'nonsense'});
    expect(reply['t'], 'error');
    expect(reply['why'], contains('nonsense'));
  });

  test('a scene with no file is refused with a reason', () async {
    final (_, socket) = await open();
    final reply = await ask(socket, {'t': 'scene'});
    expect(reply['t'], 'scene_done');
    expect(reply['ok'], isFalse);
    expect(reply['why'], isNotEmpty);
  });

  test('an app event (a join) is logged and sent to the showrunner', () async {
    final (director, socket) = await open();
    final messages = <Map<String, dynamic>>[];
    socket.listen((raw) => messages.add(jsonDecode(raw as String) as Map<String, dynamic>));
    // The server adds the socket to its list just after the client's upgrade
    // returns, so give it a moment before the first event.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    director.reportEvent('join', {'player': 'P1', 'side': 'left'});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(director.log.names, contains('join'));
    expect(messages.last['t'], 'event');
    expect(messages.last['name'], 'join');
    expect(messages.last['side'], 'left');
  });

  test('stop answers, even with nothing running', () async {
    final (_, socket) = await open();
    final reply = await ask(socket, {'t': 'stop'});
    expect(reply['t'], 'stopped');
  });
}
