import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fonts the host's screens draw with, which the test bundle has none of:
/// the theme's family (Roboto: regular, medium and bold) and the icons' own.
///
/// Text measured in the test's own font has a box for every letter, so it wraps
/// where a device's text doesn't and every fit comes out too tight. These come
/// from the Flutter SDK's font cache, which every machine that runs
/// `flutter test` has downloaded, so the same test reads the same on Windows,
/// macOS and Linux (m12 bug 1107f's fit test and its pictures). Call it from
/// `setUpAll`: the engine's font work needs the real event loop.
Future<void> loadHostFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT is not set: run the tests through `flutter test`');
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  await _load('Roboto', [
    for (final face in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) '$fonts/$face',
  ]);
  await _load('MaterialIcons', ['$fonts/materialicons-regular.otf']);
}

/// Loads [paths] as the faces of [family].
Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  }
  await loader.load();
}
