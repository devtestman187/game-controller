import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';

/// The value of every slider on the screen, in the order the screen reader walks
/// them. The key finds a box that the two volume sliders share, so the sliders
/// are read from the whole tree; a slider with no value is left out.
List<String> _spokenValues(WidgetTester tester) {
  final values = <String>[];
  void visit(SemanticsNode node) {
    if (node.value.isNotEmpty) values.add(node.value);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  return values;
}

/// The percentage shown beside a volume slider: the last text in the row above
/// it, after the row's name.
String _percentShownAbove(WidgetTester tester, String key) {
  final column = find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Column)).first;
  final row = find.descendant(of: column, matching: find.byType(Row)).first;
  return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).last.data ?? '';
}

/// The Sounds and Music sliders read the percentage on the screen, so a screen
/// reader says what each volume is set to. Both looks are checked.
void main() {
  for (final palette in ['Sunny', 'Night']) {
    testWidgets('the $palette look: the Sounds and Music sliders read their percentage', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, screen: const LookAndSoundScreen());
      await tester.tap(find.text(palette));
      await tester.pumpAndSettle();
      final spoken = _spokenValues(tester);
      for (final key in ['soundVolume', 'musicVolume']) {
        expect(spoken, contains(_percentShownAbove(tester, key)), reason: '$key reads the percentage shown');
      }
      handle.dispose();
    });
  }
}
