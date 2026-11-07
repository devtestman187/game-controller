import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A phone a test speaks for itself, over a raw channel: the frames it writes
/// reach the host as written, and every frame the host sends back arrives here
/// as a [Message], so a test sees what the host really sent instead of what a
/// [ControllerClient] makes of it.
///
/// Frames keep their order, so once a reply is in, everything the host sent
/// before it is in [fromHost] — and what it never sent will not come.
final class WirePhone {
  WirePhone._(this._channel) {
    _channel.incoming.listen((data) {
      final message = _codec.decode(data);
      if (message == null) throw StateError('Unreadable frame from the host: $data');
      _fromHost.add(message);
      if (!_arrived.isClosed) _arrived.add(message);
    });
    addTearDown(_arrived.close);
  }

  static const _codec = MessageCodec();

  final MessageChannel _channel;
  final _arrived = StreamController<Message>.broadcast();
  final _fromHost = <Message>[];

  /// A phone that has said hello as [controllerId], listing [capabilities],
  /// and got the host's welcome: the host has its session from here on. With
  /// [code] it pairs as well, and the host must accept it.
  static Future<WirePhone> open(
    HostServer host,
    TestTransport transport, {
    required String controllerId,
    List<String> capabilities = const [],
    String? code,
  }) async {
    final phone = WirePhone._(await rawPeer(host, transport));
    await phone.ask<WelcomeMessage>(
      HelloMessage(
        controllerId: controllerId,
        name: 'Phone $controllerId',
        platform: 'test',
        appVersion: 'test',
        capabilities: capabilities,
      ),
    );
    if (code != null) {
      final result = await phone.ask<PairResultMessage>(PairRequestMessage(code: code));
      if (!result.ok) throw StateError('$controllerId was not paired: ${result.failure}');
    }
    return phone;
  }

  /// Every message the host has sent this phone so far, in order.
  List<Message> get fromHost => List.unmodifiable(_fromHost);

  /// Sends [message] and waits up to 5 s for the host's next message of type
  /// [T]. It waits before it sends, so an answer that comes at once is not
  /// missed.
  Future<T> ask<T extends Message>(Message message) {
    final answer = _arrived.stream.where((m) => m is T).cast<T>().first;
    _channel.send(_codec.encode(message));
    return answer.timeout(const Duration(seconds: 5));
  }

  /// A ping and its pong: the round trip that shows everything the host sent
  /// before it has arrived.
  Future<void> drain() async {
    await ask<PongMessage>(const PingMessage(id: 0, sentAtMs: 0));
  }
}
