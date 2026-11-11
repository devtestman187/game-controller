import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The best-times board (M14 f1, r5 finding 4; T15, design section 9 N14): the
/// top three of each puzzle and level, with the time and the names that set it,
/// opened from Shape Race's pick.
void main() {
  testWidgets('the board lists each puzzle\'s top 3, solo and team, with times and names', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    appContainer(tester).read(bestTimesProvider.notifier)
      ..record(puzzleId: 'house', team: false, timeMs: 95000, names: ['Mia'])
      ..record(puzzleId: 'house', team: false, timeMs: 88000, names: ['Dad'])
      ..record(puzzleId: 'house', team: false, timeMs: 101000, names: ['Sam'])
      ..record(puzzleId: 'house', team: false, timeMs: 120000, names: ['Nobody'])
      ..record(puzzleId: 'house', team: true, timeMs: 110000, names: ['Mia', 'Dad']);
    await openShapeRace(tester);
    await tapVisible(tester, find.byKey(const Key('openBestTimes')));
    await tester.pumpAndSettle();

    expect(find.byType(BestTimesScreen), findsOneWidget);
    // The fastest three of the solo board, fastest first.
    expect(find.text('1:28 · Dad'), findsOneWidget);
    expect(find.text('1:35 · Mia'), findsOneWidget);
    expect(find.text('1:41 · Sam'), findsOneWidget);
    expect(find.text('2:00 · Nobody'), findsNothing, reason: 'only the fastest three are kept');
    // The team board, kept apart from it, with both players' names.
    expect(find.text('1:50 · Mia, Dad'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    // Under its puzzle and its level, as the pick lists them.
    expect(find.text('House'), findsWidgets);
    expect(find.text('Easy'), findsOneWidget);
  });

  testWidgets('a host that has played nothing says so, and back returns to the pick', (tester) async {
    await pumpHost(tester, screen: const StubHome());
    await openShapeRace(tester);
    await tapVisible(tester, find.byKey(const Key('openBestTimes')));
    await tester.pumpAndSettle();
    expect(find.byType(BestTimesScreen), findsOneWidget);
    expect(find.text('No times yet'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BestTimesScreen), findsNothing);
    expect(find.byType(ShapeRaceScreen), findsOneWidget);
  });
}
