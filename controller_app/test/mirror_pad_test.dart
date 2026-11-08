import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:controller/src/ui/top_bar_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:puzzle_game/puzzle_game.dart' hide phonePxPerMm;

import 'support/host_app.dart';
import 'support/joined.dart';
import 'support/mirror_boards.dart';

/// The three phone sizes the layout is tested at (m12-phone-layout §0.2): the
/// owner's iPhone, the iPhone 15 and the smallest 16:9 phone.
const iphone = Size(852, 393);
const phone15 = Size(734, 370);
const phone169 = Size(667, 375);

/// Every puzzle the library ships, by ID, in its index's order.
Map<String, Puzzle> loadPuzzles() {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return {
    for (final id in (index['puzzles'] as List).cast<String>())
      id: Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  };
}

/// The camera a phone plays the left side with.
const sideLeft = PuzzleCamera.side(PuzzleSide.left);

/// A race's HUD on a phone with nothing placed, as the game measures it.
({String score, List<String> short}) raceText(Puzzle puzzle) {
  final n = puzzle.pieces.length;
  return (score: 'You 0/$n · Right 0/$n', short: ['You 0/$n', 'Right 0/$n']);
}

/// The mirror [box] draws for [puzzle]'s race with [pad] over the game, or
/// null.
MirrorPlacement? mirrorWith(Puzzle puzzle, Size box, List<Rect> pad) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  return PuzzleCamera.mirrorPlace(
    puzzle,
    layout,
    sideLeft,
    box,
    split: true,
    text: raceText(puzzle),
    pxPerMm: phonePxPerMm,
    padRects: pad,
  );
}

/// The mirror [box] draws for [puzzle]'s race with the app's [mode] pad on the
/// screen, or null.
MirrorPlacement? mirrorOf(Puzzle puzzle, Size box, PadMode mode) =>
    mirrorWith(puzzle, box, leftPadRects(box, mode: mode, mm: phonePxPerMm));

/// [rect] of [layout]'s own world as [box] draws it, in the box's px.
Rect onScreen(SplitLayout layout, Size box, Rect rect) {
  final place = PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left);
  return Rect.fromLTWH(
    place.origin.dx + rect.left * place.scale,
    place.origin.dy + rect.top * place.scale,
    rect.width * place.scale,
    rect.height * place.scale,
  );
}

/// The left hand's controls as the app draws them in [box], in the shapes
/// [ControlShape] measures overlap with: the same geometry [leftPadRects]
/// reports, worked out here from the layouts instead, so the two check each
/// other. The bar the game shows through is at the screen's top.
List<ControlShape> drawnLeft(Size box, PadMode mode) {
  final body = Size(box.width, box.height - topBarHeightPx);
  final bar = const Offset(0, topBarHeightPx);
  List<ControlShape> arms(Rect dpad) => [
    for (final (_, arm) in dpadArms(dpad.width)) ControlShape.rect(arm.shift(dpad.topLeft + bar)),
  ];
  switch (mode) {
    case PadMode.dpad:
      return arms(padLayout(body, mm: phonePxPerMm).dpad);
    case PadMode.sticks:
      final layout = stickLayout(body, mm: phonePxPerMm);
      return [ControlShape.circle(layout.leftStick.shift(bar)), ...arms(layout.dpad)];
    case PadMode.gyro:
      return [ControlShape.rect(padLayout(body, mm: phonePxPerMm).leftArea.shift(bar))];
  }
}

