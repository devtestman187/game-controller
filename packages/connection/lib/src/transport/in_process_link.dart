import 'dart:async';

import 'message_channel.dart';

/// A connected pair of channels for the host phone's own player (D1): both
/// ends run in this process, so there is no socket and no network address.
///
/// Frames go through non-sync [StreamController]s: they are delivered after
/// [MessageChannel.send] returns, in order, from the event loop. No timer and
/// no delay is involved.
final class InProcessLink {
  /// Makes a link with both ends open.
  factory InProcessLink() {
    final toHost = StreamController<String>();
    final toController = StreamController<String>();
    final closing = _Closing();
    // Each end reads the other end's stream and writes its own.
    return InProcessLink._(_InProcessEnd(closing, toHost, toController), _InProcessEnd(closing, toController, toHost));
  }

  InProcessLink._(this.host, this.controller);

  /// The end the host (server) owns.
  final MessageChannel host;

  /// The end the controller (client) owns.
  final MessageChannel controller;
}

/// What both ends of a link share: closing either closes both, with the same
/// code and reason.
final class _Closing {
  bool closed = false;
  int? code;
  String? reason;
}

/// One end of an [InProcessLink]: it reads the peer's frames from [_incoming]
/// and sends its own into [_outgoing], the peer's incoming stream. Both ends
/// share one [_Closing], so a close on either side closes both.
final class _InProcessEnd implements MessageChannel {
  _InProcessEnd(this._closing, this._incoming, this._outgoing);

  final _Closing _closing;

  /// Frames from the peer: the other end's outgoing controller.
  final StreamController<String> _incoming;

  /// What this end sends: its frames go to the other end's incoming stream.
  final StreamController<String> _outgoing;

  @override
  String? get remoteAddress => null;

  @override
  bool get isLocal => true;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  int? get closeCode => _incoming.isClosed ? _closing.code : null;

  @override
  String? get closeReason => _incoming.isClosed ? _closing.reason : null;

  @override
  void send(String text) {
    if (_closing.closed) return;
    _outgoing.add(text);
  }

  @override
  Future<void> close(int code, [String? reason]) {
    if (_closing.closed) return Future.value();
    _closing
      ..closed = true
      ..code = code
      ..reason = reason;
    // Both controllers hold one end's frames each: closing them delivers
    // what is already buffered, in order, then done, on both ends. There is
    // nothing to wait for in-process, and a controller's close future waits
    // for a listener that may never come.
    unawaited(_incoming.close());
    unawaited(_outgoing.close());
    return Future.value();
  }
}
