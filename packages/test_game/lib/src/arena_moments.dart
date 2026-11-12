import 'dart:math' show cos, pi;
import 'dart:ui' show Offset;

import 'arena_snapshot.dart';

/// Where a marble looks until it first moves: right, the way it starts, from
/// the start pad towards the goal.
const lookRight = Offset(1, 0);

/// How far a marble must travel between two snapshots to have a direction, as
/// a fraction of the field. A snapshot keeps positions to a ten-thousandth of
/// the field (`ArenaSnapshot`'s rounding), so anything less is rounding rather
/// than walking.
const stillShare = 0.0005;

/// How often a recovering marble fades and comes back, in Hz: 2.5, so a change
/// every 0.4 s. The design's comfort rule (G5) allows under 3 a second, and
/// M12 blinked its marble at 5.
const recoverPulseHz = 2.5;

/// A recovering marble's alpha at its fullest and at its faintest (rule 2).
const recoverFullAlpha = 1.0;
const recoverFaintAlpha = 0.4;

/// The alpha a recovering marble is drawn at with effects off: the middle of
/// its fade, so a player can still see they are recovering while nothing moves
/// (design D8).
const recoverStillAlpha = 0.7;

/// The alpha of a marble that has been recovering for [roundTimeS] seconds of
/// its round: full at 0, faint at 0.2 s, full again at 0.4 s, and so on
/// [recoverPulseHz] times a second. It is read from the round's own clock,
/// never from Random, so every device draws the same fade in the same frame.
double recoveringAlpha(double roundTimeS) {
  final middle = (recoverFullAlpha + recoverFaintAlpha) / 2;
  final sway = (recoverFullAlpha - recoverFaintAlpha) / 2;
  return middle + sway * cos(2 * pi * recoverPulseHz * roundTimeS);
}

/// How long a marble's coin count pops after it changes, in seconds (M14 b2):
/// long enough to see a pick-up or a drop, short enough not to hide the count
/// it brings.
const coinPopS = 0.4;

/// Where every marble last moved, worked out from the snapshots as the view
/// saw them (rule 3): the eyes look that way, and a marble that stops keeps
/// looking the way it went.
///
/// The view keeps one and feeds it each new snapshot; a new round — a new
/// round number — starts every marble looking right again, and the jump back
/// to the start pad is not read as a move. Nothing is added to the snapshot or
/// the protocol, so a joined phone works the same out of the same frames.
///
/// It is a view-side value: no Flutter and no look, as the rules are.
final class ArenaMoments {
  /// The round the marbles have been seen in, or null before the first
  /// snapshot.
  int? _round;

  /// The way each player's marble looks, as a unit vector.
  final Map<String, Offset> _looks = {};

  /// Where each player's marble stood in the snapshot before.
  final Map<String, Offset> _places = {};

  /// Each player's coin count as the snapshot before had it, and the round's
  /// clock when it last changed, so a count that changes pops once (M14 b2).
  final Map<String, int> _coins = {};
  final Map<String, double> _coinChangedAt = {};

  /// Notes where every marble of [snapshot] is, the way it moved since the
  /// snapshot before, and whether its coin count changed.
  void observe(ArenaSnapshot snapshot) {
    if (snapshot.round != _round) {
      _round = snapshot.round;
      _looks.clear();
      _places.clear();
      _coins.clear();
      _coinChangedAt.clear();
    }
    for (final player in snapshot.players) {
      final place = Offset(player.x, player.y);
      final before = _places[player.id];
      if (before == null) {
        // A marble new to the round looks right, whatever it looked before.
        _looks.remove(player.id);
      } else {
        final travel = place - before;
        if (travel.distance > stillShare) _looks[player.id] = travel / travel.distance;
      }
      _places[player.id] = place;
      final coins = _coins[player.id];
      if (coins != null && coins != player.coins) _coinChangedAt[player.id] = snapshot.roundTimeS;
      _coins[player.id] = player.coins;
    }
  }

  /// The way player [id]'s marble looks: the way it last moved, or right.
  Offset lookOf(String id) => _looks[id] ?? lookRight;

  /// How much player [id]'s coin count is popping at [atTimeS] of the round
  /// (M14 b2): 1 at the change, fading to 0 over [coinPopS]. Worked out from
  /// the round's own clock, so every screen shows the same pop.
  double coinPopOf(String id, double atTimeS) {
    final changedAt = _coinChangedAt[id];
    if (changedAt == null) return 0;
    final elapsed = atTimeS - changedAt;
    if (elapsed < 0 || elapsed >= coinPopS) return 0;
    return (1 - elapsed / coinPopS).clamp(0.0, 1.0);
  }
}
