import 'package:flutter_riverpod/misc.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';
import 'host_monitor.dart';
import 'hosting.dart';
import 'hosting_frame_rate.dart';
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
  // The host's away state, so a game pauses while this phone is hidden and a
  // round hidden too long is abandoned (m12 §2.10). Before the first host
  // there is no round to pause.
  party.hostAwayProvider.overrideWith((ref) => ref.watch(hostingProvider)?.away ?? const party.NeverAway()),
  // How this phone runs a game: the rate "Frame rate (test)" saves in Settings,
  // which the host screens read when a round starts (m12 §0.5).
  party.hostingSettingsProvider.overrideWith((ref) => hostingSettingsAt(ref.watch(hostingFrameRateProvider))),
  // The battery and heat a hosted session records (m12 §0.1): this phone's own
  // reading, as the Diagnostics screen shows it.
  party.hostDeviceMonitorProvider.overrideWith((ref) => PhoneHostMonitor(ref.watch(deviceStatusSourceProvider))),
  // This phone's own player in the match it hosts, so the puzzle screen draws
  // its own side of a phones match (m12-phone-layout §3).
  party.ownPlayerIdProvider.overrideWith((ref) => ref.watch(identityProvider).controllerId),
  // A tablet has the room for both sides, so the same screen draws the whole
  // match there (m12-phone-layout §0.6).
  party.wholeMatchProvider.overrideWith((ref) => ref.watch(isTabletProvider)),
];
