import 'dart:math';
import 'dart:typed_data';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart' show ToyColors;

import 'support/frames.dart';
import 'support/match_helpers.dart' as helpers;

final puzzle = helpers.load('house');

/// The bar's fill in the look the tests draw: the look's `good`, which the fill
/// is drawn flat in (the shaded track is no one colour).
final good = ToyColors.sunny.good.toARGB32() & 0xFFFFFF;

/// The house played with a clock of this many seconds: the bar is only a share
/// of the way when the clock holds [timeLeftMs].
const limitS = 120;
const timeLeftMs = 45000;

/// The house's board with every piece placed (B-001): the picture is done, so
/// only the bar's rule decides how far it is filled.
PuzzleSnapshot placedBoard({
  required PuzzlePhase phase,
  int clockMs = timeLeftMs,
  PuzzleSide? side,
  List<PlayerView> players = const [],
}) => PuzzleSnapshot(
  puzzleId: puzzle.id,
  timeLeftMs: clockMs,
  phase: phase,
  side: side,
  pieces: [for (final _ in puzzle.pieces) const PieceView(x: 80, y: 50, angle: 0, state: PieceState.locked)],
  players: players,
);

/// The clause a full-clock bar is measured against: a bar of the clock fills
/// all the way while the clock has all its time.
const fullClockMs = limitS * 1000;

/// The house's board mid-round, with [clockMs] on the clock: every piece is
/// still in the tray, so only the clock can fill the bar.
PuzzleSnapshot trayBoard({int clockMs = timeLeftMs, PuzzleSide? side, List<PlayerView> players = const []}) =>
    PuzzleSnapshot(
      puzzleId: puzzle.id,
      timeLeftMs: clockMs,
      phase: PuzzlePhase.playing,
      side: side,
      pieces: [for (final _ in puzzle.pieces) const PieceView(x: 80, y: 50, angle: 0, state: PieceState.tray)],
      players: players,
    );

typedef Frame = (int, int, Uint8List);

/// The rightmost column of [colour] inside [region] of [frame], in px; null
/// when that colour is not drawn there.
int? rightmost(Frame frame, Rect region, int colour) {
  final (width, height, bytes) = frame;
  final top = region.top.round().clamp(0, height - 1);
  final bottom = region.bottom.round().clamp(0, height);
  final last = region.right.round().clamp(0, width - 1);
  int? found;
  for (var y = top; y < bottom; y++) {
    for (var x = last; x >= region.left.round(); x--) {
      if (pixel(bytes, width, x, y) == colour) {
        if (found == null || x > found) found = x;
        break;
      }
    }
  }
  return found;
}

/// Where the bar's fill ends in [frame], in px: the rightmost column of the
/// look's `good` in [region], the only place it is drawn.
int fillEnd(Frame frame, Rect region) => rightmost(frame, region, good)!;

