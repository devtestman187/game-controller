import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every TV test measures its screens in the look's own fonts, Fredoka and
/// Nunito (M13), as the TV draws them.
///
/// Text in the test's own font has a full box for every letter, so it wraps
/// where the TV's text doesn't, and a panel's rows come out far taller than on
/// the screen (Claude's 3b review: the home's first controller measured 187 px
/// high and pushed the second out of the list). The fonts travel with
/// `toy_look` (OFL, design D13), so they are read from the package. Icons keep
/// their box size in any font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('packages/toy_look/Fredoka', '../packages/toy_look/fonts/fredoka/Fredoka-Variable.ttf');
  await _load('packages/toy_look/Nunito', '../packages/toy_look/fonts/nunito/Nunito-Variable.ttf');
  await testMain();
}

/// Registers the face at [path] (from the app's folder, where `flutter test`
/// runs) as the family [family].
Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}
