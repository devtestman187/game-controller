import 'dart:io';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:party_host/party_host.dart';

import '../../app_info.dart';
import '../../tv_text.dart';
import '../status_line.dart';
import 'panel.dart';

/// The code a phone types to pair, the addresses to type by hand, how network
/// discovery stands, and the controls for the simulated controllers. The
/// build's version sits at its bottom (M13 3d): the header has no room for it
/// at the TV's type, and a tester finds it here.
class PairingPanel extends StatelessWidget {
  const PairingPanel({super.key, required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final advertisedName = state.advertisedName ?? '${TvText.name} (${state.hostName})';
    return Panel(
      title: TvText.pairingCode,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PairingCode(state: state, advertisedName: advertisedName),
          const SizedBox(height: ToySizes.space12),
          _AddressList(state: state),
          const SizedBox(height: ToySizes.space8),
          AdvertiseStatus(state: state),
          const SizedBox(height: ToySizes.space4),
          const SoundLine(),
          if (Platform.isWindows) ...[const SizedBox(height: ToySizes.space4), const _FirewallNote()],
          const SizedBox(height: ToySizes.space4),
          const _SiteUrl(),
          const SizedBox(height: ToySizes.space12),
          _PairingButtons(state: state),
          _SimList(sims: state.sims),
          const SizedBox(height: ToySizes.space8),
          Text(
            TvText.buildLine,
            key: const Key('buildLine'),
            style: look.type.body.copyWith(color: look.colors.inkSoft),
          ),
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
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The clock's own type (M13 3d): the code is the one thing a player
        // reads from the couch.
        Text(
          state.host.pairingCode.split('').join(' '),
          key: const Key('pairingCode'),
          style: look.type.clock.copyWith(color: look.colors.ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        Text(TvText.enterCode(advertisedName), style: look.type.body.copyWith(color: look.colors.ink)),
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
    final look = ToyLookScope.of(context);
    final colors = look.colors;
    final ink = look.type.body.copyWith(color: colors.ink);
    final soft = look.type.body.copyWith(color: colors.inkSoft);
    final port = state.host.port;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TvText.manualAddress, style: soft),
        if (port == null)
          Text(HostText.dash, style: ink)
        else if (state.addresses.isEmpty)
          StatusLine(label: TvText.noNetwork, color: colors.bad)
        else
          for (final a in state.addresses.take(3))
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: TvText.address(a.address, port), style: ink),
                  TextSpan(text: '   ${a.interfaceName}', style: soft),
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
    final look = ToyLookScope.of(context);
    return Text(TvText.firewall, style: look.type.body.copyWith(color: look.colors.inkSoft));
  }
}

/// Where to read more: the tester guide and the privacy policy.
class _SiteUrl extends StatelessWidget {
  const _SiteUrl();

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Text(
      TvText.site(siteUrl),
      key: const Key('siteUrl'),
      style: look.type.body.copyWith(color: look.colors.inkSoft),
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
      spacing: ToySizes.space8,
      runSpacing: ToySizes.space8,
      children: [
        HostButton(label: TvText.newCode, icon: Icons.refresh, autofocus: true, onPressed: controller.newPairingCode),
        HostButton(
          key: const Key('addSim'),
          label: sims.isEmpty ? TvText.simulateController : TvText.addSimulatedController,
          icon: Icons.smart_toy_outlined,
          onPressed: port == null || sims.length >= HostService.maxSims ? null : controller.addSimulatedController,
        ),
        if (sims.isNotEmpty)
          HostButton(
            key: const Key('stopSims'),
            label: sims.length == 1 ? TvText.stopSimulation : TvText.stopSimulations,
            icon: Icons.stop_circle_outlined,
            onPressed: controller.stopSimulatedControllers,
          ),
        HostButton(
          label: TvText.dropConnections,
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
    final colors = ToyLookScope.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, sim) in sims.indexed) ...[
          const SizedBox(height: ToySizes.space8),
          // Its state is a dot in the look's status colours, never coloured
          // words (M13 3d).
          StatusLine(
            label: TvText.simulatedController(
              sims.length == 1 ? '' : ' ${i + 1}',
              _clientStatusLabel(sim),
              pingMs: sim.isConnected ? sim.rttMs : null,
            ),
            color: _clientStatusColor(colors, sim.status),
          ),
        ],
      ],
    );
  }
}

/// A simulated phone's state in the look's tokens: connected is good, a phone
/// on its way in is the focus yellow, a reconnect is the caution amber, and a
/// failure is bad. A stopped one is simply ink.
Color _clientStatusColor(ToyColors colors, ClientStatus status) => switch (status) {
  ClientStatus.connected => colors.good,
  ClientStatus.connecting || ClientStatus.waitingForCode || ClientStatus.pairing => colors.focus,
  ClientStatus.reconnecting => colors.caution,
  ClientStatus.failed => colors.bad,
  ClientStatus.idle => colors.inkSoft,
};

/// Whether the four event sounds loaded (they play in the game and the
/// haptic test).
class SoundLine extends ConsumerWidget {
  const SoundLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(soundStatusProvider);
    final colors = ToyLookScope.of(context).colors;
    final total = SoundKey.values.length;
    final (color, message) = s.error != null
        ? (colors.bad, TvText.soundsOff(s.error!))
        : !s.ready
        ? (colors.focus, TvText.soundsLoading)
        : (s.loaded == total ? colors.good : colors.caution, TvText.soundsLoaded(s.loaded, total, s.engine));
    return StatusLine(label: message, color: color, labelKey: const Key('soundStatus'));
  }
}

/// How network discovery stands: starting, working, or failed.
class AdvertiseStatus extends StatelessWidget {
  const AdvertiseStatus({super.key, required this.state});

  final HostViewState state;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final (color, message) = switch (state.advertise) {
      AdvertiseState.starting => (colors.focus, TvText.discovering),
      AdvertiseState.advertising => (colors.good, TvText.discoverable),
      AdvertiseState.failed => (colors.bad, TvText.discoveryFailed(state.advertiseError)),
    };
    return StatusLine(label: message, color: color);
  }
}

String _clientStatusLabel(ClientSnapshot s) => switch (s.status) {
  ClientStatus.idle => TvText.off,
  ClientStatus.connecting => TvText.connecting,
  ClientStatus.waitingForCode => TvText.waitingForCode,
  ClientStatus.pairing => TvText.pairing,
  ClientStatus.connected => TvText.connected,
  ClientStatus.reconnecting => TvText.reconnecting(s.attempt),
  ClientStatus.failed => TvText.failed(s.problem?.name ?? 'unknown'),
};
