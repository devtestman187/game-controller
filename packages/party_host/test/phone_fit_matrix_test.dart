import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/phone_fit_matrix_support.dart';
import 'support/toy_fonts.dart';

/// The final gate of M16's phone-host move (brief s9m): every moved host screen
/// x four and six players x the five sizes, laid out in [HostFrame] as both
/// host apps draw it. Each case measures its scroll, every way-on button, its
/// smallest text and its overflow errors, and asserts the owner's decision
/// (Nov 20): no scrolling, way-on buttons whole on screen (DESIGN rule 6), no
/// overflow, and at least 20 frame px of type (DESIGN rule 3).
///
/// The numbers go to `docs/briefs/m16/phonehost2/s9-matrix.json` only on a
/// complete run with PHONE_FIT=1, the guard the other fit tests use; a plain
/// run writes nothing.

/// Every measurement taken, in the order the tests run: the file is written
/// once they are all in.
final _results = <Map<String, Object?>>[];

/// The folder the results go in, from the package or from the repo root
/// (phone_fit_picker_join_test's shape).
final _outDir = Directory.current.path.endsWith('party_host')
    ? Directory('../../docs/briefs/m16/phonehost2')
    : Directory('docs/briefs/m16/phonehost2');

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);
  tearDownAll(_writeResults);

  for (final device in matrixDevices) {
    for (final roster in matrixRosters) {
      for (final screen in matrixScreens) {
        testWidgets('${screen.name}, ${roster.label}, ${device.name}: no scroll, every way on on screen, 20 px text', (
          tester,
        ) async {
          _expectFits(screen, roster, device, await _oneCase(tester, screen, roster, device));
        });
      }
    }
  }

  testWidgets('the six ten-character nicknames fit the 190 px score row whole, with the real fonts', (tester) async {
    final screen = matrixScreens.firstWhere((s) => s.name == 'night-final');
    final roster = matrixRosters.last;
    final device = matrixDevices.first;
    final errors = <String>[];
    final reported = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    try {
      await screen.open(tester, (size: device.size, names: roster.names, points: roster.points));
      expect(tester.takeException(), isNull, reason: 'the final scores open without an overflow');
      for (var i = 0; i < roster.names.length; i++) {
        final paragraph = tester.renderObject<RenderParagraph>(find.byKey(Key('nightName-p${i + 1}')));
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"${roster.names[i]}" is drawn whole in its ${scoreRowNameWidthPx.round()} px column',
        );
      }
      for (final name in roster.names) {
        expect(
          nameWidthPx(name),
          lessThanOrEqualTo(scoreRowNameWidthPx),
          reason: '"$name" fits a ${ToyType.frame.body.fontSize} px line in the score row\'s column',
        );
      }
    } finally {
      FlutterError.onError = reported;
    }
  });
}

/// One case: [screen] opened in the frame at [device]'s size for [roster], its
/// measurement recorded in the results, and the measurement returned so the
/// caller can assert on it (a failing case is still measured).
Future<MatrixMeasurement> _oneCase(
  WidgetTester tester,
  MatrixCase screen,
  MatrixRoster roster,
  MatrixDevice device,
) async {
  final errors = <String>[];
  final reported = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  try {
    await screen.open(tester, (size: device.size, names: roster.names, points: roster.points));
    final thrown = tester.takeException();
    if (thrown != null) errors.add(thrown.toString());
    final measured = measureMatrix(tester, screen, device.name, errors);
    _results.add(matrixJson(screen, roster, device, measured));
    return measured;
  } finally {
    FlutterError.onError = reported;
  }
}

/// The owner's decision on one case: it drew text, nothing overflowed, nothing
/// scrolls, every way-on button is whole on the screen, and no text is under
/// the frame's 20 px floor.
void _expectFits(MatrixCase screen, MatrixRoster roster, MatrixDevice device, MatrixMeasurement m) {
  final where = '${screen.name} at ${device.name} with ${roster.label}';
  expect(m.measured.errors, isEmpty, reason: '$where overflows: ${m.measured.errors}');
  expect(m.measured.texts, greaterThan(0), reason: '$where drew no text');
  // The arena results' card scrolls under its banner when it is full (B-036, owner:
  // "Card scrolls"); every other screen still must not scroll.
  for (final scroll in m.measured.scrolls.where((_) => screen.name != 'arena-results')) {
    expect(
      scroll.extent,
      lessThanOrEqualTo(matrixSlop),
      reason: '$where scrolls ${_axis(scroll.axis)} by ${scroll.extent} px of ${scroll.viewport}',
    );
  }
  final smallest = m.measured.smallestFontDp;
  expect(smallest, isNotNull, reason: '$where drew no measured type');
  expect(
    smallest! / m.scale,
    greaterThanOrEqualTo(matrixTextFloorPx - matrixSlop),
    reason: '$where draws type at ${(smallest / m.scale).toStringAsFixed(2)} frame px',
  );
  final found = m.buttons.where((button) => button['found'] == true).toList();
  if (screen.waysOn.isEmpty) {
    expect(found, isEmpty, reason: '$where has a button but $screen.waysOn names none');
  } else {
    expect(found, isNotEmpty, reason: '$where has none of its ways on (${screen.waysOn}) on screen');
  }
  for (final button in found) {
    expect(button['onScreen'], isTrue, reason: '$where draws ${button['key']} off screen: $button');
  }
}

/// [axis] as the failure's words name it.
String _axis(Axis axis) => axis == Axis.vertical ? 'down' : 'across';

/// Whether the results are wanted: PHONE_FIT=1 in the environment, which
/// `--dart-define=PHONE_FIT=true` stands in for on a tool that cannot set a
/// variable for one command (phone_fit_option_c_test's switch).
final _wanted = Platform.environment['PHONE_FIT'] == '1' || const bool.fromEnvironment('PHONE_FIT');

/// Writes the results file: only on purpose (PHONE_FIT=1) and only by a complete
/// run of every case.
void _writeResults() {
  if (!_wanted || _results.length != matrixCaseCount) return;
  File('${_outDir.path}/s9-matrix.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
}
