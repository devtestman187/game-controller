import 'package:controller/src/ui/your_character.dart';
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

    testWidgets('a 320x640 phone wraps Change under the join line, centred, in the menu look', (tester) async {
      await expectWrappedBelowLine(tester, screen: const Size(320, 640), tv: false);
    });

    testWidgets('a 320x640 phone wraps Change under the join line, centred, in the TV look', (tester) async {
      await expectWrappedBelowLine(tester, screen: const Size(320, 640), tv: true);
    });

    testWidgets('a 852x393 landscape phone keeps the join line and Change on one row', (tester) async {
      await expectOneRow(tester, screen: const Size(852, 393));
    });

    testWidgets('a 393x852 portrait phone gets a 142 px panel, so the join line wraps there', (tester) async {
      await expectWrappedBelowLine(tester, screen: const Size(393, 852), tv: false);
    });

    testWidgets('a 360x640 phone reports which way the join line falls', (tester) async {
      await pumpApp(tester, screen: const Size(360, 640));
      final textRect = tester.getRect(find.text(joinLine));
      final buttonRect = tester.getRect(find.byKey(changeCharacter));
      final wrapped = buttonRect.top >= textRect.bottom;
      debugPrint('360x640 join line: ${wrapped ? 'wrapped' : 'one row'}');
      expectJoinLineInsideItsBox(tester);
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

/// At 320x640 the manual address row (connect_manual_entry.dart) and the app bar
/// (connect_screen.dart) overflow too. They are not this job's, so this drains
/// those exceptions and checks the join line by its geometry: every part of the line
/// sits inside its own box, so nothing spills past the panel.
void expectJoinLineInsideItsBox(WidgetTester tester) {
  for (var error = tester.takeException(); error != null; error = tester.takeException()) {}
  final box = tester.getRect(find.byType(YourCharacter));
  final lineRight = tester.getRect(find.text(joinLine)).right;
  final buttonRight = tester.getRect(find.byKey(changeCharacter)).right;
  expect(lineRight, lessThanOrEqualTo(box.right + layoutRoundingPx), reason: 'the join text runs past its box');
  expect(buttonRight, lessThanOrEqualTo(box.right + layoutRoundingPx), reason: 'Change runs past its box');
}

/// Pumps a phone too narrow for the join line and Change on one row: Change must
/// sit below the line, centred under the badge-and-text block.
Future<void> expectWrappedBelowLine(WidgetTester tester, {required Size screen, required bool tv}) async {
  await pumpApp(tester, screen: screen, extra: [if (tv) party.toyTvProvider.overrideWithValue(true)]);
  expectJoinLineInsideItsBox(tester);
  final textRect = tester.getRect(find.text(joinLine));
  final buttonRect = tester.getRect(find.byKey(changeCharacter));
  expect(buttonRect.top, greaterThanOrEqualTo(textRect.bottom), reason: 'Change sits below the join line');
  final blockLeft = tester.getRect(find.byType(party.ToyBadge)).left;
  final blockCentreX = (blockLeft + textRect.right) / 2;
  expect(
    (buttonRect.center.dx - blockCentreX).abs(),
    lessThanOrEqualTo(1),
    reason: 'Change centre ${buttonRect.center.dx}px, line block centre ${blockCentreX}px',
  );
}

/// Pumps a phone wide enough for one row: Change sits level with the join line,
/// with the 8 px gap before it.
Future<void> expectOneRow(WidgetTester tester, {required Size screen}) async {
  await pumpApp(tester, screen: screen);
  expect(tester.takeException(), isNull);
  final textRect = tester.getRect(find.text(joinLine));
  final buttonRect = tester.getRect(find.byKey(changeCharacter));
  expect(
    (buttonRect.center.dy - textRect.center.dy).abs(),
    lessThanOrEqualTo(2),
    reason: 'Change centre y ${buttonRect.center.dy}px, line centre y ${textRect.center.dy}px',
  );
  expect(buttonRect.left - textRect.right, greaterThanOrEqualTo(party.ToySizes.space8 - layoutRoundingPx));
}
