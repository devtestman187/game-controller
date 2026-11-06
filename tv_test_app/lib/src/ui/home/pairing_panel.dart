import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';

import '../../app_info.dart';
import 'panel.dart';

/// The code a phone types to pair, the addresses to type by hand, how network
/// discovery stands, and the controls for the simulated controllers.
class PairingPanel extends StatelessWidget {
  const PairingPanel({super.key, required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final advertisedName = state.advertisedName ?? 'Thumb Party TV (${state.hostName})';
    return Panel(
      title: 'Pairing code',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PairingCode(state: state, advertisedName: advertisedName),
          const SizedBox(height: 16),
          _AddressList(state: state),
          const SizedBox(height: 12),
          AdvertiseStatus(state: state),
          const SizedBox(height: 4),
          const SoundLine(),
          if (Platform.isWindows) ...[const SizedBox(height: 4), const _FirewallNote()],
          const SizedBox(height: 4),
          const _SiteUrl(),
          const SizedBox(height: 16),
          _PairingButtons(state: state),
          _SimList(sims: state.sims),
        ],
      ),
    );
  }
}

/// The pairing code, big enough to read across the room, and how to type it.
class _PairingCode extends StatelessWidget {
  const _PairingCode({required this.state, required this.advertisedName});

  final HostViewState state;
  final String advertisedName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
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
      ],
    );
  }
}

/// The addresses to type on a phone that can't find the TV by itself.
class _AddressList extends StatelessWidget {
  const _AddressList({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final port = state.host.port;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

/// Where the phones can't find the TV, Windows needs to allow it first.
class _FirewallNote extends StatelessWidget {
  const _FirewallNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Text(
      'Phones can\'t connect? Allow Thumb Party TV through Windows Firewall on private networks '
      '(see the tester guide).',
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

/// Where to read more: the tester guide and the privacy policy.
class _SiteUrl extends StatelessWidget {
  const _SiteUrl();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Text(
      'Tester guide and privacy policy: $siteUrl',
      key: const Key('siteUrl'),
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

/// The pairing actions: a new code, simulate a phone, drop every connection.
class _PairingButtons extends ConsumerWidget {
  const _PairingButtons({required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(hostServiceProvider);
    final port = state.host.port;
    final sims = state.sims;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        HostButton(label: 'New code', icon: Icons.refresh, autofocus: true, onPressed: controller.newPairingCode),
        HostButton(
          key: const Key('addSim'),
          label: sims.isEmpty ? 'Simulate controller' : 'Add simulated controller',
          icon: Icons.smart_toy_outlined,
          onPressed: port == null || sims.length >= HostService.maxSims ? null : controller.addSimulatedController,
        ),
        if (sims.isNotEmpty)
          HostButton(
            key: const Key('stopSims'),
            label: sims.length == 1 ? 'Stop simulation' : 'Stop simulations',
            icon: Icons.stop_circle_outlined,
            onPressed: controller.stopSimulatedControllers,
          ),
        HostButton(
          label: 'Drop connections',
          icon: Icons.link_off,
          onPressed: state.host.controllers.isEmpty ? null : controller.dropAllConnections,
        ),
      ],
    );
  }
}

/// One line per simulated controller, with its state and its ping.
class _SimList extends StatelessWidget {
  const _SimList({required this.sims});

  final List<ClientSnapshot> sims;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, sim) in sims.indexed) ...[
          const SizedBox(height: 8),
          Text(
            'Simulated controller${sims.length == 1 ? '' : ' ${i + 1}'}: ${_clientStatusLabel(sim)}'
            '${sim.isConnected && sim.rttMs != null ? ' · ${sim.rttMs} ms' : ''}',
            style: text.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Whether the four event sounds loaded (they play in the game and the
/// haptic test).
class SoundLine extends ConsumerWidget {
  const SoundLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(soundStatusProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = SoundKey.values.length;
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

/// How network discovery stands: starting, working, or failed.
class AdvertiseStatus extends StatelessWidget {
  const AdvertiseStatus({super.key, required this.state});

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

String _clientStatusLabel(ClientSnapshot s) => switch (s.status) {
  ClientStatus.idle => 'Off',
  ClientStatus.connecting => 'Connecting…',
  ClientStatus.waitingForCode => 'Waiting for code',
  ClientStatus.pairing => 'Pairing…',
  ClientStatus.connected => 'Connected',
  ClientStatus.reconnecting => 'Reconnecting (attempt ${s.attempt})…',
  ClientStatus.failed => 'Failed (${s.problem?.name ?? 'unknown'})',
};
