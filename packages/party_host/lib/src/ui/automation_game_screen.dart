import 'package:connection/connection.dart' show GamePlayer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../automation/automation_game_start.dart';
import '../keep_awake.dart';
import '../providers.dart';
import '../text/host_text.dart';
import 'game_screen.dart';
import 'puzzle_choice.dart';
import 'puzzle_screen.dart';

/// The round automation starts (M15 a2): the same screens the menus open,
/// reached without a press on the waiting card, so `POST game/start` and the
/// debug start defines run one path.
class AutomationGameScreen extends ConsumerWidget {
  /// [start] says which game and how, as `POST game/start` read it.
  const AutomationGameScreen({super.key, required this.start});

  /// What the round runs.
  final AutomationGameStart start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The home screen kept these going (home_screen.dart): without them the
    // games would be silent and the screen could sleep.
    ref.watch(keepAwakeProvider);
    ref.watch(gameSoundsProvider);
    return switch (start.game) {
      AutomationGameStart.shapeRace => _ShapeRaceRound(start: start),
      _ => const GameScreen(autoStart: true),
    };
  }
}

/// Shape Race's round: the puzzle and teams asked for, or the first Easy
/// puzzle with the first player on the left, as the debug start always was.
class _ShapeRaceRound extends ConsumerWidget {
  const _ShapeRaceRound({required this.start});

  final AutomationGameStart start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(gamePlayersProvider);
    final library = ref.watch(puzzleLibraryProvider).value;
    final level = start.level ?? Level.easy;
    final id = start.puzzleId;
    final puzzle = id == null ? library?.ofLevel(level).firstOrNull : library?.byId(id);
    if (players.isEmpty || puzzle == null) return const _WaitingForController();
    return PuzzleScreen(
      choice: PuzzleChoice(level: puzzle.level, puzzleId: puzzle.id),
      teams: _teams(players),
    );
  }

  /// The sides asked for, by player number; with none asked for, the first
  /// player has the left board and the next the right, as the join screen's
  /// first two seats would.
  Map<String, PuzzleSide> _teams(List<GamePlayer> players) {
    if (start.teams.isEmpty) {
      return {
        for (final (i, p) in players.indexed)
          if (i < 2) p.id: i == 0 ? PuzzleSide.left : PuzzleSide.right,
      };
    }
    return {for (final p in players) p.id: ?start.teams[p.number]};
  }
}

/// What the app shows until a player joins: the arena's own words on a screen
/// of its own (game_screen.dart shows them while nobody is connected).
class _WaitingForController extends StatelessWidget {
  const _WaitingForController();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Scaffold(
      body: Center(
        child: Text(HostText.waitingForController, style: look.type.title.copyWith(color: look.colors.onBackground)),
      ),
    );
  }
}
