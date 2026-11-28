import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The small stages the 4v4 lobby is checked at (seatfit, Nov 27): the Shape
/// Race lobby overflowed while phones were still waiting to join.
const _sizes = [Size(640, 360), Size(800, 360), Size(960, 540)];

void main() {
  setUpAll(loadLookFonts);

  for (final perSide in [1, 2, 3, 4]) {
    for (final size in _sizes) {
      testWidgets('4 seats a side, $perSide joined a side, at ${size.width.toInt()}x${size.height.toInt()}: '
          'nothing overflows and each side stays inside the body', (tester) async {
        // Phones in the lobby: [perSide] a side press A and the rest wait, so
        // the "Not joined" line is drawn under the sides. With four a side one
        // more phone waits, so the "Game full" line is drawn too.
        final roster = [for (var i = 1; i <= (perSide == 4 ? 9 : 8); i++) 'p$i'];
        final joined = roster.take(2 * perSide).toList();
        final fake = await pumpHostLook(
          tester,
          HostLook.menu,
          size: size,
          framed: true,
          screen: const JoinScreen(choice: PuzzleChoice(level: Level.hard)),
        );
        for (final id in roster.skip(1)) {
          fake.state = withController(fake.state, phoneInfo(id, int.parse(id.substring(1)) - 1));
        }
        fake.emit();
        appContainer(tester)
            .read(puzzleSettingsProvider.notifier)
            .set(PuzzleSettings.defaults.withValue('maxPerSide', 4));
        await tester.pump();
        await neutral(tester, fake, roster);
        for (final id in joined) {
          await press(tester, fake, id, GamepadButton.a);
        }
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(const Key('notJoined')), findsOneWidget, reason: 'phones are waiting');
        expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
        final body = tester.getRect(find.byKey(const Key('hostFrameBody')));
        for (final key in const [Key('side-left'), Key('side-right')]) {
          expect(tester.getRect(find.byKey(key)).bottom, lessThanOrEqualTo(body.bottom + 1e-6), reason: '$key');
        }
      });
    }
  }
}
