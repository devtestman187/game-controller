import 'dart:io';
import 'dart:math' show min, pow;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'host_harness.dart';
import 'night_harness.dart';

/// What one measurement is opened with: the host's size, the nicknames of the
/// phones that joined (P1 first) and the points each player took in a round.
typedef PhoneFitSetup = ({Size size, List<String> names, Map<String, int> points});

/// A screen a fit test measures: how to open it, the widget that is its root
/// (the walk under it is what it draws), and the buttons that are its way on,
/// the first it has being the one that is looked for.
typedef PhoneFitCase = ({
  String name,
  Finder root,
  List<Key> actions,
  Future<void> Function(WidgetTester, PhoneFitSetup) open,
});

/// The rounds a measuring night has, and the round the scoreboard is seen
/// after (brief pf1).
const nightRounds = 5;
const midNightRounds = 2;

/// The points four players took in a round of the measuring night: P1 first,
/// one point apart, so the score rows have an order.
const fourPoints = {'p1': 7, 'p2': 5, 'p3': 3, 'p4': 1};

/// The counters the night's first round reports, so every award has a winner
/// (P1 carries most, drops least and scores most).
const _roundStats = {
  'p1': {'carries': 3, 'snaps': 9, 'wrongDrops': 0},
  'p2': {'carries': 1, 'snaps': 4, 'wrongDrops': 2},
  'p3': {'carries': 2, 'snaps': 6, 'wrongDrops': 1},
  'p4': {'carries': 0, 'snaps': 2, 'wrongDrops': 3},
};

/// The size the job asks for by name, to report what a 24 px label becomes.
const _label24Px = 24.0;

/// The round-off allowed before a width, a rect or a scale counts as too big.
const _slop = 0.5;

/// The decimals a type size is reported to: a frame scale's arithmetic leaves
/// noise in the last digits.
const _dpDecimals = 3;

/// How much of a text the results file keeps.
const _textShown = 40;

/// The six screens the fit tests measure (brief pf1: the start card, the
/// scoreboard mid-night, the final scores, the awards' reveal, the Arena's and
/// the puzzle's round results).
final nightScreens = <PhoneFitCase>[
  (name: 'night-start', root: find.byType(NightStartScreen), actions: const [Key('nightShapeRace')], open: _openStart),
  (
    name: 'night-scoreboard',
    root: find.byType(NightScoreboardScreen),
    actions: const [Key('nightShapeRace')],
    open: _openScoreboard,
  ),
  (
    name: 'night-final',
    root: find.byType(NightScoreboardScreen),
    actions: const [Key('nightBackToGames')],
    open: (tester, setup) => _openScoreboard(tester, setup, rounds: nightRounds),
  ),
  (name: 'night-reveal', root: find.byType(NightRevealScreen), actions: const [], open: _openReveal),
  (name: 'arena-results', root: find.byType(ArenaResults), actions: const [Key('arenaAgain')], open: _openArenaResults),
  (
    name: 'puzzle-results',
    root: find.byType(PuzzleScreen),
    actions: const [Key('nextPuzzle'), Key('rematch'), Key('playAgain'), Key('next')],
    open: _openPuzzleResults,
  ),
];

/// Mounts the host at the setup's size with one connected phone per nickname,
/// in the setup's order: the sample state's own two make way for them.
Future<FakeHostService> hostWithPlayers(
  WidgetTester tester,
  PhoneFitSetup setup, {
  Widget screen = const StubHome(),
}) async {
  final fake = await pumpHost(tester, screen: screen, size: setup.size);
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < setup.names.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: setup.names[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  return fake;
}

/// Starts the five-round night and records [rounds] of its rounds by hand, as
/// a played round would.
Future<void> playRounds(WidgetTester tester, PhoneFitSetup setup, int rounds) async {
  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: NightLength.five, awards: threeAwards);
  for (var i = 0; i < rounds; i++) {
    night.recordRound(roundResult(points: setup.points, winners: {'p1'}, stats: i == 0 ? _roundStats : const {}));
  }
}

/// Home → Play → Party night: the night's start card.
Future<void> _openStart(WidgetTester tester, PhoneFitSetup setup) async {
  await hostWithPlayers(tester, setup);
  await openNight(tester);
}

/// A night with [rounds] of its five in, whose scoreboard the picker's card
/// opens again: the night is over on the last round, so that is its final
/// scores.
Future<void> _openScoreboard(WidgetTester tester, PhoneFitSetup setup, {int rounds = midNightRounds}) async {
  await hostWithPlayers(tester, setup);
  await openNight(tester);
  await playRounds(tester, setup, rounds);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
  await tester.pumpAndSettle();
}

