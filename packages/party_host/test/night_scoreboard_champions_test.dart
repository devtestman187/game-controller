import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The device the final scores are drawn at: a laptop, where the card and its
/// crowns lay out as they do on the TV's host (DESIGN section 2).
const _laptopSize = Size(1280, 800);

/// The four phones the night is scored for, P1 first.
const _fourNames = ['Alexandria', 'Nightshade', 'Bartholome', 'Maxi'];
const _playerIds = ['p1', 'p2', 'p3', 'p4'];

/// Three rounds of points: P1 leads with 27 (9 a round), P2 has 15, P3 and P4
/// have 6 each, so P1 alone is the champion.
const _leaderPoints = {'p1': 9, 'p2': 5, 'p3': 2, 'p4': 2};

/// Three rounds of points with P1 and P2 level on top: 15 each, P3 3, P4 0, so
/// the two of them share the champion.
const _tiedPoints = {'p1': 5, 'p2': 5, 'p3': 1, 'p4': 0};

/// The night's rounds, as the scoreboard's own test records them.
const _nightLength = NightLength.three;

/// The key the card is found by, as `night_scoreboard_card_test.dart` has it.
const _cardKey = Key('nightScoreboard');

/// The night's scoreboard drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5).
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

/// Mounts the host at [_laptopSize] on the scoreboard, with the four phones
/// joined and the night played to its end: each of its three rounds gives
/// [points], and [winners] win each round.
Future<FakeHostService> _pumpFinalScores(
  WidgetTester tester, {
  required Map<String, int> points,
  required Set<String> winners,
}) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightScoreboardScreen()),
    size: _laptopSize,
  );
  // The sample state's own two phones make way for the four a test names.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < _fourNames.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: _fourNames[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();

  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: _nightLength, awards: threeAwards);
  for (var i = 0; i < _nightLength.rounds; i++) {
    night.recordRound(roundResult(points: points, winners: winners));
  }
  await tester.pumpAndSettle();
  return fake;
}

/// The champions the night names among the players the host has now, which is
/// the rule the card's crowns are checked against.
Set<String> _championsOf(WidgetTester tester) {
  final night = appContainer(tester).read(partyNightProvider);
  if (night == null) fail('no night is running');
  return night.championsAmong(appContainer(tester).read(gamePlayersProvider));
}

/// The players whose crown the card draws, out of [ids].
Set<String> _crownedIds(WidgetTester tester, Iterable<String> ids) => {
  for (final id in ids)
    if (find.byKey(Key('nightCrown-$id')).evaluate().isNotEmpty) id,
};

void main() {
  setUpAll(loadLookFonts);

  testWidgets('one leader on the final scores is the only crowned row, as championsAmong names it', (tester) async {
    await _pumpFinalScores(tester, points: _leaderPoints, winners: {'p1'});

    final champions = _championsOf(tester);
    expect(champions, {'p1'}, reason: 'P1 has 27 points, the most');
    expect(_crownedIds(tester, _playerIds), champions, reason: 'the crown sits on the champions alone');
    expect(find.byKey(_cardKey), findsOneWidget);
  });

  testWidgets('two players tied on top of the final scores are both crowned, as championsAmong shares the win', (
    tester,
  ) async {
    await _pumpFinalScores(tester, points: _tiedPoints, winners: {'p1', 'p2'});

    final champions = _championsOf(tester);
    expect(champions, {'p1', 'p2'}, reason: 'P1 and P2 have 15 points each, the most');
    expect(_crownedIds(tester, _playerIds), champions, reason: 'both tied players wear the crown');
  });

  testWidgets(
    'a leaver who finished top keeps the crown while championsAmong names them, as their row keeps its place',
    (tester) async {
      final fake = await _pumpFinalScores(tester, points: _leaderPoints, winners: {'p1'});

      fake.removeController('p1');
      fake.emit();
      await tester.pumpAndSettle();

      final champions = _championsOf(tester);
      expect(champions, {'p1'}, reason: 'P1 left holding the most points, so still the champion');
      expect(_crownedIds(tester, _playerIds), champions, reason: 'the leaver keeps the crown');
      expect(find.byKey(const Key('nightRow-p1')), findsOneWidget, reason: 'the leaver keeps their row');
    },
  );
}
