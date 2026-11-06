import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../input_visualizer.dart';
import 'panel.dart';

/// The paired and connected phones, each with its state and live input, and
/// the button that forgets the ones that are gone.
class ControllersPanel extends ConsumerWidget {
  const ControllersPanel({super.key, required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllers = state.host.controllers;
    final connected = state.host.connected.length;
    final text = Theme.of(context).textTheme;
    final anyGone = controllers.any((c) => c.state != ControllerState.connected);
    return Panel(
      title: 'Controllers · $connected connected',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HostButton(
            label: 'Forget phones',
            compact: true,
            onPressed: anyGone
                ? () {
                    final n = ref.read(hostServiceProvider).forgetPairings();
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
              itemBuilder: (context, i) => ControllerTile(info: controllers[i]),
            ),
    );
  }
}

/// One controller: who it is, what it does, and its ping.
class ControllerTile extends StatelessWidget {
  const ControllerTile({super.key, required this.info});

  /// Below this width the input picture is smaller, so the name and the state
  /// still fit on a 1080p TV (960 logical pixels wide).
  static const narrowWidth = 560.0;

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = info.state == ControllerState.connected;
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (live && info.player != null)
                PlayerBadge(key: Key('player-${info.controllerId}'), number: info.player!, size: 30)
              else
                Icon(_platformIcon(info.platform), size: 28),
              const SizedBox(width: 12),
              Expanded(child: _ControllerDetails(info: info)),
              const SizedBox(width: 8),
              InputVisualizer(
                key: Key('visualizer-${info.controllerId}'),
                gamepad: live ? GamepadState.fromInput(info.input) : null,
                width: constraints.maxWidth < narrowWidth ? 160 : 210,
              ),
              const SizedBox(width: 12),
              SizedBox(width: 92, child: _ControllerLatency(info: info)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone's icon by its platform.
IconData _platformIcon(String platform) => switch (platform) {
  'ios' => Icons.phone_iphone,
  'android' => Icons.phone_android,
  'sim' => Icons.smart_toy_outlined,
  _ => Icons.devices_other,
};

/// Who the controller is and what it is doing, including the live tilt and
/// sticks.
class _ControllerDetails extends StatelessWidget {
  const _ControllerDetails({required this.info});

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
    final live = info.state == ControllerState.connected;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(info.name, style: text.titleMedium, overflow: TextOverflow.ellipsis),
        // The host phone's own player has no address to show (M12).
        Text(
          [info.platform, info.appVersion, ?info.remoteAddress].join(' · '),
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
    );
  }
}

/// The ping, its average and worst, and the input delay, of one controller.
class _ControllerLatency extends StatelessWidget {
  const _ControllerLatency({required this.info});

  final ControllerInfo info;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final live = info.state == ControllerState.connected;
    final rtt = info.rttMs;
    final stats = info.rttStats;
    return Column(
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
          Text('input ~${info.inputLatency!.avgMs} ms', key: Key('inputLatency-${info.controllerId}'), style: muted),
      ],
    );
  }
}
