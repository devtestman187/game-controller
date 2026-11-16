import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reporter whose start fails, as an SDK that cannot initialise does.
class _FailingReporter extends FakeCrashReporter {
  @override
  Future<void> enable() async => throw StateError('cannot start');
}

void main() {
  late FlutterExceptionHandler? savedOnError;

  setUp(() {
    savedOnError = FlutterError.onError;
  });

  tearDown(() {
    FlutterError.onError = savedOnError;
    CrashReports.use(const NoopCrashReporter());
  });

  test('a reporter that fails to start leaves reports off and never throws', () async {
    SharedPreferences.setMockInitialValues({'crashConsent': true});
    final prefs = await SharedPreferences.getInstance();
    final reporter = _FailingReporter();
    await startCrashReporting(prefs: prefs, dsn: 'x', release: '1', environment: 'test', reporter: reporter);
    expect(reporter.enabled, isFalse);
  });

  test('with no earlier error handler an uncaught framework error is still presented', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    FlutterError.onError = null;
    await startCrashReporting(prefs: prefs, dsn: '', release: '1', environment: 'test', reporter: FakeCrashReporter());
    final presented = <FlutterErrorDetails>[];
    final presentErrorBefore = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = presentErrorBefore);
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
    expect(presented, hasLength(1));
  });
}
