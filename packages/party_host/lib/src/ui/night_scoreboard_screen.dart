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
import 'host_screen.dart';
import 'leave_round.dart';
import 'lobby_music.dart';
import 'night_widgets.dart';
import 'player_badge.dart';

part 'night_scoreboard_widgets.dart';

/// How wide the scoreboard is, in logical pixels: the mock-up's 900, inside a
/// screen of 1280 (frames 4, 5 and 7).
const nightScoreCardWidthPx = 900.0;

/// The scoreboard between a night's rounds, and its final scores (design
/// section 4, mock-up frames 4, 5 and 7): the players in total order with the
/// round's points beside their totals, the banner before the last round and the
/// buttons that pick the next one; after the last round the winner wears a
/// crown, the celebration plays over confetti, and the night's only button goes
/// back to the games.
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
    ref.listen(partyNightProvider, (_, next) {
      if (next?.isOver ?? false) _celebrate();
    });
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: NightText.partyNight,
        body: LobbyHold(
          child: SafeArea(
            child: PopScope(
              // Back asks first: only its Yes clears the night.
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _askToEnd(context);
              },
              // A night that is ending draws nothing for the frame before the
              // picker is back.
              child: night == null ? const SizedBox.shrink() : _Scoreboard(night: night),
            ),
          ),
        ),
      ),
    );
  }

  /// "End the party night?" (design section 4): Yes clears the night and goes
  /// back to the games, No — or a tap outside — leaves it running.
  Future<void> _askToEnd(BuildContext context) async {
    final end = await showDialog<bool>(context: context, builder: (_) => const NightLeaveDialog());
    if (end != true || !context.mounted) return;
    ref.read(partyNightProvider.notifier).end();
    leaveForGamePicker(context);
  }
}

/// The card itself: its header, the banner before the last round, a row for
/// each player, and either the two game buttons or "Back to games".
class _Scoreboard extends ConsumerWidget {
  const _Scoreboard({required this.night});

  final NightState night;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final over = night.isOver;
    return ListView(
      padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
      children: [
        Stack(
          children: [
            // The night is won: confetti round the final scores (frame 7).
            if (over)
              Positioned.fill(
                child: IgnorePointer(child: NightConfetti(key: const Key('nightConfetti'))),
              ),
            Center(
              child: _ScoreCard(
                night: night,
                players: ref.watch(gamePlayersProvider),
                onShapeRace: () => _open(context, const ShapeRaceScreen()),
                onBumperRound: nightBumperRoundReady ? () => _open(context, const GameScreen()) : null,
                onBackToGames: () => _backToGames(context, ref),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// The final scores' one button: the night is over, so it ends without
  /// asking (the scoreboard is the only way on) and the picker is back.
  void _backToGames(BuildContext context, WidgetRef ref) {
    ref.read(partyNightProvider.notifier).end();
    leaveForGamePicker(context);
  }
}
