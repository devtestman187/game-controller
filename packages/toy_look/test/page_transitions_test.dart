import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

final _look = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// The app both hosts run: the look above [MaterialApp], which takes the
/// theme made from it, so a page's transition comes from the theme.
Widget _app() => ToyStillSky(
  child: ToyLookScope(
    look: _look,
    child: MaterialApp(
      theme: toyTheme(_look),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Text('first page'),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          const Text('second page'),
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const AlertDialog(title: Text('a dialog')),
                            ),
                            child: const Text('open dialog'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('push'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// How many toy backgrounds stand behind [text].
Finder _backgroundBehind(String text) => find.ancestor(of: find.text(text), matching: find.byType(ToyBackground));

void main() {
  testWidgets('a page under a toyTheme has a toy background behind it, and a transparent scaffold', (tester) async {
    await tester.pumpWidget(_app());
    expect(_backgroundBehind('first page'), findsOneWidget);
    // The scaffold paints nothing of its own: the page's own background is
    // the sky, so a page sliding over another never shows the one below.
    expect(Theme.of(tester.element(find.text('first page'))).scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('a pushed page carries its own toy background, through the transition', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('push'));
    await tester.pump();
    // Half-way through the slide, the page already has its own sky behind it.
    await tester.pump(const Duration(milliseconds: 100));
    expect(_backgroundBehind('second page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_backgroundBehind('second page'), findsOneWidget);
  });

  testWidgets('a dialog has no toy background of its own', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('a dialog'), findsOneWidget);
    expect(_backgroundBehind('a dialog'), findsNothing);
  });
}
