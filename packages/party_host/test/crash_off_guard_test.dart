import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/crash/crash_reporter.dart';

import 'support/recording_reporter.dart';

/// `CrashReports.capture` drops a report itself while reports are off (the
/// run's review): a reporter that keeps every report it is handed is still
/// sent nothing, so the fake's own drop cannot hide a missing check.
void main() {
  tearDown(() => CrashReports.use(const NoopCrashReporter()));

  test('a reporter that keeps every report is still sent nothing while reports are off', () {
    final reporter = RecordingReporter();
    CrashReports.use(reporter);

    CrashReports.capture(StateError('off'), StackTrace.current, where: 'test');

    expect(reporter.enabled, isFalse);
    expect(reporter.captures, isEmpty, reason: 'the drop is CrashReports\' own, not the reporter\'s');
  });

  test('the same reporter keeps a report handed over while reports are off', () {
    final reporter = RecordingReporter();

    reporter.capture(StateError('off'), null, where: 'test');

    expect(reporter.captures, hasLength(1), reason: 'so the empty list above can only come from CrashReports');
  });
}
