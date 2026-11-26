import 'dart:async';

import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/home/home_text.dart';
import 'package:controller/src/home/home_view.dart';
import 'package:controller/src/home/phone_home_screen.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:controller/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// A launch whose questions were put already, which a test can reset to put
/// them again from Home.
class _ResettableAsked extends LaunchConsentAskedNotifier {
  @override
  bool build() => true;

  void reset() => state = false;
}

/// Records the exits Back asks for, in place of the platform's exit.
class _FakeExit {
  int calls = 0;

  Future<void> call() async {
    calls++;
  }
}

/// A client state the test sets, so a connection can land while this phone hosts.
class _SetClientState extends ClientStateNotifier {
  @override
  ClientSnapshot build() => const ClientSnapshot(status: ClientStatus.idle);

  void emit(ClientSnapshot snapshot) => state = snapshot;
}

/// Pushes Home over the app's pad and lets its first frame run.
Future<void> openHome(WidgetTester tester, {bool fromLaunch = false}) async {
  unawaited(
    Navigator.of(tester.element(find.byType(ControllerScreen, skipOffstage: false).first))
        .push(MaterialPageRoute<void>(builder: (_) => PhoneHomeScreen(fromLaunch: fromLaunch))),
  );
  await settle(tester);
}

/// Puts the launch's questions back to unasked, as a first Home finds them.
void forgetAsked(WidgetTester tester) {
  final container = ProviderScope.containerOf(tester.element(find.byType(ControllerScreen, skipOffstage: false).first));
  final asked = container.read(launchConsentAskedProvider.notifier);
  if (asked is _ResettableAsked) asked.reset();
}

/// The saved settings of a user who has seen the coach marks, which would else dim Home.
const noTips = <String, Object>{'showTips': false};

/// The colour of the role button labelled [label].
Color? buttonColor(WidgetTester tester, String label) =>
    tester.widget<party.ToyButton>(find.widgetWithText(party.ToyButton, label)).color;

/// A found host, as discovery reports it.
DiscoveryState found() => DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]);

