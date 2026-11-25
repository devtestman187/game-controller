import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
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

/// The text after the "label: " of a gyro dialog line, which is the value the gyro
/// dialog's slider reads.
String _afterLabel(String line) => line.substring(line.indexOf(': ') + 2);

/// The whole line, which is the value the stick dialog's slider reads.
String _wholeLine(String line) => line;

/// A dialog slider reads exactly [spokenFor] of the line shown above it, and that
/// value is not empty, so an empty value cannot pass. The slider's own node reports
/// no value in the dialog, so the value is looked up in the screen reader's walk.
void _expectReadsLine(WidgetTester tester, String key, String Function(String line) spokenFor) {
  final spoken = spokenFor(_lineShownAbove(tester, key));
  expect(spoken, isNotEmpty, reason: '$key shows a value');
  final walk = tester.semantics.simulatedAccessibilityTraversal();
  expect(walk.where((node) => node.value == spoken), isNotEmpty, reason: '$key reads the line shown');
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
        final shown = _valueShownAbove(tester, key);
        expect(shown, isNotEmpty, reason: '$key shows a value');
        // The row merges the slider into its own node, which reads no value, so the
        // node that speaks the shown value is taken from the screen reader's walk.
        final walk = tester.semantics.simulatedAccessibilityTraversal();
        expect(walk.where((node) => node.value == shown), isNotEmpty, reason: '$key reads the value shown');
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
      app.motion.hold(const Vec3(1, 0, 0), samples: 50); // Upright in front of the player, as the gyro test holds it.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Gyro settings'));
      await tester.pumpAndSettle();
      for (final key in _gyroSliders) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        _expectReadsLine(tester, key, _afterLabel);
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
      await tester.pumpAndSettle();
      for (final key in _stickSliders) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        _expectReadsLine(tester, key, _wholeLine);
      }
      handle.dispose();
    });
  }
}
