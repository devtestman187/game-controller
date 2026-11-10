import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
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

/// The family the picture's theme falls back to for a symbol no font the apps
/// bundle draws: the join screen's `◀` and `▶` (M13.4). A device draws them
/// from its system font; a test's own font gives a box, as the look's Fredoka
/// and Nunito do (neither has U+25C0 or U+25B6).
const String symbolFallbackFamily = 'SymbolFallback';

/// The package the look's fonts come from, as its styles name it. Flutter puts
/// a style's package in front of every family it falls back to, not only the
/// style's own, and the look's styles are the ones that draw the join screen's
/// header: so the face is loaded under this package's [symbolFallbackFamily]
/// as well, or the header finds no fallback at all.
const String _lookPackage = 'toy_look';

/// The families [loadSymbolFont] loads the machine's face as: the plain name
/// the picture's theme lists, and the look's packaged spelling the engine
/// resolves it to.
const List<String> _symbolFamilies = [symbolFallbackFamily, 'packages/$_lookPackage/$symbolFallbackFamily'];

/// Where a desktop machine keeps a face that has those symbols, the first one
/// [loadSymbolFont] finds: Windows' Segoe UI Symbol, macOS' Apple Symbols, and
/// DejaVu (Linux).
const List<String> _symbolFontPaths = [
  'C:/Windows/Fonts/seguisym.ttf',
  '/System/Library/Fonts/Apple Symbols.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
];

/// Registers the machine's symbol face as [symbolFallbackFamily], for the
/// pictures' theme to name as a fallback. Only a picture test loads it: a fit
/// test measures the app's own text, and the face is the machine's, not the
/// repo's (its licence is not one this project ships), so a machine without it
/// still draws the pictures and says so.
///
/// Call it from `setUpAll`, after [loadHostFonts].
Future<void> loadSymbolFont() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final face = _symbolFont();
  if (face == null) {
    debugPrint(
      'no symbol font on this machine (tried ${_symbolFontPaths.join(', ')}): '
      'the join screen\'s ◀ ▶ are drawn as boxes',
    );
    return;
  }
  for (final family in _symbolFamilies) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(face.readAsBytesSync())));
    await loader.load();
  }
}

/// The first of [_symbolFontPaths] this machine has, or null.
File? _symbolFont() {
  for (final path in _symbolFontPaths) {
    final font = File(path);
    if (font.existsSync()) return font;
  }
  return null;
}

/// Registers [faces], kept in [dir], as the family [family].
Future<void> _load(String family, String dir, List<String> faces) async {
  final loader = FontLoader(family);
  for (final face in faces) {
    // `flutter test` runs in the package's folder.
    loader.addFont(Future.value(ByteData.sublistView(File('$dir/$face').readAsBytesSync())));
  }
  await loader.load();
}
