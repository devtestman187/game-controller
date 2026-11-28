import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The golden slot's handover to the view (M17 glow1): Match.snapshot() carries the slot that glows, so the view
/// paints it, and it carries none once the slot is claimed or before the first delay has passed.
void main() {
  const idle = {'p1': none, 'p2': none};

  /// A two-board race of [flatWorld] on Lively party: the present's gate, so the golden slot runs.
  PuzzleMatch race() => begin(flatWorld(), const {
    'p1': PuzzleSide.left,
    'p2': PuzzleSide.right,
  }, settings: const PuzzleSettings(chaos: Chaos.party));

  test('snapshot() carries the glowing golden slot, the same one the match reports', () {
    final m = race();
    drive(m, idle, frames: 210);
    expect(m.snapshot().golden, isNotNull, reason: 'at about 10.5 s a slot glows, so the snapshot carries it');
    expect(m.snapshot().golden, m.golden, reason: 'the snapshot hands over the match\'s own slot');
  });

  test('snapshot() carries no golden slot before the first delay has passed', () {
    final m = race();
    drive(m, idle, frames: 190);
    expect(m.snapshot().golden, isNull, reason: 'at about 9.5 s nothing glows yet (firstDelayS is 10 s)');
  });

  test('snapshot() carries no golden slot once the first claim has taken it', () {
    final m = race();
    drive(m, idle, frames: 210);
    final slot = m.golden ?? fail('no slot glows after 10.5 s');
    final left = m.gameOf(PuzzleSide.left);
    place(m, left, 'p1', slot);
    expect(m.snapshot().golden, isNull, reason: 'the claimed slot stops glowing, so the snapshot drops it');
  });
}
