import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';

import 'support/all_looks.dart';
import 'support/host_harness.dart';

/// The value [_marker] gives when nothing overrides it.
const _defaultMarker = 'default';

/// The value a test's own override gives [_marker], so a test sees it kept in
/// both looks.
const _callerMarker = 'caller';

/// A provider the host harness never overrides, so a test can pass its own
/// override through [pumpHostLook] without a duplicate for one provider.
final _marker = Provider<String>((ref) => _defaultMarker);

/// The key the probe's text carries, so a test finds it once.
const _probeKey = Key('probe');

/// What the probe says: the TV flag the scope answers, the hour of the clock it
/// gives, and the marker it reads, so a test sees the look's overrides and its
/// own.
String _probeText({required bool isTv, required int hour, String marker = _defaultMarker}) =>
    'tv:$isTv hour:$hour marker:$marker';

/// A screen that says what the scope it was mounted in answers.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(toyTvProvider);
    final hour = ref.watch(lookClockProvider)().hour;
    return Text(
      _probeText(isTv: isTv, hour: hour, marker: ref.watch(_marker)),
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
      await pumpHostLook(tester, look, screen: const _Probe(), overrides: [_marker.overrideWithValue(_callerMarker)]);
      expect(
        find.text(_probeText(isTv: look == HostLook.tv, hour: harnessNow.hour, marker: _callerMarker)),
        findsOneWidget,
        reason: 'the ${look.name} look keeps the caller\'s own override and its own TV flag',
      );
    });
  });
}
