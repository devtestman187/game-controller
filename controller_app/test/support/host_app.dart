import 'dart:io';

import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/host_start_sheet.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';

import 'pump_app.dart';

/// The app with a real host in it (m12 §3): the fakes the other tests use,
/// the host's own inputs, its folders in a temp folder, and fakes for the
/// advertiser, the sound player and the screen-on adapter. [advertiser] is the
/// fake advertising is recorded on, [sounds] the fake the sounds are counted
/// on; [extra] overrides more, after these, so a test can replace the host's
/// builder.
Future<TestApp> pumpHostApp(
  WidgetTester tester, {
  bool tablet = false,
  Size screen = const Size(852, 393),
  party_test.FakeAdvertiser? advertiser,
  party_test.FakeSoundPlayer? sounds,
  List<Override> extra = const [],
}) async {
  final dir = Directory.systemTemp.createTempSync('thumb-party-host-');
  addTearDown(() => dir.deleteSync(recursive: true));
  // The puzzles come from the asset bundle, which never answers inside the
  // test's clock: read them first, in the real one.
  final puzzles = await tester.runAsync(() async {
    final container = ProviderContainer();
    try {
      return await container.read(party.puzzleLibraryProvider.future);
    } finally {
      container.dispose();
    }
  });
  if (puzzles == null) fail('The puzzles did not load');
  return pumpApp(
    tester,
    tablet: tablet,
    screen: screen,
    extra: [
      ...phoneHostOverrides(directories: TempHostDirectories(dir)),
      party.advertiserProvider.overrideWithValue(advertiser ?? party_test.FakeAdvertiser()),
      party.soundPlayerProvider.overrideWithValue(sounds ?? party_test.FakeSoundPlayer()),
      party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      party.puzzleLibraryProvider.overrideWith((ref) async => puzzles),
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

/// Waits until this phone's own player has paired on its host's link.
Future<void> hostReady(WidgetTester tester, PhoneHost host) =>
    until(tester, () => host.client.snapshot.isConnected, () => 'The own player did not pair: ${host.client.snapshot}');

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
  await hostReady(tester, host);
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

/// Presses a face button on the pad, where a finger would.
Future<void> tapFace(WidgetTester tester, ControllerButton button) async {
  final rect = tester.getRect(find.byKey(const Key('faceButtons')));
  await tester.tapAt(rect.topLeft + FaceGeometry.classic.centers[button]! * rect.width);
  await tester.pump();
}

/// A press the menus count as a new one. The host holds every press for
/// [GameHost.minPressMs] of real time (M10), which the test's clock doesn't
/// move, so the button has to be up again before the next press.
Future<void> pressFace(WidgetTester tester, ControllerButton button) async {
  await tapFace(tester, button);
  // A few frames for the press to reach the host and the menus to act on it.
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