void main() {
  final puzzles = loadPuzzles();

  group('the pad the app passes the game', () {
    test('is where the left hand\'s controls are drawn, per mode, under the bar', () {
      final body = Size(iphone.width, iphone.height - topBarHeightPx);
      final bar = const Offset(0, topBarHeightPx);
      // D-pad mode: the D-pad's four arms, inside its square at the body's
      // bottom left.
      final dpad = padLayout(body).dpad;
      expect(leftPadRects(iphone, mode: PadMode.dpad, mm: phonePxPerMm), [
        for (final (_, arm) in dpadArms(dpad.width)) arm.shift(dpad.topLeft + bar),
      ], reason: 'the drawn arms alone: the square\'s corners are empty');
      // Stick mode: the left stick's disc (its square holds it) and the D-pad's
      // arms below it; a floating stick may start anywhere in its zone.
      final sticks = stickLayout(body);
      expect(leftPadRects(iphone, mode: PadMode.sticks, mm: phonePxPerMm), [
        sticks.leftStick.shift(bar),
        for (final (_, arm) in dpadArms(sticks.dpad.width)) arm.shift(sticks.dpad.topLeft + bar),
      ]);
      expect(
        leftPadRects(iphone, mode: PadMode.sticks, mm: phonePxPerMm, sticks: const StickSettings(floating: true)).first,
        sticks.leftZone.shift(bar),
        reason: 'a floating stick may be anywhere in its zone',
      );
      // Gyro mode: the area the tilt view fills.
      expect(leftPadRects(iphone, mode: PadMode.gyro, mm: phonePxPerMm), [padLayout(body).leftArea.shift(bar)]);
      // A screen too short for a body has no pad to keep clear of.
      expect(leftPadRects(const Size(852, 40), mode: PadMode.dpad, mm: phonePxPerMm), isEmpty);
    });

    testWidgets('puts the D-pad exactly where the app says it is, under the bar', (tester) async {
      // A joined phone at 852 x 393: the same size the test's layout uses.
      await joined(tester);
      final dpad = tester.getRect(find.byKey(const Key('dpad')));
      final rects = leftPadRects(iphone, mode: PadMode.dpad, mm: phonePxPerMm);
      expect(rects.map((r) => r.left).reduce(min), dpad.left);
      expect(rects.map((r) => r.top).reduce(min), dpad.top);
      expect(rects.map((r) => r.right).reduce(max), dpad.right);
      expect(rects.map((r) => r.bottom).reduce(max), dpad.bottom);
      expect(
        dpad.top,
        greaterThanOrEqualTo(topBarHeightPx),
        reason: 'the bar\'s 52 px are the game\'s, not the pad\'s',
      );
    });
  });

  group('the mirror and the pad (m12-opponent-mirror rule 3, code-health N4)', () {
    test('the mirror never meets a control the app draws, in any mode or phone size', () {
      for (final box in const [iphone, phone15, phone169]) {
        for (final mode in PadMode.values) {
          final shapes = drawnLeft(box, mode);
          final pad = leftPadRects(box, mode: mode, mm: phonePxPerMm);
          for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
            final where = '$id, $mode, $box';
            final mirror = mirrorOf(puzzle, box, mode);
            if (mirror == null) continue;
            for (final rect in pad) {
              expect(rect.overlaps(mirror.rect), isFalse, reason: where);
            }
            for (final shape in shapes) {
              expect(
                shape.distanceTo(ControlShape.rect(mirror.rect)),
                greaterThan(0),
                reason: '$where: the mirror is clear of the control drawn at ${shape.bounds}',
              );
            }
          }
        }
      }
    });

    test('the corner with the D-pad, the gap with the stick, the tilt view over both', () {
      // Rule 8's one placement rule: the box's top left first, then the gap
      // under the clock between the pad and the board. The D-pad leaves the
      // corner free; the left stick's disc takes it, so the stick's mirror is
      // under the clock, which stays where the phone without a mirror draws it;
      // the tilt view fills the left area from the corner to the board, so no
      // place is clear of it (question 2 in the report).
      for (final box in const [iphone, phone15, phone169]) {
        for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
          final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
          final where = '$id at $box';
          final board = onScreen(layout, box, layout.left.board);
          final tray = onScreen(layout, box, layout.left.tray);
          final corner = mirrorOf(puzzle, box, PadMode.dpad);
          if (corner != null) {
            expect(corner.rect.left, PuzzleCamera.hudMarginPx, reason: where);
            expect(corner.rect.top, closeTo(box.height * PuzzleCamera.hudTopFraction, 1e-9), reason: where);
            // The clock area keeps today's corner picture: the short form to
            // the mirror's right (rule 5), clear of the world.
            expect(corner.hud.form, HudForm.short, reason: where);
            expect(corner.hud.rect.left, closeTo(corner.rect.right + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
          }
          final stick = mirrorOf(puzzle, box, PadMode.sticks);
          if (stick != null) {
            final disc = leftPadRects(box, mode: PadMode.sticks, mm: phonePxPerMm).first;
            final alone = PuzzleCamera.hudPlace(layout, sideLeft, box, raceText(puzzle));
            // Under the clock, where the box without a mirror puts it, and to
            // the right of the disc: the gap between the pad and the board.
            expect(stick.hud, alone, reason: where);
            expect(stick.rect.top, closeTo(alone.rect.bottom + PuzzleCamera.mirrorGapPx, 1e-9), reason: where);
            expect(stick.rect.left, greaterThanOrEqualTo(disc.right + PuzzleCamera.mirrorGapPx - 1e-9), reason: where);
          }
          for (final mirror in [corner, stick]) {
            if (mirror == null) continue;
            expect(mirror.rect.overlaps(board), isFalse, reason: where);
            expect(mirror.rect.overlaps(tray), isFalse, reason: where);
            expect(mirror.rect.overlaps(mirror.hud.rect), isFalse, reason: where);
            expect(mirror.rect.right, lessThanOrEqualTo(box.width + 1e-9), reason: where);
            expect(mirror.rect.bottom, lessThanOrEqualTo(box.height + 1e-9), reason: where);
          }
          expect(mirrorOf(puzzle, box, PadMode.gyro), isNull, reason: '$where: the tilt view covers both places');
        }
      }
    });

    test('which puzzles keep the mirror, phone by phone and mode by mode', () {
      List<String> kept(Size box, PadMode mode) => [
        for (final MapEntry(key: id, value: puzzle) in puzzles.entries)
          if (mirrorOf(puzzle, box, mode) != null) id,
      ];
      // The D-pad leaves the corner free, so the mirror is the board's top left
      // as it is with no pad, and the clock area's room decides the rest (the
      // table s11 pinned): the boat's world leaves no room on the 15, and only
      // the tree's fits on the 16:9 phone.
      expect(kept(iphone, PadMode.dpad), ['house', 'rocket', 'tree', 'boat']);
      expect(kept(phone15, PadMode.dpad), ['house', 'rocket', 'tree']);
      expect(kept(phone169, PadMode.dpad), ['tree']);
      // The stick's disc takes the corner and the clock area keeps its place,
      // so the mirror must fit the gap under it: the boat's board is too close
      // to the disc on the 852 phone, and the tree's and the boat's on the 15.
      expect(kept(iphone, PadMode.sticks), ['house', 'rocket', 'tree']);
      expect(kept(phone15, PadMode.sticks), ['house', 'rocket']);
      expect(kept(phone169, PadMode.sticks), ['rocket']);
      // The tilt view fills the left area, corner and gap alike.
      for (final box in const [iphone, phone15, phone169]) {
        expect(kept(box, PadMode.gyro), isEmpty, reason: 'the tilt view covers both places at $box');
      }
    });

    test('a control anywhere else leaves the mirror where it is', () {
      // The D-pad is below both places, so the mirror it leaves is the one the
      // game draws with no pad at all.
      for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
        expect(mirrorOf(puzzle, iphone, PadMode.dpad), mirrorWith(puzzle, iphone, const []), reason: id);
      }
    });

    test('over boards of every shape and piece size, on every phone and mode: absent or clear, and readable', () {
      // Rule 7: the mirror is sized from the board's shape and its pieces, so
      // every made-up board must either keep it clear of everything or have
      // none, and a board that only fits a smaller one gets the smaller one.
      // Boards from half as wide as they are tall to twice as wide, pieces from
      // comfortably big down to just under the floor (at these boards' scales
      // 10 units square is 2.5 mm at the mirror's, 8 is under 2 mm).
      var mirrors = 0;
      var smaller = 0;
      for (final box in const [iphone, phone15, phone169]) {
        for (final mode in PadMode.values) {
          final pad = leftPadRects(box, mode: mode, mm: phonePxPerMm);
          for (final aspect in const [0.5, 1.0, 1.5, 2.0]) {
            for (final side in const [24.0, 16.0, 10.0, 8.0]) {
              final puzzle = madeUpPuzzle(aspect: aspect, side: side);
              final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
              final where = 'aspect $aspect, side $side, $mode, $box';
              final mirror = mirrorWith(puzzle, box, pad);
              if (mirror == null) continue;
              mirrors++;
              final board = onScreen(layout, box, layout.left.board);
              final tray = onScreen(layout, box, layout.left.tray);
              for (final rect in [...pad, board, tray, mirror.hud.rect]) {
                expect(rect.overlaps(mirror.rect), isFalse, reason: where);
              }
              // Every piece the mirror draws, and the dot, is at the floor...
              final smallest = puzzle.pieces.map((p) => p.shape.size).reduce(min);
              expect(
                mirror.scale * smallest / phonePxPerMm,
                greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9),
                reason: where,
              );
              final dot = 2 * mirrorDotRadius(puzzle) * mirror.scale / phonePxPerMm;
              expect(dot, greaterThanOrEqualTo(mirrorMinPieceMm - 1e-9), reason: where);
              // ...and it is no bigger than the board fraction allows.
              final maxScale =
                  PuzzleCamera.place(layout, sideLeft, box, PuzzleSide.left).scale * PuzzleCamera.mirrorFraction;
              expect(mirror.scale, lessThanOrEqualTo(maxScale + 1e-9), reason: where);
              if (mirror.scale < maxScale - 1e-9) smaller++;
            }
          }
        }
      }
      expect(mirrors, greaterThan(0));
      expect(smaller, greaterThan(0), reason: 'a board that only fits smaller gets a smaller mirror, not none');
    });
  });

  group('the host phone\'s own round', () {
    setUpAll(loadPuzzles);

    testWidgets('gets this phone\'s pad rects and density, as a joined phone does', (tester) async {
      // "Play on this phone": the round shows on this phone under its pad, so
      // the game is told where the pad is (m12-opponent-mirror rule 3).
      await pumpHostApp(tester);
      final host = await soloRound(tester);
      final view = tester.widget<MatchView>(find.byType(MatchView));
      final box = tester.getSize(find.byType(MatchView));
      expect(view.pxPerMm, phonePxPerMm);
      expect(view.padRects, leftPadRects(box, mode: PadMode.dpad, mm: phonePxPerMm));
      await tester.runAsync(host.dispose);
    });

    testWidgets('"Show on this device" draws no pad over its game, so it passes none', (tester) async {
      await pumpHostApp(tester);
      final host = await enterHostMode(tester, choice: HostChoice.onDevice);
      final pad = hostContainer(tester).read(party.hostPadProvider);
      expect(pad.rects(iphone), isEmpty);
      expect(pad.pxPerMm, phonePxPerMm);
      await tester.runAsync(host.dispose);
    });
  });
}
