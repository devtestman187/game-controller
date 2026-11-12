import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metrics/metrics.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

/// The app a script drives: the shared shell and gate over the harness's home,
/// so `POST game/start` has a navigator to push the round on and `GET
/// screenshot` a frame to take (M15 a2).
Future<FakeHostService> pumpAutomation(WidgetTester tester) => pumpHost(
  tester,
  screen: const AutomationShell(child: AutomationGate(child: StubHome())),
  overrides: [
    // Every host app supplies its own identity; `status` reports it (M15 a2).
    hostIdentityProvider.overrideWithValue(
      const HostIdentity(
        appVersion: '0.1.0',
        versionLabel: '0.1.0',
        hostType: 'tv',
        kind: 'tv',
        hostOs: 'android',
        defaultHostName: 'Android TV',
        serviceName: '_thumbparty._tcp',
      ),
    ),
  ],
);

/// The host's container, as the app has it.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AutomationGate)));

/// The interface's own actions, as the server calls them.
AutomationApi apiOf(WidgetTester tester) => containerOf(tester).read(automationServerProvider).api;

/// The id of the first simulated player the interface added.
String playerId(FakeHostService fake) => fake.gameHost.players.firstWhere((p) => p.scripted).id;

/// A press through the interface, and its release a frame later.
Future<void> scriptPress(WidgetTester tester, AutomationApi api, String id, String button) async {
  await scriptHold(tester, api, id, {
    'buttons': [button],
  });
}

/// A D-pad push through the interface, and its release a frame later.
Future<void> scriptMove(WidgetTester tester, AutomationApi api, String id, {int dx = 0, int dy = 0}) async {
  await scriptHold(tester, api, id, {'dx': dx, 'dy': dy});
}

