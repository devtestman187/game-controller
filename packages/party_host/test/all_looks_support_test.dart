import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';

/// The hour the caller's own clock gives, so a test sees its override kept in
/// both looks ([harnessNow] is midday).
const _callerHour = 23;

/// The clock a test hands the helper as its own override.
DateTime _callerClock() => DateTime(2026, 11, 8, _callerHour);

/// The key the probe's text carries, so a test finds it once.
const _probeKey = Key('probe');

/// What the probe says: the TV flag the scope answers, and the hour of the
/// clock it gives, so a test reads both the look's override and its own.
String _probeText({required bool isTv, required int hour}) => 'tv:$isTv hour:$hour';

/// A screen that says what the scope it was mounted in answers.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(toyTvProvider);
    final hour = ref.watch(lookClockProvider)().hour;
    return Text(
      _probeText(isTv: isTv, hour: hour),
      key: _probeKey,
    );
  }
}

void main() {
  testWidgets('the helper pumps the screen in each look, the TV flag off in the menu look and on in the TV look', (
    tester,
  ) async {
    await pumpHostLook(tester, HostLook.menu, screen: const _Probe());
    expect(find.byKey(_probeKey), findsOneWidget, reason: 'the menu look mounts the screen once');
    expect(
      find.text(_probeText(isTv: false, hour: harnessNow.hour)),
      findsOneWidget,
      reason: 'the menu look leaves the TV flag off',
    );

    // A second look in one test needs the first look's tree gone, as
    // forEachLook takes it down between its looks.
    await tester.pumpWidget(const SizedBox.shrink());

    await pumpHostLook(tester, HostLook.tv, screen: const _Probe());
    expect(find.byKey(_probeKey), findsOneWidget, reason: 'the TV look mounts the screen once');
    expect(
      find.text(_probeText(isTv: true, hour: harnessNow.hour)),
      findsOneWidget,
      reason: 'the TV look turns the TV flag on',
    );
  });

  testWidgets('forEachLook runs the body for the menu look first, then the TV look', (tester) async {
    final seen = <HostLook>[];
    await forEachLook(tester, (look) async {
      seen.add(look);
      await pumpHostLook(tester, look, screen: const _Probe());
      expect(find.byKey(_probeKey), findsOneWidget, reason: 'the body mounts its screen in the ${look.name} look');
    });
    expect(seen, [HostLook.menu, HostLook.tv], reason: 'the menu look comes first, the TV look after it');
  });

  testWidgets('the helper keeps the caller\'s own overrides in both looks', (tester) async {
    await forEachLook(tester, (look) async {
      await pumpHostLook(tester, look, screen: const _Probe(), clock: _callerClock);
      final probe = tester.widget<Text>(find.byKey(_probeKey));
      expect(probe.data, endsWith('hour:$_callerHour'), reason: 'the ${look.name} look keeps the caller\'s clock');
    });
  });
}
