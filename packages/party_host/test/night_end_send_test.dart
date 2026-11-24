import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The night's end the host sends the phones when the awards reveal ends or is
/// skipped (M16 bugs4 nh2): once, with the night's awards in order and the final
/// standings, award points included.
void main() {
  /// Both phones joined as players 1 and 2: the sample state has Ben's phone
  /// still pairing, so the night would never have heard of him (M16 bugs4 nh2).
  Future<void> joinTwoPhones(WidgetTester tester, FakeHostService fake) async {
    ControllerInfo phone(String id, int player) => ControllerInfo(
      controllerId: id,
      name: 'Phone $id',
      platform: 'ios',
      appVersion: '0.6.0',
      remoteAddress: '192.168.1.$player',
      state: ControllerState.connected,
      since: DateTime(2026),
      player: player,
    );
    fake.state = HostViewState(
      hostName: 'TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '1234',
        controllers: [phone('p1', 1), phone('p2', 2)],
      ),
    );
    fake.emit();
    // The roster reaches the night's providers on the next turn of the event loop, before the night starts.
    await tester.pump();
  }

  /// Plays a night of three rounds under the reveal's awards [awards] (M16 bugs4
  /// nh2): p1 scores 9 and p2 7, p2's one carry is the only one, so Best Helper
  /// is p2's, and p1's 3 in the last round is the most, so Comeback is p1's.
  Future<void> playNight(WidgetTester tester, FakeHostService fake, {required List<NightAward> awards}) async {
    await joinTwoPhones(tester, fake);
    final night = appContainer(tester).read(partyNightProvider.notifier)
      ..start(length: NightLength.three, awards: awards);
    night
      ..recordRound(
        roundResult(
          points: {'p1': 3, 'p2': 4},
          stats: {
            'p2': {'carries': 1},
          },
        ),
      )
      ..recordRound(roundResult(points: {'p1': 3, 'p2': 2}))
      ..recordRound(roundResult(points: {'p1': 3, 'p2': 1}));
    await tester.pump();
  }

  const mainAwards = [NightAward.bestHelper, NightAward.comeback, NightAward.catCatcher];

  testWidgets('nothing is sent to the phones while the reveal runs', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    await playNight(tester, fake, awards: mainAwards);

    expect(fake.gameHost.shownNightEnds, isEmpty, reason: 'the first award is still on the screen');
    await tester.pump(const Duration(milliseconds: nightAwardRevealMs));
    expect(fake.gameHost.shownNightEnds, isEmpty, reason: 'the second award is on the screen');
  });

  testWidgets('Escape skips the reveal and sends the night\'s end exactly once', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    await playNight(tester, fake, awards: mainAwards);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(fake.gameHost.shownNightEnds, hasLength(1));
  });

  testWidgets('the reveal\'s timer sends the night\'s end exactly once, when the last award has shown', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    await playNight(tester, fake, awards: mainAwards);

    // Two won awards of four seconds each, then one nobody won for two: 10 s in all.
    await tester.pump(const Duration(milliseconds: nightAwardRevealMs * 2));
    expect(fake.gameHost.shownNightEnds, isEmpty, reason: 'Cat Catcher is still to show');
    await tester.pump(const Duration(milliseconds: nightAwardMissedRevealMs));
    await tester.pumpAndSettle();

    expect(fake.gameHost.shownNightEnds, hasLength(1));
  });

  testWidgets('the night\'s end carries its three awards in the order revealed, with the winners', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    await playNight(tester, fake, awards: mainAwards);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final awards = fake.gameHost.shownNightEnds.single.awards;
    expect(awards.map((award) => award.id), ['bestHelper', 'comeback', 'catCatcher']);
    expect(awards.map((award) => award.name), ['Best Helper', 'Comeback', 'Cat Catcher']);
    expect(awards.map((award) => award.points), [awardPoints, awardPoints, awardPoints]);
    expect(awards.map((award) => award.winners), [
      ['p2'],
      ['p1'],
      <String>[],
    ], reason: 'an award nobody won has no winners');
    expect(awards.map((award) => award.reason), [
      'Most carries home together: 1',
      'Most points in the last round: 3',
      null,
    ]);
  });

  testWidgets('the night\'s end standings are the night\'s rows, with their ids and the award points', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    await playNight(tester, fake, awards: mainAwards);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final players = appContainer(tester).read(gamePlayersProvider);
    final rows = appContainer(tester).read(partyNightProvider)!.rows(players);
    final standings = fake.gameHost.shownNightEnds.single.standings;
    expect(standings.map((standing) => standing.id), ['p1', 'p2']);
    expect(standings.map((standing) => standing.points), [12, 10], reason: 'Mia 9 + Comeback 3, Ben 7 + Best Helper 3');
    expect(standings.map((standing) => standing.points), rows.map((row) => row.total));
    expect(standings.map((standing) => standing.id), rows.map((row) => row.id));
    expect(standings.map((standing) => standing.number), rows.map((row) => row.number));
  });

  testWidgets('when the awards change who is first, the night\'s end leads with the final first place', (tester) async {
    final fake = await pumpHost(tester, screen: const NightRevealScreen());
    // p1 leads 9 to 7 before the awards; Best Helper alone (p2 +3) takes p2 to 10.
    await playNight(tester, fake, awards: const [NightAward.bestHelper, NightAward.catCatcher, NightAward.tryAgain]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final standings = fake.gameHost.shownNightEnds.single.standings;
    expect(standings.first.id, 'p2', reason: 'the award takes Ben past Mia');
    expect(standings.map((standing) => standing.points), [10, 9]);
  });
}
