import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

const changeCharacter = Key('changeCharacter');

void main() {
  group('the join screen shows your character (M16 identity)', () {
    testWidgets('the phone\'s saved character is named, with a Change link that opens Settings, in the menu look', (
      tester,
    ) async {
      await expectCharacterAndChange(tester, tv: false);
    });

    testWidgets('the phone\'s saved character is named, with a Change link that opens Settings, in the TV look', (
      tester,
    ) async {
      await expectCharacterAndChange(tester, tv: true);
    });

    testWidgets('a phone that never picked a character shows the one it would get as player 1', (tester) async {
      await pumpApp(tester);
      expect(find.text('You: the Blue Ears'), findsOneWidget);
    });
  });

  group('the taken notice (M16 identity)', () {
    test('it says what was taken and what the phone got instead', () {
      expect(party.PhoneText.takenTonight('Red', 'Orange'), 'Red was taken: you\'re Orange');
    });
  });
}

/// Opens the Connect screen in one look with a saved teal crown, checks the
/// character is named there, and that Change leads to the Settings screen.
Future<void> expectCharacterAndChange(WidgetTester tester, {required bool tv}) async {
  await pumpApp(
    tester,
    // The TV look's bigger type needs a tablet's room.
    screen: tv ? const Size(1180, 820) : const Size(852, 393),
    saved: {'profileCharacter': '{"c":4,"a":"crown"}'},
    extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
  );
  expect(find.text('You: the Teal Crown'), findsOneWidget);
  expect(tester.takeException(), isNull, reason: 'the line fits the panel at the look\'s type size');

  await tapVisible(tester, find.byKey(changeCharacter));
  await settle(tester);
  expect(find.byKey(const Key('resetSettings')), findsOneWidget, reason: 'Change opens the Settings screen');
}
