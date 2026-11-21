import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:test_game/test_game.dart' show roboPlayerId;

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// The slack sizes are compared with, as `host_frame_screen_test.dart` has it:
/// [Size] is two doubles, and a frame's arithmetic leaves noise in the last
/// digits.
const _tolerance = 1e-9;

/// One device, with the scale and the frame the design's math gives it (DESIGN
/// section 2; the numbers are `host_frame_screen_test.dart`'s).
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

/// The names the four and the six phones join with: at most ten characters, the
/// longest a real host keeps, so the rows show what they show with real names
/// (DESIGN section 6).
const _fourNames = ['Alexandria', 'Nightshade', 'Bartholome', 'Maxi'];
const _sixNames = [..._fourNames, 'WWWWWWWWWW', 'iiiiiiiiii'];

/// The points a round gave the joined players (P1 first): a leader, then two
/// players level in third, so the rows show "1" and "3=" (DESIGN section 4).
const _fourPoints = {'p1': 9, 'p2': 5, 'p3': 2, 'p4': 2};
const _sixPoints = {'p1': 9, 'p2': 7, 'p3': 3, 'p4': 3, 'p5': 2, 'p6': 1};

/// The night a test scores: three rounds, the three awards by hand.
const _nightLength = NightLength.three;

/// The keys the frame's regions and the scoreboard's parts are found by.
const _headerKey = Key('hostFrameHeader');
const _bodyKey = Key('hostFrameBody');
const _footerKey = Key('hostFrameFooter');
const _chipKey = Key('nightScoreChip');
const _backKey = Key('nightBackToGames');
const _shapeRaceKey = Key('nightShapeRace');
const _bumperKey = Key('nightBumper');

const _fourPlayers = 4;
const _sixPlayers = 6;

/// Every way a roster and its points go together: four players and six.
const _rosters = [(_fourPlayers, _fourNames, _fourPoints), (_sixPlayers, _sixNames, _sixPoints)];

/// The night's scoreboard drawn in the host's frame, as the app draws every
/// screen (DESIGN section 5): [hostFrameBuilder] over it, so the screen lays
/// out at the frame's size with the frame's type.
class _NightInFrame extends StatelessWidget {
  const _NightInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

Key _rowKey(String id) => Key('nightRow-$id');

/// Mounts the host at [device]'s size on the scoreboard in the frame, with the
/// phones of [names] joined and [rounds] of the night's three recorded, each
/// round giving [points] and P1 winning it.
Future<FakeHostService> _pumpScoreboard(
  WidgetTester tester,
  Size device, {
  required List<String> names,
  required Map<String, int> points,
  int rounds = 1,
}) async {
  final fake = await pumpHost(
    tester,
    screen: const _NightInFrame(child: NightScoreboardScreen()),
    size: device,
  );
  // The sample state's own two phones make way for the roster a test names.
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < names.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: names[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();

  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: _nightLength, awards: threeAwards);
  for (var i = 0; i < rounds; i++) {
    night.recordRound(roundResult(points: points, winners: {'p1'}));
  }
  await tester.pumpAndSettle();
  return fake;
}

/// Whether [id]'s row wears a disc of [colour]: the podium's metal (DESIGN
/// section 4, the final scores).
bool _wearsDisc(WidgetTester tester, String id, Color colour) => find
    .descendant(
      of: find.byKey(_rowKey(id)),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == colour,
      ),
    )
    .evaluate()
    .isNotEmpty;

