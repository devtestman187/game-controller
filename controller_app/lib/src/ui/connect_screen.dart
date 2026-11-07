import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery.dart';
import '../host/hosting.dart';
import '../providers.dart';
import 'connect_panels.dart';
import 'diagnostics_screen.dart';
import 'labels.dart';

/// Choosing and pairing a TV: TVs found on the network (plus manual entry) on
/// the left, the connection on the right. Closes itself once connected.
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clientStateProvider, (previous, next) {
      // A hosting phone's own player connects to this phone: that is no reason
      // to close this screen, which would pop the host route above it (m12 §3).
      if (ref.read(hostingProvider)?.live ?? false) return;
      if (next.isConnected && !(previous?.isConnected ?? false)) Navigator.of(context).maybePop();
    });
    final client = ref.watch(clientStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to a TV'),
        actions: [
          StatusChip(client: client),
          IconButton(
            tooltip: 'Diagnostics',
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: _HostList()),
            VerticalDivider(width: 1),
            Expanded(flex: 4, child: ConnectionPanel()),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.client});

  final ClientSnapshot client;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (client.status) {
      ClientStatus.connected => Colors.greenAccent,
      ClientStatus.reconnecting || ClientStatus.connecting || ClientStatus.pairing => Colors.amberAccent,
      ClientStatus.waitingForCode => scheme.primary,
      ClientStatus.idle || ClientStatus.failed => scheme.onSurfaceVariant,
    };
    final rtt = client.rttMs;
    return Chip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(client.isConnected && rtt != null ? '${statusLabel(client)} · $rtt ms' : statusLabel(client)),
    );
  }
}

class _HostList extends ConsumerWidget {
  const _HostList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryStateProvider);
    final target = ref.watch(clientStateProvider.select((s) => s.target));
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('TVs on this Wi-Fi', style: text.titleMedium)),
              IconButton(
                tooltip: 'Search again',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(discoveryProvider).restart(),
              ),
            ],
          ),
          Expanded(
            child: discovery.hosts.isEmpty
                ? _NoHosts(discovery: discovery)
                : ListView(
                    children: [
                      for (final host in discovery.hosts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.tv),
                          title: Text(host.name),
                          subtitle: Text(
                            host.compatible
                                ? host.address.display
                                : '${host.address.display} · needs a matching app version',
                          ),
                          trailing: target != null && target.sameHostAs(host.address)
                              ? const Icon(Icons.check_circle_outline)
                              : const Icon(Icons.chevron_right),
                          onTap: () => ref.read(connectionActionsProvider).connect(host.address),
                        ),
                    ],
                  ),
          ),
          const _ManualEntry(),
        ],
      ),
    );
  }
}

class _NoHosts extends StatelessWidget {
  const _NoHosts({required this.discovery});

  final DiscoveryState discovery;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final error = discovery.error;
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error == null)
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 12),
              child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.wifi_off)),
          Expanded(
            child: Text(
              error == null
                  ? 'Searching… Open the Thumb Party TV app on the TV or PC, on the same Wi-Fi as this phone.'
                  : 'Discovery isn\'t working ($error). Type the address shown on the TV below.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends ConsumerStatefulWidget {
  const _ManualEntry();

  @override
  ConsumerState<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends ConsumerState<_ManualEntry> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    try {
      final host = HostAddress.parse(_controller.text);
      setState(() => _error = null);
      FocusScope.of(context).unfocus();
      ref.read(connectionActionsProvider).connect(host);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('manualAddress'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _connect(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: 'Or type the address',
              hintText: '192.168.1.50:45780',
              errorText: _error,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FilledButton(onPressed: _connect, child: const Text('Connect')),
        ),
      ],
    );
  }
}

/// Opens the Connect screen, from the bar's chip.
void openConnect(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen()));
