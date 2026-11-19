import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_game/test_game.dart';

/// A frame with one wall at [wallX], one hazard, this round's clock and
/// sprite `a` at [x]. Sprite `c` is only in [withC].
ArenaSnapshot frame({
  required int round,
  required double wallX,
  required double roundTimeS,
  required double x,
  double cooldown = 0,
  bool withC = false,
}) => ArenaSnapshot(
  round: round,
  roundTimeS: roundTimeS,
  phase: ArenaPhase.playing,
  walls: [Rect.fromLTRB(wallX, 0, wallX + 0.01, 0.5)],
  goal: const Rect.fromLTRB(0.86, 0.38, 0.97, 0.62),
  hazards: const [Offset(0.3, 0.3)],
  players: [
    ArenaPlayerView(id: 'a', x: x, y: 0.5, cooldown: cooldown),
    if (withC) const ArenaPlayerView(id: 'c', x: 0.9, y: 0.1),
  ],
);

void main() {
  final a = frame(round: 1, wallX: 0.2, roundTimeS: 2, x: 0.1);
  final b = frame(round: 3, wallX: 0.7, roundTimeS: 4, x: 0.3, cooldown: 1, withC: true);

  test('t = 0 and t = 1 are the two frames themselves', () {
    expect(a.lerpTo(b, 0).encode(), a.encode());
    expect(a.lerpTo(b, 1).encode(), b.encode());
  });

  test('a sprite moves half way at t = 0.5, and its cooldown with it', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.player('a')!.x, closeTo(0.2, 1e-9), reason: '0.1 + (0.3 - 0.1) / 2');
    expect(s.player('a')!.y, 0.5);
    expect(s.player('a')!.cooldown, closeTo(0.5, 1e-9), reason: '0 + (1 - 0) / 2');
  });

  test('a sprite only in the next frame is not drawn yet', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.players.map((p) => p.id), ['a']);
  });

  test('the round, the field and the other counters come from this frame', () {
    final s = a.lerpTo(b, 0.5);
    expect(s.round, 1);
    expect(s.walls, a.walls);
    expect(s.goal, a.goal);
    expect(s.phase, ArenaPhase.playing);
    expect(s.roundTimeS, closeTo(3, 1e-9), reason: '2 + (4 - 2) / 2');
    expect(s.hazards.single, const Offset(0.3, 0.3));
  });

  group('the phone\'s own coins and place (M16 slice B)', () {
    /// A Bumper Round frame whose players hold [coins], each as `(id, coins)`.
    ArenaSnapshot bumper(List<(String, int)> players) => ArenaSnapshot(
      round: 1,
      roundTimeS: 30,
      phase: ArenaPhase.playing,
      walls: const [],
      goal: Rect.zero,
      hazards: const [],
      players: [for (final (id, coins) in players) ArenaPlayerView(id: id, x: 0.5, y: 0.5, coins: coins)],
      mode: ArenaMode.bumper,
      timeLeftMs: 30000,
    );

    test('coinsOf reads the player\'s own coins, and is null in the race', () {
      final frame = bumper([('a', 3), ('b', 1)]);
      expect(frame.coinsOf('a'), 3);
      expect(frame.coinsOf('b'), 1);
      expect(frame.coinsOf('nobody'), isNull);
      final race = const ArenaSnapshot(
        round: 1,
        roundTimeS: 30,
        phase: ArenaPhase.playing,
        walls: [],
        goal: Rect.zero,
        hazards: [],
        players: [ArenaPlayerView(id: 'a', x: 0.5, y: 0.5, coins: 5)],
      );
      expect(race.coinsOf('a'), isNull, reason: 'the race counts no coins');
    });

    test('placeOf ranks by coins, ties share the higher place, and it is null in the race', () {
      final frame = bumper([('a', 7), ('b', 7), ('c', 3), ('d', 1)]);
      expect(frame.placeOf('a'), 1);
      expect(frame.placeOf('b'), 1, reason: 'tied coins share first');
      expect(frame.placeOf('c'), 3, reason: 'two above, so third');
      expect(frame.placeOf('d'), 4);
      expect(frame.placeOf('nobody'), isNull);
      final race = const ArenaSnapshot(
        round: 1,
        roundTimeS: 30,
        phase: ArenaPhase.playing,
        walls: [],
        goal: Rect.zero,
        hazards: [],
        players: [ArenaPlayerView(id: 'a', x: 0.5, y: 0.5, coins: 5)],
      );
      expect(race.placeOf('a'), isNull, reason: 'the race has no coin order');
    });
  });
}
