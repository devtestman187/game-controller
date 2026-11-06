import 'dart:async';

import 'package:protocol/protocol.dart';

import 'client_host.dart';
import 'client_messages.dart';
import 'client_types.dart';
import 'transport/connect_error.dart';
import 'transport/connector.dart';
import 'transport/message_channel.dart';

/// The channel to the TV: opening it, the heartbeats over it and what happens
/// when it goes (internal; today's `ControllerClient` socket code).
///
/// The client owns it from the first [open], so the channel count and the
/// last-heard time outlive a reconnect.
final class ClientConnection {
  ClientConnection(
    this._host, {
    required this.heartbeatInterval,
    required this.heartbeatTimeout,
    required this.connector,
    required DateTime Function() wallClock,
  }) : _wallClock = wallClock,
       _lastHeardAt = wallClock();

  static const _codec = MessageCodec();

  final ClientHost _host;

  /// How often this phone pings the TV.
  final Duration heartbeatInterval;

  /// The connection counts as dropped after this long without any message.
  final Duration heartbeatTimeout;

  /// How a channel to the host is opened.
  final Connector connector;

  /// Wall-clock time, replaced in tests to act out a sleeping phone.
  final DateTime Function() _wallClock;

  /// Bumped by [startSession], so callbacks from an older session do nothing.
  int _session = 0;

  /// Bumped for every channel, so events from a replaced one do nothing.
  int _channelId = 0;
  MessageChannel? _channel;
  bool _opening = false;
  Timer? _heartbeat;
  int _lastHeardMs = 0;
  DateTime _lastHeardAt;
  int _nextPingId = 0;

  /// The number of the session in progress.
  int get session => _session;

  /// Whether a channel is open.
  bool get hasChannel => _channel != null;

  /// Whether [open] is trying the target's addresses right now.
  bool get isOpening => _opening;

  /// Starts a new connection session and returns its number. Callbacks from
  /// an older session, and an [open] still running, then do nothing.
  int startSession() => ++_session;

  /// Asks the [connector] for a channel and, when one opens, says hello and
  /// starts the heartbeats. [messages] gets the frames from then on.
  Future<void> open(int session, ClientMessages messages) async {
    final target = _host.snapshot.target;
    if (target == null) return;
    _opening = true;
    MessageChannel? channel;
    ConnectFailed? failure;
    try {
      // A session that ends while it is connecting gets no channel.
      channel = await connector.open(target, isCancelled: () => session != _session);
    } on ConnectFailed catch (e) {
      failure = e;
    }
    if (session != _session) {
      channel?.close(CloseCodes.goingAway).ignore();
      return;
    }
    _opening = false;
    final opened = channel;
    if (opened == null) return _onConnectFailed(failure);
    _attach(opened, target.display, messages);
  }

  /// Takes over a channel that just opened: says hello, listens and beats.
  void _attach(MessageChannel channel, String display, ClientMessages messages) {
    final channelId = ++_channelId;
    _channel = channel;
    _host.welcomed = false;
    _lastHeardMs = _host.nowMs;
    _lastHeardAt = _wallClock();
    _host.log('Connected to $display, saying hello');
    channel.incoming.listen(
      (data) {
        if (channelId != _channelId) return;
        _lastHeardMs = _host.nowMs;
        _lastHeardAt = _wallClock();
        messages.onData(data);
      },
      onDone: () => _onChannelDone(channelId, channel.closeCode, channel.closeReason),
      onError: (Object e) => _host.log('Connection error: ${describeError(e)}'),
    );
    send(_host.identity.toHello());
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _beat(channelId));
  }

  /// Sends [message] to the TV, if a channel is open.
  void send(Message message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.send(_codec.encode(message));
    } catch (e) {
      _host.log('Send failed: $e');
    }
  }

  /// Drops the open channel and stops the heartbeats.
  void dropChannel({int? closeCode}) {
    _heartbeat?.cancel();
    _heartbeat = null;
    final channel = _channel;
    _channel = null;
    _host.welcomed = false;
    _channelId++;
    // close() can wait a long time on a dead network, so don't await it.
    channel?.close(closeCode ?? 1000).then((_) {}, onError: (_) {});
  }

  /// Replaces the channel when the app was away for longer than half the
  /// heartbeat timeout, so the phone doesn't wait out the whole timeout.
  /// Returns false when it was away for less, so nothing was done.
  bool replaceQuietChannel(DateTime now) {
    final quiet = now.difference(_lastHeardAt);
    if (quiet < heartbeatTimeout ~/ 2) return false;
    _host.log('Back after ${(quiet.inMilliseconds / 1000).toStringAsFixed(1)} s without the TV, reconnecting now');
    dropChannel(closeCode: CloseCodes.heartbeatTimeout);
    return true;
  }

  /// The connector couldn't open a channel: retry once this phone has paired,
  /// otherwise say that the host can't be reached.
  void _onConnectFailed(ConnectFailed? failure) {
    final detail = failure?.detail;
    final osError = failure?.osErrorCode;
    if (_host.everPaired) {
      _host.scheduleRetry(detail: detail, osErrorCode: osError);
    } else {
      _host.setSnapshot(
        _host.snapshot.copyWith(
          status: ClientStatus.failed,
          problem: ClientProblem.unreachable,
          detail: detail,
          osErrorCode: osError,
        ),
      );
    }
  }

  /// The channel's done callback: the TV closed it or the network dropped.
  void _onChannelDone(int channelId, int? code, String? reason) {
    if (channelId != _channelId) return;
    dropChannel();
    final why = reason == null || reason.isEmpty ? '' : ': $reason';
    _host.log('Connection closed${code == null ? '' : ' (code $code$why)'}');
    switch (code) {
      case CloseCodes.versionMismatch:
        _host.giveUp(ClientProblem.versionMismatch, reason);
      case CloseCodes.replaced:
        _host.giveUp(ClientProblem.replaced, reason);
      case CloseCodes.protocolError:
        _host.giveUp(ClientProblem.protocolError, reason);
      case CloseCodes.pairingTimeout:
        _host.giveUp(ClientProblem.pairingTimeout, reason);
      case CloseCodes.pairingFailed:
        // The pair result already set the status. A new code reconnects.
        if (_host.snapshot.status != ClientStatus.waitingForCode) {
          _host.setSnapshot(
            _host.snapshot.copyWith(status: ClientStatus.waitingForCode, problem: ClientProblem.wrongCode),
          );
        }
      default:
        if (_host.snapshot.status == ClientStatus.waitingForCode) return; // A new code reconnects.
        if (_host.everPaired) {
          _host.scheduleRetry(detail: reason);
        } else {
          _host.giveUp(ClientProblem.connectionLost, reason);
        }
    }
  }

  void _beat(int channelId) {
    if (channelId != _channelId) return;
    final quietMs = _host.nowMs - _lastHeardMs;
    if (quietMs > heartbeatTimeout.inMilliseconds) {
      _host.log('No heartbeat for ${(quietMs / 1000).toStringAsFixed(1)} s, the connection is gone');
      dropChannel(closeCode: CloseCodes.heartbeatTimeout);
      if (_host.everPaired) {
        _host.scheduleRetry(detail: 'No heartbeat');
      } else if (_host.snapshot.status != ClientStatus.waitingForCode) {
        _host.giveUp(ClientProblem.connectionLost, 'No heartbeat');
      }
      return;
    }
    send(PingMessage(id: _nextPingId++, sentAtMs: _host.nowMs));
  }
}
