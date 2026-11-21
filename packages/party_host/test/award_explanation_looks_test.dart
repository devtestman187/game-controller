import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/all_looks.dart';
import 'support/toy_fonts.dart';

/// The slack a measured size is compared with, as `award_explanation_size_test.dart`
/// has it: [Size] is two doubles, and a size that should be the same twice is.
const _tolerance = 1e-9;

/// One device the host lays its frame out for (DESIGN section 2; the numbers
/// are `night_start_frame_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;
}

/// The five devices every slice of the phone-host layout is checked at:
/// 640x360, 852x393, 1024x768, 1280x800 and 1920x1080 (DESIGN section 2), as
/// `award_explanation_tv_test.dart` has them.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360)),
  _Case(label: '852x393, a phone in landscape', device: Size(852, 393)),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080)),
];

/// The keyed box every award's explanation is drawn in (B-033), and the key of
/// the button that closes it.
const _cardKey = Key('awardExplanation');
const _closeKey = Key('awardExplanationClose');

/// The width a start card's tile has room for in the frame's row: about 300 at
/// the frame's 960 px. The tile is not what this test measures, so a fixed
/// width does, as one tile of the row.
const _tileWidthPx = 320.0;

/// One award's tile alone on a screen in the frame, so a test can open the "i"
/// of every one of the twelve awards without a night's draw deciding which
/// three it shows.
class _TileUnderTest extends StatelessWidget {
  const _TileUnderTest({required this.award});

  /// The award whose "i" the test opens.
  final NightAward award;

  @override
  Widget build(BuildContext context) {
    final colours = ToyLookScope.of(context).colors;
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: _tileWidthPx,
          child: AwardTile(award: award, colour: colours.player(1)),
        ),
      ),
    );
  }
}

/// Checks that [finder]'s box lies inside [box], for the line, the title and
/// the OK button the explanation is made of.
void _expectInside(WidgetTester tester, Finder finder, Rect box, String part) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(box.top), reason: '$part is inside the explanation');
  expect(rect.left, greaterThanOrEqualTo(box.left), reason: '$part is inside the explanation');
  expect(rect.bottom, lessThanOrEqualTo(box.bottom), reason: '$part is inside the explanation');
  expect(rect.right, lessThanOrEqualTo(box.right), reason: '$part is inside the explanation');
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: every award\'s explanation holds its title, line and OK in both looks', (
      tester,
    ) async {
      await forEachLook(tester, (look) async {
        for (final award in NightAward.values) {
          await pumpHostLook(
            tester,
            look,
            framed: true,
            size: frameCase.device,
            screen: _TileUnderTest(award: award),
          );
          final info = find.byKey(Key('awardInfo-${award.name}'));
          expect(info, findsOneWidget, reason: '${award.title} has its "i" in the ${look.name} look');
          await tester.tap(info);
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '${award.title}\'s line and button fit its box in the ${look.name} look',
          );
          final card = find.byKey(_cardKey);
          expect(card, findsOneWidget, reason: 'the "i" opens ${award.title}\'s explanation in the ${look.name} look');

          final line = find.descendant(of: card, matching: find.text(award.line));
          final title = find.descendant(of: card, matching: find.text(award.title));
          expect(line, findsOneWidget, reason: 'the box says who wins ${award.title} in the ${look.name} look');
          expect(title, findsOneWidget, reason: 'the box names ${award.title} in the ${look.name} look');
          final box = tester.getRect(card);
          _expectInside(tester, title, box, 'the title');
          _expectInside(tester, line, box, 'the line');
          _expectInside(tester, find.byKey(_closeKey), box, 'the OK button');

          // The body scrolls only as a guard (B-033): in both looks the box is
          // tall enough for its content, so nothing is hidden behind a scroll
          // the remote cannot work.
          final scrollable = find.descendant(of: card, matching: find.byType(Scrollable));
          expect(scrollable, findsOneWidget, reason: 'the box\'s body is the guard scroll');
          expect(
            tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
            moreOrLessEquals(0, epsilon: _tolerance),
            reason: '${award.title}\'s box fits the ${look.name} look with no scroll',
          );

          await tester.tap(find.byKey(_closeKey));
          await tester.pumpAndSettle();
          expect(
            card,
            findsNothing,
            reason: 'the OK button closes ${award.title}\'s explanation in the ${look.name} look',
          );
        }
      });
    });
  }
}
