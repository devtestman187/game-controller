/// The joined phone's round strip as a picture, for the M16 phone fit review
/// (docs/briefs/m16/phonefit, M16 item 1): the whole 852 × 393 screen the
/// owner's iPhone draws, with the strip showing round 2 of 5, 0:42 left, this
/// phone's 4 coins and its 2nd place — the look mock-up frame 0 draws
/// (816 × 384).
///
/// The pictures are written only on request, so a plain test run leaves the
/// tree clean: `ROUND_STRIP_PNG=1 flutter test test/round_strip_png_test.dart`.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/controls_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import 'support/pump_app.dart';
import 'support/test_font.dart';

/// The room the phone's screen has, in logical pixels: the landscape iPhone the
/// app's own tests use (one unit is a logical pixel).
const phoneSize = Size(852, 393);

/// Where the pictures go, from this package's folder (`flutter test` runs
/// there), so the review reads them beside this brief.
const shotDir = '../docs/briefs/m16/phonefit';

/// Whether this run asked for the pictures: `ROUND_STRIP_PNG=1 flutter test
/// test/round_strip_png_test.dart`. A plain run skips both, so the suite
/// writes no files and needs none of the fonts.
final bool captureRequested = Platform.environment['ROUND_STRIP_PNG'] == '1';

void main() {
  // The strip's text is the look's own faces, which the test bundle has none
  // of: without them every letter comes out as a box (as `test/support/
  // test_font.dart` says), and the picture would show no words at all. The
  // icons are the pad's; a picture shows them too.
  setUpAll(loadHostFonts);
  setUpAll(loadIconFont);

  testWidgets('round-strip-852x393.png: the strip shows round 2 of 5, 0:42, 4 coins and 2nd', (tester) async {
    await pumpJoinedRound(tester, devicePixelRatio: 1);
    expect(find.byKey(const Key('roundStrip')), findsOneWidget);
    expect(find.text('Round 2 of 5'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget, reason: '42 s as m:ss');
    expect(tester.widget<Text>(find.byKey(const Key('roundCoins'))).data, '4');
    expect(tester.widget<Text>(find.byKey(const Key('roundPlace'))).data, '2nd');

    final bytes = await screenPng(tester);
    expect(bytes.length, greaterThan(5000), reason: 'the picture is a screen, not a blank frame');
    writePng('round-strip-852x393.png', bytes);
  }, skip: !captureRequested);

  testWidgets('round-strip-852x393-2x.png: the same strip at two pixels a logical pixel', (tester) async {
    await pumpJoinedRound(tester, devicePixelRatio: 2);
    expect(find.text('Round 2 of 5'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget, reason: '42 s as m:ss');

    final bytes = await screenPng(tester);
    expect(bytes.length, greaterThan(5000), reason: 'the picture is a screen, not a blank frame');
    writePng('round-strip-852x393-2x.png', bytes);
  }, skip: !captureRequested);
}

/// Mounts the app joined to a host showing a round, as `round_state_test`
/// does: the view starts "Round 2 of 5" and its frame leaves 42 s on the
/// clock, with this phone on 4 coins behind a rival's 7, so the strip shows its
/// place as well as its coins. [devicePixelRatio] is the view's pixels per
/// logical pixel; the screen has the same [phoneSize] of logical room either
/// way.
Future<void> pumpJoinedRound(WidgetTester tester, {required double devicePixelRatio}) async {
  final app = await pumpApp(
    tester,
    paired: true,
    // `pumpApp` lays the view out at one pixel per logical pixel, so it is
    // given the screen's pixels; the ratio is set again above the app it mounts.
    screen: phoneSize * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  await tester.pump();
  app.client.emit(connected);
  await settle(tester);

  app.client.nowMs = 1000;
  app.client.viewStart(_roundStart());
  await settle(tester);
  app.client.viewFrame(_roundFrame(tester));
  await settle(tester);
}

/// The view a host that names its series sends: the Arena, round 2 of 5.
ViewStartMessage _roundStart() => ViewStartMessage(
  game: arenaModule.id,
  snapshotVersion: arenaModule.snapshotVersion,
  setup: arenaSetup,
  hz: 60,
  round: 2,
  rounds: 5,
);

/// One frame of that round with 42 s left on its clock, as the strip's coins
/// and place read it: this phone on 4, second behind a rival's 7.
FrameMessage _roundFrame(WidgetTester tester) {
  final me = ProviderScope.containerOf(tester.element(find.byType(ControlsLayer))).read(identityProvider).controllerId;
  final snapshot = ArenaSnapshot(
    round: 2,
    roundTimeS: 30,
    phase: ArenaPhase.playing,
    walls: const [],
    goal: Rect.zero,
    hazards: const [],
    players: [
      const ArenaPlayerView(id: 'rival', x: 0.5, y: 0.5, coins: 7),
      ArenaPlayerView(id: me, x: 0.5, y: 0.5, coins: 4),
      const ArenaPlayerView(id: 'third', x: 0.5, y: 0.5, coins: 1),
    ],
    mode: ArenaMode.bumper,
    timeLeftMs: 42000,
  );
  return FrameMessage(n: 1, atMs: 2000, snapshot: snapshot.toJson(), timeLeftMs: 42000);
}

/// The whole test screen as a PNG, drawn at the view's own pixels per logical
/// pixel (as `test/support/pixels.dart` reads the screen's pixels back).
Future<Uint8List> screenPng(WidgetTester tester) async {
  final ratio = tester.view.devicePixelRatio;
  final size = tester.view.physicalSize / ratio;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = (await tester.runAsync(() => layer.toImage(Offset.zero & size, pixelRatio: ratio)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  image.dispose();
  return data.buffer.asUint8List();
}

/// Writes [bytes] as [name] in [shotDir], creating the folder if it is absent.
void writePng(String name, Uint8List bytes) {
  final dir = Directory(shotDir)..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(bytes);
}
