import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone_fit_support.dart';
import 'support/toy_fonts.dart';

/// Whether the measurement is wanted: the frames are measured only when
/// PHONE_FIT=1 is set in the environment, so the suite's normal run is
/// untouched (brief oc1). `--dart-define=PHONE_FIT=true` is the same switch for
/// a tool that cannot set a variable for one command.
final _enabled = Platform.environment['PHONE_FIT'] == '1' || const bool.fromEnvironment('PHONE_FIT');

/// The frame the host screens are designed in: the TV's 960x540, laid out at
/// its own pixels and scaled to the device (option C).
const _designFrame = Size(960, 540);

/// The room the Thumby's head and caption take at the bottom of the frame, in
/// frame px: the host lays out above it, so its layout is the frame less this.
const _thumbyStripPx = 60.0;

/// The head's box, the caption strip beside it and the gap around them, in
/// frame px.
const _thumbyHeadPx = 56.0;
const _thumbyCaptionPx = 12.0;
const _thumbyPadPx = 2.0;

/// The placeholder's colours in the saved picture: the strip, the head's box
/// and its caption. Nothing of the host is drawn in them, so the picture shows
/// what is the Thumby's and what is the screen's.
const _stripColour = Color(0xFFE3DACB);
const _headColour = Color(0xFF4A4A55);
const _captionColour = Color(0xFF9A9AA6);

/// The bytes of a pixel in the RGBA data a picture is read back as.
const _rgbaBytes = 4;

/// A device the frame is drawn on: its name for the files and its logical
/// size.
typedef _Device = ({String name, Size size});

/// A screen measured with the roster it is opened with.
typedef _Screen = ({PhoneFitCase screen, List<String> names, Map<String, int> points});

/// The devices the frame is drawn on, in logical pixels (brief oc1): the two a
/// phone host lies at, two tablets and a TV.
const _devices = <_Device>[
  (name: '640x360', size: Size(640, 360)),
  (name: '852x393', size: Size(852, 393)),
  (name: '1024x768', size: Size(1024, 768)),
  (name: '1280x800', size: Size(1280, 800)),
  (name: '1920x1080', size: Size(1920, 1080)),
];

/// The nicknames the four phones joined with: at most 10 characters, the
/// longest a real host keeps (`maxNicknameLength`), so a score row shows what
/// it shows with real names (brief oc1).
const _fourNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris'];

/// The nicknames the six-player variants add.
const _sixNames = [..._fourNames, 'Nightshade', 'Zed'];

/// The points six players took in a round of the measuring night: the four
/// players' points, with the two extra behind them.
const _sixPoints = {...fourPoints, 'p5': 2, 'p6': 0};

/// The screens whose rows grow with the roster, and so are measured again with
/// six phones.
const _sixPlayerScreens = {'night-scoreboard', 'night-final'};

/// The screen and roster of every case: the six pf1 screens with four players,
/// and the two night screens that list the players again with six (brief oc1).
final _screens = <_Screen>[
  for (final screen in nightScreens) (screen: screen, names: _fourNames, points: fourPoints),
  for (final screen in nightScreens.where((s) => _sixPlayerScreens.contains(s.name)))
    (screen: _renamed(screen, '${screen.name}-6p'), names: _sixNames, points: _sixPoints),
];

/// [screen] under [name], for a roster variant's record and files.
PhoneFitCase _renamed(PhoneFitCase screen, String name) =>
    (name: name, root: screen.root, actions: screen.actions, open: screen.open);

/// Every measurement taken, in the order the tests run: the file is written
/// once they are all in.
final _results = <Map<String, Object?>>[];

/// The folder the pictures and the results go in, from the package or from the
/// repo root (the other fit test's shape).
final _outDir = Directory.current.path.endsWith('party_host')
    ? Directory('../../docs/briefs/m16/phonefit/optionC')
    : Directory('docs/briefs/m16/phonefit/optionC');

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);
  tearDownAll(() {
    if (_results.isEmpty) return;
    File('${_outDir.path}/results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
  });

  for (final device in _devices) {
    for (final screen in _screens) {
      for (final withStrip in [false, true]) {
        testWidgets(
          '${screen.screen.name} in a 960x540 frame on ${device.name}${withStrip ? ', Thumby strip' : ''}',
          (tester) async => _results.add(await _oneCase(tester, screen, device, withStrip: withStrip)),
          skip: !_enabled,
        );
      }
    }
  }
}

