import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

/// The two ways to make a channel: a WebSocket on localhost, or a link inside
/// this process (D1).
enum _Transport { webSocket, inProcess }

/// The target the in-process connector takes: the host phone's own player.
final _localTarget = HostAddress.local(hostId: 'host-1', name: 'Test TV');

void main() {
  group('a connected pair', () {
    for (final transport in _Transport.values) {
      group(transport.name, () {
        test('keeps the order of frames, also those sent before the peer listens', () async {
          final pair = await _Pair.open(transport);
          for (final text in ['one', 'two', 'three']) {
            pair.controller.send(text);
          }
          expect(await pair.host.incoming.take(3).toList(), ['one', 'two', 'three']);
        });

        test('never delivers a frame inside send', () async {
          final pair = await _Pair.open(transport);
          final first = Completer<String>();
          pair.host.incoming.listen(first.complete);
          pair.controller.send('hello');
          expect(first.isCompleted, isFalse);
          expect(await first.future, 'hello');
        });

        test('shows the close code and reason on both ends', () async {
          final pair = await _Pair.open(transport);
          expect(pair.host.closeCode, isNull);
          expect(pair.controller.closeCode, isNull);

          await pair.controller.close(CloseCodes.replaced, 'Replaced by a newer connection');
          await pair.host.incoming.drain<void>();
          await pair.controller.incoming.drain<void>();

          for (final end in [pair.host, pair.controller]) {
            expect(end.closeCode, CloseCodes.replaced);
            expect(end.closeReason, 'Replaced by a newer connection');
          }
        });

        test('ends incoming once, when either side closes', () async {
          final pair = await _Pair.open(transport);
          var doneEvents = 0;
          final done = Completer<void>();
          pair.host.incoming.listen(
            (_) {},
            onDone: () {
              doneEvents++;
              done.complete();
            },
          );

          await pair.controller.close(CloseCodes.goingAway, 'Bye');
          await done.future;
          expect(doneEvents, 1);
        });

        test('does nothing when send is called after close', () async {
          final pair = await _Pair.open(transport);
          await pair.host.close(CloseCodes.goingAway, 'Bye');
          pair.host.send('too late');
          expect(await pair.controller.incoming.toList(), isEmpty);
        });

        test('keeps the first code when close is called twice', () async {
          final pair = await _Pair.open(transport);
          final closing = pair.controller.close(CloseCodes.goingAway, 'Bye');
          final again = pair.controller.close(CloseCodes.protocolError, 'Second');
          await Future.wait([closing, again]);

          await pair.host.incoming.drain<void>();
          expect(pair.host.closeCode, CloseCodes.goingAway);
          expect(pair.host.closeReason, 'Bye');
        });

        test('says whether the peer is local, and its address', () async {
          final pair = await _Pair.open(transport);
          final local = transport == _Transport.inProcess;
          for (final end in [pair.host, pair.controller]) {
            expect(end.isLocal, local);
            expect(end.remoteAddress, local ? isNull : '127.0.0.1');
          }
        });

        test('stays open when the listener stops', () async {
          final pair = await _Pair.open(transport);
          await pair.listener.stop();
          pair.controller.send('still here');
          expect(await pair.host.incoming.take(1).toList(), ['still here']);
        });
      });
    }
  });

  group('a web socket channel', () {
    test('closes with protocolError when the peer sends a binary frame', () async {
      final listener = WebSocketListener(preferredPort: 0, hostName: 'Test TV');
      addTearDown(listener.stop);
      final accepted = Completer<MessageChannel>();
      await listener.start(accepted.complete);
      final socket = await WebSocket.connect('ws://127.0.0.1:${_portOf(listener)}$webSocketPath');
      addTearDown(socket.close);

      final channel = await accepted.future;
      final frames = channel.incoming.toList();
      // Read the channel's side of the close, so the handshake can finish.
      socket.listen((_) {});
      socket.add(const [1, 2, 3]);
      expect(await frames, isEmpty);
      expect(channel.closeCode, CloseCodes.protocolError);
      expect(channel.closeReason, 'Expected text frames');
    });
  });

  group('a web socket listener', () {
    test('answers a plain GET with the status page', () async {
      final listener = WebSocketListener(preferredPort: 0, hostName: 'Test TV');
      addTearDown(listener.stop);
      await listener.start((_) {});

      final http = HttpClient();
      addTearDown(http.close);
      final response = await (await http.get('127.0.0.1', _portOf(listener), '/')).close();
      expect(response.statusCode, 200);
      final page = await response.transform(utf8.decoder).join();
      expect(page, 'Test TV is running the controller host (protocol v$protocolVersion).\n');
    });
  });

  group('the connectors', () {
    test('the web socket connector rejects a local target', () async {
      await expectLater(
        WebSocketConnector().open(_localTarget, isCancelled: () => false),
        throwsA(isA<ConnectFailed>()),
      );
    });

    test('the web socket connector opens nothing when cancelled first', () async {
      final channels = <MessageChannel>[];
      final listener = WebSocketListener(preferredPort: 0, hostName: 'Test TV');
      addTearDown(listener.stop);
      await listener.start(channels.add);
      final target = HostAddress(addresses: ['127.0.0.1'], port: _portOf(listener));

      await expectLater(WebSocketConnector().open(target, isCancelled: () => true), throwsA(isA<ConnectFailed>()));
      expect(channels, isEmpty);
    });

    test('the in-process connector rejects a network target', () async {
      final listener = InProcessListener();
      await listener.start((_) {});
      final target = HostAddress(addresses: ['127.0.0.1'], port: defaultPort);
      await expectLater(
        InProcessConnector(listener).open(target, isCancelled: () => false),
        throwsA(isA<ConnectFailed>()),
      );
    });

    test('the in-process connector opens nothing when cancelled first', () async {
      final channels = <MessageChannel>[];
      final listener = InProcessListener();
      await listener.start(channels.add);
      await expectLater(
        InProcessConnector(listener).open(_localTarget, isCancelled: () => true),
        throwsA(isA<ConnectFailed>()),
      );
      expect(channels, isEmpty);
    });
  });

  group('an in-process listener', () {
    test('connect throws ConnectFailed before start', () {
      expect(InProcessListener().connect, throwsA(isA<ConnectFailed>()));
    });

    test('connect throws ConnectFailed after stop', () async {
      final listener = InProcessListener();
      await listener.start((_) {});
      await listener.stop();
      expect(listener.connect, throwsA(isA<ConnectFailed>()));
    });

    test('has no port', () async {
      final listener = InProcessListener();
      await listener.start((_) {});
      expect(listener.port, isNull);
    });
  });
}

