/// Protocol version sent in every message envelope (`"v"`).
///
/// Bump this when a change is not backward compatible. Peers with a different
/// version reject messages with [ProtocolVersionMismatch] so mismatched
/// builds fail loudly instead of misbehaving.
const int protocolVersion = 1;

/// Thrown when a peer sends a message with a different protocol version.
class ProtocolVersionMismatch implements Exception {
  const ProtocolVersionMismatch({required this.expected, required this.actual});

  final int expected;
  final int actual;

  @override
  String toString() =>
      'ProtocolVersionMismatch: expected v$expected, got v$actual. '
      'Update the older app so both use the same protocol version.';
}

/// Thrown when a frame is not a valid protocol message.
class ProtocolFormatException implements Exception {
  const ProtocolFormatException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolFormatException: $message';
}
