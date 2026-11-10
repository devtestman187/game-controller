import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../night/party_night.dart';
import '../providers.dart';
import '../text/host_text.dart';
import '../text/night_text.dart';
import 'game_picture.dart';
import 'game_screen.dart';
import 'host_button.dart';
import 'host_card_button.dart';
import 'host_card_focus.dart';
import 'host_screen.dart';
import 'join_screen.dart';
import 'lobby_music.dart';
import 'night_scoreboard_screen.dart';
import 'night_start_screen.dart';
import 'puzzle_choice.dart';
import 'puzzle_settings_screen.dart';

part 'games_screen_widgets.dart';

/// The game picker's route name: Quit in the pause menu comes back here.
const gamesRouteName = '/games';

/// The game picker (PRD v2 T11): Shape Race (the puzzle) and the Arena, and
/// the puzzle's playtest settings. Works with the remote.
///
/// Each game is a big card with a drawn picture, its title and a line (M13 3b,
/// mock-up `game-picker`); the settings button and its line are under them.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ToyLookScope.of(context);
    // Watching the night keeps it listening to the roster while the picker is
    // on screen, so a player who leaves then keeps their row.
    final night = ref.watch(partyNightProvider);
    // A touch-first host shows no focus look, so its picker keeps Shape Race's
    // focus as it always had it (the owner's joined-phone case, m12 bug 1107f).
    final touchFirst = ref.watch(hostTouchFirstProvider);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.playTitle,
        body: LobbyHold(
          child: SafeArea(
            child: ListView(
              padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
              children: [
                _GameRow(
                  autofocusShapeRace: touchFirst,
                  autofocusNight: !touchFirst,
                  onShapeRace: () => _open(context, const ShapeRaceScreen()),
                  onArena: () => _open(context, const GameScreen()),
                  onNight: () => _open(
                    context,
                    night != null && night.round > 0 ? const NightScoreboardScreen() : const NightStartScreen(),
                  ),
                ),
                const SizedBox(height: ToySizes.space24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: HostButton(
                    key: const Key('openPuzzleSettings'),
                    label: HostText.puzzleSettings,
                    icon: Icons.tune,
                    onPressed: () => _open(context, const PuzzleSettingsScreen()),
                  ),
                ),
                const SizedBox(height: ToySizes.space8),
                Text(HostText.playtestLine, style: look.type.body.copyWith(color: look.colors.onBackground)),
              ],
            ),
          ),
        ),
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
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: HostScreen(
        title: HostText.shapeRace,
        body: SafeArea(
          child: switch (library) {
            AsyncData(:final value) => ListView(
              padding: hostMenuPadding(ref.watch(hostBarHeightProvider)),
              children: [
                for (final (i, level) in Level.values.indexed)
                  if (value.ofLevel(level) case final puzzles when puzzles.isNotEmpty) ...[
                    _LevelCard(
                      level: level,
                      puzzles: puzzles,
                      autofocus: i == 0,
                      onPlay: (choice) => _play(context, choice),
                    ),
                    const SizedBox(height: ToySizes.space24),
                  ],
              ],
            ),
            AsyncError(:final error) => Center(child: Text(HostText.puzzlesFailed('$error'))),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  /// Players join and pick sides first (M11).
  void _play(BuildContext context, PuzzleChoice choice) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => JoinScreen(choice: choice)));
}
