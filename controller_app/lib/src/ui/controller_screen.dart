import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'connect_screen.dart';
import 'diagnostics_screen.dart';
import 'haptics_dialog.dart';
import 'labels.dart';
import 'pad_widgets.dart';

enum PadMode { dpad, gyro }

/// The controller itself: D-pad on the left, Start/Select in the middle,
/// face buttons on the right, and a slim bar on top for the connection, mode,
/// haptics and Diagnostics.
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
    } else {
      // Leaving the app (or a system sheet on top) must not leave input held.
      ref.read(padProvider.notifier).releaseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the TV shows up at a new address (new DHCP lease), reconnect there.
    ref.listen(discoveryStateProvider, (_, next) {
      final client = ref.read(clientProvider);
      for (final host in next.hosts) {
        client.updateAddress(host.address);
      }
    });
    final input = ref.watch(padProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 8, 16),
                      child: Center(child: DpadView()),
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
    final text = Theme.of(context).textTheme;
    final stats = client.rttStats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
      child: Row(
        children: [
          // The connection and ping take whatever room is left, and shorten.
          Expanded(
            child: Row(
              children: [
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
            segments: const [
              ButtonSegment(value: PadMode.dpad, label: Text('D-pad'), icon: Icon(Icons.gamepad_outlined)),
              ButtonSegment(
                value: PadMode.gyro,
                label: Text('Gyro'),
                icon: Icon(Icons.screen_rotation_alt_outlined),
                tooltip: 'Gyro mode arrives in Milestone 3',
                enabled: false,
              ),
            ],
            selected: const {PadMode.dpad},
            onSelectionChanged: (_) {},
          ),
          IconButton(
            tooltip: 'Haptics',
            icon: const Icon(Icons.vibration),
            onPressed: () => showHapticsDialog(context),
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
