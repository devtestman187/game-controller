import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/main.dart';
import 'package:tvtest/src/tv_host_presence.dart';

/// A TV that is hidden is a host that is away (M16 item 2): the phones that
/// joined it draw their host-away card from `hostAwayProvider`, which the app's
/// root scope maps to the TV's one `HostPresence`.
void main() {
  testWidgets('the TV reports host away while its app is hidden, and back when it is shown', (tester) async {
    final fake = FakeHostService(sampleState());
    // The first launch's question is already answered, so no dialog covers the
    // home screen.
    SharedPreferences.setMockInitialValues({statsConsentKey: true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          hostServiceProvider.overrideWithValue(fake),
          // The platform inputs the home screen keeps alive: a widget test has
          // no audio engine and no screen to keep awake.
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          screenAwakeProvider.overrideWithValue(FakeScreenAwake()),
          // `main.dart`'s mapping, which is only built in the app's own scope.
          hostAwayProvider.overrideWith((ref) => ref.watch(tvHostPresenceProvider).away),
          // The TV look, as the app's root scope sets it.
          toyTvProvider.overrideWithValue(true),
          lookClockProvider.overrideWithValue(() => DateTime(2026, 11, 8, 12)),
        ],
        child: const ToyStillSky(child: TvTestApp()),
      ),
    );
    await tester.pumpAndSettle();

    final away = ProviderScope.containerOf(tester.element(find.byType(TvTestApp))).read(hostAwayProvider);
    expect(away.value, isFalse, reason: 'a shown TV is not away');
    expect(fake.gameHost.hostAways, isEmpty, reason: 'nothing is told to the phones before it is hidden');

    // The system reports a backgrounded app as inactive first, then hidden.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(away.value, isTrue, reason: 'the hidden TV is away');
    expect(fake.gameHost.hostAways, [30], reason: 'the phones hear the 30 s grace of the away card');

    // Hidden comes back through inactive, where the listener sees the app
    // shown; resumed then makes it interactive again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(away.value, isFalse, reason: 'shown again inside the grace, the host is back');
    expect(fake.gameHost.hostAways, [30, null], reason: 'the phones hear the host is back');
    expect(fake.resumes, 1, reason: 'the server restarts before the game unpauses');
  });
}
