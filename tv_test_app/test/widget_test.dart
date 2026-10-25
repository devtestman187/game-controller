import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';
import 'package:tvtest/main.dart';
import 'package:tvtest/src/host_controller.dart';
import 'package:tvtest/src/providers.dart';
import 'package:tvtest/src/sound.dart';
import 'package:tvtest/src/ui/game_screen.dart';
import 'package:tvtest/src/ui/haptic_panel_screen.dart';
import 'package:tvtest/src/ui/input_visualizer.dart';
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
        rttStats: const RttSummary(minMs: 8, avgMs: 20, maxMs: 140, samples: 30),
        input: InputStateMessage(seq: 3, buttons: {ControllerButton.a}, dx: 1),
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

/// Scrolls a button into view first: the pairing panel scrolls at TV size.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<FakeHostController> pumpApp(WidgetTester tester, {Size size = const Size(960, 540)}) async {
  sounds = FakeSoundPlayer();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = FakeHostController(sampleState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hostControllerProvider.overrideWithValue(fake), soundPlayerProvider.overrideWithValue(sounds)],
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
    expect(find.text('1 connected'), findsOneWidget);
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
      for (final screen in [GameScreen, HapticPanelScreen]) {
        if (find.byType(screen).evaluate().isNotEmpty) {
          opened.add(screen);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      await tester.pumpAndSettle();
    }

    // "New code" is focused on launch. Walk the pairing panel's buttons with
    // Down, or Right when Down doesn't move (they share rows on wide screens).
    const header = {'Test game', 'Haptic test'};
    for (var i = 0; i < 8 && pressed.length < 3; i++) {
      final label = focused();
      if (!header.contains(label)) await pressFocused();
      await key(LogicalKeyboardKey.arrowDown);
      if (focused() == label) await key(LogicalKeyboardKey.arrowRight);
    }
    // Up reaches the two buttons in the header, then Right or Left the other.
    for (var i = 0; i < 8 && !header.contains(focused()); i++) {
      await key(LogicalKeyboardKey.arrowUp);
    }
    final first = focused();
    await pressFocused();
    await key(LogicalKeyboardKey.arrowRight);
    if (focused() == first) await key(LogicalKeyboardKey.arrowLeft);
    await pressFocused();

    expect(pressed, {'New code', 'Simulate controller', 'Drop connections', 'Test game', 'Haptic test'});
    expect([fake.newCodes, fake.simToggles, fake.drops], [1, 1, 1]);
    expect(opened.toSet(), {GameScreen, HapticPanelScreen});
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
      expect(find.text('iPhone 3F1C (ios 0.1.0)'), findsOneWidget);
      expect(find.textContaining('12 ms'), findsOneWidget);
      expect(find.text('D-pad'), findsOneWidget);
      expect(find.text('D-pad 1, 0'), findsOneWidget);
      expect(find.textContaining('rumble (game: dash)'), findsOneWidget);
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

  test('the game follows the controller used last, or the first connected one', () {
    ControllerInfo c(String id, ControllerState state) => ControllerInfo(
      controllerId: id,
      name: id,
      platform: 'test',
      appVersion: 't',
      remoteAddress: '1',
      state: state,
      since: DateTime(2026),
    );
    HostViewState s(List<ControllerInfo> list, String? active) => HostViewState(
      hostName: 'TV',
      host: HostSnapshot(running: true, pairingCode: '1', controllers: list),
      activeControllerId: active,
    );
    final a = c('a', ControllerState.connected);
    final b = c('b', ControllerState.connected);
    expect(s([a, b], null).driver?.controllerId, 'a');
    expect(s([a, b], 'b').driver?.controllerId, 'b');
    expect(s([a, c('b', ControllerState.disconnected)], 'b').driver?.controllerId, 'a');
    expect(s([], 'b').driver, isNull);
  });
}
