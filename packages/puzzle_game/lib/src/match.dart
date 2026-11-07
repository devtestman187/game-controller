import 'dart:math';

import 'package:connection/connection.dart';

import 'game.dart';
import 'puzzle.dart';
import 'puzzle_values.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'split_layout.dart';

/// A side of the split screen, chosen on the join screen (PRD v2 T13).
enum PuzzleSide { left, right }

/// Who plays whom, from how many players joined each side (PRD v2 "Modes
/// and layout"). [solo] and [team] play on one board; the others race on
/// the split screen.
enum MatchFormat {
  solo('solo'),
  team('team'),
  oneVsOne('1v1'),
  twoVsOne('2v1'),
  twoVsTwo('2v2');

  const MatchFormat(this.label);

  /// The name in analytics records.
  final String label;

  bool get split => this != solo && this != team;

  /// The format for these sides. A side holds at most two players.
  static MatchFormat of(Map<String, PuzzleSide> teams) {
    final left = teams.values.where((s) => s == PuzzleSide.left).length;
    final right = teams.length - left;
    if (left == 0 || right == 0) return teams.length >= 2 ? team : solo;
    if (left == 1 && right == 1) return oneVsOne;
    if (left == 2 && right == 2) return twoVsTwo;
    return twoVsOne;
  }
}

/// How a match ended.
final class MatchResult {
  const MatchResult({required this.format, required this.sides, this.winner});

  final MatchFormat format;

  /// Each side's result (one entry on one board).
  final Map<PuzzleSide, PuzzleResult> sides;

  /// The side that won the race, or null: a draw, or a one-board game.
  final PuzzleSide? winner;

  /// A race that nobody won: equal pieces at time-up (including none), or
  /// both sides finishing in the same frame.
  bool get draw => format.split && winner == null;

  /// "win", "loss" or "draw" for a side in a race; on one board, "win" for a
  /// finished puzzle and "loss" at time-up.
  String outcomeFor(PuzzleSide side) {
    if (!format.split) return sides[side]?.finished == true ? 'win' : 'loss';
    if (winner == null) return 'draw';
    return winner == side ? 'win' : 'loss';
  }
}

/// One side's game in a match: who plays on it, and their rules.
final class MatchSide {
  MatchSide(this.side, this.game);

  final PuzzleSide side;
  final PuzzleGame game;
}

/// Shape Race for 1 to 4 players (PRD v2 M11): one board for a solo player
/// or a team of two, or two boards side by side, each with its own tray,
/// against one clock. On phones ([LayoutTarget.phones]) each side plays in the
/// same on-a-phone world, tray on top, and a solo player has the one side
/// (m12 §0.4–0.5). Players play only on their own side, so they stay in their
/// own half. The first side to finish wins; at time-up the side with more
/// pieces placed wins, and equal counts are a draw. Players who didn't join a
/// side just watch.
class PuzzleMatch {
  PuzzleMatch(
    this.puzzle, {
    required Map<String, PuzzleSide> teams,
    PuzzleSettings settings = PuzzleSettings.defaults,
    required Random random,
    this.target = LayoutTarget.screen,
  }) : teams = Map.unmodifiable(teams),
       format = MatchFormat.of(teams),
       seed = random.nextInt(1 << 32) {
    // Both sides start with the same tray, mirrored, so the race is fair: the
    // layout picks the angles and sizes the tray for them. A one-board screen
    // match has no layout; one on phones shows the layout's left world.
    final layout = format.split || target == LayoutTarget.phones ? SplitLayout.of(puzzle, seed, target: target) : null;
    sides = switch (layout) {
      null => [
        MatchSide(
          teams.values.firstOrNull ?? PuzzleSide.left,
          PuzzleGame(puzzle, settings: settings, random: Random(seed)),
        ),
      ],
      final SplitLayout l when format.split => [
        MatchSide(
          PuzzleSide.left,
          PuzzleGame(puzzle, settings: settings, random: Random(seed), field: l.left, angles: l.angles),
        ),
        MatchSide(
          PuzzleSide.right,
          PuzzleGame(puzzle, settings: settings, random: Random(seed), field: l.right, angles: l.angles),
        ),
      ],
      final SplitLayout l => [
        MatchSide(
          teams.values.firstOrNull ?? PuzzleSide.left,
          PuzzleGame(puzzle, settings: settings, random: Random(seed), field: l.left, angles: l.angles),
        ),
      ],
    };
  }

