import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';
import 'phone_host.dart';

/// The host this app runs, or null before the first "Host a game" (m12 §3).
final hostingProvider = NotifierProvider<HostingNotifier, PhoneHost?>(HostingNotifier.new);

/// Starts the app's host, and (in m12's next step) stops it again.
class HostingNotifier extends Notifier<PhoneHost?> {
  @override
  PhoneHost? build() => null;

  /// Starts a host and returns it: the caller shows it in the host route.
  PhoneHost start() {
    final host = ref.read(phoneHostBuilderProvider)(_inputs(ref));
    unawaited(host.start());
    // Searching for a TV is pointless while this phone is the host, and
    // Bonsoir would browse for the app's life (m12 §3).
    unawaited(ref.read(discoveryProvider).stop());
    state = host;
    return host;
  }
}

/// This app's inputs for a host, from the providers its root scope has.
PhoneHostInputs _inputs(Ref ref) => (
  prefs: ref.read(party.prefsProvider),
  log: ref.read(party.logProvider),
  identity: ref.read(party.hostIdentityProvider),
  directories: ref.read(party.hostDirectoriesProvider),
  advertiser: ref.read(party.advertiserProvider),
  controller: ref.read(identityProvider),
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
