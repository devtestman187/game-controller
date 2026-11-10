/// The pictures the tester guide shows (`site/shots/*.png`), drawn from the
/// apps' own widgets (m13.4, tester-guide): a screen of the TV's app and one of
/// the phone's, each captured as the app draws it, then framed side by side on
/// a plain background and written as one PNG.
///
/// The screens are captured in the look's Sunny palette only: the guide is one
/// page for every device, and a tester reads it before choosing a look.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connection/connection.dart';
import 'package:controller/main.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/gyro.dart';
import 'package:controller/src/haptics.dart';
import 'package:controller/src/tilt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'pump_app.dart';

/// The TV's screen (the size the TV app's own screens are laid out at) and the
/// phone's (the owner's iPhone in landscape).
const tvShot = Size(960, 540);
const phoneShot = Size(852, 393);

/// The picture each shot is written at: 1440 x 576, the two frames centred on
/// the Sunny background. Wide enough to read on a laptop, and small enough
/// that six of them load fast on a phone (the busiest is under 300 KB).
const shotPicture = Size(1440, 576);

/// The TV's and the phone's screens inside the picture: the TV drawn at its own
/// 16:9, the phone at its 852 x 393 share of the picture's height.
const tvScreenInShot = Size(720, 405);
const phoneScreenWidthInShot = 486.0;
const phoneScreenInShot = Size(phoneScreenWidthInShot, phoneScreenWidthInShot * 393 / 852);

/// The frame round each screen: the phone's is rounder than the TV's.
const tvBezelPx = 14.0;
const tvCornerPx = 20.0;
const phoneBezelPx = 12.0;
const phoneCornerPx = 30.0;

/// The room the picture keeps at its sides, round the two frames.
const shotGapPx = 56.0;

/// The most one picture may take.
const shotMaxBytes = 300 * 1024;

/// Where the pictures go, from this package's folder (`flutter test` runs
/// there; `site` is one above it), and the address the page uses for them.
const shotDir = '../site/shots';

/// The midday the look's Auto choice reads, so every screen is Sunny (M13:
/// Auto shows Sunny from 7:00 to 19:00).
final shotNoon = DateTime(2026, 11, 10, 12);

/// The puzzle files, read from the package next door: the app ships them as
/// assets, and a test's bundle has none (as `puzzle_size_test` reads them).
final PuzzleLibrary shotPuzzles = () {
  const dir = '../packages/puzzle_game/puzzles';
  final index = jsonDecode(File('$dir/index.json').readAsStringSync()) as Map<String, Object?>;
  return PuzzleLibrary([
    for (final id in (index['puzzles'] as List).cast<String>()) Puzzle.parse(File('$dir/$id.json').readAsStringSync()),
  ]);
}();

/// A running TV with two phones on its roster: the sample state's iPhone, and a
/// second phone joined on the right.
party.HostViewState roomState() =>
    party_test.withController(party_test.sampleState(), party_test.phoneInfo('p2', 2, platform: 'ios'));

/// Puts the last app's screen away: a test mounts the TV's app and then the
/// phone's, and a provider scope can't be given a different set of overrides
/// than the one it was made with.
Future<void> putAway(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// The device's saved settings for a picture: the look's effects off. A still
/// catches a worker mid-blink or a piece mid boing, on the view's own clock,
/// which no two runs share; with the effects off the boards come to rest, so
/// the same bytes are written every run. Every other colour and size is the
/// same either way, and the test bundle loads no shaders, so the pictures look
/// as they do on a device.
const shotSettings = <String, Object>{party.LookSettingsNotifier.effectsKey: false};

/// Mounts the TV's app's home (an empty screen: the test opens the screens it
/// takes pictures of) with the look over it and every platform input a fake,
/// and returns the fake host behind its screens.
Future<party_test.FakeHostService> pumpTv(WidgetTester tester, GlobalKey shot) async {
  tester.view.physicalSize = tvShot;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await putAway(tester);
  SharedPreferences.setMockInitialValues(shotSettings);
  final prefs = await SharedPreferences.getInstance();
  final fake = party_test.FakeHostService(roomState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        party.prefsProvider.overrideWithValue(prefs),
        party.puzzleLibraryProvider.overrideWith((ref) => shotPuzzles),
        party.hostServiceProvider.overrideWithValue(fake),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
        party.lookClockProvider.overrideWithValue(() => shotNoon),
      ],
      child: RepaintBoundary(key: shot, child: const _TvApp()),
    ),
  );
  await tester.pump();
  return fake;
}

