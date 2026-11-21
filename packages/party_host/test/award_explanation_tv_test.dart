import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
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
/// 640x360, 852x393, 1024x768, 1280x800 and 1920x1080 (DESIGN section 2).
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

/// The height the explanation needs in the TV look, in frame px (M16 bugs1 f1):
/// B-033's 207 was measured with the menu's 48 px OK button, so the same card
/// with the TV's 64 px one needs 207 - 48 + 64.
const _tvHeightPx = 223.0;

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

/// Mounts [award]'s tile in the frame at [device]'s size in the TV look, as
/// the TV app draws it, and opens its "i", so the explanation is over the
/// screen when it returns.
Future<void> _openExplanation(WidgetTester tester, NightAward award, Size device) async {
  await pumpHost(
    tester,
    framed: true,
    size: device,
    screen: _TileUnderTest(award: award),
    overrides: [toyTvProvider.overrideWithValue(true)],
  );
  final info = find.byKey(Key('awardInfo-${award.name}'));
  expect(info, findsOneWidget, reason: '${award.title} has its "i"');
  await tester.tap(info);
  await tester.pumpAndSettle();
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
    testWidgets('${frameCase.label}: the TV look\'s explanation holds its OK button with no scroll', (tester) async {
      final sizes = <String, Size>{};
      for (final award in NightAward.values) {
        await _openExplanation(tester, award, frameCase.device);
        expect(tester.takeException(), isNull, reason: '${award.title}\'s line and button fit its box');
        final card = find.byKey(_cardKey);
        expect(card, findsOneWidget, reason: 'the "i" opens ${award.title}\'s explanation');
        sizes[award.title] = tester.getSize(card);

        final line = find.descendant(of: card, matching: find.text(award.line));
        final title = find.descendant(of: card, matching: find.text(award.title));
        expect(line, findsOneWidget, reason: 'the box says who wins ${award.title}');
        expect(title, findsOneWidget, reason: 'the box names ${award.title}');
        final box = tester.getRect(card);
        _expectInside(tester, title, box, 'the title');
        _expectInside(tester, line, box, 'the line');
        _expectInside(tester, find.byKey(_closeKey), box, 'the OK button');

        // The body scrolls only as a guard (B-033): in the TV look the box is
        // tall enough for its content, so nothing is hidden behind a scroll the
        // remote cannot work.
        final scrollable = find.descendant(of: card, matching: find.byType(Scrollable));
        expect(scrollable, findsOneWidget, reason: 'the box\'s body is the guard scroll');
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          moreOrLessEquals(0, epsilon: _tolerance),
          reason: '${award.title}\'s box fits the TV look with no scroll',
        );

        await tester.tap(find.byKey(_closeKey));
        await tester.pumpAndSettle();
        expect(card, findsNothing, reason: 'the OK button closes ${award.title}\'s explanation');
      }

      // B-033: one box for all twelve awards, so a player's eye finds the same
      // card whatever line it holds.
      final measured = sizes.values.toList();
      final first = measured.first;
      for (final size in measured) {
        expect(
          size.width,
          moreOrLessEquals(first.width, epsilon: _tolerance),
          reason: 'every award\'s box is the same width: $sizes',
        );
        expect(
          size.height,
          moreOrLessEquals(first.height, epsilon: _tolerance),
          reason: 'every award\'s box is the same height: $sizes',
        );
      }
      expect(first.width, moreOrLessEquals(awardExplanationWidthPx, epsilon: _tolerance));
      expect(
        first.height,
        moreOrLessEquals(_tvHeightPx, epsilon: _tolerance),
        reason: 'the box is as tall as the TV look\'s button needs',
      );
      final frame = HostFrameInfo.of(tester.element(find.byType(Scaffold))).frame;
      expect(first.width, lessThanOrEqualTo(frame.width), reason: 'the box fits the frame\'s width');
      expect(first.height, lessThanOrEqualTo(frame.height), reason: 'the box fits the frame\'s height');
    });
  }
}
