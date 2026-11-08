import 'dart:math';

import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/tilt.dart';
import 'package:controller/src/ui/bar_modes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// The phone held upright with its top on the left, turned like a steering
/// wheel by [deg] degrees: gyro mode turns this into a positive x tilt
/// (gyro_mode_test's pose).
Vec3 tilted(double deg) => Vec3(cos(deg * pi / 180), sin(deg * pi / 180), 0);

void main() {
  // The puzzle files are read once, before any test runs: no test here waits
  // on their real reads while it runs (s9g).
  setUpAll(loadPuzzles);

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
      expect(ownClientOf(host).snapshot.isConnected, isTrue);
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
      expect(ownClientOf(host).snapshot.isConnected, isTrue);
      // A hosting phone still has no TV to look for.
      expect(app.discovery.restarts, restarts);
      await settle(tester);
      // The bar came back with the app, and the host is still up under it: the
      // full bar over the picker keeps the code to join it, and the mode's
      // labels with it (m12-host-touch rule 1, s7d2 Q1).
      expect(find.byType(BarModes), findsOneWidget);
      expect(find.byKey(const Key('hostChip')), findsOneWidget);
      expect(hostOf(tester), same(host));
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

    // m12 fix-f2, R3 finding 4: tilt is the one input that sends by itself,
    // so the app's resume starts it only where the pad is, as the pad does.
    testWidgets('coming back to the app on the pause menu sends no tilt', (tester) async {
      final app = await pumpHostApp(tester, saved: {'padMode': 'gyro'});
      // The mode used last comes back at launch (M3), and sends where the pad
      // is: in controller mode, as it always has.
      await tester.pump(const Duration(seconds: 1));
      app.motion.hold(tilted(0), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));

      // Into a round, where the pad is up and tilt sends with it. The pad's
      // sends go to the fake from here, so what it sends is counted.
      final host = await enterHostMode(tester);
      hostContainer(tester).read(ownClientProvider.notifier).set(app.client);
      await tester.tap(find.byKey(const Key('pickShapeRace')));
      await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
      await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
      await tester.tap(find.byKey(const Key('random-easy')));
      await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
      await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
      await tester.tap(find.byKey(const Key('joinStart')));
      await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
      await until(tester, () => hostPhase(tester) != party.RoundPhase.none, () => 'The round did not start');
      // The beat runs on the round's clock: the phone is held still through
      // it, as the sensors need a reading to come back (rule 3).
      while (hostPhase(tester) != party.RoundPhase.playing) {
        app.motion.hold(tilted(0), samples: 2);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Past Start's grace, so the press below counts as a new one (m12 §2.10).
      await settle(tester);
      final playing = app.client.inputs.length;
      app.motion.hold(tilted(15));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.client.inputs.length, greaterThan(playing), reason: 'the round has the pad');
      expect(app.motion.listening, isTrue);

      // Start pauses the round: the pad goes away with it, and tilt too.
      ownClientOf(host).sendInput({ControllerButton.start});
      await untilShown(tester, find.byKey(const Key('pauseMenu')), 'The pause menu');
      ownClientOf(host).sendInput({});
      await until(tester, () => hostPhase(tester) == party.RoundPhase.none, () => 'The phase did not stop');
      await settle(tester);
      final paused = app.client.inputs.length;

      // The app goes to the background and comes back on the menu: it starts
      // no search and no sensors, as the pad is not there (m12 §2.10, rule 2).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await until(tester, () => !host.away.value, () => 'The host did not come back');
      await settle(tester);
      app.motion.hold(tilted(30));
      await tester.pump(const Duration(milliseconds: 500));
      expect(app.client.inputs.length, paused, reason: 'the pause menu has no pad');
      expect(app.motion.listening, isFalse, reason: 'no sensors outside a round');

      // Resume brings back the pad and tilt with it.
      await tester.tap(find.byKey(const Key('pauseResume')));
      await until(tester, () => hostPhase(tester) == party.RoundPhase.playing, () => 'The phase did not go on');
      await settle(tester);
      final resumed = app.client.inputs.length;
      app.motion.hold(tilted(0), samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
      app.motion.hold(tilted(60));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.client.inputs.length, greaterThan(resumed), reason: 'Resume brings tilt back');
      await tester.runAsync(host.dispose);
    });

    testWidgets('a round hidden longer than the grace is abandoned: back to the game picker', (tester) async {
      // The presence's clock, moved by the test: 31 s under 30 s of grace.
      var nowMs = 0;
      await pumpHostApp(
        tester,
        extra: [
          phoneHostBuilderProvider.overrideWithValue(
            (inputs, {required playsHere}) => PhoneHost.live(inputs, playsHere: playsHere, nowMs: () => nowMs),
          ),
        ],
      );
      final host = await enterHostMode(tester);
      // Into Shape Race, join, and the match starts (m12 §3): the picker and
      // the levels are taps, the join screen's own player is in by itself and
      // Start on the screen begins the round (m12-host-touch rules 1, 5).
      // Each screen comes up after the host's menus read the tap and the
      // puzzle library loads, which a busy PC delays past a fixed number of
      // pumps (s9c).
      await tester.tap(find.byKey(const Key('pickShapeRace')));
      await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
      await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
      await tester.tap(find.byKey(const Key('random-easy')));
      await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
      await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
      await tester.tap(find.byKey(const Key('joinStart')));
      await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
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