/// The TV app's root, as both host apps build it (M13): the look over the
/// MaterialApp, whose theme comes from it, with the menus working every screen
/// from the phones.
class _TvApp extends ConsumerWidget {
  const _TvApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(party.toyLookProvider);
    return party.ToyStillSky(
      child: party.ToyLookScope(
        look: look,
        child: MaterialApp(
          title: 'Thumb Party TV',
          theme: party.toyTheme(look),
          navigatorObservers: [ref.watch(party.toyLookRouteObserverProvider)],
          builder: (context, child) => party.HostFocusScope(child: party.ControllerMenus(child: child!)),
          home: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Opens [screen] on the TV, as the app opens it from its menu, and lets the
/// page transition finish.
Future<void> openTv(WidgetTester tester, Widget screen) async {
  tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The pose the tilt picture is held in: upright in landscape-left, turned 4
/// degrees to the right. Tilt mode calibrates on the first reading, so the
/// stick it shows is at its center.
final steeringPose = Vec3(cos(4 * pi / 180), sin(4 * pi / 180), 0);

/// Mounts the phone's app with every platform input a fake, inside [shot]'s
/// boundary. [paired] starts it on the pad, as a phone that has joined before
/// does, with [mode] picked in its bar and [layout] as the TV's screen tells
/// its phones to show; without [paired] it opens on the Connect screen with
/// [code] typed in.
Future<TestApp> pumpPhone(
  WidgetTester tester,
  GlobalKey shot, {
  bool paired = true,
  PadMode mode = PadMode.dpad,
  GameLayoutMessage? layout,
  String? code,
}) async {
  tester.view.physicalSize = phoneShot;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await putAway(tester);
  SharedPreferences.setMockInitialValues({if (paired) 'lastHost': jsonEncode(tv.toJson()), ...shotSettings});
  final prefs = await SharedPreferences.getInstance();
  final app = TestApp(
    FakeClient(savedTokens: paired ? {'tv-1': 'token'} : {}),
    FakeDiscovery(),
    FakeHaptics(),
    prefs,
    FakeMotionSensors(),
  );
  await pumpFaked(
    tester,
    RepaintBoundary(key: shot, child: const ControllerApp()),
    app: app,
  );
  await settle(tester);
  if (!paired) {
    // A TV found on the Wi-Fi asking for its code: the phone's side of joining.
    app.discovery.emit(DiscoveryState(running: true, everFound: true, hosts: [DiscoveredHost(address: tv)]));
    await settle(tester);
    app.client.emit(ClientSnapshot(status: ClientStatus.waitingForCode, target: tv, hostName: 'Android TV'));
    await settle(tester);
    if (code != null) {
      await tester.enterText(find.byKey(const Key('pairingCode')), code);
      await settle(tester);
    }
    return app;
  }
  app.client.emit(connected);
  await settle(tester);
  if (mode != PadMode.dpad) {
    // The bar's own mode labels, before the round's layout takes the bar over.
    await tester.tap(find.text(party.PhoneText.modeName(mode.name)));
    await tester.pump();
    if (mode == PadMode.gyro) {
      app.motion.hold(steeringPose, samples: 50);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  if (layout != null) {
    app.client.setLayout(layout);
    await settle(tester);
  }
  return app;
}

/// The screen in [shot]'s boundary as it is drawn now.
Future<ui.Image> captureScreen(WidgetTester tester, GlobalKey shot) async {
  final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(boundary.toImage);
  if (image == null) fail('a screen could not be drawn');
  return image;
}

/// The screen in [shot]'s boundary, drawn and captured twice: a page of
/// pictures that change from run to run is no use to a tester. Returns the
/// first capture, which the caller owns.
Future<ui.Image> captureSteady(WidgetTester tester, GlobalKey shot) async {
  final first = await captureScreen(tester, shot);
  final again = await captureScreen(tester, shot);
  final bytes = await png(tester, first);
  expect(await png(tester, again), bytes, reason: 'two captures of a screen are the same bytes');
  again.dispose();
  return first;
}

/// [image] as a PNG file's bytes.
Future<Uint8List> png(WidgetTester tester, ui.Image image) async {
  final data = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  if (data == null) fail('an image could not be written as a PNG');
  return data.buffer.asUint8List();
}

/// Writes the picture of [name] to `site/shots/<name>.png`: the TV's screen and
/// the phone's in their frames on the Sunny background, drawn twice so the
/// bytes prove the picture is the same every run.
Future<void> writeShot(WidgetTester tester, String name, {required ui.Image tv, required ui.Image phone}) async {
  final bytes = await pictureBytes(tester, tv: tv, phone: phone);
  expect(
    await pictureBytes(tester, tv: tv, phone: phone),
    bytes,
    reason: 'two drawings of $name are the same bytes',
  );
  final dir = Directory(shotDir)..createSync(recursive: true);
  final file = File('${dir.path}/$name.png')..writeAsBytesSync(bytes);
  final size = file.lengthSync();
  expect(
    size,
    lessThan(shotMaxBytes),
    reason: '$name is ${size ~/ 1024} KB, over the ${shotMaxBytes ~/ 1024} KB the page allows',
  );
}

/// [picture]'s PNG bytes at [shotPicture].
Future<Uint8List> pictureBytes(WidgetTester tester, {required ui.Image tv, required ui.Image phone}) async {
  tester.view.physicalSize = shotPicture;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.fromSize(
          size: shotPicture,
          child: ShotPicture(tv: tv, phone: phone),
        ),
      ),
    ),
  );
  final image = await captureScreen(tester, key);
  final bytes = await png(tester, image);
  image.dispose();
  return bytes;
}

/// The TV's and the phone's screens in their frames, on the Sunny background:
/// the picture the tester guide shows.
class ShotPicture extends StatelessWidget {
  const ShotPicture({super.key, required this.tv, required this.phone});

  /// The TV's screen as the app drew it.
  final ui.Image tv;

  /// The phone's screen as the app drew it.
  final ui.Image phone;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: party.ToyColors.sunny.background,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: shotGapPx),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Framed(image: tv, screen: tvScreenInShot, bezel: tvBezelPx, corner: tvCornerPx, label: 'TV'),
          _Framed(image: phone, screen: phoneScreenInShot, bezel: phoneBezelPx, corner: phoneCornerPx, label: 'Phone'),
        ],
      ),
    ),
  );
}

/// One screen in a device's frame: the look's ink as the body, the screen
/// inset by [bezel], and the corners a TV's and a phone's have.
class _Framed extends StatelessWidget {
  const _Framed({
    required this.image,
    required this.screen,
    required this.bezel,
    required this.corner,
    required this.label,
  });

  final ui.Image image;
  final Size screen;
  final double bezel;
  final double corner;

  /// What the frame is, for a test that goes looking for it.
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: Container(
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(color: party.ToyColors.sunny.ink, borderRadius: BorderRadius.circular(corner)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(corner - bezel / 2),
        child: RawImage(image: image, width: screen.width, height: screen.height, fit: BoxFit.fill),
      ),
    ),
  );
}
