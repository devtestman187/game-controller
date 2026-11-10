import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'piece_colors.dart';

part 'piece_shape.dart';

/// The puzzle file format this build reads (m13 s20, docs/levels.md): files
/// say `"format": 1`, and one that says a higher number was written for a
/// newer app and is refused with a message saying so.
const puzzleFormat = 1;

/// The field every puzzle is played on, in field units: 16:9 (PRD v2 S4),
/// drawn scaled into whatever box the host gives.
const fieldSize = Size(160, 90);

/// The board (where the outlines are) and the tray (where the pieces start),
/// in field units. Puzzle data is in board units: 0..[boardSize] from the
/// board's top left.
const boardSize = Size(80, 72);
const boardRect = Rect.fromLTWH(16, 13, 80, 72);
const trayRect = Rect.fromLTWH(102, 13, 54, 72);

/// The strip along the top with the clock and the count.
const hudHeight = 10.0;

/// One side's world, in field units: its size, the board, the tray, and
/// where the dots may go. [single] is the one-board layout (1 player, or a
/// team of two on one board); the split screen's worlds come from
/// `SplitLayout`, which crops each side's board to the puzzle's picture.
final class PuzzleField {
  const PuzzleField({
    required this.size,
    required this.board,
    required this.tray,
    required this.origin,
    required this.top,
    required this.startX,
    this.trayOverlap = 0,
    this.trayScale = 1,
  });

  final Size size;
  final Rect board;
  final Rect tray;

  /// Where board unit (0, 0) of the puzzle data lands in the field: [board]
  /// stays the rectangle drawn as the board.
  final Offset origin;

  /// Dots stay below this: the one-board layout's clock strip, nothing on the
  /// split screen, and the world's top margin on phones, where the tray and
  /// its pieces are above the board (m12 §1).
  final double top;

  /// Where the dots start, one above the other.
  final double startX;

  /// How much a tray row's pieces may overlap: each piece after the first
  /// starts this fraction of the previous box's width before its right edge.
  /// 0: a gap between boxes, as on one board.
  final double trayOverlap;

  /// The size a piece still in the tray is drawn, packed and picked up at: 1
  /// on one board, smaller on the split screen so the pile fits.
  final double trayScale;

  static const single = PuzzleField(
    size: fieldSize,
    board: boardRect,
    tray: trayRect,
    origin: Offset(16, 13), // boardRect.topLeft, which a getter can't be in a const
    top: hudHeight,
    startX: 8,
  );
}

enum Level {
  easy,
  medium,
  hard;

  /// Easy outlines are coloured to match their pieces; Medium and Hard
  /// outlines are grey, so only the shape helps.
  bool get colouredOutlines => this == easy;
}

/// The levels a puzzle file may say (m14 g1): [Level.hard] is in the enum for
/// the difficulty to come, but has no rules yet, so a file may not use it.
const puzzleLevels = ['easy', 'medium'];

/// The refusal of a level this build does not have, in the same words in the
/// schema, the parser, the rule book and `tools/level.sh new`.
String notALevel(String level) => '"$level" is not a level: use ${puzzleLevels.join(' or ')}';

/// One piece and its outline: where it belongs on the board.
final class PieceSpec {
  PieceSpec({
    required this.id,
    required this.shape,
    required this.color,
    required this.target,
    this.targetAngle = 0,
    String? kind,
    this.rotated = false,
    this.big = false,
  }) : kind = kind ?? id;

  final String id;

  /// Pieces of the same kind (and shape) are interchangeable: either window
  /// fits either window outline.
  final String kind;
  final PieceShape shape;

  /// 0xAARRGGBB.
  final int color;

  /// The outline's centre, in board units.
  final Offset target;
  final double targetAngle;

  /// Starts at a random angle at least 30° from correct.
  final bool rotated;

  /// A big piece (teams carry it together, M11).
  final bool big;
}

/// A puzzle: a picture made of distinct shapes (PRD v2 "Puzzle game
/// design"). Loaded from a data file, so more can be added without code.
/// [checkPuzzle] in `puzzle_rules.dart` is the linter that holds the rules a
/// puzzle file must keep (unique ids, pieces of a kind sharing a shape, and
/// the rest), so a broken file is caught by `tools/level.sh check`.
final class Puzzle {
  Puzzle({required this.id, required this.name, required this.level, required List<PieceSpec> pieces})
    : pieces = List.unmodifiable(pieces);

