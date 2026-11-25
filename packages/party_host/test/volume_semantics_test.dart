import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/all_looks.dart';

/// The percentage shown beside a volume slider: the last text in the row above
/// it, after the row's name.
String _percentShownAbove(WidgetTester tester, String key) {
  final column = find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Column)).first;
  final row = find.descendant(of: column, matching: find.byType(Row)).first;
  return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).last.data ?? '';
}

/// The value of the slider's own semantics node, or null when the slider has
/// none. The widget's first render object is a pointer region with no semantics,
/// so the walk goes down until it reaches a node that is a slider.
String? _sliderSpokenValue(WidgetTester tester, String key) {
  String? spoken;
  void visit(Element element) {
    final node = element.renderObject?.debugSemantics;
    if (node != null && node.getSemanticsData().flagsCollection.isSlider) {
      spoken = node.value;
      return;
    }
    element.visitChildren(visit);
  }

  tester.element(find.byKey(Key(key))).visitChildren(visit);
  return spoken;
}

/// The Sounds and Music sliders read the percentage on the screen, so a screen
/// reader says what each volume is set to. Both palettes are checked, each in
/// the menu look and the TV look.
void main() {
  for (final palette in ['Sunny', 'Night']) {
    testWidgets('the $palette palette: each Sounds and Music slider reads the percentage shown above it', (
      tester,
    ) async {
      await forEachLook(tester, (look) async {
        final handle = tester.ensureSemantics();
        await pumpHostLook(tester, look, screen: const LookAndSoundScreen());
        await tester.tap(find.text(palette));
        await tester.pumpAndSettle();
        for (final key in ['soundVolume', 'musicVolume']) {
          final shown = _percentShownAbove(tester, key);
          expect(shown, isNotEmpty, reason: '$key shows a percentage in the ${look.name} look');
          expect(
            _sliderSpokenValue(tester, key),
            shown,
            reason: '$key reads the percentage shown in the ${look.name} look',
          );
        }
        handle.dispose();
      });
    });
  }
}
