import 'package:protocol/protocol.dart';

import 'host_pairings.dart';
import 'host_types.dart';
import 'latency.dart';
import 'rtt.dart';
import 'transport/message_channel.dart';

/// What the log calls a peer without a network address: the host phone's own
/// player (D1).
const String localPeerLabel = 'the local player';

/// What a controller is told about its host in the welcome (internal).
final class HostDetails {
  const HostDetails({
    required this.hostId,
    required this.hostName,
    required this.appVersion,
    required this.capabilities,
  });

  final String hostId;
  final String hostName;
  final String appVersion;

  /// What this host supports ([Capability]), sent in every welcome (M9).
  final List<String> capabilities;
}

/// What a [HostConnection] needs from the server that owns it (internal).
///
/// Everything here is a call the session code made on [HostServer] before the
/// split; the server keeps its own members private.
abstract interface class HostSessionHost {
  /// The fields of every welcome.
  HostDetails get details;

  /// The pairings this host remembers.
  PairingBook get pairingBook;

  /// The server's clock in ms, the one [ControllerInfo.inputAtMs] and
  /// [ControllerMessage.receivedAtMs] use.
  int get nowMs;

  /// Writes one line to the host app's log.
  void log(String message);

  /// Fires a new snapshot after every visible change.
  void emit();

  /// Hands [message] to whoever listens for the controllers' messages.
  void forward(ControllerMessage message);

  /// Closes every other connection of the controller [session] is paired
  /// with, as that one is the newest.
  void replaceOther(HostConnection session, int code, String reason);

  /// The controller's number from before if it's still free, otherwise the
  /// lowest free one.
  int reservePlayerNumber(int? previous);

  /// The controllers that are paired right now, in any order.
  Set<String> get pairedControllerIds;

  /// [session] is gone; the server forgets it.
  void sessionEnded(HostConnection session);

  /// Tells the app that the saved pairings changed.
  void pairingsChanged();
}

/// One controller's connection: the state it built up, its messages in and
/// out, and its heartbeats (internal; today's `HostServer._Session` plus the
/// server's handling for one session).
final class HostConnection {
  HostConnection(this._channel, this.openedAtMs, this._host) : lastHeardMs = openedAtMs;

  static const _codec = MessageCodec();

  final MessageChannel _channel;
  final HostSessionHost _host;

  /// The peer's network address, as the host shows it. Null for the host
  /// phone's own player (D1).
  String? get remoteAddress => _channel.remoteAddress;

  /// When the connection opened, on the host's clock.
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

  /// The name for logs: the controller's own, or its address before hello.
  String get who => hello?.name ?? remoteAddress ?? localPeerLabel;

  /// Takes one text frame from the channel. A binary frame never gets here:
  /// the channel closes it as a protocol error.
  void onData(String data) {
    if (closed) return;
    lastHeardMs = _host.nowMs;
    final message = _decode(data);
    if (message == null) return; // An optional message type from a newer peer.
    _handle(message);
  }

  /// The channel's done callback: the peer closed or the network dropped.
  void onClosed() {
    if (closed) return;
    final code = _channel.closeCode;
    _host.log('$who disconnected${code == null ? '' : ' (code $code)'}');
    _ended();
  }

  /// Closes from this side. The channel's own done callback then does nothing.
  void close(int code, String reason) {
    if (closed) return;
    _ended();
    // close() can wait a long time on a dead network, so don't await it.
    _channel.close(code, reason).then((_) {}, onError: (_) {});
  }

  /// Sends [message] to this controller, if the connection is still open.
  void send(Message message) {
    if (closed) return;
    final String text;
    try {
      text = _codec.encode(message);
    } catch (e) {
      _host.log('Send to $who failed: $e');
      return;
    }
    sendText(text);
  }

  /// Sends [text], a message that is already encoded: [HostServer.sendToAll]
  /// encodes one message once for every controller that takes it.
  void sendText(String text) {
    if (closed) return;
    try {
      _channel.send(text);
    } catch (e) {
      _host.log('Send to $who failed: $e');
    }
  }

  /// The heartbeat and pairing-window check for this connection, run on every
  /// heartbeat tick; otherwise it pings.
  void tick(int now, {required Duration heartbeatTimeout, required Duration pairingWindow}) {
    final quietMs = now - lastHeardMs;
    if (quietMs > heartbeatTimeout.inMilliseconds) {
      _host.log('$who: no heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, dropping the connection');
      close(CloseCodes.heartbeatTimeout, 'No heartbeat');
    } else if (!paired && now - openedAtMs > pairingWindow.inMilliseconds) {
      _host.log('$who: didn\'t pair in time');
      close(CloseCodes.pairingTimeout, 'Pairing timed out');
    } else {
      send(PingMessage(id: nextPingId++, sentAtMs: now));
    }
  }

