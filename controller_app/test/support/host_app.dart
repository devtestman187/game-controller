import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:controller/src/ui/pad_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'pump_app.dart';

/// Every puzzle, read from the puzzle package's files once per test file
/// (s9g): the load is real file and asset work, which the test's clock never
/// waits out, so [loadPuzzles] reads it before a file's first test and
/// [pumpHostApp] hands the ready library to the app.
PuzzleLibrary? _puzzles;

/// Reads the puzzle files in the real event loop, once per test file: call it
/// from `setUpAll`, so no test waits on their reads while it runs (s9g).
Future<void> loadPuzzles() async {
  if (_puzzles != null) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  _puzzles = await PuzzleLibrary.load();
}

/// The app with a real host in it (m12 §3): the fakes the other tests use,
/// the host's own inputs, its folders in a temp folder, and fakes for the
/// advertiser, the sound player and the screen-on adapter. [advertiser] is the
/// fake advertising is recorded on, [sounds] the fake the sounds are counted
/// on, [saved] the settings saved before the launch; [extra] overrides more,
/// after these, so a test can replace the host's builder.
Future<TestApp> pumpHostApp(
  WidgetTester tester, {
  bool tablet = false,
  Size screen = const Size(852, 393),
  Map<String, Object> saved = const {},
  party_test.FakeAdvertiser? advertiser,
  party_test.FakeSoundPlayer? sounds,
  List<Override> extra = const [],
}) async {
  final dir = Directory.systemTemp.createTempSync('thumb-party-host-');
  addTearDown(() => dir.deleteSync(recursive: true));
  // A file that didn't read the puzzles in setUpAll gets them here, the slow
  // way: the asset bundle never answers inside the test's clock, so the real
  // event loop has to.
  final puzzles = _puzzles ?? await tester.runAsync(PuzzleLibrary.load);
  if (puzzles == null) fail('The puzzles did not load');
  return pumpApp(
    tester,
    tablet: tablet,
    screen: screen,
    saved: saved,
    extra: [
      ...phoneHostOverrides(directories: TempHostDirectories(dir)),
      party.advertiserProvider.overrideWithValue(advertiser ?? party_test.FakeAdvertiser()),
      party.soundPlayerProvider.overrideWithValue(sounds ?? party_test.FakeSoundPlayer()),
      party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      // The ready library, not a load: the screens' puzzle lists show on their
      // first frame, with nothing to wait for (s9g).
      party.puzzleLibraryProvider.overrideWith((ref) => puzzles),
      ...extra,
    ],
  );
}

/// The host's folders in a temp folder, so a test session never writes into
/// the developer's own folders.
class TempHostDirectories implements party.HostDirectories {
  TempHostDirectories(this.base);

  /// The folder the sessions and the exports go in.
  final Directory base;

  @override
  Future<Directory> sessions() async => Directory('${base.path}${Platform.pathSeparator}sessions');

  @override
  Future<Directory> exports() async => base;
}

/// The app's one container: the party host providers live here, and the
/// pause menu's dialog and the host route read it alike (m12 §3).
ProviderContainer hostContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ControllerScreen).first));

/// The round's phase as the host writes it (m12-host-touch): what the host
/// phone's pad and top bar follow.
party.RoundPhase hostPhase(WidgetTester tester) => hostContainer(tester).read(party.roundPhaseProvider).value;

/// The host the app started: the route is up and `hostingProvider` holds it.
PhoneHost hostOf(WidgetTester tester) {
  final host = hostContainer(tester).read(hostingProvider);
  if (host == null) fail('No host was started');
  return host;
}

/// The longest a wait on the host's own work may take: the puzzle library
/// loads, the server starts and the own player pairs outside the test's clock,
/// and a busy PC slows them all down (s9c).
const _waitLimit = Duration(seconds: 5);

/// This phone's own player of a host that plays here: a host in "Show on this
/// device" has none (m12 bug 1108a rule A), and asking this one for it fails
/// the test rather than reading a null.
ControllerClient ownClientOf(PhoneHost host) {
  final client = host.client;
  if (client == null) fail('This host has no own player: ${host.service.shareView}');
  return client;
}

/// The test's clock one wait step moves, after [_hostWorkStep] of real time:
/// the host's file work, its socket and its own player's link need the event
/// loop between the pumps, and the screens' timers need the pumps between them.
const _frameStep = Duration(milliseconds: 16);
const _hostWorkStep = Duration(milliseconds: 5);

/// Lets the real time the host needs pass in small steps until [done] is
/// true: its file work, its socket and its own player's link run outside the
/// test's clock, so every wait in the real event loop is followed by a pump
/// that hands the result back to the test's zone. Fails after [_waitLimit]
/// with [why]'s message.
Future<void> until(WidgetTester tester, bool Function() done, String Function() why) async {
  for (var waited = Duration.zero; waited < _waitLimit; waited += _frameStep) {
    if (done()) return;
    await tester.runAsync(() => Future<void>.delayed(_hostWorkStep));
    await tester.pump(_frameStep);
  }
  if (done()) return;
  fail(why());
}

/// Pumps in small steps until [finder] matches: for a screen that is up only
/// after the host's own work — the puzzle library's load, a pad press reaching
/// the host's menus, the own player's pairing — which a fixed number of pumps
/// can race (s9c). [what] names it in the failure.
Future<void> untilShown(WidgetTester tester, Finder finder, String what) =>
    until(tester, () => finder.evaluate().isNotEmpty, () => '$what did not show within ${_waitLimit.inSeconds} s');

