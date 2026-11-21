import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
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

/// The coins a round gave the joined players (P1 first): a leader, then two
/// players level in third, so the rows show "1" and "3=" (DESIGN section 4).
const _fourCoins = {'p1': 9, 'p2': 5, 'p3': 2, 'p4': 2};
const _sixCoins = {'p1': 9, 'p2': 7, 'p3': 3, 'p4': 3, 'p5': 2, 'p6': 1};

/// What Robo takes in the round the tests draw: its line is in the result, so
/// its row is on the card.
const _roboCoins = 1;

/// The keys the frame's regions are found by.
const _bodyKey = Key('hostFrameBody');

const _fourPlayers = 4;
const _sixPlayers = 6;

/// Every way a roster and its coins go together: four players and six.
const _rosters = [(_fourPlayers, _fourNames, _fourCoins), (_sixPlayers, _sixNames, _sixCoins)];

/// The results drawn in the host's frame, as the app draws every screen
/// (DESIGN section 5): [hostFrameBuilder] over them, so they lay out at the
/// frame's size with the frame's type.
class _ResultsInFrame extends StatelessWidget {
  const _ResultsInFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => hostFrameBuilder(context, child);
}

Key _rowKey(String id) => Key('arenaResultRow-$id');

/// A player's line for the round: [count] of the coins it counted.
RoundLine _coins(RoundOutcome outcome, int count) =>
    RoundLine(outcome: outcome, count: count, countOf: RoundCount.coins);

/// The results the tests draw: [coins] for the joined players, P1's win, and
/// Robo's own line unless [withRobo] is false.
RoundResult _round(Map<String, int> coins, {bool withRobo = true, bool draw = false}) => RoundResult(
  game: 'arena',
  winners: draw ? const {} : const {'p1'},
  draw: draw,
  points: coins,
  lines: {
    for (final entry in coins.entries) entry.key: _coins(draw ? RoundOutcome.draw : RoundOutcome.loss, entry.value),
    if (withRobo) roboPlayerId: _coins(draw ? RoundOutcome.draw : RoundOutcome.loss, _roboCoins),
  },
);

/// Mounts the host at [device]'s size on the Bumper Round's results in the
/// frame, with the phones of [names] joined and the round's [coins].
Future<void> _pumpResults(
  WidgetTester tester,
  Size device, {
  required List<String> names,
  required Map<String, int> coins,
  bool night = false,
  bool lastRound = false,
  bool draw = false,
}) async {
  final again = FocusNode(debugLabel: 'arenaAgain');
  addTearDown(again.dispose);
  await pumpHost(
    tester,
    screen: _ResultsInFrame(
      child: ArenaResults(
        result: _round(coins, draw: draw),
        night: night,
        lastRound: lastRound,
        againFocus: again,
        onAgain: () {},
        onChangeMode: () {},
        onNext: () {},
        onEndNight: () {},
      ),
    ),
    size: device,
    overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
  );
  final roster = appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster;
  roster.put([for (var i = 0; i < names.length; i++) nightPlayer('p${i + 1}', i + 1, names[i])]);
  await tester.pumpAndSettle();
}

/// The look the results are drawn in (the frame's, DESIGN section 5).
ToyLook _lookOf(WidgetTester tester) => ToyLookScope.of(tester.element(find.byType(ArenaResults)));

/// Whether [id]'s row is washed in the winner's gold (DESIGN section 4, the
/// Arena results): a box of the look's focus yellow behind the row.
bool _hasWash(WidgetTester tester, String id) {
  final wash = _lookOf(tester).colors.focus.withValues(alpha: scoreWinnerWashAlpha);
  return find
      .descendant(
        of: find.byKey(_rowKey(id)),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == wash,
        ),
      )
      .evaluate()
      .isNotEmpty;
}

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

/// Every text inside the screen, with the style it is drawn in (the frame's
/// floor of 20 px, DESIGN section 1, rule 3).
Iterable<({String? text, double? size})> _texts(WidgetTester tester) sync* {
  for (final element in find.descendant(of: find.byType(ArenaResults), matching: find.byType(Text)).evaluate()) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    yield (text: text.data, size: style.fontSize);
  }
}

/// A screen that pushes [results] on a route of its own the way the game screen
/// does, so the results can pop and the frame's header draws its back arrow.
class _ResultsOnARoute extends StatefulWidget {
  const _ResultsOnARoute({required this.results});

  /// The results to push.
  final Widget results;

  @override
  State<_ResultsOnARoute> createState() => _ResultsOnARouteState();
}

