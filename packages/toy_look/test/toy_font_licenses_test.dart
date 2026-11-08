import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_look/toy_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both fonts reach the licence page, each with the OFL text that came with it', () async {
    final loaded = <String, String>{};
    await registerToyFontLicenses(
      load: (key) async {
        final text = 'OFL for $key';
        loaded[key] = text;
        return text;
      },
    );

    // One entry per font, read through the loader with the package's own key.
    expect(loaded, hasLength(2));
    final fredokaKey = loaded.keys.firstWhere((key) => key.contains('fredoka'));
    final nunitoKey = loaded.keys.firstWhere((key) => key.contains('nunito'));
    expect(fredokaKey, startsWith('packages/toy_look/'));
    expect(nunitoKey, startsWith('packages/toy_look/'));

    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Fredoka') || entry.packages.contains('Nunito'))
        .toList();
    expect(entries, hasLength(2));
    final fredoka = entries.firstWhere((entry) => entry.packages.contains('Fredoka'));
    final nunito = entries.firstWhere((entry) => entry.packages.contains('Nunito'));
    expect(fredoka.packages, ['Fredoka']);
    expect(nunito.packages, ['Nunito']);
    expect(fredoka.paragraphs.single.text, loaded[fredokaKey]);
    expect(nunito.paragraphs.single.text, loaded[nunitoKey]);
  });
}
