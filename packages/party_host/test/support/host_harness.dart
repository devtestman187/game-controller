import 'dart:convert';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fake sound player the last [pumpHost] mounted.
late FakeSoundPlayer sounds;

/// The fake screen-awake adapter the last [pumpHost] mounted.
late FakeScreenAwake awake;

/// The time the harness's clock says: midday, so the look is Sunny unless a
/// test overrides [lookClockProvider] with a time of its own (M13).
final harnessNow = DateTime(2026, 11, 8, 12);

/// Mounts [screen] the way a host app does: inside the look and
/// [ControllerMenus], with every platform input replaced by a fake. A host
/// app's home screen comes from the app; the tests here start on [StubHome].
/// [clock] is the device's time for Auto's palette, [harnessNow] by default.
///
/// [stillSky] puts a [ToyStillSky] above the app, as every widget test that
/// settles needs (the sky drifts for as long as a menu is open): a test about
/// the drift itself passes false, and settles by pumping instead.
Future<FakeHostService> pumpHost(
  WidgetTester tester, {
  required Widget screen,
  Size size = const Size(960, 540),
  bool? consent = true,
  List<Map<String, Object?>> sessions = const [],
  List<Override> overrides = const [],
  DateTime Function()? clock,
  bool stillSky = true,
}) async {
  sounds = FakeSoundPlayer();
  awake = FakeScreenAwake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeHostService(sampleState(), consent: consent);
  fake.stats.summaries.addAll(sessions);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        puzzleLibraryProvider.overrideWith((ref) => testPuzzles()),
        hostServiceProvider.overrideWithValue(fake),
        soundPlayerProvider.overrideWithValue(sounds),
        screenAwakeProvider.overrideWithValue(awake),
        lookClockProvider.overrideWithValue(clock ?? () => harnessNow),
        ...overrides,
      ],
      child: Shortcuts(
        // The TV app's own keys, so the tests press what the remote presses.
        shortcuts: hostActivateShortcuts,
        child: stillSky ? ToyStillSky(child: _HarnessApp(screen: screen)) : _HarnessApp(screen: screen),
      ),
    ),
  );
  if (stillSky) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return fake;
}

