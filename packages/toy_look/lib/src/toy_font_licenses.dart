import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

/// The two fonts' licence texts, as the package ships them (design D13: the
/// OFL asks for its text to travel with the font).
const _fontLicenses = [
  (family: 'Fredoka', asset: 'packages/toy_look/fonts/fredoka/OFL.txt'),
  (family: 'Nunito', asset: 'packages/toy_look/fonts/nunito/OFL.txt'),
];

/// Adds the two bundled fonts' licence texts to the app's licence page (M13,
/// design D13): one entry per font, read from the assets that ship beside the
/// fonts.
///
/// The apps call it once at start, so the licences page has both fonts when a
/// player opens it. [load] is how the text is read: [rootBundle.loadString]
/// unless a test hands in its own reader.
Future<void> registerToyFontLicenses({Future<String> Function(String key)? load}) async {
  final read = load ?? rootBundle.loadString;
  for (final license in _fontLicenses) {
    final text = await read(license.asset);
    LicenseRegistry.addLicense(() => Stream.value(LicenseEntryWithLineBreaks([license.family], text)));
  }
}
