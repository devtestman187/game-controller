import 'dart:convert';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'points.dart';
import 'puzzle_values.dart';

/// A piece as the view sees it.
final class PieceView {
  const PieceView({
    required this.x,
    required this.y,
    required this.angle,
    required this.state,
    this.holders = const [],
    this.calling = false,
  });

  final double x;
  final double y;
  final double angle;
  final PieceState state;

  /// The player numbers carrying it: one, or two teammates with a big piece.
  final List<int> holders;

  /// A big piece carried alone, calling the free teammate (the edge flash).
  final bool calling;

  /// The first player carrying it.
  int? get holder => holders.firstOrNull;
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
final class PuzzleSnapshot implements GameSnapshot {
  PuzzleSnapshot({
    required this.puzzleId,
    required this.timeLeftMs,
    required this.phase,
    required this.pieces,
    required this.players,
    this.warning = false,
    this.readyTargets = const {},
    this.hintTargets = const {},
    this.finishTimeMs,
    this.points = 0,
    this.night = false,
    List<PuzzlePopup> popups = const [],
    List<int>? order,
  }) : order = List.unmodifiable(order ?? [for (var i = 0; i < pieces.length; i++) i]),
       popups = List.unmodifiable(popups);

  static const version = 2;

  /// Snapshots stay under this many bytes, even for 4 players (PRD v2 S8).
  static const maxBytes = 2048;

  /// Which puzzle: the receiver draws its own copy of the puzzle data.
  final String puzzleId;
  final int timeLeftMs;
  final bool warning;
  final PuzzlePhase phase;
  final List<PieceView> pieces;
  final List<PlayerView> players;

  /// The piece indices from the lowest layer to the highest: the order the
  /// loose pieces are drawn in, so a piece on top hides the one under it.
  final List<int> order;

  /// Outlines a held piece is close enough to drop into.
  final Set<int> readyTargets;

  /// Outlines glowing as a hint.
  final Set<int> hintTargets;
  final int? finishTimeMs;

  /// The points the side playing this board has earned (M14 a1), scaled for
  /// the night.
  final int points;

  /// This is a party night's round (party-night N4): the pop-ups and the
  /// points are drawn. Outside a night they are counted but not drawn.
  final bool night;

  /// The pop-ups alive on this board, oldest first, each with its age in ms so
  /// a phone that joins mid-round draws the same rise and fade.
  final List<PuzzlePopup> popups;

  int get placed => pieces.where((p) => p.state == PieceState.locked).length;

  /// 0, 1, 2, …: the order nothing moved yet leaves them in.
  bool get _identityOrder {
    for (var i = 0; i < order.length; i++) {
      if (order[i] != i) return false;
    }
    return true;
  }

  @override
  Map<String, Object?> toJson() => {
    'v': version,
    'pz': puzzleId,
    't': timeLeftMs,
    if (warning) 'w': 1,
    'ph': phase.index,
    if (!_identityOrder) 'o': order,
    'pc': [
      for (final p in pieces) [_i(p.x), _i(p.y), _i(p.angle), p.state.index, ...p.holders],
    ],
    if (pieces.any((p) => p.calling))
      'cl': [
        for (final (i, p) in pieces.indexed)
          if (p.calling) i,
      ],
    'pl': [
      for (final p in players) [p.number, _i(p.x), _i(p.y), ?p.held],
    ],
    if (readyTargets.isNotEmpty) 'rd': readyTargets.toList()..sort(),
    if (hintTargets.isNotEmpty) 'hn': hintTargets.toList()..sort(),
    'ft': ?finishTimeMs,
    if (night) 'nt': 1,
    if (points > 0) 'pts': points,
    if (popups.isNotEmpty)
      'pop': [
        for (final p in popups) [p.side.index, _i(p.place.dx), _i(p.place.dy), p.amount, p.ageMs, p.icon.index],
      ],
  };

  String encode() => jsonEncode(toJson());

  static PuzzleSnapshot decode(String text) => fromJson(jsonDecode(text) as Map<String, Object?>);

  static PuzzleSnapshot fromJson(Map<String, Object?> j) {
    if (j['v'] != version) throw FormatException('Puzzle snapshot version ${j['v']}, expected $version');
    double d(Object? v) => (v as num) / 10;
    final calling = {...((j['cl'] as List?) ?? const []).cast<int>()};
    return PuzzleSnapshot(
      puzzleId: j['pz'] as String,
      timeLeftMs: j['t'] as int,
      warning: j['w'] == 1,
      phase: PuzzlePhase.values[j['ph'] as int],
      pieces: [
        for (final (i, p) in (j['pc'] as List).cast<List>().indexed)
          PieceView(
            x: d(p[0]),
            y: d(p[1]),
            angle: d(p[2]),
            state: PieceState.values[p[3] as int],
            holders: p.skip(4).cast<int>().toList(),
            calling: calling.contains(i),
          ),
      ],
      players: [
        for (final p in (j['pl'] as List).cast<List>())
          PlayerView(number: p[0] as int, x: d(p[1]), y: d(p[2]), held: p.length > 3 ? p[3] as int : null),
      ],
      readyTargets: {...((j['rd'] as List?) ?? const []).cast<int>()},
      hintTargets: {...((j['hn'] as List?) ?? const []).cast<int>()},
      finishTimeMs: j['ft'] as int?,
      points: j['pts'] as int? ?? 0,
      night: j['nt'] == 1,
      popups: [
        for (final p in (j['pop'] as List? ?? const []).cast<List>())
          PuzzlePopup(
            side: PuzzleSide.values[p[0] as int],
            place: Offset(d(p[1]), d(p[2])),
            amount: p[3] as int,
            ageMs: p[4] as int,
            icon: PuzzleIcon.values[p[5] as int],
          ),
      ],
      order: (j['o'] as List?)?.cast<int>(),
    );
  }

