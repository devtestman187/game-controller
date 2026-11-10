import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fonts the host's screens draw with, which the test bundle has none of:
/// the look's Fredoka and Nunito (M13), and Roboto for the stock Material text
/// that names its own family.
///
/// Text measured in the test's own font has a box for every letter, so it wraps
/// where a device's text doesn't and every fit comes out too tight. The faces
/// are kept in `test/fonts` (Apache 2.0, see its license file): the Flutter
/// SDK's font cache is only downloaded by a build, so a CI job that only tests
/// doesn't have it (m12 build 5's CI). The look's two travel with `toy_look`
/// (OFL, design D13), so they are read from the package. Icons keep their box
/// size in any font, so the fit needs no icon font; [loadIconFont] adds the
/// Material icons for the tests that draw one. Call them from `setUpAll`: the
/// engine's font work needs the real event loop.
Future<void> loadHostFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Roboto', 'test/fonts', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']);
  // The theme names them with the package (ToyType), and that is the family
  // the bundle looks up: `packages/toy_look/Fredoka`.
  await _load('packages/toy_look/Fredoka', '../packages/toy_look/fonts/fredoka', ['Fredoka-Variable.ttf']);
  await _load('packages/toy_look/Nunito', '../packages/toy_look/fonts/nunito', ['Nunito-Variable.ttf']);
}

/// The Material icons the apps draw their buttons, tabs and bar with, which the
/// test bundle has none of (M13.4, tester-guide): without the font every icon
/// in a picture came out as an empty box. A fit test measures text only, so it
/// needs no icon font ("icons keep their box size in any font"); a picture
/// shows icons, so `site_shots_test` loads this before it draws one.
///
/// The one face holds every variant Material's names ask for (the filled,
/// outlined, round and sharp sets share the family and differ in codepoint), so
/// one load covers all of them. Call it from `setUpAll`, after [loadHostFonts].
Future<void> loadIconFont() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = iconFont();
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

/// The Flutter SDK's material icons: the engine keeps them in the cache that
/// `flutter test` runs it from, found by walking up from the running tool so
/// that no folder is written down here. A machine that has never precached the
/// SDK's artifacts has no icons, and the walk says so.
File iconFont() {
  final tool = File(Platform.resolvedExecutable).parent;
  for (var dir = tool; ; dir = dir.parent) {
    for (final name in _iconFaceNames) {
      final font = File.fromUri(dir.uri.resolve('$_iconFontInCache/$name'));
      if (font.existsSync()) return font;
    }
    if (dir.parent.path == dir.path) {
      fail(
        'the Material icons are not in the Flutter SDK\'s cache above ${tool.path}: '
        'run `flutter precache` and try again',
      );
    }
  }
}

/// The icons' folder in the SDK's cache, as a URI path from the cache's root (a
/// `/` here is the URI's, not a folder separator this file writes), and the two
/// spellings of the face's file name: the SDK ships it in lower case, and
/// Windows can't tell that from the capitalised name older versions use.
const String _iconFontInCache = 'artifacts/material_fonts';
const List<String> _iconFaceNames = ['materialicons-regular.otf', 'MaterialIcons-Regular.otf'];

/// Registers [faces], kept in [dir], as the family [family].
Future<void> _load(String family, String dir, List<String> faces) async {
  final loader = FontLoader(family);
  for (final face in faces) {
    // `flutter test` runs in the package's folder.
    loader.addFont(Future.value(ByteData.sublistView(File('$dir/$face').readAsBytesSync())));
  }
  await loader.load();
}
