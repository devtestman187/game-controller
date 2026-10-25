import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tvtest/main.dart';
import 'package:tvtest/src/host_controller.dart';
import 'package:tvtest/src/providers.dart';
import 'package:tvtest/src/screen_awake.dart';
import 'package:tvtest/src/sound.dart';
import 'package:tvtest/src/ui/game_screen.dart';
import 'package:tvtest/src/ui/haptic_panel_screen.dart';
import 'package:tvtest/src/ui/input_visualizer.dart';
import 'package:tvtest/src/ui/latency_screen.dart';
import 'package:tvtest/src/ui/tv_button.dart';

class FakeHostController implements HostController {
  FakeHostController(this.state);

  @override
  HostViewState state;
  final _changes = StreamController<HostViewState>.broadcast();
  int newCodes = 0;
  int simToggles = 0;
  int drops = 0;

  @override
  Stream<HostViewState> get changes => _changes.stream;

  void emit() => _changes.add(state);

  @override
  void newPairingCode() => newCodes++;

  @override
  void toggleSimulatedController() => simToggles++;

  @override
  void dropAllConnections() => drops++;

  final haptics = <(HapticEventMessage, String?)>[];

  @override
  int sendHaptic(HapticEventMessage message, {String? controllerId}) {
    haptics.add((message, controllerId));
    return controllerId != null ? 1 : state.host.connected.length;
  }

  int forgets = 0;
  int exports = 0;

  @override
  int forgetPairings() {
    forgets++;
    return 1;
  }

  @override
  Future<String> exportLog() async {
    exports++;
    return 'D:/logs/controller-test-log.txt';
  }

  @override
  Future<void> dispose() => _changes.close();
}

HostViewState sampleState() => HostViewState(
  hostName: 'Android TV',
  host: HostSnapshot(
    running: true,
    port: 45780,
    pairingCode: '0427',
    controllers: [
      ControllerInfo(
        controllerId: 'p1',
        name: 'iPhone 3F1C',
        platform: 'ios',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.20',
        state: ControllerState.connected,
        since: DateTime(2026),
        rttMs: 12,
        rttStats: const RttSummary(minMs: 8, avgMs: 20, maxMs: 140, samples: 30, p95Ms: 60),
        input: InputStateMessage(seq: 3, buttons: {ControllerButton.a}, dx: 1),
        player: 1,
        inputLatency: const RttSummary(minMs: 3, avgMs: 9, maxMs: 41, samples: 900, p95Ms: 18),
        inputLatencySession: const RttSummary(minMs: 2, avgMs: 10, maxMs: 80, samples: 5400),
        latencyErrorMs: 4,
      ),
      ControllerInfo(
        controllerId: 'p2',
        name: 'Pixel',
        platform: 'android',
        appVersion: '0.1.0',
        remoteAddress: '192.168.1.21',
        state: ControllerState.pairing,
        since: DateTime(2026),
      ),
    ],
  ),
  addresses: const [LocalAddress('192.168.1.50', 'wlan0')],
  advertise: AdvertiseState.advertising,
  advertisedName: 'Controller Test (Android TV)',
);

late FakeSoundPlayer sounds;
late FakeScreenAwake awake;

class FakeScreenAwake implements ScreenAwake {
  final calls = <bool>[];

  bool get on => calls.isNotEmpty && calls.last;

  @override
  Future<void> set(bool on) async => calls.add(on);
}

