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
/// size in any font, so the fit needs no icon font. Call it from `setUpAll`:
/// the engine's font work needs the real event loop.
Future<void> loadHostFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Roboto', 'test/fonts', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']);
  // The theme names them with the package (ToyType), and that is the family
  // the bundle looks up: `packages/toy_look/Fredoka`.
  await _load('packages/toy_look/Fredoka', '../packages/toy_look/fonts/fredoka', ['Fredoka-Variable.ttf']);
  await _load('packages/toy_look/Nunito', '../packages/toy_look/fonts/nunito', ['Nunito-Variable.ttf']);
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
