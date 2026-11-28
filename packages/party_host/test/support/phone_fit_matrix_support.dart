import 'dart:math' as math;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'host_harness.dart';
import 'night_harness.dart';
import 'phone_fit_support.dart';

/// One device the matrix measures: its name for the results and its logical
/// size (brief s9m; the five sizes the owner decided on, Nov 20).
typedef MatrixDevice = ({String name, Size size});

/// The five sizes every moved host screen is measured at (brief s9m).
const matrixDevices = <MatrixDevice>[
  (name: '640x360', size: Size(640, 360)),
  (name: '852x393', size: Size(852, 393)),
  (name: '1024x768', size: Size(1024, 768)),
  (name: '1280x800', size: Size(1280, 800)),
  (name: '1920x1080', size: Size(1920, 1080)),
];

/// The text floor of the frame, in frame px (DESIGN section 1, rule 3): the
/// owner's decision is 20 frame px, which is 13.33 dp at 640x360.
const matrixTextFloorPx = 20.0;

/// The slack a frame size, a scroll extent or a rect is compared with: a
/// frame's arithmetic leaves noise in the last digits.
const matrixSlop = 0.01;

/// The nicknames the four phones join with: ten characters, the longest a real
/// host keeps, so a row shows what it shows with real names (brief s9m).
const matrixFourNames = ['Alexandria', 'Nightshade', 'Bartholome', 'Maximilian'];

/// The nicknames the six-player variants add.
const matrixSixNames = [...matrixFourNames, 'Dragonfire', 'Strawberry'];

/// A roster the matrix measures: how many phones joined (for the results and
/// the report) and the names and points they carry.
typedef MatrixRoster = ({int players, String label, List<String> names, Map<String, int> points});

/// The two rosters the owner's decision names: four and six players.
const matrixRosters = <MatrixRoster>[
  (players: 4, label: '4 players', names: matrixFourNames, points: fourPoints),
  (players: 6, label: '6 players', names: matrixSixNames, points: {...fourPoints, 'p5': 2, 'p6': 0}),
];

/// One screen the matrix measures: how to open it, the widget that is its root,
/// and every button that is its way on (the first found is its main one).
typedef MatrixCase = ({
  String name,
  Finder root,
  List<Key> waysOn,
  Future<void> Function(WidgetTester, PhoneFitSetup) open,
});

/// The eight screens the owner's decision names, and each one's ways on: the
/// night's start card, the scoreboard between rounds, the final scores, the
/// awards' reveal, the Arena's and the puzzle's results, the game picker and
/// the join screen. The reveal has no button at all (COMMON: no Skip, no dots).
final matrixScreens = <MatrixCase>[
  (
    name: 'night-start',
    root: find.byType(NightStartScreen),
    waysOn: const [Key('nightShapeRace'), Key('nightBumper')],
    open: _openStart,
  ),
  (
    name: 'night-scoreboard',
    root: find.byType(NightScoreboardScreen),
    waysOn: const [Key('nightShapeRace'), Key('nightBumper')],
    open: _openScoreboard,
  ),
  (
    name: 'night-final',
    root: find.byType(NightScoreboardScreen),
    waysOn: const [Key('nightBackToGames')],
    open: (tester, setup) => _openScoreboard(tester, setup, rounds: nightRounds),
  ),
  (name: 'night-reveal', root: find.byType(NightRevealScreen), waysOn: const [], open: _openReveal),
  (
    name: 'arena-results',
    root: find.byType(ArenaResults),
    waysOn: const [Key('arenaAgain'), Key('arenaChangeMode')],
    open: _openArenaResults,
  ),
  (
    name: 'puzzle-results',
    root: find.byType(PuzzleScreen),
    waysOn: const [
      Key('nextPuzzle'),
      Key('rematch'),
      Key('playAgain'),
      Key('resultsBack'),
      Key('changeTeams'),
      Key('replay'),
    ],
    open: _openPuzzleResults,
  ),
  (
    name: 'games-picker',
    root: find.byType(GamesScreen),
    waysOn: const [Key('pickShapeRace'), Key('pickArena'), Key('pickPartyNight'), Key('openPuzzleSettings')],
    open: _openPicker,
  ),
  (
    name: 'join-screen',
    root: find.byType(JoinScreen),
    waysOn: const [Key('joinStart'), Key('joinBack')],
    open: _openJoinScreen,
  ),
];

