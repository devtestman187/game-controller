/// One open, ordered, text-only connection between a host and a controller
/// (PRD v2 P1). Implementations: WebSocketChannelAdapter, and the two ends
/// of an InProcessLink.
abstract interface class MessageChannel {
  /// The peer's network address for logs and saved pairings, shown as the
  /// user would type it (displayIp). Null for an in-process peer.
  String? get remoteAddress;

  /// True when the peer runs in this process: the host phone's own player
  /// (D1). Such a channel has no network address.
  bool get isLocal;

  /// Text frames from the peer, in order. Single subscription. May carry an
  /// error (logged by the owner); closes once the channel is closed by
  /// either side. A binary frame closes the channel with
  /// CloseCodes.protocolError, "Expected text frames".
  Stream<String> get incoming;

  /// Sends one text frame. Does nothing once the channel is closing.
  void send(String text);

  /// Closes the channel with [code] (CloseCodes) and [reason]. Calling it
  /// again does nothing. Completes when the close is done; never throws.
  Future<void> close(int code, [String? reason]);

  /// After [incoming] is done: the close code and reason, whichever side
  /// closed. Null before then, or if the peer vanished without one.
  int? get closeCode;
  String? get closeReason;
}
