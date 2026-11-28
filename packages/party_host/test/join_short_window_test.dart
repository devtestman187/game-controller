import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/all_looks.dart';
import 'support/toy_fonts.dart';

/// The join screen below its frame-body floor (392 px): the body is drawn at its floor and scaled down. A short window
/// with no frame must not throw and draws both sides at a finite size (glow1: the suspected infinite width did not reproduce).
void main() {
  setUpAll(loadLookFonts);

  for (final size in const [Size(640, 300), Size(800, 200), Size(960, 380)]) {
    testWidgets('unframed ${size.width.toInt()}x${size.height.toInt()}: no exception, sides drawn', (tester) async {
      await pumpHostLook(
        tester,
        HostLook.menu,
        size: size,
        screen: const JoinScreen(choice: PuzzleChoice(level: Level.hard)),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('side-left')), findsOneWidget);
      final rect = tester.getRect(find.byKey(const Key('side-left')));
      expect(rect.width.isFinite && rect.height.isFinite, isTrue);
    });
  }
}
