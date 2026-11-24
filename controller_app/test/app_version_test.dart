import 'package:controller/src/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the app version comes from --dart-define=APP_VERSION (release tag)', () {
    test('appVersion is a x.y.z version, with -dev on a local build', () {
      expect(appVersion, isNotEmpty);
      expect(appVersion, const String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0-dev'));
    });

    test('versionLabel shows the version and the build number', () {
      expect(versionLabel, '$appVersion ($buildNumber)');
    });
  });
}
