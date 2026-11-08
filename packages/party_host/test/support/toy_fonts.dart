import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fonts the look's screens draw with, which the test bundle has none of:
/// Fredoka and Nunito travel with `toy_look` (OFL, design D13), so they are
/// read from the package (M13 3b, as the phone app's `test_font.dart` does).
///
/// Text measured in the test's own font has a box for every letter, so it wraps
/// where a device's text doesn't and every fit comes out too tight. Icons keep
/// their box size in any font, so the fit needs no icon font. Call it from
/// `setUpAll`: the engine's font work needs the real event loop.
Future<void> loadLookFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The type names them with the package (ToyType), and that is the family the
  // bundle looks up: `packages/toy_look/Fredoka`.
  await _load('packages/toy_look/Fredoka', '../toy_look/fonts/fredoka', ['Fredoka-Variable.ttf']);
  await _load('packages/toy_look/Nunito', '../toy_look/fonts/nunito', ['Nunito-Variable.ttf']);
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
