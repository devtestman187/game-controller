import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';

import '../advertiser.dart';
import '../host_view_state.dart';

/// A host state like a running TV's: one connected iPhone with ping, input
/// delay and a pressed D-pad, one Pixel still pairing, one address, and
/// advertising working.
HostViewState sampleState() => HostViewState(
  hostName: 'Android TV',
  host: HostSnapshot(
    running: true,
    port: 45780,
    pairingCode: '0427',
    controllers: [
      ControllerInfo(
        controllerId: 'p1',
        name: 'iPhone 3F1C',
        platform: 'ios',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.20',
        state: ControllerState.connected,
        since: DateTime(2026),
        rttMs: 12,
        rttStats: const RttSummary(minMs: 8, avgMs: 20, maxMs: 140, samples: 30, p95Ms: 60),
        input: InputStateMessage(seq: 3, buttons: {ControllerButton.a}, dx: 1),
        player: 1,
        inputLatency: const RttSummary(minMs: 3, avgMs: 9, maxMs: 41, samples: 900, p95Ms: 18),
        inputLatencySession: const RttSummary(minMs: 2, avgMs: 10, maxMs: 80, samples: 5400),
        latencyErrorMs: 4,
      ),
      ControllerInfo(
        controllerId: 'p2',
        name: 'Pixel',
        platform: 'android',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.21',
        state: ControllerState.pairing,
        since: DateTime(2026),
      ),
    ],
  ),
  addresses: const [LocalAddress('192.168.1.50', 'wlan0')],
  advertise: AdvertiseState.advertising,
  advertisedName: 'Thumb Party TV (Android TV)',
);

/// A connected phone, like the sample state's first controller, without
/// input.
ControllerInfo phoneInfo(String id, int player, {String platform = 'android'}) => ControllerInfo(
  controllerId: id,
  name: 'Phone $player',
  platform: platform,
  appVersion: '0.1.0',
  remoteAddress: '192.168.1.2$player',
  state: ControllerState.connected,
  since: DateTime(2026),
  player: player,
);

/// [s] with [c] added to its controllers, as the host reports a new phone.
HostViewState withController(HostViewState s, ControllerInfo c) => HostViewState(
  hostName: s.hostName,
  host: HostSnapshot(
    running: s.host.running,
    port: s.host.port,
    pairingCode: s.host.pairingCode,
    controllers: [...s.host.controllers, c],
  ),
  addresses: s.addresses,
  advertise: s.advertise,
  advertisedName: s.advertisedName,
  advertiseError: s.advertiseError,
  serverError: s.serverError,
  sims: s.sims,
);

/// A small saved session: one phone, D-pad then sticks, with a rating.
Map<String, Object?> sampleSession() {
  final c = SessionCollector(
    id: 'abcd1234',
    hostType: HostType.androidTv,
    hostApp: '0.9.0',
    startedAt: DateTime.utc(2026, 10, 31),
    startMs: 0,
  );
  c.joined(
    'p1',
    number: 1,
    atMs: 0,
    platform: 'ios',
    device: const DeviceInfo(kind: DeviceInfo.phone),
  );
  c.metrics(
    'p1',
    MetricsMessage(
      segment: 's1',
      index: 0,
      mode: 'dpad',
      durationMs: 60000,
      ended: true,
      data: {
        'start': 0,
        'presses': {'a': 40, 'b': 2},
        'empty': {'5,1': 3},
        'near': {'b': 4},
        'slide': {'a': 1},
      },
    ),
  );
  c.metrics(
    'p1',
    MetricsMessage(
      segment: 's2',
      index: 0,
      mode: 'sticks',
      durationMs: 30000,
      data: {
        'start': 60000,
        'presses': {'ls': 5},
      },
    ),
  );
  for (final ms in [8, 9, 10]) {
    c.stage('p1', LatencyStage.sentToReceived, ms);
  }
  c.mode('p1', 'sticks');
  c.rating(
    'p1',
    RatingMessage(id: 'r', face: RatingFace.good),
    game: 'arena',
  );
  return c.summary(90000);
}
