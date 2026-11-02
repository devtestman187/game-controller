import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../providers.dart';
import 'game_screen.dart';
import 'join_screen.dart';
import 'puzzle_screen.dart';
import 'puzzle_settings_screen.dart';
import 'tv_button.dart';

/// The game picker's route name: Quit in the pause menu comes back here.
const gamesRouteName = '/games';

/// The game picker (PRD v2 T11): Shape Race (the puzzle) and the Arena, and
/// the puzzle's playtest settings. Works with the remote.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(title: const Text('Play')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _GameCard(
                    key: const Key('pickShapeRace'),
                    title: 'Shape Race',
                    subtitle: 'Carry, turn and drop the pieces to build the picture.',
                    icon: Icons.extension_outlined,
                    autofocus: true,
                    onPressed: () => _open(context, const ShapeRaceScreen()),
                  ),
                  _GameCard(
                    key: const Key('pickArena'),
                    title: 'Arena',
                    subtitle: 'Race past walls and hazards to the goal.',
                    icon: Icons.videogame_asset_outlined,
                    onPressed: () => _open(context, const GameScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TvButton(
                  key: const Key('openPuzzleSettings'),
                  label: 'Puzzle settings',
                  icon: Icons.tune,
                  onPressed: () => _open(context, const PuzzleSettingsScreen()),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For playtesting: tolerances, speeds and the time limit.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.autofocus = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 380,
      height: 180,
      child: FilledButton.tonal(
        autofocus: autofocus,
        onPressed: onPressed,
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(20)),
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? BorderSide(color: scheme.primary, width: 4) : BorderSide.none,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 64),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: text.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shape Race: pick a level and a puzzle, or a random one of the level.
class ShapeRaceScreen extends ConsumerWidget {
  const ShapeRaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(puzzleLibraryProvider);
    final text = Theme.of(context).textTheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(title: const Text('Shape Race')),
        body: SafeArea(
          child: switch (library) {
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (final (i, level) in Level.values.indexed)
                  if (value.ofLevel(level) case final puzzles when puzzles.isNotEmpty) ...[
                    Text(_levelName(level), style: text.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TvButton(
                          key: Key('random-${level.name}'),
                          label: 'Any ${_levelName(level)} puzzle',
                          icon: Icons.shuffle,
                          autofocus: i == 0,
                          onPressed: () => _play(context, PuzzleChoice(level: level)),
                        ),
                        for (final p in puzzles)
                          TvButton(
                            key: Key('puzzle-${p.id}'),
                            label: p.name,
                            onPressed: () => _play(context, PuzzleChoice(level: level, puzzleId: p.id)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
              ],
            ),
            AsyncError(:final error) => Center(child: Text('The puzzles could not be loaded: $error')),
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

String _levelName(Level level) => switch (level) {
  Level.easy => 'Easy',
  Level.medium => 'Medium',
  Level.hard => 'Hard',
};
