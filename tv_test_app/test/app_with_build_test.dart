import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/app_info.dart';

void main() {
  group('appWithBuild (M14 stats)', () {
    test('a store build number joins the version with a plus', () {
      // 0.14.0 and the 654th commit, as CI passes them: the TV's crash report
      // names its build the phone's way (the run's review: it sent "0.14.0 (654)").
      expect(appWithBuild('0.14.0', '654'), '0.14.0+654');
    });

    test('a local "dev" build and an empty build give the bare version', () {
      expect(appWithBuild('0.14.0', 'dev'), '0.14.0');
      expect(appWithBuild('0.14.0', ''), '0.14.0');
    });

    test('a count longer than the stats reader keeps gives the bare version', () {
      // metrics' splitAppBuild reads 1 to 9 digits and drops a longer one.
      expect(appWithBuild('0.14.0', '1234567890'), '0.14.0');
    });
  });
}
