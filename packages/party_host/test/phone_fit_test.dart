import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';
import 'support/night_harness.dart';
import 'support/toy_fonts.dart';

/// Whether the measurement is wanted: the night screens are measured only when
/// PHONE_FIT=1 is set in the environment, so the suite's normal run is
/// untouched (brief pf1). `--dart-define=PHONE_FIT=true` is the same switch for
/// a tool that cannot set a variable for one command.
final _enabled = Platform.environment['PHONE_FIT'] == '1' || const bool.fromEnvironment('PHONE_FIT');

/// The host sizes measured, in logical pixels with a devicePixelRatio of 1: a
/// phone host lying down and standing up, a tablet and a TV (brief pf1).
const _sizes = [
  (name: '640x360', size: Size(640, 360)),
  (name: '360x640', size: Size(360, 640)),
  (name: '1280x800', size: Size(1280, 800)),
  (name: '1280x720', size: Size(1280, 720)),
];

/// The nicknames the four phones joined with: every one is 18 characters or
/// more, so a card that cuts a name shows here (brief pf1).
const _names = ['Bartholomew The Great', 'Maximilian Thunderbolt', 'Alexandria Nightshade', 'Christopher Von Trapp'];

/// The points the four players took in a round of the measuring night.
const _roundPoints = {'p1': 7, 'p2': 5, 'p3': 3, 'p4': 1};

/// The counters the night's first round reports, so every award has a winner
/// (P1 carries most, drops least and scores most).
const _roundStats = {
  'p1': {'carries': 3, 'snaps': 9, 'wrongDrops': 0},
  'p2': {'carries': 1, 'snaps': 4, 'wrongDrops': 2},
  'p3': {'carries': 2, 'snaps': 6, 'wrongDrops': 1},
  'p4': {'carries': 0, 'snaps': 2, 'wrongDrops': 3},
};

/// The night the screens are measured with: five rounds, of which the
/// scoreboard is seen after [_midNightRounds].
const _nightRounds = 5;
const _midNightRounds = 2;

/// The size the job asks for by name, to report what a 24 px label becomes.
const _label24Px = 24.0;

/// The round-off allowed before a width, a rect or a scale counts as too big.
const _slop = 0.5;

/// How much of a text the results file keeps.
const _textShown = 40;

/// A screen the job measures: how to open it, the widget that is its root (the
/// walk under it is what it draws), and the buttons that are its way on, the
/// first it has being the one that is looked for.
typedef _Case = ({String name, Finder root, List<Key> actions, Future<void> Function(WidgetTester, Size) open});

/// The six screens the job measures (brief pf1: the start card, the scoreboard
/// mid-night, the final scores, the awards' reveal, the Arena's and the
/// puzzle's round results).
final _cases = <_Case>[
  (name: 'night-start', root: find.byType(NightStartScreen), actions: const [Key('nightShapeRace')], open: _openStart),
  (
    name: 'night-scoreboard',
    root: find.byType(NightScoreboardScreen),
    actions: const [Key('nightShapeRace')],
    open: (tester, size) => _openScoreboard(tester, size, rounds: _midNightRounds),
  ),
  (
    name: 'night-final',
    root: find.byType(NightScoreboardScreen),
    actions: const [Key('nightBackToGames')],
    open: (tester, size) => _openScoreboard(tester, size, rounds: _nightRounds),
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

/// Every measurement taken, in the order the tests run: the file is written
/// once they are all in.
final _results = <Map<String, Object?>>[];

/// The folder the pictures and the results go in, from the package or from the
/// repo root ([puzzleDataDir]'s shape).
final _outDir = Directory.current.path.endsWith('party_host')
    ? Directory('../../docs/briefs/m16/phonefit')
    : Directory('docs/briefs/m16/phonefit');

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);
  tearDownAll(() {
    if (_results.isEmpty) return;
    File('${_outDir.path}/results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
  });

  for (final at in _sizes) {
    for (final screen in _cases) {
      testWidgets('${screen.name} at ${at.name}: what it draws and whether it fits', (tester) async {
        // A RenderFlex overflow is a report, not a throw: taking them here
        // keeps one screen's spill from stopping the others (brief pf1).
        final errors = <String>[];
        final reported = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.exceptionAsString());
        try {
          await screen.open(tester, at.size);
          final thrown = tester.takeException();
          if (thrown != null) errors.add(thrown.toString());
          await _savePng(tester, '${screen.name}-${at.name}');
          _results.add(_measure(tester, screen, at.name, errors));
        } finally {
          FlutterError.onError = reported;
        }
      }, skip: !_enabled);
    }
  }
}

