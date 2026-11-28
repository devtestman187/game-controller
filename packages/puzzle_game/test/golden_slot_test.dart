import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

/// The golden slot (M17 race1c r3e): one outline glows on both boards, the first side to fill it earns double the snap's
/// points, the pick favours the side behind, and it runs only in a two-board match on the present's gate.
void main() {
  const idle = {'p1': none, 'p2': none};
  const bothOpen = {0, 1, 2, 3, 4};
  const rightOnly = {5, 6, 7, 8, 9};
  const leftOnly = {10, 11, 12, 13, 14};

  /// A two-board race of [flatWorld] on Lively party: the present's gate, so the golden slot runs.
  PuzzleMatch race() => begin(flatWorld(), const {
    'p1': PuzzleSide.left,
    'p2': PuzzleSide.right,
  }, settings: const PuzzleSettings(chaos: Chaos.party));

  /// Drops piece [i] for [id] off its outline, so the drop is wrong and its next snap is a try again.
  void misplace(PuzzleMatch m, PuzzleGame game, String id, int i) {
    game.player(id)!.pos = game.pieces[i].pos;
    tap(m, id, const {});
    final middle = game.field.board.center;
    game.player(id)!.pos = middle;
    game.pieces[i].pos = middle;
    tap(m, id, const {});
  }

  /// The slot a fresh golden slot picks once its first delay has passed, with [openLeft] and [openRight] open.
  int? pickOnce(
    Random random, {
    required Set<int> openLeft,
    required Set<int> openRight,
    required int placedLeft,
    required int placedRight,
  }) {
    final golden = GoldenSlot(random);
    golden.update(
      GoldenSlot.firstDelayS,
      enabled: true,
      inputs: GoldenInputs(openLeft: openLeft, openRight: openRight, placedLeft: placedLeft, placedRight: placedRight),
    );
    return golden.slot;
  }

  test('a slot glows only after the first delay, not before', () {
    final m = race();
    drive(m, idle, frames: 190);
    expect(m.golden, isNull, reason: 'at about 9.5 s nothing glows yet (firstDelayS is 10 s)');
    drive(m, idle, frames: 20);
    expect(m.golden, isNotNull, reason: 'at about 10.5 s a slot glows');
  });

  test('the first snap on a glowing slot earns double points, and the slot then stops glowing', () {
    final m = race();
    drive(m, idle, frames: 210);
    final slot = m.golden ?? fail('no slot glows after 10.5 s');
    final left = m.gameOf(PuzzleSide.left);
    final before = left.points;
    place(m, left, 'p1', slot);
    expect(left.points - before, 4, reason: 'a snap is 2 points, and the first claim pays it twice');
    expect(m.golden, isNull, reason: 'the claimed slot stops glowing');
  });

  test('a snap on two boards with Chaos off earns its base 2 points, as no slot glows yet', () {
    final m = begin(flatWorld(), const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    final left = m.gameOf(PuzzleSide.left);
    place(m, left, 'p1', 0);
    expect(left.points, 2, reason: 'with no golden slot a snap is its base 2 points at pointsScale 1');
  });

  test('a snap on one board earns its base 2 points, as no golden slot runs there', () {
    final m = begin(flatWorld(), const {'p1': PuzzleSide.left}, settings: const PuzzleSettings(chaos: Chaos.party));
    final left = m.gameOf(PuzzleSide.left);
    place(m, left, 'p1', 0);
    expect(left.points, 2, reason: 'one board has no golden slot, so the snap is its base 2 points');
  });

  test('a wrong re-snap on the glowing slot pays its try-again point and leaves the slot glowing', () {
    final m = race();
    drive(m, idle, frames: 210);
    final slot = m.golden ?? fail('no slot glows after 10.5 s');
    final left = m.gameOf(PuzzleSide.left);
    misplace(m, left, 'p1', slot);
    expect(left.pieces[slot].state, PieceState.wrong, reason: 'the first drop misses the outline');
    final before = left.points;
    place(m, left, 'p1', slot);
    expect(
      left.points - before,
      1,
      reason: 'a try again pays PuzzlePoints.wrongSnap, 1 point, and never the golden double',
    );
    expect(m.golden, slot, reason: 'a wrong re-snap claims nothing, so the slot keeps glowing');
  });

  test('no slot glows when the present gate is off, on Wild, or on one board', () {
    final off = begin(flatWorld(), const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
    final wild = begin(flatWorld(), const {
      'p1': PuzzleSide.left,
      'p2': PuzzleSide.right,
    }, settings: const PuzzleSettings(chaos: Chaos.party, catPreset: CatPreset.wild));
    final solo = begin(flatWorld(), const {'p1': PuzzleSide.left}, settings: const PuzzleSettings(chaos: Chaos.party));
    for (final (name, m) in [('Chaos off', off), ('Wild', wild), ('one board', solo)]) {
      drive(m, idle, frames: 1200);
      expect(m.golden, isNull, reason: '$name: no golden slot in 60 s');
    }
  });

  test('nothing glows while disabled, however long it waits', () {
    final golden = GoldenSlot(Random(1));
    golden.update(
      1000,
      enabled: false,
      inputs: const GoldenInputs(openLeft: bothOpen, openRight: bothOpen, placedLeft: 0, placedRight: 0),
    );
    expect(golden.slot, isNull, reason: 'the gate is off, so no pick is made');
  });

  test('a glowing slot that both sides have locked clears, with no claim', () {
    final golden = GoldenSlot(Random(3));
    golden.update(
      GoldenSlot.firstDelayS,
      enabled: true,
      inputs: const GoldenInputs(openLeft: bothOpen, openRight: bothOpen, placedLeft: 0, placedRight: 0),
    );
    final slot = golden.slot ?? fail('no slot glows after firstDelayS');
    final rest = {...bothOpen}..remove(slot);
    golden.update(
      0.05,
      enabled: true,
      inputs: GoldenInputs(openLeft: rest, openRight: rest, placedLeft: 1, placedRight: 1),
    );
    expect(golden.slot, isNull, reason: 'both sides locked the slot, so it clears');
    expect(golden.claim(PuzzleSide.left, slot), isFalse, reason: 'a cleared slot cannot be claimed');
  });

  test('the first claim wins, only for the glowing slot, and a second claim gives nothing', () {
    final golden = GoldenSlot(Random(5));
    golden.update(
      GoldenSlot.firstDelayS,
      enabled: true,
      inputs: const GoldenInputs(openLeft: bothOpen, openRight: bothOpen, placedLeft: 0, placedRight: 0),
    );
    final slot = golden.slot ?? fail('no slot glows after firstDelayS');
    final other = bothOpen.firstWhere((s) => s != slot);
    expect(golden.claim(PuzzleSide.right, other), isFalse, reason: 'only the glowing slot can be claimed');
    expect(golden.claim(PuzzleSide.right, slot), isTrue, reason: 'the first claim on the glowing slot wins');
    expect(golden.claim(PuzzleSide.left, slot), isFalse, reason: 'a second claim on the same slot gives nothing');
    expect(golden.claimedBy, PuzzleSide.right);
  });

  test('the side behind is picked more often: 2 to 1 per slot, and never the leader\'s own', () {
    // Left has 2 placed and right 1, so right is behind: its own slots weigh 2, the shared ones 1, and left's own
    // slots are never candidates. Expected share of right's own slots: 10 / 15 = 2/3.
    final random = Random(7);
    final counts = <int, int>{};
    const picks = 3000;
    for (var n = 0; n < picks; n++) {
      final picked = pickOnce(
        random,
        openLeft: {...bothOpen, ...leftOnly},
        openRight: {...bothOpen, ...rightOnly},
        placedLeft: 2,
        placedRight: 1,
      );
      if (picked != null) counts.update(picked, (c) => c + 1, ifAbsent: () => 1);
    }
    int countIn(Set<int> slots) => slots.fold(0, (sum, s) => sum + (counts[s] ?? 0));
    expect(counts.values.fold(0, (sum, c) => sum + c), picks, reason: 'every pick finds a candidate');
    expect(countIn(leftOnly), 0, reason: 'the leader\'s own slots are never picked');
    expect(countIn(rightOnly) / picks, closeTo(2 / 3, 0.05), reason: 'the side behind gets 2/3 of the picks');
  });
}
