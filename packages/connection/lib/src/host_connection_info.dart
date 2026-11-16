part of 'host_connection.dart';

/// How the host UI and its log show one connection ([HostConnection.toInfo]).
///
/// Part of `host_connection.dart`, so it reads the connection's own fields.
ControllerInfo _infoOf(HostConnection s, int now) => ControllerInfo(
  controllerId: s.hello!.controllerId,
  name: s.hello!.name,
  platform: s.hello!.platform,
  appVersion: s.hello!.appVersion,
  remoteAddress: s.remoteAddress,
  isLocal: s._channel.isLocal,
  state: s.paired ? ControllerState.connected : ControllerState.pairing,
  since: s.since,
  rttMs: s.rttMs,
  rttStats: s.rttWindow.summary(now),
  input: s.paired ? s.input : null,
  player: s.paired ? s.player : null,
  inputLatency: s.latency.summary(now),
  inputLatencySession: switch (s.latency.session) {
    final t when t.count > 0 => RttSummary(minMs: t.minMs!, avgMs: t.avgMs!, maxMs: t.maxMs!, samples: t.count),
    _ => null,
  },
  latencyErrorMs: s.latency.uncertaintyMs,
  capabilities: s.hello!.capabilities,
  device: s.hello!.device,
  role: s.hello!.role,
  inputAtMs: s.paired ? s.inputAtMs : null,
  character: s.paired ? s.character : null,
);

/// The latency log line for [s] ([HostConnection.latencyLine]), or null before
/// the first ping came back.
String? _latencyLineOf(HostConnection s, int now) {
  final rtt = s.rttWindow.summary(now);
  if (rtt == null) return null;
  final latency = s.latency.summary(now);
  final error = s.latency.uncertaintyMs;
  final inputText = latency == null
      ? 'input delay not measured${s.latency.offsetMs == null ? ' (phone sends no clock)' : ''}'
      : 'input delay ~ avg ${latency.avgMs} · p95 ${latency.p95Ms} · max ${latency.maxMs} ms (± $error ms, '
            '${latency.samples} states)';
  return 'Latency ${s.who}: ping $rtt, $inputText';
}
