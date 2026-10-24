import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/main.dart';

void main() {
  testWidgets('remote navigation moves focus and selects', (tester) async {
    await tester.pumpWidget(const TvTestApp());
    await tester.pumpAndSettle();

    // First button is focused on launch; select activates it.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Selected: Input'), findsOneWidget);

    // Right arrow moves to the next button.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Selected: Game'), findsOneWidget);
  });
}
