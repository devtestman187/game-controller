import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../app_info.dart';
import '../host_controller.dart';
import '../providers.dart';
import 'game_screen.dart';
import 'haptic_panel_screen.dart';
import 'input_visualizer.dart';
import 'latency_screen.dart';
import 'tv_button.dart';

/// The TV's main screen: pairing code, addresses, connected controllers with
/// live ping, and the log. Works with a TV remote and in a laptop window.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostStateProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pairing = _PairingPanel(state: state);
            final controllers = _ControllersPanel(state: state);
            if (constraints.maxWidth >= 720 && constraints.maxHeight >= 420) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(state: state),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: pairing),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 7, child: controllers),
                                const SizedBox(height: 12),
                                const Expanded(flex: 4, child: _LogPanel()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            // Narrow laptop window: stack everything and scroll.
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(state: state),
                const SizedBox(height: 12),
                pairing,
                const SizedBox(height: 12),
                SizedBox(height: 320, child: controllers),
                const SizedBox(height: 12),
                const SizedBox(height: 240, child: _LogPanel()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = state.serverError;
    final (status, statusColor) = error != null
        ? (error, scheme.error)
        : state.host.running
        ? ('Listening on port ${state.host.port}', scheme.onSurface)
        : ('Starting…', scheme.onSurface);
    final title = Row(
      children: [
        Icon(Icons.tv, size: 32, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Controller Test', style: text.headlineSmall),
                TextSpan(
                  text: '   Protocol v$protocolVersion · app $appVersion · Milestone 6',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            status,
            style: text.bodyMedium?.copyWith(color: statusColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
    // Always in view at the top, so the remote reaches them with Up.
    final buttons = [
      TvButton(
        label: 'Test game',
        icon: Icons.videogame_asset_outlined,
        onPressed: () => _open(context, const GameScreen()),
      ),
      TvButton(label: 'Haptic test', icon: Icons.vibration, onPressed: () => _open(context, const HapticPanelScreen())),
      TvButton(label: 'Latency', icon: Icons.speed, onPressed: () => _open(context, const LatencyScreen())),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 760
          ? Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                buttons[0],
                const SizedBox(width: 8),
                buttons[1],
                const SizedBox(width: 8),
                buttons[2],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: buttons),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing, this.scrollable = false});

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Wrap [child] in a scroll view when the panel has a fixed height.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // In the narrow layout the panel sits in a scrolling list (unbounded
        // height), so it sizes to its content instead of filling the space.
        final bounded = constraints.hasBoundedHeight;
        final body = scrollable && bounded ? SingleChildScrollView(child: child) : child;
        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 8),
                if (bounded) Flexible(child: body) else body,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PairingPanel extends ConsumerWidget {
  const _PairingPanel({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(hostControllerProvider);
    final port = state.host.port;
    final sim = state.sim;
    final advertisedName = state.advertisedName ?? 'Controller Test (${state.hostName})';

    return _Panel(
      title: 'Pairing code',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.host.pairingCode.split('').join(' '),
            key: const Key('pairingCode'),
            style: text.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text('On the phone, choose "$advertisedName" and enter this code.', style: text.bodyLarge),
          const SizedBox(height: 16),
          Text('Address for manual entry', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          if (port == null)
            Text('–', style: text.titleLarge)
          else if (state.addresses.isEmpty)
            Text('No network connection', style: text.titleMedium?.copyWith(color: scheme.error))
          else
            for (final a in state.addresses.take(3))
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${a.address}:$port', style: text.titleLarge),
                    TextSpan(
                      text: '   ${a.interfaceName}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          _AdvertiseStatus(state: state),
          const SizedBox(height: 4),
          const _SoundLine(),
          if (Platform.isWindows) ...[
            const SizedBox(height: 4),
            Text(
              'Phones can\'t connect? Allow Controller Test through Windows Firewall on private networks '
              '(see tv_test_app/README.md).',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TvButton(label: 'New code', icon: Icons.refresh, autofocus: true, onPressed: controller.newPairingCode),
              TvButton(
                label: sim == null ? 'Simulate controller' : 'Stop simulation',
                icon: sim == null ? Icons.smart_toy_outlined : Icons.stop_circle_outlined,
                onPressed: port == null ? null : controller.toggleSimulatedController,
              ),
              TvButton(
                label: 'Drop connections',
                icon: Icons.link_off,
                onPressed: state.host.controllers.isEmpty ? null : controller.dropAllConnections,
              ),
            ],
          ),
          if (sim != null) ...[
            const SizedBox(height: 8),
            Text(
              'Simulated controller: ${_clientStatusLabel(sim)}'
              '${sim.isConnected && sim.rttMs != null ? ' · ${sim.rttMs} ms' : ''}',
              style: text.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

/// Whether the four event sounds loaded (they play in the game and the
/// haptic test).
class _SoundLine extends ConsumerWidget {
  const _SoundLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(soundStatusProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = HapticEvent.values.length;
    final (icon, color, message) = s.error != null
        ? (Icons.volume_off, scheme.error, 'Sounds are off: ${s.error}')
        : !s.ready
        ? (Icons.volume_mute, scheme.onSurfaceVariant, 'Loading sounds…')
        : (
            s.loaded == total ? Icons.volume_up : Icons.volume_down,
            s.loaded == total ? Colors.greenAccent : Colors.amberAccent,
            '${s.loaded} of $total event sounds loaded (${s.engine})',
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, key: const Key('soundStatus'), style: text.bodyMedium),
        ),
      ],
    );
  }
}

class _AdvertiseStatus extends StatelessWidget {
  const _AdvertiseStatus({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, message) = switch (state.advertise) {
      AdvertiseState.starting => (Icons.wifi_find, scheme.onSurfaceVariant, 'Starting network discovery…'),
      AdvertiseState.advertising => (Icons.wifi_tethering, Colors.greenAccent, 'Phones on this Wi-Fi can find this TV'),
      AdvertiseState.failed => (
        Icons.wifi_tethering_error,
        scheme.error,
        'Network discovery isn\'t working (${state.advertiseError}). Phones can still use the address above.',
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: text.bodyMedium)),
      ],
    );
  }
}

class _ControllersPanel extends ConsumerWidget {
  const _ControllersPanel({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllers = state.host.controllers;
    final connected = state.host.connected.length;
    final text = Theme.of(context).textTheme;
    final anyGone = controllers.any((c) => c.state != ControllerState.connected);
    return _Panel(
      title: 'Controllers · $connected connected',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TvButton(
            label: 'Forget phones',
            compact: true,
            onPressed: anyGone
                ? () {
                    final n = ref.read(hostControllerProvider).forgetPairings();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Forgot $n phone${n == 1 ? '' : 's'}. They need the code again.')),
                    );
                  }
                : null,
          ),
        ],
      ),
      child: controllers.isEmpty
          ? Center(
              child: Text(
                'No controllers yet. Open the controller app on the phone.',
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: controllers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ControllerTile(info: controllers[i]),
            ),
    );
  }
}

class _ControllerTile extends StatelessWidget {
  const _ControllerTile({required this.info});

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (info.state) {
      ControllerState.connected => ('Connected', Colors.greenAccent),
      ControllerState.pairing => ('Waiting for code', Colors.amberAccent),
      ControllerState.disconnected => ('Disconnected', scheme.onSurfaceVariant),
    };
    final icon = switch (info.platform) {
      'ios' => Icons.phone_iphone,
      'android' => Icons.phone_android,
      'sim' => Icons.smart_toy_outlined,
      _ => Icons.devices_other,
    };
    final rtt = info.rttMs;
    final stats = info.rttStats;
    final live = info.state == ControllerState.connected;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a 1080p TV the tile is narrow: a smaller picture leaves room for the name and state.
        final narrow = constraints.maxWidth < 560;
        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (live && info.player != null)
                  PlayerBadge(key: Key('player-${info.controllerId}'), number: info.player!, size: 30)
                else
                  Icon(icon, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.name, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                      Text(
                        '${info.platform} · ${info.appVersion} · ${info.remoteAddress}',
                        style: muted,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        label,
                        style: text.titleSmall?.copyWith(color: color),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                      if (live && (info.input?.hasAnalog ?? false))
                        Text(
                          'Tilt x ${info.input!.ax!.toStringAsFixed(2)}  y ${info.input!.ay!.toStringAsFixed(2)}',
                          key: Key('tilt-${info.controllerId}'),
                          style: text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      if (live && (info.input?.hasSticks ?? false))
                        Text(
                          'L ${info.input!.lx!.toStringAsFixed(2)}, ${info.input!.ly!.toStringAsFixed(2)}   '
                          'R ${info.input!.rx!.toStringAsFixed(2)}, ${info.input!.ry!.toStringAsFixed(2)}',
                          key: Key('sticks-${info.controllerId}'),
                          style: text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InputVisualizer(
                  key: Key('visualizer-${info.controllerId}'),
                  input: live ? info.input : null,
                  width: narrow ? 160 : 210,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        live && rtt != null ? '$rtt ms' : '–',
                        style: text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                      if (live && stats != null) ...[
                        Text('avg ${stats.avgMs} ms', style: muted),
                        Text('max ${stats.maxMs} ms', style: muted),
                      ],
                      if (live && info.inputLatency != null)
                        Text(
                          'input ~${info.inputLatency!.avgMs} ms',
                          key: Key('inputLatency-${info.controllerId}'),
                          style: muted,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogPanel extends ConsumerWidget {
  const _LogPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(logLinesProvider);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.3);
    return _Panel(
      title: 'Log',
      trailing: TvButton(
        label: 'Save log',
        icon: Icons.save_alt,
        compact: true,
        onPressed: () => saveLog(context, ref),
      ),
      child: ExcludeFocus(
        child: ListView.builder(
          reverse: true, // Newest at the bottom, and it stays scrolled there.
          itemCount: lines.length,
          itemBuilder: (context, i) => Text(lines[lines.length - 1 - i].toString(), style: style),
        ),
      ),
    );
  }
}

String _clientStatusLabel(ClientSnapshot s) => switch (s.status) {
  ClientStatus.idle => 'Off',
  ClientStatus.connecting => 'Connecting…',
  ClientStatus.waitingForCode => 'Waiting for code',
  ClientStatus.pairing => 'Pairing…',
  ClientStatus.connected => 'Connected',
  ClientStatus.reconnecting => 'Reconnecting (attempt ${s.attempt})…',
  ClientStatus.failed => 'Failed (${s.problem?.name ?? 'unknown'})',
};
