import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/demo_flags.dart';

void main() {
  test('demoDirector is off unless the build sets DEMO_DIRECTOR', () {
    // The demo pipeline must never run in a test build, or in a store build:
    // no demo preferences prefix, no full-screen call, no demo sessions folder.
    expect(demoDirector, isFalse);
  });
}
