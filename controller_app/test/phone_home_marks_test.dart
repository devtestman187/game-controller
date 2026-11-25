import 'dart:async';

import 'package:connection/connection.dart';
import 'package:controller/src/home/home_prefs.dart';
import 'package:controller/src/home/home_text.dart';
import 'package:controller/src/home/home_view.dart';
import 'package:controller/src/home/phone_home_screen.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;

import 'support/pump_app.dart';

/// A launch whose questions were put already, which a test puts back to unasked.
class _ResettableAsked extends LaunchConsentAskedNotifier {
  @override
  bool build() => true;

  void reset() => state = false;
}

/// The launch asks its consent questions, and has not asked yet.
final _asking = [
  launchConsentAskProvider.overrideWithValue(true),
  launchConsentAskedProvider.overrideWith(_ResettableAsked.new),
];

/// Puts the launch's questions back to unasked, as a first Home finds them.
void forgetAsked(WidgetTester tester) {
  final container = ProviderScope.containerOf(tester.element(find.byType(ControllerScreen, skipOffstage: false).first));
  final asked = container.read(launchConsentAskedProvider.notifier);
  if (asked is _ResettableAsked) asked.reset();
}

/// Pushes Home over the app's pad, with the client in [status] (idle: the app's
/// paired launch is still connecting), and lets its first frame run.
Future<void> openHome(WidgetTester tester, TestApp app, {ClientStatus status = ClientStatus.idle}) async {
  app.client.emit(ClientSnapshot(status: status));
  unawaited(
    Navigator.of(tester.element(find.byType(ControllerScreen, skipOffstage: false).first))
        .push(MaterialPageRoute<void>(builder: (_) => const PhoneHomeScreen(fromLaunch: false))),
  );
  await settle(tester);
  // The marks come up a frame after the questions are answered, and read their anchor a frame after that.
  await tester.pump();
  await tester.pump();
}

/// The saved `showTips` flag, or null while nothing is saved.
bool? savedTips(TestApp app) => app.prefs.getBool('showTips');

/// Lets Home's search timer run out, so no timer is left pending.
Future<void> endHome(WidgetTester tester) => tester.pump(homeSearchWait);

final _marks = find.text(HomeText.skip);

