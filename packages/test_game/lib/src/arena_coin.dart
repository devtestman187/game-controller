import 'dart:ui';

import 'arena_field.dart';

/// One coin on the Bumper Round's field (party-night §7, M14 G9): a value with
/// its place as fractions of the field and how long it has been out, which the
/// painter turns into its spin.
///
/// A coin is only ever made by the round, at a free spot of a map's coin zone,
/// never under a marble and never on a wall: the map rules hold the zones clear
/// (M14 k1b).
final class ArenaCoin {
  const ArenaCoin({required this.x, required this.y, this.ageS = 0});

  /// A coin's radius, twice it, and the most places a round offers each zone:
  /// a coin is a marble's size, so one [MapGrid] serves both, and a zone offers
  /// several times the coins out, so a coin taken has somewhere else to come
  /// back.
  static const double radius = ArenaFieldRules.playerRadius;
  static const double diameter = 2 * radius;
  static const int spotsPerZone = 4 * coinsOut;

  /// How many coins the field holds at once (party-night §7): taking one makes
  /// room for a new one.
  static const int coinsOut = 3;

  /// Across and down, as fractions of the field.
  final double x;
  final double y;

  /// Seconds since it appeared: its spin turns on it and stops with effects
  /// off.
  final double ageS;

  Offset get position => Offset(x, y);

  /// The same coin, [dt] seconds older.
  ArenaCoin aged(double dt) => ArenaCoin(x: x, y: y, ageS: ageS + dt);

  @override
  String toString() => 'ArenaCoin($x, $y, ${ageS}s)';
}