/// Waits until this phone's own player has paired on its host's link; a host
/// that shows the game on this device pairs none (m12 bug 1108a rule A), so
/// asking this of it fails the test.
Future<void> hostReady(WidgetTester tester, PhoneHost host) => until(
  tester,
  () => ownClientOf(host).snapshot.isConnected,
  () => 'The own player did not pair: ${ownClientOf(host).snapshot}',
);

/// Waits for the round's "Get ready" beat to end (m12-host-touch rule 3): the
/// round steps, and the pad's presses reach it, only then. The phone app asks
/// its host for the beat, so every round starts with one.
Future<void> untilPlaying(WidgetTester tester) => until(
  tester,
  () => hostPhase(tester) == party.RoundPhase.playing,
  () => 'The Get ready beat did not end: ${hostPhase(tester)}',
);

/// Opens the start sheet and picks [choice]; returns the host.
Future<PhoneHost> enterHostMode(WidgetTester tester, {HostChoice choice = HostChoice.onPhone}) async {
  final key = switch (choice) {
    HostChoice.onPhone => const Key('hostOnPhone'),
    HostChoice.onDevice => const Key('hostOnDevice'),
  };
  await tester.tap(find.byKey(const Key('hostGame')));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
  final host = hostOf(tester);
  if (choice == HostChoice.onPhone) {
    // This phone's own player is what its screens wait for (m12 §3).
    await hostReady(tester, host);
  } else {
    // "Show on this device" has no own player to wait for: the host's start is
    // what its screens wait on (m12 bug 1108a).
    await until(tester, () => host.started, () => 'The host did not start');
  }
  await settle(tester);
  return host;
}

/// Stops the host from its chip, as a player does (s7d2 Q1): "Stop hosting",
/// then the host route pops and the Connect screen is back under it.
Future<void> stopHosting(WidgetTester tester, PhoneHost host) async {
  await tester.tap(find.byKey(const Key('hostChip')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('stopHosting')));
  await until(tester, () => !host.live, () => 'The host did not stop');
  await settle(tester);
}

/// The host phone's own player on the join screen's [side] panel, where it
/// says "(you)" (m12-host-touch rule 5).
Finder ownPlayerOn(String side) =>
    find.descendant(of: find.byKey(Key('side-$side')), matching: find.textContaining('(you)'));

/// Hosts on this phone and opens a solo Shape Race round: a tap on the
/// picker's card and on a random easy puzzle, then Start on the join screen,
/// where the own player is in by itself (m12-host-touch rule 5). The round's
/// "Get ready" beat is waited out (rule 3), so the round plays when it returns.
Future<PhoneHost> soloRound(WidgetTester tester) async {
  final host = await enterHostMode(tester);
  await tester.tap(find.byKey(const Key('pickShapeRace')));
  await untilShown(tester, find.byType(party.ShapeRaceScreen), 'The Shape Race screen');
  await untilShown(tester, find.byKey(const Key('random-easy')), 'The puzzle list');
  await tester.tap(find.byKey(const Key('random-easy')));
  await untilShown(tester, find.byType(party.JoinScreen), 'The join screen');
  await untilShown(tester, ownPlayerOn('left'), 'The own player on the left');
  await tester.tap(find.byKey(const Key('joinStart')));
  await untilShown(tester, find.byType(party.PuzzleScreen), 'The puzzle screen');
  await untilPlaying(tester);
  await settle(tester);
  return host;
}

/// Presses A on the pad to work the host's menus: the press goes out to the
/// host, the menus act on it, and the next screen is up.
Future<void> pressA(WidgetTester tester) async {
  await pressFace(tester, ControllerButton.a);
  await settle(tester);
}

/// Presses B on the pad, as the menus' "Back".
Future<void> pressB(WidgetTester tester) async {
  await pressFace(tester, ControllerButton.b);
  await settle(tester);
}

/// Presses Start on the pad, where a finger would: how the host phone pauses
/// its round (m12-host-touch rule 4), whatever the game labels the button.
Future<void> pressStart(WidgetTester tester) async {
  await tester.tap(_startButton);
  await _afterPress(tester);
}

/// The pad's Start pill: the one [SmallButton] drawn for
/// [ControllerButton.start].
Finder get _startButton => find.byWidgetPredicate((w) => w is SmallButton && w.button == ControllerButton.start);

/// Where a finger presses [button] on the pad.
Offset atFace(WidgetTester tester, ControllerButton button) {
  final rect = tester.getRect(find.byKey(const Key('faceButtons')));
  return rect.topLeft + FaceGeometry.classic.centers[button]! * rect.width;
}

/// Presses a face button on the pad, where a finger would.
Future<void> tapFace(WidgetTester tester, ControllerButton button) async {
  await tester.tapAt(atFace(tester, button));
  await tester.pump();
}

/// A press the menus count as a new one. The host holds every press for
/// [GameHost.minPressMs] of real time (M10), which the test's clock doesn't
/// move, so the button has to be up again before the next press.
Future<void> pressFace(WidgetTester tester, ControllerButton button) async {
  await tapFace(tester, button);
  await _afterPress(tester);
}

/// The frames and the real time a press needs to reach the host and the menus
/// to act on it, and the button to be up again for the next one.
Future<void> _afterPress(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pump(const Duration(milliseconds: 16));
  await settle(tester);
}

/// The labels the pad shows for its face buttons, as the menus set them.
String faceLabels(WidgetTester tester) =>
    tester.widget<Semantics>(find.byKey(const Key('faceButtonLabels'))).properties.label!;
