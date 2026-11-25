import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The three players every night here has, by id: P1 is the sample host's own
/// phone, and P2 and P3 join as [_join] makes them.
const _playerIds = ['p1', 'p2', 'p3'];

/// The name each player's winner line shows (`NightText.playerName`): P1's
/// nickname from the sample state, and the default name [phoneInfo] gives the
/// phones that join.
const _names = {'p1': 'iPhone 3F1C', 'p2': 'Phone 2', 'p3': 'Phone 3'};

/// Joins P2 and P3 to the host's roster as two connected phones (as
/// arena_night_test's phones are), so each can win an award and be named.
Future<void> _join(WidgetTester tester, FakeHostService fake) async {
  fake.state = withController(withController(fake.state, phoneInfo('p2', 2)), phoneInfo('p3', 3));
  await tester.pump();
  await tester.pump();
}

/// The night's three rounds, as the game hands each to the night (design section 2 N1).
///
/// Round points: P1 5 + 2 + 4 = 11, P2 2 + 4 + 1 = 7, P3 1 + 0 + 0 = 1. Counters summed over the
/// night: carries P1 3, P2 3, P3 1; snaps and wrong drops P1 5 and 1, P2 9 and 3, P3 2 and 2.
/// The last round's points are P1 4, P2 1, P3 0.
final _rounds = [
  roundResult(
    points: {'p1': 5, 'p2': 2, 'p3': 1},
    winners: {'p1'},
    stats: {
      'p1': {'carries': 2, 'snaps': 3, 'wrongDrops': 1},
      'p2': {'carries': 1, 'snaps': 4, 'wrongDrops': 0},
      'p3': {'carries': 0, 'snaps': 1, 'wrongDrops': 2},
    },
  ),
  roundResult(
    points: {'p1': 2, 'p2': 4, 'p3': 0},
    winners: {'p2'},
    stats: {
      'p1': {'carries': 1, 'snaps': 2, 'wrongDrops': 0},
      'p2': {'carries': 2, 'snaps': 3, 'wrongDrops': 2},
      'p3': {'carries': 1, 'snaps': 1, 'wrongDrops': 0},
    },
  ),
  roundResult(
    points: {'p1': 4, 'p2': 1, 'p3': 0},
    winners: {'p1'},
    stats: {
      'p1': {'carries': 0, 'snaps': 0, 'wrongDrops': 0},
      'p2': {'carries': 0, 'snaps': 2, 'wrongDrops': 1},
      'p3': {'carries': 0, 'snaps': 0, 'wrongDrops': 0},
    },
  ),
];

/// One award as the reveal names it: its winners (ids, empty when nobody won) and the reason line
/// it shows with them (null when nobody won).
typedef _Reveal = ({NightAward award, List<String> winners, String? reason});

/// A night's awards in the start card's order, and what the reveal names for each, in that order.
typedef _Night = ({List<NightAward> awards, List<_Reveal> reveals});

/// The three awards with a tie: P1 and P2 carry 3 each (Best Helper, both win), P1 has the last round's
/// 4 points (Comeback) and the fewest wrong drops of the players with 3 snaps or more (Sharpshooter).
/// Final scores: P1 11 + 3 × 3 = 20, P2 7 + 3 × 1 = 10, P3 1.
final _tieNight = (
  awards: threeAwards,
  reveals: <_Reveal>[
    (award: NightAward.bestHelper, winners: ['p1', 'p2'], reason: 'Most carries home together: 3'),
    (award: NightAward.comeback, winners: ['p1'], reason: 'Most points in the last round: 4'),
    (award: NightAward.sharpshooter, winners: ['p1'], reason: 'Fewest wrong drops: 1'),
  ],
);

/// Cat Catcher counts shooed cats, which no round reports: nobody wins it, and its +0 leaves
/// the other two as in [_tieNight]. Final scores: P1 11 + 3 × 2 = 17, P2 7 + 3 = 10, P3 1.
final _missedNight = (
  awards: const [NightAward.catCatcher, NightAward.bestHelper, NightAward.sharpshooter],
  reveals: <_Reveal>[
    (award: NightAward.catCatcher, winners: <String>[], reason: null),
    (award: NightAward.bestHelper, winners: ['p1', 'p2'], reason: 'Most carries home together: 3'),
    (award: NightAward.sharpshooter, winners: ['p1'], reason: 'Fewest wrong drops: 1'),
  ],
);

