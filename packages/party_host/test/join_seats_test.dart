import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The sizes a side's seats are checked at: the frame's 960x540 stage and a
/// 360x640 phone.
const _sizes = [Size(960, 540), Size(360, 640)];

/// The empty seats on screen: each is drawn by an [EmptySeatPainter].
Finder _emptySeats() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EmptySeatPainter);

void main() {
  setUpAll(loadLookFonts);

  for (final perSide in [3, 4]) {
    for (final size in _sizes) {
      testWidgets('$perSide a side at ${size.width.toInt()}x${size.height.toInt()}: the sides draw $perSide seats '
          'each and fit the body with nothing to scroll, in every look', (tester) async {
        await forEachLook(tester, (look) async {
          final fake = await pumpHostLook(
            tester,
            look,
            size: size,
            framed: true,
            screen: const JoinScreen(choice: PuzzleChoice(level: Level.hard)),
          );
          appContainer(tester)
              .read(puzzleSettingsProvider.notifier)
              .set(PuzzleSettings.defaults.withValue('maxPerSide', perSide));
          await tester.pump();
          await neutral(tester, fake, ['p1']);
          await press(tester, fake, 'p1', GamepadButton.a);
          await tester.pump(const Duration(milliseconds: 500));

          final reason = '$look';
          expect(tester.takeException(), isNull, reason: 'nothing overflows, $reason');
          expect(_emptySeats(), findsNWidgets(2 * perSide - 1), reason: 'one joined, the rest empty, $reason');
          final scrollable = find.descendant(of: find.byType(JoinScreen), matching: find.byType(Scrollable));
          expect(scrollable, findsNothing, reason: 'a side never scrolls, $reason');
          final body = tester.getRect(find.byKey(const Key('hostFrameBody')));
          for (final key in const [Key('side-left'), Key('side-right')]) {
            final rect = tester.getRect(find.byKey(key));
            expect(rect.bottom, lessThanOrEqualTo(body.bottom + 1e-6), reason: '$key is inside the body, $reason');
          }
        });
      });
    }
  }

  testWidgets('two a side keeps the 52 px seat', (tester) async {
    final fake = await pumpHostLook(
      tester,
      HostLook.menu,
      framed: true,
      screen: const JoinScreen(choice: PuzzleChoice(level: Level.hard)),
    );
    await neutral(tester, fake, ['p1']);
    await press(tester, fake, 'p1', GamepadButton.a);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_emptySeats(), findsNWidgets(3));
    final seat = tester.getSize(find.ancestor(of: _emptySeats().first, matching: find.byType(SizedBox)).first);
    expect(seat.height, 52, reason: 'the seat keeps the scoreboard row height');
  });
}
