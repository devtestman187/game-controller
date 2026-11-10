import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

void main() {
  testWidgets('an abandoned round ends the game abandoned and goes back to the game picker', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArena(tester, fake);
    expect(find.byType(GameScreen), findsOneWidget);
    // The round runs: a step has recorded its start.
    await tester.pump(const Duration(milliseconds: 16));
    expect(fake.gameHost.records.where((r) => r.name == 'round_start'), hasLength(1));

    final context = tester.element(find.byType(GameScreen));
    var fired = 0;
    ProviderScope.containerOf(context, listen: false).read(hostAbandonProvider).addListener(() => fired++);
    abandonRound(context);
    await navigated(tester);

    expect(fired, 1, reason: 'the views listening abandon their session');
    final end = fake.gameHost.records.singleWhere((r) => r.name == 'round_end');
    expect(end.data, {'reason': ViewEndReason.abandoned});
    expect(fake.gameHost.viewEnds.single.reason, ViewEndReason.abandoned);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
  });

  testWidgets('leaving with Quit ends the game quit, not abandoned', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArena(tester, fake);
    await tester.pump(const Duration(milliseconds: 16));

    final context = tester.element(find.byType(GameScreen));
    var fired = 0;
    ProviderScope.containerOf(context, listen: false).read(hostAbandonProvider).addListener(() => fired++);
    leaveForGamePicker(context);
    await navigated(tester);

    expect(fired, 0, reason: 'the players chose to stop: nothing was lost');
    expect(fake.gameHost.records.where((r) => r.name == 'round_end'), isEmpty);
    expect(fake.gameHost.viewEnds.single.reason, ViewEndReason.quit);
    expect(find.byType(GamesScreen), findsOneWidget);
  });
}