/// One case: the frame laid out as [device] draws it (less the Thumby's strip
/// when it is reserved), its picture saved, and what it measured.
Future<Map<String, Object?>> _oneCase(
  WidgetTester tester,
  _Screen screen,
  _Device device, {
  required bool withStrip,
}) async {
  final fit = _fit(device.size);
  final layout = _layout(fit, withStrip: withStrip);
  final errors = <String>[];
  final reported = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    await screen.screen.open(tester, (size: layout, names: screen.names, points: screen.points));
    final thrown = tester.takeException();
    if (thrown != null) errors.add(thrown.toString());
    final unused = await _unusedArea(tester, layout);
    final measured = measureScreen(tester, screen.screen, device.name, errors, deviceScale: fit.scale);
    final stem = '${screen.screen.name}-${device.name}${withStrip ? '-thumby' : ''}';
    await _savePicture(tester, '${_outDir.path}/$stem.png', layout: layout, scale: fit.scale, withStrip: withStrip);
    return {
      ...measurementJson(measured),
      'case': stem,
      'device': device.name,
      'frame': _sizeName(fit.frame),
      'layout': _sizeName(layout),
      'scale': _round(fit.scale, 4),
      'thumby': withStrip,
      'scrollExtent': scrollExtentOf(measured).roundToDouble(),
      'contentHeight': contentHeightOf(measured)?.roundToDouble(),
      'fitsNoScroll': fitsNoScroll(measured),
      'dominant': '#${unused.colour.toRadixString(16).padLeft(6, '0')}',
      'unusedPct': _round(unused.share * 100, 1),
    };
  } finally {
    FlutterError.onError = reported;
  }
}

/// How [device] draws the frame: the scale a Transform.scale wrapper would
/// set (the device's smaller side over the frame's) and the frame's own size,
/// which grows past 960x540 the other way round — that extra is layout room.
({double scale, Size frame}) _fit(Size device) {
  final scale = math.min(device.width / _designFrame.width, device.height / _designFrame.height);
  return (scale: scale, frame: device / scale);
}

/// The size the host lays out in: the frame's, less the Thumby's strip.
Size _layout(({double scale, Size frame}) fit, {required bool withStrip}) {
  final reserved = withStrip ? _thumbyStripPx : 0.0;
  return Size(fit.frame.width, fit.frame.height - reserved);
}

/// The colour most of the frame is, and its share of the frame's pixels: what
/// the screen leaves unused. It is read from the rendered frame picture, not
/// from the widgets, so a painted background counts once.
Future<({int colour, double share})> _unusedArea(WidgetTester tester, Size layout) async {
  final image = await _frameImage(tester, layout);
  final data = (await tester.runAsync(() => image.toByteData()))!;
  image.dispose();
  final bytes = data.buffer.asUint8List();
  final counts = <int, int>{};
  for (var i = 0; i + _rgbaBytes - 1 < bytes.length; i += _rgbaBytes) {
    final colour = bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
    counts[colour] = (counts[colour] ?? 0) + 1;
  }
  var dominant = 0;
  var most = 0;
  for (final entry in counts.entries) {
    if (entry.value > most) {
      dominant = entry.key;
      most = entry.value;
    }
  }
  return (colour: dominant, share: most / (bytes.length / _rgbaBytes));
}

/// The frame as it was drawn, in frame px: the root layer's own image, which
/// needs the real event loop.
Future<ui.Image> _frameImage(WidgetTester tester, Size layout) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  return (await tester.runAsync(() => layer.toImage(Offset.zero & layout)))!;
}

/// Saves the frame at [scale], so the picture is the device's size, with the
/// Thumby's placeholder drawn under it when the strip is reserved.
Future<void> _savePicture(
  WidgetTester tester,
  String path, {
  required Size layout,
  required double scale,
  required bool withStrip,
}) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final laid = (await tester.runAsync(() => layer.toImage(Offset.zero & layout, pixelRatio: scale)))!;
  final image = withStrip ? await _withStrip(tester, laid, scale) : laid;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
  image.dispose();
  if (withStrip) laid.dispose();
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}

/// [frame] with the Thumby's strip under it: a placeholder for the head in its
/// 56x56 box and a caption strip beside it, at the device's scale. The host's
/// own pixels are left as they were drawn.
Future<ui.Image> _withStrip(WidgetTester tester, ui.Image frame, double scale) async {
  final width = frame.width.toDouble();
  final strip = _thumbyStripPx * scale;
  final height = frame.height + strip;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(frame, Offset.zero, Paint());
  canvas.drawRect(Rect.fromLTWH(0, frame.height.toDouble(), width, strip), Paint()..color = _stripColour);
  final pad = _thumbyPadPx * scale;
  final head = _thumbyHeadPx * scale;
  final caption = _thumbyCaptionPx * scale;
  final top = frame.height + pad;
  canvas.drawRect(Rect.fromLTWH(pad, top, head, head), Paint()..color = _headColour);
  canvas.drawRect(
    Rect.fromLTWH(pad * 3 + head, top + (head - caption) / 2, width / 4, caption),
    Paint()..color = _captionColour,
  );
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(width.ceil(), height.ceil())))!;
  picture.dispose();
  return image;
}

/// [size] as the files and the report name it.
String _sizeName(Size size) => '${size.width.round()}x${size.height.round()}';

/// [value] to [places] decimals, so the results file stays readable.
double _round(double value, int places) {
  final unit = math.pow(10, places).toDouble();
  return (value * unit).round() / unit;
}
