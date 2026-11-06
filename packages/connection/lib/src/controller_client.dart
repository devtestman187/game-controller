import 'dart:async';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'client_connection.dart';
import 'client_controls.dart';
import 'client_host.dart';
import 'client_input.dart';
import 'client_metrics.dart';
import 'client_messages.dart';
import 'client_types.dart';
import 'controller_identity.dart';
import 'host_address.dart';
import 'log.dart';
import 'rtt.dart';
import 'transport/connector.dart';

/// The phone's side of the connection: connects to a host, pairs with the
/// code (or a saved token), keeps heartbeats going and reconnects on its own
/// after a drop.
class ControllerClient {
  ControllerClient({
    required this.identity,
    required this._connector,
    Map<String, String> tokens = const {},
    this.onTokenChanged,
    this.heartbeatInterval = const Duration(seconds: 1),
    this.heartbeatTimeout = const Duration(seconds: 4),
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

  /// Who this phone is. Can change (the device details load a moment after
  /// launch); the next hello uses the new one.
  ControllerIdentity identity;

  /// Called when a host issues a pairing token (or forgets one, with null),
  /// so the app can save it and reconnect without a code after a restart.
  final void Function(String hostId, String? token)? onTokenChanged;

  final Duration heartbeatInterval;

  /// The connection counts as dropped after this long without any message.
  final Duration heartbeatTimeout;

  /// Wait before each reconnect attempt. The last value repeats forever.
  final List<Duration> retryDelays;

  /// At most this many metrics segments wait for an ack. The oldest go first.
  static const maxOutbox = MetricsOutbox.maxOutbox;

  /// How a channel to the host is opened: a WebSocket on the LAN, or the
  /// link to the host phone's own player (D1).
  final Connector _connector;

  /// Wall-clock time, replaced in tests to act out a sleeping phone.
  final DateTime Function() _wallClock;
  final Map<String, String> _tokens;
  final LogSink _log;
  final _clock = Stopwatch()..start();
  final _changes = StreamController<ClientSnapshot>.broadcast();
  final _controls = ClientControls();
  final _input = ClientInput();
  final _metrics = MetricsOutbox();
  final _rtt = RttWindow();

  ClientSnapshot _snap = const ClientSnapshot(status: ClientStatus.idle);

  /// The channel's and the handlers' view of this client, made on first use.
  ClientHost? _clientHost;

  /// The channel to the host; it outlives reconnects, so its counters do too.
  ClientConnection? _channel;
  bool _everPaired = false;
  bool _welcomed = false;
  String? _pendingCode;
  Timer? _retry;

  ClientHost get _host => _clientHost ??= _ClientHost(this);

  ClientConnection get _connection => _channel ??= ClientConnection(
    _host,
    heartbeatInterval: heartbeatInterval,
    heartbeatTimeout: heartbeatTimeout,
    connector: _connector,
    wallClock: _wallClock,
  );

  ClientSnapshot get snapshot => _snap;

  Stream<ClientSnapshot> get changes => _changes.stream;

  /// Saved pairing tokens by host ID.
  Map<String, String> get tokens => Map.unmodifiable(_tokens);

  /// Input states sent since the app started, for Diagnostics.
  int get inputsSent => _input.statesSent;

  /// Haptic events from the TV (M5), only while paired.
  Stream<HapticEventMessage> get hapticEvents => _controls.hapticEvents;

  /// Haptic events received since the app started, for Diagnostics.
  int get hapticsReceived => _controls.hapticsReceived;

  /// The game's controls for this phone (M10): labels, hidden buttons and
  /// allowed modes. Back to standard when the connection ends.
  GameLayoutMessage get layout => _controls.layout;

  Stream<GameLayoutMessage> get layouts => _controls.layouts;

  /// The game's status panel for this phone (M10), hidden when there is none.
  StatusMessage get status => _controls.status;

  Stream<StatusMessage> get statuses => _controls.statuses;

  /// Rating prompts from the TV (M9), only while paired.
  Stream<RatingAskMessage> get ratingAsks => _controls.ratingAsks;

  /// Metrics segments waiting for the TV to acknowledge them.
  int get metricsWaiting => _metrics.waiting;

  /// Whether the connected host takes metrics batches.
  bool get hostTakesMetrics => _snap.isConnected && _snap.hostCapabilities.contains(Capability.metrics);

  /// Queues a metrics batch (M9) and sends it if the host takes metrics.
  /// Only the newest batch of each segment is kept; unacknowledged ones go
  /// again after every reconnect, so nothing is lost while Wi-Fi is off.
  void sendMetrics(MetricsMessage batch) {
    switch (_metrics.add(batch)) {
      case OutboxResult.ignored:
        return;
      case OutboxResult.droppedOldest:
        _log('Metrics: dropped the oldest unsent segment (more than $maxOutbox waiting)');
      case OutboxResult.kept:
    }
    if (hostTakesMetrics) _send(batch);
  }

  /// Answers a rating prompt (M9). Sent only if connected.
  void sendRating(RatingMessage rating) {
    if (_snap.isConnected && _snap.hostCapabilities.contains(Capability.rating)) _send(rating);
  }

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
    _input.remember(buttons, dx: dx, dy: dy, ax: ax, ay: ay, left: left, right: right);
    if (_snap.isConnected) _send(_input.nextState(_now));
  }

  /// Connects to [target]. If [code] is given it's sent right away;
  /// otherwise a saved token is used, or the status becomes
  /// [ClientStatus.waitingForCode].
  void connect(HostAddress target, {String? code}) {
    _teardown();
    _rtt.clear();
    final session = _connection.startSession();
    _everPaired = false;
    _pendingCode = code;
    _set(ClientSnapshot(status: ClientStatus.connecting, target: target));
    _open(session);
  }

  /// Sends the code the user typed. Reconnects first if the host closed the
  /// connection after a wrong code.
  void submitCode(String code) {
    if (_snap.target == null) return;
    final channel = _connection;
    _retry?.cancel();
    if (channel.hasChannel && _welcomed) {
      _log('Sending pairing code');
      _send(PairRequestMessage(code: code));
      _set(_snap.copyWith(status: ClientStatus.pairing, problem: null, detail: null));
    } else {
      _pendingCode = code;
      _set(_snap.copyWith(status: ClientStatus.pairing, problem: null, detail: null));
      if (!channel.hasChannel && !channel.isOpening) _open(channel.session);
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
    final channel = _connection;
    if (_snap.status != ClientStatus.reconnecting || channel.hasChannel || channel.isOpening) return;
    _retry?.cancel();
    _retry = null;
    _open(channel.session);
  }

  /// Call when the app comes back to the foreground or the phone wakes up.
  ///
  /// The TV has usually dropped a connection that was quiet while the app
  /// slept, so one quiet for longer than [heartbeatTimeout] / 2 is replaced
  /// at once, and a pending reconnect is tried now. Wall-clock time is used
  /// here: the monotonic clock may not advance while the phone sleeps.
  void resume() {
    switch (_snap.status) {
      case ClientStatus.connected:
        if (!_connection.replaceQuietChannel(_wallClock())) return;
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
    _channel?.startSession();
    _teardown();
    _everPaired = false;
    _set(const ClientSnapshot(status: ClientStatus.idle));
  }

  Future<void> dispose() async {
    disconnect();
    await _changes.close();
    await _controls.close();
  }

  int get _now => _clock.elapsedMilliseconds;

  /// Starts an attempt to reach the host again for [session].
  void _open(int session) {
    _connection.open(session, ClientMessages(_host, rtt: _rtt, controls: _controls, input: _input, metrics: _metrics));
  }

  /// Saves [token] for [hostId], or forgets it with null, and tells the app
  /// when that changed anything.
  void _saveToken(String hostId, String? token) {
    if (token == null) {
      if (_tokens.remove(hostId) != null) onTokenChanged?.call(hostId, null);
      return;
    }
    if (_tokens[hostId] == token) return;
    _tokens[hostId] = token;
    onTokenChanged?.call(hostId, token);
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
    final session = _connection.session;
    _retry?.cancel();
    _retry = Timer(delay, () {
      final channel = _connection;
      if (session == channel.session && !channel.hasChannel && !channel.isOpening) _open(session);
    });
  }

  void _giveUp(ClientProblem problem, String? detail, {int? closeCode}) {
    _retry?.cancel();
    _channel?.dropChannel(closeCode: closeCode);
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

  void _teardown() {
    _retry?.cancel();
    _retry = null;
    _pendingCode = null;
    _channel?.dropChannel();
  }

  void _send(Message message) => _channel?.send(message);

  void _set(ClientSnapshot next) {
    final wasConnected = _snap.isConnected;
    _snap = next;
    if (wasConnected && !next.isConnected) _controls.reset();
    if (!_changes.isClosed) _changes.add(next);
  }
}

void _noLog(String _) {}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

/// What the channel and the message handlers can do with a [ControllerClient]
/// (internal), so the client's own members stay private.
final class _ClientHost implements ClientHost {
  _ClientHost(this._client);

  final ControllerClient _client;

  @override
  void log(String message) => _client._log(message);

  @override
  int get nowMs => _client._now;

  @override
  ClientSnapshot get snapshot => _client._snap;

  @override
  void setSnapshot(ClientSnapshot next) => _client._set(next);

  @override
  String? takePendingCode() {
    final code = _client._pendingCode;
    _client._pendingCode = null;
    return code;
  }

  @override
  bool get everPaired => _client._everPaired;

  @override
  set everPaired(bool value) => _client._everPaired = value;

  @override
  bool get welcomed => _client._welcomed;

  @override
  set welcomed(bool value) => _client._welcomed = value;

  @override
  String? tokenFor(String hostId) => _client._tokens[hostId];

  @override
  void saveToken(String hostId, String? token) => _client._saveToken(hostId, token);

  @override
  ControllerIdentity get identity => _client.identity;

  @override
  bool get hostTakesMetrics => _client.hostTakesMetrics;

  @override
  void send(Message message) => _client._send(message);

  @override
  void dropChannel({int? closeCode}) => _client._channel?.dropChannel(closeCode: closeCode);

  @override
  void scheduleRetry({String? detail, int? osErrorCode, Duration? delay}) =>
      _client._scheduleRetry(detail: detail, osErrorCode: osErrorCode, delay: delay);

  @override
  void giveUp(ClientProblem problem, String? detail, {int? closeCode}) =>
      _client._giveUp(problem, detail, closeCode: closeCode);
}
