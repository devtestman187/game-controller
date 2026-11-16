import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';

import 'support/host_harness.dart';

/// A stats store whose reads a test can hold open one at a time: a read that
/// is still going is what a slow session folder looks like (M14 sentry1).
class _GatedStats extends FakeStats {
  /// How many times the screen asked for the saved sessions.
  int reads = 0;

  /// Whether the reads bring the sessions; while false they fail, as a folder
  /// that cannot be read does.
  bool works = false;

  Completer<void>? _gate;

  /// Holds the reads that start from now on until [release] is called.
  void hold() => _gate = Completer<void>();

  /// Lets a held read finish.
  void release() {
    final gate = _gate;
    _gate = null;
    gate?.complete();
  }

  @override
  Future<List<SessionFile>> sessions() async {
    reads++;
    final gate = _gate;
    if (gate != null) await gate.future;
    if (!works) throw StateError('the session folder is not readable');
    return super.sessions();
  }
}

void main() {
  /// The Stats screen over [stats], whose first read has already failed so its
  /// Retry is showing.
  Future<void> pumpFailing(WidgetTester tester, _GatedStats stats) async {
    await pumpHost(tester, screen: const StatsScreen(), overrides: [statsServiceProvider.overrideWithValue(stats)]);
    expect(find.byKey(const Key('statsRetry')), findsOneWidget);
    expect(stats.reads, 1, reason: 'the screen read the sessions once and failed');
  }

  testWidgets('two quick Retry presses read the sessions once', (tester) async {
    final stats = _GatedStats();
    await pumpFailing(tester, stats);

    // The read that starts now stays going until the test lets it finish.
    stats
      ..works = true
      ..hold();
    await tester.tap(find.byKey(const Key('statsRetry')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('statsRetry')));
    await tester.pump();

    expect(stats.reads, 2, reason: 'the second press waited for the read that was already going');

    stats
      ..summaries.add(sampleSession())
      ..release();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sessionTable')), findsOneWidget);
    expect(stats.reads, 2, reason: 'the held read is the one that filled the table');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reading flag clears when a read fails, so Retry reads again', (tester) async {
    final stats = _GatedStats();
    await pumpFailing(tester, stats);

    await tester.tap(find.byKey(const Key('statsRetry')));
    await tester.pumpAndSettle();

    expect(stats.reads, 2, reason: 'the failed read ended, so its flag cleared');
    expect(find.byKey(const Key('statsRetry')), findsOneWidget, reason: 'it failed again');

    stats
      ..works = true
      ..summaries.add(sampleSession());
    await tester.tap(find.byKey(const Key('statsRetry')));
    await tester.pumpAndSettle();

    expect(stats.reads, 3);
    expect(find.byKey(const Key('sessionTable')), findsOneWidget);
  });
}