/// Mounts the host at [size] with four phones joined, each with a long
/// nickname: the sample state's own two make way for them.
Future<FakeHostService> _hostWithFour(WidgetTester tester, Size size, {Widget screen = const StubHome()}) async {
  final fake = await pumpHost(tester, screen: screen, size: size);
  fake.removeController('p1');
  fake.removeController('p2');
  var state = fake.state;
  for (var i = 0; i < _names.length; i++) {
    state = withController(state, phoneInfo('p${i + 1}', i + 1, name: _names[i]));
  }
  fake.state = state;
  fake.emit();
  await tester.pumpAndSettle();
  return fake;
}

/// Starts the five-round night and records [rounds] of its rounds by hand, as
/// a played round would.
Future<void> _playRounds(WidgetTester tester, int rounds) async {
  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: NightLength.five, awards: threeAwards);
  for (var i = 0; i < rounds; i++) {
    night.recordRound(roundResult(points: _roundPoints, winners: {'p1'}, stats: i == 0 ? _roundStats : const {}));
  }
}

/// Home → Play → Party night: the night's start card.
Future<void> _openStart(WidgetTester tester, Size size) async {
  await _hostWithFour(tester, size);
  await openNight(tester);
}

/// A night with [rounds] of its five in, whose scoreboard the picker's card
/// opens again: the night is over on the last round, so that is its final
/// scores.
Future<void> _openScoreboard(WidgetTester tester, Size size, {required int rounds}) async {
  await _hostWithFour(tester, size);
  await openNight(tester);
  await _playRounds(tester, rounds);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('pickPartyNight')));
  await tester.pumpAndSettle();
}

/// The awards' reveal under a night already played: its first award is on the
/// screen, read before the award's timer moves on.
Future<void> _openReveal(WidgetTester tester, Size size) async {
  await _hostWithFour(tester, size, screen: const NightRevealScreen());
  await _playRounds(tester, _nightRounds);
  await tester.pump();
}

/// The round's result, as the Bumper Round hands it over: P1 won the coins.
RoundResult _arenaResult() => RoundResult(
  game: 'arena',
  winners: {'p1'},
  points: _roundPoints,
  lines: {
    for (final line in _roundPoints.entries)
      line.key: RoundLine(
        outcome: line.key == 'p1' ? RoundOutcome.win : RoundOutcome.loss,
        count: line.value,
        countOf: RoundCount.coins,
      ),
  },
);

/// The Bumper Round's results card over the harness, as the Arena shows it
/// after a round ([ArenaResults] owns the card alone).
Future<void> _openArenaResults(WidgetTester tester, Size size) async {
  final again = FocusNode(debugLabel: 'fitArenaAgain');
  addTearDown(again.dispose);
  await _hostWithFour(
    tester,
    size,
    screen: ArenaResults(
      result: _arenaResult(),
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
/// over the board (the other two players sit the round out).
Future<void> _openPuzzleResults(WidgetTester tester, Size size) async {
  final fake = await _hostWithFour(tester, size);
  await openJoin(tester);
  await startRace(tester, fake);
  lockEveryPiece(tester);
  await endRound(tester);
}

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
/// own text scale (a MediaQuery's) and everything that scales it above.
double? _fontDp(RenderParagraph paragraph) {
  final size = paragraph.text.style?.fontSize;
  if (size == null) return null;
  return paragraph.textScaler.scale(size) * _scaleAbove(paragraph);
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

/// What the screen at [size] measured: its errors, its scrolling, the text it
/// had to shorten, its smallest type and its way on.
Map<String, Object?> _measure(WidgetTester tester, _Case screen, String size, List<String> errors) {
  final drawn = _Drawn()..visit(tester.element(screen.root));
  final sizes = <double>[];
  final label24 = <double>[];
  final scaled = <double>{};
  final clipped = <Map<String, Object?>>[];
  for (final paragraph in drawn.paragraphs) {
    final dp = _fontDp(paragraph);
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
  return {
    'screen': screen.name,
    'size': size,
    'errors': errors,
    'scrolls': [
      for (final s in drawn.scrolls)
        {
          'extent': s.position.maxScrollExtent.roundToDouble(),
          'viewport': s.position.viewportDimension.roundToDouble(),
        },
    ],
    'clipped': clipped,
    'texts': drawn.paragraphs.length,
    'smallestFontDp': sizes.isEmpty ? null : sizes.reduce(min),
    'label24Dp': label24,
    'wayOn': _action(tester, screen.actions),
    'scalesAwayFromOne': scaled.toList(),
  };
}

/// Saves the frame on the screen as `<name>.png`, read as the pixels tests read
/// it: the root layer's own image, which needs the real event loop.
Future<void> _savePng(WidgetTester tester, String name) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  image.dispose();
  File('${_outDir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
}
