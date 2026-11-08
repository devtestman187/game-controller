import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

void main() {
  testWidgets('a page route\'s push and pop call back; a dialog\'s push does not', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [ToyLookRouteObserver(() => changes.add('page'))],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        body: Column(
                          children: [
                            TextButton(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const AlertDialog(title: Text('a dialog')),
                              ),
                              child: const Text('open dialog'),
                            ),
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('pop')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('push'),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(title: Text('a dialog')),
                  ),
                  child: const Text('dialog here'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The app's first page is a page route like any other.
    expect(changes, hasLength(1));

    await tester.tap(find.text('dialog here'));
    await tester.pumpAndSettle();
    expect(changes, hasLength(1), reason: 'a dialog is not a page route');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(changes, hasLength(1), reason: 'and its pop is not one either');

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(changes, hasLength(2), reason: 'the pushed page');
    await tester.tap(find.text('pop'));
    await tester.pumpAndSettle();
    expect(changes, hasLength(3), reason: 'and the pop back');
  });

  testWidgets('a page replaced by another calls back, as the join screen hands over to a round', (tester) async {
    // The join screen starts a round, and a round the next one, with
    // pushReplacement: the round's first frame should have the palette of the
    // moment it starts (Claude's 3a review).
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [ToyLookRouteObserver(() => changes.add('page'))],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const Text('the round'))),
            child: const Text('start'),
          ),
        ),
      ),
    );
    expect(changes, hasLength(1));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('the round'), findsOneWidget);
    expect(changes, hasLength(2), reason: 'the replacement');
  });
}
