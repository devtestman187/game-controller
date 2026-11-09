import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

/// The two fonts' licence assets, as the package's pubspec declares them.
const _assets = {
  'Fredoka': 'packages/toy_look/fonts/fredoka/OFL.txt',
  'Nunito': 'packages/toy_look/fonts/nunito/OFL.txt',
};

/// A licence text as one run of words: the licence page breaks the file into
/// paragraphs and joins their lines for itself, so its breaks and a Windows
/// checkout's carriage returns don't matter here, and its words do.
String _text(Iterable<String> lines) => lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both fonts reach the licence page, each with the OFL text that ships beside it', () async {
    // Read from the package's own bundle, not a fake loader: an asset the app
    // doesn't ship fails here (M13 9 review).
    await registerToyFontLicenses();

    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Fredoka') || entry.packages.contains('Nunito'))
        .toList();
    expect(entries, hasLength(2));
    for (final MapEntry(key: family, value: asset) in _assets.entries) {
      final entry = entries.firstWhere((entry) => entry.packages.contains(family));
      expect(entry.packages, [family]);
      // The entry's text is the shipped file's, word for word (M13 9 review).
      final shown = _text(entry.paragraphs.expand((paragraph) => paragraph.text.split('\n')));
      expect(shown, contains('SIL Open Font License, Version 1.1'), reason: '$family: the OFL itself');
      expect(shown, startsWith('Copyright'), reason: '$family: its own copyright line');
      expect(shown, equals(_text((await rootBundle.loadString(asset)).split('\n'))), reason: '$family: its asset');
    }
  });
}
