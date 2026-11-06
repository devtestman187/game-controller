import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_address.dart';
import 'host_connection.dart';
import 'host_pairings.dart';
import 'host_types.dart';
import 'log.dart';
import 'saved_pairing.dart';

/// The WebSocket server that runs on the TV (and on the laptop).
///
/// It shows a pairing code, accepts controllers that send that code (or a
/// token from an earlier pairing), sends heartbeats, measures the round-trip
/// time and drops connections that go quiet.
class HostServer {
  HostServer({
    required this.hostId,
    required this.hostName,
    required this.appVersion,
    this.preferredPort = defaultPort,
    this.heartbeatInterval = const Duration(seconds: 1),
    this.heartbeatTimeout = const Duration(seconds: 4),
    this.pairingWindow = const Duration(minutes: 5),
    this.maxWrongCodes = 5,
    this.latencyLogInterval = const Duration(seconds: 30),
    Iterable<SavedPairing> pairings = const [],
    this.onPairingsChanged,
    this.maxSavedPairings = 8,
    this.capabilities = const [],
    LogSink? log,
    Random? random,
  }) : _log = log ?? _noLog,
       _pairings = PairingBook(
         random: random ?? Random.secure(),
         maxSavedPairings: maxSavedPairings,
         maxWrongCodes: maxWrongCodes,
         pairings: pairings,
       );

  final String hostId;
  final String hostName;
  final String appVersion;

  /// Port to try first. If it's taken, any free port is used.
  final int preferredPort;
  final Duration heartbeatInterval;

  /// A connection that sends nothing for this long is dropped.
  final Duration heartbeatTimeout;

  /// How long an unpaired connection may stay open.
  final Duration pairingWindow;

  /// After this many wrong codes in a row, the code changes.
  final int maxWrongCodes;

  /// How often each connected controller's ping and input delay go to the
  /// log, so an exported log shows a whole session (PRD T8).
  final Duration latencyLogInterval;

  /// Called with every pairing whenever one is added or forgotten, so the
  /// app can save them and pass them back as `pairings` after a restart.
  final void Function(List<SavedPairing> pairings)? onPairingsChanged;

  /// Only the most recently seen pairings are kept.
  final int maxSavedPairings;

  /// What this host supports ([Capability]), sent in every welcome (M9).
  /// With [Capability.metrics] the server acknowledges each metrics batch.
  final List<String> capabilities;

  /// The server's clock in ms, the one [ControllerInfo.inputAtMs] and
  /// [ControllerMessage.receivedAtMs] use.
  int get nowMs => _now;

  final LogSink _log;
  final PairingBook _pairings;
  final _clock = Stopwatch()..start();

  final _sessions = <HostConnection>{};
  final _changes = StreamController<HostSnapshot>.broadcast();
  final _messages = StreamController<ControllerMessage>.broadcast();
  HttpServer? _http;
  Timer? _heartbeat;
  int _lastLatencyLogMs = 0;

  /// Fires a new snapshot after every visible change, including each new
  /// round-trip time.
  Stream<HostSnapshot> get changes => _changes.stream;

  /// Messages from paired controllers only.
  Stream<ControllerMessage> get messages => _messages.stream;

  HostSnapshot get snapshot =>
      HostSnapshot(running: _http != null, port: _http?.port, pairingCode: _pairings.code, controllers: _controllers());

  String get pairingCode => _pairings.code;

  /// The port actually in use, once started.
  int? get port => _http?.port;

