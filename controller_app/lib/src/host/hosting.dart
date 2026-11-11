import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'phone_host.dart';

/// The host this app runs, or null before the first "Host a game" (m12 §3).
final hostingProvider = NotifierProvider<HostingNotifier, PhoneHost?>(HostingNotifier.new);

/// Starts and stops the app's host.
class HostingNotifier extends Notifier<PhoneHost?> {
  @override
  PhoneHost? build() => null;

  /// Starts a host and returns it: the caller shows it in the host route.
  /// [playsHere] is the caller's choice, known before the host is built: this
  /// phone's own player plays the game it hosts, or the phone is only the
  /// screen. Passing it here means a phone that shows the game never pairs a
  /// player and then drops it (m12 bug 1108a rule D).
  PhoneHost start({required bool playsHere}) {
    final start = ref.read(party.hostStartLogProvider);
    final host = ref.read(phoneHostBuilderProvider)(_inputs(ref), playsHere: playsHere);
    start.step(party.HostStartStep.hostBuilt);
    // Whether this phone draws the game itself, before the host starts: the
    // screens read it as soon as they open, and a phone that shows the game is
    // the screen and pairs nobody (m12 bug 1108a rules A, D).
    host.service.shareView = playsHere;
    // The screens' client, before the route opens: this phone's own player
    // plays the game it hosts (m12 §3). A phone that shows the game has none,
    // so the bar falls back to what it shows without a player (rule B).
    final client = host.client;
    if (client != null) ref.read(ownClientProvider.notifier).set(client);
    // Over a game the controls take the saved opacity and the bar shows the
    // ping instead of the status panel (m12 §2.7). Set here, not by the
    // route: Riverpod refuses a provider changed from a widget's dispose.
    ref.read(gameShownProvider.notifier).set(true);
    unawaited(host.start());
    // Searching for a TV is pointless while this phone is the host, and
    // Bonsoir would browse for the app's life (m12 §3).
    unawaited(ref.read(discoveryProvider).stop());
    state = host;
    return host;
  }

  /// Stops the host; the host route pops itself when it is done. Calling it
  /// again does nothing. The stopped host stays in the state on purpose: the
  /// party host providers below still watch its service, and a state that
  /// went back to null would leave them with nothing to read (m12 §3). The
  /// screens ask [PhoneHost.live].
  Future<void> stop() async {
    final host = state;
    if (host == null || !host.live) return;
    // Back to the TV client before the host lets its own client go.
    ref.read(ownClientProvider.notifier).clear();
    ref.read(gameShownProvider.notifier).set(false);
    await host.dispose();
    // Searching again: the player lands on the Connect screen, and a phone
    // that hosts is one that found no TV (m12 §3).
    unawaited(ref.read(discoveryProvider).restart());
  }
}

/// This app's inputs for a host, from the providers its root scope has.
PhoneHostInputs _inputs(Ref ref) => (
  prefs: ref.read(party.prefsProvider),
  log: ref.read(party.logProvider),
  identity: ref.read(party.hostIdentityProvider),
  directories: ref.read(party.hostDirectoriesProvider),
  advertiser: ref.read(party.advertiserProvider),
  controller: ownPlayerIdentity(ref.read(identityProvider)),
  monitor: ref.read(party.hostDeviceMonitorProvider),
  // The store build's Firestore uploader, or null where the build has none
  // (M14 r5 8): the sessions are kept on the phone either way.
  uploader: ref.read(party.sessionUploaderProvider),
  start: ref.read(party.hostStartLogProvider),
);

/// The identity this phone's own player pairs with: the phone's, without
/// [Capability.view] (m12 §0.1). The host phone draws its own game in
/// `host/host_games.dart`, so the server must not send it frames, and a server
/// rule on `isLocal` would also have caught the connection tests' in-process
/// viewers.
ControllerIdentity ownPlayerIdentity(ControllerIdentity identity) => identity.copyWith(
  capabilities: [
    for (final capability in identity.capabilities)
      if (capability != Capability.view) capability,
  ],
);

/// Builds the host this app runs (the seam tests use, as the TV's
/// `localPlayerSourceProvider` is).
final phoneHostBuilderProvider = Provider<PhoneHostBuilder>((ref) => PhoneHost.live);

/// The running host's service, which `party.hostServiceProvider` is overridden
/// with. It throws before the first "Host a game": nothing that is always on
/// screen reads it (the host chip returns early, m12 §3).
final phoneServiceProvider = Provider<party.HostService>((ref) {
  final host = ref.watch(hostingProvider);
  if (host == null) throw StateError('No host is running in this app');
  return host.service;
});
