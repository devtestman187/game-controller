import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:controller/src/layout.dart';
import 'package:controller/src/ui/result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' show ToyLookScope;
import 'package:protocol/protocol.dart';

import 'support/joined.dart';
import 'support/pump_app.dart';
import 'support/test_font.dart';

/// Whether the measurement is wanted: the results are written only when
/// NIGHT_FIT=1 is set (or `--dart-define=NIGHT_FIT=true`), so the suite's
/// normal run leaves the docs folder untouched (brief p0a).
final _enabled = Platform.environment['NIGHT_FIT'] == '1' || const bool.fromEnvironment('NIGHT_FIT');

/// The room Thumby's corner head needs at the top right, in dp (brief p0a).
const _headDp = 56.0;

/// The lines of body type the caption strip needs, across the full width.
const _stripLines = 2;

/// The share of the view a box must cover each way to count as the page behind
/// the content rather than content.
const _backdropShare = 0.5;

/// The decimals the results file keeps.
const _decimals = 100;

/// How much of a text the results file keeps.
const _textShown = 24;

/// The results file both fit tests write a section of, from the app's folder or
/// from the repo root.
final _outFile = File(
  Directory.current.path.endsWith('controller_app')
      ? '../docs/briefs/m17/m17prep/p0a-fit.json'
      : 'docs/briefs/m17/m17prep/p0a-fit.json',
);

/// The name of this file's section in the results file.
const _section = 'nightResult';

/// The two sizes of the brief: a small portrait phone and an iPhone SE lying.
const _sizes = <Size>[Size(360, 640), Size(667, 375)];

/// The nicknames and points of the six standings, best first.
const _names = ['Bartholome', 'Maxi', 'Alexandria', 'Chris', 'Nightshade', 'Zed'];
const _points = [12, 9, 7, 5, 3, 1];

/// A night's round the card is held at: round 2 of 5 (its standings), or round
/// 5 of 5 with the night's end in (awards, standings and winner: the tallest).
typedef _Moment = ({String name, int round, bool withEnd});

const _moments = <_Moment>[
  (name: 'round-standings', round: 2, withEnd: false),
  (name: 'night-end', round: 5, withEnd: true),
];

/// The rounds of the measuring night.
const _nightRounds = 5;

/// A thing the card draws: what it is and where, in dp.
typedef _Box = ({String what, Rect rect});