  Future<void> start() async {
    if (_http != null) return;
    final http = await _bind();
    _http = http;
    _log('Listening on port ${http.port} (pairing code ${_pairings.code})');
    http.listen(_onRequest, onError: (Object e) => _log('Server error: $e'));
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _tick());
    _emit();
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final s in _sessions.toList()) {
      s.close(CloseCodes.goingAway, 'Host is closing');
    }
    final http = _http;
    _http = null;
    await http?.close(force: true);
    _emit();
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
    await _messages.close();
  }

  /// Shows a new code. Controllers that are already paired stay paired.
  void newPairingCode() {
    final code = _pairings.newCode();
    _log('New pairing code $code');
    _emit();
  }

  /// The saved pairings, most recently seen first.
  List<SavedPairing> get pairings => _pairings.saved;

  /// Forgets every pairing whose controller isn't connected right now, so
  /// those phones need the code again. Returns how many were forgotten.
  int forgetDisconnected() {
    final gone = _pairings.forgetDisconnected(_liveIds);
    if (gone > 0) {
      _log('Forgot $gone paired controller${gone == 1 ? '' : 's'}');
      _pairingsChanged();
      _emit();
    }
    return gone;
  }

  /// Closes every connection as if the network dropped, so controllers
  /// reconnect on their own. A testing aid for the reconnect logic.
  void dropAllConnections() {
    _log('Dropping all connections (test)');
    for (final s in _sessions.toList()) {
      s.close(CloseCodes.goingAway, 'Dropped for testing');
    }
  }

  /// Sends [message] to every paired controller that can take it. Returns
  /// how many it went to.
  int sendToAll(Message message) {
    final paired = _sessions.where((s) => s.paired && _accepts(s, message)).toList();
    for (final s in paired) {
      s.send(message);
    }
    return paired.length;
  }

  /// Sends [message] to a paired controller. Returns false if it isn't
  /// connected, or if it didn't list the capability the message needs (a
  /// host never sends a message the controller didn't list, PRD v2 P2).
  bool send(String controllerId, Message message) {
    final s = _sessions.where((s) => s.paired && s.hello?.controllerId == controllerId).firstOrNull;
    if (s == null || !_accepts(s, message)) return false;
    s.send(message);
    return true;
  }

  /// The capability a host message needs, or null for the v1 messages every
  /// controller takes.
  static String? capabilityFor(Message message) => switch (message) {
    MetricsAckMessage() => Capability.metrics,
    RatingAskMessage() => Capability.rating,
    GameLayoutMessage() => Capability.layout,
    StatusMessage() => Capability.status,
    _ => null,
  };

  bool _accepts(HostConnection s, Message message) {
    final needed = capabilityFor(message);
    return needed == null || (s.hello?.supports(needed) ?? false);
  }

  /// Takes the lowest free player number for a local player.
  int reserveLocalPlayer() {
    final n = _pairings.reserveLocalPlayer(taken: _takenPlayerNumbers);
    _emit();
    return n;
  }

  void releaseLocalPlayer(int number) {
    if (_pairings.releaseLocalPlayer(number)) _emit();
  }

  int get _now => _clock.elapsedMilliseconds;

  /// The controllers of the sessions that are paired right now.
  Set<String> get _liveIds => {for (final s in _sessions.where((s) => s.paired)) s.hello!.controllerId};

  /// The player numbers the live paired sessions hold.
  Set<int> get _takenPlayerNumbers => {for (final s in _sessions.where((s) => s.paired && s.player != null)) s.player!};

  /// The controller's number from before if it's still free, otherwise the
  /// lowest free one.
  int _reservePlayerNumber(int? previous) => _pairings.pickPlayer(previous, taken: _takenPlayerNumbers);

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
    throw lastError ?? StateError('Could not start the server');
  }

  Future<void> _onRequest(HttpRequest request) async {
    final remote = displayIp(request.connectionInfo?.remoteAddress.address ?? '?');
    if (request.uri.path == webSocketPath && WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        _onSocket(await WebSocketTransformer.upgrade(request), remote);
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

  void _onSocket(WebSocket socket, String remote) {
    if (_http == null) {
      socket.close(CloseCodes.goingAway, 'Host is closing');
      return;
    }
    final s = HostConnection(socket, remote, _now, _SessionHost(this));
    _sessions.add(s);
    _log('Connection from $remote');
    socket.listen(
      (data) => s.onData(data),
      onDone: s.onClosed,
      onError: (Object e) => _log('Connection error from ${s.who}: $e'),
    );
  }

  void _forward(ControllerMessage message) {
    if (_messages.isClosed) return;
    _messages.add(message);
  }

  void _pairingsChanged() => onPairingsChanged?.call(pairings);

  void _tick() {
    final now = _now;
    for (final s in _sessions.toList()) {
      s.tick(now, heartbeatTimeout: heartbeatTimeout, pairingWindow: pairingWindow);
    }
    if (now - _lastLatencyLogMs >= latencyLogInterval.inMilliseconds) {
      _lastLatencyLogMs = now;
      for (final s in _sessions.where((s) => s.paired)) {
        final line = s.latencyLine(now);
        if (line != null) _log(line);
      }
    }
  }

  /// Closes every other connection of [session]'s controller: that one is the
  /// newest, and the older ones are usually half-open after a Wi-Fi drop.
  void _replaceOther(HostConnection session, int code, String reason) {
    final id = session.hello?.controllerId;
    for (final other in _sessions.toList()) {
      if (other != session && other.hello?.controllerId == id) other.close(code, reason);
    }
  }

  List<ControllerInfo> _controllers() {
    final list = <ControllerInfo>[];
    final live = <String>{};
    for (final s in _sessions) {
      final hello = s.hello;
      if (hello == null) continue;
      if (s.paired) live.add(hello.controllerId);
      list.add(s.toInfo(_now));
    }
    for (final k in _pairings.all) {
      // A paired controller that is reconnecting shows once, as "pairing".
      if (live.contains(k.hello.controllerId) || list.any((c) => c.controllerId == k.hello.controllerId)) continue;
      list.add(k.toInfo());
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }
}

void _noLog(String _) {}

/// What a [HostConnection] can do with its server (internal): the server's
/// callbacks, without putting them in [HostServer]'s public API.
final class _SessionHost implements HostSessionHost {
  _SessionHost(this._server);

  final HostServer _server;

  @override
  HostDetails get details => HostDetails(
    hostId: _server.hostId,
    hostName: _server.hostName,
    appVersion: _server.appVersion,
    capabilities: _server.capabilities,
  );

  @override
  PairingBook get pairingBook => _server._pairings;

  @override
  int get nowMs => _server.nowMs;

  @override
  void log(String message) => _server._log(message);

  @override
  void emit() => _server._emit();

  @override
  void forward(ControllerMessage message) => _server._forward(message);

  @override
  void replaceOther(HostConnection session, int code, String reason) => _server._replaceOther(session, code, reason);

  @override
  int reservePlayerNumber(int? previous) => _server._reservePlayerNumber(previous);

  @override
  Set<String> get pairedControllerIds => _server._liveIds;

  @override
  void sessionEnded(HostConnection session) => _server._sessions.remove(session);

  @override
  void pairingsChanged() => _server._pairingsChanged();
}
