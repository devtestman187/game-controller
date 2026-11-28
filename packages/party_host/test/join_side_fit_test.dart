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

/// The lowest scale a side card was drawn at in any case below (0.89, 800x360 with nine phones waiting), minus 0.05: it can't silently get worse.
const _minScale = 0.84;

/// The card's own scale in side [key]: what [FittedBox] gives it, without the
/// scale the whole body may have above it.
double _cardScale(WidgetTester tester, Key key) {
  final card = find.descendant(of: find.byKey(key), matching: find.byType(ToyCard)).first;
  final outer = tester.getRect(find.byKey(key)).height / tester.getSize(find.byKey(key)).height;
  return tester.getRect(card).height / tester.getSize(card).height / outer;
}

void main() {
  setUpAll(loadLookFonts);

  for (final own in [false, true]) {
    for (final perSide in [1, 2, 3, 4]) {
      for (final size in _sizes) {
        // The host phone's own player is checked at the smallest stage, once.
        if (own && (size != _sizes.first || perSide != 1)) continue;
        testWidgets('${own ? 'host phone plays, ' : ''}4 seats a side, $perSide joined a side, at '
            '${size.width.toInt()}x${size.height.toInt()}: nothing overflows, the cards keep their scale', (
          tester,
        ) async {
          // Phones in the lobby: [perSide] a side press A and the rest wait, so
          // the "Not joined" line is drawn under the sides, wrapping while many
          // wait. With four a side one more phone waits.
          final roster = [for (var i = 1; i <= (perSide == 4 ? 9 : 8); i++) 'p$i'];
          final joined = roster.take(2 * perSide).toList();
          final fake = await pumpHostLook(
            tester,
            HostLook.menu,
            size: size,
            overrides: [
              if (own) ...[ownPlayerIdProvider.overrideWithValue('p1'), hostTouchFirstProvider.overrideWithValue(true)],
            ],
            framed: true,
            screen: const JoinScreen(choice: PuzzleChoice(level: Level.hard)),
          );
          fake.shareView = own;
          var lowest = 1.0;
          // Every stage of the lobby is checked, as the overflow came while
          // the waiting line was long, before the last phone joined.
          void check(String stage) {
            expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow, $stage');
            final frame = find.byKey(const Key('hostFrameBody'));
            final body = frame.evaluate().isEmpty ? Offset.zero & size : tester.getRect(frame);
            for (final key in const [Key('side-left'), Key('side-right')]) {
              final scale = _cardScale(tester, key);
              if (scale < lowest) lowest = scale;
              expect(scale, greaterThanOrEqualTo(_minScale), reason: 'the card keeps its scale, $key, $stage');
              expect(tester.getRect(find.byKey(key)).bottom, lessThanOrEqualTo(body.bottom + 1e-6), reason: '$key');
            }
          }

          for (final id in roster.skip(1)) {
            fake.state = withController(fake.state, phoneInfo(id, int.parse(id.substring(1)) - 1));
          }
          fake.emit();
          appContainer(tester)
              .read(puzzleSettingsProvider.notifier)
              .set(PuzzleSettings.defaults.withValue('maxPerSide', 4));
          await tester.pump();
          await neutral(tester, fake, own ? roster.skip(1) : roster);
          check('nobody joined');
          for (final id in joined) {
            await press(tester, fake, id, GamepadButton.a);
            check('after $id joined');
          }
          await tester.pump(const Duration(milliseconds: 500));
          check('settled');
          if (!own) expect(find.byKey(const Key('notJoined')), findsOneWidget, reason: 'phones are waiting');
          debugPrint('SCALE own=$own perSide=$perSide $size lowest $lowest');
        });
      }
    }
  }
}