/// The apps' root, as both of them build it (M13): the look over the
/// MaterialApp, which takes the theme made from it, and the look's own route
/// observer, so a page's push or pop works the palette out again. It's a phone
/// look (the menu sizes and the phone's type).
class _HarnessApp extends ConsumerWidget {
  const _HarnessApp({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(toyLookProvider);
    return ToyLookScope(
      look: look,
      child: MaterialApp(
        title: 'Thumb Party host',
        theme: toyTheme(look),
        navigatorObservers: [ref.watch(toyLookRouteObserverProvider)],
        // The phones work every screen like the remote (PRD v2 T21), and a
        // touch-first host's thumbs take a focus look away (m12 bug 1107f).
        builder: (context, child) => HostFocusScope(child: ControllerMenus(child: child!)),
        home: screen,
      ),
    );
  }
}

/// Stands in for a host app's home screen: one Play button that opens the
/// game picker under its route name, as the TV app's main screen does. It
/// watches the games' sounds and the phone-joined cue, as every host app's
/// main screen does.
class StubHome extends ConsumerWidget {
  const StubHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gameSoundsProvider);
    ref.watch(playerJoinedProvider);
    return Scaffold(
      key: const Key('home'),
      body: Center(
        child: HostButton(
          key: const Key('openPlay'),
          label: 'Play',
          icon: Icons.sports_esports_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: gamesRouteName),
              builder: (_) => const GamesScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrolls a button into view first: some screens scroll at TV size.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Home → Play → Arena.
Future<void> openArena(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pickArena')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Home → Play → Shape Race.
Future<void> openShapeRace(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pickShapeRace')));
  await tester.pumpAndSettle();
}

/// Home → Play → Shape Race → the house puzzle's join screen.
Future<void> openJoin(WidgetTester tester) async {
  await openShapeRace(tester);
  await tester.tap(find.byKey(const Key('puzzle-house')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// From the join screen: P1 joins the left side and starts the round.
Future<void> startRound(WidgetTester tester, FakeHostService fake) async {
  await press(tester, fake, 'p1', GamepadButton.a);
  await press(tester, fake, 'p1', GamepadButton.a);
  await navigated(tester);
}

/// From the join screen with both phones on the roster: P1 takes the left
/// side, P2 the right, and P1 starts the race.
Future<void> startRace(WidgetTester tester, FakeHostService fake) async {
  await press(tester, fake, 'p1', GamepadButton.a);
  await press(tester, fake, 'p2', GamepadButton.a);
  await press(tester, fake, 'p1', GamepadButton.start);
  await navigated(tester);
}

/// Home → Play → Shape Race → the house puzzle, with P1 on the left and P2 on
/// the right: a race is running when it returns. [size] and [clock] are
/// [pumpHost]'s.
Future<FakeHostService> openRace(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Size size = const Size(960, 540),
  DateTime Function()? clock,
}) async {
  final fake = await pumpHost(tester, screen: const StubHome(), overrides: overrides, size: size, clock: clock);
  fake.state = withController(fake.state, phoneInfo('p2', 2));
  fake.emit();
  await neutral(tester, fake, ['p1', 'p2']);
  await openJoin(tester);
  await startRace(tester, fake);
  return fake;
}

/// The round's clock in ms, as the rules left it (Shape Race's first board).
int timeLeftMs(WidgetTester tester) =>
    tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).snapshot.boards.first.timeLeftMs;

/// Puts [id]'s phone away, at the host clock's zero unless the test set it,
/// and lets the screens hear it: the round waits for that player.
Future<void> holdSlot(WidgetTester tester, FakeHostService fake, String id) async {
  fake.gameHost.clockMs ??= 0;
  fake.gameHost.setAway(id, isAway: true);
  await tester.pump();
  await tester.pump();
}

/// Puts every piece of [side]'s board in place by hand, so the round ends on
/// the steps after it. Returns the play view's match.
PuzzleMatch lockEveryPiece(WidgetTester tester, {PuzzleSide side = PuzzleSide.left}) {
  final match = tester.state<PuzzlePlayViewState>(find.byType(PuzzlePlayView)).match;
  final game = match.gameOf(side);
  for (var i = 0; i < game.pieces.length; i++) {
    game.pieces[i]
      ..state = PieceState.locked
      ..pos = game.targetAt(i);
  }
  return match;
}

/// The frames the rules need to see the end and show the results: a 16 ms
/// frame can pass without one of their 1/60 s steps.
Future<void> endRound(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A phone's buttons, read by the menus two frames later.
Future<void> phone(WidgetTester tester, FakeHostService fake, String id, Set<GamepadButton> buttons) async {
  fake.gameHost.setGamepad(id, GamepadState(buttons: buttons, mode: InputMode.dpad));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// A press: the button held, then let go (the menus act on the change).
Future<void> press(WidgetTester tester, FakeHostService fake, String id, GamepadButton button) async {
  await phone(tester, fake, id, {button});
  await phone(tester, fake, id, {});
}

/// A new player counts as holding what it holds now: settle it first.
Future<void> neutral(WidgetTester tester, FakeHostService fake, Iterable<String> ids) async {
  for (final id in ids) {
    await phone(tester, fake, id, {});
  }
}

/// Lets a push, a pop or a replacement finish.
Future<void> navigated(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder focusText(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first;

bool focused(WidgetTester tester, String key) => Focus.of(tester.element(focusText(key))).hasFocus;

/// The tooltip of the button under the focus (the settings screen's steps).
String? focusedTooltip() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Tooltip>()?.message;

/// The puzzle data folder, relative to this package, or to the repo root when
/// a single test file is run from there.
final puzzleDataDir = Directory.current.path.endsWith('party_host')
    ? '../puzzle_game/puzzles'
    : 'packages/puzzle_game/puzzles';

/// A puzzle, read straight from the package's data files.
Puzzle housePuzzle() => Puzzle.parse(File('$puzzleDataDir/house.json').readAsStringSync());

/// The puzzles, read straight from the package's data files (the asset
/// bundle loads them outside the test's clock).
PuzzleLibrary testPuzzles() {
  final index = jsonDecode(File('$puzzleDataDir/index.json').readAsStringSync()) as Map<String, Object?>;
  return PuzzleLibrary([
    for (final id in (index['puzzles'] as List).cast<String>())
      Puzzle.parse(File('$puzzleDataDir/$id.json').readAsStringSync()),
  ]);
}
