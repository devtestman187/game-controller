import 'dart:math';

/// [color] as a puzzle file writes it: "#RRGGBB".
String hexOf(int color) => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// One named piece colour (m13 s20): a colour a puzzle file may write as its
/// name instead of a hex code. Every token stands out from the board in both
/// looks (at least [pieceBoardDistance] in OKLab, the rule s17 set), which a
/// test proves for the whole table.
final class PieceColor {
  const PieceColor(this.name, this.color);

  /// The name a puzzle file writes, lower case: "red", "sky", "silver".
  final String name;

  /// The colour, 0xAARRGGBB.
  final int color;

  /// The colour as a file writes it: "#RRGGBB".
  String get hex => hexOf(color);
}

/// The piece colour tokens (m13 s20), picked from the toy palette and named by
/// what they look like, so a puzzle file reads as a picture rather than a list
/// of hex codes. A colour without a token is written as "#RRGGBB".
///
/// Every token is at least [pieceBoardDistance] from the board in Sunny and
/// Night (the s17 rule), so a piece is seen wherever it is placed.
abstract final class PiecePalette {
  static const red = PieceColor('red', 0xFFC0392B);
  static const orange = PieceColor('orange', 0xFFE9762B);
  static const yellow = PieceColor('yellow', 0xFFF2C200);
  static const green = PieceColor('green', 0xFF27AE60);
  static const sky = PieceColor('sky', 0xFF85C1E9);
  static const blue = PieceColor('blue', 0xFF2E86C1);
  static const purple = PieceColor('purple', 0xFFA66CFF);
  static const brown = PieceColor('brown', 0xFF8E5B3A);
  static const slate = PieceColor('slate', 0xFF546E7A);
  static const silver = PieceColor('silver', 0xFF9FB8CE);
  static const steel = PieceColor('steel', 0xFF7EA6C9);
  static const sand = PieceColor('sand', 0xFFB3A285);

  /// Every token, in the order docs/levels.md shows them.
  static const all = [red, orange, yellow, green, sky, blue, purple, brown, slate, silver, steel, sand];

  /// The token called [name], or null.
  static PieceColor? byName(String name) => all.where((token) => token.name == name).firstOrNull;

  /// [color]'s token name, or null when no token has exactly that colour.
  static String? nameOf(int color) => all.where((token) => token.color == color).firstOrNull?.name;

  /// The colour a puzzle file's `"color"` names: a token's name, or
  /// "#RRGGBB". Throws a [FormatException] naming the value when it is neither
  /// (a typo in a token is the common case, so the message lists where the
  /// names are).
  static int parse(Object? value) {
    if (value is! String) {
      throw FormatException('A piece needs a "color": a name ("red", "sky", …) or "#RRGGBB", got $value');
    }
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return 0xFF000000 | int.parse(value.substring(1), radix: 16);
    }
    final token = byName(value);
    if (token != null) return token.color;
    final hex = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(value) ? ' (write a hex colour as "#RRGGBB")' : '';
    throw FormatException(
      'Unknown colour "$value"$hex: use a name from docs/levels.md '
      '(${all.map((token) => token.name).join(', ')}) or "#RRGGBB"',
    );
  }

  /// The board's colour in each look, which a piece stands out from, as
  /// 0xAARRGGBB: the look's cream and indigo. A rules file may not import the
  /// look, so a test proves these match `ToyColors`' boards.
  static const boards = {'Sunny': 0xFFFFEFD0, 'Night': 0xFF30297A};

  /// The least OKLab distance [color] keeps from the board in any look, and
  /// the look it is nearest to.
  static ({double distance, String look}) nearestBoard(int color) {
    var nearest = (distance: double.infinity, look: '');
    for (final MapEntry(key: look, value: board) in boards.entries) {
      final distance = oklabDistance(color, board);
      if (distance < nearest.distance) nearest = (distance: distance, look: look);
    }
    return nearest;
  }

  /// [color] as a check's message names it: its token's name and hex, or just
  /// the hex when no token has it.
  static String describe(int color) {
    final name = nameOf(color);
    return name == null ? hexOf(color) : '"$name" ${hexOf(color)}';
  }

  /// Up to two tokens [color] could become: the nearest that stand out from
  /// the board in both looks, as `"yellow" or "orange"`.
  static String alternatives(int color) {
    final safe = [
      for (final token in all)
        if (nearestBoard(token.color).distance >= pieceBoardDistance) token,
    ]..sort((a, b) => oklabDistance(color, a.color).compareTo(oklabDistance(color, b.color)));
    if (safe.isEmpty) return 'another colour from docs/levels.md';
    return safe.take(2).map((token) => '"${token.name}"').join(' or ');
  }
}

/// The least OKLab distance a piece's colour keeps from the board, in both
/// looks (m13 s17 rule 3, decided at device test 3): the rocket's light grey
/// body was 0.084 from Sunny's cream and read as part of the board.
const pieceBoardDistance = 0.15;

/// The least OKLab distance between two pieces of one puzzle, unless they are
/// the same shape (m13 s17 rule 4: the house's walls and door must differ).
const piecePairDistance = 0.08;

/// How far apart two colours look, as the OKLab distance: 0 is the same
/// colour; a piece on the board keeps [pieceBoardDistance] from it.
double oklabDistance(int a, int b) => labDistance(oklab(a), oklab(b));

/// A colour in OKLab: lightness, then the two chroma axes (Björn Ottosson's
/// conversion, the space the design's colour rules measure distance in).
List<double> oklab(int argb) {
  double linear(int channel) {
    final c = channel / 255.0;
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linear((argb >> 16) & 0xFF);
  final g = linear((argb >> 8) & 0xFF);
  final b = linear(argb & 0xFF);
  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
  final lc = pow(l, 1 / 3).toDouble();
  final mc = pow(m, 1 / 3).toDouble();
  final sc = pow(s, 1 / 3).toDouble();
  return [
    0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
    1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
    0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc,
  ];
}

/// How far apart two OKLab colours are: the distance between their lightness
/// and their two chroma axes.
double labDistance(List<double> p, List<double> q) =>
    sqrt(pow(p[0] - q[0], 2) + pow(p[1] - q[1], 2) + pow(p[2] - q[2], 2));