class _ResultsOnARouteState extends State<_ResultsOnARoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => _ResultsInFrame(child: widget.results)));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUpAll(loadLookFonts);

  for (final frameCase in _cases) {
    for (final (players, names, coins) in _rosters) {
      for (final night in [false, true]) {
        final where = night ? "in a night's round" : 'outside a night';
        testWidgets('${frameCase.label}, $players players $where: no scroll, 52 px rows and the footer on', (
          tester,
        ) async {
          await _pumpResults(tester, frameCase.device, names: names, coins: coins, night: night);

          expect(
            find.descendant(of: find.byKey(_bodyKey), matching: find.byType(Scrollable)),
            findsNothing,
            reason: 'the rows and Robo fit the body, so nothing scrolls (DESIGN section 1, rule 6)',
          );
          expect(tester.takeException(), isNull, reason: 'nothing overflows the frame');

          for (final id in [...coins.keys, roboPlayerId]) {
            expect(
              tester.getSize(find.byKey(_rowKey(id))).height,
              moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance),
              reason: "$id's row is the design's 52 px line, the winner's too",
            );
          }

          final buttons = night
              ? const [Key('next'), Key('endNight')]
              : const [Key('arenaAgain'), Key('arenaChangeMode')];
          var total = 0.0;
          for (final key in buttons) {
            final rect = tester.getRect(find.byKey(key));
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$key is on screen');
            expect(rect.top, greaterThanOrEqualTo(0), reason: '$key is on screen');
            expect(rect.right, lessThanOrEqualTo(frameCase.device.width), reason: '$key is on screen');
            expect(rect.bottom, lessThanOrEqualTo(frameCase.device.height + _tolerance), reason: '$key is on');
            expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key can be pressed');
            // In frame px, the size the footer lays its buttons out in, rather
            // than the device px `getRect` reports through the frame's scale.
            total += tester.getSize(find.byKey(key)).width;
          }
          expect(
            total + (buttons.length - 1) * nightFooterButtonGapPx,
            lessThanOrEqualTo(nightFooterButtonsWidthPx),
            reason: 'the footer keeps room for Thumby beside its buttons (DESIGN section 3): $total px',
          );
        });
      }
    }
  }

  for (final frameCase in _cases) {
    for (final (players, names, coins) in _rosters) {
      testWidgets('${frameCase.label}, $players players: every text on the results is at least 20 frame px', (
        tester,
      ) async {
        await _pumpResults(tester, frameCase.device, names: names, coins: coins);
        final texts = _texts(tester).toList();
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(text.size, greaterThanOrEqualTo(20), reason: '"${text.text}" is a frame size (DESIGN rule 3)');
        }
      });
    }
  }

  testWidgets('the winner\'s row is washed gold and wears the crown, and every row keeps the 52 px line', (
    tester,
  ) async {
    await _pumpResults(tester, const Size(640, 360), names: _sixNames, coins: _sixCoins);

    expect(find.text('P1 Alexandria wins!'), findsOneWidget, reason: 'the title names the round\'s winner');
    expect(
      _hasWash(tester, 'p1'),
      isTrue,
      reason: 'the winner\'s row is washed in the look\'s gold (DESIGN section 4)',
    );
    expect(find.byKey(const Key('arenaCrown-p1')), findsOneWidget, reason: 'the crown sits on the winner\'s badge');
    for (final id in ['p2', 'p3', 'p4', 'p5', 'p6', roboPlayerId]) {
      expect(_hasWash(tester, id), isFalse, reason: 'the gold wash is the winner\'s alone');
      expect(find.byKey(Key('arenaCrown-$id')), findsNothing, reason: 'so is the crown');
      expect(
        tester.getSize(find.byKey(_rowKey(id))).height,
        moreOrLessEquals(scoreRowHeightPx, epsilon: _tolerance),
        reason: '$id keeps the 52 px line, as the Arena\'s rows have no taller winner line',
      );
    }
    // The rows stand in the round's order, as the night's card does.
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p1'))).data, '1');
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p2'))).data, '2');
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p3'))).data, '3=', reason: 'P3 and P4 are level');
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p4'))).data, '3=');
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultCoins-p1'))).data, '9 coins');
  });

  testWidgets('a draw says so in the title and nobody wears a crown or the wash', (tester) async {
    await _pumpResults(
      tester,
      const Size(640, 360),
      names: _fourNames.sublist(0, 2),
      coins: const {'p1': 4, 'p2': 4},
      draw: true,
    );

    expect(find.text('Draw!'), findsOneWidget, reason: 'equal coins are a draw (design section 7)');
    expect(find.byKey(const Key('arenaCrown-p1')), findsNothing);
    expect(_hasWash(tester, 'p1'), isFalse);
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p1'))).data, '1=', reason: 'the two are level');
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultRank-p2'))).data, '1=');
  });

  testWidgets('Robo\'s row wears the robot head and a "bot" tag, and no badge number', (tester) async {
    await _pumpResults(tester, const Size(640, 360), names: _fourNames, coins: _fourCoins);

    final row = find.byKey(_rowKey(roboPlayerId));
    expect(row, findsOneWidget, reason: 'Robo has a seat, so a row');
    expect(
      find.descendant(of: row, matching: find.byType(RoboBadge)),
      findsOneWidget,
      reason: 'Robo\'s head stands where a player\'s numbered badge would',
    );
    expect(
      find.descendant(of: row, matching: find.byType(PlayerBadge)),
      findsNothing,
      reason: 'no badge number: the row is tagged instead (DESIGN section 4)',
    );
    expect(
      find.descendant(of: row, matching: find.text('bot')),
      findsOneWidget,
      reason: 'the "bot" tag names it',
    );
    expect(tester.widget<Text>(find.byKey(const Key('arenaResultCoins-robo'))).data, '1 coin');
  });

  testWidgets('the card fills the stage width, and the footer\'s buttons share its 480 px budget', (tester) async {
    await _pumpResults(tester, const Size(640, 360), names: _sixNames, coins: _sixCoins);

    expect(
      tester.getSize(find.byKey(const Key('arenaResults'))).width,
      moreOrLessEquals(960 - 2 * hostFrameGutterPx, epsilon: _tolerance),
      reason: 'a card fills the stage minus the 24 px gutter either side (DESIGN section 1, rule 4)',
    );
    final pair = tester.getSize(find.byKey(const Key('arenaAgain'))).width;
    final mode = tester.getSize(find.byKey(const Key('arenaChangeMode'))).width;
    expect(
      pair + nightFooterButtonGapPx + mode,
      lessThanOrEqualTo(nightFooterButtonsWidthPx),
      reason: 'Play again and Change mode are the footer\'s whole room: ${pair + mode + nightFooterButtonGapPx} px',
    );
    expect(find.byKey(const Key('arenaResultsBack')), findsNothing, reason: 'Back is the header\'s arrow alone');
  });

  group('nickname fit', () {
    testWidgets('Alexandria and Nightshade fit the name column at 22 px', (tester) async {
      for (final name in ['P1 Alexandria', 'P2 Nightshade']) {
        expect(
          _widthOf(name, ToyType.frame.body.fontSize!),
          lessThanOrEqualTo(scoreRowNameWidthPx),
          reason: '$name fits a 22 px line in the ${scoreRowNameWidthPx}px column',
        );
      }
    });

    testWidgets('the results draw both ten-character nicknames whole', (tester) async {
      await _pumpResults(tester, const Size(640, 360), names: _fourNames, coins: _fourCoins);

      for (final id in ['p1', 'p2']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.byKey(Key('arenaResultName-$id')));
        expect(paragraph.didExceedMaxLines, isFalse, reason: "$id's name is not ellipsised");
      }
    });
  });

  // The results pushed on a route of their own inside the frame, as the game
  // screen pushes them: a route that can pop, which the header's arrow needs.
  testWidgets('outside a night the header\'s arrow is the way back, since Back left the footer', (tester) async {
    final again = FocusNode(debugLabel: 'arenaAgain');
    addTearDown(again.dispose);
    final results = ArenaResults(
      result: _round(_fourCoins),
      night: false,
      lastRound: false,
      againFocus: again,
      onAgain: () {},
      onChangeMode: () {},
      onNext: () {},
      onEndNight: () {},
    );
    await pumpHost(
      tester,
      screen: _ResultsOnARoute(results: results),
      size: const Size(640, 360),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    (appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster).put([
      for (var i = 0; i < _fourNames.length; i++) nightPlayer('p${i + 1}', i + 1, _fourNames[i]),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(ArenaResults), findsOneWidget);
    expect(find.byKey(const Key('hostTitleBarBack')), findsOneWidget, reason: 'the way back is the header\'s arrow');
    await tester.tap(find.byKey(const Key('hostTitleBarBack')));
    await tester.pumpAndSettle();
    expect(find.byType(ArenaResults), findsNothing, reason: 'the arrow pops the results\' route, as Back did');
  });

  testWidgets('a player who joined the round too late keeps a soft line on the card', (tester) async {
    final again = FocusNode(debugLabel: 'arenaAgain');
    addTearDown(again.dispose);
    await pumpHost(
      tester,
      screen: _ResultsInFrame(
        child: ArenaResults(
          result: _round(_fourCoins, withRobo: false),
          night: false,
          lastRound: false,
          againFocus: again,
          onAgain: () {},
          onChangeMode: () {},
          onNext: () {},
          onEndNight: () {},
        ),
      ),
      size: const Size(640, 360),
      overrides: [gamePlayersProvider.overrideWith(TestRoster.new)],
    );
    final roster = appContainer(tester).read(gamePlayersProvider.notifier) as TestRoster;
    roster.put([
      for (var i = 0; i < _fourNames.length; i++) nightPlayer('p${i + 1}', i + 1, _fourNames[i]),
      nightPlayer('p5', 5, 'Jo'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('P5 Jo joins next round'), findsOneWidget, reason: 'P5 waits for the next round (section 8)');
    expect(find.byKey(_rowKey('p5')), findsNothing, reason: 'a player with no line has no row');
    expect(tester.takeException(), isNull);
  });
}
