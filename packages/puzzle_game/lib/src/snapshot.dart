import 'dart:convert';

import 'game.dart';

/// A piece as the view sees it.
final class PieceView {
  const PieceView({required this.x, required this.y, required this.angle, required this.state, this.holder});

  final double x;
  final double y;
  final double angle;
  final PieceState state;

  /// The player number carrying it.
  final int? holder;
}

/// A player's dot as the view sees it.
final class PlayerView {
  const PlayerView({required this.number, required this.x, required this.y, this.held});

  final int number;
  final double x;
  final double y;

  /// The index of the piece it carries.
  final int? held;
}

/// The whole game as one value the view draws from (PRD v2 S8): rules and
/// drawing are separate, so a host can send this to phones that show the
/// game (M12). Versioned, compact JSON: positions to a tenth of a unit,
/// angles to a tenth of a degree.
final class PuzzleSnapshot {
  const PuzzleSnapshot({
    required this.puzzleId,
    required this.timeLeftMs,
    required this.phase,
    required this.pieces,
    required this.players,
    this.warning = false,
    this.readyTargets = const {},
    this.hintTargets = const {},
    this.finishTimeMs,
  });

  static const version = 1;

  /// Snapshots stay under this many bytes, even for 4 players (PRD v2 S8).
  static const maxBytes = 2048;

  /// Which puzzle: the receiver draws its own copy of the puzzle data.
  final String puzzleId;
  final int timeLeftMs;
  final bool warning;
  final PuzzlePhase phase;
  final List<PieceView> pieces;
  final List<PlayerView> players;

  /// Outlines a held piece is close enough to drop into.
  final Set<int> readyTargets;

  /// Outlines glowing as a hint.
  final Set<int> hintTargets;
  final int? finishTimeMs;

  int get placed => pieces.where((p) => p.state == PieceState.locked).length;

  Map<String, Object?> toJson() => {
    'v': version,
    'pz': puzzleId,
    't': timeLeftMs,
    if (warning) 'w': 1,
    'ph': phase.index,
    'pc': [
      for (final p in pieces) [_i(p.x), _i(p.y), _i(p.angle), p.state.index, ?p.holder],
    ],
    'pl': [
      for (final p in players) [p.number, _i(p.x), _i(p.y), ?p.held],
    ],
    if (readyTargets.isNotEmpty) 'rd': readyTargets.toList()..sort(),
    if (hintTargets.isNotEmpty) 'hn': hintTargets.toList()..sort(),
    'ft': ?finishTimeMs,
  };

  String encode() => jsonEncode(toJson());

  static PuzzleSnapshot decode(String text) => fromJson(jsonDecode(text) as Map<String, Object?>);

  static PuzzleSnapshot fromJson(Map<String, Object?> j) {
    if (j['v'] != version) throw FormatException('Puzzle snapshot version ${j['v']}, expected $version');
    double d(Object? v) => (v as num) / 10;
    return PuzzleSnapshot(
      puzzleId: j['pz'] as String,
      timeLeftMs: j['t'] as int,
      warning: j['w'] == 1,
      phase: PuzzlePhase.values[j['ph'] as int],
      pieces: [
        for (final p in (j['pc'] as List).cast<List>())
          PieceView(
            x: d(p[0]),
            y: d(p[1]),
            angle: d(p[2]),
            state: PieceState.values[p[3] as int],
            holder: p.length > 4 ? p[4] as int : null,
          ),
      ],
      players: [
        for (final p in (j['pl'] as List).cast<List>())
          PlayerView(number: p[0] as int, x: d(p[1]), y: d(p[2]), held: p.length > 3 ? p[3] as int : null),
      ],
      readyTargets: {...((j['rd'] as List?) ?? const []).cast<int>()},
      hintTargets: {...((j['hn'] as List?) ?? const []).cast<int>()},
      finishTimeMs: j['ft'] as int?,
    );
  }
}

int _i(double v) => (v * 10).round();
