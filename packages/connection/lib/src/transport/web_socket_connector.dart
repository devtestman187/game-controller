import 'dart:io';

import 'package:protocol/protocol.dart';

import '../host_address.dart';
import '../log.dart';
import 'connect_error.dart';
import 'connector.dart';
import 'message_channel.dart';
import 'web_socket_channel.dart';

/// How long one connect attempt may take: 4 s, as today. A connect on a home
/// network takes well under a second; longer means the host is unreachable.
const Duration defaultConnectTimeout = Duration(seconds: 4);

const String _localTargetMessage = 'The host phone\'s own player has no network address';
const String _cancelledMessage = 'Connection cancelled';

/// A [Connector] for phones on the LAN: each of the target's addresses in
/// turn, one WebSocket connect each.
final class WebSocketConnector implements Connector {
  /// [connectTimeout] limits one attempt; [log] gets the same lines the
  /// client always wrote.
  WebSocketConnector({this.connectTimeout = defaultConnectTimeout, LogSink? log}) : _log = log ?? _noLog;

  /// How long each address gets to answer.
  final Duration connectTimeout;

  final LogSink _log;

  @override
  Future<MessageChannel> open(HostAddress target, {required bool Function() isCancelled}) async {
    if (target.isLocal) throw ConnectFailed(_localTargetMessage);
    Object? lastError;
    for (final address in target.ordered) {
      if (isCancelled()) throw ConnectFailed(_cancelledMessage);
      final uri = target.uriFor(address);
      _log('Connecting to $uri');
      final http = HttpClient()..connectionTimeout = connectTimeout;
      WebSocket? socket;
      try {
        socket = await WebSocket.connect(uri.toString(), customClient: http);
      } catch (e) {
        lastError = e;
        http.close(force: true);
        _log('Could not connect to $uri: ${describeError(e)}');
      }
      final opened = socket;
      if (opened == null) continue;
      if (isCancelled()) {
        // Cancelled while the connect ran: hand nothing back.
        opened.close(CloseCodes.goingAway).ignore();
        throw ConnectFailed(_cancelledMessage);
      }
      return WebSocketChannelAdapter(opened, remoteAddress: displayIp(address));
    }
    throw _failed(lastError);
  }

  /// The failure to report when no address opened a channel.
  ConnectFailed _failed(Object? error) => switch (error) {
    SocketException(:final osError?) => ConnectFailed(describeError(error), osErrorCode: osError.errorCode),
    null => ConnectFailed('No address to try'),
    _ => ConnectFailed(describeError(error)),
  };
}

void _noLog(String _) {}
