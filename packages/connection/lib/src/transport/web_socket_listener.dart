import 'dart:io';

import 'package:protocol/protocol.dart';

import '../host_address.dart';
import '../log.dart';
import 'channel_listener.dart';
import 'connect_error.dart';
import 'message_channel.dart';
import 'web_socket_channel.dart';

/// A [ChannelListener] for phones on the LAN: the WebSocket endpoint, and a
/// plain page so a browser can check the firewall.
final class WebSocketListener implements ChannelListener {
  /// [preferredPort] is tried first, then any free port (0 asks for one).
  /// [hostName] goes on the status page.
  WebSocketListener({this.preferredPort = defaultPort, required this.hostName, LogSink? log}) : _log = log ?? noLog;

  /// Port to try first. If it's taken, any free port is used.
  final int preferredPort;

  /// The host's name, as the status page shows it.
  final String hostName;

  final LogSink _log;
  HttpServer? _http;

  @override
  int? get port => _http?.port;

  @override
  Future<void> start(void Function(MessageChannel channel) onChannel) async {
    if (_http != null) return;
    final http = await _bind();
    _http = http;
    http.listen((request) => _onRequest(request, onChannel), onError: (Object e) => _log('Server error: $e'));
  }

  @override
  Future<void> stop() async {
    final http = _http;
    _http = null;
    await http?.close(force: true);
  }

  Future<HttpServer> _bind() async {
    // Dual-stack first, so phones that resolve the host to IPv6 still connect.
    final attempts = <(InternetAddress, int)>[
      (InternetAddress.anyIPv6, preferredPort),
      (InternetAddress.anyIPv4, preferredPort),
      if (preferredPort != 0) ...[(InternetAddress.anyIPv6, 0), (InternetAddress.anyIPv4, 0)],
    ];
    Object? lastError;
    for (final (address, port) in attempts) {
      try {
        return await HttpServer.bind(address, port, v6Only: false);
      } on SocketException catch (e) {
        lastError = e;
        _log('Could not listen on ${address.address} port $port: ${e.osError?.message ?? e.message}');
      }
    }
    // Every address failed; the last error is the one the user sees. The
    // message is only the cause: callers say what failed ("The server could
    // not start: …").
    throw ListenFailed(lastError == null ? 'No address to listen on' : describeError(lastError));
  }

  Future<void> _onRequest(HttpRequest request, void Function(MessageChannel channel) onChannel) async {
    if (request.uri.path == webSocketPath && WebSocketTransformer.isUpgradeRequest(request)) {
      final remote = displayIp(request.connectionInfo?.remoteAddress.address ?? '?');
      try {
        onChannel(WebSocketChannelAdapter(await WebSocketTransformer.upgrade(request), remoteAddress: remote));
      } catch (e) {
        _log('WebSocket upgrade from $remote failed: $e');
      }
      return;
    }
    // A plain page, so opening http://<address>:<port> in the phone's browser
    // shows whether the firewall lets connections through.
    request.response
      ..headers.contentType = ContentType.text
      ..write('$hostName is running the controller host (protocol v$protocolVersion).\n');
    await request.response.close();
  }
}
