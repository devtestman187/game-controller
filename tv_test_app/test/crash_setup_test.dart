import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/src/tv_host_setup.dart';

/// The crash reporter a test hands the app's setup: it counts what the app
/// asked it to do and keeps the reports it was given, so a test can show the
/// app started reports through it.
class _TestCrashReporter implements CrashReporter {
  /// The `where` tag of every report, in order.
  final captures = <String?>[];

  /// How many times the app turned reports on.
  int enableCount = 0;

  bool _isEnabled = false;

  @override
  bool get enabled => _isEnabled;

  @override
  Future<void> enable() async {
    enableCount++;
    _isEnabled = true;
  }

  @override
  Future<void> disable() async {
    _isEnabled = false;
  }

  @override
  void capture(Object error, StackTrace? stack, {String? where}) => captures.add(where);
}

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
    final reporter = _TestCrashReporter();
    final started = await tvStartCrashReporting(prefs, reporter: reporter);
    expect(started, same(reporter), reason: 'the app provides the reporter the setup returned');

    // It is the reporter every report now goes to.
    await reporter.enable();
    CrashReports.capture(StateError('tv setup'), StackTrace.empty, where: 'tvSetup');
    expect(reporter.captures, ['tvSetup']);
  });

  test('a build with no DSN sends nothing even after a yes', () async {
    SharedPreferences.setMockInitialValues({crashConsentKey: true});
    final prefs = await SharedPreferences.getInstance();
    final reporter = _TestCrashReporter();
    await tvStartCrashReporting(prefs, reporter: reporter);
    expect(reporter.enableCount, 0, reason: 'this test build has no SENTRY_DSN, so Sentry cannot start');
    expect(reporter.enabled, isFalse);
  });
}
