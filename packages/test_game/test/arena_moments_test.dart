import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// The arena at [round] with one marble per (id, x, y), the rest of the field
/// clear: these tests read the way the marbles look and nothing else.
ArenaSnapshot arena(int round, List<(String, double, double)> players) => ArenaSnapshot(
  round: round,
  roundTimeS: 0,
  phase: ArenaPhase.playing,
  walls: const [],
  goal: const Rect.fromLTRB(0.86, 0.38, 0.97, 0.62),
  hazards: const [],
  players: [for (final (id, x, y) in players) ArenaPlayerView(id: id, x: x, y: y)],
);

/// The steps of such a snapshot play: round 1, one marble.
final start = arena(1, [('a', 0.5, 0.5)]);

/// How many times the fade comes back down to its middle in [seconds], read
/// from [recoveringAlpha] every millisecond: one dip is one change.
int dipsIn(double seconds) {
  var dips = 0;
  var before = recoveringAlpha(0);
  for (var ms = 1; ms <= seconds * 1000; ms++) {
    final alpha = recoveringAlpha(ms / 1000);
    if (before >= recoverStillAlpha && alpha < recoverStillAlpha) dips++;
    before = alpha;
  }
  return dips;
}

void main() {
  test('a marble looks right until it moves', () {
    final moments = ArenaMoments();
    expect(moments.lookOf('a'), lookRight, reason: 'a marble that has never moved looks right');
    moments.observe(start);
    expect(moments.lookOf('a'), lookRight, reason: 'the first snapshot only says where it is');
  });

  test('the eyes follow the last move', () {
    final moments = ArenaMoments()..observe(start);
    moments.observe(arena(1, [('a', 0.6, 0.5)]));
    expect(moments.lookOf('a'), const Offset(1, 0), reason: 'it moved right');
    moments.observe(arena(1, [('a', 0.6, 0.7)]));
    expect(moments.lookOf('a'), const Offset(0, 1), reason: 'it moved down');
    // (3, 4) of the field: a unit vector, so the eyes look 53° down-right.
    moments.observe(arena(1, [('a', 0.63, 0.74)]));
    expect(moments.lookOf('a').dx, closeTo(0.6, 1e-9), reason: 'the way it moved, as a unit vector');
    expect(moments.lookOf('a').dy, closeTo(0.8, 1e-9));
  });

  test('a still marble keeps looking the way it last moved', () {
    final moments = ArenaMoments()..observe(start);
    moments.observe(arena(1, [('a', 0.5, 0.4)]));
    expect(moments.lookOf('a'), const Offset(0, -1), reason: 'it moved up');
    moments.observe(arena(1, [('a', 0.5, 0.4)]));
    expect(moments.lookOf('a'), const Offset(0, -1), reason: 'a marble that stops keeps looking that way');
    // A snapshot keeps positions to a ten-thousandth of the field, so a nudge
    // of 0.0002 is rounding, not walking (0.0002·√2 < 0.0005).
    moments.observe(arena(1, [('a', 0.5002, 0.4002)]));
    expect(moments.lookOf('a'), const Offset(0, -1), reason: "a snapshot's rounding is not a move");
    moments.observe(arena(1, [('a', 0.5008, 0.4008)]));
    expect(moments.lookOf('a').dx, greaterThan(0), reason: 'a walk of 0.0011 is a move');
    expect(moments.lookOf('a').dy, greaterThan(0));
  });

  test('each player has its own direction', () {
    final moments = ArenaMoments()..observe(arena(1, [('a', 0.3, 0.5), ('b', 0.7, 0.5)]));
    moments.observe(arena(1, [('a', 0.34, 0.5), ('b', 0.7, 0.46)]));
    expect(moments.lookOf('a'), const Offset(1, 0), reason: 'a moved right');
    expect(moments.lookOf('b'), const Offset(0, -1), reason: 'b moved up');
  });

  test('a new round starts again, and the jump back to the start is no move', () {
    final moments = ArenaMoments()..observe(start);
    moments.observe(arena(1, [('a', 0.5, 0.2)]));
    expect(moments.lookOf('a'), const Offset(0, -1), reason: 'it moved up in round 1');
    moments.observe(arena(2, [('a', 0.07, 0.5)]));
    expect(moments.lookOf('a'), lookRight, reason: 'round 2 puts it back at the start pad, looking right');
    moments.observe(arena(2, [('a', 0.04, 0.5)]));
    expect(moments.lookOf('a'), const Offset(-1, 0), reason: 'and it looks left once it moves left');
  });

  test('a recovering marble fades in and out 2.5 times a second', () {
    expect(recoveringAlpha(0), recoverFullAlpha, reason: 'it starts at full');
    expect(recoveringAlpha(0.1), closeTo(recoverStillAlpha, 1e-9), reason: 'a tenth of a second on it is halfway');
    expect(recoveringAlpha(0.2), closeTo(recoverFaintAlpha, 1e-9), reason: 'a fifth of a second on it is faintest');
    expect(recoveringAlpha(0.4), closeTo(recoverFullAlpha, 1e-9), reason: 'and back at full after two fifths');
    var low = recoverFullAlpha;
    var high = recoverFaintAlpha;
    for (var ms = 0; ms <= 400; ms++) {
      final alpha = recoveringAlpha(ms / 1000);
      if (alpha < low) low = alpha;
      if (alpha > high) high = alpha;
    }
    expect(low, closeTo(recoverFaintAlpha, 1e-9));
    expect(high, closeTo(recoverFullAlpha, 1e-9));
    // Design comfort rule G5: under three changes a second (M12 blinked at 5).
    expect(dipsIn(10), 25, reason: 'a dip every 0.4 s');
    expect(dipsIn(10) / 10, lessThan(3), reason: 'under 3 changes a second');
    expect(recoverStillAlpha, closeTo((recoverFullAlpha + recoverFaintAlpha) / 2, 1e-9));
  });
}
