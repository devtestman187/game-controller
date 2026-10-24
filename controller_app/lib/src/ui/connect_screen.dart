import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery.dart';
import '../providers.dart';
import 'diagnostics_screen.dart';
import 'labels.dart';

/// Choosing and pairing a TV: TVs found on the network (plus manual entry) on
/// the left, the connection on the right. Closes itself once connected.
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clientStateProvider, (previous, next) {
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
                  ? 'Searching… Open the Controller Test app on the TV or laptop, on the same Wi-Fi as this phone.'
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

/// The right-hand side: what the connection is doing and what to do next.
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(clientStateProvider);
    final actions = ref.read(connectionActionsProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final problem = problemMessage(s);
    final host = s.hostLabel;

    final List<Widget> children = switch (s.status) {
      ClientStatus.idle => [
        const Icon(Icons.link_off, size: 40),
        const SizedBox(height: 8),
        Text('Not connected', style: text.titleLarge),
        const SizedBox(height: 4),
        const Text('Pick a TV on the left, or type its address.', textAlign: TextAlign.center),
      ],
      ClientStatus.connecting => [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text('Connecting to $host…', style: text.titleMedium, textAlign: TextAlign.center),
        TextButton(onPressed: actions.disconnect, child: const Text('Cancel')),
      ],
      ClientStatus.waitingForCode || ClientStatus.pairing => [_CodeEntry(snapshot: s, problem: problem)],
      ClientStatus.connected => [
        const Icon(Icons.check_circle, size: 48, color: Colors.greenAccent),
        const SizedBox(height: 8),
        Text('Connected to $host', style: text.titleLarge, textAlign: TextAlign.center),
        Text(s.rttMs == null ? 'Ping –' : 'Ping ${s.rttMs} ms', style: text.titleMedium),
        if (s.rttStats != null) Text('Last 30 s: ${s.rttStats}', style: text.bodySmall),
        const SizedBox(height: 8),
        Text('Go back to use the controller.', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: actions.disconnect, child: const Text('Disconnect')),
      ],
      ClientStatus.reconnecting => [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text('Connection lost. Reconnecting to $host…', style: text.titleMedium, textAlign: TextAlign.center),
        Text('Attempt ${s.attempt}', style: text.bodySmall),
        TextButton(onPressed: actions.disconnect, child: const Text('Stop')),
      ],
      ClientStatus.failed => [
        Icon(Icons.error_outline, size: 40, color: scheme.error),
        const SizedBox(height: 8),
        Text(problem ?? 'Not connected', textAlign: TextAlign.center, style: text.bodyLarge),
        if (s.detail != null) ...[
          const SizedBox(height: 4),
          Text(
            s.detail!,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (s.target != null)
              FilledButton(onPressed: () => actions.connect(s.target!), child: const Text('Try again')),
            TextButton(onPressed: actions.disconnect, child: const Text('Cancel')),
          ],
        ),
      ],
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _CodeEntry extends ConsumerStatefulWidget {
  const _CodeEntry({required this.snapshot, required this.problem});

  final ClientSnapshot snapshot;
  final String? problem;

  @override
  ConsumerState<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends ConsumerState<_CodeEntry> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(_CodeEntry old) {
    super.didUpdateWidget(old);
    // Clear the field after a wrong code so the next one can be typed fresh.
    if (widget.snapshot.problem != old.snapshot.problem && widget.snapshot.status == ClientStatus.waitingForCode) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length == 4) ref.read(connectionActionsProvider).submitCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = widget.snapshot.status == ClientStatus.pairing;
    final problem = widget.problem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the code shown on ${widget.snapshot.hostLabel}',
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 180,
          child: TextField(
            key: const Key('pairingCode'),
            controller: _controller,
            autofocus: true,
            enabled: !busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0000', counterText: ''),
            // Four digits is a whole code, so send it without an extra tap.
            onChanged: (value) {
              if (value.length == 4) _submit();
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 8),
          Text(
            problem,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            FilledButton(onPressed: busy ? null : _submit, child: const Text('Pair')),
            const SizedBox(width: 8),
            TextButton(onPressed: ref.read(connectionActionsProvider).disconnect, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}
