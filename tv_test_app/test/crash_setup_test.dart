import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/src/tv_host_setup.dart';

/// The TV app starts crash reporting at startup (design sentry-consent.md):
/// its build's reporter takes every report, and a build with no DSN sends
/// nothing even after a yes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? flutterErrorBefore;

  setUp(() {
    flutterErrorBefore = FlutterError.onError;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FlutterError.onError = flutterErrorBefore;
    CrashReports.use(const NoopCrashReporter());
  });

  test('the app starts crash reporting with the reporter its build made', () async {
    final prefs = await SharedPreferences.getInstance();
    final reporter = FakeCrashReporter();
    final started = await tvStartCrashReporting(prefs, reporter: reporter);
    expect(started, same(reporter), reason: 'the app provides the reporter the setup returned');

    // It is the reporter every report now goes to.
    await reporter.enable();
    CrashReports.capture(StateError('tv setup'), StackTrace.empty, where: 'tvSetup');
    expect(reporter.captures.map((report) => report.where), ['tvSetup']);
  });

  test('a build with no DSN sends nothing even after a yes', () async {
    SharedPreferences.setMockInitialValues({crashConsentKey: true});
    final prefs = await SharedPreferences.getInstance();
    final reporter = FakeCrashReporter();
    await tvStartCrashReporting(prefs, reporter: reporter);
    expect(reporter.enableCount, 0, reason: 'this test build has no SENTRY_DSN, so Sentry cannot start');
    expect(reporter.enabled, isFalse);
  });
}
