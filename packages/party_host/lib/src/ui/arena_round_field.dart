import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../abandon_signal.dart';
import '../providers.dart';
import '../text/host_text.dart';
import 'game_debug_overlay.dart';
import 'pause_menu.dart';

/// A round's field under [Pausable]: Start pauses, the host's going away and
/// a phone the round waits for hold it, and its 3-2-1 runs on the TV too
/// (design section 8).
///
/// It moved out of the arena screen in M15 a2, so that screen keeps the room
/// the automation interface's own start needed.
class ArenaRoundField extends ConsumerWidget {
  const ArenaRoundField({
    super.key,
    required this.game,
    required this.playing,
    required this.debug,
    required this.hosting,
    required this.roundTags,
    required this.keyboardAvailable,
    required this.onEvent,
    required this.onClock,
    required this.onFinished,
  });

  /// The round's game; a new one is a new field, so Play again starts it from
  /// the top.
  final ArenaGame game;

  /// Whether the round is on: the results are no round (m12 §2.10), though
  /// their card stands over the field (M14 f1).
  final bool playing;

  /// Whether the debug overlay is on (a key on the remote or a keyboard).
  final bool debug;

  /// How this round runs, read when it started (m12 §3).
  final HostingSettings hosting;

  /// The tags only the host knows for the round's summary (M14).
  final List<String> roundTags;

  /// Whether the host has a keyboard to offer when no phone is in the round.
  final bool keyboardAvailable;

  final void Function(GameEvent) onEvent;
  final void Function(int) onClock;
  final void Function(RoundResult) onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nobody = ref.watch(gamePlayersProvider.select((p) => p.isEmpty));
    return Pausable(
      enabled: playing,
      beat: Pausable.ready,
      builder: (context, paused) => Stack(
        children: [
          ArenaView(
            key: ObjectKey(game),
            game: game,
            host: ref.read(gameHostProvider),
            settings: hosting,
            roboLevel: ref.watch(arenaSettingsProvider.select((s) => s.roboLevel)),
            roundTags: roundTags,
            onEvent: onEvent,
            onClock: onClock,
            onFinished: onFinished,
            paused: paused,
            abandon: ref.read(hostAbandonProvider),
          ),
          if (nobody)
            Positioned(
              left: 0,
              right: 0,
              bottom: arenaNoteBottomPx,
              child: Center(child: ArenaNote(keyboardAvailable ? HostText.noControllerKeys : HostText.noController)),
            ),
          if (debug) const Positioned(top: debugOverlayTopPx, left: ToySizes.space12, child: DebugOverlay()),
        ],
      ),
    );
  }
}
