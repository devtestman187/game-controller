import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/match_helpers.dart';

void main() {
  group('formats', () {
    test('the format follows from who joined each side', () {
      expect(MatchFormat.of({'p1': PuzzleSide.left}), MatchFormat.solo);
      expect(MatchFormat.of({'p1': PuzzleSide.right}), MatchFormat.solo);
      expect(MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left}), MatchFormat.team);
      expect(MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.right}), MatchFormat.oneVsOne);
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right}),
        MatchFormat.twoVsOne,
      );
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.right, 'p3': PuzzleSide.right}),
        MatchFormat.twoVsOne,
      );
      expect(
        MatchFormat.of({'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right, 'p4': PuzzleSide.right}),
        MatchFormat.twoVsTwo,
      );
      expect(MatchFormat.solo.split, isFalse);
      expect(MatchFormat.team.split, isFalse);
      expect(MatchFormat.oneVsOne.split, isTrue);
      expect(MatchFormat.twoVsOne.split, isTrue);
      expect(MatchFormat.twoVsTwo.split, isTrue);
      // A solo player gets the whole field …
      final solo = begin(load('house'), {'p1': PuzzleSide.left});
      expect(solo.sides, hasLength(1));
      expect(solo.sides.single.game.field, PuzzleField.single);
      // … and a race gets a side each, from the split layout, the left first.
      final race = begin(load('house'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final layout = SplitLayout.of(race.puzzle, race.seed);
      expect(race.sides, hasLength(2));
      expect(race.gameOf(PuzzleSide.left).field, same(layout.left));
      expect(race.gameOf(PuzzleSide.right).field, same(layout.right));
    });

    test('both sides start with the same tray', () {
      final m = begin(load('boat'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      for (var i = 0; i < left.pieces.length; i++) {
        // The same angle, and the same place relative to the tray: mirrored.
        expect(right.pieces[i].angle, left.pieces[i].angle, reason: 'piece $i');
        final l = left.pieces[i].pos - left.field.tray.topLeft;
        final r = right.pieces[i].pos - right.field.tray.topLeft;
        expect(r.dx, closeTo(l.dx, 1e-9), reason: 'piece $i x');
        expect(r.dy, closeTo(l.dy, 1e-9), reason: 'piece $i y');
      }
    });

    test('every puzzle fits each half: pieces start in the tray, outlines lie on the board', () {
      for (final id in ['house', 'rocket', 'tree', 'boat']) {
        final puzzle = load(id);
        for (var seed = 0; seed < 20; seed++) {
          final layout = SplitLayout.of(puzzle, seed);
          for (final field in [layout.left, layout.right]) {
            final game = PuzzleGame(puzzle, angles: layout.angles, field: field, random: Random(seed));
            for (final p in game.pieces) {
              final spec = puzzle.pieces[p.index];
              final box = pieceBox(puzzle, game, p);
              expect(
                field.tray.inflate(0.01).contains(box.topLeft) && field.tray.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed ${spec.id} leaves the tray: $box',
              );
              expect(box.overlaps(field.board), isFalse, reason: '$id seed $seed ${spec.id} starts on the board');
            }
            // Every outline lies on the board.
            for (final (i, spec) in puzzle.pieces.indexed) {
              final box = spec.shape.bounds(spec.targetAngle).shift(game.targetAt(i));
              expect(
                field.board.inflate(0.01).contains(box.topLeft) && field.board.inflate(0.01).contains(box.bottomRight),
                isTrue,
                reason: '$id seed $seed ${spec.id} outline leaves the board',
              );
            }
          }
        }
      }
    });
  });

  group('sides', () {
    test('players play only on their own side, and players who did not join just watch', () {
      final m = begin(load('house'), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      m.update(0.016, {'p1': none, 'p2': none, 'p3': none});
      expect(left.player('p1'), isNotNull);
      expect(left.player('p2'), isNull);
      expect(left.player('p3'), isNull);
      expect(right.player('p2'), isNotNull);
      expect(right.player('p1'), isNull);
      expect(right.player('p3'), isNull);
      final p1Before = left.player('p1')!.pos;
      final p2Before = right.player('p2')!.pos;
      drive(m, {'p1': pushRight, 'p2': none, 'p3': none}, frames: 10);
      expect(left.player('p1')!.pos.dx - p1Before.dx, closeTo(24, 1e-6), reason: '48 for half a second');
      expect(right.player('p2')!.pos, p2Before, reason: 'p2 was not pushed');
    });

    test('the first side to finish wins, and the other side stops', () {
      final m = begin(onePiece(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      place(m, left, 'p1', 0, others: {'p2': none});
      final result = m.result!;
      expect(result.winner, PuzzleSide.left);
      expect(result.draw, isFalse);
      expect(result.outcomeFor(PuzzleSide.left), 'win');
      expect(result.outcomeFor(PuzzleSide.right), 'loss');
      expect(result.sides[PuzzleSide.left]!.finished, isTrue);
      expect(result.sides[PuzzleSide.left]!.timeS, isNotNull);
      expect(result.sides[PuzzleSide.right]!.finished, isFalse);
      expect(left.phase, PuzzlePhase.finished);
      expect(right.phase, PuzzlePhase.stopped);
    });

    test('at time-up the side with more pieces placed wins', () {
      final m = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      place(m, left, 'p1', 3, others: {'p2': none}); // the sun, a circle: it fits at any angle
      drive(m, {'p1': none, 'p2': none}, frames: 620); // 31 s
      final result = m.result!;
      expect(result.winner, PuzzleSide.left);
      expect(left.phase, PuzzlePhase.timeUp);
      expect(right.phase, PuzzlePhase.timeUp);
      expect(result.sides[PuzzleSide.left]!.placed, 1);
      expect(result.sides[PuzzleSide.right]!.placed, 0);
    });

    test('equal pieces at time-up is a draw, including none', () {
      final nothing = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      final both = begin(load('house'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.right,
      }, settings: const PuzzleSettings(timeLimitS: 30));
      place(both, both.gameOf(PuzzleSide.left), 'p1', 3, others: {'p2': none});
      place(both, both.gameOf(PuzzleSide.right), 'p2', 3, others: {'p1': none});
      for (final m in [nothing, both]) {
        drive(m, {'p1': none, 'p2': none}, frames: 620); // 31 s
        final result = m.result!;
        expect(result.draw, isTrue);
        expect(result.winner, isNull);
        expect(result.outcomeFor(PuzzleSide.left), 'draw');
        expect(result.outcomeFor(PuzzleSide.right), 'draw');
      }
    });

    test('both sides finishing in the same frame is a draw', () {
      final m = begin(onePiece(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.right});
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      left.player('p1')!.pos = left.pieces[0].pos;
      tap(m, 'p1', {'p2': none});
      right.player('p2')!.pos = right.pieces[0].pos;
      tap(m, 'p2', {'p1': none});
      for (final (game, id) in [(left, 'p1'), (right, 'p2')]) {
        game.player(id)!.pos = game.targetAt(0);
        game.pieces[0].pos = game.targetAt(0);
        game.pieces[0].angle = 0;
      }
      m.update(0.016, {'p1': pressA, 'p2': pressA});
      m.update(0.016, {'p1': none, 'p2': none});
      final result = m.result!;
      expect(result.draw, isTrue);
      expect(result.winner, isNull);
      expect(left.phase, PuzzlePhase.finished);
      expect(right.phase, PuzzlePhase.finished);
    });

    test('on one board a finish is a win and time-up a loss', () {
      final won = begin(onePiece(), {'p1': PuzzleSide.left});
      place(won, won.gameOf(PuzzleSide.left), 'p1', 0);
      final win = won.result!;
      expect(win.outcomeFor(PuzzleSide.left), 'win');
      expect(win.draw, isFalse);
      expect(win.winner, isNull);
      // Time runs out with nothing placed.
      final timed = begin(onePiece(), {'p1': PuzzleSide.left}, settings: const PuzzleSettings(timeLimitS: 30));
      drive(timed, {'p1': none}, frames: 620); // 31 s
      final loss = timed.result!;
      expect(loss.outcomeFor(PuzzleSide.left), 'loss');
      expect(loss.draw, isFalse);
    });
  });

  group('big pieces', () {
    // Two teammates on one board: the crate is piece 0, the ball piece 1.
    PuzzleMatch teamMatch() => begin(crateAndBall(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.left});

    /// Both teammates take the crate, side by side.
    PuzzleMatch bothCarrying() {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos + const Offset(-3, 0);
      tap(m, 'p1', {'p2': none});
      game.player('p2')!.pos = crate.pos + const Offset(3, 0);
      tap(m, 'p2', {'p1': none});
      return m;
    }

    test('two teammates carry a big piece at normal speed, following the average of their pushes', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos + const Offset(-3, 0);
      tap(m, 'p1', {'p2': none});
      game.player('p2')!.pos = crate.pos + const Offset(3, 0);
      final joining = tap(m, 'p2', {'p1': none});
      final pickup = joining.singleWhere((e) => e.event.kind == PuzzleEventKind.pickup);
      expect(pickup.event.playerId, 'p2');
      expect(pickup.event.data['joined'], isTrue, reason: 'the second end of a big piece');
      expect(crate.carriers, ['p1', 'p2']);
      expect(crate.calling, isFalse);
      final at = crate.pos;
      drive(m, {'p1': pushRight, 'p2': pushRight}, frames: 10);
      expect(crate.pos.dx - at.dx, closeTo(24, 1e-6), reason: '48 for half a second');
      final p1 = game.player('p1')!;
      final p2 = game.player('p2')!;
      expect(p1.pos.dx - crate.pos.dx, closeTo(-3, 1e-6));
      expect(p1.pos.dy - crate.pos.dy, closeTo(0, 1e-6));
      expect(p2.pos.dx - crate.pos.dx, closeTo(3, 1e-6));
      expect(p2.pos.dy - crate.pos.dy, closeTo(0, 1e-6));
      // Pushed opposite ways, the average is zero.
      final still = crate.pos;
      drive(m, {'p1': pushRight, 'p2': pushLeft}, frames: 10);
      expect(crate.pos.dx - still.dx, closeTo(0, 1e-6));
      // One pushing, one still: half the speed.
      final before = crate.pos;
      drive(m, {'p1': pushRight, 'p2': none}, frames: 10);
      expect(crate.pos.dx - before.dx, closeTo(12, 1e-6), reason: 'half the push for half a second');
    });

    test('carried alone it moves slowly and its edge calls the teammate, who feels a help call at once and then every '
        'interval', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      game.player('p1')!.pos = crate.pos;
      tap(m, 'p1', {'p2': none});
      final before = crate.pos;
      drive(m, {'p1': pushRight, 'p2': none}, frames: 20);
      expect(crate.pos.dx - before.dx, closeTo(16.8, 1e-6), reason: '48 × 0.35 for a second');
      expect(crate.calling, isTrue);
      final board = m.snapshot().boards.single;
      expect(board.pieces[0].calling, isTrue);
      expect(board.pieces[0].holders, [1]);

      // The call comes at once, then every help interval: three in seven
      // seconds.
      final fresh = teamMatch();
      final freshGame = fresh.gameOf(PuzzleSide.left);
      final freshCrate = freshGame.pieces[0];
      freshGame.player('p1')!.pos = freshCrate.pos;
      final events = [
        ...tap(fresh, 'p1', {'p2': none}),
        ...drive(fresh, {'p1': none, 'p2': none}, frames: 140),
      ];
      final helps = events.where((e) => e.event.kind == PuzzleEventKind.help).toList();
      expect(helps, hasLength(3));
      for (final e in helps) {
        expect(e.event.playerId, 'p2');
        expect(e.event.data['from'], 'p1');
      }
      expect(freshGame.player('p1')!.helpCalls, 3);
      expect(freshGame.player('p1')!.soloBigCarries, 1);
      expect(freshGame.player('p1')!.soloBigS, closeTo(7.05, 0.1));
      // p2 takes the other end: no more calls.
      freshGame.player('p2')!.pos = freshCrate.pos + const Offset(3, 0);
      tap(fresh, 'p2', {'p1': none});
      expect(freshCrate.calling, isFalse);
      final later = drive(fresh, {'p1': none, 'p2': none}, frames: 140);
      expect(later.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);
    });

    test('either carrier drops it, and both let go with the one press', () {
      final m = bothCarrying();
      final game = m.gameOf(PuzzleSide.left);
      final crate = game.pieces[0];
      crate.pos = game.targetAt(0);
      crate.angle = 0;
      final events = [
        ...m.update(0.016, {'p1': pressA, 'p2': pressA}),
        ...m.update(0.016, {'p1': none, 'p2': none}),
      ];
      final snaps = events.where((e) => e.event.kind == PuzzleEventKind.snap).toList();
      expect(snaps, hasLength(1), reason: 'the second carrier does not drop it twice');
      expect(['p1', 'p2'], contains(snaps.single.event.playerId));
      expect(events.where((e) => e.event.kind == PuzzleEventKind.pickup), isEmpty);
      expect(crate.state, PieceState.locked);
      expect(crate.carriers, isEmpty);
      expect(game.player('p1')!.held, isNull);
      expect(game.player('p2')!.held, isNull);
    });

    test('only a big piece can be shared: an ordinary held piece still cannot be taken', () {
      final m = teamMatch();
      final game = m.gameOf(PuzzleSide.left);
      final ball = game.pieces[1];
      game.player('p1')!.pos = ball.pos;
      tap(m, 'p1', {'p2': none});
      expect(ball.carriers, ['p1']);
      game.player('p2')!.pos = ball.pos;
      final events = tap(m, 'p2', {'p1': none});
      expect(events.where((e) => e.event.kind == PuzzleEventKind.pickup), isEmpty);
      expect(game.player('p2')!.held, isNull);
      expect(ball.carriers, ['p1']);
    });

    test(
      'when one carrier leaves the other carries on, and alone in the game it is an ordinary piece at full speed',
      () {
        final m = bothCarrying();
        final game = m.gameOf(PuzzleSide.left);
        final crate = game.pieces[0];
        m.update(0.05, {'p1': none}); // p2 is missing from the inputs, so it leaves
        expect(crate.state, PieceState.held);
        expect(crate.carriers, ['p1']);
        expect(game.team, isFalse);
        final before = crate.pos;
        final events = drive(m, {'p1': pushRight}, frames: 10);
        expect(crate.pos.dx - before.dx, closeTo(24, 1e-6), reason: 'full speed alone in the game');
        // Carried now as an ordinary piece, p1's dot keeps the grab it took its
        // end by (s14).
        expect(crate.pos.dx - game.player('p1')!.pos.dx, closeTo(3, 1e-6));
        expect(crate.pos.dy - game.player('p1')!.pos.dy, closeTo(0, 1e-6));
        expect(crate.calling, isFalse);
        expect(events.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);
      },
    );

    test('a solo player carries big pieces at full speed, also as the lone side of a 2 vs 1', () {
      final solo = begin(crateAndBall(), {'p1': PuzzleSide.left});
      final soloGame = solo.gameOf(PuzzleSide.left);
      final soloCrate = soloGame.pieces[0];
      soloGame.player('p1')!.pos = soloCrate.pos;
      tap(solo, 'p1', {});
      final soloBefore = soloCrate.pos;
      final soloEvents = drive(solo, {'p1': pushRight}, frames: 10);
      expect(soloCrate.pos.dx - soloBefore.dx, closeTo(24, 1e-6), reason: 'alone on the side, full speed');
      expect(soloEvents.where((e) => e.event.kind == PuzzleEventKind.help), isEmpty);

      final m = begin(crateAndBall(), {'p1': PuzzleSide.left, 'p2': PuzzleSide.left, 'p3': PuzzleSide.right});
      expect(m.format, MatchFormat.twoVsOne);
      final left = m.gameOf(PuzzleSide.left);
      final right = m.gameOf(PuzzleSide.right);
      final leftCrate = left.pieces[0];
      final rightCrate = right.pieces[0];
      left.player('p1')!.pos = leftCrate.pos;
      tap(m, 'p1', {'p2': none, 'p3': none});
      right.player('p3')!.pos = rightCrate.pos;
      tap(m, 'p3', {'p1': none, 'p2': none});
      final leftBefore = leftCrate.pos;
      final rightBefore = rightCrate.pos;
      drive(m, {'p1': pushRight, 'p2': none, 'p3': pushRight}, frames: 10);
      expect(rightCrate.pos.dx - rightBefore.dx, closeTo(24, 1e-6), reason: 'p3 is alone on its side');
      expect(leftCrate.pos.dx - leftBefore.dx, closeTo(8.4, 1e-6), reason: '48 × 0.35 for half a second');
    });
  });

  group('snapshots', () {
    test('a match snapshot keeps both boards, the carriers and the call, and stays under 2 KB with 4 players on the '
        'biggest puzzle', () {
      final m = begin(load('boat'), {
        'p1': PuzzleSide.left,
        'p2': PuzzleSide.left,
        'p3': PuzzleSide.right,
        'p4': PuzzleSide.right,
      });
      final left = m.gameOf(PuzzleSide.left);
      final hull = left.puzzle.pieces.indexWhere((p) => p.id == 'hull');
      expect(hull, isNot(-1));
      left.player('p1')!.pos = left.pieces[hull].pos;
      tap(m, 'p1', {'p2': none, 'p3': none, 'p4': none});
      final s = m.snapshot();
      expect(s.boards, hasLength(2));
      expect(s.seed, m.seed);
      final encoded = s.encode();
      expect(MatchSnapshot.decode(encoded).encode(), encoded);
      final back = MatchSnapshot.decode(encoded);
      expect(back.seed, m.seed);
      expect(back.boards[0].pieces[hull].calling, isTrue);
      expect(back.boards[0].pieces[hull].holders, [1]);
      expect(encoded.length, lessThan(PuzzleSnapshot.maxBytes));
    });

    test('a split snapshot keeps the seed and the pile order, a one-board one has neither', () {
      final puzzle = twoSquares();
      final m = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left, 'p2': PuzzleSide.right}, random: Random(1));
      m.update(0.016, const {'p1': none, 'p2': none}, numbers: const {'p1': 1, 'p2': 2});
      final left = m.gameOf(PuzzleSide.left);
      // The first piece goes down off the board: it now lies on top, so the
      // order changes.
      left.player('p1')!.pos = left.pieces[0].pos;
      tap(m, 'p1', {'p2': none});
      expect(left.player('p1')!.held, 0);
      left.pieces[0].pos = left.field.tray.center;
      tap(m, 'p1', {'p2': none});
      expect(left.pieces[0].state, PieceState.loose);
      expect(left.pieces[0].layer, greaterThan(left.pieces[1].layer));

      final s = m.snapshot();
      expect(s.seed, m.seed);
      expect(s.boards[0].order, [1, 0]);
      final encoded = s.encode();
      final back = MatchSnapshot.decode(encoded);
      expect(back.encode(), encoded);
      expect(back.seed, m.seed);
      expect(back.boards[0].order, [1, 0]);
      expect(back.boards[1].order, [0, 1]);

      // One board: the seed and the identity order stay out of the JSON.
      final solo = PuzzleMatch(puzzle, teams: const {'p1': PuzzleSide.left}, random: Random(3));
      solo.update(0.016, const {'p1': none}, numbers: const {'p1': 1});
      final board = solo.snapshot();
      expect(board.seed, isNull);
      expect(board.toJson().containsKey('sd'), isFalse);
      expect(board.boards.single.toJson().containsKey('o'), isFalse);
    });

    test('a one-board phones match plays the layout\'s left world and keeps its seed in the snapshot', () {
      final puzzle = load('house');
      final m = PuzzleMatch(
        puzzle,
        teams: const {'p1': PuzzleSide.left},
        random: Random(1),
        target: LayoutTarget.phones,
      );
      final layout = SplitLayout.of(puzzle, m.seed, target: LayoutTarget.phones);
      expect(m.sides, hasLength(1));
      expect(m.gameOf(PuzzleSide.left).field, same(layout.left));
      expect(m.gameOf(PuzzleSide.left).angles, layout.angles);
      final s = m.snapshot();
      expect(s.boards, hasLength(1));
      expect(s.seed, m.seed);
      expect(s.toJson()['sd'], m.seed);
      expect(MatchSnapshot.decode(s.encode()).seed, m.seed);
    });
  });
}
