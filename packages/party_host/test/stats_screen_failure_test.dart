import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/src/testing/fake_crash.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// A stats store whose [sessions] fails until [works] is set, as a session
/// folder that cannot be read does (M14 sentry1).
class _FlakySessions extends FakeStats {
  bool works = false;

  @override
  Future<List<SessionFile>> sessions() async {
    if (!works) throw StateError('the session folder is not readable');
    return super.sessions();
  }
}

void main() {
  late FakeCrashReporter crash;

  setUp(() async {
    crash = FakeCrashReporter();
    CrashReports.use(crash);
    await crash.enable();
  });

  tearDown(() => CrashReports.use(const NoopCrashReporter()));

  /// The Stats screen over a store whose sessions cannot be read.
  Future<_FlakySessions> pumpFailing(WidgetTester tester, {Size size = const Size(960, 540)}) async {
    final flaky = _FlakySessions();
    await pumpHost(
      tester,
      screen: const StatsScreen(),
      size: size,
      overrides: [statsServiceProvider.overrideWithValue(flaky)],
    );
    return flaky;
  }

  testWidgets('a sessions() that throws shows the error and a Retry, never a spinner forever', (tester) async {
    await pumpFailing(tester);

    expect(find.text('Could not read the saved sessions.'), findsOneWidget);
    expect(find.byKey(const Key('statsRetry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the read is over: it failed');
    expect(find.byKey(const Key('sessionTable')), findsNothing);
    expect(crash.captures, hasLength(1), reason: 'the failure is reported once');
    expect(crash.captures.single.where, 'stats_load');
    expect(crash.captures.single.error, isA<StateError>());
    expect(tester.takeException(), isNull, reason: 'the guard reports it instead of throwing it on');
  });

  testWidgets('the error state fits a phone', (tester) async {
    await pumpFailing(tester, size: const Size(852, 393));

    expect(find.text('Could not read the saved sessions.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Retry reads the sessions again and shows the table once they come', (tester) async {
    final flaky = await pumpFailing(tester);
    expect(find.byKey(const Key('sessionTable')), findsNothing);

    flaky
      ..works = true
      ..summaries.add(sampleSession());
    await tester.tap(find.byKey(const Key('statsRetry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sessionTable')), findsOneWidget);
    expect(find.text('Could not read the saved sessions.'), findsNothing);
    expect(find.text('D-pad'), findsOneWidget);
    expect(crash.captures, hasLength(1), reason: 'the retry succeeded, so nothing more is reported');
  });

  testWidgets('the remote reaches Retry and presses it', (tester) async {
    final flaky = await pumpFailing(tester);
    // Export takes the remote's focus; Tab walks the focus on to the Retry.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    flaky
      ..works = true
      ..summaries.add(sampleSession());
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sessionTable')), findsOneWidget, reason: 'the remote pressed Retry');
  });

  testWidgets('Export still saves the session files while the sessions could not be read', (tester) async {
    final flaky = await pumpFailing(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(flaky.exports, 1);
    expect(find.textContaining('D:/Downloads/thumb-party-sessions'), findsOneWidget);
  });
}
