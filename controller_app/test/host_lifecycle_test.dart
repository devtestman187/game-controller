import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';
import 'support/pump_app.dart';

void main() {
  group('a hosting phone and the app lifecycle (m12 §2.10)', () {
    testWidgets('coming back to the app leaves the search off and the own player paired', (tester) async {
      final app = await pumpHostApp(tester);
      final host = await enterHostMode(tester);
      final restarts = app.discovery.restarts;
      final stops = app.discovery.stops;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      // Nothing to find while hosting: the search stays stopped, and the TV
      // client below is not resumed or reconnected (m12 §2.7).
      expect(app.discovery.restarts, restarts);
      expect(app.discovery.stops, stops);
      expect(app.client.calls, isEmpty);
      expect(host.client.snapshot.isConnected, isTrue);
      expect(hostOf(tester), same(host));
      await tester.runAsync(host.dispose);
    });

    testWidgets('hiding the app pauses the round, and showing it brings the host back', (tester) async {
      final advertiser = party_test.FakeAdvertiser();
      final app = await pumpHostApp(tester, advertiser: advertiser);
      final host = await enterHostMode(tester);
      final away = hostContainer(tester).read(party.hostAwayProvider);
      final starts = advertiser.starts.length;
      final restarts = app.discovery.restarts;
      expect(away.value, isFalse);

      // The system reports a backgrounded app as inactive first.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      // The screens pause the game then, as for an open pause menu (s5a).
      expect(away.value, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(tester, () => !away.value, () => 'The host did not come back');
      // The server can be found again before the pause ends: one more start.
      expect(advertiser.starts.length, starts + 1);
      expect(host.live, isTrue);
      expect(host.client.snapshot.isConnected, isTrue);
      // A hosting phone still has no TV to look for.
      expect(app.discovery.restarts, restarts);
      await settle(tester);
      expect(find.byKey(const Key('hostChip')), findsOneWidget);
      await tester.runAsync(host.dispose);
    });

    testWidgets('showing the app again starts the host sound engine once', (tester) async {
      final sounds = party_test.FakeSoundPlayer();
      await pumpHostApp(tester, sounds: sounds);
      final host = await enterHostMode(tester);
      expect(sounds.restarts, 0);

      // The phone locked or another app took it, then back: iOS stopped the
      // app's sound (s5c).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(tester, () => !host.away.value, () => 'The host did not come back');
      await settle(tester);

      expect(sounds.restarts, 1);
      await tester.runAsync(host.dispose);
    });

    testWidgets('an app that is not hosting restarts no sound when it is shown again', (tester) async {
      final sounds = party_test.FakeSoundPlayer();
      await pumpHostApp(tester, sounds: sounds);
      expect(sounds.restarts, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(sounds.restarts, 0);
    });

    testWidgets('a round hidden longer than the grace is abandoned: back to the game picker', (tester) async {
      // The presence's clock, moved by the test: 31 s under 30 s of grace.
      var nowMs = 0;
      await pumpHostApp(
        tester,
        extra: [phoneHostBuilderProvider.overrideWithValue((inputs) => PhoneHost.live(inputs, nowMs: () => nowMs))],
      );
      final host = await enterHostMode(tester);
      // Into Shape Race, join, and the match starts (m12 §3).
      await pressA(tester);
      await pressA(tester);
      await pressA(tester);
      await pressA(tester);
      expect(find.byType(party.PuzzleScreen), findsOneWidget);

      final container = hostContainer(tester);
      var fired = 0;
      container.read(party.hostAbandonProvider).addListener(() => fired++);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      nowMs += 31000;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(tester, () => fired > 0, () => 'The round was not abandoned');
      await settle(tester);

      // The views heard the signal, and the round is back at the picker.
      expect(fired, 1);
      expect(find.byType(party.PuzzleScreen), findsNothing);
      expect(find.byType(party.GamesScreen), findsOneWidget);
      expect(host.live, isTrue);
      await tester.runAsync(host.dispose);
    });
  });
}
