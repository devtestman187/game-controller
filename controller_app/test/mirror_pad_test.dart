import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:controller/src/gyro.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/sticks.dart';
import 'package:controller/src/ui/joined_view.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/joined.dart';

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

/// The mirror [box] draws for [puzzle]'s race with the app's [mode] pad on the
/// screen, or null.
({Rect rect, double scale})? mirrorOf(Puzzle puzzle, Size box, PadMode mode) {
  final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
  return PuzzleCamera.mirrorPlace(
    layout,
    sideLeft,
    box,
    split: true,
    text: raceText(puzzle),
    padRects: leftPadRects(box, mode: mode, mm: phonePxPerMm),
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
      return arms(padLayout(body).dpad);
    case PadMode.sticks:
      final layout = stickLayout(body);
      return [ControlShape.circle(layout.leftStick.shift(bar)), ...arms(layout.dpad)];
    case PadMode.gyro:
      return [ControlShape.rect(padLayout(body).leftArea.shift(bar))];
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
    test('the mirror never meets the left stick\'s disc or the D-pad, in any mode or phone size', () {
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

    test('which puzzles keep the mirror, phone by phone and mode by mode', () {
      List<String> kept(Size box, PadMode mode) => [
        for (final MapEntry(key: id, value: puzzle) in puzzles.entries)
          if (mirrorOf(puzzle, box, mode) != null) id,
      ];
      // D-pad mode: the mirror is in the board's top left, above the arms, and
      // the HUD's room decides the rest (the same table s11 pinned).
      expect(kept(iphone, PadMode.dpad), ['house', 'rocket', 'tree', 'boat']);
      expect(kept(phone15, PadMode.dpad), ['house', 'rocket', 'tree']);
      expect(kept(phone169, PadMode.dpad), ['tree']);
      // Sticks: the left stick's disc reaches up to where the mirror goes on
      // every one of the three phones (at 852 the disc's top is 108 and the
      // mirror's bottom 126 to 132), so the box keeps today's HUD.
      for (final box in const [iphone, phone15, phone169]) {
        expect(kept(box, PadMode.sticks), isEmpty, reason: 'the stick is over the mirror at $box');
        // Gyro: the tilt view fills the same top left.
        expect(kept(box, PadMode.gyro), isEmpty, reason: 'the tilt view is over the mirror at $box');
      }
    });

    test('a control anywhere else leaves the mirror where it is', () {
      // The same mirror without the pad is what the D-pad mode still draws, so
      // the pad changes nothing where it doesn't reach.
      for (final MapEntry(key: id, value: puzzle) in puzzles.entries) {
        final layout = SplitLayout.of(puzzle, 1, target: LayoutTarget.phones);
        final bare = PuzzleCamera.mirrorPlace(layout, sideLeft, iphone, split: true, text: raceText(puzzle));
        expect(mirrorOf(puzzle, iphone, PadMode.dpad), bare, reason: id);
      }
    });
  });
}