  /// This connection as the host UI shows it, on the host's clock, when it is
  /// paired or still pairing. Must not be called before hello.
  ControllerInfo toInfo(int now) => ControllerInfo(
    controllerId: hello!.controllerId,
    name: hello!.name,
    platform: hello!.platform,
    appVersion: hello!.appVersion,
    remoteAddress: remoteAddress,
    isLocal: _channel.isLocal,
    state: paired ? ControllerState.connected : ControllerState.pairing,
    since: since,
    rttMs: rttMs,
    rttStats: rttWindow.summary(now),
    input: paired ? input : null,
    player: paired ? player : null,
    inputLatency: latency.summary(now),
    inputLatencySession: switch (latency.session) {
      final t when t.count > 0 => RttSummary(minMs: t.minMs!, avgMs: t.avgMs!, maxMs: t.maxMs!, samples: t.count),
      _ => null,
    },
    latencyErrorMs: latency.uncertaintyMs,
    capabilities: hello!.capabilities,
    device: hello!.device,
    role: hello!.role,
    inputAtMs: paired ? inputAtMs : null,
  );

  /// The latency log line for this connection, or null before the first ping
  /// came back.
  String? latencyLine(int now) {
    final rtt = rttWindow.summary(now);
    if (rtt == null) return null;
    final latency = this.latency.summary(now);
    final error = this.latency.uncertaintyMs;
    final inputText = latency == null
        ? 'input delay not measured${this.latency.offsetMs == null ? ' (phone sends no clock)' : ''}'
        : 'input delay ~ avg ${latency.avgMs} · p95 ${latency.p95Ms} · max ${latency.maxMs} ms (± $error ms, '
              '${latency.samples} states)';
    return 'Latency $who: ping $rtt, $inputText';
  }

  /// The decoded message, or null when it was bad (the connection is closed
  /// then) or an optional type this host doesn't know.
  Message? _decode(String data) {
    try {
      return _codec.decode(data);
    } on ProtocolVersionMismatch catch (e) {
      _host.log('$who uses protocol v${e.actual}, this host uses v${e.expected}');
      close(CloseCodes.versionMismatch, 'The TV app uses protocol v$protocolVersion');
    } on ProtocolFormatException catch (e) {
      _host.log('Bad message from $who: ${e.message}');
      close(CloseCodes.protocolError, 'Bad message');
    }
    return null;
  }

  void _handle(Message message) {
    switch (message) {
      case PingMessage():
        send(PongMessage.answering(message, atMs: _host.nowMs));
      case PongMessage():
        _onPong(message);
      case HelloMessage():
        _onHello(message);
      case PairRequestMessage():
        _onPair(message);
      case InputStateMessage():
        _onInput(message);
      case MetricsMessage():
        _onMetrics(message);
      case RatingMessage():
        if (paired) _forward(message, _host.nowMs);
      case WelcomeMessage() ||
          PairResultMessage() ||
          HapticEventMessage() ||
          PlayerMessage() ||
          MetricsAckMessage() ||
          RatingAskMessage() ||
          GameLayoutMessage() ||
          StatusMessage() ||
          ViewStartMessage() ||
          FrameMessage() ||
          ViewEndMessage() ||
          HostAwayMessage() ||
          HostBackMessage() ||
          PlayerAwayMessage() ||
          PlayerBackMessage():
        close(CloseCodes.protocolError, 'Unexpected ${message.type}');
    }
  }

  void _onPong(PongMessage message) {
    final now = _host.nowMs;
    final rtt = now - message.sentAtMs;
    if (rtt >= 0 && paired) {
      rttMs = rtt;
      rttWindow.add(now, rtt);
      final peer = message.atMs;
      if (peer != null) latency.addPong(sentAtMs: message.sentAtMs, peerMs: peer, receivedMs: now);
      _host.emit();
    }
  }

  void _onInput(InputStateMessage message) {
    // Input counts only once paired, and only in order.
    if (!paired || message.seq <= (input?.seq ?? -1)) return;
    final now = _host.nowMs;
    input = message;
    inputAtMs = now;
    final sent = message.sentAtMs;
    final delay = sent == null ? null : latency.addInput(peerSentMs: sent, receivedMs: now);
    _host.emit();
    _forward(message, now, delayMs: delay);
  }