  final Puzzle puzzle;

  /// The world the sides are laid out in (m12 §0.4), from the view's setup:
  /// the split screen, or one side per phone.
  final LayoutTarget target;

  /// The seed the trays were laid out from, kept so a snapshot can rebuild
  /// the same layout.
  final int seed;

  /// Each player's side.
  final Map<String, PuzzleSide> teams;
  final MatchFormat format;

  /// One side, or left then right.
  late final List<MatchSide> sides;

  MatchResult? _result;

  /// Null until the match is over.
  MatchResult? get result => _result;

  set settings(PuzzleSettings s) {
    for (final side in sides) {
      side.game.settings = s;
    }
  }

  /// The game a side plays (on one board, the only one).
  PuzzleGame gameOf(PuzzleSide side) => (sides.where((s) => s.side == side).firstOrNull ?? sides.first).game;

  /// The side a player plays on, or null for someone watching.
  PuzzleSide? sideOf(String playerId) => teams[playerId];

  /// The game a player plays in, or null for someone watching.
  PuzzleGame? gameFor(String playerId) => teams.containsKey(playerId) ? gameOf(teams[playerId]!) : null;

  /// Advances every side by [dt] with its players' controls (players who
  /// aren't in [inputs] are away), and decides the winner once a side
  /// finishes or time runs out.
  List<({PuzzleSide side, PuzzleEvent event})> update(
    double dt,
    Map<String, GamepadState> inputs, {
    Map<String, int> numbers = const {},
  }) {
    final events = <({PuzzleSide side, PuzzleEvent event})>[];
    for (final s in sides) {
      final own = {
        for (final MapEntry(:key, :value) in inputs.entries)
          if (teams.containsKey(key) && (!format.split || teams[key] == s.side)) key: value,
      };
      for (final e in s.game.update(dt, own, numbers: numbers)) {
        events.add((side: s.side, event: e));
      }
    }
    if (_result == null) _decide();
    return events;
  }

  void _decide() {
    final games = [for (final s in sides) s.game];
    if (games.every((g) => g.phase == PuzzlePhase.playing)) return;
    PuzzleSide? winner;
    if (format.split) {
      final finished = [
        for (final s in sides)
          if (s.game.phase == PuzzlePhase.finished) s.side,
      ];
      if (finished.isNotEmpty) {
        // The first to finish wins; both in the same frame is a draw.
        if (finished.length == 1) winner = finished.single;
        for (final g in games) {
          g.stop();
        }
      } else {
        // Time's up (both clocks run together): more pieces placed wins.
        for (final g in games) {
          g.stop();
        }
        final left = gameOf(PuzzleSide.left).placed;
        final right = gameOf(PuzzleSide.right).placed;
        if (left != right) winner = left > right ? PuzzleSide.left : PuzzleSide.right;
      }
    }
    _result = MatchResult(format: format, sides: {for (final s in sides) s.side: s.game.result!}, winner: winner);
  }

  /// Everything the view needs (S8). The seed travels whenever the sides came
  /// from a layout, so a viewer can rebuild it: a race, and a one-board phones
  /// match, whose side is the layout's left world.
  MatchSnapshot snapshot() => MatchSnapshot(
    boards: [for (final s in sides) s.game.snapshot()],
    seed: format.split || target == LayoutTarget.phones ? seed : null,
  );
}