/// Scrolls a button into view first: the pairing panel scrolls at TV size.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<FakeHostController> pumpApp(WidgetTester tester, {Size size = const Size(960, 540)}) async {
  sounds = FakeSoundPlayer();
  awake = FakeScreenAwake();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeHostController(sampleState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostControllerProvider.overrideWithValue(fake),
        soundPlayerProvider.overrideWithValue(sounds),
        screenAwakeProvider.overrideWithValue(awake),
      ],
      child: const TvTestApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows the pairing code, address and controllers with ping', (tester) async {
    await pumpApp(tester);
    expect(find.text('0 4 2 7'), findsOneWidget);
    expect(find.textContaining('192.168.1.50:45780'), findsOneWidget);
    expect(find.textContaining('Controller Test (Android TV)'), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('Waiting for code'), findsOneWidget);
    expect(find.text('Controllers · 1 connected'), findsOneWidget);
    expect(find.text('avg 20 ms'), findsOneWidget);
    expect(find.text('max 140 ms'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p1')));
    expect(shown.input?.buttons, {ControllerButton.a});
    expect(shown.input?.dx, 1);
    // A controller still pairing shows nothing pressed.
    expect(tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p2'))).input, isNull);
  });

  testWidgets('the remote reaches and presses every button', (tester) async {
    final fake = await pumpApp(tester);
    String? focused() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvButton>()?.label;

    final pressed = <String>{};
    final opened = <Type>[];
    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }

    // Presses OK on the focused button. A new screen is closed again with Esc
    // (Back on the remote), which returns focus to the button.
    Future<void> pressFocused() async {
      final label = focused();
      if (label == null || !pressed.add(label)) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      // The game animates every frame, so pump through the page transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final screen in [GameScreen, HapticPanelScreen, LatencyScreen]) {
        if (find.byType(screen).evaluate().isNotEmpty) {
          opened.add(screen);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      await tester.pumpAndSettle();
    }

    // "New code" is focused on launch. Find every button the arrows reach:
    // from each one found, try all four arrows (going back to it by focusing
    // it directly before each try). Then press each one with OK.
    void focusButton(String label) => Focus.of(
      tester.element(find.descendant(of: find.widgetWithText(TvButton, label), matching: find.text(label))),
    ).requestFocus();
    const directions = [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
    ];
    final reached = <String>{focused()!};
    final queue = [focused()!];
    while (queue.isNotEmpty) {
      final from = queue.removeLast();
      for (final d in directions) {
        focusButton(from);
        await tester.pump();
        await key(d);
        final to = focused();
        if (to != null && reached.add(to)) queue.add(to);
      }
    }
    for (final label in reached) {
      focusButton(label);
      await tester.pump();
      await pressFocused();
    }

    expect(pressed, {
      'New code',
      'Simulate controller',
      'Drop connections',
      'Forget phones',
      'Save log',
      'Test game',
      'Haptic test',
      'Latency',
    });
    expect([fake.newCodes, fake.simToggles, fake.drops, fake.forgets, fake.exports], [1, 1, 1, 1, 1]);
    expect(opened.toSet(), {GameScreen, HapticPanelScreen, LatencyScreen});
  });

  testWidgets('updates when the host state changes', (tester) async {
    final fake = await pumpApp(tester);
    final s = fake.state;
    fake.state = HostViewState(
      hostName: s.hostName,
      host: HostSnapshot(running: true, port: 45780, pairingCode: '9001', controllers: const []),
      addresses: s.addresses,
      advertise: AdvertiseState.failed,
      advertiseError: 'mDNS unavailable',
    );
    fake._changes.add(fake.state);
    await tester.pumpAndSettle();
    expect(find.text('9 0 0 1'), findsOneWidget);
    expect(find.textContaining('No controllers yet'), findsOneWidget);
    expect(find.textContaining('mDNS unavailable'), findsOneWidget);
  });

  testWidgets('shows gyro tilt as numbers and a stick', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '0427',
        controllers: [
          ControllerInfo(
            controllerId: 'g1',
            name: 'iPhone 3F1C',
            platform: 'ios',
            appVersion: '0.3.0',
            remoteAddress: '192.168.1.20',
            state: ControllerState.connected,
            since: DateTime(2026),
            rttMs: 8,
            input: InputStateMessage(seq: 9, buttons: {ControllerButton.b}, ax: 0.25, ay: -0.5),
          ),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(find.text('Tilt x 0.25  y -0.50'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-g1')));
    expect([shown.input?.ax, shown.input?.ay], [0.25, -0.5]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows both sticks and the shoulder buttons in stick mode', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '0427',
        controllers: [
          ControllerInfo(
            controllerId: 's1',
            name: 'iPhone 3F1C',
            platform: 'ios',
            appVersion: '0.4.0',
            remoteAddress: '192.168.1.20',
            state: ControllerState.connected,
            since: DateTime(2026),
            rttMs: 8,
            input: InputStateMessage(
              seq: 4,
              buttons: {ControllerButton.lb, ControllerButton.a},
              lx: -0.5,
              ly: 0.25,
              rx: 1,
              ry: 0,
            ),
          ),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(find.text('L -0.50, 0.25   R 1.00, 0.00'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-s1')));
    expect(shown.input?.hasSticks, isTrue);
    expect(shown.input?.buttons, {ControllerButton.lb, ControllerButton.a});
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small laptop window without overflow', (tester) async {
    await pumpApp(tester, size: const Size(600, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('0 4 2 7'), findsOneWidget);
  });

  testWidgets('fits a 1080p TV (960 x 540 logical pixels) without overflow', (tester) async {
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Center), findsWidgets);
  });

  testWidgets('shows that the four event sounds loaded', (tester) async {
    await pumpApp(tester);
    expect(find.text('4 of 4 event sounds loaded (fake)'), findsOneWidget);
  });

  group('haptic test panel', () {
    Future<FakeHostController> openPanel(WidgetTester tester) async {
      final fake = await pumpApp(tester);
      await tapVisible(tester, find.text('Haptic test'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('each button sends its event to the connected controllers and plays its sound', (tester) async {
      final fake = await openPanel(tester);
      expect(find.text('Sends to iPhone 3F1C'), findsOneWidget);
      for (final e in HapticEvent.values) {
        await tester.tap(find.byKey(Key('fire-${e.name}')));
        await tester.pump();
      }
      expect(fake.haptics.map((h) => h.$1), [for (final e in HapticEvent.values) HapticEventMessage(event: e)]);
      expect(fake.haptics.every((h) => h.$2 == null), isTrue, reason: 'to every connected controller');
      expect(sounds.played, HapticEvent.values);
      expect(find.text('Last: rumble, 100%, 400 ms (panel) → 1 controller'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('intensity and duration steppers change what is sent', (tester) async {
      final fake = await openPanel(tester);
      await tester.tap(find.byTooltip('Less Intensity'));
      await tester.tap(find.byTooltip('Less Intensity'));
      await tester.tap(find.byTooltip('More Duration'));
      await tester.tap(find.byTooltip('More Duration'));
      await tester.pump();
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('200 ms'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fire-error')));
      await tester.pump();
      expect(fake.haptics.single.$1, HapticEventMessage(event: HapticEvent.error, intensity: 0.8, durationMs: 200));

      // The limits hold, and the buttons stay usable there.
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip('More Intensity'));
        await tester.tap(find.byTooltip('Less Duration'));
      }
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Natural'), findsOneWidget);
    });

    testWidgets('works with the remote: Hit has focus and OK fires it', (tester) async {
      final fake = await openPanel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(fake.haptics.single.$1.event, HapticEvent.hit);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(fake.haptics.last.$1.event, HapticEvent.success);
    });

    testWidgets('without a controller the sounds still play', (tester) async {
      final fake = await pumpApp(tester);
      fake.state = HostViewState(
        hostName: 'Android TV',
        host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: const []),
      );
      fake.emit();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Haptic test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No controller connected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fire-hit')));
      await tester.pump();
      expect(sounds.played, [HapticEvent.hit]);
      expect(find.textContaining('→ no controller'), findsOneWidget);
    });
  });

  group('test game', () {
    Future<void> frames(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<FakeHostController> openGame(WidgetTester tester, {Size size = const Size(960, 540)}) async {
      final fake = await pumpApp(tester, size: size);
      await tapVisible(tester, find.text('Test game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
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
      expect(sounds.played.take(2), [HapticEvent.rumble, HapticEvent.hit]);
      expect(find.text('Dashes 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OK or D shows the debug overlay, and again hides it', (tester) async {
      await openGame(tester);
      expect(find.byKey(const Key('debugOverlay')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await frames(tester, 5);
      expect(find.byKey(const Key('debugOverlay')), findsOneWidget);
      expect(find.text('iPhone 3F1C (ios 0.1.0), Connected'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.textContaining('12 ms'), findsOneWidget);
      expect(find.text('~9 ms avg (± 4 ms)'), findsOneWidget);
      expect(find.text('D-pad'), findsOneWidget);
      expect(find.text('D-pad 1, 0'), findsOneWidget);
      expect(find.textContaining('rumble (game: dash, P1)'), findsOneWidget);
      expect(find.text('4 of 4 loaded'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await frames(tester, 2);
      expect(find.byKey(const Key('debugOverlay')), findsNothing);
    });

    testWidgets('Escape goes back to the main screen', (tester) async {
      await openGame(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('0 4 2 7'), findsOneWidget);
    });

    testWidgets('fills a small laptop window without overflow', (tester) async {
      await openGame(tester, size: const Size(600, 800));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await frames(tester, 10);
      expect(tester.takeException(), isNull);
    });
  });

  group('several controllers (M6)', () {
    ControllerInfo c(String id, int? player, {InputStateMessage? input, String name = 'Phone'}) => ControllerInfo(
      controllerId: id,
      name: '$name $id',
      platform: 'ios',
      appVersion: '0.6.0',
      remoteAddress: '192.168.1.2$player',
      state: player == null ? ControllerState.disconnected : ControllerState.connected,
      since: DateTime(2026),
      rttMs: 10,
      player: player,
      input: input,
    );
    HostViewState s(List<ControllerInfo> list) => HostViewState(
      hostName: 'TV',
      host: HostSnapshot(running: true, port: 45780, pairingCode: '1234', controllers: list),
    );

    test('players are the connected controllers in player order, each with its colour', () {
      final state = s([c('b', 2), c('gone', null), c('a', 1)]);
      expect(state.players.map((p) => p.controllerId), ['a', 'b']);
      final feeds = playerFeeds(state);
      expect(feeds.map((f) => (f.id, f.number)), [('a', 1), ('b', 2)]);
      expect(feeds.map((f) => f.color), [Color(playerColors[0]), Color(playerColors[1])]);
    });

    testWidgets('each controller drives its own sprite, and feels only its own events', (tester) async {
      final fake = await pumpApp(tester);
      // Player 1 dashes, player 2 walks left into the edge of the field.
      fake.state = s([
        c('a', 1, input: InputStateMessage(seq: 1, buttons: {ControllerButton.a})),
        c('b', 2, input: InputStateMessage(seq: 1, dx: -1)),
      ]);
      fake.emit();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-a')), findsOneWidget);
      expect(find.byKey(const Key('player-b')), findsOneWidget);
      await tapVisible(tester, find.text('Test game'));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final sent = fake.haptics.map((h) => (h.$1.event, h.$2)).toList();
      expect(sent.where((e) => e.$2 == 'a').map((e) => e.$1).first, HapticEvent.rumble);
      expect(sent.where((e) => e.$2 == 'b').map((e) => e.$1), contains(HapticEvent.hit));
      expect(sent.where((e) => e.$2 == null), isEmpty, reason: 'game events never go to everyone');
      expect(find.text('P1 Phone a'), findsOneWidget);
      expect(find.text('P2 Phone b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('latency and the log (M6)', () {
    testWidgets('the screen stays on while a controller is connected, and may sleep after', (tester) async {
      final fake = await pumpApp(tester);
      expect(awake.on, isTrue, reason: 'the sample state has one connected controller');
      fake.state = HostViewState(
        hostName: 'Android TV',
        host: HostSnapshot(running: true, port: 45780, pairingCode: '0427', controllers: const []),
      );
      fake.emit();
      await tester.pumpAndSettle();
      expect(awake.on, isFalse);
      expect(awake.calls, [true, false]);
    });

    testWidgets('the main screen shows the player badge and the input delay', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('player-p1')), findsOneWidget);
      expect(find.text('input ~9 ms'), findsOneWidget);
    });

    testWidgets('the latency screen shows ping and input delay against the target', (tester) async {
      final fake = await pumpApp(tester);
      await tapVisible(tester, find.text('Latency'));
      await tester.pumpAndSettle();
      expect(find.byType(LatencyScreen), findsOneWidget);
      expect(find.text('iPhone 3F1C'), findsOneWidget);
      expect(find.text('Within the 50 ms target'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('inputDelay-p1'))).data, '9 ms');
      expect(find.text('p95 18 · max 41 ms · ± 4 ms'), findsOneWidget);
      expect(find.text('10 ms'), findsOneWidget, reason: 'session average');
      expect(find.text('min 8 · p95 60 · max 140 ms'), findsOneWidget);
      // Save log is focused: OK saves and says where.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fake.exports, 1);
      expect(find.textContaining('Log saved to D:/logs/controller-test-log.txt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the latency screen fits a small window', (tester) async {
      await pumpApp(tester, size: const Size(600, 800));
      await tapVisible(tester, find.text('Latency'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('the exported log starts with each controller\'s latency, then every line', () {
      final log = LogBuffer()
        ..add('host', 'Listening on port 45780')
        ..add('host', 'iPhone 3F1C connected');
      final text = buildLogExport(sampleState(), log, now: DateTime(2026, 10, 25, 20, 15));
      expect(text, startsWith('Controller Test '));
      expect(text, contains('2026-10-25T20:15:00.000'));
      expect(text, contains('P1 iPhone 3F1C (ios 0.1.0), connected'));
      expect(text, contains('Ping: min 8 · avg 20 · max 140 ms, p95 60 ms'));
      expect(
        text,
        contains(
          'Input delay (estimated, one way): avg 9 · p95 18 · max 41 ms (± 4 ms); session avg 10 ms over 5400 states',
        ),
      );
      expect(text, contains('Pixel (android 0.1.0), pairing'));
      expect(text, contains('[host] iPhone 3F1C connected'));
    });

    test('pairings are saved and loaded; broken data is ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(loadPairings(prefs), isEmpty);
      savePairings(prefs, const [
        SavedPairing(controllerId: 'p1', token: 'tok', name: 'iPhone 3F1C', platform: 'ios', appVersion: '0.6.0'),
      ]);
      expect(loadPairings(prefs).single.token, 'tok');
      await prefs.setString('pairings', '[{"id": "x"}, 5, {"id": "p2", "token": "t2"}]');
      expect(loadPairings(prefs).map((p) => p.controllerId), ['p2']);
      await prefs.setString('pairings', 'not json');
      expect(loadPairings(prefs), isEmpty);
    });
  });
}
