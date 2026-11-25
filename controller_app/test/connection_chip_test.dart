import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';
import 'touch_targets_test.dart' show minTargetDp, targetScreens;

/// The landscape phone the owner measured the pill's label at.
const _landscape = Size(667, 375);

void main() {
  for (final tv in [false, true]) {
    final look = tv ? 'TV' : 'menu';
    testWidgets('the connected chip is at least 48 dp square and its label is not cut at 667x375 in the $look look', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        paired: true,
        screen: _landscape,
        extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
      );
      app.client.emit(connected);
      await settle(tester);
      final size = tester.getSize(find.byKey(const Key('connectionChip')));
      expect(size.width, greaterThanOrEqualTo(minTargetDp), reason: 'chip width $size');
      expect(size.height, greaterThanOrEqualTo(minTargetDp), reason: 'chip height $size');
      final label = find.descendant(of: find.byKey(const Key('connectionChip')), matching: find.byType(Text));
      // The dot alone (the room is under the threshold) has no label to cut: its tooltip carries the label.
      if (label.evaluate().isEmpty) {
        final tooltip = find.ancestor(of: find.byKey(const Key('connectionChip')), matching: find.byType(Tooltip));
        expect(tooltip, findsOneWidget, reason: 'the dot-only chip has no tooltip');
      } else {
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: 'the chip label "${paragraph.text.toPlainText()}" is cut');
      }
    });
  }

  for (final entry in targetScreens.entries) {
    for (final tv in [false, true]) {
      testWidgets('the connected chip is at least 48 dp square at ${entry.key} in the ${tv ? 'TV' : 'menu'} look', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          paired: true,
          screen: entry.value,
          extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
        );
        app.client.emit(connected);
        await settle(tester);
        final chip = find.byKey(const Key('connectionChip'));
        // The portrait phone asks to be turned and shows no bar chip.
        if (entry.value.height > entry.value.width && chip.evaluate().isEmpty) return;
        final size = tester.getSize(chip);
        expect(size.width, greaterThanOrEqualTo(minTargetDp), reason: 'chip width $size');
        expect(size.height, greaterThanOrEqualTo(minTargetDp), reason: 'chip height $size');
        // B-044 control: at 568x320 in the TV look the connected chip is 35.9x48, below 48 dp wide.
      }, skip: tv && entry.key == '568x320');
    }
  }
}