/// A player's round points over the night, as the rounds gave them.
int _roundPoints(String id) => _rounds.fold(0, (sum, round) => sum + (round.points[id] ?? 0));

/// Plays [night] in [look] at [size] from the start card to the final scores. The card shows the
/// night's awards; the reveal names each in turn with its winners and reason; each final score is
/// the round points plus [awardPoints] per award the reveal named the player for. As a phone host
/// the phone's share flag is set too, as end_night_arena_test's phone-host case does.
Future<void> _playNight(
  WidgetTester tester,
  HostLook look,
  _Night night, {
  Size size = const Size(960, 540),
  bool phoneHost = false,
}) async {
  final start = await pumpHostLook(tester, look, screen: const StubHome(), size: size, framed: phoneHost);
  if (phoneHost) start.shareView = true;
  await _join(tester, start);
  appContainer(tester).read(partyNightProvider.notifier).start(length: NightLength.three, awards: night.awards);
  await openNight(tester);
  final shown = [for (final card in tester.widgetList<AwardTile>(find.byType(AwardTile))) card.award];
  expect(shown, night.awards, reason: 'the start card shows the night\'s three awards, in its order');

  // The reveal is a fresh mount: the night it names is the one the card showed, with the same rounds.
  await tester.pumpWidget(const SizedBox.shrink());
  final reveal = await pumpHostLook(tester, look, screen: const NightRevealScreen(), size: size, framed: phoneHost);
  if (phoneHost) reveal.shareView = true;
  await _join(tester, reveal);
  final played = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: NightLength.three, awards: shown);
  for (final round in _rounds) {
    played.recordRound(round);
  }
  await tester.pump();

  for (final (i, outcome) in night.reveals.indexed) {
    expect(find.text(outcome.award.title), findsOneWidget, reason: 'reveal ${i + 1} names ${outcome.award.title}');
    if (i == 0) {
      for (final id in outcome.winners) {
        expect(find.text(_names[id]!), findsOneWidget, reason: 'BISECT $id');
      }
      return;
    }
    final reason = outcome.reason;
    if (reason == null) {
      expect(find.text('Not won tonight'), findsOneWidget, reason: '${outcome.award.title} is not won');
    } else {
      for (final id in outcome.winners) {
        expect(find.text(_names[id]!), findsOneWidget, reason: '${outcome.award.title} names $id');
      }
      expect(find.text(reason), findsOneWidget);
      expect(find.text('+$awardPoints points'), findsOneWidget, reason: 'each winner gets the award\'s points');
    }
    final stayMs = reason == null ? nightAwardMissedRevealMs : nightAwardRevealMs;
    await tester.pump(Duration(milliseconds: stayMs));
  }

  await tester.pumpAndSettle();
  expect(find.byType(NightScoreboardScreen), findsOneWidget, reason: 'the final scores follow the reveal');
  final host = appContainer(tester).read(partyNightProvider)!;
  for (final id in _playerIds) {
    final roundPoints = _roundPoints(id);
    final won = night.reveals.where((outcome) => outcome.winners.contains(id)).length;
    expect(host.awardsWonBy(id), won, reason: '$id wins as many awards as the reveal named');
    expect(host.totals[id], roundPoints, reason: '$id\'s round points are the rounds\' sum');
    expect(
      tester.widget<Text>(find.byKey(Key('nightTotal-$id'))).data,
      '${roundPoints + awardPoints * won}',
      reason: '$id\'s final score is round points plus $awardPoints per award won',
    );
  }
}

/// The awards flow from the start card to the final scores (M14 c2, design section 6, PRD item 7):
/// the card's awards are the ones the reveal names in turn, a tied award goes to every player level
/// on its best value, and an award nobody won adds nothing.
void main() {
  testWidgets('a night with a tied award: the card, the reveal and the final scores agree in both looks', (
    tester,
  ) async {
    await forEachLook(tester, (look) => _playNight(tester, look, _tieNight));
  });

  testWidgets('an award nobody won is revealed as "Not won tonight" and adds no points, in both looks', (tester) async {
    await forEachLook(tester, (look) => _playNight(tester, look, _missedNight));
  });

  testWidgets('a phone host at 640x360 plays the tied night to the same final scores', (tester) async {
    await _playNight(tester, HostLook.menu, _tieNight, size: const Size(640, 360), phoneHost: true);
  });
}
