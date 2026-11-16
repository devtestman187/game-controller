import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/crash/crash_reporter.dart';
import 'package:party_host/src/host_id.dart';
import 'package:party_host/src/testing/fake_crash.dart';

import 'support/fake_prefs.dart';

/// The host id retry stops with its host (the run's review): a retry still
/// waiting when the host service is disposed writes nothing, and the last
/// failure leaves one line in the host's log, besides the crash report.
void main() {
  late FakeCrashReporter crashes;
  late List<String> lines;

  setUp(() async {
    crashes = FakeCrashReporter();
    await crashes.enable();
    CrashReports.use(crashes);
    lines = [];
    addTearDown(() => CrashReports.use(const NoopCrashReporter()));
  });

  test('a retry still waiting when the host is disposed writes nothing and reports nothing', () async {
    var hostRuns = true;
    final prefs = FakePrefs(failures: hostIdWriteTries);
    final waits = <Duration>[];

    await persistHostId(
      prefs,
      'host-id-1',
      wait: (delay) async {
        waits.add(delay);
        // The host service is disposed while the write waits for its retry.
        hostRuns = false;
      },
      isAlive: () => hostRuns,
      log: lines.add,
    );

    expect(prefs.writes, 1);
    expect(waits, [hostIdRetryDelay]);
    expect(prefs.saved, isEmpty);
    expect(crashes.captures, isEmpty, reason: 'a stopped host has no failure to report');
    expect(lines, isEmpty);
  });

  test('the last failure logs one line without the error text', () async {
    final prefs = FakePrefs(failures: hostIdWriteTries, throwsOnWrite: true);

    await persistHostId(prefs, 'host-id-2', wait: (_) async {}, log: lines.add);

    expect(prefs.writes, hostIdWriteTries);
    expect(lines, hasLength(1));
    expect(lines.single, contains('host id'));
    expect(lines.single, isNot(contains('The disk is full')), reason: 'the log line carries no error text');
    expect(crashes.captures, hasLength(1));
    expect(crashes.captures.single.where, hostIdWriteWhere);
    expect(crashes.captures.single.error, isA<StateError>());
  });
}
