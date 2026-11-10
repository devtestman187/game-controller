import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';

import 'host_harness.dart';

/// A player, as a phone joining the roster reports one.
GamePlayer nightPlayer(String id, int number, [String? nickname]) =>
    GamePlayer(id: id, number: number, nickname: nickname);

/// A roster the test sets by hand: the host's own list is built from the host
/// service, which a unit test has not.
final class TestRoster extends GamePlayersNotifier {
  @override
  List<GamePlayer> build() => const [];

  /// Replaces the roster, as a phone joining or leaving reports it.
  void put(List<GamePlayer> players) => state = players;
}

/// A container whose roster the test sets by hand; the night is
/// [partyNightProvider] in it.
({ProviderContainer container, TestRoster roster}) nightContainer() {
  final container = ProviderContainer(overrides: [gamePlayersProvider.overrideWith(TestRoster.new)]);
  addTearDown(container.dispose);
  final roster = container.read(gamePlayersProvider.notifier) as TestRoster;
  return (container: container, roster: roster);
}

/// A round's result as a game hands it to the night (design section 2 N1).
RoundResult roundResult({
  required Map<String, int> points,
  Set<String> winners = const {},
  Map<String, Map<String, int>> stats = const {},
}) => RoundResult(game: 'puzzle', winners: winners, points: points, stats: stats);

/// Three awards, as a night's start card has drawn them.
const threeAwards = [NightAward.bestHelper, NightAward.comeback, NightAward.sharpshooter];

/// The app's container, for a widget test that sets the night up by hand.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Home → Play → Party night: the night's start card.
Future<void> openNight(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
  await tester.pumpAndSettle();
}

/// From the start card or the scoreboard: Shape Race's puzzle pick.
Future<void> pickShapeRaceRound(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('nightShapeRace')));
  await tester.pumpAndSettle();
}
