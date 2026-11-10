import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

const tray = PieceState.tray;
const locked = PieceState.locked;

/// A board of [states], on [phase], with its pieces at the board's middle.
PuzzleSnapshot board(List<PieceState> states, {PuzzlePhase phase = PuzzlePhase.playing}) => PuzzleSnapshot(
  puzzleId: 'celebrate',
  timeLeftMs: phase == PuzzlePhase.playing ? 60000 : 0,
  phase: phase,
  pieces: [for (final state in states) PieceView(x: 40, y: 40, angle: 0, state: state)],
  players: const [],
);

MatchSnapshot matchOf(PuzzleSnapshot board) => MatchSnapshot(boards: [board]);

void main() {
  test('the celebration starts on the frame the board finishes, and not before', () {
    final moments = PieceMoments();
    moments.observe(matchOf(board([locked, locked, tray])), 0);
    expect(moments.finishAgeMs(0, 0), isNull, reason: 'the picture is not finished');

    moments.observe(matchOf(board([locked, locked, locked], phase: PuzzlePhase.finished)), 500);
    expect(moments.finishAgeMs(0, 500), 0, reason: 'it starts on the frame the last piece goes in');
    expect(moments.finishAgeMs(0, 800), 300);
  });

  test('a view built on a board that is already finished does not celebrate it', () {
    // A phone that joins after the picture is done shows the picture, as a
    // view that starts mid-round shows the board (PieceMoments' own rule).
    final moments = PieceMoments();
    moments.observe(matchOf(board([locked, locked, locked], phase: PuzzlePhase.finished)), 1000);
    expect(moments.finishAgeMs(0, 2000), isNull);
  });

  test('the pieces pop in the order they were placed, 120 ms apart', () {
    final moments = PieceMoments();
    moments.observe(matchOf(board([tray, tray, tray])), 0);
    moments.observe(matchOf(board([tray, tray, locked])), 100);
    moments.observe(matchOf(board([locked, tray, locked])), 200);
    moments.observe(matchOf(board([locked, locked, locked], phase: PuzzlePhase.finished)), 300);

    expect(moments.placeOf(0, 2), 0, reason: 'the last piece in was the middle one');
    expect(moments.placeOf(0, 0), 1);
    expect(moments.placeOf(0, 1), 2, reason: 'the piece in the last pop waits longest');

    // The pops follow the places: the first pops at once, the next 120 ms
    // later, the third 240 ms later, each to 110% and back over 240 ms.
    expect(Celebration.popStartMs(0), 0);
    expect(Celebration.popStartMs(1), 120);
    expect(Celebration.popStartMs(2), 240);
    expect(Celebration.popScale(0, 120), closeTo(1.10, 1e-9), reason: 'its pop is at 110% half way');
    expect(Celebration.popScale(1, 120), 1.0, reason: 'the second piece has just started to pop');
    expect(Celebration.popScale(1, 240), closeTo(1.10, 1e-9));
    expect(Celebration.popScale(2, 120), 1.0, reason: 'the third waits 240 ms');
    expect(Celebration.popScale(0, 240), 1.0, reason: 'a pop is a squash and back, not a step');
  });

  test('the whole moment is over after 2.5 s', () {
    expect(Celebration.totalMs, 2500);
    expect(Celebration.isRunning(0), isTrue);
    expect(Celebration.isRunning(2499), isTrue);
    expect(Celebration.isRunning(2500), isFalse);
    expect(Celebration.popScale(0, 2500), 1.0);
    expect(Celebration.glowAlpha(2500), 0);
    expect(Celebration.starsOf(2500, boardRect), isEmpty);
    expect(Celebration.confettiOf(2500, boardRect), isEmpty);
  });

  test('with the effects off the picture stands still and the glow is a still rim', () {
    for (final age in [0, 60, 120, 600, 1200, 2400]) {
      for (final place in [0, 1, 2]) {
        expect(Celebration.popScale(place, age, effects: false), 1.0, reason: 'no pop with the effects off');
      }
    }
    expect(Celebration.glowAlpha(100, effects: false), greaterThan(0), reason: 'the rim is still there');
    expect(
      Celebration.glowAlpha(2000, effects: false),
      Celebration.glowAlpha(100, effects: false),
      reason: 'and it does not breathe',
    );
    expect(Celebration.confettiOf(600, boardRect, effects: false), isEmpty, reason: 'no falling confetti');

    final appeared = Celebration.starsOf(600, boardRect, effects: false);
    final later = Celebration.starsOf(1800, boardRect, effects: false);
    expect(appeared, hasLength(Celebration.stars));
    expect(later, hasLength(appeared.length));
    for (var i = 0; i < appeared.length; i++) {
      expect(later[i].at, appeared[i].at, reason: 'the stars stand where they appeared');
      expect(later[i].alpha, appeared[i].alpha);
    }
  });

  test('the stars and the confetti never cross the picture', () {
    var stars = 0;
    var confetti = 0;
    for (var age = 0; age < Celebration.totalMs; age += 50) {
      for (final star in Celebration.starsOf(age, boardRect)) {
        stars++;
        expect(
          boardRect.inflate(star.radius).contains(star.at),
          isFalse,
          reason: 'a star at ${star.at} at $age ms covers part of the picture',
        );
      }
      for (final bit in Celebration.confettiOf(age, boardRect)) {
        confetti++;
        final rect = Rect.fromCenter(center: bit.at, width: bit.wide, height: bit.tall);
        expect(boardRect.overlaps(rect), isFalse, reason: 'confetti at ${bit.at} at $age ms is over the picture');
      }
    }
    expect(stars, greaterThan(0));
    expect(confetti, greaterThan(0));
  });

  test('the glow breathes once and never flashes', () {
    var last = Celebration.glowAlpha(0);
    var rising = true;
    var turns = 0;
    for (var age = 25; age <= Celebration.totalMs; age += 25) {
      final alpha = Celebration.glowAlpha(age);
      final delta = alpha - last;
      expect(delta.abs(), lessThan(0.12), reason: 'a step at $age ms: $last to $alpha');
      if ((rising && delta < 0) || (!rising && delta > 0)) {
        turns++;
        rising = !rising;
      }
      last = alpha;
    }
    expect(turns, 1, reason: 'one fade up and one down: the brightness changes once (G5)');
  });
}
