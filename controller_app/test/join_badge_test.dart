import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

const _changeCharacter = Key('changeCharacter');
const _settingsPreview = Key('characterPreview');

/// A badge's "Player N" label, which a numbered badge speaks.
final _playerNumberLabel = RegExp(r'Player \d');

/// Shows the join screen's badge and the Settings preview with no number: the
/// join line already names the character, and the phone has no player number
/// until the TV pairs (owner decision, Nov 23).
void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'the TV look' : 'the menu look';
    group('the badge without a number, in $look', () {
      testWidgets('the join screen\'s badge draws no number and speaks no "Player N" label', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpWithTealCrown(tester, tv: tv);
        expect(find.text('You: the Teal Crown'), findsOneWidget);

        final badges = tester.widgetList<party.ToyBadge>(find.byType(party.ToyBadge)).toList();
        expect(badges, hasLength(1), reason: 'the join screen has one badge: the phone\'s character');
        expect(badges.single.numbered, isFalse);
        expect(find.bySemanticsLabel(_playerNumberLabel), findsNothing);
        semantics.dispose();
      });

      testWidgets('the Settings preview\'s figures draw no number and speak no "Player N" label', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpWithTealCrown(tester, tv: tv);
        await tapVisible(tester, find.byKey(_changeCharacter));
        await settle(tester);

        final preview = find.byKey(_settingsPreview);
        expect(preview, findsOneWidget);
        final figures = tester
            .widgetList<party.ToyBadge>(find.descendant(of: preview, matching: find.byType(party.ToyBadge)))
            .toList();
        expect(figures, hasLength(2), reason: 'the worker and the marble');
        expect(figures.map((f) => f.numbered), [false, false]);
        expect(find.bySemanticsLabel(_playerNumberLabel), findsNothing);
        semantics.dispose();
      });
    });
  }
}

/// Mounts the app with a saved teal crown, on the menu or the TV look at a
/// size each look's type fits.
Future<void> _pumpWithTealCrown(WidgetTester tester, {required bool tv}) async {
  await pumpApp(
    tester,
    // The TV look's bigger type needs a tablet's room.
    screen: tv ? const Size(1180, 820) : const Size(852, 393),
    saved: {'profileCharacter': '{"c":4,"a":"crown"}'},
    extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
  );
}
