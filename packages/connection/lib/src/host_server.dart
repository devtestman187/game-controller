import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:protocol/protocol.dart';

import 'host_address.dart';
import 'latency.dart';
import 'log.dart';
import 'rtt.dart';

/// Where a controller is in its connection, as seen by the host.
enum ControllerState {
  /// Connected but hasn't entered the right code yet. Its input is ignored.
  pairing,

  /// Paired and sending heartbeats.
  connected,

  /// Paired earlier, but its connection is gone. It can come back without a
  /// code, also after the host app restarts if the app saves the pairings
  /// ([HostServer.onPairingsChanged]).
  disconnected,
}

/// One controller in [HostSnapshot.controllers].
final class ControllerInfo {
  const ControllerInfo({
    required this.controllerId,
    required this.name,
    required this.platform,
    required this.appVersion,
    required this.remoteAddress,
    required this.state,
    required this.since,
    this.rttMs,
    this.rttStats,
    this.input,
    this.player,
    this.inputLatency,
    this.inputLatencySession,
    this.latencyErrorMs,
    this.capabilities = const [],
    this.device,
    this.role = DeviceRole.controller,
    this.inputAtMs,
  });

  final String controllerId;
  final String name;
  final String platform;
  final String appVersion;
  final String remoteAddress;
  final ControllerState state;

  /// When [state] last changed.
  final DateTime since;

  /// Latest heartbeat round-trip time, measured on the host.
  final int? rttMs;

  /// Lowest, average and highest round-trip time over the last 30 s.
  final RttSummary? rttStats;

  /// The controller's current input. Null when it isn't connected, so a
  /// dropped controller never leaves buttons held.
  final InputStateMessage? input;

  /// Player number (1, 2, …), also sent to the phone in a [PlayerMessage].
  /// Null while it isn't connected.
  final int? player;

  /// Estimated one-way input delay, phone to host, over the last 30 s. Null
  /// until the clocks are compared (and always for phones older than M6).
  final RttSummary? inputLatency;

  /// The same over the whole connection.
  final RttSummary? inputLatencySession;

  /// How far off the input delay estimate can be, in ms (half the best
  /// recent round trip).
  final int? latencyErrorMs;

  /// What the controller supports ([Capability]), from its hello (M9).
  final List<String> capabilities;

  /// The kind of device (M9), or null for older phones.
  final DeviceInfo? device;

  /// [DeviceRole.controller] for every v2 phone.
  final String role;

  /// When [input] arrived, on [HostServer.nowMs]. For the latency stages.
  final int? inputAtMs;

  bool supports(String capability) => capabilities.contains(capability);
}

/// A pairing the host app can save, so phones reconnect without a code after
/// the app restarts.
final class SavedPairing {
  const SavedPairing({
    required this.controllerId,
    required this.token,
    required this.name,
    required this.platform,
    required this.appVersion,
    this.remoteAddress = '',
  });

  final String controllerId;
  final String token;
  final String name;
  final String platform;
  final String appVersion;
  final String remoteAddress;

  Map<String, Object?> toJson() => {
    'id': controllerId,
    'token': token,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
    'address': remoteAddress,
  };

  /// Null if [json] isn't a saved pairing.
  static SavedPairing? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final token = json['token'];
    if (id is! String || token is! String || id.isEmpty || token.isEmpty) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    return SavedPairing(
      controllerId: id,
      token: token,
      name: text('name').isEmpty ? 'Thumb Party TV' : text('name'),
      platform: text('platform'),
      appVersion: text('appVersion'),
      remoteAddress: text('address'),
    );
  }
}

/// Everything the host UI shows, as one immutable value.
final class HostSnapshot {
  const HostSnapshot({required this.running, required this.pairingCode, required this.controllers, this.port});

  final bool running;
  final int? port;
  final String pairingCode;
  final List<ControllerInfo> controllers;

  Iterable<ControllerInfo> get connected => controllers.where((c) => c.state == ControllerState.connected);
}

/// A message from a paired controller (input messages arrive here from M2).
final class ControllerMessage {
  const ControllerMessage(this.controllerId, this.message, {this.receivedAtMs = 0, this.delayMs});

  final String controllerId;
  final Message message;

  /// When it arrived, on [HostServer.nowMs].
  final int receivedAtMs;