  void _onMetrics(MetricsMessage message) {
    if (!paired) return;
    // Acknowledged at once: the app keeps it from here (M9).
    if (_host.details.capabilities.contains(Capability.metrics) && hello!.supports(Capability.metrics)) {
      send(MetricsAckMessage(segment: message.segment, index: message.index));
    }
    _forward(message, _host.nowMs);
  }

  void _onHello(HelloMessage hello) {
    if (this.hello != null) return close(CloseCodes.protocolError, 'Duplicate hello');
    this.hello = hello;
    final caps = hello.capabilities.isEmpty ? '' : ', supports ${hello.capabilities.join(', ')}';
    _host.log(
      '${hello.name} (${hello.platform} ${hello.appVersion}$caps) says hello from ${remoteAddress ?? localPeerLabel}',
    );
    final details = _host.details;
    send(
      WelcomeMessage(
        hostId: details.hostId,
        hostName: details.hostName,
        appVersion: details.appVersion,
        capabilities: details.capabilities,
      ),
    );
    _host.emit();
  }

  void _onPair(PairRequestMessage request) {
    final hello = this.hello;
    if (hello == null) return close(CloseCodes.protocolError, 'Pair request before hello');
    final book = _host.pairingBook;
    if (paired) {
      send(PairResultMessage.accepted(token: book.known(hello.controllerId)!.token));
      return;
    }

    final token = request.token;
    if (token != null) {
      if (book.known(hello.controllerId)?.token == token) {
        _accept(token, how: 'saved pairing');
      } else {
        _host.log('${hello.name}: saved pairing not recognized, waiting for the code');
        send(const PairResultMessage.refused(PairFailure.unknownToken));
      }
      return;
    }

    if (request.code == book.code) {
      book.clearWrongCodes();
      _accept(book.newToken(), how: 'pairing code');
      return;
    }

    if (book.countWrongCode()) {
      _host.log('${hello.name}: wrong code, ${book.maxWrongCodes} in a row. New pairing code ${book.code}');
      send(const PairResultMessage.refused(PairFailure.tooManyAttempts));
    } else {
      _host.log('${hello.name}: wrong code (${book.wrongCodes} of ${book.maxWrongCodes})');
      send(const PairResultMessage.refused(PairFailure.wrongCode));
    }
    close(CloseCodes.pairingFailed, 'Wrong pairing code');
  }

  void _accept(String token, {required String how}) {
    final hello = this.hello!;
    // One live connection per controller. An older one is usually half-open
    // after a Wi-Fi drop, so replace it.
    _host.replaceOther(this, CloseCodes.replaced, 'Replaced by a newer connection');
    final book = _host.pairingBook;
    final number = _host.reservePlayerNumber(book.known(hello.controllerId)?.player);
    paired = true;
    since = DateTime.now();
    player = number;
    final changed = book.remember(
      hello,
      token,
      remoteAddress: remoteAddress,
      player: number,
      live: _host.pairedControllerIds,
    );
    send(PairResultMessage.accepted(token: token));
    send(PlayerMessage(number: number));
    _host.log('${hello.name} connected ($how), player $player');
    if (changed) _host.pairingsChanged();
    _host.emit();
  }

  void _forward(Message message, int now, {int? delayMs}) =>
      _host.forward(ControllerMessage(hello!.controllerId, message, receivedAtMs: now, delayMs: delayMs));

  void _ended() {
    closed = true;
    _host.sessionEnded(this);
    final id = hello?.controllerId;
    if (paired && id != null) {
      _host.pairingBook.markSeen(id);
      final total = latency.session;
      final connectedFor = DateTime.now().difference(since);
      _host.log(
        'Session of $who ended after ${_duration(connectedFor)}: input delay ~ $total'
        '${latency.uncertaintyMs == null ? '' : ' (± ${latency.uncertaintyMs} ms)'}',
      );
    }
    // No stuck inputs: whoever reads the input stream sees everything released.
    final input = this.input;
    if (id != null && input != null && !input.isNeutral) {
      _host.forward(ControllerMessage(id, InputStateMessage(seq: input.seq + 1)));
    }
    _host.emit();
  }
}

String _duration(Duration d) => d.inMinutes >= 1 ? '${d.inMinutes} min ${d.inSeconds % 60} s' : '${d.inSeconds} s';
