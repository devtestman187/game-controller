import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// The WebSocket listener phones reach the host on, which remembers the port
/// it got (m12 §2.10).
///
/// A host that comes back from the background listens on the same port
/// again, so a phone whose connection dropped finds it where it left it; a
/// taken port falls back to any free one, as `WebSocketListener` does on its
/// own. Each start makes a new listener, since a stopped one can't be
/// pointed at another port.
class LanListener implements ChannelListener {
  /// [hostName] goes on the listener's status page, and [log] gets its
  /// bind failures, as before (PRD T6).
  LanListener({required this.hostName, this.log});

  /// The host's name, as the status page shows it.
  final String hostName;

  /// Where each listener's lines go; null logs nothing.
  final LogSink? log;

  WebSocketListener? _inner;
  int? _lastPort;

  @override
  int? get port => _inner?.port;

  @override
  Future<void> start(void Function(MessageChannel channel) onChannel) async {
    final inner = WebSocketListener(preferredPort: _lastPort ?? defaultPort, hostName: hostName, log: log);
    _inner = inner;
    try {
      await inner.start(onChannel);
    } on Object {
      _inner = null;
      rethrow;
    }
    _lastPort = inner.port;
  }

  @override
  Future<void> stop() async {
    final inner = _inner;
    _inner = null;
    await inner?.stop();
  }
}
