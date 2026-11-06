import 'dart:async';
import 'dart:io';

import 'package:protocol/protocol.dart';

import 'message_channel.dart';

/// A [MessageChannel] over a `dart:io` WebSocket: one end of a LAN
/// connection.
final class WebSocketChannelAdapter implements MessageChannel {
  /// Wraps [socket] and the peer's address, [remoteAddress] (a WebSocket
  /// doesn't carry it). Subscribes at once, so frames that arrive before the
  /// owner listens to [incoming] are kept, in order.
  WebSocketChannelAdapter(WebSocket socket, {required this.remoteAddress}) : _socket = socket {
    _socket.listen(_onData, onDone: _onDone, onError: _onError);
  }

  final WebSocket _socket;

  /// The socket's frames, handed on as they arrive. Not a sync controller:
  /// a frame is never delivered inside [send].
  final _incoming = StreamController<String>();

  /// The close in flight, so a second [close] waits for the first one.
  Future<void>? _closing;

  @override
  final String remoteAddress;

  @override
  bool get isLocal => false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String text) {
    if (_closing != null || _incoming.isClosed) return;
    _socket.add(text);
  }

  @override
  Future<void> close(int code, [String? reason]) {
    final pending = _closing;
    if (pending != null) return pending;
    if (_incoming.isClosed) return Future.value();
    // The contract says close never throws: a close that fails has already
    // lost the peer, and the stream's onError reports it.
    final closing = _socket.close(code, reason).then((_) {}, onError: (Object _) {});
    _closing = closing;
    return closing;
  }

  @override
  int? get closeCode => _incoming.isClosed ? _socket.closeCode : null;

  @override
  String? get closeReason => _incoming.isClosed ? _socket.closeReason : null;

  void _onData(Object? data) {
    if (data is String) {
      _incoming.add(data);
      return;
    }
    // A binary frame can't be a message: end the connection, as the host
    // always has (R5 in the plan).
    unawaited(close(CloseCodes.protocolError, 'Expected text frames'));
  }

  void _onError(Object error, StackTrace stack) {
    if (!_incoming.isClosed) _incoming.addError(error, stack);
  }

  void _onDone() {
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}
