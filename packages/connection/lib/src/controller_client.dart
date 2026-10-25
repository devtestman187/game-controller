import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_address.dart';
import 'log.dart';
import 'rtt.dart';

/// Who this controller is. Sent to the host in the hello message.
final class ControllerIdentity {
  const ControllerIdentity({
    required this.controllerId,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  final String controllerId;
  final String name;
  final String platform;
  final String appVersion;

  HelloMessage toHello() =>
      HelloMessage(controllerId: controllerId, name: name, platform: platform, appVersion: appVersion);
}

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
  );

  @override
  String toString() =>
      'ClientSnapshot(${status.name}, ${target?.display}, problem: ${problem?.name}, attempt: $attempt)';
}

const Object _keep = Object();

/// The phone's side of the connection: connects to a host, pairs with the
/// code (or a saved token), keeps heartbeats going and reconnects on its own
/// after a drop.
class ControllerClient {
  ControllerClient({
    required this.identity,
    Map<String, String> tokens = const {},
    this.onTokenChanged,
    this.heartbeatInterval = const Duration(seconds: 1),
    this.heartbeatTimeout = const Duration(seconds: 4),
    this.connectTimeout = const Duration(seconds: 4),
    this.retryDelays = const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ],
    LogSink? log,
    DateTime Function()? wallClock,
  }) : _wallClock = wallClock ?? DateTime.now,
       _tokens = Map.of(tokens),
       _log = log ?? _noLog;

  final ControllerIdentity identity;

  /// Called when a host issues a pairing token (or forgets one, with null),
  /// so the app can save it and reconnect without a code after a restart.
  final void Function(String hostId, String? token)? onTokenChanged;

  final Duration heartbeatInterval;

  /// The connection counts as dropped after this long without any message.
  final Duration heartbeatTimeout;
  final Duration connectTimeout;

  /// Wait before each reconnect attempt. The last value repeats forever.
  final List<Duration> retryDelays;

  /// Wall-clock time, replaced in tests to act out a sleeping phone.
  final DateTime Function() _wallClock;
  final Map<String, String> _tokens;
  final LogSink _log;
  static const _codec = MessageCodec();
  final _clock = Stopwatch()..start();
  final _changes = StreamController<ClientSnapshot>.broadcast();
  final _haptics = StreamController<HapticEventMessage>.broadcast();
  int _hapticsReceived = 0;

  ClientSnapshot _snap = const ClientSnapshot(status: ClientStatus.idle);

  /// Bumped by [connect] and [disconnect], so callbacks from an older
  /// session do nothing.
  int _session = 0;

  /// Bumped for every socket, so events from a replaced socket do nothing.
  int _socketId = 0;
  WebSocket? _ws;
  bool _welcomed = false;
  bool _opening = false;
  bool _everPaired = false;
  String? _pendingCode;
  Timer? _heartbeat;
  Timer? _retry;
  int _lastHeardMs = 0;
  late DateTime _lastHeardAt = _wallClock();
  int _nextPingId = 0;
  final _rttWindow = RttWindow();
  int _inputSeq = 0;
  Set<ControllerButton> _buttons = const {};
  int _dx = 0;
  int _dy = 0;
  double? _ax;
  double? _ay;
  ({double x, double y})? _left;
  ({double x, double y})? _right;
  int _inputsSent = 0;

  ClientSnapshot get snapshot => _snap;

  Stream<ClientSnapshot> get changes => _changes.stream;

  /// Saved pairing tokens by host ID.
  Map<String, String> get tokens => Map.unmodifiable(_tokens);

  /// Input states sent since the app started, for Diagnostics.
  int get inputsSent => _inputsSent;

  /// Haptic events from the TV (M5), only while paired.
  Stream<HapticEventMessage> get hapticEvents => _haptics.stream;

  /// Haptic events received since the app started, for Diagnostics.
  int get hapticsReceived => _hapticsReceived;

  /// Sets the controller's input and sends it if connected. While not
  /// connected it's kept and sent as soon as pairing completes, so a button
  /// held through a reconnect still counts and a released one is released.
  /// [ax] and [ay] are the gyro tilt (-1 to 1), null outside gyro mode.
  /// [left] and [right] are the analog sticks, null outside stick mode.
  void sendInput(
    Set<ControllerButton> buttons, {
    int dx = 0,
    int dy = 0,
    double? ax,
    double? ay,
    ({double x, double y})? left,
    ({double x, double y})? right,
  }) {
    _buttons = Set.of(buttons);
    _dx = dx;
    _dy = dy;
    _ax = ax;
    _ay = ay;
    _left = left;
    _right = right;
    if (_snap.isConnected) _sendInputState();
  }

  void _sendInputState() {
    _inputsSent++;
    _send(
      InputStateMessage(
        seq: ++_inputSeq,
        buttons: _buttons,
        dx: _dx,
        dy: _dy,
        ax: _ax,
        ay: _ay,
        lx: _left?.x,
        ly: _left?.y,
        rx: _right?.x,
        ry: _right?.y,
        sentAtMs: _now,
      ),
    );
  }

  /// Connects to [target]. If [code] is given it's sent right away;
  /// otherwise a saved token is used, or the status becomes
  /// [ClientStatus.waitingForCode].
  void connect(HostAddress target, {String? code}) {
    _teardown();
    _rttWindow.clear();
    _session++;
    _everPaired = false;
    _pendingCode = code;
    _set(ClientSnapshot(status: ClientStatus.connecting, target: target));
    _open(_session);
  }

  /// Sends the code the user typed. Reconnects first if the host closed the
  /// connection after a wrong code.
  void submitCode(String code) {
    if (_snap.target == null) return;
    _retry?.cancel();
    if (_ws != null && _welcomed) {
      _log('Sending pairing code');
      _send(PairRequestMessage(code: code));
      _set(_snap.copyWith(status: ClientStatus.pairing, problem: null, detail: null));
    } else {
      _pendingCode = code;
      _set(_snap.copyWith(status: ClientStatus.pairing, problem: null, detail: null));
      if (_ws == null && !_opening) _open(_session);
    }
  }

  /// Uses a host's new address (found by discovery) for the next attempts,
  /// if it's the same host as the current target.
  void updateAddress(HostAddress found) {
    final target = _snap.target;
    if (target == null || !target.sameHostAs(found)) return;
    if (target.port == found.port && _sameList(target.addresses, found.addresses)) return;
    _log('${found.label} is now at ${found.display}');
    _set(_snap.copyWith(target: found.copyWith(name: found.name ?? target.name)));
    // Waiting for the next attempt at the old address helps no one.
    if (_snap.status == ClientStatus.reconnecting) retryNow();
  }

  /// Tries a pending reconnect now instead of waiting for its timer.
  void retryNow() {
    if (_snap.status != ClientStatus.reconnecting || _ws != null || _opening) return;
    _retry?.cancel();
    _retry = null;
    _open(_session);
  }

  /// Call when the app comes back to the foreground or the phone wakes up.
  ///
  /// While the app was suspended nothing was heard from the TV, and the TV
  /// has usually dropped the connection already. Instead of waiting several
  /// seconds for the heartbeat timeout, a connection that has been quiet for
  /// longer than [heartbeatTimeout] / 2 is replaced at once, and a pending
  /// reconnect is tried now. Wall-clock time is used here, because the
  /// monotonic clock may not advance while the phone sleeps.
  void resume() {
    switch (_snap.status) {
      case ClientStatus.connected:
        final quiet = _wallClock().difference(_lastHeardAt);
        if (quiet < heartbeatTimeout ~/ 2) return;
        _log('Back after ${(quiet.inMilliseconds / 1000).toStringAsFixed(1)} s without the TV, reconnecting now');
        _dropSocket(closeCode: CloseCodes.heartbeatTimeout);
        _scheduleRetry(detail: 'App resumed', delay: Duration.zero);
      case ClientStatus.reconnecting:
        _log('App resumed, trying to reconnect now');
        retryNow();
      default:
    }
  }

  /// Closes the connection and stops retrying.
  void disconnect() {
    if (_snap.status != ClientStatus.idle) _log('Disconnecting');
    _session++;
    _teardown();
    _everPaired = false;
    _set(const ClientSnapshot(status: ClientStatus.idle));
  }

  Future<void> dispose() async {
    disconnect();
    await _changes.close();
    await _haptics.close();
  }

  int get _now => _clock.elapsedMilliseconds;

  Future<void> _open(int session) async {
    final target = _snap.target;
    if (target == null) return;
    _opening = true;
    Object? lastError;
    WebSocket? ws;
    for (final address in target.ordered) {
      final uri = target.uriFor(address);
      _log('Connecting to $uri');
      final http = HttpClient()..connectionTimeout = connectTimeout;
      try {
        ws = await WebSocket.connect(uri.toString(), customClient: http);
        break;
      } catch (e) {
        lastError = e;
        http.close(force: true);
        _log('Could not connect to $uri: ${describeError(e)}');
      }
      if (session != _session) break;
    }
    if (session != _session) {
      ws?.close(CloseCodes.goingAway).ignore();
      return;
    }
    _opening = false;
    if (ws == null) return _onConnectFailed(lastError);

    final socketId = ++_socketId;
    _ws = ws;
    _welcomed = false;
    _lastHeardMs = _now;
    _lastHeardAt = _wallClock();
    _log('Connected to ${target.display}, saying hello');
    final socket = ws;
    socket.listen(
      (data) => _onData(socketId, data),
      onDone: () => _onSocketDone(socketId, socket.closeCode, socket.closeReason),
      onError: (Object e) => _log('Connection error: ${describeError(e)}'),
    );
    _send(identity.toHello());
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _beat(socketId));
  }

  void _onConnectFailed(Object? error) {
    final osError = error is SocketException ? error.osError?.errorCode : null;
    final detail = error == null ? null : describeError(error);
    if (_everPaired) {
      _scheduleRetry(detail: detail, osErrorCode: osError);
    } else {
      _set(
        _snap.copyWith(
          status: ClientStatus.failed,
          problem: ClientProblem.unreachable,
          detail: detail,
          osErrorCode: osError,
        ),
      );
    }
  }

  void _onData(int socketId, Object? data) {
    if (socketId != _socketId) return;
    _lastHeardMs = _now;
    _lastHeardAt = _wallClock();
    if (data is! String) return;

    final Message? message;
    try {
      message = _codec.decode(data);
    } on ProtocolVersionMismatch catch (e) {
      _log('The TV uses protocol v${e.actual}, this phone uses v${e.expected}');
      return _giveUp(
        ClientProblem.versionMismatch,
        'TV protocol v${e.actual}, phone v${e.expected}',
        closeCode: CloseCodes.versionMismatch,
      );
    } on ProtocolFormatException catch (e) {
      _log('Bad message from the TV: ${e.message}');
      return _giveUp(ClientProblem.protocolError, e.message, closeCode: CloseCodes.protocolError);
    }
    if (message == null) return;

    switch (message) {
      case PingMessage():
        _send(PongMessage.answering(message, atMs: _now));
      case PongMessage():
        final rtt = _now - message.sentAtMs;
        if (rtt >= 0 && _snap.isConnected) {
          _rttWindow.add(_now, rtt);
          _set(_snap.copyWith(rttMs: rtt, rttStats: _rttWindow.summary(_now)));
        }
      case WelcomeMessage():
        _onWelcome(message);
      case PairResultMessage():
        _onPairResult(message);
      case HapticEventMessage():
        // Only while paired: a TV we are not paired with has no business here.
        if (!_snap.isConnected) return;
        _hapticsReceived++;
        if (!_haptics.isClosed) _haptics.add(message);
      case PlayerMessage():
        if (_snap.isConnected && _snap.player != message.number) {
          _log("The TV made this phone player ${message.number}");
          _set(_snap.copyWith(player: message.number));
        }
      case HelloMessage() || PairRequestMessage() || InputStateMessage():
        _log('Ignoring unexpected ${message.type} from the TV');
    }
  }

  void _onWelcome(WelcomeMessage welcome) {
    _welcomed = true;
    // Trust the host's own ID over the advertised one: tokens are saved by it.
    final target = _snap.target!.copyWith(hostId: welcome.hostId);
    _set(_snap.copyWith(target: target, hostName: welcome.hostName));
    _log('Welcome from ${welcome.hostName} (TV app ${welcome.appVersion})');

    final code = _pendingCode;
    _pendingCode = null;
    final token = _tokens[welcome.hostId];
    if (code != null) {
      _log('Sending pairing code');
      _send(PairRequestMessage(code: code));
      _set(_snap.copyWith(status: ClientStatus.pairing));
    } else if (token != null) {
      _log('Using the saved pairing');
      _send(PairRequestMessage(token: token));
    } else {
      _set(_snap.copyWith(status: ClientStatus.waitingForCode));
    }
  }

  void _onPairResult(PairResultMessage result) {
    final hostId = _snap.target!.hostId!;
    if (result.ok) {
      final token = result.token!;
      if (_tokens[hostId] != token) {
        _tokens[hostId] = token;
        onTokenChanged?.call(hostId, token);
      }
      _everPaired = true;
      _log('Paired with ${_snap.hostLabel}');
      _set(_snap.copyWith(status: ClientStatus.connected, problem: null, detail: null, attempt: 0, osErrorCode: null));
      // The TV starts each connection with nothing pressed. Tell it what is
      // held right now (also after a reconnect).
      _sendInputState();
      return;
    }
    switch (result.failure!) {
      case PairFailure.unknownToken:
        _log('The TV no longer knows this phone, the code is needed again');
        if (_tokens.remove(hostId) != null) onTokenChanged?.call(hostId, null);
        _everPaired = false;
        _set(_snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.pairingForgotten));
      case PairFailure.wrongCode:
        _log('Wrong pairing code');
        _dropSocket(); // The host closes it anyway. A new code reconnects.
        _set(_snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.wrongCode));
      case PairFailure.tooManyAttempts:
        _log('Too many wrong codes, the TV shows a new one');
        _dropSocket();
        _set(_snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.tooManyAttempts));
    }
  }

  void _onSocketDone(int socketId, int? code, String? reason) {
    if (socketId != _socketId) return;
    _dropSocket();
    final why = reason == null || reason.isEmpty ? '' : ': $reason';
    _log('Connection closed${code == null ? '' : ' (code $code$why)'}');
    switch (code) {
      case CloseCodes.versionMismatch:
        _giveUp(ClientProblem.versionMismatch, reason);
      case CloseCodes.replaced:
        _giveUp(ClientProblem.replaced, reason);
      case CloseCodes.protocolError:
        _giveUp(ClientProblem.protocolError, reason);
      case CloseCodes.pairingTimeout:
        _giveUp(ClientProblem.pairingTimeout, reason);
      case CloseCodes.pairingFailed:
        // The pair result already set the status. A new code reconnects.
        if (_snap.status != ClientStatus.waitingForCode) {
          _set(_snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.wrongCode));
        }
      default:
        if (_snap.status == ClientStatus.waitingForCode) return; // A new code reconnects.
        if (_everPaired) {
          _scheduleRetry(detail: reason);
        } else {
          _giveUp(ClientProblem.connectionLost, reason);
        }
    }
  }

  void _beat(int socketId) {
    if (socketId != _socketId) return;
    final quietMs = _now - _lastHeardMs;
    if (quietMs > heartbeatTimeout.inMilliseconds) {
      _log('No heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, the connection is gone');
      _dropSocket(closeCode: CloseCodes.heartbeatTimeout);
      if (_everPaired) {
        _scheduleRetry(detail: 'No heartbeat');
      } else if (_snap.status != ClientStatus.waitingForCode) {
        _giveUp(ClientProblem.connectionLost, 'No heartbeat');
      }
      return;
    }
    _send(PingMessage(id: _nextPingId++, sentAtMs: _now));
  }

  void _scheduleRetry({String? detail, int? osErrorCode, Duration? delay}) {
    final attempt = _snap.attempt + 1;
    delay ??= retryDelays[min(attempt - 1, retryDelays.length - 1)];
    _set(
      _snap.copyWith(
        status: ClientStatus.reconnecting,
        problem: ClientProblem.connectionLost,
        detail: detail,
        attempt: attempt,
        rttMs: null,
        rttStats: null,
        player: null,
        osErrorCode: osErrorCode,
      ),
    );
    _log('Reconnecting in ${delay.inMilliseconds} ms (attempt $attempt)');
    final session = _session;
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (session == _session && _ws == null && !_opening) _open(session);
    });
  }

  void _giveUp(ClientProblem problem, String? detail, {int? closeCode}) {
    _retry?.cancel();
    _dropSocket(closeCode: closeCode);
    _everPaired = false;
    _set(
      _snap.copyWith(
        status: ClientStatus.failed,
        problem: problem,
        detail: detail,
        rttMs: null,
        rttStats: null,
        player: null,
      ),
    );
  }

  void _dropSocket({int? closeCode}) {
    _heartbeat?.cancel();
    _heartbeat = null;
    final ws = _ws;
    _ws = null;
    _welcomed = false;
    _socketId++;
    // close() can wait a long time on a dead network, so don't await it.
    ws?.close(closeCode ?? 1000).then((_) {}, onError: (_) {});
  }

  void _teardown() {
    _retry?.cancel();
    _retry = null;
    _pendingCode = null;
    _dropSocket();
  }

  void _send(Message message) {
    final ws = _ws;
    if (ws == null) return;
    try {
      ws.add(_codec.encode(message));
    } catch (e) {
      _log('Send failed: $e');
    }
  }

  void _set(ClientSnapshot next) {
    _snap = next;
    if (!_changes.isClosed) _changes.add(next);
  }
}

void _noLog(String _) {}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

/// A short, readable description of a connection error.
String describeError(Object error) => switch (error) {
  SocketException(osError: final os?) => '${os.message.trim()} (OS error ${os.errorCode})',
  SocketException(:final message) => message,
  WebSocketException(:final message) => message,
  HttpException(:final message) => message,
  TimeoutException() => 'Timed out',
  _ => '$error',
};
