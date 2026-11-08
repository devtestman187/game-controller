import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The font the host's screens draw with, which the test bundle has none of:
/// the theme's family, Roboto (regular, medium and bold).
///
/// Text measured in the test's own font has a box for every letter, so it wraps
/// where a device's text doesn't and every fit comes out too tight. The faces
/// are kept in `test/fonts` (Apache 2.0, see its license file): the Flutter
/// SDK's font cache is only downloaded by a build, so a CI job that only tests
/// doesn't have it (m12 build 5's CI). Icons keep their box size in any font,
/// so the fit needs no icon font. Call it from `setUpAll`: the engine's font
/// work needs the real event loop.
Future<void> loadHostFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Roboto');
  for (final face in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    // `flutter test` runs in the package's folder.
    loader.addFont(Future.value(ByteData.sublistView(File('test/fonts/$face').readAsBytesSync())));
  }
  await loader.load();
}
