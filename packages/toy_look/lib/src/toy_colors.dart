import 'dart:ui' show Color;

import 'package:protocol/protocol.dart' show playerColor;

import 'look_choice.dart';

/// The look's colours (M13, docs/design/look-and-sound.md section 3), named by
/// what they are for rather than by what they look like, so a later change
/// moves every use at once.
///
/// The tokens that differ between the palettes have a value in each of
/// [sunny] and [night]; the rest are shared by both. Text on a coloured fill is
/// always [ink], never white (design D12), and every text pair keeps 4.5:1
/// (the contrast test).
final class ToyColors {
  const ToyColors({
    required this.ink,
    required this.background,
    required this.backgroundGlow,
    required this.dotAlpha,
    required this.onBackground,
    required this.paper,
    required this.board,
    required this.tray,
    required this.targetNeutral,
    required this.field,
    required this.wall,
    required this.focus,
    required this.good,
    required this.caution,
    required this.bad,
    required this.faceA,
    required this.faceB,
    required this.faceX,
    required this.faceY,
  });

  /// The Sunny palette: a light sky behind everything (design D1).
  static const sunny = ToyColors(
    ink: Color(0xFF1E1646),
    background: Color(0xFF7CC8F8),
    backgroundGlow: Color(0xFFC4EAFF),
    dotAlpha: 0.22,
    onBackground: Color(0xFF1E1646),
    paper: Color(0xFFFFF6E3),
    board: Color(0xFFFFEFD0),
    tray: Color(0xFFF5D9A8),
    targetNeutral: Color(0xFFB3A285),
    field: Color(0xFFA9DCFB),
    wall: Color(0xFF7F8FD1),
    focus: Color(0xFFFFD23F),
    good: Color(0xFF2FCB74),
    caution: Color(0xFFFFB020),
    bad: Color(0xFFFF4D5E),
    faceA: Color(0xFF2FCB74),
    faceB: Color(0xFFFF4D5E),
    faceX: Color(0xFF2E9BF0),
    faceY: Color(0xFFFFD23F),
  );

  /// The Night palette: a deep grape behind everything, easy on the eyes in a
  /// dark room (design D1).
  static const night = ToyColors(
    ink: Color(0xFF120D2E),
    background: Color(0xFF241C5E),
    backgroundGlow: Color(0xFF3B2F8F),
    dotAlpha: 0.07,
    onBackground: Color(0xFFFFFFFF),
    paper: Color(0xFFFFF6E3),
    board: Color(0xFF30297A),
    tray: Color(0xFF3D3592),
    targetNeutral: Color(0xFF9289D6),
    field: Color(0xFF2A2270),
    wall: Color(0xFF8C9BD8),
    focus: Color(0xFFFFD23F),
    good: Color(0xFF2FCB74),
    caution: Color(0xFFFFB020),
    bad: Color(0xFFFF4D5E),
    faceA: Color(0xFF2FCB74),
    faceB: Color(0xFFFF4D5E),
    faceX: Color(0xFF2E9BF0),
    faceY: Color(0xFFFFD23F),
  );

  /// The palette [palette]'s tokens.
  static ToyColors of(ToyPalette palette) => switch (palette) {
    ToyPalette.sunny => sunny,
    ToyPalette.night => night,
  };

  /// Every outline and shadow, and the text on paper.
  final Color ink;

  /// The screen behind everything.
  final Color background;

  /// The soft lighter centre of [background].
  final Color backgroundGlow;

  /// How strongly the background's white polka dots show over [background]:
  /// faint in the sunlight (22 %) and fainter at night (7 %), where the dots
  /// are a hint rather than a pattern (design section 4).
  final double dotAlpha;

  /// Text straight on the background.
  final Color onBackground;

  /// Cards, dialogs, side panels and the results card.
  final Color paper;

  /// Shape Race's play mat.
  final Color board;

  /// Shape Race's tray strip.
  final Color tray;

  /// Medium and Hard target outlines.
  final Color targetNeutral;

  /// The Arena's floor.
  final Color field;

  /// The Arena's walls.
  final Color wall;

  /// The controller's focus ring and glow.
  final Color focus;

  /// Right, a link OK and a winner.
  final Color good;

  /// Waiting and a slow link.
  final Color caution;

  /// Wrong, a hazard and the last 15 s.
  final Color bad;

  /// The pad's A.
  final Color faceA;

  /// The pad's B.
  final Color faceB;

  /// The pad's X.
  final Color faceX;

  /// The pad's Y.
  final Color faceY;

  /// Player [number]'s colour, from the protocol's one palette of player
  /// colours (design D6): the same value on the host and on every phone.
  Color player(int number) => Color(playerColor(number));
}
