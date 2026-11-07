import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart' as party;

import '../providers.dart';

/// The game the host shows this phone (m12 §5), drawn behind this phone's own
/// controls: the frames the client receives, and each frame's sounds played
/// by the party sound player.
///
/// Shown only while the host shows a view, and nothing at all while it shows
/// none, so a phone joined to a host that sends it no game keeps its
/// controller screen.
class JoinedView extends ConsumerWidget {
  const JoinedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onSounds: (names) => _play(ref, names),
    );
    // The view stays mounted while none is on, so it hears the start that
    // turns one on: it draws nothing itself until then. Keeping it off the
    // screen and its ticker quiet is all this does.
    return Visibility(visible: ref.watch(viewActiveProvider), maintainState: true, child: view);
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
