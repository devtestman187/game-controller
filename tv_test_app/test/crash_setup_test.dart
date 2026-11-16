import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/src/app_info.dart';
import 'package:tvtest/src/tv_host_setup.dart';

/// The TV app starts crash reporting at startup (design sentry-consent.md):
/// its build's reporter takes every report, names the build as the phone does,
/// and a build with no DSN sends nothing even after a yes.
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

  test('the app starts crash reporting with the release and environment of its build', () async {
    final prefs = await SharedPreferences.getInstance();
    final started = await tvStartCrashReporting(prefs);
    expect(started, isA<SentryCrashReporter>(), reason: 'the app provides no reporter of its own');
    final sentry = started as SentryCrashReporter;
    // A build with no SENTRY_DSN never initialises Sentry: the fields are the
    // only thing a test can read, and they are what the reports carry.
    expect(sentry.release, appWithBuild(appVersion, buildNumber), reason: 'the phone\'s "0.14.0+654" format');
    expect(sentry.environment, 'debug', reason: 'flutter test runs a debug build');
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
