import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';
import 'package:protocol/protocol.dart';
import 'package:tvtest/src/ui/haptic_panel_screen.dart';
import 'package:tvtest/src/ui/input_visualizer.dart';
import 'package:tvtest/src/ui/latency_screen.dart';
import 'package:tvtest/src/ui/shader_spike_screen.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('shows the pairing code, address and controllers with ping', (tester) async {
    await pumpApp(tester);
    expect(find.text('0 4 2 7'), findsOneWidget);
    expect(find.textContaining('192.168.1.50:45780'), findsOneWidget);
    expect(find.textContaining('Thumb Party TV (Android TV)'), findsOneWidget);
    expect(find.text('iPhone 3F1C'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('Waiting for code'), findsOneWidget);
    expect(
      find.textContaining('devtestman187.github.io/game-controller'),
      findsOneWidget,
      reason: 'guide and privacy link',
    );
    expect(find.textContaining('Version 0.'), findsOneWidget, reason: 'testers can say which build they have');
    expect(find.text('Controllers · 1 connected'), findsOneWidget);
    expect(find.text('avg 20 ms'), findsOneWidget);
    expect(find.text('max 140 ms'), findsOneWidget);
    final shown = tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p1')));
    expect(shown.gamepad?.buttons, {GamepadButton.a, GamepadButton.dpadRight});
    expect(shown.gamepad?.dpadX, 1);
    // A controller still pairing shows nothing pressed.
    expect(tester.widget<InputVisualizer>(find.byKey(const Key('visualizer-p2'))).gamepad, isNull);
  });

  testWidgets('the remote reaches and presses every button', (tester) async {
    final fake = await pumpApp(tester);
    String? focused() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<HostButton>()?.label;

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
      for (final screen in [GamesScreen, HapticPanelScreen, LatencyScreen, ShaderSpikeScreen, StatsScreen]) {
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
      tester.element(find.descendant(of: find.widgetWithText(HostButton, label), matching: find.text(label))),
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
      'Play',
      'Haptic test',
      'Latency',
      'Look test',
      'Stats',
    });
    expect([fake.newCodes, fake.simAdds, fake.drops, fake.forgets, fake.exports], [1, 1, 1, 1, 1]);
    expect(opened.toSet(), {GamesScreen, HapticPanelScreen, LatencyScreen, ShaderSpikeScreen, StatsScreen});
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
    fake.emit();
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
    expect([shown.gamepad?.tiltX, shown.gamepad?.tiltY], [0.25, -0.5]);
    expect(shown.gamepad?.mode, InputMode.gyro);
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
    expect(shown.gamepad?.mode, InputMode.sticks);
    expect(shown.gamepad?.buttons, {GamepadButton.lb, GamepadButton.a});
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves the address out for the host phone\'s own player', (tester) async {
    final fake = await pumpApp(tester);
    fake.state = HostViewState(
      hostName: 'Android TV',
      host: HostSnapshot(
        running: true,
        port: 45780,
        pairingCode: '0427',
        controllers: [
          ControllerInfo(
            controllerId: 'local',
            name: 'Keyboard',
            platform: 'android',
            appVersion: '0.6.0',
            remoteAddress: null,
            isLocal: true,
            state: ControllerState.connected,
            since: DateTime(2026),
            rttMs: 0,
          ),
        ],
      ),
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(find.text('android · 0.6.0'), findsOneWidget);
    expect(find.textContaining(' · 192.168.'), findsNothing);
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
    expect(
      find.text('${SoundKey.values.length} of ${SoundKey.values.length} event sounds loaded (fake)'),
      findsOneWidget,
    );
  });

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

  testWidgets('the first launch asks the adult about sharing; nothing is shared by default', (tester) async {
    final fake = await pumpApp(tester, consent: null);
    expect(find.byKey(const Key('consentDialog')), findsOneWidget);
    expect(find.textContaining('No names, accounts'), findsOneWidget);
    // "Don't share" has the remote's focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(fake.stats.consents, [false]);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('once answered, the prompt does not come back', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('consentDialog')), findsNothing);
  });

  testWidgets('Add simulated controller adds up to three; Stop simulations shows once there are some', (tester) async {
    final fake = await pumpApp(tester);
    await tapVisible(tester, find.byKey(const Key('addSim')));
    await tester.pump();
    expect(fake.simAdds, 1);
    expect(find.byKey(const Key('stopSims')), findsNothing);

    // Three simulated controllers: no room for more, and a way to stop them.
    final s = fake.state;
    fake.state = HostViewState(
      hostName: s.hostName,
      host: s.host,
      addresses: s.addresses,
      advertise: s.advertise,
      advertisedName: s.advertisedName,
      sims: [
        for (var i = 0; i < HostService.maxSims; i++) ClientSnapshot(status: ClientStatus.connected, player: i + 2),
      ],
    );
    fake.emit();
    await tester.pumpAndSettle();
    expect(tester.widget<HostButton>(find.byKey(const Key('addSim'))).onPressed, isNull);
    expect(find.byKey(const Key('stopSims')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('stopSims')));
    await tester.pump();
    expect(fake.simStops, 1);
  });
}
