import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

/// The night's two round choices, as the start card's segment offers them.
const _options = [RoundOption(value: 3, label: '3 rounds'), RoundOption(value: 5, label: '5 rounds')];

/// Mounts a segment choosing the five-round chip, as the header holds it.
/// [onChanged] null is a night already under way, whose chips can't be picked.
Future<void> _pumpSegment(WidgetTester tester, {required ValueChanged<int>? onChanged}) async {
  final look = ToyLook.build(palette: ToyPalette.sunny, tv: true);
  await tester.pumpWidget(
    ProviderScope(
      child: ToyLookScope(
        look: look,
        child: MaterialApp(
          theme: toyTheme(look),
          home: Scaffold(
            body: Center(
              child: RoundSegment(value: 5, onChanged: onChanged, options: _options),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a screen reader presses a chip and picks its option', (tester) async {
    final picks = <int>[];
    final semantics = tester.ensureSemantics();
    await _pumpSegment(tester, onChanged: picks.add);

    // The chip a screen reader lands on says its label and is a button it can
    // press (finding 10: the tap used to sit under ExcludeSemantics).
    final chip = tester.getSemantics(find.text('3 rounds'));
    expect(chip.getSemanticsData().label, '3 rounds');
    expect(
      chip.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'TalkBack must be able to press the chip',
    );

    tester.semantics.tap(find.semantics.byLabel('3 rounds'));
    await tester.pump();
    expect(picks, [3], reason: 'the three-round chip reports its own value');
    semantics.dispose();
  });

  testWidgets('a segment with nothing to change calls nothing and takes no focus', (tester) async {
    final picks = <int>[];
    final semantics = tester.ensureSemantics();
    await _pumpSegment(tester, onChanged: picks.add);

    // The night starts: the same chips are drawn, with nothing left to change.
    await _pumpSegment(tester, onChanged: null);

    await tester.tap(find.text('3 rounds'));
    await tester.pump();
    expect(picks, isEmpty, reason: 'a disabled chip does not call the callback it had');

    // A direction key walks the host's controls and the centre key presses the
    // focused one; a disabled segment is not one of them.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<RoundSegment>(),
      isNull,
      reason: 'no chip takes the focus',
    );
    expect(picks, isEmpty);
    expect(tester.takeException(), isNull);

    final chip = tester.getSemantics(find.text('3 rounds'));
    expect(
      chip.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'a screen reader cannot press it either',
    );
    semantics.dispose();
  });
}
