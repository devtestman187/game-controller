import 'package:protocol/protocol.dart';

import 'client_controls.dart';
import 'client_host.dart';
import 'client_input.dart';
import 'client_metrics.dart';
import 'client_types.dart';
import 'rtt.dart';

/// The messages from the TV, as they arrive on one channel (internal).
///
/// It holds no state of its own: the channel it was made for is gone when it
/// is, and everything else belongs to the client ([ClientHost]) or to the
/// helpers it was given.
final class ClientMessages {
  ClientMessages(
    this._host, {
    required this._rtt,
    required this._controls,
    required this._input,
    required this._metrics,
  });

  static const _codec = MessageCodec();

  final ClientHost _host;
  final RttWindow _rtt;
  final ClientControls _controls;
  final ClientInput _input;
  final MetricsOutbox _metrics;

  /// Takes one text frame from the TV. A binary frame never gets here: the
  /// channel closes it as a protocol error.
  void onData(String data) {
    final message = _decode(data);
    if (message == null) return;

    switch (message) {
      case PingMessage():
        _host.send(PongMessage.answering(message, atMs: _host.nowMs));
      case PongMessage():
        _onPong(message);
      case WelcomeMessage():
        _onWelcome(message);
      case PairResultMessage():
        _onPairResult(message);
      case HapticEventMessage():
        // Only while paired: a TV we are not paired with has no business here.
        if (!_host.snapshot.isConnected) return;
        _controls.addHaptic(message);
      case PlayerMessage():
        if (_host.snapshot.isConnected && _host.snapshot.player != message.number) {
          _host.log('The TV made this phone player ${message.number}');
          _host.setSnapshot(_host.snapshot.copyWith(player: message.number));
        }
      case MetricsAckMessage():
        _metrics.acknowledge(message);
      case RatingAskMessage():
        if (!_host.snapshot.isConnected || !_host.identity.capabilities.contains(Capability.rating)) return;
        _controls.addRatingAsk(message);
      case GameLayoutMessage():
        if (!_host.snapshot.isConnected || !_host.identity.capabilities.contains(Capability.layout)) return;
        _controls.setLayout(message);
      case StatusMessage():
        if (!_host.snapshot.isConnected || !_host.identity.capabilities.contains(Capability.status)) return;
        _controls.setStatus(message);
      case ViewStartMessage():
        if (!_showsView) return;
        _controls.addViewStart(message);
      case FrameMessage():
        if (!_showsView) return;
        _controls.addViewFrame(message, arrivedAtMs: _host.nowMs);
      case ViewEndMessage():
        if (!_showsView) return;
        _controls.addViewEnd(message);
      case HelloMessage() || PairRequestMessage() || InputStateMessage() || MetricsMessage() || RatingMessage():
        _host.log('Ignoring unexpected ${message.type} from the TV');
    }
  }

  /// True while this phone shows the game (M12): paired, and its identity
  /// listed [Capability.view].
  bool get _showsView => _host.snapshot.isConnected && _host.identity.capabilities.contains(Capability.view);

  /// The decoded message, or null when it was bad (the client gives up then)
  /// or an optional type this phone doesn't know.
  Message? _decode(String data) {
    try {
      return _codec.decode(data);
    } on ProtocolVersionMismatch catch (e) {
      _host.log('The TV uses protocol v${e.actual}, this phone uses v${e.expected}');
      _host.giveUp(
        ClientProblem.versionMismatch,
        'TV protocol v${e.actual}, phone v${e.expected}',
        closeCode: CloseCodes.versionMismatch,
      );
    } on ProtocolFormatException catch (e) {
      _host.log('Bad message from the TV: ${e.message}');
      _host.giveUp(ClientProblem.protocolError, e.message, closeCode: CloseCodes.protocolError);
    }
    return null;
  }

  void _onPong(PongMessage message) {
    final now = _host.nowMs;
    final rtt = now - message.sentAtMs;
    if (rtt >= 0 && _host.snapshot.isConnected) {
      _rtt.add(now, rtt);
      _host.setSnapshot(_host.snapshot.copyWith(rttMs: rtt, rttStats: _rtt.summary(now)));
    }
  }

  void _onWelcome(WelcomeMessage welcome) {
    _host.welcomed = true;
    // Trust the host's own ID over the advertised one: tokens are saved by it.
    final target = _host.snapshot.target!.copyWith(hostId: welcome.hostId);
    _host.setSnapshot(
      _host.snapshot.copyWith(target: target, hostName: welcome.hostName, hostCapabilities: welcome.capabilities),
    );
    _host.log(
      'Welcome from ${welcome.hostName} (TV app ${welcome.appVersion}'
      '${welcome.capabilities.isEmpty ? '' : ', supports ${welcome.capabilities.join(', ')}'})',
    );

    final code = _host.takePendingCode();
    final token = _host.tokenFor(welcome.hostId);
    if (code != null) {
      _host.log('Sending pairing code');
      _host.send(PairRequestMessage(code: code));
      _host.setSnapshot(_host.snapshot.copyWith(status: ClientStatus.pairing));
    } else if (token != null) {
      _host.log('Using the saved pairing');
      _host.send(PairRequestMessage(token: token));
    } else {
      _host.setSnapshot(_host.snapshot.copyWith(status: ClientStatus.waitingForCode));
    }
  }

  void _onPairResult(PairResultMessage result) {
    final snap = _host.snapshot;
    final hostId = snap.target!.hostId!;
    if (result.ok) {
      _host.saveToken(hostId, result.token!);
      _host.everPaired = true;
      _host.log('Paired with ${snap.hostLabel}');
      _host.setSnapshot(
        snap.copyWith(status: ClientStatus.connected, problem: null, detail: null, attempt: 0, osErrorCode: null),
      );
      // The TV starts each connection with nothing pressed. Tell it what is
      // held right now (also after a reconnect).
      _host.send(_input.nextState(_host.nowMs));
      _resendMetrics();
      return;
    }
    switch (result.failure!) {
      case PairFailure.unknownToken:
        _host.log('The TV no longer knows this phone, the code is needed again');
        _host.saveToken(hostId, null);
        _host.everPaired = false;
        _host.setSnapshot(snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.pairingForgotten));
      case PairFailure.wrongCode:
        _host.log('Wrong pairing code');
        _host.dropChannel(); // The host closes it anyway. A new code reconnects.
        _host.setSnapshot(snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.wrongCode));
      case PairFailure.tooManyAttempts:
        _host.log('Too many wrong codes, the TV shows a new one');
        _host.dropChannel();
        _host.setSnapshot(snap.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.tooManyAttempts));
    }
  }

  /// After pairing: everything the TV hasn't acknowledged yet.
  void _resendMetrics() {
    if (!_host.hostTakesMetrics) return;
    var sent = 0;
    for (final batch in _metrics.unacknowledged) {
      _host.send(batch);
      sent++;
    }
    if (sent > 0) _host.log('Metrics: sent $sent waiting segment${sent == 1 ? '' : 's'} again');
  }
}
