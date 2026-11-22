import 'package:controller/src/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

const nicknameField = Key('settingsNickname');
const nicknameCount = Key('nicknameCount');

void main() {
  group('the nickname rules (M16 identity)', () {
    test('letters, numbers, spaces and the basic punctuation . , ! ? \' - _ are kept', () {
      expect(nicknameOfText('Mia'), 'Mia');
      expect(nicknameOfText("Mia's team"), "Mia's team");
      expect(nicknameOfText('Mia, no?'), 'Mia, no?');
      expect(nicknameOfText('a-b_c!'), 'a-b_c!');
    });

    test('an emoji or a control character is dropped', () {
      expect(nicknameOfText('Mia🐱'), 'Mia');
      expect(nicknameOfText('Mia\u0007'), 'Mia');
      expect(nicknameOfText('Mia\tdad'), 'Miadad');
      expect(nicknameOfText('🐱'), isNull, reason: 'an emoji alone leaves nothing');
    });

    test('the text is trimmed and cut to ten characters', () {
      expect(nicknameOfText('  Mia  '), 'Mia');
      expect(nicknameOfText('Mia Maria Mia Mia'), 'Mia Maria');
      expect(nicknameOfText('MiaMiaMia0'), 'MiaMiaMia0', reason: 'ten characters are kept whole');
      expect(nicknameOfText('MiaMariaMia!'), 'MiaMariaMi', reason: 'the eleventh character is cut');
    });

    test('an empty nickname saves nothing, and the hello keeps the phone\'s own name', () {
      expect(nicknameOfText('   '), isNull);
      expect(phoneName(controllerId: 'ab12cd34'), 'Phone AB12');
    });
  });

  group('the nickname field and its count (M16 identity)', () {
    testWidgets(
      'the field takes the look\'s text size, and the 0 / 10 counter has a line of its own, in the menu look',
      (tester) async {
        await expectNicknameRowFits(tester, tv: false);
      },
    );

    testWidgets('the field takes the look\'s text size, and the 0 / 10 counter has a line of its own, in the TV look', (
      tester,
    ) async {
      await expectNicknameRowFits(tester, tv: true);
    });
  });
}

/// Opens the settings in one look and checks the nickname row draws whole:
/// the field at the look's body size with its text inside it, the count on its
/// own line under the field, and nothing overflowing the page.
Future<void> expectNicknameRowFits(WidgetTester tester, {required bool tv}) async {
  await pumpApp(
    tester,
    paired: true,
    // The TV look's bigger type needs a tablet's room around the two columns.
    screen: tv ? const Size(1180, 820) : const Size(852, 393),
    extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
  );
  await openSettings(tester);
  await scrollTo(tester, find.byKey(nicknameField));
  final look = party.ToyLookScope.of(tester.element(find.byKey(nicknameField)));
  expect(tester.widget<Text>(find.byKey(nicknameCount)).data, '0 / 10');

  await tester.enterText(find.byKey(nicknameField), 'Mia! Mia M');
  await tester.pump();
  expect(tester.widget<Text>(find.byKey(nicknameCount)).data, '10 / 10');
  expect(tester.takeException(), isNull, reason: 'nothing overflows at the look\'s type size');

  final field = tester.getRect(find.byKey(nicknameField));
  final typed = tester.getRect(find.text('Mia! Mia M'));
  expect(typed.top, greaterThanOrEqualTo(field.top), reason: 'the typed text starts inside the field');
  expect(typed.bottom, lessThanOrEqualTo(field.bottom), reason: 'and its last line ends inside it');
  expect(tester.widget<TextField>(find.byKey(nicknameField)).style?.fontSize, look.type.body.fontSize);

  final count = tester.getRect(find.byKey(nicknameCount));
  expect(count.top, greaterThanOrEqualTo(field.bottom), reason: 'the count has a line of its own under the field');
  expect(count.height, greaterThanOrEqualTo(look.type.body.fontSize!), reason: 'never squeezed to a sliver');
}
