import 'package:connection/connection.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/choices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/pump_app.dart';

const _save = ChoiceCard(id: 'save', title: 'Save +2', detail: 'Keep the Bolts', cost: 0);
const _build = ChoiceCard(id: 'build', title: 'Build', detail: 'A tower', cost: 3, maxCount: 3);
const _locked = ChoiceCard(id: 'gone', title: 'Sold out', enabled: false);

ChoicesMessage _round({
  List<ChoiceCard> cards = const [_save, _build, _locked],
  int endsInMs = 12000,
  String? picked,
  int pickedCount = 1,
  bool locked = false,
  bool paused = false,
}) => ChoicesMessage(
  round: 4,
  title: 'What now?',
  cards: cards,
  endsInMs: endsInMs,
  defaultId: 'save',
  currency: 'Bolts',
  picked: picked,
  pickedCount: pickedCount,
  locked: locked,
  paused: paused,
);

const _screens = {'360x640': Size(360, 640), '320x640': Size(320, 640), '667x375': Size(667, 375)};

/// Shows [round]. The controller screen is landscape only (it shows "too small" under
/// [minWindowWidth]), so a narrower screen shows the overlay alone, as a widget.
Future<TestApp> _pumpRound(
  WidgetTester tester,
  ChoicesMessage round, {
  bool tv = false,
  Size screen = const Size(667, 375),
}) async {
  final extra = [if (tv) party.toyTvProvider.overrideWithValue(true)];
  final TestApp app;
  if (screen.width >= minWindowWidth) {
    app = await pumpApp(tester, paired: true, screen: screen, extra: extra);
    app.client.emit(connected);
    await settle(tester);
  } else {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    app = TestApp(
      FakeClient(),
      FakeDiscovery(),
      FakeHaptics(),
      await SharedPreferences.getInstance(),
      FakeMotionSensors(),
    );
    await pumpFaked(
      tester,
      Consumer(
        builder: (context, ref, _) {
          final look = ref.watch(party.toyLookProvider);
          return party.ToyLookScope(
            look: look,
            child: MaterialApp(
              theme: party.toyTheme(look),
              home: const Scaffold(body: ChoicesOverlay()),
            ),
          );
        },
      ),
      app: app,
      extra: extra,
    );
  }
  app.client.choicesRound(round);
  await _flush(tester);
  return app;
}

/// Unmounts the app so the countdown's timer is gone before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

