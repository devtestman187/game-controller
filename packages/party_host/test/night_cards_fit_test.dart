import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/phone_fit_matrix_support.dart';
import 'support/phone_fit_support.dart';
import 'support/toy_fonts.dart';

/// Whether the measurement is wanted: the results are written only when
/// NIGHT_FIT=1 is set (or `--dart-define=NIGHT_FIT=true`), so the suite's
/// normal run leaves the docs folder untouched (brief p0a, as option C does).
final _enabled = Platform.environment['NIGHT_FIT'] == '1' || const bool.fromEnvironment('NIGHT_FIT');

/// The frame the host screens are designed in, laid out at its own pixels and
/// scaled to the device (option C).
const _designFrame = Size(960, 540);

/// The room Thumby's corner head needs at the top right, in dp (brief p0a).
const _headDp = 56.0;

/// The share of the view a box must cover each way to count as the card or page
/// behind the content rather than content.
const _backdropShare = 0.5;

/// The lines of body type the caption strip needs, across the full width.
const _stripLines = 2;

/// The results file both fit tests write a section of, from the package or from
/// the repo root.
final _outFile = File(
  Directory.current.path.endsWith('party_host')
      ? '../../docs/briefs/m17/m17prep/p0a-fit.json'
      : 'docs/briefs/m17/m17prep/p0a-fit.json',
);

/// The name of this file's section in the results file.
const _section = 'nightCards';

/// A device the cards are drawn on: its name and its logical size.
typedef _Device = ({String name, Size size});

/// The two sizes of the brief: a small portrait phone and an iPhone SE lying.
const _devices = <_Device>[(name: '360x640', size: Size(360, 640)), (name: '667x375', size: Size(667, 375))];

/// The nicknames the phones joined with, at most 10 characters.
const _sixNames = ['Bartholome', 'Maxi', 'Alexandria', 'Chris', 'Nightshade', 'Zed'];
const _sixPoints = {...fourPoints, 'p5': 2, 'p6': 0};

/// A thing the screen draws: what it is and where, in dp.
typedef _Box = ({String what, Rect rect});

/// What one card measured at one size.
typedef _Measured = ({
  List<String> errors,
  int texts,
  double smallestTextFramePx,
  List<String> belowFloor,
  double contentBottomDp,
  String lowest,
  double freeBandDp,
  double cornerFreeWidthDp,
  String cornerBlocker,
  double bodyLineDp,
});

/// Every record taken, in the order the tests run.
final _results = <Map<String, Object?>>[];

void main() {
  setUpAll(loadLookFonts);
  tearDownAll(() {
    if (!_enabled || _results.isEmpty) return;
    final file = _outFile.existsSync()
        ? jsonDecode(_outFile.readAsStringSync()) as Map<String, Object?>
        : <String, Object?>{};
    file[_section] = _results;
    _outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(file));
  });

  final cards = nightScreens.where((s) => const {'night-start', 'night-scoreboard', 'night-reveal'}.contains(s.name));
  for (final card in cards) {
    for (final device in _devices) {
      for (final players in const [4, 6]) {
        testWidgets('${card.name} at ${device.name} with $players players draws without overflow or exception', (
          tester,
        ) async {
          final record = await _oneCase(tester, card, device, players);
          if (_enabled) _results.add(record.json);
          expect(record.measured.errors, isEmpty, reason: 'overflow or exception');
        });
      }
    }
  }

  testWidgets('the measurer reports the overflow of a deliberately overflowing widget', (tester) async {
    final errors = <String>[];
    final reported = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: Key('stub'),
              width: 100,
              height: 100,
              child: Row(children: [SizedBox(width: 400, height: 20), Text('stub')]),
            ),
          ),
        ),
      );
    } finally {
      FlutterError.onError = reported;
    }
    final measured = _measure(
      tester,
      find.byKey(const Key('stub')),
      layout: const Size(100, 100),
      scale: 1,
      bodyStyle: const TextStyle(fontSize: 20),
      errors: errors,
    );

    expect(measured.errors, isNotEmpty);
    expect(measured.errors.first, contains('overflowed'));
  });
}

/// One case's measurement and its record.
typedef _Record = ({_Measured measured, Map<String, Object?> json});

