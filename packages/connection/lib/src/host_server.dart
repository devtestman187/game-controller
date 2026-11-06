import 'dart:async';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_connection.dart';
import 'host_pairings.dart';
import 'host_types.dart';
import 'log.dart';
import 'saved_pairing.dart';
import 'transport/channel_listener.dart';
import 'transport/message_channel.dart';

/// The server that runs on the TV (and on the laptop), and on a phone hosting
/// a game itself (M12).
///
/// It shows a pairing code, accepts controllers that send that code (or a
/// token from an earlier pairing) over any of its listeners, sends
/// heartbeats, measures the round-trip time and drops connections that go
/// quiet.
class HostServer {
  HostServer({
    required this.hostId,
    required this.hostName,
    required this.appVersion,
    required List<ChannelListener> listeners,
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
       _listeners = List.unmodifiable(listeners),
       _pairings = PairingBook(
         random: random ?? Random.secure(),
         maxSavedPairings: maxSavedPairings,
         maxWrongCodes: maxWrongCodes,
         pairings: pairings,
       );

  final String hostId;
  final String hostName;
  final String appVersion;

  /// Where controllers reach this host: the WebSocket on the LAN, and (on a
  /// phone) the link to its own player (D1).
  final List<ChannelListener> _listeners;

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
  bool _running = false;
  Timer? _heartbeat;
  int _lastLatencyLogMs = 0;

  /// Fires a new snapshot after every visible change, including each new
  /// round-trip time.
  Stream<HostSnapshot> get changes => _changes.stream;

  /// Messages from paired controllers only.
  Stream<ControllerMessage> get messages => _messages.stream;

  HostSnapshot get snapshot =>
      HostSnapshot(running: _running, port: port, pairingCode: _pairings.code, controllers: _controllers());

  String get pairingCode => _pairings.code;

  /// The port phones reach this host on: the first listener that has one.
  int? get port {
    for (final listener in _listeners) {
      final port = listener.port;
      if (port != null) return port;
    }
    return null;
  }

  /// Starts every listener and the heartbeats. A listener that can't start
  /// stops the ones already going and its failure is thrown.
  Future<void> start() async {
    if (_running) return;
    final started = <ChannelListener>[];
    for (final listener in _listeners) {
      try {
        await listener.start(_onChannel);
      } on Object {
        for (final going in started) {
          await going.stop();
        }
        rethrow;
      }
      started.add(listener);
    }
    _running = true;
    final port = this.port;
    // A listener without a port (the host phone's own player) adds no line,
    // so the TV's log reads as it always has.
    if (port != null) _log('Listening on port $port (pairing code ${_pairings.code})');
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _tick());
    _emit();
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    // Sessions first: each phone sees 1001 "Host is closing", as it always
    // has.
    for (final s in _sessions.toList()) {
      s.close(CloseCodes.goingAway, 'Host is closing');
    }
    _running = false;
    for (final listener in _listeners) {
      await listener.stop();
    }
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

  /// Takes one new channel from a listener. The server owns it from here on.
  void _onChannel(MessageChannel channel) {
    if (!_running) {
      channel.close(CloseCodes.goingAway, 'Host is closing');
      return;
    }
    final s = HostConnection(channel, _now, _SessionHost(this));
    _sessions.add(s);
    _log('Connection from ${s.who}');
    channel.incoming.listen(
      s.onData,
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