  final String id;
  final String name;
  final Level level;
  final List<PieceSpec> pieces;

  /// A target's centre in field units.
  Offset targetAt(int i) => boardRect.topLeft + pieces[i].target;

  /// The puzzle [json] holds. `$schema` is left to the editor; `format`
  /// missing means [puzzleFormat] (files written before the format existed),
  /// and a higher one is refused with a message naming the version. A field
  /// of the wrong type is a [FormatException] naming it (and the puzzle or
  /// piece it is in), never a bare cast's error.
  static Puzzle fromJson(Map<String, Object?> json) {
    // The header every level file shares (M14 k1a): "$schema" is the editor's,
    // and a format this build can't read is refused in the kit's words.
    readLevelHeader(json, currentFormat: puzzleFormat, kind: 'puzzle');
    final rawPieces = json['pieces'];
    if (rawPieces is! List || rawPieces.isEmpty) throw const FormatException('A puzzle needs "pieces"');
    final id = _text(json, 'id');
    final level = _text(json, 'level');
    if (!puzzleLevels.contains(level)) throw FormatException(notALevel(level));
    return Puzzle(
      id: id,
      name: _text(json, 'name', puzzle: id),
      level: Level.values.byName(level),
      pieces: [for (final raw in rawPieces) _piece(raw, id)],
    );
  }

  /// [json]'s [key] as text, or a [FormatException] naming the field (and
  /// [puzzle], once its id is known).
  static String _text(Map<String, Object?> json, String key, {String? puzzle}) => switch (json[key]) {
    final String value => value,
    final other => throw FormatException(
      '${puzzle == null ? '' : 'Puzzle "$puzzle": '}"$key" must be text, got ${jsonEncode(other)}',
    ),
  };

  /// A piece from its JSON, or a [FormatException] naming the puzzle, the
  /// piece and the field.
  static PieceSpec _piece(Object? raw, String puzzle) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('Puzzle "$puzzle": a piece is not an object, got ${jsonEncode(raw)}');
    }
    final id = switch (raw['id']) {
      final String value => value,
      final other => throw FormatException('Puzzle "$puzzle": a piece\'s "id" must be text, got ${jsonEncode(other)}'),
    };
    final kind = switch (raw['kind']) {
      null => null,
      final String value => value,
      final other => throw FormatException(
        'Puzzle "$puzzle", piece "$id": "kind" must be text, got ${jsonEncode(other)}',
      ),
    };
    final angle = switch (raw['angle']) {
      null => 0.0,
      final num degrees => degrees.toDouble(),
      final other => throw FormatException(
        'Puzzle "$puzzle", piece "$id": "angle" must be a number, got ${jsonEncode(other)}',
      ),
    };
    return PieceSpec(
      id: id,
      kind: kind,
      shape: PieceShape.fromJson(raw['shape']),
      color: PiecePalette.parse(raw['color']),
      target: switch (raw['at']) {
        [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
        _ => throw FormatException('Puzzle "$puzzle", piece "$id": "at" must be [x, y], got ${jsonEncode(raw['at'])}'),
      },
      targetAngle: angle,
      rotated: raw['rotated'] == true,
      big: raw['big'] == true,
    );
  }

  static Puzzle parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('A puzzle file is a JSON object: {"id": ..., "pieces": [...]}');
    }
    return fromJson(decoded);
  }
}

/// The angle difference to [target] for a shape with [symmetry] (see
/// [PieceShape.symmetry]), from 0 up to half the symmetry.
double angleError(double angle, double target, double symmetry) {
  if (symmetry == 0) return 0;
  final d = (angle - target) % symmetry;
  final m = d < 0 ? d + symmetry : d;
  return min(m, symmetry - m);
}

/// The angle nearest [angle] that looks exactly like [target] (for snapping
/// without a visible jump on symmetric pieces).
double snapAngle(double angle, double target, double symmetry) {
  if (symmetry == 0) return angle;
  final turns = ((angle - target) / symmetry).round();
  return target + turns * symmetry;
}
