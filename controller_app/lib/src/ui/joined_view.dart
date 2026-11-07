import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';
import 'waiting_card.dart';

/// The game the host shows this phone (m12 §5), drawn behind this phone's own
/// controls: the frames the client receives, and each frame's sounds played
/// by the party sound player. The waiting card sits over it while the host is
/// away or the link is down (m12-joined-view §0.3).
///
/// Shown only while the host shows a view, and nothing at all while it shows
/// none, so a phone joined to a host that sends it no game keeps its
/// controller screen.
class JoinedView extends ConsumerStatefulWidget {
  const JoinedView({super.key});

  @override
  ConsumerState<JoinedView> createState() => _JoinedViewState();
}

class _JoinedViewState extends ConsumerState<JoinedView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // iOS stops the app's sound while it is hidden, when the phone locks or
    // another app takes it, and the engine doesn't come back by itself: start
    // it again when the app is shown, as the host route does (s5c). Only a
    // game shown here plays through that engine.
    _lifecycle = AppLifecycleListener(onShow: _onShown);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onShown() {
    if (ref.read(viewActiveProvider)) unawaited(ref.read(party.soundPlayerProvider).restart());
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientProvider);
    final stats = client.viewerStats;
    // A client without the view capability is sent no frames and measures
    // nothing (m12 §4), so there is nothing to draw or measure.
    if (stats == null) return const SizedBox.shrink();
    final view = FrameView(
      views: client.view,
      registry: ref.watch(gameRegistryProvider),
      stats: stats,
      // The client's clock is the one frame arrivals are taken on (D3).
      nowMs: () => client.nowMs,
      playerId: ref.watch(identityProvider).controllerId,
      // A tablet has the room for both sides of a phones match (m12-phone-
      // layout §0.6); a phone draws its own.
      wholeMatch: ref.watch(isTabletProvider),
      onSounds: (names) => _play(ref, names),
    );
    final wait = ref.watch(hostWaitProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The view stays mounted while none is on, so it hears the start that
        // turns one on: it draws nothing itself until then. Keeping it off the
        // screen and its ticker quiet is all this does.
        Visibility(visible: ref.watch(viewActiveProvider), maintainState: true, child: view),
        if (wait != null) WaitingCard(wait: wait),
      ],
    );
  }

  /// A frame's sounds, through the player the host screens use (m12 §0.2):
  /// the phone app has no other sound player.
  void _play(WidgetRef ref, List<String> names) {
    final player = ref.read(party.soundPlayerProvider);
    for (final name in names) {
      player.play(name);
    }
  }
}