/// The awards' reveal under a night already played: its first award is on the
/// screen, read before the award's timer moves on.
Future<void> _openReveal(WidgetTester tester, PhoneFitSetup setup) async {
  await hostWithPlayers(tester, setup, screen: const NightRevealScreen());
  await playRounds(tester, setup, nightRounds);
  await tester.pump();
}

/// The round's result, as the Bumper Round hands it over: P1 won the coins.
RoundResult _arenaResult(Map<String, int> points) => RoundResult(
  game: 'arena',
  winners: {'p1'},
  points: points,
  lines: {
    for (final line in points.entries)
      line.key: RoundLine(
        outcome: line.key == 'p1' ? RoundOutcome.win : RoundOutcome.loss,
        count: line.value,
        countOf: RoundCount.coins,
      ),
  },
);

/// The Bumper Round's results card over the harness, as the Arena shows it
/// after a round ([ArenaResults] owns the card alone).
Future<void> _openArenaResults(WidgetTester tester, PhoneFitSetup setup) async {
  final again = FocusNode(debugLabel: 'fitArenaAgain');
  addTearDown(again.dispose);
  await hostWithPlayers(
    tester,
    setup,
    screen: ArenaResults(
      result: _arenaResult(setup.points),
      night: false,
      lastRound: false,
      againFocus: again,
      onAgain: () {},
      onChangeMode: () {},
      onNext: () {},
      onEndNight: () {},
    ),
  );
}

/// Shape Race's race between P1 and P2, played to its end: the results card
/// over the board (the other players sit the round out).
Future<void> _openPuzzleResults(WidgetTester tester, PhoneFitSetup setup) async {
  final fake = await hostWithPlayers(tester, setup);
  await openJoin(tester);
  await startRace(tester, fake);
  lockEveryPiece(tester);
  await endRound(tester);
}

/// One scrollable a screen has: how far the content runs past the room it
/// shows ([extent] and [viewport], in dp) and the [axis] it runs along.
typedef PhoneFitScroll = ({double extent, double viewport, Axis axis});

/// What one screen at one size measured: what the results file keeps
/// ([measurementJson]) and the numbers a scaled-frame test reads on. Every
/// size is in device dp already (frame px in a host laid out in a frame).
typedef PhoneFitMeasurement = ({
  String screenName,
  String sizeName,
  List<String> errors,
  List<PhoneFitScroll> scrolls,
  List<Map<String, Object?>> clipped,
  int texts,
  double? smallestFontDp,
  List<double> label24Dp,
  Map<String, Object?>? wayOn,
  List<double> scalesAwayFromOne,
});

/// The record the results file keeps for [m].
Map<String, Object?> measurementJson(PhoneFitMeasurement m) => {
  'screen': m.screenName,
  'size': m.sizeName,
  'errors': m.errors,
  'scrolls': [
    for (final s in m.scrolls) {'extent': s.extent.roundToDouble(), 'viewport': s.viewport.roundToDouble()},
  ],
  'clipped': m.clipped,
  'texts': m.texts,
  'smallestFontDp': m.smallestFontDp,
  'label24Dp': m.label24Dp,
  'wayOn': m.wayOn,
  'scalesAwayFromOne': m.scalesAwayFromOne,
};

/// The vertical scroll of [m] that runs furthest, or null when it has none.
PhoneFitScroll? longestScroll(PhoneFitMeasurement m) {
  final vertical = m.scrolls.where((s) => s.axis == Axis.vertical);
  return vertical.isEmpty ? null : vertical.reduce((a, b) => a.extent >= b.extent ? a : b);
}

/// How far [m] scrolls lengthways, in dp (0 when it does not).
double scrollExtentOf(PhoneFitMeasurement m) => longestScroll(m)?.extent ?? 0;

/// The height of [m]'s scrolling content, viewport plus extent, in dp.
double? contentHeightOf(PhoneFitMeasurement m) {
  final longest = longestScroll(m);
  return longest == null ? null : longest.viewport + longest.extent;
}

/// Whether [m] shows whole without scrolling and without an error.
bool fitsNoScroll(PhoneFitMeasurement m) => m.errors.isEmpty && scrollExtentOf(m) <= _slop;

/// What one screen draws, found by one walk under its root: its paragraphs and
/// its scrollables, each once (a Text's element and its RichText's share one
/// paragraph, so the walk meets it more than once).
final class _Drawn {
  final paragraphs = <RenderParagraph>[];
  final scrolls = <ScrollableState>[];

  void visit(Element element) {
    final render = element.renderObject;
    if (render is RenderParagraph && !paragraphs.contains(render)) paragraphs.add(render);
    if (element is StatefulElement) {
      final state = element.state;
      if (state is ScrollableState && !scrolls.contains(state)) scrolls.add(state);
    }
    element.visitChildren(visit);
  }
}

