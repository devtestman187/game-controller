import 'package:controller/src/app_info.dart';
import 'package:controller/src/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('appWithBuild (M14 stats)', () {
    test('a store build number joins the version with a plus', () {
      // 0.14.0 and the 654th commit, as CI passes them: the stats' app cell.
      expect(appWithBuild('0.14.0', '654'), '0.14.0+654');
    });

    test('a local "dev" build and an empty build give the bare version', () {
      expect(appWithBuild('0.14.0', 'dev'), '0.14.0');
      expect(appWithBuild('0.14.0', ''), '0.14.0');
    });

    test('the phone\'s controller identity sends the version with its build number', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Local builds have buildNumber 'dev', so this is '0.14.0' here and
      // '0.14.0+654' under CI's --dart-define: either way the identity is the
      // one appWithBuild makes, not the bare version.
      expect(loadIdentity(prefs).appVersion, appWithBuild(appVersion, buildNumber));
    });
  });
}