  /// The board at [t] between this snapshot (0) and [next] (1) (m12 §4): dots
  /// and pieces move, a piece turns the shortest way round (350° → 10° passes
  /// through 0°), and its state, who holds it and the clock stay this
  /// snapshot's. Pieces are paired by index, which every board lists the same
  /// way; a piece only in [next] isn't drawn yet.
  @override
  PuzzleSnapshot lerpTo(GameSnapshot next, double t) {
    if (next is! PuzzleSnapshot) {
      throw ArgumentError.value(next, 'next', 'A puzzle snapshot lerps with another puzzle snapshot');
    }
    if (t <= 0) return this;
    if (t >= 1) return next;
    double lerp(double from, double to) => from + (to - from) * t;
    PieceView piece(PieceView a, PieceView b) => PieceView(
      x: lerp(a.x, b.x),
      y: lerp(a.y, b.y),
      angle: _lerpAngleDeg(a.angle, b.angle, t),
      state: a.state,
      holders: a.holders,
      calling: a.calling,
    );
    PlayerView player(PlayerView a, PlayerView b) =>
        PlayerView(number: a.number, x: lerp(a.x, b.x), y: lerp(a.y, b.y), held: a.held);
    return PuzzleSnapshot(
      puzzleId: puzzleId,
      timeLeftMs: timeLeftMs,
      warning: warning,
      phase: phase,
      order: order,
      readyTargets: readyTargets,
      hintTargets: hintTargets,
      finishTimeMs: finishTimeMs,
      points: points,
      night: night,
      popups: popups,
      pieces: [for (final (i, a) in pieces.indexed) i < next.pieces.length ? piece(a, next.pieces[i]) : a],
      players: [for (final (i, a) in players.indexed) i < next.players.length ? player(a, next.players[i]) : a],
    );
  }
}

int _i(double v) => (v * 10).round();

/// [from] turned [t] of the way to [to], the shortest way round the circle:
/// 350° to 10° passes 0°, so half way is 0° (or 360°).
double _lerpAngleDeg(double from, double to, double t) {
  // −180..180: the shortest signed turn, so a piece never spins the long way.
  final turn = (to - from + 540) % 360 - 180;
  return (from + turn * t) % 360;
}

/// A whole match as the view sees it (S8): one board, or the left and right
/// boards of the split screen.
final class MatchSnapshot implements GameSnapshot {
  const MatchSnapshot({required this.boards, this.seed});

  static const version = 2;

  /// One board, or two: left, then right.
  final List<PuzzleSnapshot> boards;

  /// The seed the sides' layout was built from, so a phone can rebuild the
  /// same one: a race, or a one-board `phones` match (m12 §1). Null for one
  /// board on the screen, which starts at its own angles.
  final int? seed;

  bool get split => boards.length == 2;

  /// Each board's points by the side that plays it (M14 a1): the boards are
  /// the sides' boards in order, left then right in a race, and a one-board
  /// match's only board comes first.
  Map<PuzzleSide, int> get points => {for (final (i, board) in boards.indexed) PuzzleSide.values[i]: board.points};

  /// This is a party night's round (N4): one of the boards says so, and the
  /// view draws the points and the pop-ups.
  bool get night => boards.any((b) => b.night);

  @override
  Map<String, Object?> toJson() => {
    'v': version,
    'b': [for (final b in boards) b.toJson()],
    'sd': ?seed,
  };

  String encode() => jsonEncode(toJson());

  static MatchSnapshot decode(String text) => fromJson(jsonDecode(text) as Map<String, Object?>);

  static MatchSnapshot fromJson(Map<String, Object?> j) {
    if (j['v'] != version) throw FormatException('Match snapshot version ${j['v']}, expected $version');
    return MatchSnapshot(
      boards: [for (final b in (j['b'] as List).cast<Map<String, Object?>>()) PuzzleSnapshot.fromJson(b)],
      seed: j['sd'] as int?,
    );
  }

  /// The match at [t] between this snapshot (0) and [next] (1) (m12 §4): each
  /// board moves towards the board of the same side, and the seed stays this
  /// snapshot's. A board only in [next] isn't drawn yet.
  @override
  MatchSnapshot lerpTo(GameSnapshot next, double t) {
    if (next is! MatchSnapshot) {
      throw ArgumentError.value(next, 'next', 'A match snapshot lerps with another match snapshot');
    }
    if (t <= 0) return this;
    if (t >= 1) return next;
    return MatchSnapshot(
      boards: [for (final (i, a) in boards.indexed) i < next.boards.length ? a.lerpTo(next.boards[i], t) : a],
      seed: seed,
    );
  }
}
