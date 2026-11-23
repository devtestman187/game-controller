import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/all_looks.dart';

/// The key the test gives the crown on the winner's badge, so its box can be read.
const _crownKey = Key('winnerCrown');

/// The winner's badge diameter the design asks for (DESIGN section 4, "48 px
/// badge"), in frame px.
const _winnerBadgePx = 48.0;

/// How far the crown's bottom edge sits over the disc's top, in frame px: a few
/// px, so the crown reads as seated on the rim rather than floating above it.
const _rimOverlapMinPx = 2.0;
const _rimOverlapMaxPx = 6.0;

/// The most the rank's text may be tall inside its podium disc, as a share of the
/// disc's diameter, so the number sits inside the disc and its outline.
const _rankTextMaxShare = 0.625;

/// Mounts the winner's row, a gold podium disc with rank 1 and a crown on its
/// badge, in [look]: the menu's sizes and type, or the TV's (review-rules part A
/// item 6). Player 2 is the winner, so the badge draws no second "1" for the rank.
Future<void> _pumpWinner(WidgetTester tester, HostLook look) async {
  final toyLook = ToyLook.build(palette: ToyPalette.sunny, tv: look == HostLook.tv);
  await tester.pumpWidget(
    ToyLookScope(
      look: toyLook,
      child: MaterialApp(
        theme: toyTheme(toyLook),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 912,
              child: ScoreRow(
                row: ScoreRowData(
                  rank: 1,
                  number: 2,
                  name: 'Nightshade',
                  points: 30,
                  isWinner: true,
                  medal: ScoreRowMedal.gold,
                ),
                maxPoints: 30,
                badgeMark: NightCrown(key: _crownKey, size: 30),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The podium disc: the 32 px box the rank's medal is drawn in.
Finder get _medalDisc =>
    find.byWidgetPredicate((w) => w is SizedBox && w.width == scoreRowMedalPx && w.height == scoreRowMedalPx);

void main() {
  testWidgets('the winner\'s badge is 48 px wide in every look', (tester) async {
    await forEachLook(tester, (look) async {
      await _pumpWinner(tester, look);

      expect(tester.getSize(find.byType(PlayerBadge)).width, _winnerBadgePx, reason: 'the winner\'s badge is 48 px');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the crown is seated on the rim: its bottom edge a few px over the disc\'s top, centred', (tester) async {
    await forEachLook(tester, (look) async {
      await _pumpWinner(tester, look);

      final badge = tester.getRect(find.byType(PlayerBadge));
      final crown = tester.getRect(find.byKey(_crownKey));
      final overlap = crown.bottom - badge.top;
      expect(
        overlap,
        inInclusiveRange(_rimOverlapMinPx, _rimOverlapMaxPx),
        reason: 'the crown\'s bottom edge sits a few px over the disc\'s top, not above it',
      );
      expect((crown.center.dx - badge.center.dx).abs(), lessThan(0.5), reason: 'the crown is centred on the disc');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the rank in a podium disc sits inside the disc and its outline', (tester) async {
    await forEachLook(tester, (look) async {
      await _pumpWinner(tester, look);

      final disc = tester.getRect(_medalDisc);
      final text = tester.getRect(find.descendant(of: _medalDisc, matching: find.text('1')));
      expect(text.left, greaterThanOrEqualTo(disc.left), reason: 'the number is inside the disc, on the left');
      expect(text.right, lessThanOrEqualTo(disc.right), reason: 'the number is inside the disc, on the right');
      expect(text.top, greaterThanOrEqualTo(disc.top), reason: 'the number is inside the disc, at the top');
      expect(text.bottom, lessThanOrEqualTo(disc.bottom), reason: 'the number is inside the disc, at the bottom');
      expect(
        text.height,
        lessThanOrEqualTo(disc.height * _rankTextMaxShare),
        reason: 'the number is at most 0.625 of the disc (20 px floor in a 32 px disc) high',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