/// [input] for the player, held for the two frames the menus read it in, then
/// let go.
Future<void> scriptHold(WidgetTester tester, AutomationApi api, String id, Map<String, Object?> input) async {
  api.input({'player': id, ...input});
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
  api.input({'player': id, 'buttons': const []});
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('status reports the host, the pairing code, the port and the players', (tester) async {
    final fake = await pumpAutomation(tester);
    final api = apiOf(tester);
    expect(fake.state.host.port, 45780);
    final status = api.status();
    expect(status['screen'], 'home', reason: 'no round was started');
    expect(status['ready'], isTrue, reason: 'the host runs and no round is up');
    expect(status['pairingCode'], '0427');
    expect(status['port'], 45780, reason: 'the controller port, as the host state has it');
    expect(status['players'], hasLength(1), reason: 'the harness\'s phone is in the roster');
    expect((status['players']! as List<Object?>).single, containsPair('id', 'p1'));

    api.players({
      'nickname': 'Robo',
      'character': {'colour': 3, 'accessory': 'cap'},
    });
    await tester.pump();
    final after = api.status();
    final players = after['players']! as List<Object?>;
    expect(players, hasLength(2));
    expect(players.last, containsPair('nickname', 'Robo'));
    expect(players.last, containsPair('simulated', true), reason: 'a script drives it, not a person');
  });

  testWidgets('an added player is the menus\' kind of player, and a script drives it', (tester) async {
    final fake = await pumpAutomation(tester);
    final api = apiOf(tester);
    api.players({});
    await tester.pump();
    final added = fake.gameHost.players.firstWhere((p) => p.scripted);
    expect(added.local, isTrue, reason: 'it lives on the host, as a joined phone\'s player does');
    expect(fake.gameHost.players.where((p) => p.scripted), hasLength(1));
  });

  testWidgets('input drives a menu: the scripted player walks the picker and starts a game', (tester) async {
    await pumpAutomation(tester);
    final api = apiOf(tester);
    final player = api.players({})['player']! as Map<String, Object?>;
    final id = player['id']! as String;
    // A player the menus see for the first time counts as holding what it
    // holds, so it starts with its hands off.
    api.input({'player': id, 'buttons': const []});
    await tester.pump(const Duration(milliseconds: 32));

    // A pad press brings the focus to Play, and A opens the picker, as a
    // thumb would.
    await scriptMove(tester, api, id, dy: 1);
    await tester.pump(const Duration(milliseconds: 100));
    await scriptPress(tester, api, id, 'a');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('pickArena')), findsOneWidget, reason: 'the picker is up');

    // The night card has the focus; left walks to the Arena, and A picks it.
    await scriptMove(tester, api, id, dx: -1);
    await scriptPress(tester, api, id, 'a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget, reason: 'the Arena\'s waiting card is up');
  });

  testWidgets('game/start opens the round and game/stop comes home', (tester) async {
    await pumpAutomation(tester);
    final api = apiOf(tester);
    final started = api.startGame({'game': 'arena', 'mode': 'bumper', 'level': 'easy'});
    expect(started['round'], containsPair('game', 'arena'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget, reason: 'the round\'s screen is pushed on the app\'s navigator');
    expect(api.status()['screen'], 'game');
    expect(api.status()['ready'], isFalse, reason: 'a round is up');

    api.stopGame();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(StubHome), findsOneWidget, reason: 'the host is home again');
  });

  testWidgets('state reports the round, the latest frame and the last result', (tester) async {
    final fake = await pumpAutomation(tester);
    final api = apiOf(tester);
    expect(api.state(), {'round': null, 'frame': null, 'result': null});

    fake.gameHost.frames.add(FrameMessage(n: 7, atMs: 420, snapshot: const {'x': 1}));
    api.startGame({'game': 'arena'});
    await tester.pump();
    final state = api.state();
    expect(state['round'], containsPair('game', 'arena'));
    final frame = state['frame']! as Map<String, Object?>;
    expect(frame['n'], 7, reason: 'the newest frame the game published');
    expect(frame['atMs'], 420);
    api.stopGame();
    await tester.pump();
  });

  testWidgets('probe/flash shows the card, and a press is timed from the host\'s clock', (tester) async {
    final fake = await pumpAutomation(tester);
    final api = apiOf(tester);
    final id = (api.players({})['player']! as Map<String, Object?>)['id']! as String;
    await tester.pump();

    api.flashProbe(on: true);
    await tester.pump();
    expect(find.byType(LatencyTestCard), findsOneWidget, reason: 'the card covers the screen');
    expect(find.textContaining('flip 0'), findsOneWidget);

    fake.gameHost.clockMs = 5000;
    final press = api.pressProbe({'player': id, 'button': 'a'});
    expect(press['hostMs'], 5000, reason: 'the host clock when the input landed');
    expect(press['button'], 'a');
    expect(fake.gameHost.gamepad(id).buttons, {GamepadButton.a}, reason: 'the press is in the game host');

    await tester.pump();
    expect(find.textContaining('flip 1'), findsOneWidget, reason: 'the press flips the card (M15 c2)');
    await tester.pump(const Duration(milliseconds: LatencyTestCard.flipMs));
    expect(find.textContaining('flip 2'), findsOneWidget, reason: 'and the card keeps its own cadence');
    api.flashProbe(on: false);
    await tester.pump();
    expect(find.byType(LatencyTestCard), findsNothing);
  });

  testWidgets('stats/stream lands in the live session, and stats/session reads it back', (tester) async {
    final fake = await pumpAutomation(tester);
    final live = SessionCollector(
      id: 's1',
      hostType: 'tv',
      hostApp: '0.1.0',
      startedAt: DateTime(2026, 11, 11),
      startMs: 0,
    );
    fake.stats.live = live;
    final api = apiOf(tester);
    expect(api.session()['running'], isTrue);

    final ingested = api.ingestStream({
      'viewer': {'kind': StreamKind.browser, 'platform': 'android'},
      'stages': [
        {'name': 'input', 'ms': 40},
      ],
    });
    expect(ingested['viewer'], isNotEmpty);
    final session = api.session()['session']! as Map<String, Object?>;
    final stream = session['stream']! as Map<String, Object?>;
    final viewers = stream['viewers']! as List<Object?>;
    expect(viewers, hasLength(1));
    expect(viewers.single, allOf(containsPair('kind', StreamKind.browser), containsPair('platform', 'android')));
    fake.stats.live = null;
    expect(api.session()['running'], isFalse, reason: 'no session between rounds');
  });

  testWidgets('screenshot takes the app\'s frame as a PNG', (tester) async {
    await pumpAutomation(tester);
    final api = apiOf(tester);
    final png = await tester.runAsync(api.screenshotPng);
    expect(png, isNotNull);
    expect(png!.take(4), [0x89, 0x50, 0x4E, 0x47], reason: 'PNG magic: 89 50 4E 47');
  });

  testWidgets('a host with no frame says so instead of drawing one', (tester) async {
    // The frame is only there where the shell is: this test takes the picture
    // the interface would, with no shell around it.
    final none = await ScreenFrames().capturePng();
    expect(none, isNull, reason: 'nothing is drawn, so there is no picture');
  });
}
