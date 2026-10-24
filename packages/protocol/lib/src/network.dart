/// Network constants shared by the controller and every host (TV, laptop).
library;

/// mDNS/DNS-SD service type the host advertises and the controller browses.
/// iOS also needs it in Info.plist under `NSBonjourServices`.
const String serviceType = '_gamectl._tcp';

/// TXT record key holding the host's stable ID.
const String txtHostId = 'id';

/// TXT record key holding the host's protocol version.
const String txtProtocolVersion = 'v';

/// TCP port the host listens on. If it's taken, the host picks a free port
/// and advertises that one instead.
const int defaultPort = 45780;

/// Path of the WebSocket endpoint on the host.
const String webSocketPath = '/ws';

/// WebSocket close codes (4000-4999 is the range for applications).
abstract final class CloseCodes {
  /// The host is shutting down (standard "going away"). Controllers retry.
  static const int goingAway = 1001;

  /// The peers use different protocol versions. Don't retry.
  static const int versionMismatch = 4000;

  /// A wrong pairing code was sent. Retry only with a new code.
  static const int pairingFailed = 4001;

  /// The same controller connected again on a newer connection. Don't retry.
  static const int replaced = 4002;

  /// A malformed or unexpected message. Don't retry.
  static const int protocolError = 4003;

  /// No heartbeat for too long. Retry.
  static const int heartbeatTimeout = 4004;

  /// The controller didn't pair in time. Retry only after user action.
  static const int pairingTimeout = 4005;
}
