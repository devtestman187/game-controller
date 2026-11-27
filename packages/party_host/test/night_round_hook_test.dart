import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/night/night_flow.dart';
import 'package:party_host/src/night/night_flow_controller.dart';
import 'package:party_host/src/night/night_flow_provider.dart';
import 'package:party_host/src/night/night_variant.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// Milliseconds for every card but the how-to card, which keeps its minimum so a player can read it.
const _shortPacing = NightPacing(
  setup: Duration(milliseconds: 1),
  howTo: NightPacing.minHowTo,
  results: Duration(milliseconds: 1),
  scoreboard: Duration(milliseconds: 1),
);

/// Mounts the home screen, starts a three-round night, records round 1 and pushes its scoreboard on top, as the
/// game's Next does.
Future<void> _openRoundOneScoreboard(WidgetTester tester, {List<Override> overrides = const []}) async {
  await pumpHost(tester, screen: const StubHome(), overrides: overrides);
  appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: NightLength.three, awards: threeAwards)
    ..recordRound(roundResult(points: {'p1': 5}, winners: {'p1'}));
  Navigator.of(tester.element(find.byType(StubHome)))
      .push(MaterialPageRoute<void>(builder: (_) => const NightScoreboardScreen()));
  await tester.pumpAndSettle();
}

NightFlowController _controller(WidgetTester tester) => appContainer(tester).read(nightFlowControllerProvider)!;

void main() {
  testWidgets('with no next game chosen, the scoreboard\'s button still opens its game and starts the round', (
    tester,
  ) async {
    await _openRoundOneScoreboard(tester);
    expect(_controller(tester).flow.stage, NightStage.scoreboard, reason: 'the night waits at round 1\'s scoreboard');

    await tapVisible(tester, find.byKey(const Key('nightShapeRace')));
    await tester.pumpAndSettle();

    expect(find.byType(ShapeRaceScreen), findsOneWidget, reason: 'the button opens Shape Race as before');
    expect(_controller(tester).flow.stage, NightStage.round, reason: 'the button starts round 2 in the controller');
    expect(_controller(tester).flow.round, 2);
  });

  testWidgets('with the Bumper Round chosen, the scoreboard opens it by itself after the how-to card waits', (
    tester,
  ) async {
    await _openRoundOneScoreboard(
      tester,
      overrides: [
        nightPacingProvider.overrideWithValue(_shortPacing),
        nightNextVariantProvider.overrideWithValue(NightVariant.bumperRound),
      ],
    );

    await tester.pump(NightPacing.maxHowTo);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget, reason: 'the scoreboard opens the Bumper Round by itself');
    expect(_controller(tester).flow.stage, NightStage.round);
    expect(_controller(tester).flow.round, 2);
  });

  testWidgets('with no next game chosen, the controller waits at the how-to card and nothing opens', (tester) async {
    await _openRoundOneScoreboard(tester, overrides: [nightPacingProvider.overrideWithValue(_shortPacing)]);

    await tester.pump(NightPacing.maxHowTo);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsNothing, reason: 'no variant is chosen, so no game opens');
    expect(find.byType(ShapeRaceScreen), findsNothing, reason: 'no variant is chosen, so no game opens');
    expect(find.byType(NightScoreboardScreen), findsOneWidget, reason: 'the scoreboard stays on top');
    expect(_controller(tester).flow.stage, NightStage.howTo, reason: 'the flow waits at round 2\'s how-to card');
    expect(_controller(tester).flow.round, 2);
  });

  testWidgets('leaving the scoreboard clears the controller\'s hooks, so no screen that has gone takes a round', (
    tester,
  ) async {
    await _openRoundOneScoreboard(tester);
    expect(_controller(tester).hooks, isNotNull, reason: 'the scoreboard is the controller\'s host while it shows');

    Navigator.of(tester.element(find.byType(NightScoreboardScreen))).pop();
    await tester.pumpAndSettle();

    expect(_controller(tester).hooks, isNull, reason: 'the scoreboard that set the hooks has gone');
  });
}
