import 'dart:io';
import 'dart:math' as math;

import 'package:controller/src/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mirror_corner_proof_test.dart' show loadPuzzles;
import 'support/pump_app.dart';

/// Whether a short "5/9" count of the other side's progress fits in the compact game bar between the
/// player's dot and the Start (Pause) button, keeping the 8 dp gaps (measurement only).
const _screens = [Size(568, 320), Size(667, 375), Size(800, 360), Size(844, 390), Size(956, 440)];
const _gapDp = 8.0;

class _ShownGame extends GameShownNotifier {
  @override
  bool build() => true;
}

double _textWidth(String text, double size) {
  final p = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return p.width;
}

void main() {
  final maxPieces = loadPuzzles().values.map((p) => p.pieces.length).reduce(math.max);
  for (final screen in _screens) {
    for (final withPlayer in [false, true]) {
      testWidgets('count fit at ${screen.width.toInt()}x${screen.height.toInt()} badge $withPlayer', (tester) async {
        final app = await pumpApp(
          tester,
          paired: true,
          screen: screen,
          extra: [gameShownProvider.overrideWith(() => _ShownGame())],
        );
        app.client.emit(withPlayer ? connected.copyWith(player: 1) : connected);
        await settle(tester);
        expect(tester.takeException(), isNull);
        var leftRight = tester.getRect(find.byKey(const Key('connectionButton'))).right;
        final badge = find.byKey(const Key('playerBadge'));
        if (badge.evaluate().isNotEmpty) leftRight = math.max(leftRight, tester.getRect(badge).right);
        final start = tester.getRect(find.byKey(const Key('barStart')));
        final free = start.left - leftRight;
        final room = free - 2 * _gapDp;
        final short = _textWidth('5/9', 14);
        final wide = _textWidth('$maxPieces/$maxPieces', 14);
        stdout.writeln(
          'BAR ${screen.width.toInt()}x${screen.height.toInt()} badge=$withPlayer free=${free.toStringAsFixed(1)} '
          'room(after 2x8 gaps)=${room.toStringAsFixed(1)} "5/9"@14=${short.toStringAsFixed(1)} fits=${room >= short} '
          '"$maxPieces/$maxPieces"@14=${wide.toStringAsFixed(1)} fits=${room >= wide}',
        );
      });
    }
  }
}
