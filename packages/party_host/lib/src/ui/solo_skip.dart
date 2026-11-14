import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arena_settings_provider.dart';

/// Whether the screens before a round are skipped (M14 bugs B-002): a night
/// with exactly one player has nobody to wait for and no sides to pick, so the
/// round starts at once instead of opening Shape Race's join screen or the
/// Arena's waiting card.
///
/// [inNight] is whether a party night is running; [players] counts the players
/// who can play this round: the phones that aren't away, and the host's own
/// player only when the host plays on this device, as the join screen counts
/// them (its own player).
///
/// The Arena OUTSIDE a night keeps its waiting card even with one player: its
/// map choice matters there. When the Arena gets more maps and a solo player
/// should pick one, this is the one place to change.
bool skipsLobby({required bool inNight, required int players}) => inNight && players == 1;

/// A night's one-player round in the Arena (B-002), in place of its waiting
/// card: it draws nothing and calls [onStart] as soon as the map library is in,
/// as the card's Start would on its Surprise-me map (a map the night hasn't
/// used). The maps are what a round waits for: without them Surprise me would
/// fall back to the playroom. If they don't load, the playroom stands in, as it
/// does for the card's Start.
///
/// The start comes after this frame, never during it: the maps are often in
/// already, and a round cannot begin inside a build.
class SoloRoundStart extends ConsumerStatefulWidget {
  const SoloRoundStart({super.key, required this.onStart});

  /// Starts the round on this map, or on Surprise me's when null.
  final void Function(String? mapId) onStart;

  @override
  ConsumerState<SoloRoundStart> createState() => _SoloRoundStartState();
}

class _SoloRoundStartState extends ConsumerState<SoloRoundStart> {
  /// Whether the start is on its way, so a rebuild asks only once.
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    if (!_asked && !ref.watch(arenaMapLibraryProvider).isLoading) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStart(null);
      });
    }
    return const SizedBox.shrink();
  }
}