/// Taps [finder] after scrolling it into view: at 667x375 the cards do not all fit.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Lets a message from the host reach the screen: one frame for the stream, one for the rebuild.
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final tv in [false, true]) {
    final lookName = tv ? 'TV look' : 'menu look';
    group('the choices screen in the $lookName', () {
      for (final entry in _screens.entries) {
        testWidgets('at ${entry.key} nothing overflows and every button is at least 48 dp', (tester) async {
          final app = await _pumpRound(tester, _round(), tv: tv, screen: entry.value);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${entry.key}');
          const buttons = [
            'choiceLock',
            'choiceCard_save',
            'choiceCard_build',
            'choiceMinus_build',
            'choicePlus_build',
          ];
          for (final name in buttons) {
            final size = tester.getSize(find.byKey(Key(name)));
            expect(size.width, greaterThanOrEqualTo(48), reason: '$name width at ${entry.key}');
            expect(size.height, greaterThanOrEqualTo(48), reason: '$name height at ${entry.key}');
          }
          expect(app.client.choicePicks, isEmpty, reason: 'showing the round sends nothing');
          await _unmount(tester);
        });
      }

      testWidgets('six cards scroll instead of overflowing at 667x375', (tester) async {
        final cards = [for (var i = 0; i < 6; i++) ChoiceCard(id: 'c$i', title: 'Card $i', detail: 'Line')];
        await _pumpRound(
          tester,
          _round(cards: cards),
          tv: tv,
          screen: _screens['667x375']!,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('choiceLock')), findsOneWidget, reason: 'the lock button stays on screen');
        await _unmount(tester);
      });

      testWidgets('a tap picks a card and a second tap clears it', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        await _tap(tester, find.byKey(const Key('choiceCard_save')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 4, pick: 'save'));
        await _tap(tester, find.byKey(const Key('choiceCard_save')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 4), reason: 'a null pick clears it');
        expect(app.client.choicePicks, hasLength(2));
        await _unmount(tester);
      });

      testWidgets('plus and minus keep a counted card between 1 and its maxCount', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        final picks = app.client.choicePicks;
        for (var i = 0; i < 4; i++) {
          await _tap(tester, find.byKey(const Key('choicePlus_build')));
        }
        expect([for (final p in picks) p.count], [1, 2, 3], reason: 'a fourth plus past maxCount 3 sends nothing');
        expect(find.text('Build 3'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await _tap(tester, find.byKey(const Key('choiceMinus_build')));
        }
        expect([for (final p in picks) p.count], [1, 2, 3, 2, 1], reason: 'minus stops at 1 and sends nothing there');
        expect(picks.last.pick, 'build', reason: 'a greyed button does not clear the card');
        await _unmount(tester);
      });

      testWidgets('Lock in sends locked true and Locked undoes it with locked false', (tester) async {
        final app = await _pumpRound(tester, _round(picked: 'save'), tv: tv);
        expect(find.text('Lock in'), findsOneWidget);
        await _tap(tester, find.byKey(const Key('choiceLock')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 4, pick: 'save', locked: true));
        expect(find.text('Locked'), findsOneWidget);
        await _tap(tester, find.byKey(const Key('choiceLock')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 4, pick: 'save'));
        expect(find.text('Lock in'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('a locked choice cannot be changed by a card tap', (tester) async {
        final app = await _pumpRound(tester, _round(picked: 'save', locked: true), tv: tv);
        await _tap(tester, find.byKey(const Key('choiceCard_build')));
        expect(app.client.choicePicks, isEmpty);
        await _unmount(tester);
      });

      testWidgets('a disabled card sends nothing', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        await _tap(tester, find.byKey(const Key('choiceCard_gone')));
        expect(app.client.choicePicks, isEmpty);
        await _unmount(tester);
      });

      testWidgets('the countdown runs on the phone clock and Paused stops it', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        expect(find.text('12 s'), findsOneWidget);
        expect(find.text('Paused'), findsNothing);
        app.client.nowMs = 3000;
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('9 s'), findsOneWidget, reason: '12 s minus 3 s on the phone clock');
        app.client.choicesRound(_round(endsInMs: 9000, paused: true));
        await _flush(tester);
        expect(find.text('Paused'), findsOneWidget);
        app.client.nowMs = 8000;
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('9 s'), findsOneWidget, reason: 'a paused round stands still');
        await _unmount(tester);
      });

      testWidgets('a resend with picked and locked shows them', (tester) async {
        await _pumpRound(tester, _round(picked: 'build', pickedCount: 2, locked: true), tv: tv);
        expect(find.text('Build 2'), findsOneWidget, reason: 'the held count shows after a reconnect');
        expect(find.text('Locked'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('the end says what the player got, what was chosen for them, or No choice', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        app.client.choicesEnd(const ChoicesEndMessage(round: 4, result: 'save', count: 1, byDefault: false));
        await _flush(tester);
        expect(find.text('You got: Save +2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));

        app.client.choicesRound(_round());
        await _flush(tester);
        app.client.choicesEnd(const ChoicesEndMessage(round: 4, result: 'save', count: 1, byDefault: true));
        await _flush(tester);
        expect(find.text('Chosen for you: Save +2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));

        app.client.choicesRound(_round());
        await _flush(tester);
        app.client.choicesEnd(const ChoicesEndMessage(round: 4, count: 1, byDefault: false));
        await _flush(tester);
        expect(find.text('No choice'), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('the overlay is gone 3 s after the end and the pad is back', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        expect(find.byKey(const Key('dpad')), findsNothing, reason: 'the round covers the pad');
        app.client.choicesEnd(const ChoicesEndMessage(round: 4, result: 'save', count: 1, byDefault: false));
        await _flush(tester);
        await tester.pump(const Duration(milliseconds: 2900));
        expect(find.byKey(const Key('choicesResult')), findsOneWidget, reason: 'still there before 3 s');
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const Key('choicesResult')), findsNothing);
        expect(find.byKey(const Key('dpad')), findsOneWidget);
        await _unmount(tester);
      });

      testWidgets('a dropped link clears the round', (tester) async {
        final app = await _pumpRound(tester, _round(), tv: tv);
        app.client.emit(const ClientSnapshot(status: ClientStatus.reconnecting));
        await _flush(tester);
        expect(find.byKey(const Key('choicesTitle')), findsNothing);
        await _unmount(tester);
      });
    });
  }
}