/// How wide [text] is drawn in [fontSize] with the look's real font: what the
/// name column has to hold (DESIGN section 6: "re-measure in Flutter").
double _widthOf(String text, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: ToyType.frame.body.copyWith(fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// How much a row's bar has filled: the box that shows the row's share of the
/// card's leader, or null when the row has none.
double _barFill(WidgetTester tester, String id) {
  final fill = find.descendant(
    of: find.descendant(of: find.byKey(_rowKey(id)), matching: find.byKey(const Key('scoreRowBar'))),
    matching: find.byType(FractionallySizedBox),
  );
  // An empty bar is its track alone: no fill widget, which reads as a share of
  // 0.
  if (fill.evaluate().isEmpty) return 0.0;
  return tester.widget<FractionallySizedBox>(fill).widthFactor!;
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    for (final (players, names, points) in _rosters) {
      testWidgets('${frameCase.label}, $players players: no scroll, 52 px rows and the footer on screen', (
        tester,
      ) async {
        await _pumpScoreboard(tester, frameCase.device, names: names, points: points);

        expect(
          find.descendant(of: find.byKey(_bodyKey), matching: find.byType(Scrollable)),
          findsNothing,
          reason: 'the rows fit the body, so nothing scrolls (DESIGN section 1, rule 6)',
        );
        expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

        for (final id in points.keys) {
          expect(
            tester.getSize(find.byKey(_rowKey(id))).height,
            moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance),
            reason: "$id's row is the design's 52 px line",
          );
        }
        for (final key in [_shapeRaceKey, _bumperKey]) {
          final rect = tester.getRect(find.byKey(key));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$key is on screen');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '$key is on screen');
          expect(rect.right, lessThanOrEqualTo(frameCase.device.width), reason: '$key is on screen');
          expect(rect.bottom, lessThanOrEqualTo(frameCase.device.height + _tolerance), reason: '$key is on screen');
          expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
        }
      });

      testWidgets('${frameCase.label}, $players players: every text on the scoreboard is at least 20 frame px', (
        tester,
      ) async {
        await _pumpScoreboard(tester, frameCase.device, names: names, points: points);
        final texts = find.descendant(of: find.byType(NightScoreboardScreen), matching: find.byType(Text));
        expect(texts, findsWidgets);
        for (final element in texts.evaluate()) {
          final text = element.widget as Text;
          final style = DefaultTextStyle.of(element).style.merge(text.style);
          expect(
            style.fontSize,
            greaterThanOrEqualTo(20),
            reason: '"${text.data ?? text.textSpan?.toPlainText()}" is a frame size (DESIGN rule 3)',
          );
        }
      });
    }
  }

  testWidgets('the header says which round it is, and before the last round it says the round is double', (
    tester,
  ) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints);
    expect(find.text('Round 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('nightLastRoundBanner')), findsNothing, reason: 'two rounds come after this one');
  });

  testWidgets('before the last round the header carries the banner in its 48 px chip line', (tester) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints, rounds: 2);

    expect(find.text('Round 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('nightLastRoundBanner')), findsOneWidget, reason: 'the next round is worth double');
    expect(
      tester.getSize(find.byKey(_chipKey)).height,
      moreOrLessEquals(roundChipHeightPx, epsilon: _tolerance),
      reason: 'the trailing chip line is the header chip height',
    );
    final header = tester.getRect(find.byKey(_headerKey));
    final chip = tester.getRect(find.byKey(_chipKey));
    expect(chip.top, greaterThanOrEqualTo(header.top), reason: 'the chip is inside the header');
    expect(chip.bottom, lessThanOrEqualTo(header.bottom), reason: 'the chip is inside the header');
  });

  testWidgets('the final scores say so in the header and drop the banner', (tester) async {
    await _pumpScoreboard(
      tester,
      const Size(640, 360),
      names: _fourNames,
      points: _fourPoints,
      rounds: _nightLength.rounds,
    );

    expect(find.text('Final scores'), findsOneWidget);
    expect(find.byKey(const Key('nightLastRoundBanner')), findsNothing, reason: 'no round is left to play');
  });

  testWidgets('two players on the same total share their place, so the row reads "3=" and "1"', (tester) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints);

    expect(tester.widget<Text>(find.byKey(const Key('nightPlace-p1'))).data, '1');
    expect(tester.widget<Text>(find.byKey(const Key('nightPlace-p2'))).data, '2');
    expect(tester.widget<Text>(find.byKey(const Key('nightPlace-p3'))).data, '3=', reason: 'P3 and P4 are level');
    expect(tester.widget<Text>(find.byKey(const Key('nightPlace-p4'))).data, '3=');
  });

  testWidgets('a player who left is greyed and Robo is drawn full, as it is never away', (tester) async {
    final fake = await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints);
    // Robo plays a round of its own (party-night §7a): it gets a row.
    appContainer(tester).read(partyNightProvider.notifier).recordRound(roundResult(points: {roboPlayerId: 6}));
    // P4's phone leaves: their row stays on the card, greyed (design section 4).
    fake.removeController('p4');
    await tester.pumpAndSettle();

    expect(tester.widget<Opacity>(find.byKey(_rowKey('p4'))).opacity, nightAwayOpacity, reason: 'a leaver is greyed');
    expect(tester.widget<Opacity>(find.byKey(_rowKey('robo'))).opacity, 1, reason: 'Robo is on the TV: never away');
    expect(tester.widget<Opacity>(find.byKey(_rowKey('p1'))).opacity, 1);
    expect(_barFill(tester, 'p1'), 1.0, reason: 'the leader fills the bar: width = points/maxPoints');
  });

  testWidgets('the final scores: the winner is taller with the crown, and ranks 1 to 3 wear the podium', (
    tester,
  ) async {
    await _pumpScoreboard(
      tester,
      const Size(640, 360),
      names: _sixNames,
      points: _sixPoints,
      rounds: _nightLength.rounds,
    );

    expect(find.text('Final scores'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_rowKey('p1'))).height,
      moreOrLessEquals(scoreWinnerRowHeightPx, epsilon: _tolerance),
      reason: "the winner's row is taller than the others",
    );
    for (final id in ['p2', 'p3', 'p4', 'p5', 'p6']) {
      expect(
        tester.getSize(find.byKey(_rowKey(id))).height,
        moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance),
        reason: "$id's row keeps the 52 px line",
      );
      expect(find.byKey(Key('nightCrown-$id')), findsNothing, reason: 'only the winner wears the crown');
    }
    expect(find.byKey(const Key('nightCrown-p1')), findsOneWidget);

    final look = ToyLookScope.of(tester.element(find.byType(NightScoreboardScreen)));
    expect(_wearsDisc(tester, 'p1', look.colors.focus), isTrue, reason: 'the gold disc is the look\'s focus yellow');
    expect(
      _wearsDisc(tester, 'p2', scoreSilver(look.colors)),
      isTrue,
      reason: 'the silver disc is the look\'s wall grey',
    );
    expect(_wearsDisc(tester, 'p3', scoreBronze(look.colors)), isTrue, reason: 'P3 and P4 are level, both in third');
    expect(_wearsDisc(tester, 'p4', scoreBronze(look.colors)), isTrue);
    expect(_wearsDisc(tester, 'p5', scoreSilver(look.colors)), isFalse, reason: 'fourth and below wear no disc');
    expect(find.byKey(const Key('nightConfetti')), findsOneWidget, reason: 'the night ends in confetti');
    await tester.pump();
    expect(
      sounds.played.where((sound) => sound == 'celebration').length,
      1,
      reason: 'the celebration plays once, however often the screen rebuilds',
    );
  });

  testWidgets('between the rounds the footer is the night\'s two buttons and no row wears a crown', (tester) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _sixNames, points: _sixPoints);

    expect(
      find.descendant(of: find.byKey(_footerKey), matching: find.byType(HostButton)),
      findsNWidgets(2),
      reason: 'Shape Race and the Bumper Round are the way on between rounds',
    );
    expect(find.byKey(_backKey), findsNothing);
    for (final id in _sixPoints.keys) {
      expect(find.byKey(Key('nightCrown-$id')), findsNothing, reason: 'the crown is the final scores\'');
      expect(tester.getSize(find.byKey(_rowKey(id))).height, moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance));
    }
    final look = ToyLookScope.of(tester.element(find.byType(NightScoreboardScreen)));
    expect(_wearsDisc(tester, 'p1', look.colors.focus), isFalse, reason: 'the podium is the final scores\'');
    expect(find.byKey(const Key('nightConfetti')), findsNothing);
  });

  testWidgets('the final scores\' footer is one button, Back to games, and it ends the night', (tester) async {
    await _pumpScoreboard(
      tester,
      const Size(640, 360),
      names: _fourNames,
      points: _fourPoints,
      rounds: _nightLength.rounds,
    );

    expect(find.descendant(of: find.byKey(_footerKey), matching: find.byType(HostButton)), findsOneWidget);
    expect(find.byKey(_backKey), findsOneWidget);
    expect(find.byKey(_shapeRaceKey), findsNothing, reason: 'the night is over: there is no next round');
    expect(find.byKey(_bumperKey), findsNothing);

    final container = appContainer(tester);
    await tapVisible(tester, find.byKey(_backKey));
    await tester.pumpAndSettle();
    expect(container.read(partyNightProvider), isNull, reason: 'the night is over and gone');
  });

  testWidgets('a row shows what the round added, and a round with nothing to add shows no "+0"', (tester) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints);
    expect(tester.widget<Text>(find.byKey(const Key('nightRoundPoints-p1'))).data, '+9');
    expect(tester.widget<Text>(find.byKey(const Key('nightRoundPoints-p3'))).data, '+2');
  });

  testWidgets('before any round the bars are empty and no row has a "+0"', (tester) async {
    await _pumpScoreboard(tester, const Size(640, 360), names: _fourNames, points: _fourPoints, rounds: 0);

    expect(find.byKey(const Key('nightRoundPoints-p1')), findsNothing, reason: 'nothing to add, no "+0"');
    expect(_barFill(tester, 'p1'), 0.0, reason: 'no round has scored yet');
  });

  testWidgets('the frame\'s small text is used and the winner\'s name is the design\'s 32 px', (tester) async {
    await _pumpScoreboard(
      tester,
      const Size(640, 360),
      names: _fourNames,
      points: _fourPoints,
      rounds: _nightLength.rounds,
    );

    final winnerName = tester.widget<Text>(find.byKey(const Key('nightName-p1'))).style;
    expect(winnerName?.fontSize, scoreWinnerNamePx, reason: 'the winner\'s name is bigger (DESIGN section 4)');
    final name = tester.widget<Text>(find.byKey(const Key('nightName-p2'))).style;
    expect(name?.fontSize, ToyType.frame.body.fontSize);
  });

  group('nickname fit', () {
    /// The names the design judges by eye (DESIGN section 6): two real
    /// nicknames, and ten characters of the widest and narrowest letters.
    const realNames = ['Alexandria', 'Nightshade'];
    const widestName = 'WWWWWWWWWW';
    const narrowestName = 'iiiiiiiiii';

    testWidgets('Alexandria and Nightshade fit the name column at 22 and at the winner\'s 32 px', (tester) async {
      for (final name in realNames) {
        for (final size in [ToyType.frame.body.fontSize!, scoreWinnerNamePx]) {
          expect(
            _widthOf(name, size),
            lessThanOrEqualTo(scoreRowNameWidthPx),
            reason: '$name fits a $size px line in the ${scoreRowNameWidthPx}px column',
          );
        }
      }
    });

    testWidgets('the widest ten letters need more than the column, so a name that long is ellipsised', (tester) async {
      expect(_widthOf(widestName, ToyType.frame.body.fontSize!), greaterThan(scoreRowNameWidthPx));
      expect(_widthOf(narrowestName, ToyType.frame.body.fontSize!), lessThan(scoreRowNameWidthPx));
    });

    testWidgets('the final scores draw Alexandria and Nightshade whole, on the winner\'s row and the next', (
      tester,
    ) async {
      await _pumpScoreboard(
        tester,
        const Size(640, 360),
        names: _fourNames,
        points: _fourPoints,
        rounds: _nightLength.rounds,
      );

      for (final id in ['p1', 'p2']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.byKey(Key('nightName-$id')));
        expect(paragraph.didExceedMaxLines, isFalse, reason: "$id's name is not ellipsised");
      }
    });
  });
}
