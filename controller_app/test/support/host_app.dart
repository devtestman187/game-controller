import 'dart:io';

import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';

import 'pump_app.dart';

/// The app with a real host in it (m12 §3): the fakes the other tests use,
/// the host's own inputs, its folders in a temp folder, and fakes for the
/// advertiser, the sound player and the screen-on adapter.
Future<TestApp> pumpHostApp(WidgetTester tester, {bool tablet = false, Size screen = const Size(852, 393)}) async {
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
      party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
      party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
      party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      party.puzzleLibraryProvider.overrideWith((ref) async => puzzles),
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

/// The host the app started: the route is up and `hostingProvider` holds it.
PhoneHost hostOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(tester.element(find.byType(ControllerScreen).first));
  final host = container.read(hostingProvider);
  if (host == null) fail('No host was started');
  return host;
}

/// Lets the real service finish its file and socket work and pair this
/// phone's own player: the test's clock doesn't move real I/O, so every wait
/// in the real event loop is followed by a pump that hands the result back to
/// the test's zone.
Future<void> hostReady(WidgetTester tester, PhoneHost host) async {
  for (var i = 0; i < 200; i++) {
    if (host.client.snapshot.isConnected) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('The own player did not pair: ${host.client.snapshot}');
}

/// Opens the start sheet and picks "Play on this phone"; returns the host.
Future<PhoneHost> enterHostMode(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hostGame')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('hostOnPhone')));
  await settle(tester);
  final host = hostOf(tester);
  await hostReady(tester, host);
  await settle(tester);
  return host;
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
