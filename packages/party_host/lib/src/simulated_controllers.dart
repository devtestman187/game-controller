import 'dart:async';

import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

/// The built-in simulated controllers (M11): each one pairs on its own and
/// presses every button and direction in a loop, so 4-player layouts can be
/// checked with fewer phones.
///
/// Split from the host service, which decides when to add one (up to
/// `HostService.maxSims`) and stops them all when the game ends.
class SimulatedControllers {
  /// [hostId] names each controller, [appVersion] is what it reports as its
  /// app, [log] gets the start and stop lines, [logBuffer] gets what each one
  /// felt (as a phone's log would), and [changed] tells the host service to
  /// emit its state.
  SimulatedControllers({
    required this.hostId,
    required this.appVersion,
    required this.log,
    required this.logBuffer,
    required this.changed,
  });

  /// The host's ID; its first characters name each simulated controller.
  final String hostId;

  /// What each simulated controller reports as its app version.
  final String appVersion;

  /// Where the start and stop lines go.
  final LogSink log;

  /// The host's log, where each simulated controller's haptics go.
  final LogBuffer logBuffer;

  /// Tells the host service that the set of controllers changed.
  final void Function() changed;

  final _sims = <_Sim>[];

  /// Each running simulated controller's latest snapshot, for the state.
  List<ClientSnapshot> get snapshots => [for (final s in _sims) s.client.snapshot];

  /// Adds one that pairs with [pairingCode] on the server at [port].
  void add({required int port, required String pairingCode}) {
    // The first free slot, so the IDs stay the same after a stop.
    var n = 1;
    while (_sims.any((s) => s.slot == n)) {
      n++;
    }
    log('Starting simulated controller $n');
    final client = ControllerClient(
      identity: ControllerIdentity(
        controllerId: 'sim-${hostId.substring(0, 6)}${n == 1 ? '' : '-$n'}',
        name: n == 1 ? 'Simulated controller' : 'Simulated controller $n',
        platform: 'sim',
        appVersion: appVersion,
      ),
      connector: WebSocketConnector(log: logBuffer.sink('sim$n')),
      log: logBuffer.sink('sim$n'),
    );
    final sim = _Sim(n, client);
    sim.sub = client.changes.listen((s) {
      // Once paired, press every button and direction in a loop, so the input
      // display and the games can be checked without a phone.
      if (s.isConnected) sim.demo ??= runDemoInput(client);
      changed();
    });
    // So the log shows what a phone would feel.
    sim.hapticsSub = client.hapticEvents.listen(
      (e) => logBuffer.add('sim$n', 'Felt ${e.event.name} (${(e.intensity * 100).round()}%, ${e.durationMs} ms)'),
    );
    _sims.add(sim);
    client.connect(
      HostAddress(addresses: ['127.0.0.1'], port: port),
      code: pairingCode,
    );
  }

  /// Stops every one; says so in the log once there is any.
  void stopAll() {
    if (_sims.isEmpty) return;
    log('Stopping ${_sims.length} simulated controller${_sims.length == 1 ? '' : 's'}');
    for (final s in _sims) {
      unawaited(s.stop());
    }
    _sims.clear();
  }

  /// Stops every one and waits for it, for the host service's dispose.
  Future<void> dispose() async {
    for (final s in _sims) {
      await s.stop();
    }
    _sims.clear();
  }
}

/// One built-in simulated controller.
class _Sim {
  _Sim(this.slot, this.client);

  final int slot;
  final ControllerClient client;
  StreamSubscription<ClientSnapshot>? sub;
  StreamSubscription<HapticEventMessage>? hapticsSub;
  Timer? demo;

  Future<void> stop() async {
    demo?.cancel();
    await sub?.cancel();
    await hapticsSub?.cancel();
    await client.dispose();
  }
}
