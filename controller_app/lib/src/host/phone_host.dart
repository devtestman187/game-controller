import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:shared_preferences/shared_preferences.dart';

import '../host_grace.dart';

/// What a [PhoneHost] is built from: the host's inputs, which the app's root
/// scope supplies to `party_host`, and this phone's own controller identity.
/// [monitor] reads this phone's battery and heat for the session summary: the
/// host service it builds takes it from here, not from the provider graph
/// (m12 §0.1).
typedef PhoneHostInputs = ({
  SharedPreferences prefs,
  LogBuffer log,
  party.HostIdentity identity,
  party.HostDirectories directories,
  party.Advertiser advertiser,
  ControllerIdentity controller,
  party.HostDeviceMonitor monitor,
});

/// Builds the host this app runs; a test overrides it with its own inputs.
typedef PhoneHostBuilder = PhoneHost Function(PhoneHostInputs inputs);

/// The phone as a host (m12 §2.7, D1): the service, the link this phone's own
/// player pairs on, and the presence that pauses a round while the app is
/// hidden. No Riverpod here, so the facts the UI asks ([live], [disposed])
/// are plain fields.
class PhoneHost {
  PhoneHost._(this.service, this.listener, this.client, [this._nowMs]);

  /// Builds the host the phone app runs: the server with the in-process link
  /// for its own player, and the client on the other end of that link.
  /// [nowMs] is the clock the presence measures a hidden period on; a test
  /// moves it, the app leaves it out.
  factory PhoneHost.live(PhoneHostInputs inputs, {int Function()? nowMs}) {
    final listener = InProcessListener();
    final service = party.LiveHostService(
      prefs: inputs.prefs,
      log: inputs.log,
      identity: inputs.identity,
      directories: inputs.directories,
      advertiser: inputs.advertiser,
      inProcess: listener,
      monitor: inputs.monitor,
    );
    final client = ControllerClient(
      identity: inputs.controller,
      connector: InProcessConnector(listener),
      log: inputs.log.sink('own'),
    );
    return PhoneHost._(service, listener, client, nowMs);
  }

  /// The host service: the server, the stats and the games. The live class,
  /// not `HostService`, because only it has `start()` — as the TV app holds
  /// it (`tv_host_setup.dart`).
  final party.LiveHostService service;

  /// The link the own player pairs on: one process, no socket, no port.
  final InProcessListener listener;

  /// This phone's own player, as the host sees it.
  final ControllerClient client;

  /// The navigator the host's games live in. `HostGames` installs it, and
  /// [abandon] comes back to it.
  final gamesKey = GlobalKey<NavigatorState>();

  /// The clock the presence measures a hidden period on; null means the real
  /// one.
  final int Function()? _nowMs;

  party.HostPresence? _presence;
  AppLifecycleListener? _lifecycle;
  final _disposed = Completer<void>();

  /// False from the moment [dispose] runs: a stopped host is never shown.
  bool get live => !_disposed.isCompleted;

  /// Completes when the host has stopped; the host route pops itself then.
  Future<void> get disposed => _disposed.future;

  /// True while the app is hidden (m12 §2.10): the game pauses then, and a
  /// round hidden for longer than [hostGraceS] is abandoned. Before [start]
  /// there is no round to pause, so this never goes away.
  ValueListenable<bool> get away => _presence?.away ?? const party.NeverAway();

  /// Starts the server, then pairs the own player on the link: the listener
  /// has to be running first, since [InProcessListener.connect] throws until
  /// it is.
  Future<void> start() async {
    await service.start();
    if (!live) return;
    final state = service.state;
    client.connect(
      // A placeholder host id: the welcome replaces it before anything is
      // saved, and this client keeps no tokens (m12 §3).
      HostAddress.local(hostId: client.identity.controllerId, name: state.hostName),
      code: state.host.pairingCode,
    );
    final presence = _presence = party.HostPresence(
      host: service,
      onAbandon: abandon,
      nowMs: _nowMs,
      graceS: hostGraceS,
    );
    _lifecycle = AppLifecycleListener(onHide: presence.hidden, onShow: () => unawaited(presence.shown()));
  }

  /// Back to the game picker: the app stayed hidden too long (m12 §2.10).
  void abandon() {
    // The overlay is inside the games navigator, so "back to the picker"
    // finds that one and not the app's.
    final context = gamesKey.currentState?.overlay?.context;
    if (context != null) party.abandonRound(context);
  }

  /// Stops everything and releases the port. Calling it again does nothing.
  Future<void> dispose() async {
    if (_disposed.isCompleted) return;
    _lifecycle?.dispose();
    _presence?.dispose();
    await client.dispose();
    await listener.stop();
    await service.dispose();
    _disposed.complete();
  }
}