/// One case: the card opened in the frame as [device] draws it, with
/// [players] phones, and what it measured.
Future<_Record> _oneCase(WidgetTester tester, PhoneFitCase card, _Device device, int players) async {
  final scale = math.min(device.size.width / _designFrame.width, device.size.height / _designFrame.height);
  final layout = device.size / scale;
  final errors = <String>[];
  final reported = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    final names = _sixNames.take(players).toList();
    final points = players == 4 ? fourPoints : _sixPoints;
    await card.open(tester, (size: layout, names: names, points: points));
    final thrown = tester.takeException();
    if (thrown != null) errors.add(thrown.toString());
    final bodyStyle = ToyLookScope.of(tester.element(card.root)).type.body;
    final measured = _measure(tester, card.root, layout: layout, scale: scale, bodyStyle: bodyStyle, errors: errors);
    final whole = measureScreen(tester, card, device.name, errors, deviceScale: scale);
    final headFits = measured.cornerFreeWidthDp >= _headDp;
    final stripFits = measured.freeBandDp >= _stripLines * measured.bodyLineDp;
    return (
      measured: measured,
      json: {
        'card': card.name,
        'device': device.name,
        'players': players,
        'layoutPx': '${layout.width.round()}x${layout.height.round()}',
        'scale': _round(scale),
        'errors': measured.errors,
        'texts': measured.texts,
        'smallestTextFramePx': measured.smallestTextFramePx,
        'belowFloor': measured.belowFloor,
        'clipped': whole.clipped.length,
        'scrollExtentDp': _round(scrollExtentOf(whole) * scale),
        'contentBottomDp': measured.contentBottomDp,
        'lowestElement': measured.lowest,
        'freeBandDp': measured.freeBandDp,
        'bodyLineDp': measured.bodyLineDp,
        'stripNeedsDp': _round(_stripLines * measured.bodyLineDp),
        'cornerFreeWidthDp': measured.cornerFreeWidthDp,
        'cornerBlocker': measured.cornerBlocker,
        'headFits': headFits,
        'stripFits': stripFits,
      },
    );
  } finally {
    FlutterError.onError = reported;
  }
}

/// What [root] draws: its text sizes (frame px) and the things it draws (dp,
/// through [scale]), against a [layout] of frame px.
_Measured _measure(
  WidgetTester tester,
  Finder root, {
  required Size layout,
  required double scale,
  required TextStyle bodyStyle,
  required List<String> errors,
}) {
  final paragraphs = <RenderParagraph>[];
  final boxes = <RenderBox>[];
  void visit(Element element) {
    final render = element.renderObject;
    if (render is RenderParagraph && !paragraphs.contains(render)) paragraphs.add(render);
    if (render is RenderDecoratedBox || render is RenderPhysicalShape || render is RenderPhysicalModel) {
      if (!boxes.contains(render)) boxes.add(render! as RenderBox);
    }
    element.visitChildren(visit);
  }

  visit(tester.element(root));
  final things = <_Box>[];
  final sizes = <double>[];
  final belowFloor = <String>[];
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    final px = paragraph.textScaler.scale(paragraph.text.style?.fontSize ?? 0);
    final framePx = (px * _scaleAbove(paragraph) * 1000).round() / 1000;
    if (px > 0) sizes.add(framePx);
    if (px > 0 && framePx < matrixTextFloorPx - matrixSlop) belowFloor.add('${_short(text)} $framePx');
    things.add((what: 'text "${_short(text)}"', rect: _dp(paragraph, scale)));
  }
  for (final box in boxes) {
    final rect = _dp(box, scale);
    // A box over half the view each way is the card or the page behind the
    // content, not content: it would hide every free band.
    final isBackdrop =
        rect.width >= layout.width * scale * _backdropShare && rect.height >= layout.height * scale * _backdropShare;
    if (!isBackdrop) things.add((what: '${box.runtimeType} ${_rectName(rect)}', rect: rect));
  }
  final view = layout * scale;
  final visible = [
    for (final t in things)
      if (!t.rect.isEmpty && t.rect.top < view.height) t,
  ];
  var bottom = 0.0;
  var lowest = 'nothing';
  for (final t in visible) {
    final b = math.min(t.rect.bottom, view.height);
    if (b > bottom) {
      bottom = b;
      lowest = t.what;
    }
  }
  var right = 0.0;
  var blocker = 'nothing';
  for (final t in visible.where((t) => t.rect.top < _headDp)) {
    if (t.rect.right > right) {
      right = t.rect.right;
      blocker = t.what;
    }
  }
  final line = TextPainter(
    text: TextSpan(text: 'Ag', style: bodyStyle),
    textDirection: TextDirection.ltr,
  )..layout();
  final lineDp = line.height * scale;
  line.dispose();
  return (
    errors: errors,
    texts: paragraphs.length,
    smallestTextFramePx: sizes.isEmpty ? 0 : sizes.reduce(math.min),
    belowFloor: belowFloor,
    contentBottomDp: _round(bottom),
    lowest: lowest,
    freeBandDp: _round(view.height - bottom),
    cornerFreeWidthDp: _round(view.width - right),
    cornerBlocker: blocker,
    bodyLineDp: _round(lineDp),
  );
}

/// [rect] as the results file names a box: its left, top, width and height in dp.
String _rectName(Rect rect) =>
    '[${rect.left.round()},${rect.top.round()} ${rect.width.round()}x${rect.height.round()}]';

/// [box]'s rect on the screen, scaled from frame px to dp.
Rect _dp(RenderBox box, double scale) {
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return Rect.fromLTRB(rect.left * scale, rect.top * scale, rect.right * scale, rect.bottom * scale);
}

/// How far everything above [paragraph] scales it (1 in a frame laid out at
/// its own pixels).
double _scaleAbove(RenderParagraph paragraph) {
  final origin = paragraph.localToGlobal(Offset.zero);
  return (paragraph.localToGlobal(const Offset(1, 0)) - origin).distance;
}

/// [text] cut for the results file.
String _short(String text) => text.length <= 24 ? text : '${text.substring(0, 24)}…';

/// [value] to 2 decimals, so the results file stays readable.
double _round(double value) => (value * 100).round() / 100;