/// What the card measured at one size.
typedef _Measured = ({
  List<String> errors,
  int texts,
  double smallestTextDp,
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
  setUpAll(loadHostFonts);
  tearDownAll(() {
    if (!_enabled || _results.isEmpty) return;
    final file = _outFile.existsSync()
        ? jsonDecode(_outFile.readAsStringSync()) as Map<String, Object?>
        : <String, Object?>{};
    file[_section] = _results;
    _outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(file));
  });

  for (final moment in _moments) {
    for (final size in _sizes) {
      for (final players in const [4, 6]) {
        testWidgets('the phone result card at ${moment.name}, ${size.width.round()}x${size.height.round()}, '
            '$players players draws without overflow or exception', (tester) async {
          final errors = <String>[];
          final reported = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.exceptionAsString());
          try {
            await _open(tester, size, moment, players);
            final thrown = tester.takeException();
            if (thrown != null) errors.add(thrown.toString());
          } finally {
            FlutterError.onError = reported;
          }
          expect(errors, isEmpty, reason: 'overflow or exception');
          if (size.width < minWindowWidth) {
            // The phone is locked to landscape: a window narrower than the
            // pad needs shows only "Make the window bigger", never the card.
            expect(find.byType(ResultCard), findsNothing, reason: 'the card is not drawn in a window this narrow');
            expect(find.byKey(const Key('tooSmall')), findsOneWidget);
            if (_enabled) _results.add(_tooSmallJson(moment, size, players));
            return;
          }
          final body = ToyLookScope.of(tester.element(find.byType(ResultCard))).type.body;
          final measured = _measure(tester, find.byType(ResultCard), view: size, bodyStyle: body, errors: errors);
          if (_enabled) _results.add(_json(moment, size, players, measured));

          expect(measured.errors, isEmpty, reason: 'overflow or exception');
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
      view: const Size(100, 100),
      bodyStyle: const TextStyle(fontSize: 20),
      errors: errors,
    );

    expect(measured.errors, isNotEmpty);
    expect(measured.errors.first, contains('overflowed'));
  });
}

/// A standing for the player at [index] of the roster, whose ID is `p<number>`.
ViewStanding _standing(int index) => ViewStanding(
  id: 'p${index + 1}',
  number: index + 1,
  name: _names[index],
  points: _points[index],
  character: const PlayerCharacter(colourSlot: 1, accessory: PlayerAccessory.ears),
);

/// The phone joined as player 1 with the round's end shown at [size]: [players]
/// standings, and the night's end when the moment has it.
Future<void> _open(WidgetTester tester, Size size, _Moment moment, int players) async {
  final standings = [for (var i = 0; i < players; i++) _standing(i)];
  final app = await joined(tester, screen: size);
  app.client.emit(connected.copyWith(player: 1));
  await settle(tester);
  app.client.viewEnd(
    ViewEndMessage(
      reason: ViewEndReason.finished,
      result: ViewResult(
        outcome: ViewOutcome.win,
        timeS: 58,
        points: 12,
        round: moment.round,
        of: _nightRounds,
        place: 1,
        standings: standings,
      ),
    ),
  );
  await settle(tester);
  if (moment.withEnd) {
    app.client.nightEnd(
      NightEndMessage(
        awards: const [
          NightAwardRow(id: 'fast', name: 'Fastest', points: 3, winners: ['p1']),
          NightAwardRow(id: 'steady', name: 'Steadiest', points: 3, winners: ['p2']),
          NightAwardRow(id: 'none', name: 'Most carries', points: 3, winners: []),
        ],
        standings: standings,
      ),
    );
    await settle(tester);
  }
}

/// The record of a case where the window is too narrow for the card to be drawn.
Map<String, Object?> _tooSmallJson(_Moment moment, Size size, int players) => {
  'moment': moment.name,
  'device': '${size.width.round()}x${size.height.round()}',
  'players': players,
  'cardShown': false,
  'shown': 'Make the window bigger (window under $minWindowWidth dp wide)',
};

/// The record the results file keeps for one case.
Map<String, Object?> _json(_Moment moment, Size size, int players, _Measured m) => {
  'moment': moment.name,
  'device': '${size.width.round()}x${size.height.round()}',
  'players': players,
  'errors': m.errors,
  'texts': m.texts,
  'smallestTextDp': m.smallestTextDp,
  'contentBottomDp': m.contentBottomDp,
  'lowestElement': m.lowest,
  'freeBandDp': m.freeBandDp,
  'bodyLineDp': m.bodyLineDp,
  'stripNeedsDp': _round(_stripLines * m.bodyLineDp),
  'cornerFreeWidthDp': m.cornerFreeWidthDp,
  'cornerBlocker': m.cornerBlocker,
  'headFits': m.cornerFreeWidthDp >= _headDp,
  'stripFits': m.freeBandDp >= _stripLines * m.bodyLineDp,
};

/// What [root] draws on a [view] of dp: its text sizes and the things it draws,
/// where the free band under them and the free width at the top right are.
_Measured _measure(
  WidgetTester tester,
  Finder root, {
  required Size view,
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
  for (final paragraph in paragraphs) {
    final text = paragraph.text.toPlainText();
    final px = paragraph.textScaler.scale(paragraph.text.style?.fontSize ?? 0);
    if (px > 0) sizes.add(px * _scaleAbove(paragraph));
    final short = text.length <= _textShown ? text : '${text.substring(0, _textShown)}…';
    things.add((what: 'text "$short"', rect: paragraph.localToGlobal(Offset.zero) & paragraph.size));
  }
  for (final box in boxes) {
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // A box over half the view each way is the card or the page behind the
    // content, not content: it would hide every free band.
    final isBackdrop = rect.width >= view.width * _backdropShare && rect.height >= view.height * _backdropShare;
    if (!isBackdrop) things.add((what: '${box.runtimeType} ${_rectName(rect)}', rect: rect));
  }
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
  final lineDp = line.height;
  line.dispose();
  return (
    errors: errors,
    texts: paragraphs.length,
    smallestTextDp: sizes.isEmpty ? 0 : _round(sizes.reduce(math.min)),
    contentBottomDp: _round(bottom),
    lowest: lowest,
    freeBandDp: _round(view.height - bottom),
    cornerFreeWidthDp: _round(view.width - right),
    cornerBlocker: blocker,
    bodyLineDp: _round(lineDp),
  );
}

/// How far everything above [paragraph] scales it: the card shrinks as a whole
/// to fit a small screen, and its text with it.
double _scaleAbove(RenderParagraph paragraph) {
  final origin = paragraph.localToGlobal(Offset.zero);
  return (paragraph.localToGlobal(const Offset(1, 0)) - origin).distance;
}

/// [rect] as the results file names a box: its left, top, width and height in dp.
String _rectName(Rect rect) =>
    '[${rect.left.round()},${rect.top.round()} ${rect.width.round()}x${rect.height.round()}]';

/// [value] to 2 decimals, so the results file stays readable.
double _round(double value) => (value * _decimals).round() / _decimals;
