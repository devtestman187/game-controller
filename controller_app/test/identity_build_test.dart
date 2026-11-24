import 'package:controller/src/app_info.dart';
import 'package:controller/src/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('loadIdentity\'s build number (M14 stats)', () {
    test('a build passed in joins the version: "0.14.0+654"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // 0.14.0 is the app's version, 654 the commit count as CI passes it: the
      // identity the phone says hello with carries the build the caller names,
      // not only the one compiled in.
      expect(loadIdentity(prefs, build: '654').appVersion, '$appVersion+654');
    });

    test('a nine-digit build is sent; a ten-digit one gives the bare version', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // The stats' reader keeps 1 to 9 digits and drops anything longer, so the
      // phone sends the bare version rather than a build the reader would drop.
      expect(loadIdentity(prefs, build: '123456789').appVersion, '$appVersion+123456789');
      expect(loadIdentity(prefs, build: '1234567890').appVersion, appVersion);
    });

    test('a local "dev" build sends the bare version', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(loadIdentity(prefs).appVersion, appVersion);
    });
  });
}
