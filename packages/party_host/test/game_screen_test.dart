import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:game_kit/game_kit.dart';
import 'package:party_host/party_host.dart';
import 'package:party_host/testing.dart';
import 'package:protocol/protocol.dart';

import 'support/host_harness.dart';

void main() {
  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<FakeHostService> openGame(WidgetTester tester, {Size size = const Size(960, 540)}) async {
    final fake = await pumpHost(tester, screen: const StubHome(), size: size);
    await openArena(tester);
    return fake;
  }

  testWidgets('the connected controller drives it; events go to it with their sounds', (tester) async {
    // The sample controller holds A and right: it dashes at once, then
    // walks into the first wall.
    final fake = await openGame(tester);
    await frames(tester, 90);
    final sent = fake.haptics.map((h) => (h.$1.event, h.$2)).toList();
    expect(sent.first, (HapticEvent.rumble, 'p1'));
    expect(sent, contains((HapticEvent.hit, 'p1')));
    expect(sounds.played.take(2), ['rumble', 'hit']);
    expect(find.text('Dashes 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OK or D shows the debug overlay, and again hides it', (tester) async {
    await openGame(tester);
    expect(find.byKey(const Key('debugOverlay')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await frames(tester, 5);
    expect(find.byKey(const Key('debugOverlay')), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.textContaining('12 ms'), findsOneWidget);
    expect(find.text('~9 ms avg (± 4 ms)'), findsOneWidget);
    expect(find.text('D-pad'), findsOneWidget);
    expect(find.text('D-pad 1, 0'), findsOneWidget);
    expect(find.textContaining('rumble (game: dash, P1)'), findsOneWidget);
    expect(find.text('${SoundKey.values.length} of ${SoundKey.values.length} loaded'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await frames(tester, 2);
    expect(find.byKey(const Key('debugOverlay')), findsNothing);
  });

  testWidgets('Escape goes back to the game picker, and again to the main screen', (tester) async {
    await openGame(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('fills a small laptop window without overflow', (tester) async {
    await openGame(tester, size: const Size(600, 800));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await frames(tester, 10);
    expect(tester.takeException(), isNull);
  });

  // M6: several controllers, each with its own sprite and its own events.
  testWidgets('each controller drives its own sprite, and feels only its own events', (tester) async {
    ControllerInfo c(String id, int player, {InputStateMessage? input}) => ControllerInfo(
      controllerId: id,
      name: 'Phone $id',
      platform: 'ios',
      appVersion: '0.6.0',
      remoteAddress: '192.168.1.2$player',
      state: ControllerState.connected,
      since: DateTime(2026),
      rttMs: 10,
      player: player,
      input: input,
    );
    final fake = await pumpHost(tester, screen: const StubHome());
    // Player 1 dashes, player 2 walks left into the edge of the field.
    fake.state = HostViewState(
      hostName: 'TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '1234',
        controllers: [
          c('a', 1, input: InputStateMessage(seq: 1, buttons: {ControllerButton.a})),
          c('b', 2, input: InputStateMessage(seq: 1, dx: -1)),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(fake.gameHost.players.map((p) => (p.id, p.number)), [('a', 1), ('b', 2)]);
    await openArena(tester);
    expect(find.byKey(const Key('hud-a')), findsOneWidget);
    expect(find.byKey(const Key('hud-b')), findsOneWidget);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final sent = fake.haptics.map((h) => (h.$1.event, h.$2)).toList();
    expect(sent.where((e) => e.$2 == 'a').map((e) => e.$1).first, HapticEvent.rumble);
    expect(sent.where((e) => e.$2 == 'b').map((e) => e.$1), contains(HapticEvent.hit));
    expect(sent.map((e) => e.$2).toSet(), {'a', 'b'}, reason: 'game events go to their own player only');
    expect(find.text('P1 Phone a'), findsOneWidget);
    expect(find.text('P2 Phone b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the arena reports its rounds and events to the game host', (tester) async {
    final fake = await pumpHost(tester, screen: const StubHome());
    await openArena(tester);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final names = fake.gameHost.records.map((r) => r.name).toSet();
    expect(names, containsAll(['round_start', 'dash', 'wall_hit']));
  });

  testWidgets('the round runs at the rate the hosting settings ask for', (tester) async {
    final fake = await pumpHost(
      tester,
      screen: const StubHome(),
      overrides: [hostingSettingsProvider.overrideWithValue(const HostingSettings(frameRateHz: 20))],
    );
    await openArena(tester);
    await frames(tester, 10);
    final start = fake.gameHost.records.firstWhere((r) => r.name == 'round_start');
    expect(start.data['hz'], 20);
  });
}
