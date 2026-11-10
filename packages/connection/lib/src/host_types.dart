import 'package:protocol/protocol.dart';

import 'rtt.dart';

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
    this.isLocal = false,
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
    this.character,
  });

  final String controllerId;
  final String name;
  final String platform;
  final String appVersion;

  /// The peer's network address, as the host shows it. Null for a local
  /// player ([isLocal]): the host phone's own player has no address (D1).
  final String? remoteAddress;

  /// True when this player runs in the host's own process: the host phone's
  /// own player (D1). Such a player has no [remoteAddress].
  final bool isLocal;

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

  /// The colour and accessory this player wears (M14 L7): the one it asked
  /// for, or the nearest free one. Null while it isn't connected.
  final PlayerCharacter? character;

  bool supports(String capability) => capabilities.contains(capability);
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
