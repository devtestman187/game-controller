import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/src/crash/crash_reporter.dart';
import 'package:party_host/src/host_id.dart';
import 'package:party_host/src/testing/fake_crash.dart';

import 'support/fake_prefs.dart';

void main() {
  late FakeCrashReporter crashes;

  setUp(() async {
    crashes = FakeCrashReporter();
    await crashes.enable();
    CrashReports.use(crashes);
    addTearDown(() => CrashReports.use(const NoopCrashReporter()));
  });

  test('a write that fails twice then succeeds is saved on the third try', () async {
    final prefs = FakePrefs(failures: 2);
    final waits = <Duration>[];

    await persistHostId(prefs, 'host-id-1', wait: (delay) async => waits.add(delay));

    expect(prefs.writes, 3);
    expect(prefs.saved['hostId'], 'host-id-1');
    expect(waits, [hostIdRetryDelay, hostIdRetryDelay]);
    expect(crashes.captures, isEmpty);
  });

  test('a thrown error counts as a failed try and the next one saves', () async {
    final prefs = FakePrefs(failures: 1, throwsOnWrite: true);

    await persistHostId(prefs, 'host-id-2', wait: (_) async {});

    expect(prefs.writes, 2);
    expect(prefs.saved['hostId'], 'host-id-2');
    expect(crashes.captures, isEmpty);
  });

  test('a write that always fails reports once and the host keeps its new id', () async {
    final prefs = FakePrefs(failures: hostIdWriteTries);

    final id = loadOrMakeHostId(prefs, Random(7), wait: (_) async {});
    await pumpEventQueue();

    expect(id, matches(RegExp('^[0-9a-f]{${hostIdBytes * 2}}\$')));
    expect(prefs.writes, hostIdWriteTries);
    expect(prefs.saved, isEmpty);
    expect(crashes.captures, hasLength(1));
    expect(crashes.captures.single.where, hostIdWriteWhere);
    expect(crashes.captures.single.error, isA<StateError>());
  });

  test('a write that keeps throwing reports the thrown error once', () async {
    final prefs = FakePrefs(failures: hostIdWriteTries, throwsOnWrite: true);

    loadOrMakeHostId(prefs, Random(7), wait: (_) async {});
    await pumpEventQueue();

    expect(prefs.writes, hostIdWriteTries);
    expect(crashes.captures, hasLength(1));
    expect(crashes.captures.single.error, isA<StateError>());
    expect(crashes.captures.single.stack, isNotNull);
  });

  test('a saved id is reused and never rewritten', () async {
    final prefs = FakePrefs()..saved['hostId'] = 'saved-host-id';

    final id = loadOrMakeHostId(prefs, Random(1));
    await pumpEventQueue();

    expect(id, 'saved-host-id');
    expect(prefs.writes, 0);
    expect(prefs.saved['hostId'], 'saved-host-id');
  });

  test('no write happens when an id exists', () async {
    final prefs = FakePrefs()..saved['hostId'] = 'saved-host-id';

    loadOrMakeHostId(prefs, Random(1));
    await pumpEventQueue();

    expect(prefs.writes, 0);
    expect(crashes.captures, isEmpty);
  });
}
