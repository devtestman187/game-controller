import 'package:flutter_riverpod/misc.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';
import 'hosting.dart';
import 'phone_host_setup.dart';

/// The `party_host` providers this app supplies, in the app's root scope
/// (m12 §3). The host route, the pause menu's dialog and the games all read
/// this one container, so they can never disagree about the host — and the
/// dialog, which lives above every route, still sees them.
List<Override> phoneHostOverrides({required party.HostDirectories directories}) => [
  // The instance the controller side already loads, so the host's id survives
  // a restart as the TV's does.
  party.prefsProvider.overrideWith((ref) => ref.watch(prefsProvider)),
  // The host's name and kind come from this phone's identity, which is built
  // from the prefs and the display: made on first read, not here.
  party.hostIdentityProvider.overrideWith((ref) => phoneHostIdentity(ref.watch(identityProvider))),
  party.hostDirectoriesProvider.overrideWithValue(directories),
  // The one running service: the app starts it when the player hosts, and the
  // host screens, the pause menu and the own player all use that same one.
  party.hostServiceProvider.overrideWith((ref) => ref.watch(phoneServiceProvider)),
];
