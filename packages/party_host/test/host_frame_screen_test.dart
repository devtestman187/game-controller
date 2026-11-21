import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/toy_fonts.dart';

/// The slack the frame's math is compared with, as `host_frame_test.dart` has
/// it: [Size] is two doubles, and 1024 x 768 gives a frame width of 960 within
/// one part in 10^15.
const _tolerance = 1e-9;

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_test.dart`'s).
class _Case {
  const _Case({required this.label, required this.device, required this.scale, required this.frame});

  /// The device in the brief's words, for the test's name.
  final String label;

  /// The device's logical size: its physical size at a device pixel ratio of 1.
  final Size device;

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the host lays out in, in frame px.
  final Size frame;

  /// The body's height: the frame less the 64 px header and the 84 px footer
  /// (DESIGN section 1, rule 5).
  double get bodyHeight => frame.height - 64 - 84;
}

/// The five devices every slice of the phone-host layout is checked at:
///
/// * 640x360, a small phone: s = 640/960 = .667, frame 960x540, body 392.
/// * 852x393, a phone in landscape: s = 393/540 = .728, frame 1170.687x540,
///   body 392.
/// * 1024x768, a tablet: s = 1024/960 = 1.067, frame 960x720, body 572.
/// * 1280x800, a laptop: s = 1280/960 = 1.333, frame 960x600, body 452.
/// * 1920x1080, the TV: s = 1920/960 = 2, frame 960x540, body 392.
const _cases = [
  _Case(label: '640x360, a small phone', device: Size(640, 360), scale: 0.6666666666666666, frame: Size(960, 540)),
  _Case(
    label: '852x393, a phone in landscape',
    device: Size(852, 393),
    scale: 0.7277777777777777,
    frame: Size(1170.6870229007634, 540),
  ),
  _Case(label: '1024x768, a tablet', device: Size(1024, 768), scale: 1.0666666666666667, frame: Size(960, 720)),
  _Case(label: '1280x800, a laptop', device: Size(1280, 800), scale: 1.3333333333333333, frame: Size(960, 600)),
  _Case(label: '1920x1080, the TV', device: Size(1920, 1080), scale: 2, frame: Size(960, 540)),
];

/// The keys the scaffold's three regions are found by.
const _headerKey = Key('hostFrameHeader');
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');

/// The body's list, and the footer's two buttons.
const _listKey = Key('bodyList');
const _firstButtonKey = Key('footerFirst');
const _secondButtonKey = Key('footerSecond');
const _barKey = Key('scoreRowBar');

/// How many rows the body's list holds, at 60 frame px each: 1200, more than
/// the tallest body (572) has room for, so the list scrolls.
const _tallBodyRows = 20;
const _tallRowHeightPx = 60.0;

/// The six players of a score card, the first with the design's ten-character
/// name (DESIGN section 6).
const _playerNames = ['Nightshade', 'Alexandria', 'Bright Fox', 'Milo', 'Jo', 'Ziggy'];

/// The score a card's rows are drawn against: the leader's bar fills its slack.
const _maxPoints = 30;

/// The look the frame's screens are drawn in: the TV's sizes, which are the
/// frame's (28 px buttons, 22 px body), in the Sunny palette.
ToyLook _look() => ToyLook.build(palette: ToyPalette.sunny, tv: true);

/// Mounts [home] the way a host app will (DESIGN section 5): the app's
/// [ProviderScope], the look and its theme, and the frame above the navigator
/// at [device]'s size with a device pixel ratio of 1, so logical and physical
/// pixels are the same. Returns the look the screen was drawn in.
Future<ToyLook> _pumpFrame(WidgetTester tester, Size device, {required Widget home}) async {
  final look = _look();
  tester.view.physicalSize = device;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ToyLookScope(
        look: look,
        child: MaterialApp(theme: toyTheme(look), builder: hostFrameBuilder, home: home),
      ),
    ),
  );
  return look;
}

/// The screen the frame holds: a header with its title and a chip, a body that
/// is a list longer than it, and the footer's two buttons, which count their
/// presses.
class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.onFirst, required this.onSecond});

  final VoidCallback onFirst;
  final VoidCallback onSecond;

  @override
  Widget build(BuildContext context) => HostFrameScreen(
    title: 'Party night',
    trailing: Builder(
      builder: (context) => ToyPill(label: 'Round 2 of 5', fill: ToyLookScope.of(context).colors.paper),
    ),
    body: ListView(
      key: _listKey,
      children: [for (var i = 0; i < _tallBodyRows; i++) SizedBox(height: _tallRowHeightPx, child: Text('Row $i'))],
    ),
    footer: [
      ToyButton(key: _firstButtonKey, label: 'Shape Race', onPressed: onFirst),
      ToyButton(key: _secondButtonKey, label: 'Bumper Round', onPressed: onSecond),
    ],
  );
}

/// The score card the body holds: six rows at 52 frame px, 312 together
/// (DESIGN section 4).
Widget _scoreCard({int maxPoints = _maxPoints, List<String> names = _playerNames}) => Column(
  children: [
    for (var i = 0; i < names.length; i++)
      ScoreRow(
        key: Key('scoreRow$i'),
        row: ScoreRowData(rank: i + 1, number: i + 1, name: names[i], points: maxPoints - i * 5, delta: 3),
        maxPoints: maxPoints,
      ),
  ],
);

/// The night's two round choices, as the start card's segment offers them.
const _roundOptions = [RoundOption(value: 3, label: '3 rounds'), RoundOption(value: 5, label: '5 rounds')];

/// The painter of the chip that says [label]: the look's pill, so the test can
/// read the fill the chip was drawn with.
ToyPillPainter _chipPainter(WidgetTester tester, String label) {
  final paint = tester.widget<CustomPaint>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is ToyPillPainter),
    ),
  );
  return paint.painter! as ToyPillPainter;
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    testWidgets('${frameCase.label}: a 64 px header, a flexing body and an 84 px footer at the frame\'s bottom', (
      tester,
    ) async {
      await _pumpFrame(
        tester,
        frameCase.device,
        home: _TestScreen(onFirst: () {}, onSecond: () {}),
      );

      final header = tester.getSize(find.byKey(_headerKey));
      expect(header.height, moreOrLessEquals(64, epsilon: _tolerance), reason: 'the header is 64 frame px');
      expect(header.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));

      // The title is at the header's left in the frame's title type, and the
      // screen's own chip at its right end.
      final title = tester.widget<Text>(find.text('Party night'));
      expect(title.style?.fontSize, 40, reason: 'the frame\'s title type (DESIGN section 5)');
      expect(title.maxLines, 1);
      expect(find.descendant(of: find.byKey(_headerKey), matching: find.byType(ToyPill)), findsOneWidget);

      final body = tester.getSize(find.byKey(_bodyKey));
      expect(
        body.height,
        moreOrLessEquals(frameCase.bodyHeight, epsilon: _tolerance),
        reason: 'the body takes the rest',
      );
      expect(body.width, moreOrLessEquals(frameCase.frame.width, epsilon: _tolerance));

      final footer = tester.getSize(find.byKey(_footerKey));
      expect(footer.height, moreOrLessEquals(84, epsilon: _tolerance), reason: 'the footer is 84 frame px');

      // Drawn at the device's scale, the footer's frame rect ends exactly at
      // the frame's bottom edge, so no part of it is off screen.
      final drawn = tester.getRect(find.byKey(_footerKey));
      expect(drawn.bottom, moreOrLessEquals(frameCase.device.height, epsilon: _tolerance));
      expect(drawn.top, moreOrLessEquals(frameCase.device.height - 84 * frameCase.scale, epsilon: _tolerance));
      expect(drawn.left, greaterThanOrEqualTo(0));
      expect(drawn.right, lessThanOrEqualTo(frameCase.device.width));

      expect(tester.takeException(), isNull);
    });

    testWidgets('${frameCase.label}: the footer stays put and its buttons work while the body scrolls', (tester) async {
      var first = 0;
      var second = 0;
      await _pumpFrame(
        tester,
        frameCase.device,
        home: _TestScreen(onFirst: () => first++, onSecond: () => second++),
      );

      final footerBefore = tester.getRect(find.byKey(_footerKey));
      // The body's list is longer than the body: it scrolls, and the footer
      // above nothing but the column's end never moves (rule 5).
      await tester.drag(find.byKey(_listKey), const Offset(0, -120));
      await tester.pump();
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, greaterThan(0));
      expect(tester.getRect(find.byKey(_footerKey)), footerBefore);

      await tester.tap(find.byKey(_firstButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(_secondButtonKey));
      await tester.pump();
      expect(first, 1, reason: 'the first footer button is hit-testable at the screen\'s bottom edge');
      expect(second, 1, reason: 'and so is the second');
      expect(tester.takeException(), isNull);
    });

    testWidgets('${frameCase.label}: six 52 px score rows fit the body with a ten-character name', (tester) async {
      await _pumpFrame(
        tester,
        frameCase.device,
        home: HostFrameScreen(title: 'Scores', body: _scoreCard()),
      );

      for (var i = 0; i < _playerNames.length; i++) {
        final row = find.byKey(Key('scoreRow$i'));
        final size = tester.getSize(row);
        expect(size.height, moreOrLessEquals(52, epsilon: _tolerance));
        expect(size.width, moreOrLessEquals(frameCase.frame.width - 48, epsilon: _tolerance));
      }
      expect(
        _playerNames.length * 52,
        lessThanOrEqualTo(frameCase.bodyHeight),
        reason: 'six rows of 52 frame px fit the body (DESIGN section 4)',
      );
      final name = tester.renderObject<RenderParagraph>(find.text('Nightshade'));
      expect(name.didExceedMaxLines, isFalse, reason: 'ten characters fit the 190 px column');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a score row is rank, 38 px badge, name, bar, star total and delta', (tester) async {
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: HostFrameScreen(title: 'Scores', body: _scoreCard()),
    );
    final row = find.byKey(const Key('scoreRow0'));

    expect(
      find.descendant(of: row, matching: find.text('1')),
      findsOneWidget,
      reason: 'the rank',
    );
    final badge = tester.widget<PlayerBadge>(find.descendant(of: row, matching: find.byType(PlayerBadge)));
    expect(badge.size, 38, reason: 'the design\'s 38 px badge (DESIGN section 4)');
    expect(badge.number, 1);

    final name = tester.widget<Text>(find.descendant(of: row, matching: find.text('Nightshade')));
    expect(name.overflow, TextOverflow.ellipsis, reason: 'a long name is ellipsised, not clipped');
    expect(name.maxLines, 1);
    expect(tester.getSize(find.descendant(of: row, matching: find.text('Nightshade'))).width, 190);

    expect(find.descendant(of: row, matching: find.byIcon(Icons.star)), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('$_maxPoints')),
      findsOneWidget,
      reason: 'star + total',
    );
    expect(
      find.descendant(of: row, matching: find.text('+3')),
      findsOneWidget,
      reason: 'what the round added',
    );

    // The bar is proportional to the row's 30 points of the card's 30.
    final bar = find.descendant(of: row, matching: find.byType(FractionallySizedBox));
    expect(tester.widget<FractionallySizedBox>(bar).widthFactor, moreOrLessEquals(1, epsilon: _tolerance));
    expect(tester.getSize(find.descendant(of: row, matching: find.byKey(_barKey))).height, 16);
  });

  testWidgets('a row that is not the leader fills its bar in proportion to its points', (tester) async {
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: HostFrameScreen(title: 'Scores', body: _scoreCard()),
    );
    final row = find.byKey(const Key('scoreRow2'));
    // Rank 3 has 30 - 2 * 5 = 20 of the card's 30.
    expect(
      tester
          .widget<FractionallySizedBox>(find.descendant(of: row, matching: find.byType(FractionallySizedBox)))
          .widthFactor,
      moreOrLessEquals(20 / 30, epsilon: _tolerance),
    );
  });

  testWidgets('the bar takes the slack, so a wider frame makes it wider', (tester) async {
    final home = HostFrameScreen(title: 'Scores', body: _scoreCard());
    await _pumpFrame(tester, const Size(640, 360), home: home);
    final narrow = tester.getSize(
      find.descendant(of: find.byKey(const Key('scoreRow0')), matching: find.byKey(_barKey)),
    );

    await _pumpFrame(tester, const Size(852, 393), home: home);
    final wide = tester.getSize(find.descendant(of: find.byKey(const Key('scoreRow0')), matching: find.byKey(_barKey)));

    // 852x393's frame is 1170.687 wide: 210.687 frame px more than 960, and
    // every one of them goes to the bar.
    expect(wide.width - narrow.width, moreOrLessEquals(210.6870229007634, epsilon: 1e-6));
  });

  testWidgets('a name too long for the column is ellipsised', (tester) async {
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: HostFrameScreen(
        title: 'Scores',
        body: _scoreCard(names: const ['Bartholomew Alexander']),
      ),
    );
    final long = tester.renderObject<RenderParagraph>(find.text('Bartholomew Alexander'));
    expect(long.didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every text in a score row is at least 20 frame px', (tester) async {
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: HostFrameScreen(title: 'Scores', body: _scoreCard()),
    );
    final texts = tester.widgetList<Text>(
      find.descendant(of: find.byKey(const Key('scoreRow0')), matching: find.byType(Text)),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.style?.fontSize, greaterThanOrEqualTo(20), reason: '"${text.data}" is a frame size (rule 3)');
    }
  });

  testWidgets('a round segment shows its two chips and fills the chosen one', (tester) async {
    final look = await _pumpFrame(
      tester,
      const Size(640, 360),
      home: Scaffold(
        body: Center(
          child: RoundSegment(value: 3, onChanged: (_) {}, options: _roundOptions),
        ),
      ),
    );

    expect(find.text('3 rounds'), findsOneWidget);
    expect(find.text('5 rounds'), findsOneWidget);
    expect(_chipPainter(tester, '3 rounds').fill, look.colors.focus, reason: 'the chosen chip takes the focus yellow');
    expect(_chipPainter(tester, '5 rounds').fill, look.colors.paper);
    for (final label in ['3 rounds', '5 rounds']) {
      expect(tester.widget<Text>(find.text(label)).style?.fontSize, greaterThanOrEqualTo(20));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking the other chip reports its own value', (tester) async {
    final picks = <int>[];
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: Scaffold(
        body: Center(
          child: RoundSegment(value: 5, onChanged: picks.add, options: _roundOptions),
        ),
      ),
    );

    await tester.tap(find.text('3 rounds'));
    await tester.pump();
    expect(picks, [3]);
  });

  testWidgets('a chip takes the focus and the centre key picks it', (tester) async {
    final picks = <int>[];
    await _pumpFrame(
      tester,
      const Size(640, 360),
      home: Scaffold(
        body: Center(
          child: RoundSegment(value: 5, onChanged: picks.add, options: _roundOptions),
        ),
      ),
    );

    // A direction key moves the focus to the first chip, as the remote's pad
    // does (PRD v2 T21).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    expect(focus?.context?.findAncestorWidgetOfExactType<RoundSegment>(), isNotNull, reason: 'the chip is focusable');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picks, [3], reason: 'the first chip is the three-round one');
  });
}
