import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// One panel of the picture: wide enough for the picker's two cards side by
/// side (2 x 380 plus the gaps) and tall enough to show the sky above them.
const _panelWidth = 880.0;
const _panelHeight = 460.0;
const _panel = Size(_panelWidth, _panelHeight);

/// The gap between the picture's two panels, in logical pixels.
const _panelGap = 16.0;

/// The Night look the picture is drawn in, at the TV's sizes.
final _night = ToyLook.build(palette: ToyPalette.night, tv: true);

/// How far the sky has drifted when it is drawn: far enough for the twinkle to
/// have turned, the same moment in every run.
const _moment = Duration(milliseconds: 700);

/// The fonts the look draws with: Fredoka and Nunito travel with the package
/// (OFL, design D13), so they are read from it, as `puzzle_game`'s tests do.
Future<void> _loadFonts() async {
  for (final (family, dir, face) in const [
    ('packages/toy_look/Fredoka', 'fonts/fredoka', 'Fredoka-Variable.ttf'),
    ('packages/toy_look/Nunito', 'fonts/nunito', 'Nunito-Variable.ttf'),
  ]) {
    // `flutter test` runs in the package's folder.
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(File('$dir/$face').readAsBytesSync())))).load();
  }
}

/// [child] drawn in [_panel] in the Night look, after [_moment] of drift.
Widget _screen(Widget child) => ToyLookScope(
  look: _night,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: toyTheme(_night),
    home: SizedBox.fromSize(size: _panel, child: child),
  ),
);

/// [child] in the sky's box, drawn and read back as an image.
Future<ui.Image> _capture(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = _panel;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: _screen(SizedBox.fromSize(size: _panel, child: child)),
    ),
  );
  // The sky drifts from its own ticker: two pumps put it at [_moment].
  await tester.pump(_moment);
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage()))!;
}

/// A game picker card as the picker draws one (M13 3b): a [ToyCard] with the
/// game's picture, its name and a line, in the picker's two-card row. The
/// picture is a plain toy shape here: the picker's drawings live in
/// `party_host`, which `toy_look` may not import.
Widget _gameCard(ToyColors colors, String title, String line, Color fill) => SizedBox(
  width: 380,
  height: _night.sizes.buttonHeight * 4,
  child: ToyCard(
    padding: const EdgeInsets.all(ToySizes.space12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _night.sizes.buttonHeight * 4 * 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.ink, width: _night.sizes.outlineWidth),
            ),
          ),
        ),
        const SizedBox(height: ToySizes.space8),
        Text(title, style: _night.type.button.copyWith(color: colors.ink)),
        const SizedBox(height: ToySizes.space4),
        Text(line, style: _night.type.body.copyWith(color: colors.ink), maxLines: 2),
      ],
    ),
  ),
);

/// The picker's row of two cards, over the drifting sky.
Widget _picker() => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: ToySizes.space16),
      child: Text('Games', style: _night.type.title.copyWith(color: _night.colors.onBackground)),
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _gameCard(_night.colors, 'Shape Race', 'Fit the pieces, racing the other side', _night.colors.focus),
        const SizedBox(width: ToySizes.space16),
        _gameCard(_night.colors, 'Puzzle', 'One picture, two sides, no clock to hide in', _night.colors.focus),
      ],
    ),
  ],
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('writes docs/design/m13-night-sky.png', (tester) async {
    final alone = await _capture(tester, const ToyBackground());
    final picker = await _capture(tester, ToyBackground(child: _picker()));
    // The same moment of the same sky, again: the picture is deterministic.
    final again = await _capture(tester, ToyBackground(child: _picker()));

    // The engine's image work needs the real event loop, away from the test's
    // own clock.
    final written = (await tester.runAsync(() async {
      final first = (await picker.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final repeat = (await again.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      expect(repeat, first, reason: 'the same sky at the same moment is the same picture');
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(
          const Rect.fromLTWH(0, 0, _panelWidth, _panelHeight * 2 + _panelGap),
          Paint()..color = const Color(0xFF120B2E),
        )
        ..drawImage(alone, Offset.zero, Paint())
        ..drawImage(picker, const Offset(0, _panelHeight + _panelGap), Paint());
      final image = await recorder.endRecording().toImage(_panelWidth.round(), (_panelHeight * 2 + _panelGap).round());
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final brightest = _brightestPixel(raw);
      image.dispose();
      return (png, brightest);
    }))!;

    final (png, brightest) = written;
    final file = File('../../docs/design/m13-night-sky.png')..writeAsBytesSync(png);
    expect(file.lengthSync(), greaterThan(5000));
    // The sky has stars on it: the panels are not the plain background.
    expect(brightest, greaterThan(150), reason: 'a star shows on the sky');
    alone.dispose();
    picker.dispose();
    again.dispose();
  });
}

/// The brightest pixel of the picture, 0 to 255: a star over the Night sky.
int _brightestPixel(Uint8List bytes) {
  var brightest = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
    final value = (0.2126 * r + 0.7152 * g + 0.0722 * b).round();
    if (value > brightest) brightest = value;
  }
  return brightest;
}
