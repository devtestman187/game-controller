import 'dart:io';

import 'package:connection/connection.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A host a test scripts by hand, where a real one would be: a phone reaches
/// it the way [transport] does, and [onChannel] gets the host's end of every
/// channel the phone opens, so the test answers in whatever order it likes,
/// or stays silent.
///
/// It is a [Connector], so the client of the test connects through it and
/// every retry opens a channel of its own. It is closed with the test.
final class FakeHost implements Connector {
  FakeHost._(this.address, this._connector);

  /// A fake host that phones reach the way [transport] does.
  static Future<FakeHost> start(TestTransport transport) async {
    switch (transport) {
      case TestTransport.webSocket:
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final host = FakeHost._(HostAddress(addresses: ['127.0.0.1'], port: server.port), WebSocketConnector());
        server.listen((request) async {
          host._accept(
            WebSocketChannelAdapter(await WebSocketTransformer.upgrade(request), remoteAddress: '127.0.0.1'),
          );
        });
        addTearDown(() => server.close(force: true));
        return host;
      case TestTransport.inProcess:
        final listener = InProcessListener();
        final host = FakeHost._(HostAddress.local(hostId: 'fake-host', name: 'Fake TV'), InProcessConnector(listener));
        await listener.start(host._accept);
        addTearDown(listener.stop);
        return host;
    }
  }

  /// The address a phone uses to reach this host.
  final HostAddress address;

  /// How the phone's end of a channel is opened.
  final Connector _connector;

  /// The host's end of every channel the phone opened, oldest first.
  final channels = <MessageChannel>[];

  /// Called with the host's end of every channel, as soon as it opens.
  void Function(MessageChannel channel)? onChannel;

  @override
  Future<MessageChannel> open(HostAddress target, {required bool Function() isCancelled}) =>
      _connector.open(address, isCancelled: isCancelled);

  void _accept(MessageChannel channel) {
    channels.add(channel);
    onChannel?.call(channel);
  }
}