/// The text's size on the device, in dp: its font size through the paragraph's
/// own text scale (a MediaQuery's), everything that scales it above, and the
/// frame's own scale.
double? _fontDp(RenderParagraph paragraph, double deviceScale) {
  final size = paragraph.text.style?.fontSize;
  if (size == null) return null;
  final unit = pow(10, _dpDecimals).toDouble();
  return (paragraph.textScaler.scale(size) * _scaleAbove(paragraph) * deviceScale * unit).round() / unit;
}

/// How far everything above [paragraph] scales it, as the test accounts for a
/// global wrapper: the distance two points a dp apart are drawn at, which reads
/// every Transform.scale, FittedBox and anything else the ancestors push, with
/// the paragraph's own text scale handled by [_fontDp].
double _scaleAbove(RenderParagraph paragraph) {
  final origin = paragraph.localToGlobal(Offset.zero);
  return (paragraph.localToGlobal(const Offset(1, 0)) - origin).distance;
}

/// Whether the paragraph had to shorten its text: it hit its lines' limit (an
/// ellipsis or a cut), or has no room to wrap and is wider than the box its
/// ancestors gave it.
bool _isClipped(RenderParagraph paragraph) =>
    paragraph.didExceedMaxLines ||
    (!paragraph.softWrap &&
        paragraph.constraints.hasBoundedWidth &&
        paragraph.getMaxIntrinsicWidth(double.infinity) > paragraph.constraints.maxWidth + _slop);

/// The screen's way on, the first of [keys] it has, and whether that button
/// sits whole on the screen without scrolling.
Map<String, Object?>? _action(WidgetTester tester, List<Key> keys) {
  final view = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final key in keys) {
    final finder = find.byKey(key);
    if (finder.evaluate().isEmpty) continue;
    final rect = tester.getRect(finder);
    final onScreen =
        rect.top >= view.top - _slop &&
        rect.bottom <= view.bottom + _slop &&
        rect.left >= view.left - _slop &&
        rect.right <= view.right + _slop;
    return {
      'key': key is ValueKey<String> ? key.value : key.toString(),
      'onScreen': onScreen,
      'top': rect.top.roundToDouble(),
      'bottom': rect.bottom.roundToDouble(),
    };
  }
  return null;
}

/// [text] cut for the results file, where the report reads it.
String _short(String text) => text.length <= _textShown ? text : '${text.substring(0, _textShown)}…';

/// What [screen] draws at [sizeName]: its errors, its scrolling, the text it
/// had to shorten, its smallest type and its way on. [deviceScale] is what the
/// frame is drawn at on the device: a host laid out in frame pixels draws type
/// that many times as large in device dp.
PhoneFitMeasurement measureScreen(
  WidgetTester tester,
  PhoneFitCase screen,
  String sizeName,
  List<String> errors, {
  double deviceScale = 1,
}) {
  final drawn = _Drawn()..visit(tester.element(screen.root));
  final sizes = <double>[];
  final label24 = <double>[];
  final scaled = <double>{};
  final clipped = <Map<String, Object?>>[];
  for (final paragraph in drawn.paragraphs) {
    final dp = _fontDp(paragraph, deviceScale);
    final scale = _scaleAbove(paragraph);
    if ((scale - 1).abs() > _slop) scaled.add((scale * 1000).round() / 1000);
    if (dp != null) {
      sizes.add(dp);
      if (paragraph.text.style?.fontSize == _label24Px) label24.add(dp);
    }
    if (_isClipped(paragraph)) {
      clipped.add({
        'text': _short(paragraph.text.toPlainText()),
        'wanted': paragraph.getMaxIntrinsicWidth(double.infinity).roundToDouble(),
        'given': paragraph.constraints.maxWidth,
        'laidOut': paragraph.size.width.roundToDouble(),
        'ellipsis': paragraph.didExceedMaxLines,
      });
    }
  }
  return (
    screenName: screen.name,
    sizeName: sizeName,
    errors: errors,
    scrolls: [
      for (final s in drawn.scrolls)
        (
          extent: s.position.maxScrollExtent.roundToDouble(),
          viewport: s.position.viewportDimension.roundToDouble(),
          axis: axisDirectionToAxis(s.axisDirection),
        ),
    ],
    clipped: clipped,
    texts: drawn.paragraphs.length,
    smallestFontDp: sizes.isEmpty ? null : sizes.reduce(min),
    label24Dp: label24,
    wayOn: _action(tester, screen.actions),
    scalesAwayFromOne: scaled.toList(),
  );
}

/// Saves the frame on the screen as the PNG at [path], read as the pixels
/// tests read it: the root layer's own image, which needs the real event loop.
/// [pixelRatio] is the scale the frame is drawn at on the device.
Future<void> saveFramePng(WidgetTester tester, String path, {double pixelRatio = 1}) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size, pixelRatio: pixelRatio)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  image.dispose();
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}