  /// For input states: the estimated one-way delay from the phone, or null
  /// before the clocks are compared (the "sent to received" stage, S7).
  final int? delayMs;
}

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
       _random = random ?? Random.secure() {
    _code = _newCode();
    for (final p in pairings) {
      _known[p.controllerId] = _Known(
        HelloMessage(controllerId: p.controllerId, name: p.name, platform: p.platform, appVersion: p.appVersion),
        p.token,
        p.remoteAddress,
      );
    }
  }

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
  final Random _random;
  static const _codec = MessageCodec();
  final _clock = Stopwatch()..start();

  final _sessions = <_Session>{};
  final _known = <String, _Known>{};
  final _changes = StreamController<HostSnapshot>.broadcast();
  final _messages = StreamController<ControllerMessage>.broadcast();
  HttpServer? _http;
  Timer? _heartbeat;
  late String _code;
  int _wrongCodes = 0;
  int _lastLatencyLogMs = 0;

  /// Fires a new snapshot after every visible change, including each new
  /// round-trip time.
  Stream<HostSnapshot> get changes => _changes.stream;

  /// Messages from paired controllers only.
  Stream<ControllerMessage> get messages => _messages.stream;

  HostSnapshot get snapshot =>
      HostSnapshot(running: _http != null, port: _http?.port, pairingCode: _code, controllers: _controllers());

  String get pairingCode => _code;

  /// The port actually in use, once started.
  int? get port => _http?.port;

  Future<void> start() async {
    if (_http != null) return;
    final http = await _bind();
    _http = http;
    _log('Listening on port ${http.port} (pairing code $_code)');
    http.listen(_onRequest, onError: (Object e) => _log('Server error: $e'));
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _tick());
    _emit();
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    for (final s in _sessions.toList()) {
      _close(s, CloseCodes.goingAway, 'Host is closing');
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
    _code = _newCode(previous: _code);
    _wrongCodes = 0;
    _log('New pairing code $_code');
    _emit();
  }

  /// The saved pairings, most recently seen first.
  List<SavedPairing> get pairings {
    // Newest first. The clock can give two pairings the same time (Windows'
    // clock is coarse), so a tie goes to the one added later.
    final entries = _known.entries.toList();
    final order = {for (final (i, e) in entries.indexed) e.key: i};
    final known = entries
      ..sort((a, b) {
        final byTime = b.value.lastSeen.compareTo(a.value.lastSeen);
        return byTime != 0 ? byTime : order[b.key]!.compareTo(order[a.key]!);
      });
    return [
      for (final MapEntry(key: id, value: k) in known)
        SavedPairing(
          controllerId: id,
          token: k.token,
          name: k.hello.name,
          platform: k.hello.platform,
          appVersion: k.hello.appVersion,
          remoteAddress: k.remoteAddress,
        ),
    ];
  }

  /// Forgets every pairing whose controller isn't connected right now, so
  /// those phones need the code again. Returns how many were forgotten.
  int forgetDisconnected() {
    final live = {for (final s in _sessions.where((s) => s.paired)) s.hello!.controllerId};
    final gone = _known.keys.where((id) => !live.contains(id)).toList();
    for (final id in gone) {
      _known.remove(id);
    }
    if (gone.isNotEmpty) {
      _log('Forgot ${gone.length} paired controller${gone.length == 1 ? '' : 's'}');
      _pairingsChanged();
      _emit();
    }
    return gone.length;
  }

  /// Closes every connection as if the network dropped, so controllers
  /// reconnect on their own. A testing aid for the reconnect logic.
  void dropAllConnections() {
    _log('Dropping all connections (test)');
    for (final s in _sessions.toList()) {
      _close(s, CloseCodes.goingAway, 'Dropped for testing');
    }
  }

  /// Sends [message] to every paired controller that can take it. Returns
  /// how many it went to.
  int sendToAll(Message message) {
    final paired = _sessions.where((s) => s.paired && _accepts(s, message)).toList();
    for (final s in paired) {
      _send(s, message);
    }
    return paired.length;
  }

  /// Sends [message] to a paired controller. Returns false if it isn't
  /// connected, or if it didn't list the capability the message needs (a
  /// host never sends a message the controller didn't list, PRD v2 P2).
  bool send(String controllerId, Message message) {
    final s = _sessions.where((s) => s.paired && s.hello?.controllerId == controllerId).firstOrNull;
    if (s == null || !_accepts(s, message)) return false;
    _send(s, message);
    return true;
  }

  /// The capability a host message needs, or null for the v1 messages every
  /// controller takes.
  static String? capabilityFor(Message message) => switch (message) {
    MetricsAckMessage() => Capability.metrics,
    RatingAskMessage() => Capability.rating,
    _ => null,
  };

  bool _accepts(_Session s, Message message) {
    final needed = capabilityFor(message);
    return needed == null || (s.hello?.supports(needed) ?? false);
  }

  /// Player numbers taken by players on this device (a keyboard player on
  /// Windows, PRD v2 S2), so phones get other numbers.
  final _localNumbers = <int>{};

  /// Takes the lowest free player number for a local player.
  int reserveLocalPlayer() {
    final n = _pickPlayer(null);
    _localNumbers.add(n);
    _emit();
    return n;
  }

  void releaseLocalPlayer(int number) {
    if (_localNumbers.remove(number)) _emit();
  }

  int get _now => _clock.elapsedMilliseconds;

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
    final s = _Session(socket, remote, _now);
    _sessions.add(s);
    _log('Connection from $remote');
    socket.listen(
      (data) => _onData(s, data),
      onDone: () => _onClosed(s),
      onError: (Object e) => _log('Connection error from ${_who(s)}: $e'),
    );
  }

  void _onData(_Session s, Object? data) {
    if (s.closed) return;
    s.lastHeardMs = _now;
    if (data is! String) return _close(s, CloseCodes.protocolError, 'Expected text frames');

    final Message? message;
    try {
      message = _codec.decode(data);
    } on ProtocolVersionMismatch catch (e) {
      _log('${_who(s)} uses protocol v${e.actual}, this host uses v${e.expected}');
      return _close(s, CloseCodes.versionMismatch, 'The TV app uses protocol v$protocolVersion');
    } on ProtocolFormatException catch (e) {
      _log('Bad message from ${_who(s)}: ${e.message}');
      return _close(s, CloseCodes.protocolError, 'Bad message');
    }
    if (message == null) return; // An optional message type from a newer peer.

    switch (message) {
      case PingMessage():
        _send(s, PongMessage.answering(message, atMs: _now));
      case PongMessage():
        final now = _now;
        final rtt = now - message.sentAtMs;
        if (rtt >= 0 && s.paired) {
          s.rttMs = rtt;
          s.rttWindow.add(now, rtt);
          final peer = message.atMs;
          if (peer != null) s.latency.addPong(sentAtMs: message.sentAtMs, peerMs: peer, receivedMs: now);
          _emit();
        }
      case HelloMessage():
        _onHello(s, message);
      case PairRequestMessage():
        _onPair(s, message);
      case InputStateMessage():
        // Input counts only once paired, and only in order.
        if (!s.paired || message.seq <= (s.input?.seq ?? -1)) return;
        final now = _now;
        s.input = message;
        s.inputAtMs = now;
        final sent = message.sentAtMs;
        final delay = sent == null ? null : s.latency.addInput(peerSentMs: sent, receivedMs: now);
        _emit();
        _forward(s, message, now, delayMs: delay);
      case MetricsMessage():
        if (!s.paired) return;
        // Acknowledged at once: the app keeps it from here (M9).
        if (capabilities.contains(Capability.metrics) && s.hello!.supports(Capability.metrics)) {
          _send(s, MetricsAckMessage(segment: message.segment, index: message.index));
        }
        _forward(s, message, _now);
      case RatingMessage():
        if (s.paired) _forward(s, message, _now);
      case WelcomeMessage() ||
          PairResultMessage() ||
          HapticEventMessage() ||
          PlayerMessage() ||
          MetricsAckMessage() ||
          RatingAskMessage():
        _close(s, CloseCodes.protocolError, 'Unexpected ${message.type}');
    }
  }

  void _forward(_Session s, Message message, int now, {int? delayMs}) {
    if (_messages.isClosed) return;
    _messages.add(ControllerMessage(s.hello!.controllerId, message, receivedAtMs: now, delayMs: delayMs));
  }

  void _onHello(_Session s, HelloMessage hello) {
    if (s.hello != null) return _close(s, CloseCodes.protocolError, 'Duplicate hello');
    s.hello = hello;
    final caps = hello.capabilities.isEmpty ? '' : ', supports ${hello.capabilities.join(', ')}';
    _log('${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${s.remoteAddress}');
    _send(s, WelcomeMessage(hostId: hostId, hostName: hostName, appVersion: appVersion, capabilities: capabilities));
    _emit();
  }

  void _onPair(_Session s, PairRequestMessage request) {
    final hello = s.hello;
    if (hello == null) return _close(s, CloseCodes.protocolError, 'Pair request before hello');
    if (s.paired) {
      _send(s, PairResultMessage.accepted(token: _known[hello.controllerId]!.token));
      return;
    }

    final token = request.token;
    if (token != null) {
      final known = _known[hello.controllerId];
      if (known != null && known.token == token) {
        _accept(s, token, how: 'saved pairing');
      } else {
        _log('${hello.name}: saved pairing not recognized, waiting for the code');
        _send(s, const PairResultMessage.refused(PairFailure.unknownToken));
      }
      return;
    }

    if (request.code == _code) {
      _wrongCodes = 0;
      _accept(s, _newToken(), how: 'pairing code');
      return;
    }

    _wrongCodes++;
    if (_wrongCodes >= maxWrongCodes) {
      _code = _newCode(previous: _code);
      _wrongCodes = 0;
      _log('${hello.name}: wrong code, $maxWrongCodes in a row. New pairing code $_code');
      _send(s, const PairResultMessage.refused(PairFailure.tooManyAttempts));
    } else {
      _log('${hello.name}: wrong code ($_wrongCodes of $maxWrongCodes)');
      _send(s, const PairResultMessage.refused(PairFailure.wrongCode));
    }
    _close(s, CloseCodes.pairingFailed, 'Wrong pairing code');
  }

  void _accept(_Session s, String token, {required String how}) {
    final hello = s.hello!;
    // One live connection per controller. An older one is usually half-open
    // after a Wi-Fi drop, so replace it.
    for (final other in _sessions.toList()) {
      if (other != s && other.hello?.controllerId == hello.controllerId) {
        _close(other, CloseCodes.replaced, 'Replaced by a newer connection');
      }
    }
    final previous = _known[hello.controllerId];
    s
      ..paired = true
      ..since = DateTime.now()
      ..player = _pickPlayer(previous?.player);
    _known[hello.controllerId] = _Known(hello, token, s.remoteAddress)..player = s.player;
    _trimPairings();
    _send(s, PairResultMessage.accepted(token: token));
    _send(s, PlayerMessage(number: s.player!));
    _log('${hello.name} connected ($how), player ${s.player}');
    if (previous == null || previous.token != token || previous.hello.name != hello.name) _pairingsChanged();
    _emit();
  }

  /// The controller's number from before if it's still free, otherwise the
  /// lowest free one. A number stays reserved for a minute after its
  /// controller drops, so a short Wi-Fi drop doesn't swap players.
  int _pickPlayer(int? previous) {
    final taken = {for (final o in _sessions.where((o) => o.paired && o.player != null)) o.player!, ..._localNumbers};
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    final reserved = {
      for (final k in _known.values)
        if (k.player != null && k.lastSeen.isAfter(cutoff) && !taken.contains(k.player)) k.player!,
    };
    if (previous != null && !taken.contains(previous)) return previous;
    var n = 1;
    while (taken.contains(n) || reserved.contains(n)) {
      n++;
    }
    return n;
  }

  void _trimPairings() {
    if (_known.length <= maxSavedPairings) return;
    final live = {for (final s in _sessions.where((s) => s.paired)) s.hello!.controllerId};
    final oldest = _known.entries.where((e) => !live.contains(e.key)).toList()
      ..sort((a, b) => a.value.lastSeen.compareTo(b.value.lastSeen));
    for (final e in oldest.take(_known.length - maxSavedPairings)) {
      _known.remove(e.key);
    }
  }

  void _pairingsChanged() => onPairingsChanged?.call(pairings);

  void _tick() {
    final now = _now;
    for (final s in _sessions.toList()) {
      final quietMs = now - s.lastHeardMs;
      if (quietMs > heartbeatTimeout.inMilliseconds) {
        _log('${_who(s)}: no heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, dropping the connection');
        _close(s, CloseCodes.heartbeatTimeout, 'No heartbeat');
      } else if (!s.paired && now - s.openedAtMs > pairingWindow.inMilliseconds) {
        _log('${_who(s)}: didn\'t pair in time');
        _close(s, CloseCodes.pairingTimeout, 'Pairing timed out');
      } else {
        _send(s, PingMessage(id: s.nextPingId++, sentAtMs: now));
      }
    }
    if (now - _lastLatencyLogMs >= latencyLogInterval.inMilliseconds) {
      _lastLatencyLogMs = now;
      for (final s in _sessions.where((s) => s.paired)) {
        final line = _latencyLine(s, now);
        if (line != null) _log(line);
      }
    }
  }

  String? _latencyLine(_Session s, int now) {
    final rtt = s.rttWindow.summary(now);
    if (rtt == null) return null;
    final input = s.latency.summary(now);
    final error = s.latency.uncertaintyMs;
    final inputText = input == null
        ? 'input delay not measured${s.latency.offsetMs == null ? ' (phone sends no clock)' : ''}'
        : 'input delay ~ avg ${input.avgMs} · p95 ${input.p95Ms} · max ${input.maxMs} ms (± $error ms, '
              '${input.samples} states)';
    return 'Latency ${_who(s)}: ping $rtt, $inputText';
  }

  void _send(_Session s, Message message) {
    if (s.closed) return;
    try {
      s.socket.add(_codec.encode(message));
    } catch (e) {
      _log('Send to ${_who(s)} failed: $e');
    }
  }

  /// Closes from this side. The socket's own onDone then does nothing.
  void _close(_Session s, int code, String reason) {
    if (s.closed) return;
    _ended(s);
    // close() can wait a long time on a dead network, so don't await it.
    s.socket.close(code, reason).then((_) {}, onError: (_) {});
  }

  void _onClosed(_Session s) {
    if (s.closed) return;
    _log('${_who(s)} disconnected${s.socket.closeCode == null ? '' : ' (code ${s.socket.closeCode})'}');
    _ended(s);
  }

  void _ended(_Session s) {
    s.closed = true;
    _sessions.remove(s);
    final id = s.hello?.controllerId;
    if (s.paired && id != null) {
      _known[id]?.lastSeen = DateTime.now();
      final total = s.latency.session;
      final connectedFor = DateTime.now().difference(s.since);
      _log(
        'Session of ${_who(s)} ended after ${_duration(connectedFor)}: input delay ~ $total'
        '${s.latency.uncertaintyMs == null ? '' : ' (± ${s.latency.uncertaintyMs} ms)'}',
      );
    }
    // No stuck inputs: whoever reads the input stream sees everything released.
    final input = s.input;
    if (id != null && input != null && !input.isNeutral && !_messages.isClosed) {
      _messages.add(ControllerMessage(id, InputStateMessage(seq: input.seq + 1)));
    }
    _emit();
  }

  List<ControllerInfo> _controllers() {
    final list = <ControllerInfo>[];
    final live = <String>{};
    for (final s in _sessions) {
      final hello = s.hello;
      if (hello == null) continue;
      if (s.paired) live.add(hello.controllerId);
      list.add(
        ControllerInfo(
          controllerId: hello.controllerId,
          name: hello.name,
          platform: hello.platform,
          appVersion: hello.appVersion,
          remoteAddress: s.remoteAddress,
          state: s.paired ? ControllerState.connected : ControllerState.pairing,
          since: s.since,
          rttMs: s.rttMs,
          rttStats: s.rttWindow.summary(_now),
          input: s.paired ? s.input : null,
          player: s.paired ? s.player : null,
          inputLatency: s.latency.summary(_now),
          inputLatencySession: switch (s.latency.session) {
            final t when t.count > 0 => RttSummary(minMs: t.minMs!, avgMs: t.avgMs!, maxMs: t.maxMs!, samples: t.count),
            _ => null,
          },
          latencyErrorMs: s.latency.uncertaintyMs,
          capabilities: hello.capabilities,
          device: hello.device,
          role: hello.role,
          inputAtMs: s.paired ? s.inputAtMs : null,
        ),
      );
    }
    for (final MapEntry(key: id, value: k) in _known.entries) {
      // A paired controller that is reconnecting shows once, as "pairing".
      if (live.contains(id) || list.any((c) => c.controllerId == id)) continue;
      list.add(
        ControllerInfo(
          controllerId: id,
          name: k.hello.name,
          platform: k.hello.platform,
          appVersion: k.hello.appVersion,
          remoteAddress: k.remoteAddress,
          state: ControllerState.disconnected,
          since: k.lastSeen,
        ),
      );
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  String _who(_Session s) => s.hello?.name ?? s.remoteAddress;

  String _newCode({String? previous}) {
    String code;
    do {
      code = _random.nextInt(10000).toString().padLeft(4, '0');
    } while (code == previous);
    return code;
  }

  String _newToken() => List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

void _noLog(String _) {}

String _duration(Duration d) => d.inMinutes >= 1 ? '${d.inMinutes} min ${d.inSeconds % 60} s' : '${d.inSeconds} s';

class _Session {
  _Session(this.socket, this.remoteAddress, this.openedAtMs) : lastHeardMs = openedAtMs;

  final WebSocket socket;
  final String remoteAddress;
  final int openedAtMs;
  int lastHeardMs;
  HelloMessage? hello;
  bool paired = false;
  bool closed = false;
  int? rttMs;
  final rttWindow = RttWindow();
  InputStateMessage? input;
  int? inputAtMs;
  int nextPingId = 0;
  DateTime since = DateTime.now();
  int? player;
  final latency = InputLatency();
}

class _Known {
  _Known(this.hello, this.token, this.remoteAddress);

  final HelloMessage hello;
  final String token;
  final String remoteAddress;
  DateTime lastSeen = DateTime.now();
  int? player;
}
