import 'dart:async';
import 'dart:io';

import 'package:connection/connection.dart';
import 'package:controller/src/discovery.dart';
import 'package:controller/src/home/home_text.dart';
import 'package:controller/src/home/phone_home_screen.dart';
import 'package:controller/src/host/host_overrides.dart';
import 'package:controller/src/host/hosting.dart';
import 'package:controller/src/host/phone_host.dart';
import 'package:controller/src/providers.dart';
import 'package:controller/src/ui/connect_screen.dart';
import 'package:controller/src/ui/controller_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_host/party_host.dart' as party;
import 'package:party_host/testing.dart' as party_test;

import 'support/host_app.dart';
import 'support/pump_app.dart';

/// Records the exits Back asks for, in place of the platform's exit.
class _FakeExit {
  int calls = 0;

  Future<void> call() async {
    calls++;
  }
}

/// Where a launch goes first (owner decisions Q4, Q7): the pad only when the last
/// TV is found live, otherwise Home; and a connect that fails on the pad goes
/// back to Home.
void main() {
  /// The saved settings of a user who has seen the coach marks, which would else
  /// dim Home, and the look a run uses.
  Map<String, Object> saved(String look) => {'showTips': false, 'look.choice': look};

  /// What discovery holds when the app starts: [hostId] found live.
  DiscoveryState liveHost(String hostId) => DiscoveryState(
    running: true,
    everFound: true,
    hosts: [
      DiscoveredHost(
        address: HostAddress(addresses: const ['192.168.1.60'], port: 45780, hostId: hostId, name: 'Thumb Party TV'),
      ),
    ],
  );

  /// How many Homes are on screen, hidden ones under another route included.
  Finder homes() => find.byType(PhoneHomeScreen, skipOffstage: false);

  for (final look in ['sunny', 'night']) {
    for (final screen in [const Size(852, 393), const Size(393, 852)]) {
      final where = '$look look, ${screen.width.toInt()}x${screen.height.toInt()}';

      testWidgets('an unpaired launch opens Home, not Connect ($where)', (tester) async {
        await pumpApp(tester, saved: saved(look), screen: screen, toConnect: false);
        expect(find.text(HomeText.joinGame), findsOneWidget);
        expect(find.byType(ConnectScreen), findsNothing);
      });
    }
  }

  testWidgets('Join a Game on the launch Home opens Connect', (tester) async {
    await pumpApp(tester, saved: saved('sunny'), toConnect: false);
    expect(find.text(HomeText.joinGame), findsOneWidget, reason: 'the launch opens Home first');
    await reachConnect(tester);
    expect(find.byType(ConnectScreen), findsOneWidget);
  });

  testWidgets('Try without a screen on Connect closes Home too and shows the pad with the demo link', (tester) async {
    await pumpApp(tester, saved: saved('sunny'), toConnect: false);
    await reachConnect(tester);
    await tester.tap(find.byKey(const Key('tryWithoutTv')));
    await settle(tester);
    expect(find.byType(ConnectScreen), findsNothing);
    expect(homes(), findsNothing, reason: 'Home closes when the demo starts, as it does on a connection');
    expect(find.byType(ControllerScreen), findsOneWidget);
    expect(find.byKey(const Key('demoReadout')), findsOneWidget);
  });

  testWidgets('Back on the launch Home exits and never returns to the pad', (tester) async {
    final exit = _FakeExit();
    await pumpApp(
      tester,
      saved: saved('sunny'),
      toConnect: false,
      extra: [appExitProvider.overrideWithValue(exit.call)],
    );
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(exit.calls, 1, reason: 'Back asks the app to exit once');
    expect(find.byType(PhoneHomeScreen), findsOneWidget, reason: 'Home is not popped to the pad');
  });

  testWidgets('a paired launch with its host found live stays on the pad', (tester) async {
    await pumpApp(tester, paired: true, saved: saved('sunny'), discovered: liveHost('tv-1'));
    expect(find.byType(ControllerScreen), findsOneWidget);
    expect(homes(), findsNothing);
  });

  testWidgets('a paired launch whose host is gone while others are live shows Home', (tester) async {
    await pumpApp(tester, paired: true, saved: saved('sunny'), discovered: liveHost('other-tv'));
    // The launch's discovery wait ends on a timer, a frame after the first.
    await settle(tester);
    expect(find.text(HomeText.joinGame), findsOneWidget);
    expect(find.byType(ConnectScreen), findsNothing);
  });

  testWidgets('a connect that fails on the pad shows Home once, a second failure does not stack another', (
    tester,
  ) async {
    final app = await pumpApp(tester, paired: true, saved: saved('sunny'), discovered: liveHost('tv-1'));
    expect(homes(), findsNothing);

    app.client.emit(const ClientSnapshot(status: ClientStatus.connecting));
    await settle(tester);
    app.client.emit(const ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.unreachable));
    await settle(tester);
    expect(homes(), findsOneWidget, reason: 'the failed attempt returns to Home');

    app.client.emit(const ClientSnapshot(status: ClientStatus.connecting));
    await settle(tester);
    app.client.emit(const ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.unreachable));
    await settle(tester);
    expect(homes(), findsOneWidget, reason: 'Home is open already');
  });

  testWidgets('a link that dropped after connecting does not return to Home', (tester) async {
    // Positive control on its own app: a connect that fails without connecting does return to Home.
    final failing = await pumpApp(tester, paired: true, saved: saved('sunny'), discovered: liveHost('tv-1'));
    failing.client.emit(const ClientSnapshot(status: ClientStatus.connecting));
    await settle(tester);
    failing.client.emit(const ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.unreachable));
    await settle(tester);
    expect(homes(), findsOneWidget, reason: 'the failed attempt returns to Home');

    // The dropped run, on a separate app.
    final app = await pumpApp(tester, paired: true, saved: saved('sunny'), discovered: liveHost('tv-1'));
    app.client.emit(connected);
    await settle(tester);
    app.client.emit(const ClientSnapshot(status: ClientStatus.reconnecting));
    await settle(tester);
    app.client.emit(const ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.unreachable));
    await settle(tester);
    expect(homes(), findsNothing, reason: 'the waiting card handles a dropped link');
  });

  testWidgets('a connect that fails on the pad while this phone hosts does not open Home', (tester) async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-launch-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final app = await pumpApp(
      tester,
      paired: true,
      saved: saved('sunny'),
      discovered: liveHost('tv-1'),
      extra: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      ],
    );
    // "Show on this device": the phone hosts without a player of its own, so no link is needed.
    late PhoneHost host;
    await tester.runAsync(() async {
      host = hostContainer(tester).read(hostingProvider.notifier).start(playsHere: false);
    });
    try {
      expect(host.live, isTrue, reason: 'this phone is hosting');

      app.client.emit(const ClientSnapshot(status: ClientStatus.connecting));
      await settle(tester);
      app.client.emit(const ClientSnapshot(status: ClientStatus.failed, problem: ClientProblem.unreachable));
      await settle(tester);
      expect(homes(), findsNothing, reason: 'a hosting phone never gets Home');
    } finally {
      await tester.runAsync(host.dispose);
    }
  });

  testWidgets('the demo starts under the launch prompt: Home stays until the answer, then closes once', (tester) async {
    await pumpApp(
      tester,
      saved: saved('sunny'),
      toConnect: false,
      extra: [launchConsentAskProvider.overrideWithValue(true)],
    );
    expect(find.byKey(const Key('consentDialog')), findsOneWidget, reason: 'Home asks on its first frame');

    ProviderScope.containerOf(tester.element(homes())).read(demoProvider.notifier).start();
    await settle(tester);
    expect(homes(), findsOneWidget, reason: 'the prompt is still up, so Home waits for its answer');
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentNo')));
    await settle(tester);
    expect(homes(), findsNothing, reason: 'Home closes once after the answer');
    expect(find.byType(ControllerScreen), findsOneWidget, reason: 'the demo pad is shown');
    expect(find.byKey(const Key('demoReadout')), findsOneWidget);
  });

  testWidgets('the demo starts while this phone hosts live: Home stays open', (tester) async {
    final dir = Directory.systemTemp.createTempSync('thumb-party-launch-');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpApp(
      tester,
      paired: true,
      saved: saved('sunny'),
      extra: [
        ...phoneHostOverrides(directories: TempHostDirectories(dir)),
        party.advertiserProvider.overrideWithValue(party_test.FakeAdvertiser()),
        party.soundPlayerProvider.overrideWithValue(party_test.FakeSoundPlayer()),
        party.screenAwakeProvider.overrideWithValue(party_test.FakeScreenAwake()),
      ],
    );
    late PhoneHost host;
    await tester.runAsync(() async {
      host = hostContainer(tester).read(hostingProvider.notifier).start(playsHere: false);
    });
    try {
      expect(host.live, isTrue, reason: 'this phone is hosting');

      // Home opened over the pad while the phone hosts: its launch prompt is not up.
      unawaited(
        Navigator.of(tester.element(find.byType(ControllerScreen, skipOffstage: false).first))
            .push(MaterialPageRoute<void>(builder: (_) => const PhoneHomeScreen(fromLaunch: false))),
      );
      await settle(tester);
      expect(homes(), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(homes()));
      container.read(demoProvider.notifier).start();
      await settle(tester);
      expect(container.read(demoProvider), isTrue, reason: 'the demo is running');
      expect(homes(), findsOneWidget, reason: 'a live host keeps Home open when the demo starts');
    } finally {
      await tester.runAsync(host.dispose);
    }
  });
}