void main() {
  group('B-001: the bar is full when every piece is placed', () {
    // The one-board field's clock strip: the HUD's bar spans the board's left
    // edge to the tray's right, at the bottom of the strip (board_hud.dart).
    final strip = Rect.fromLTWH(0, 0, 960, hudHeight * fieldIn(const Size(960, 540)).scale);

    /// The one board of [snapshot] drawn on a TV.
    Future<Frame> oneBoard(WidgetTester tester, PuzzleSnapshot snapshot) => capture(
      tester,
      PuzzleView(puzzle: puzzle, snapshot: snapshot, timeLimitS: limitS),
      window: const Size(960, 540),
      box: const Size(960, 540),
    );

    testWidgets('a solo board: the bar fills to its end on the last piece', (tester) async {
      final full = await oneBoard(tester, trayBoard(clockMs: fullClockMs));
      // With 45 s of 120 left, a bar of the clock fills 3/8 of the way.
      final midRound = await oneBoard(tester, trayBoard(clockMs: timeLeftMs));
      final done = await oneBoard(tester, placedBoard(phase: PuzzlePhase.finished));
      final end = fillEnd(full, strip);
      expect(fillEnd(midRound, strip), lessThan(end - 50), reason: 'mid-round the clock drains the bar');
      expect(fillEnd(done, strip), closeTo(end, 2), reason: 'every piece placed fills the bar');
    });

    testWidgets('a co-op board: the bar fills to its end on the last piece', (tester) async {
      const players = [PlayerView(number: 1, x: 40, y: 60), PlayerView(number: 2, x: 120, y: 60)];
      Future<Frame> board(PuzzleSnapshot snapshot) => capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(boards: [snapshot]),
          timeLimitS: limitS,
        ),
        window: const Size(960, 540),
        box: const Size(960, 540),
      );
      final full = await board(trayBoard(clockMs: fullClockMs, players: players));
      final midRound = await board(trayBoard(clockMs: timeLeftMs, players: players));
      final done = await board(placedBoard(phase: PuzzlePhase.finished, players: players));
      final end = fillEnd(full, strip);
      expect(fillEnd(midRound, strip), lessThan(end - 50), reason: 'mid-round the clock drains the bar');
      expect(fillEnd(done, strip), closeTo(end, 2), reason: 'every piece placed fills the bar');
    });

    testWidgets('a race: the split screen\'s bar fills to its end on the last piece', (tester) async {
      const box = Size(960, 540);
      const seed = 3;
      final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.screen);
      final f = fieldIn(box);
      // The bar sits in the strip along the top, or in the gap between the
      // boards, where no board is (match_hud.dart).
      final region = layout.hudStrip
          ? Rect.fromLTWH(0, 0, box.width, SplitLayout.stripHeight * f.scale)
          : Rect.fromLTRB(
              f.origin.dx + layout.leftBox.right * f.scale,
              0,
              f.origin.dx + layout.rightBox.left * f.scale,
              box.height,
            );
      Future<Frame> race(PuzzleSnapshot left) => capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(
            seed: seed,
            boards: [
              left,
              trayBoard(side: PuzzleSide.right),
            ],
          ),
          timeLimitS: limitS,
        ),
        window: box,
        box: box,
      );
      final full = await race(trayBoard(clockMs: fullClockMs, side: PuzzleSide.left));
      final midRound = await race(trayBoard(clockMs: timeLeftMs, side: PuzzleSide.left));
      final done = await race(placedBoard(phase: PuzzlePhase.finished, side: PuzzleSide.left));
      final end = fillEnd(full, region);
      expect(fillEnd(midRound, region), lessThan(end - 10), reason: 'mid-round the clock drains the bar');
      expect(fillEnd(done, region), closeTo(end, 2), reason: 'the winning side fills the bar');
    });

    testWidgets('a phone: the bar fills to its end on the last piece', (tester) async {
      const box = Size(852, 393);
      const seed = 3;
      const camera = PuzzleCamera.side(PuzzleSide.left);
      final layout = SplitLayout.of(puzzle, seed, target: LayoutTarget.phones);
      Future<Frame> phone(PuzzleSnapshot board) => capture(
        tester,
        MatchView(
          puzzle: puzzle,
          snapshot: MatchSnapshot(seed: seed, boards: [board]),
          timeLimitS: limitS,
          target: LayoutTarget.phones,
          camera: camera,
        ),
        window: box,
        box: box,
      );

      /// The bar's rows in the HUD area (match_painter.dart).
      Rect barRows(MatchSnapshot s) {
        final hud = phoneHud(s, PuzzleSide.left);
        final scores = (score: hud.score, short: hud.short);
        final mirror = PuzzleCamera.mirrorPlace(puzzle, layout, camera, box, split: s.split, text: scores);
        final rect = PuzzleCamera.hudPlace(layout, camera, box, scores, mirror: mirror?.rect).rect;
        final unit = PuzzleCamera.hudUnit(box);
        return Rect.fromLTRB(rect.left, rect.bottom - unit * PuzzleCamera.hudBarFraction, rect.right, rect.bottom);
      }

      final full = await phone(trayBoard(clockMs: fullClockMs, side: PuzzleSide.left));
      final midRound = await phone(trayBoard(clockMs: timeLeftMs, side: PuzzleSide.left));
      final done = await phone(placedBoard(phase: PuzzlePhase.finished, side: PuzzleSide.left));
      final region = barRows(
        MatchSnapshot(
          seed: seed,
          boards: [trayBoard(clockMs: timeLeftMs)],
        ),
      );
      final end = fillEnd(full, region);
      expect(fillEnd(midRound, region), lessThan(end - 10), reason: 'mid-round the clock drains the bar');
      expect(fillEnd(done, region), closeTo(end, 2), reason: 'every piece placed fills the bar');
    });
  });

  test('the phone panel\'s bar is full once the picture is done', () {
    var nowMs = 0;
    var elapsed = Duration.zero;
    final host = MemoryGameHost(now: () => nowMs)
      ..setPlayer(const GamePlayer(id: 'p1', number: 1))
      ..setGamepad('p1', const GamepadState(mode: InputMode.dpad));
    final session = PuzzleSession(
      host: host,
      puzzle: puzzle,
      teams: const {'p1': PuzzleSide.left},
      random: Random(1),
      playtest: () => const PuzzleSettings(timeLimitS: 10),
    );
    void frame(int ms) {
      nowMs += ms;
      elapsed += Duration(milliseconds: ms);
      session.advance(elapsed);
    }

    // Half the clock gone: a bar of the clock would be half full.
    for (var i = 0; i < 50; i++) {
      frame(100);
    }
    final game = session.match.sides.first.game;
    expect(game.timeLeftS, closeTo(5, 0.2), reason: 'the clock has half its 10 s left');
    for (var i = 0; i < game.pieces.length; i++) {
      game.pieces[i]
        ..state = PieceState.locked
        ..pos = game.targetAt(i);
    }
    for (var i = 0; i < 5; i++) {
      frame(16);
    }
    expect(session.match.result, isNotNull, reason: 'the picture finished the round');
    expect(host.statuses['p1']!.progress, 1.0, reason: 'the panel says how far the round has gone: all of it');
  });
}
