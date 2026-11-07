import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

void main() {
  group('HostPresence', () {
    late FakeHostService host;
    late int clockMs;
    late int abandoned;

    HostPresence presence() => HostPresence(host: host, onAbandon: () => abandoned++, nowMs: () => clockMs);

    setUp(() {
      host = FakeHostService(sampleState());
      clockMs = 0;
      abandoned = 0;
    });

    test('hidden 10 s then shown: the game resumes, the round stays', () async {
      final p = presence();
      addTearDown(p.dispose);
      p.hidden();
      expect(p.away.value, isTrue, reason: 'away from the moment it is hidden');

      clockMs = 10000;
      await p.shown();
      expect(p.away.value, isFalse);
      expect(host.resumes, 1);
      expect(abandoned, 0, reason: '10 s is inside the 30 s grace');
    });

    test('hidden 31 s then shown: the round is abandoned', () async {
      final p = presence();
      addTearDown(p.dispose);
      p.hidden();

      clockMs = 31000;
      await p.shown();
      expect(p.away.value, isFalse);
      expect(host.resumes, 1);
      expect(abandoned, 1);
    });

    test('an abandoned round ends while the game is still paused', () async {
      bool? awayWhenAbandoned;
      late final HostPresence p;
      p = HostPresence(host: host, onAbandon: () => awayWhenAbandoned = p.away.value, nowMs: () => clockMs);
      addTearDown(p.dispose);
      p.hidden();
      clockMs = 31000;
      await p.shown();
      expect(awayWhenAbandoned, isTrue, reason: 'no step runs between coming back and leaving the round');
    });

    test('hidden twice without shown is one away period', () async {
      final p = presence();
      addTearDown(p.dispose);
      var changes = 0;
      p.away.addListener(() => changes++);

      p.hidden();
      p.hidden();
      expect(p.away.value, isTrue);
      expect(changes, 1, reason: 'the second report changed nothing');

      clockMs = 5000;
      await p.shown();
      expect(p.away.value, isFalse);
      expect(changes, 2);
      expect(abandoned, 0, reason: 'the grace counts from the first hidden report');
    });

    test('dispose stops listening: later lifecycle reports do nothing', () async {
      final p = presence();
      p.dispose();
      p.hidden();
      expect(p.away.value, isFalse);
      clockMs = 60000;
      await p.shown();
      expect(host.resumes, 0);
      expect(abandoned, 0);
    });
  });

  testWidgets('a Pausable with the host away pauses the game without the menu', (tester) async {
    final away = ValueNotifier<bool>(false);
    addTearDown(away.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostServiceProvider.overrideWithValue(FakeHostService(sampleState())),
          hostAwayProvider.overrideWithValue(away),
        ],
        child: MaterialApp(home: Pausable(enabled: true, builder: (context, paused) => Text('paused: $paused'))),
      ),
    );
    expect(find.text('paused: false'), findsOneWidget);

    away.value = true;
    await tester.pump();
    expect(find.text('paused: true'), findsOneWidget);
    expect(find.byKey(const Key('pauseMenu')), findsNothing, reason: 'away opens no menu');

    away.value = false;
    await tester.pump();
    expect(find.text('paused: false'), findsOneWidget);
  });
}
