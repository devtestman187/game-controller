import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_game/test_game.dart' show ArenaMode;

import '../arena_settings_provider.dart';
import '../night/night_pick.dart';
import '../night/variant.dart';
import 'game_screen.dart';
import 'games_screen.dart';
import 'puzzle_choice.dart';

/// Opens the game a night's round picked, at the pick's map and tier: Shape Race's puzzle of the tier, or the Bumper
/// Round on the pick's map (the host presses Start on its waiting card, as today). Arena Race has no night round, so
/// nothing opens for it and null comes back. Otherwise the future completes when the game's screen is popped.
Future<void>? openNightPick(BuildContext context, WidgetRef ref, NightPick pick) {
  final variant = pick.variant;
  switch (variant.game) {
    case VariantGame.shapeRace:
      return openShapeRacePuzzle(context, ref, PuzzleChoice(level: variant.tier));
    case VariantGame.bumperRound:
      ref.read(arenaSettingsProvider.notifier)
        ..setMode(ArenaMode.bumper)
        ..setMap(variant.mapId);
      return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GameScreen()));
    case VariantGame.arenaRace:
      return null;
  }
}
