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

const _voteCards = [
  ChoiceCard(id: 'shapeRace:easy', title: 'Shapes Easy', detail: 'Shape Race, easy'),
  ChoiceCard(id: 'arenaRace:playroom', title: 'Race Playroo', detail: 'Arena Race on Playroom'),
  ChoiceCard(id: 'bumperRound:pinball', title: 'Pinball', detail: 'Bumper Round on Pinball'),
  ChoiceCard(id: 'bumperRound:spinning-tops', title: 'Spinning Top', detail: 'Bumper Round on Spinning Tops'),
];

/// A vote-shaped round: four cards with detail lines, no cost, no default, 5 s left.
const _vote = ChoicesMessage(round: 7, title: 'Pick the next game', cards: _voteCards, endsInMs: 5000);

const _screens = {'360x640': Size(360, 640), '320x640': Size(320, 640), '667x375': Size(667, 375)};

/// Shows [round]; a screen narrower than [minWindowWidth] shows the overlay alone, as a widget.
Future<TestApp> _pumpRound(WidgetTester tester, ChoicesMessage round, {required bool tv, required Size screen}) async {
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
    group('a vote on the choices screen in the $lookName', () {
      for (final entry in _screens.entries) {
        testWidgets('at ${entry.key} nothing overflows and each vote card is at least 48 dp each way', (tester) async {
          final app = await _pumpRound(tester, _vote, tv: tv, screen: entry.value);
          expect(tester.takeException(), isNull, reason: 'no overflow at ${entry.key}');
          for (final card in _voteCards) {
            final size = tester.getSize(find.byKey(Key('choiceCard_${card.id}')));
            expect(size.width, greaterThanOrEqualTo(48), reason: '${card.id} width at ${entry.key}');
            expect(size.height, greaterThanOrEqualTo(48), reason: '${card.id} height at ${entry.key}');
          }
          expect(app.client.choicePicks, isEmpty, reason: 'showing the vote sends nothing');
          await _unmount(tester);
        });
      }

      testWidgets('the card details show', (tester) async {
        await _pumpRound(tester, _vote, tv: tv, screen: _screens['360x640']!);
        for (final card in _voteCards) {
          expect(find.text(card.detail!), findsOneWidget, reason: card.id);
        }
        await _unmount(tester);
      });

      testWidgets('a tap on a card sends a pick for it and a second tap clears it', (tester) async {
        final app = await _pumpRound(tester, _vote, tv: tv, screen: _screens['667x375']!);
        const id = 'bumperRound:spinning-tops';
        await _tap(tester, find.byKey(const Key('choiceCard_$id')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 7, pick: id));
        await _tap(tester, find.byKey(const Key('choiceCard_$id')));
        expect(app.client.choicePicks.last, const ChoicePickMessage(round: 7), reason: 'a null pick clears it');
        expect(app.client.choicePicks, hasLength(2));
        await _unmount(tester);
      });

      testWidgets('nothing is picked when the timer text reaches 0', (tester) async {
        final app = await _pumpRound(tester, _vote, tv: tv, screen: _screens['360x640']!);
        expect(find.text('5 s'), findsOneWidget);
        app.client.nowMs = 5000;
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('0 s'), findsOneWidget);
        expect(app.client.choicePicks, isEmpty, reason: 'the host settles an abstained vote, not the phone');
        await _unmount(tester);
      });
    });
  }
}
