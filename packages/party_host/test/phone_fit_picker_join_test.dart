import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/host_harness.dart';
import 'support/phone_fit_support.dart';
import 'support/toy_fonts.dart';

/// The game picker and the join screen measured at the five host sizes (brief
/// M16 s7): at the plain device size (today's real look) and laid out in the
/// 960x540 design frame (phone_fit_option_c_test's fit, without the Thumby's
/// strip). Every case runs and asserts only that its screen opened and was
/// measured; whether it fits is the report's to say. The numbers go to
/// `docs/briefs/m16/phonehost1/s7-results.json`.

/// A device the two screens are measured on: its name for the results and its
/// logical size.
typedef _Device = ({String name, Size size});

/// The frame the host screens are designed in: the TV's 960x540, laid out at
/// its own pixels and scaled to the device (option C).
const _designFrame = Size(960, 540);

/// The devices measured (brief s7): the two a phone host lies at, two tablets
/// and a TV.
const _devices = <_Device>[
  (name: '640x360', size: Size(640, 360)),
  (name: '852x393', size: Size(852, 393)),
  (name: '1024x768', size: Size(1024, 768)),
  (name: '1280x800', size: Size(1280, 800)),
  (name: '1920x1080', size: Size(1920, 1080)),
];

/// The nicknames the four phones joined with: at most 10 characters, the
/// longest a real host keeps (`maxNicknameLength`), as option C's roster.
const _fourNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris'];

/// The two screens, with four phones connected: how to open each, and the
/// buttons that are its way on (the first it has is the one looked for).
/// The picker's settings button is its last way on and is measured on its own
/// ([_settingsWayOn]).
final _screens = <PhoneFitCase>[
  (
    name: 'games-picker',
    root: find.byType(GamesScreen),
    actions: const [Key('pickShapeRace'), Key('pickArena'), Key('pickPartyNight')],
    open: _openPicker,
  ),
  (name: 'join-screen', root: find.byType(JoinScreen), actions: const [Key('joinStart')], open: _openJoinScreen),
];

/// Every measurement taken, in the order the tests run: the file is written
/// once they are all in.
final _results = <Map<String, Object?>>[];

/// The folder the results go in, from the package or from the repo root
/// ([phone_fit_test.dart]'s shape).
final _outDir = Directory.current.path.endsWith('party_host')
    ? Directory('../../docs/briefs/m16/phonehost1')
    : Directory('docs/briefs/m16/phonehost1');

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);
  tearDownAll(() {
    // The evidence file is rewritten only on purpose (PHONE_FIT=1) and only by a complete run of all 20 cases.
    if (Platform.environment['PHONE_FIT'] != '1' || _results.length != _devices.length * _screens.length * 2) return;
    File('${_outDir.path}/s7-results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
  });

  for (final device in _devices) {
    for (final screen in _screens) {
      for (final framed in [false, true]) {
        testWidgets('${screen.name} at ${device.name}${framed ? ' in a 960x540 frame' : ''}', (tester) async {
          _results.add(await _oneCase(tester, screen, device, framed: framed));
        });
      }
    }
  }
}

/// One case: [screen] opened at [device]'s size (in the 960x540 frame when
/// [framed]) and what it measured. The scroll, content and layout heights are
/// in the layout's own pixels: device dp at the plain size, frame px in the
/// frame; the smallest text is reported in device dp and in frame px.
Future<Map<String, Object?>> _oneCase(
  WidgetTester tester,
  PhoneFitCase screen,
  _Device device, {
  required bool framed,
}) async {
  final fit = _fit(device.size);
  final layout = framed ? fit.frame : device.size;
  final scale = framed ? fit.scale : 1.0;
  final errors = <String>[];
  final reported = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    await screen.open(tester, (size: layout, names: _fourNames, points: fourPoints));
    // The screen opened: what it draws is recorded, never judged.
    expect(screen.root, findsOneWidget, reason: '${screen.name} opened at ${device.name}');
    final thrown = tester.takeException();
    if (thrown != null) errors.add(thrown.toString());
    final measured = measureScreen(tester, screen, device.name, errors, deviceScale: scale);
    // Measured: every screen here has text to read.
    expect(measured.texts, greaterThan(0), reason: '${screen.name} drew no text at ${device.name}');
    final smallest = measured.smallestFontDp;
    return {
      ...measurementJson(measured),
      'case': '${screen.name}-${device.name}${framed ? '-frame' : ''}',
      'layout': framed ? 'frame' : 'plain',
      'layoutSize': _sizeName(layout),
      'frame': framed ? _sizeName(fit.frame) : null,
      'scale': _round(scale, 4),
      'scrollExtent': scrollExtentOf(measured).roundToDouble(),
      'contentHeight': contentHeightOf(measured)?.roundToDouble(),
      'screenHeight': tester.getRect(screen.root).height.roundToDouble(),
      'fitsNoScroll': fitsNoScroll(measured),
      'smallestFontFramePx': smallest == null ? null : _round(smallest / scale, 2),
      'wayOnSettings': _settingsWayOn(tester, screen, device.name, scale),
    };
  } finally {
    FlutterError.onError = reported;
  }
}

/// How [device] draws the 960x540 frame: the scale a Transform.scale wrapper
/// would set (the device's smaller side over the frame's) and the frame's own
/// size, which grows past 960x540 the other way round (that extra is layout
/// room, as phone_fit_option_c_test reads it).
({double scale, Size frame}) _fit(Size device) {
  final scale = math.min(device.width / _designFrame.width, device.height / _designFrame.height);
  return (scale: scale, frame: device / scale);
}

/// The picker's settings button, its last way on, looked for alone: the
/// picker's case names its first game card as the way on. Null for the join
/// screen, whose Start button is already its case's way on.
Map<String, Object?>? _settingsWayOn(WidgetTester tester, PhoneFitCase screen, String sizeName, double scale) {
  if (screen.name != 'games-picker') return null;
  final probe = (
    name: screen.name,
    root: screen.root,
    actions: const <Key>[Key('openPuzzleSettings')],
    open: screen.open,
  );
  return measureScreen(tester, probe, sizeName, const [], deviceScale: scale).wayOn;
}

/// Home → Play: the game picker.
Future<void> _openPicker(WidgetTester tester, PhoneFitSetup setup) async {
  await hostWithPlayers(tester, setup);
  await tapVisible(tester, find.byKey(const Key('openPlay')));
  await tester.pumpAndSettle();
}

/// Home → Play → Shape Race → the house puzzle's join screen, with all four
/// phones on a side (two a side), as they are just before Start. The house
/// puzzle is scrolled to first: the picker's level list scrolls at small sizes.
Future<void> _openJoinScreen(WidgetTester tester, PhoneFitSetup setup) async {
  final fake = await hostWithPlayers(tester, setup);
  await openShapeRace(tester);
  final house = find.byKey(const Key('puzzle-house'));
  await tester.ensureVisible(house);
  await tester.pumpAndSettle();
  await tester.tap(house);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < setup.names.length; i++) {
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