/// A connected host/controller channel pair, made the way [transport] does.
final class _Pair {
  _Pair._(this.listener, this.host, this.controller);

  /// The listener the host end was handed over by.
  final ChannelListener listener;

  final MessageChannel host;
  final MessageChannel controller;

  static Future<_Pair> open(_Transport transport) async {
    switch (transport) {
      case _Transport.webSocket:
        final listener = WebSocketListener(preferredPort: 0, hostName: 'Test TV');
        addTearDown(listener.stop);
        final accepted = Completer<MessageChannel>();
        await listener.start(accepted.complete);
        final target = HostAddress(addresses: ['127.0.0.1'], port: _portOf(listener));
        final controller = await WebSocketConnector().open(target, isCancelled: () => false);
        addTearDown(() => controller.close(CloseCodes.goingAway));
        final host = await accepted.future;
        addTearDown(() => host.close(CloseCodes.goingAway));
        return _Pair._(listener, host, controller);
      case _Transport.inProcess:
        final listener = InProcessListener();
        MessageChannel? host;
        await listener.start((channel) => host = channel);
        final controller = await InProcessConnector(listener).open(_localTarget, isCancelled: () => false);
        final hostEnd = host;
        if (hostEnd == null) throw StateError('InProcessConnector handed over no channel');
        addTearDown(() => controller.close(CloseCodes.goingAway));
        addTearDown(() => hostEnd.close(CloseCodes.goingAway));
        return _Pair._(listener, hostEnd, controller);
    }
  }
}

/// The port a started [listener] listens on.
int _portOf(WebSocketListener listener) {
  final port = listener.port;
  if (port == null) throw StateError('The listener has no port after start');
  return port;
}
