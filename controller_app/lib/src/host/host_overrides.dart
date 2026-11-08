import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:party_host/party_host.dart' as party;

import '../gyro.dart';
import '../providers.dart';
import '../ui/joined_view.dart';
import '../ui/top_bar_metrics.dart';
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
  // A round on this phone starts with the "Get ready" beat, so thumbs find the
  // pad before the clock runs (m12-host-touch rule 3). The TV asks for none
  // (rule 6).
  party.readyCountdownProvider.overrideWithValue(party.Pausable.ready),
  // The battery and heat a hosted session records (m12 §0.1): this phone's own
  // reading, as the Diagnostics screen shows it.
  party.hostDeviceMonitorProvider.overrideWith((ref) => PhoneHostMonitor(ref.watch(deviceStatusSourceProvider))),
  // A phone that hosts keeps its screen on for the whole time it hosts, in both
  // modes (m12 bug 1108a fix2 Q2): one that dims or locks while it waits for
  // players pauses and then abandons the round. This phone draws the game it
  // hosts for exactly that time, so that is what it turns the seam on with; the
  // TV keeps its rule, on while a controller is connected.
  party.keepAwakeWhileHostingProvider.overrideWith((ref) => ref.watch(gameShownProvider)),
  // This phone's own player in the match it hosts, so the puzzle screen draws
  // its own side of a phones match (m12-phone-layout §3). "Show on this device"
  // has no own player: the phone is the screen, and the whole match is drawn
  // there (m12 bug 1108a rule A).
  party.ownPlayerIdProvider.overrideWith((ref) {
    final host = ref.watch(hostingProvider);
    return host == null || !host.playsHere ? null : ref.watch(identityProvider).controllerId;
  }),
  // A tablet has the room for both sides, so the same screen draws the whole
  // match there (m12-phone-layout §0.6).
  party.wholeMatchProvider.overrideWith((ref) => ref.watch(isTabletProvider)),
  // This phone is worked by touch (m12 bug 1107f rules A and B): its host's
  // screens show no focus look until a joined phone's pad moves the focus, and
  // a thumb hides it again. The TV and the Windows app keep the default, where
  // the focus look shows from the start.
  party.hostTouchFirstProvider.overrideWithValue(true),
  // The bar this app draws over the host's screens is this high, so a host
  // screen's title bar sits below it, never under it (rule C). The TV has no
  // bar there.
  party.hostBarHeightProvider.overrideWithValue(topBarHeightPx),
  // The pad this phone draws over the game it hosts, and its density, so a
  // round it plays keeps the other side's mirror clear of the thumb, as a
  // joined phone's game does (m12-opponent-mirror rules 3, 7 and 8). "Show on
  // this device" shares no view and draws no pad, so it passes none.
  party.hostPadProvider.overrideWith((ref) {
    final mm = ref.watch(pxPerMmProvider);
    final host = ref.watch(hostingProvider);
    if (host == null || !host.service.shareView) return (pxPerMm: mm, rects: (Size box) => const <Rect>[]);
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    final sticks = ref.watch(stickSettingsProvider);
    return (pxPerMm: mm, rects: (Size box) => leftPadRects(box, mode: mode, mm: mm, sticks: sticks));
  }),
];
