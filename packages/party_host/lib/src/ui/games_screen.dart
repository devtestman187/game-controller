import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../night/party_night.dart';
import '../providers.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import '../text/record_text.dart';
import 'best_times_screen.dart';
import 'game_picture.dart';
import 'game_screen.dart';
import 'host_button.dart';
import 'host_card_button.dart';
import 'host_card_focus.dart';
import 'host_frame.dart';
import 'host_frame_screen.dart';
import 'host_screen.dart';
import 'join_screen.dart';
import 'lobby_music.dart';
import 'night_scoreboard_screen.dart';
import 'night_start_screen.dart';
import 'puzzle_choice.dart';
import 'puzzle_screen.dart';
import 'puzzle_settings_screen.dart';
import 'shop_demo_screen.dart';
import 'solo_skip.dart';

part 'games_screen_widgets.dart';

/// The game picker's route name: Quit in the pause menu comes back here.
const gamesRouteName = '/games';

/// The game picker (PRD v2 T11), drawn in the host's frame since M16 phonehost2
/// S8p (DESIGN section 1, rules 4-6): Shape Race (the puzzle), the Arena and
/// the party night as three cards across the stage, the puzzle's playtest line
/// under them, and the playtest settings as the footer's button. Works with
/// the remote.
///
/// Each game is a card with a drawn picture, its title and a line (M13 3b,
/// mock-up `game-picker`). The cards are the screen's way on and stay in the
/// body: rule 5 asks way-on buttons to live in the footer, and a picker's
/// choice is its content, so the footer keeps the one other way on.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the night keeps it listening to the roster while the picker is
    // on screen, so a player who leaves then keeps their row.
    final night = ref.watch(partyNightProvider);
    // A touch-first host shows no focus look, so its picker keeps Shape Race's
    // focus as it always had it (the owner's joined-phone case, m12 bug 1107f).
    final touchFirst = ref.watch(hostTouchFirstProvider);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostFrameScreen(
        title: HostText.playTitle,
        body: LobbyHold(
          child: _PickerBody(
            autofocusShapeRace: touchFirst,
            autofocusNight: !touchFirst,
            actions: _PickerActions(
              onShapeRace: () => _open(context, const ShapeRaceScreen()),
              onArena: () => _open(context, const GameScreen()),
              onShop: () => _open(context, const ShopDemoScreen()),
              onNight: () => _open(
                context,
                night != null && night.round > 0 ? const NightScoreboardScreen() : const NightStartScreen(),
              ),
            ),
          ),
        ),
        footer: [
          HostButton(
            key: const Key('openPuzzleSettings'),
            label: HostText.puzzleSettings,
            icon: Icons.tune,
            onPressed: () => _open(context, const PuzzleSettingsScreen()),
          ),
        ],
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

/// Shape Race: pick a level and a puzzle, or a random one of the level.
class ShapeRaceScreen extends ConsumerWidget {
  const ShapeRaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(puzzleLibraryProvider);
    // The first level with a puzzle takes the focus as the list opens, so a
    // library without an Easy puzzle still starts on a card.
    final offered = switch (library) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final firstLevel = offered == null
        ? null
        : Level.values.where((level) => offered.ofLevel(level).isNotEmpty).firstOrNull;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.shapeRace,
        body: SafeArea(
          child: switch (library) {
            AsyncData(:final value) => ListView(
              padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
              children: [
                for (final level in Level.values)
                  if (value.ofLevel(level) case final puzzles when puzzles.isNotEmpty) ...[
                    _LevelCard(
                      level: level,
                      puzzles: puzzles,
                      autofocus: level == firstLevel,
                      onPlay: (choice) => _play(context, ref, choice),
                    ),
                    const SizedBox(height: ToySizes.space24),
                  ],
                // The board of kept times lives here, a press off the puzzles
                // it belongs to (M14 f1, r5 finding 4; T15).
                Align(
                  alignment: Alignment.centerLeft,
                  child: HostButton(
                    key: const Key('openBestTimes'),
                    label: RecordText.bestTimesTitle,
                    icon: Icons.emoji_events,
                    onPressed: () => _open(context, const BestTimesScreen()),
                  ),
                ),
              ],
            ),
            AsyncError(:final error) => Center(child: Text(HostText.puzzlesFailed('$error'))),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  /// Players join and pick sides first (M11), unless a night's only player is
  /// alone: then the round starts on a solo board (B-002). A phone that joins
  /// during that round waits for the next one, which gets the join screen again.
  void _play(BuildContext context, WidgetRef ref, PuzzleChoice choice) {
    // The join screen's own-player rule: the host device's player counts only
    // when the host plays on this device.
    final own = ref.read(hostServiceProvider).shareView ? null : ref.read(ownPlayerIdProvider);
    final players = [
      for (final p in ref.read(gamePlayersProvider))
        if (!p.away && p.id != own) p,
    ];
    final solo = skipsLobby(inNight: ref.read(partyNightProvider) != null, players: players.length);
    final screen = solo
        ? PuzzleScreen(choice: choice, teams: {players.single.id: PuzzleSide.left})
        : JoinScreen(choice: choice);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
