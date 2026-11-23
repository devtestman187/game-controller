import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../abandon_signal.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../text/host_text.dart';
import 'game_debug_overlay.dart';
import 'pause_menu.dart';

/// The Bumper Round's field, under [Pausable]: Start pauses, the host's going
/// away and a phone the round waits for hold it, and its 3-2-1 runs on the TV
/// too (design section 8). It stands in its own file so that it and the screen
/// that shows it each stay within one screen of code.
class GameField extends ConsumerWidget {
  const GameField({
    super.key,
    required this.game,
    required this.playing,
    required this.debug,
    required this.hosting,
    required this.keyboard,
    required this.roundTags,
    required this.onEvent,
    required this.onClock,
    required this.onFinished,
    this.showHud = true,
  });

  /// The round's game. A new round is a new field: Play again starts from the
  /// top.
  final ArenaGame game;

  /// Whether the round is on. The results leave the field drawn under their
  /// card, but no round runs there.
  final bool playing;

  /// Whether the debug overlay is shown.
  final bool debug;

  /// Whether the round strip is drawn; the results hide it (M16 bugs3 B-036).
  final bool showHud;

  /// How the round runs (m12 §3): read when the round started.
  final HostingSettings hosting;

  /// Whether the host's own keyboard can add a player, which its note offers.
  final bool keyboard;

  /// The tags only the host knows for the round's summary.
  final List<String> roundTags;

  final void Function(GameEvent event) onEvent;
  final void Function(int timeLeftMs) onClock;
  final void Function(RoundResult result) onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nobody = ref.watch(gamePlayersProvider.select((p) => p.isEmpty));
    // The round's number and count (M16 A2), which only the night knows.
    final numbers = nightRoundNumbers(ref.watch(partyNightProvider));
    return Pausable(
      // Start pauses a round that is on alone: the results are no round (m12
      // §2.10), though the field stays drawn under them (M14 f1).
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
            round: numbers?.round,
            rounds: numbers?.rounds,
            roundTags: roundTags,
            onEvent: onEvent,
            onClock: onClock,
            onFinished: onFinished,
            showHud: showHud,
            paused: paused,
            abandon: ref.read(hostAbandonProvider),
          ),
          if (nobody)
            Positioned(
              left: 0,
              right: 0,
              bottom: arenaNoteBottomPx,
              child: Center(child: ArenaNote(keyboard ? HostText.noControllerKeys : HostText.noController)),
            ),
          if (debug) const Positioned(top: debugOverlayTopPx, left: ToySizes.space12, child: DebugOverlay()),
        ],
      ),
    );
  }
}
