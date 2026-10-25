import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../gyro.dart';
import '../providers.dart';
import 'connect_screen.dart';
import 'diagnostics_screen.dart';
import 'gyro_dialog.dart';
import 'labels.dart';
import 'pad_widgets.dart';
import 'settings_screen.dart';
import 'stick_dialog.dart';
import 'stick_widgets.dart';
import 'tilt_view.dart';

/// The controller itself: D-pad (or, in gyro mode, the tilt view) on the
/// left, Start/Select in the middle, face buttons on the right, and a slim bar
/// on top for the connection, mode, settings and Diagnostics.
class ControllerScreen extends ConsumerStatefulWidget {
  const ControllerScreen({super.key});

  @override
  ConsumerState<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends ConsumerState<ControllerScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back to the last TV if still paired, otherwise straight to choosing one.
      if (!ref.read(connectionActionsProvider).reconnectToLastHost()) openConnect(context);
      // The mode used last (saved), and the battery and CPU readout.
      unawaited(ref.read(gyroProvider.notifier).restoreMode());
      ref.read(sessionMonitorProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A fresh search after returning to the app. This also picks up TVs
      // once the user allows local network access in the iOS prompt.
      ref.read(discoveryProvider).restart();
      // After the phone slept or the app was in the background, the TV has
      // usually dropped the connection: reconnect now, not after the
      // heartbeat times out.
      ref.read(clientProvider).resume();
      ref.read(gyroProvider.notifier).resume();
      ref.read(hapticsPlayerProvider).paused = false;
    } else {
      // Leaving the app (or a system sheet on top) must not leave input held.
      ref.read(gyroProvider.notifier).pause();
      ref.read(hapticsPlayerProvider).paused = true;
      ref.read(padProvider.notifier).releaseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Play haptic events from the TV in every mode (listening keeps it alive
    // without rebuilding the screen on each event).
    ref.listen(tvHapticsProvider, (_, _) {});
    ref.listen(outagesProvider, (_, _) {});
    // While reconnecting for a while, look for the TV again now and then: it
    // may have restarted on another port, or the network may have changed.
    ref.listen(clientStateProvider, (_, next) {
      if (next.status == ClientStatus.reconnecting && next.attempt > 0 && next.attempt % 4 == 0) {
        ref.read(discoveryProvider).restart();
      }
    });
    // If the TV shows up at a new address (new DHCP lease), reconnect there.
    ref.listen(discoveryStateProvider, (_, next) {
      final client = ref.read(clientProvider);
      for (final host in next.hosts) {
        client.updateAddress(host.address);
      }
    });
    final input = ref.watch(padProvider);
    final mode = ref.watch(gyroProvider.select((g) => g.mode));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            if (mode == PadMode.sticks)
              const Expanded(
                child: Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 4), child: StickModeView()),
              )
            else
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 8, 16),
                        child: Center(child: mode == PadMode.gyro ? const TiltView() : const DpadView()),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SmallButton(button: ControllerButton.select, label: 'Select'),
                          const SizedBox(height: 16),
                          const SmallButton(button: ControllerButton.start, label: 'Start'),
                          const SizedBox(height: 24),
                          Text(
                            input.isNeutral ? 'Nothing pressed' : input.toString(),
                            key: const Key('inputSummary'),
                            style: text.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      flex: 5,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 24, 16),
                        child: Center(child: FaceButtonsView()),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void openConnect(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientStateProvider);
    final gyro = ref.watch(gyroProvider);
    final text = Theme.of(context).textTheme;
    final stats = client.rttStats;
    final gyroUnavailable = gyro.availability == GyroAvailability.unavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
      child: Row(
        children: [
          // The connection and ping take whatever room is left, and shorten.
          Expanded(
            child: Row(
              children: [
                if (client.isConnected && client.player != null) ...[
                  PlayerBadge(number: client.player!),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: ActionChip(
                    key: const Key('connectionChip'),
                    avatar: Icon(Icons.circle, size: 12, color: _statusColor(context, client)),
                    label: Text(
                      client.isConnected
                          ? '${client.hostLabel} · ${client.rttMs ?? '–'} ms'
                          : '${statusLabel(client)} · tap to connect',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => openConnect(context),
                  ),
                ),
                if (client.isConnected && stats != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '30 s: min ${stats.minMs} · avg ${stats.avgMs} · max ${stats.maxMs} ms',
                      key: const Key('pingStats'),
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<PadMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              const ButtonSegment(value: PadMode.dpad, label: Text('D-pad'), icon: Icon(Icons.gamepad_outlined)),
              ButtonSegment(
                value: PadMode.gyro,
                label: const Text('Gyro'),
                icon: const Icon(Icons.screen_rotation_alt_outlined),
                tooltip: gyroUnavailable ? gyro.problem : 'Steer by tilting the phone',
                enabled: !gyroUnavailable && gyro.availability != GyroAvailability.checking,
              ),
              const ButtonSegment(
                value: PadMode.sticks,
                label: Text('Sticks'),
                icon: Icon(Icons.sports_esports_outlined),
                tooltip: 'Two analog sticks, Xbox-style',
              ),
            ],
            selected: {gyro.mode},
            onSelectionChanged: (selection) async {
              final ok = await ref.read(gyroProvider.notifier).setMode(selection.first);
              if (!ok && context.mounted) {
                final problem = ref.read(gyroProvider).problem ?? 'Gyro mode isn\'t available.';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
              }
            },
          ),
          if (gyro.mode == PadMode.gyro)
            IconButton(
              tooltip: 'Gyro settings',
              icon: const Icon(Icons.tune),
              onPressed: () => showGyroDialog(context),
            ),
          if (gyro.mode == PadMode.sticks)
            IconButton(
              tooltip: 'Stick settings',
              icon: const Icon(Icons.tune),
              onPressed: () => showStickDialog(context),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, ClientSnapshot client) => switch (client.status) {
  ClientStatus.connected => Colors.greenAccent,
  ClientStatus.reconnecting || ClientStatus.connecting || ClientStatus.pairing => Colors.amberAccent,
  ClientStatus.waitingForCode => Theme.of(context).colorScheme.primary,
  ClientStatus.idle || ClientStatus.failed => Theme.of(context).colorScheme.onSurfaceVariant,
};

/// "P1" in the player's colour, matching the sprite and the badge on the TV.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'You are player $number on the TV',
    child: Container(
      key: const Key('playerBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Color(playerColor(number)), borderRadius: BorderRadius.circular(12)),
      child: Text(
        'P$number',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14181F)),
      ),
    ),
  );
}