void main() {
  group('when the marks show', () {
    testWidgets('a fresh install shows them once the consent is answered, and saves nothing yet', (tester) async {
      final app = await pumpApp(tester, paired: true, extra: _asking);
      forgetAsked(tester);
      await openHome(tester, app);
      expect(find.byKey(const Key('consentDialog')), findsOneWidget);
      expect(_marks, findsNothing, reason: 'not while the consent dialog is up');
      await tester.tap(find.byKey(const Key('consentNo')));
      await settle(tester);
      expect(_marks, findsOneWidget, reason: 'the question is answered');
      expect(find.text(HomeText.tipJoin), findsOneWidget);
      expect(savedTips(app), isNull, reason: 'showing saves nothing');
      await endHome(tester);
    });

    testWidgets('a saved showTips false shows none', (tester) async {
      final app = await pumpApp(tester, paired: true, saved: {'showTips': false});
      await openHome(tester, app);
      expect(_marks, findsNothing);
      expect(find.byType(HomeView), findsOneWidget);
      // The positive control: once the flag is set on, the same Home shows the marks.
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeView)));
      await container.read(showTipsProvider.notifier).set(true);
      await settle(tester);
      await tester.pump();
      await tester.pump();
      expect(_marks, findsOneWidget, reason: 'the flag was set on');
      await endHome(tester);
    });

    testWidgets('a client that is connecting shows none', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openHome(tester, app, status: ClientStatus.connecting);
      expect(find.byType(HomeView), findsOneWidget);
      expect(_marks, findsNothing);
      expect(savedTips(app), isNull);
      // The positive control: once the client is idle, the same Home shows the marks.
      app.client.emit(const ClientSnapshot(status: ClientStatus.idle));
      await settle(tester);
      await tester.pump();
      await tester.pump();
      expect(_marks, findsOneWidget, reason: 'the client is idle now');
      await endHome(tester);
    });

    testWidgets('a Connect screen pushed over Home hides them and saves nothing', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openHome(tester, app);
      expect(_marks, findsOneWidget);
      openConnect(tester.element(find.byType(HomeView)));
      await settle(tester);
      expect(find.byType(ConnectScreen), findsOneWidget);
      expect(_marks, findsNothing, reason: 'Home is not the current route');
      expect(savedTips(app), isNull, reason: 'hiding is not finishing');
      await tester.pageBack();
      await settle(tester);
      await endHome(tester);
    });
  });

  group('what finishing saves', () {
    testWidgets('tapping through the three steps saves false', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openHome(tester, app);
      for (final tip in [HomeText.tipJoin, HomeText.tipPlay, HomeText.tipDisplay]) {
        expect(find.text(tip), findsOneWidget, reason: 'step "$tip"');
        expect(savedTips(app), isNull, reason: 'not saved before the last step');
        await tester.tap(find.text(tip));
        await settle(tester);
      }
      expect(_marks, findsNothing);
      expect(savedTips(app), isFalse);
      await endHome(tester);
    });

    testWidgets('Skip at step 1 saves false', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openHome(tester, app);
      expect(find.text(HomeText.tipJoin), findsOneWidget);
      await tester.tap(_marks);
      await settle(tester);
      expect(_marks, findsNothing);
      expect(savedTips(app), isFalse);
      await endHome(tester);
    });

    testWidgets('a tap on a role button under the marks goes to the marks, not the button', (tester) async {
      final app = await pumpApp(tester, paired: true);
      await openHome(tester, app);
      await tester.tap(find.text(HomeText.joinGame), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(ConnectScreen), findsNothing, reason: 'the overlay takes the touch');
      expect(find.text(HomeText.tipPlay), findsOneWidget, reason: 'the tap advanced the marks to step 2');
      await tester.tap(_marks);
      await settle(tester);
      expect(_marks, findsNothing, reason: 'Skip ended the marks');
      await endHome(tester);
    });
  });

  group('phoneHomeMarksIdle', () {
    bool idle({
      bool isPromptUp = false,
      ClientStatus clientStatus = ClientStatus.idle,
      bool isHostingLive = false,
      bool isCurrent = true,
    }) => phoneHomeMarksIdle(
      isPromptUp: isPromptUp,
      clientStatus: clientStatus,
      isHostingLive: isHostingLive,
      isCurrent: isCurrent,
    );

    test('is true when nothing is going on', () => expect(idle(), isTrue));
    test('is false while the prompts are up', () => expect(idle(isPromptUp: true), isFalse));
    test('is false while the client is connecting', () => expect(idle(clientStatus: ClientStatus.connecting), isFalse));
    test('is false while the client is connected', () => expect(idle(clientStatus: ClientStatus.connected), isFalse));
    test('is true when the client failed or is idle', () {
      expect(idle(clientStatus: ClientStatus.failed), isTrue);
    });
    test('is false while this phone hosts a live game', () => expect(idle(isHostingLive: true), isFalse));
    test('is false when another route is on top', () => expect(idle(isCurrent: false), isFalse));
  });

  group('the looks', () {
    for (final isTv in [false, true]) {
      for (final screen in [const Size(852, 393), const Size(375, 667)]) {
        testWidgets(
          '${isTv ? 'TV' : 'menu'} look at ${screen.width.toInt()}x${screen.height.toInt()} shows the marks',
          (tester) async {
            final app = await pumpApp(
              tester,
              paired: true,
              screen: screen,
              extra: [if (isTv) party.toyTvProvider.overrideWithValue(true)],
            );
            expect(tester.takeException(), isNull, reason: 'the pad alone must not overflow');
            await openHome(tester, app);
            expect(_marks, findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'no overflow');
            await endHome(tester);
          },
        );
      }
    }
  });
}
