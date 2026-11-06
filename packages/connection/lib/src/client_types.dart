import 'host_address.dart';
import 'rtt.dart';

enum ClientStatus {
  /// Not connected and not trying to.
  idle,

  /// Opening the first connection to a host.
  connecting,

  /// Reached the host. It needs the code shown on the TV.
  waitingForCode,

  /// Sent the code, waiting for the answer.
  pairing,

  /// Paired, with heartbeats flowing.
  connected,

  /// The connection dropped after pairing. Retrying on its own.
  reconnecting,

  /// Gave up. See [ClientSnapshot.problem].
  failed,
}

/// Why the client isn't (or wasn't) connected.
enum ClientProblem {
  /// The host couldn't be reached at all.
  unreachable,

  /// The code was wrong.
  wrongCode,

  /// Too many wrong codes in a row. The TV now shows a new code.
  tooManyAttempts,

  /// The host didn't recognize the saved pairing (for example the TV app
  /// restarted), so the code is needed again.
  pairingForgotten,

  /// The TV and the phone run different protocol versions.
  versionMismatch,

  /// This phone connected again on another connection.
  replaced,

  /// The host rejected a message.
  protocolError,

  /// The code wasn't entered in time.
  pairingTimeout,

  /// The connection dropped.
  connectionLost,
}

/// Everything the controller UI shows about the connection, as one value.
final class ClientSnapshot {
  const ClientSnapshot({
    required this.status,
    this.target,
    this.hostName,
    this.rttMs,
    this.problem,
    this.detail,
    this.attempt = 0,
    this.osErrorCode,
    this.rttStats,
    this.player,
    this.hostCapabilities = const [],
  });

  final ClientStatus status;

  /// The host being connected to.
  final HostAddress? target;

  /// The host's name from its welcome message.
  final String? hostName;

  /// Latest heartbeat round-trip time, measured on the phone.
  final int? rttMs;

  final ClientProblem? problem;

  /// Technical detail for Diagnostics, such as the OS error message.
  final String? detail;

  /// Reconnect attempt number while [ClientStatus.reconnecting].
  final int attempt;

  /// OS error code from the last failed connection attempt. On iOS, 65 (no
  /// route to host) to a local address usually means the local network
  /// permission is off.
  final int? osErrorCode;

  /// Lowest, average and highest round-trip time over the last 30 s.
  final RttSummary? rttStats;

  /// This controller's player number on the TV (M6), while connected to a
  /// TV that sends one.
  final int? player;

  /// What the host supports ([Capability]), from its welcome (M9). Empty for
  /// TV apps older than M9.
  final List<String> hostCapabilities;

  bool get isConnected => status == ClientStatus.connected;

  /// The best name for the host: its own name, the advertised one, or its
  /// address.
  String get hostLabel => hostName ?? target?.label ?? '';

  ClientSnapshot copyWith({
    ClientStatus? status,
    Object? target = _keep,
    Object? hostName = _keep,
    Object? rttMs = _keep,
    Object? problem = _keep,
    Object? detail = _keep,
    int? attempt,
    Object? osErrorCode = _keep,
    Object? rttStats = _keep,
    Object? player = _keep,
    List<String>? hostCapabilities,
  }) => ClientSnapshot(
    status: status ?? this.status,
    target: identical(target, _keep) ? this.target : target as HostAddress?,
    hostName: identical(hostName, _keep) ? this.hostName : hostName as String?,
    rttMs: identical(rttMs, _keep) ? this.rttMs : rttMs as int?,
    problem: identical(problem, _keep) ? this.problem : problem as ClientProblem?,
    detail: identical(detail, _keep) ? this.detail : detail as String?,
    attempt: attempt ?? this.attempt,
    osErrorCode: identical(osErrorCode, _keep) ? this.osErrorCode : osErrorCode as int?,
    rttStats: identical(rttStats, _keep) ? this.rttStats : rttStats as RttSummary?,
    player: identical(player, _keep) ? this.player : player as int?,
    hostCapabilities: hostCapabilities ?? this.hostCapabilities,
  );

  @override
  String toString() =>
      'ClientSnapshot(${status.name}, ${target?.display}, problem: ${problem?.name}, attempt: $attempt)';
}

const Object _keep = Object();