/// Every case the matrix takes: the eight screens x the two rosters x the five
/// sizes (brief s9m).
int get matrixCaseCount => matrixScreens.length * matrixRosters.length * matrixDevices.length;

/// What one matrix case measured: the shared fit measurement, the buttons it
/// found of the screen's ways on, and the frame the screen was drawn in.
typedef MatrixMeasurement = ({
  PhoneFitMeasurement measured,
  List<Map<String, Object?>> buttons,
  double scale,
  Size frame,
  Size root,
});

/// Mounts the host in the frame at the setup's size with one connected phone
/// per nickname, in the setup's order (phone_fit_support's harness, drawn in
/// [HostFrame] as both host apps do).
Future<FakeHostService> hostInFrame(
  WidgetTester tester,
  PhoneFitSetup setup, {
  Widget screen = const StubHome(),
}) async {
  final fake = await pumpHost(tester, screen: screen, size: setup.size, framed: true);
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

/// What [screen] measured at [sizeName]: the shared measurement (with the frame
/// scale in dp rather than a hand-made one), every way-on button, and the
/// screen's own rect. [errors] are the frame's errors, collected by the caller.
MatrixMeasurement measureMatrix(WidgetTester tester, MatrixCase screen, String sizeName, List<String> errors) {
  final info = HostFrameInfo.of(tester.element(screen.root));
  final fitCase = (name: screen.name, root: screen.root, actions: screen.waysOn, open: screen.open);
  final measured = measureScreen(tester, fitCase, sizeName, errors);
  return (
    measured: measured,
    buttons: [for (final key in screen.waysOn) _button(tester, key)],
    scale: info.scale,
    frame: info.frame,
    root: tester.getRect(screen.root).size,
  );
}

/// The record the results file keeps for one case.
Map<String, Object?> matrixJson(MatrixCase screen, MatrixRoster roster, MatrixDevice device, MatrixMeasurement m) {
  final smallest = m.measured.smallestFontDp;
  return {
    ...measurementJson(m.measured),
    'case': '${screen.name}-${roster.players}p-${device.name}',
    'players': roster.players,
    'names': roster.names,
    'frame': _sizeName(m.frame),
    'frameScale': _round(m.scale, 4),
    'root': _sizeName(m.root),
    'rootFrame': {'width': _round(m.root.width / m.scale, 1), 'height': _round(m.root.height / m.scale, 1)},
    'smallestFontFramePx': smallest == null ? null : _round(smallest / m.scale, 2),
    'scrollExtent': scrollExtentOf(m.measured).roundToDouble(),
    'contentHeight': contentHeightOf(m.measured)?.roundToDouble(),
    'fitsNoScroll': fitsNoScroll(m.measured),
    'buttons': m.buttons,
  };
}

/// How wide [name] is drawn in the score row's type, with the look's real fonts
/// (brief s9m: the 190 px column is measured with the font engine).
double nameWidthPx(String name) {
  final painter = TextPainter(
    text: TextSpan(text: name, style: ToyType.frame.body),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// One way-on button as the results file keeps it: whether the screen has it,
/// whether the whole of it is on the screen, and where it sits.
Map<String, Object?> _button(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) return {'key': _keyName(key), 'found': false};
  final view = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  final rect = tester.getRect(finder);
  return {
    'key': _keyName(key),
    'found': true,
    'onScreen':
        rect.top >= view.top - matrixSlop &&
        rect.bottom <= view.bottom + matrixSlop &&
        rect.left >= view.left - matrixSlop &&
        rect.right <= view.right + matrixSlop,
    'top': _round(rect.top, 1),
    'bottom': _round(rect.bottom, 1),
  };
}

/// [key]'s name in the results file.
String _keyName(Key key) => key is ValueKey<String> ? key.value : key.toString();

/// Home → Play → Party night: the night's start card.
Future<void> _openStart(WidgetTester tester, PhoneFitSetup setup) async {
  await hostInFrame(tester, setup);
  await openNight(tester);
}

/// A night with [rounds] of its five in, whose scoreboard the picker's card
/// opens again: the night is over on the last round, so that is its final
/// scores.
Future<void> _openScoreboard(WidgetTester tester, PhoneFitSetup setup, {int rounds = midNightRounds}) async {
  await hostInFrame(tester, setup);
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
  await hostInFrame(tester, setup, screen: const NightRevealScreen());
  await playRounds(tester, setup, nightRounds);
  await tester.pump();
}

/// Starts the five-round night and records [rounds] of its rounds by hand, as a
/// played round would (phone_fit_support's, for this harness).
Future<void> playRounds(WidgetTester tester, PhoneFitSetup setup, int rounds) async {
  final night = appContainer(tester).read(partyNightProvider.notifier)
    ..start(length: NightLength.five, awards: threeAwards);
  for (var i = 0; i < rounds; i++) {
    night.recordRound(roundResult(points: setup.points, winners: {'p1'}, stats: i == 0 ? _roundStats : const {}));
  }
}

/// The counters the first round reports, so every award has a winner (P1
/// carries most, drops least and scores most), as phone_fit_support has them.
const _roundStats = {
  'p1': {'carries': 3, 'snaps': 9, 'wrongDrops': 0},
  'p2': {'carries': 1, 'snaps': 4, 'wrongDrops': 2},
  'p3': {'carries': 2, 'snaps': 6, 'wrongDrops': 1},
  'p4': {'carries': 0, 'snaps': 2, 'wrongDrops': 3},
};

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
  final again = FocusNode(debugLabel: 'matrixArenaAgain');
  addTearDown(again.dispose);
  await hostInFrame(
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

/// Shape Race's race with the most phones the round seats (two a side, the
/// brief's "use the most it takes" for six players), played to its end: the
/// results card over the board.
Future<void> _openPuzzleResults(WidgetTester tester, PhoneFitSetup setup) async {
  final fake = await hostInFrame(tester, setup);
  await openJoin(tester);
  final joined = math.min(setup.names.length, 2 * defaultMaxPerSide);
  for (var i = 0; i < joined; i++) {
    await press(tester, fake, 'p${i + 1}', GamepadButton.a);
  }
  await press(tester, fake, 'p1', GamepadButton.start);
  await navigated(tester);
  lockEveryPiece(tester);
  await endRound(tester);
}

/// Home → Play: the game picker.
Future<void> _openPicker(WidgetTester tester, PhoneFitSetup setup) async {
  await hostInFrame(tester, setup);
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
}

/// Home → Play → Shape Race → the house puzzle's join screen, with the most
/// phones Shape Race seats on a side (two a side); the rest keep watching.
Future<void> _openJoinScreen(WidgetTester tester, PhoneFitSetup setup) async {
  final fake = await hostInFrame(tester, setup);
  await openShapeRace(tester);
  final house = find.byKey(const Key('puzzle-house'));
  await tester.ensureVisible(house);
  await tester.pumpAndSettle();
  await tester.tap(house);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final joined = math.min(setup.names.length, 2 * defaultMaxPerSide);
  for (var i = 0; i < joined; i++) {
    await press(tester, fake, 'p${i + 1}', GamepadButton.a);
  }
}

/// [size] as the results file names it.
String _sizeName(Size size) => '${size.width.round()}x${size.height.round()}';

/// [value] to [places] decimals, so the results file stays readable.
double _round(double value, int places) {
  final unit = math.pow(10, places).toDouble();
  return (value * unit).round() / unit;
}
