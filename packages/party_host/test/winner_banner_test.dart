import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:test_game/test_game.dart' show roboPlayerId;

import 'support/all_looks.dart';
import 'support/host_harness.dart';
import 'support/night_harness.dart';

/// The winner banner over the Arena party-mode results card (M16 bugs3 B-036):
/// the winner's name, or the draw, in a box centred above the card, and the
/// round strip hidden while the results show.
void main() {
  /// The sizes the banner is checked at: the TV-shaped desk and a phone held
  /// upright, where a long name has the least width.
  const sizes = [Size(960, 540), Size(360, 640)];

  /// A round's coins for one player's line.
  RoundLine coins(RoundOutcome outcome, int count) =>
      RoundLine(outcome: outcome, count: count, countOf: RoundCount.coins);

  /// P1 Laksh and P2 Sam, joined to the round.
  List<GamePlayer> joined() => [nightPlayer('p1', 1, 'Laksh'), nightPlayer('p2', 2, 'Sam')];

  /// Mounts [ArenaResults] for [result] with [players] joined, in [look] at [size].
  Future<void> mountResults(
    WidgetTester tester,
    HostLook look,
    Size size,
    RoundResult result,
    List<GamePlayer> players,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHostLook(
      tester,
      look,
      size: size,
      framed: true,
      screen: ArenaResults(
        result: result,
        night: false,
        lastRound: false,
        againFocus: FocusNode(),
        onAgain: () {},
        onChangeMode: () {},
        onNext: () {},
        onEndNight: () {},
      ),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    (appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster).put(players);
    await tester.pump();
  }

  /// Checks the banner: centred within a pixel of [size]'s middle, above the
  /// card, and its title inside its own box.
  void expectBanner(WidgetTester tester, Size size, String title) {
    final bannerFinder = find.byKey(const Key('winnerBanner'));
    final banner = tester.getRect(bannerFinder);
    final card = tester.getRect(find.byKey(const Key('arenaResults')));
    final text = tester.getRect(find.descendant(of: bannerFinder, matching: find.text(title)));
    expect((banner.center.dx - size.width / 2).abs(), lessThanOrEqualTo(1), reason: 'the banner is centred');
    expect(banner.bottom, lessThanOrEqualTo(card.top), reason: 'the banner sits above the results card');
    expect(text.left, greaterThanOrEqualTo(banner.left), reason: 'the title is inside the box');
    expect(text.right, lessThanOrEqualTo(banner.right), reason: 'the title is inside the box');
    expect(text.top, greaterThanOrEqualTo(banner.top), reason: 'the title is inside the box');
    expect(text.bottom, lessThanOrEqualTo(banner.bottom), reason: 'the title is inside the box');
  }

  testWidgets('the banner shows the winner, or the draw, centred above the card in both looks', (tester) async {
    final winner = RoundResult(
      game: 'arena',
      winners: {'p1'},
      points: {'p1': 7, 'p2': 3},
      lines: {'p1': coins(RoundOutcome.win, 7), 'p2': coins(RoundOutcome.loss, 3)},
    );
    final draw = RoundResult(
      game: 'arena',
      winners: {},
      points: {'p1': 3, 'p2': 3},
      lines: {'p1': coins(RoundOutcome.draw, 3), 'p2': coins(RoundOutcome.draw, 3)},
    );
    final robo = RoundResult(
      game: 'arena',
      winners: {roboPlayerId},
      points: {roboPlayerId: 4, 'p1': 1},
      lines: {roboPlayerId: coins(RoundOutcome.win, 4), 'p1': coins(RoundOutcome.loss, 1)},
    );
    final cases = [
      (result: winner, title: 'P1 Laksh wins!'),
      (result: draw, title: 'Draw!'),
      (result: robo, title: 'Robo wins!'),
    ];
    await forEachLook(tester, (look) async {
      for (final size in sizes) {
        for (final c in cases) {
          await mountResults(tester, look, size, c.result, joined());
          expectBanner(tester, size, c.title);
        }
      }
    });
  });

  /// Whether the round strip (the HUD's clock, key roundTime) is drawn: no
  /// Visibility around it is hidden.
  bool roundStripShown(WidgetTester tester) => tester
      .widgetList<Visibility>(find.ancestor(of: find.byKey(const Key('roundTime')), matching: find.byType(Visibility)))
      .every((v) => v.visible);

  testWidgets('the round strip shows while the round plays and is hidden while the results show', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await neutral(tester, fake, ['p1']);
    await openArena(tester, fake);
    expect(find.byKey(const Key('roundTime')), findsOneWidget, reason: 'the strip is on the field while it plays');
    expect(roundStripShown(tester), isTrue, reason: 'the round strip shows while the round plays');

    while (arenaSnapshot(tester).timeLeftMs! > 0) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('arenaResults')), findsOneWidget, reason: 'the results show');
    expect(roundStripShown(tester), isFalse, reason: 'the results show, so the round strip is hidden (B-036)');
  });
}
