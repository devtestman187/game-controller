import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toy_look/toy_look.dart';

import '../night/night_state.dart';
import '../night/party_night.dart';
import '../providers.dart';
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
/// crown and the night's only button goes back to the games.
///
/// It is opened by the results' Next, which records the round first. Back here
/// asks "End the party night?" before anything is thrown away (design section
/// 4), so a stray B on a phone cannot end a night by mistake.
class NightScoreboardScreen extends ConsumerWidget {
  const NightScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final night = ref.watch(partyNightProvider);
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
                if (!didPop) _askToEnd(context, ref);
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
  Future<void> _askToEnd(BuildContext context, WidgetRef ref) async {
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
    final colors = ToyLookScope.of(context).colors;
    final over = night.isOver;
    return ListView(
      padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: nightScoreCardWidthPx),
            child: ToyCard(
              key: const Key('nightScoreboard'),
              header: over ? NightText.finalScores : NightText.roundOf(night.round, night.rounds),
              headerKey: const Key('nightScoreHeader'),
              headerColor: colors.player(4),
              padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // G2's last round is worth double: the scoreboard says so
                  // before it is played (frame 5).
                  if (!over && night.isNextRoundTheLast) ...[
                    Center(child: NightLastRoundBanner(key: const Key('nightLastRoundBanner'))),
                    const SizedBox(height: ToySizes.space16),
                  ],
                  for (final row in night.rows(ref.watch(gamePlayersProvider))) _ScoreRow(row: row, finalScores: over),
                  const SizedBox(height: ToySizes.space24),
                  if (over)
                    Center(
                      child: HostButton(
                        key: const Key('nightBackToGames'),
                        label: NightText.backToGames,
                        icon: Icons.arrow_back,
                        autofocus: true,
                        onPressed: () => _backToGames(context, ref),
                      ),
                    )
                  else
                    // Job c2's awards' reveal comes after the last round and
                    // before the final scores; the two game buttons stay under
                    // the rows until then.
                    NightGameButtons(
                      autofocus: true,
                      onShapeRace: () => _open(context, const ShapeRaceScreen()),
                      onBumperRound: nightBumperRoundReady ? () => _open(context, const GameScreen()) : null,
                    ),
                ],
              ),
            ),
          ),
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
