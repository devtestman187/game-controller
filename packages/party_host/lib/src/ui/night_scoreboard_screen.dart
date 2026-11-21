import 'dart:async';
import 'dart:math' as math;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:test_game/test_game.dart' show roboNumberFor, roboPlayerId;
import 'package:toy_look/toy_look.dart';

import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
import '../text/arena_text.dart';
import '../text/night_text.dart';
import 'game_screen.dart';
import 'games_screen.dart';
import 'host_button.dart';
import 'host_frame_screen.dart';
import 'leave_round.dart';
import 'lobby_music.dart';
import 'night_footer_buttons.dart';
import 'night_widgets.dart';
import 'round_segment.dart';
import 'score_row.dart';

part 'night_scoreboard_widgets.dart';

/// The scoreboard between a night's rounds, and its final scores (design
/// section 4, mock-up frames 4, 5 and 7): the players in total order with the
/// round's points beside their totals, the banner before the last round and the
/// buttons that pick the next one; after the last round the winner wears a
/// crown, the celebration plays over confetti, and the night's only button goes
/// back to the games.
///
/// The screen is a [HostFrameScreen] (DESIGN section 1, rule 5): the title, the
/// round chip and the double-points banner in the 64 px header, one
/// [ScoreRow] per player in the body, and the way on in the 84 px footer —
/// [NightFooterButtons] between rounds, "Back to games" on the final scores.
///
/// It is opened by the results' Next, which records the round first. Back here
/// asks "End the party night?" before anything is thrown away (design section
/// 4), so a stray B on a phone cannot end a night by mistake.
class NightScoreboardScreen extends ConsumerStatefulWidget {
  const NightScoreboardScreen({super.key});

  @override
  ConsumerState<NightScoreboardScreen> createState() => _NightScoreboardScreenState();
}

class _NightScoreboardScreenState extends ConsumerState<NightScoreboardScreen> {
  /// Whether the final scores' celebration has played: once a screen, not on
  /// every rebuild.
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    // The reveal hands over with the night already over.
    if (ref.read(partyNightProvider)?.isOver ?? false) _celebrate();
  }

  /// The night is won: the celebration plays (design section 6, frame 7).
  void _celebrate() {
    if (_celebrated) return;
    _celebrated = true;
    ref.read(soundPlayerProvider).play(SoundKey.celebration.eventName);
  }

  @override
  Widget build(BuildContext context) {
    final night = ref.watch(partyNightProvider);
    final over = night?.isOver ?? false;
    ref.listen(partyNightProvider, (_, next) {
      if (next?.isOver ?? false) _celebrate();
    });
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostFrameScreen(
        title: NightText.partyNight,
        trailing: night == null ? null : _ScoreChip(night: night),
        body: LobbyHold(
          child: PopScope(
            // Back asks first: only its Yes clears the night.
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_askToEnd(context));
            },
            // A night that is ending draws nothing for the frame before the
            // picker is back.
            child: night == null
                ? const SizedBox.shrink()
                : _Scoreboard(night: night, players: ref.watch(gamePlayersProvider)),
          ),
        ),
        footer: night == null
            ? const []
            : over
            ? [_backToGames()]
            : [_nextRound()],
      ),
    );
  }

  /// The night's way on between rounds (design section 4): the same pair the
  /// start card offers, so the two screens cannot drift apart.
  Widget _nextRound() => NightFooterButtons(
    autofocus: true,
    onShapeRace: () => _open(const ShapeRaceScreen()),
    onBumperRound: nightBumperRoundReady ? () => _open(const GameScreen()) : null,
  );

  /// The final scores' one button: the night is over, so it ends without
  /// asking (the scoreboard is the only way on) and the picker is back.
  Widget _backToGames() => HostButton(
    key: const Key('nightBackToGames'),
    label: NightText.backToGames,
    icon: Icons.arrow_back,
    autofocus: true,
    onPressed: () {
      ref.read(partyNightProvider.notifier).end();
      leaveForGamePicker(context);
    },
  );

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// "End the party night?" (design section 4): Yes clears the night and goes
  /// back to the games, No — or a tap outside — leaves it running.
  Future<void> _askToEnd(BuildContext context) async {
    final end = await showDialog<bool>(context: context, builder: (_) => const NightLeaveDialog());
    if (end != true || !context.mounted) return;
    ref.read(partyNightProvider.notifier).end();
    leaveForGamePicker(context);
  }
}
