import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

const changeCharacter = Key('changeCharacter');
const joinLine = 'You: the Blue Ears';

/// Text layout rounds positions to within a few thousandths of a pixel, so a gap
/// of exactly 8 can read as 7.999999999999886; this slack absorbs that and nothing more.
const layoutRoundingPx = 0.01;

void main() {
  group('the join line keeps a gap before its Change link (M16 identity, B-035)', () {
    testWidgets('the gap between the character line and Change is at least 8 px in the menu look', (tester) async {
      await expectGapBeforeChange(tester, screen: const Size(852, 393), tv: false);
    });

    testWidgets('the gap between the character line and Change is at least 8 px in the TV look', (tester) async {
      await expectGapBeforeChange(tester, screen: const Size(1180, 820), tv: true);
    });

    testWidgets('a small landscape phone (568x320) shows the join line and Change without an exception', (
      tester,
    ) async {
      await pumpApp(tester, screen: const Size(568, 320));
      expect(find.text(joinLine), findsOneWidget);
      expect(find.byKey(changeCharacter), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the text shrinks first and the row still fits');
    });
  });
}

/// Pumps the Connect screen in one look and measures the space from the right
/// edge of the join line to the left edge of the Change button's own box, so
/// the button's padding counts toward the gap.
Future<void> expectGapBeforeChange(WidgetTester tester, {required Size screen, required bool tv}) async {
  await pumpApp(tester, screen: screen, extra: [if (tv) party.toyTvProvider.overrideWithValue(true)]);
  final lineRight = tester.getTopRight(find.text(joinLine)).dx;
  final buttonLeft = tester.getRect(find.byKey(changeCharacter)).left;
  final gap = buttonLeft - lineRight;
  expect(
    gap,
    greaterThanOrEqualTo(party.ToySizes.space8 - layoutRoundingPx),
    reason: 'the line and Change sit apart by ${gap}px',
  );
  expect(tester.takeException(), isNull);
}
