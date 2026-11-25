import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

/// The settings sliders whose row shows the value beside the slider (the Haptics
/// strength, then the Gyro and Stick controls, then the controls' opacity).
const _settingsSliders = [
  'hapticsIntensity',
  'settingsGyroSensitivity',
  'settingsGyroDeadZone',
  'settingsGyroSmoothing',
  'settingsStickButtonSize',
  'settingsStickDeadZone',
  'settingsStickSensitivity',
  'controlsOpacitySlider',
];

/// The gyro dialog's sliders, each under the line that says what it is set to.
const _gyroSliders = ['gyroSensitivity', 'gyroDeadZone', 'gyroSmoothing'];

/// The stick dialog's sliders, each under the line that says what it is set to.
const _stickSliders = ['stickButtonSize', 'stickDeadZone', 'stickSensitivity'];

/// The value of every slider on the screen, in the order the screen reader walks
/// them. The key finds a box that a row's sliders can share, so the sliders are
/// read from the whole tree; a slider with no value is left out.
List<String> _spokenValues(WidgetTester tester) {
  final values = <String>[];
  void visit(SemanticsNode node) {
    if (node.hasFlag(SemanticsFlag.isSlider) && node.value.isNotEmpty) values.add(node.value);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  return values;
}

/// The value shown beside a settings slider: the last text in the row above it,
/// after the label.
String _valueShownAbove(WidgetTester tester, String key) {
  final column = find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Column)).first;
  final row = find.descendant(of: column, matching: find.byType(Row)).first;
  return tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).last.data ?? '';
}

/// The line shown above a dialog's slider: "label: value", or the value alone.
String _lineShownAbove(WidgetTester tester, String key) {
  final column = find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Column)).first;
  return tester.widget<Text>(find.descendant(of: column, matching: find.byType(Text)).first).data ?? '';
}

/// Every slider a player can move in settings and the two tuning dialogs reads
/// the value that is on the screen, so a screen reader says what the slider is
/// set to. Each look is checked: the menu look and the TV look share these rows.
void main() {
  for (final look in ['sunny', 'night']) {
    testWidgets('the $look look: each settings slider reads the value shown beside it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, paired: true, saved: {'look.choice': look});
      await openSettings(tester);
      for (final key in _settingsSliders) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        expect(_spokenValues(tester), contains(_valueShownAbove(tester, key)), reason: '$key reads the value shown');
      }
      handle.dispose();
    });

    testWidgets('the $look look: each gyro dialog slider reads the line shown above it', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await pumpApp(tester, paired: true, saved: {'look.choice': look});
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.text('Gyro'));
      await tester.pump();
      app.motion.hold(Vec3(1, 0, 0), samples: 50); // Upright in front of the player, as the gyro test holds it.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Gyro settings'));
      await tester.pump(const Duration(milliseconds: 300));
      for (final key in _gyroSliders) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        final line = _lineShownAbove(tester, key);
        expect(line, endsWith(tester.getSemantics(find.byKey(Key(key))).value), reason: '$key reads the line shown');
      }
      handle.dispose();
    });

    testWidgets('the $look look: each stick dialog slider reads the line shown above it', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await pumpApp(tester, paired: true, saved: {'look.choice': look});
      app.client.emit(connected);
      await tester.pump();
      await tester.tap(find.text('Sticks'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Stick settings'));
      await tester.pump(const Duration(milliseconds: 300));
      for (final key in _stickSliders) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        final line = _lineShownAbove(tester, key);
        expect(line, endsWith(tester.getSemantics(find.byKey(Key(key))).value), reason: '$key reads the line shown');
      }
      handle.dispose();
    });
  }
}