void main() {
  group('the three buttons', () {
    testWidgets('Join a Game opens the Connect screen', (tester) async {
      await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      await tester.tap(find.text(HomeText.joinGame));
      await settle(tester);
      expect(find.text('Connect to a screen'), findsOneWidget);
    });

    testWidgets('Play here hosts on this phone, with its own player and no sheet', (tester) async {
      await pumpHostApp(tester, saved: noTips);
      await openHome(tester);
      await tester.tap(find.text(HomeText.playHere));
      await settle(tester);
      await answerConsent(tester);
      final host = hostOf(tester);
      expect(host.playsHere, isTrue, reason: 'Play here plays on this phone');
      expect(find.byKey(const Key('hostOnPhone')), findsNothing, reason: 'no start sheet');
      await hostReady(tester, host);
      await tester.runAsync(hostContainer(tester).read(hostingProvider.notifier).stop);
    });

    testWidgets('Display here hosts on this device, with no own player and no sheet', (tester) async {
      await pumpHostApp(tester, saved: noTips);
      await openHome(tester);
      await tester.tap(find.text(HomeText.displayHere));
      await settle(tester);
      await answerConsent(tester);
      final host = hostOf(tester);
      expect(host.playsHere, isFalse, reason: 'Display here shows the game only');
      expect(find.byKey(const Key('hostOnDevice')), findsNothing, reason: 'no start sheet');
      await until(tester, () => host.started, () => 'The host did not start');
      await tester.runAsync(hostContainer(tester).read(hostingProvider.notifier).stop);
    });

    testWidgets('Settings and the name row open Settings, Search again restarts discovery', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      // The chip offers Search again once nothing was found.
      app.discovery.emit(const DiscoveryState(error: 'no network'));
      await settle(tester);
      await tester.tap(find.text(HomeText.searchAgain));
      expect(app.discovery.restarts, 1);
      for (final label in [HomeText.settings, HomeText.tapToAddName]) {
        await tester.tap(find.text(label));
        await settle(tester);
        expect(find.byType(SettingsScreen), findsOneWidget, reason: '$label opens Settings');
        await closeSettings(tester);
        expect(find.byType(HomeView), findsOneWidget, reason: 'Back from Settings returns to Home');
      }
    });
  });

  group('the find', () {
    testWidgets('a found host highlights Join a Game', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      app.discovery.emit(found());
      await settle(tester);
      final good = party.ToyLookScope.of(tester.element(find.byType(HomeView))).colors.good;
      expect(buttonColor(tester, HomeText.joinGame), good);
      expect(buttonColor(tester, HomeText.playHere), isNot(good));
    });

    testWidgets('while searching Home says Looking for a screen, and after homeSearchWait with no host it says none', (
      tester,
    ) async {
      await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      final good = party.ToyLookScope.of(tester.element(find.byType(HomeView))).colors.good;
      expect(find.text(HomeText.lookingForScreen), findsOneWidget, reason: 'still searching');
      await tester.pump(const Duration(seconds: 1));
      expect(buttonColor(tester, HomeText.playHere), isNot(good), reason: 'still searching');
      expect(buttonColor(tester, HomeText.joinGame), isNot(good), reason: 'still searching');
      await tester.pump(homeSearchWait);
      expect(find.text(HomeText.lookingForScreen), findsNothing);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
      expect(buttonColor(tester, HomeText.playHere), good);
    });

    testWidgets('Search again after none searches afresh: Looking for a screen, then none after homeSearchWait', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      await tester.pump(homeSearchWait);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
      await tester.tap(find.text(HomeText.searchAgain));
      await tester.pump();
      expect(app.discovery.restarts, 1);
      final good = party.ToyLookScope.of(tester.element(find.byType(HomeView))).colors.good;
      expect(find.text(HomeText.lookingForScreen), findsOneWidget);
      expect(find.text(HomeText.searchAgain), findsNothing);
      expect(buttonColor(tester, HomeText.playHere), isNot(good), reason: 'nothing highlighted while searching');
      await tester.pump(homeSearchWait);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
      expect(buttonColor(tester, HomeText.playHere), good);
    });

    testWidgets('the app resuming after none searches afresh: Looking for a screen, then none after homeSearchWait', (
      tester,
    ) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      await tester.pump(homeSearchWait);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
      // The test binding starts resumed, so the platform's walk through inactive comes first.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(app.discovery.restarts, 1);
      expect(find.text(HomeText.lookingForScreen), findsOneWidget);
      expect(find.text(HomeText.searchAgain), findsNothing);
      await tester.pump(homeSearchWait);
      expect(find.text(HomeText.noScreenFound), findsOneWidget);
    });

    testWidgets('a discovery error leads with Play here at once', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      app.discovery.emit(const DiscoveryState(error: 'no network'));
      await settle(tester);
      final good = party.ToyLookScope.of(tester.element(find.byType(HomeView))).colors.good;
      expect(buttonColor(tester, HomeText.playHere), good);
      await tester.pump(homeSearchWait);
    });
  });

  group('the launch consent', () {
    Future<TestApp> pumpAsking(WidgetTester tester) => pumpApp(
      tester,
      paired: true,
      saved: noTips,
      extra: [
        launchConsentAskProvider.overrideWithValue(true),
        launchConsentAskedProvider.overrideWith(_ResettableAsked.new),
      ],
    );

    testWidgets('Home asks once, and a second Home asks nothing', (tester) async {
      await pumpAsking(tester);
      forgetAsked(tester);
      await openHome(tester);
      expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'the first Home asks');
      await tester.tap(find.byKey(const Key('consentNo')));
      await settle(tester);
      expect(find.byKey(const Key('consentDialog')), findsNothing);

      await openHome(tester);
      expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'a launch asks once');
    });

    testWidgets('a connection under the prompt closes Home after the answer', (tester) async {
      final app = await pumpAsking(tester);
      app.client.emit(const ClientSnapshot(status: ClientStatus.idle));
      forgetAsked(tester);
      await openHome(tester);
      app.client.emit(connected);
      await settle(tester);
      expect(find.byType(HomeView), findsOneWidget, reason: 'the prompt is still up');
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('consentNo')));
      await settle(tester);
      expect(find.byType(HomeView), findsNothing, reason: 'closed after the answer');
    });
  });

  group('leaving', () {
    testWidgets('a connection closes Home', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: noTips);
      app.client.emit(const ClientSnapshot(status: ClientStatus.idle));
      await openHome(tester);
      app.client.emit(connected);
      await settle(tester);
      expect(find.byType(HomeView), findsNothing);
      expect(find.byType(ControllerScreen), findsOneWidget, reason: 'back on the pad');
    });

    testWidgets('Back on a launch Home exits the app', (tester) async {
      final exit = _FakeExit();
      await pumpApp(tester, paired: true, saved: noTips, extra: [appExitProvider.overrideWithValue(exit.call)]);
      await openHome(tester, fromLaunch: true);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(exit.calls, 1, reason: 'Back asks the app to exit once');
      expect(find.byType(HomeView), findsOneWidget, reason: 'the app exits, Home is not popped');
    });

    testWidgets('Back on a Home from the pad menu returns to the pad', (tester) async {
      final exit = _FakeExit();
      await pumpApp(tester, paired: true, saved: noTips, extra: [appExitProvider.overrideWithValue(exit.call)]);
      await openHome(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(exit.calls, 0, reason: 'the pad is shown, the app does not exit');
      expect(find.byType(HomeView), findsNothing);
    });

    testWidgets('leaving before the search wait ends leaves no timer pending', (tester) async {
      await pumpApp(tester, paired: true, saved: noTips);
      await openHome(tester);
      // Home goes before homeSearchWait is up; its timer must be cancelled, as the
      // test binding fails a test that ends with a timer pending.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(HomeView), findsNothing);
    });

    testWidgets('Home on a phone that hosts live asks nothing and stays open when a client connects', (tester) async {
      final client = _SetClientState();
      await pumpHostApp(
        tester,
        saved: noTips,
        extra: [
          launchConsentAskProvider.overrideWithValue(true),
          launchConsentAskedProvider.overrideWith(_ResettableAsked.new),
          clientStateProvider.overrideWith(() => client),
        ],
      );
      await openHome(tester);
      await tester.tap(find.text(HomeText.playHere));
      await settle(tester);
      await answerConsent(tester);
      final container = hostContainer(tester);
      expect(hostOf(tester).live, isTrue, reason: 'this phone hosts a live game');
      // A launch's questions put again over a live host: the game asks instead, so Home asks nothing.
      forgetAsked(tester);
      await openHome(tester);
      expect(find.byKey(const Key('consentDialog')), findsNothing, reason: 'a live game asks nothing over Home');
      client.emit(connected);
      await settle(tester);
      expect(find.byType(HomeView), findsOneWidget, reason: 'a live host keeps Home open');
      await tester.runAsync(container.read(hostingProvider.notifier).stop);
    });
  });

  group('the looks', () {
    for (final tv in [false, true]) {
      // The pad under Home overflows by 12 px in the TV look at 568x320 (not
      // Home's doing, reported), so the TV look is checked at 852x393.
      for (final screen in [if (tv) const Size(852, 393) else const Size(568, 320), const Size(375, 667)]) {
        testWidgets('${tv ? 'TV' : 'menu'} look at ${screen.width.toInt()}x${screen.height.toInt()} shows all three', (
          tester,
        ) async {
          await pumpApp(
            tester,
            paired: true,
            saved: noTips,
            screen: screen,
            extra: [if (tv) party.toyTvProvider.overrideWithValue(true)],
          );
          expect(tester.takeException(), isNull, reason: 'the pad alone must not overflow');
          await openHome(tester);
          for (final label in [HomeText.joinGame, HomeText.playHere, HomeText.displayHere]) {
            expect(find.text(label), findsOneWidget);
          }
          expect(tester.takeException(), isNull, reason: 'no overflow');
          await tester.pump(homeSearchWait);
        });
      }
    }
  });
}
