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
/// player opens it. The texts are read from the bundle the package ships them
/// in, so a missing asset fails the test that registers them (M13 9 review).
Future<void> registerToyFontLicenses() async {
  for (final license in _fontLicenses) {
    final text = await rootBundle.loadString(license.asset);
    LicenseRegistry.addLicense(() => Stream.value(LicenseEntryWithLineBreaks([license.family], text)));
  }
}
