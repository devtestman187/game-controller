import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone_fit_support.dart';
import 'support/toy_fonts.dart';

/// Whether the measurement is wanted: the night screens are measured only when
/// PHONE_FIT=1 is set in the environment, so the suite's normal run is
/// untouched (brief pf1). `--dart-define=PHONE_FIT=true` is the same switch for
/// a tool that cannot set a variable for one command.
final _enabled = Platform.environment['PHONE_FIT'] == '1' || const bool.fromEnvironment('PHONE_FIT');

/// The host sizes measured, in logical pixels with a devicePixelRatio of 1: a
/// phone host lying down and standing up, a tablet and a TV (brief pf1).
const _sizes = [
  (name: '640x360', size: Size(640, 360)),
  (name: '360x640', size: Size(360, 640)),
  (name: '1280x800', size: Size(1280, 800)),
  (name: '1280x720', size: Size(1280, 720)),
];

/// The nicknames the four phones joined with: every one is 18 characters or
/// more, so a card that cuts a name shows here (brief pf1).
const _names = ['Bartholomew The Great', 'Maximilian Thunderbolt', 'Alexandria Nightshade', 'Christopher Von Trapp'];

/// Every measurement taken, in the order the tests run: the file is written
/// once they are all in.
final _results = <Map<String, Object?>>[];

/// The folder the pictures and the results go in, from the package or from the
/// repo root ([puzzleDataDir]'s shape).
final _outDir = Directory.current.path.endsWith('party_host')
    ? Directory('../../docs/briefs/m16/phonefit')
    : Directory('docs/briefs/m16/phonefit');

void main() {
  // The screens are measured with their real fonts, as a device draws them.
  setUpAll(loadLookFonts);
  tearDownAll(() {
    if (_results.isEmpty) return;
    File('${_outDir.path}/results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
  });

  for (final at in _sizes) {
    for (final screen in nightScreens) {
      testWidgets('${screen.name} at ${at.name}: what it draws and whether it fits', (tester) async {
        // A RenderFlex overflow is a report, not a throw: taking them here
        // keeps one screen's spill from stopping the others (brief pf1).
        final errors = <String>[];
        final reported = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.exceptionAsString());
        try {
          await screen.open(tester, (size: at.size, names: _names, points: fourPoints));
          final thrown = tester.takeException();
          if (thrown != null) errors.add(thrown.toString());
          await saveFramePng(tester, '${_outDir.path}/${screen.name}-${at.name}.png');
          _results.add(measurementJson(measureScreen(tester, screen, at.name, errors)));
        } finally {
          FlutterError.onError = reported;
        }
      }, skip: !_enabled);
    }
  }
}
