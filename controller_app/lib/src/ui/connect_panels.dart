import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../host/host_screen.dart';
import '../host/host_start_sheet.dart';
import '../host/hosting.dart';
import '../providers.dart';
import 'labels.dart';

/// The right-hand side of the Connect screen: what the connection is doing
/// and what to do next.
class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(clientStateProvider);
    final problem = problemMessage(s);
    final status = switch (s.status) {
      ClientStatus.idle => const _NotConnected(),
      ClientStatus.connecting => _Waiting(snapshot: s, reconnecting: false),
      ClientStatus.waitingForCode || ClientStatus.pairing => _CodeEntry(snapshot: s, problem: problem),
      ClientStatus.connected => _Connected(snapshot: s),
      ClientStatus.reconnecting => _Waiting(snapshot: s, reconnecting: true),
      ClientStatus.failed => _Failed(snapshot: s, problem: problem),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [status]),
      ),
    );
  }
}

/// Nothing connects yet: what to do, and the way on without a TV.
class _NotConnected extends ConsumerWidget {
  const _NotConnected();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off, size: 40),
        const SizedBox(height: 8),
        Text('Not connected', style: text.titleLarge),
        const SizedBox(height: 4),
        const Text('Pick a TV on the left, or type its address.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const _NoTvActions(),
      ],
    );
  }
}

/// What to do while no TV answers (v2 C23, m12 §3): the controls without one,
/// or host the game here.
class _NoTvActions extends ConsumerWidget {
  const _NoTvActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      OutlinedButton.icon(
        key: const Key('tryWithoutTv'),
        icon: const Icon(Icons.sports_esports_outlined),
        label: const Text('Try without a TV'),
        onPressed: () {
          ref.read(demoProvider.notifier).start();
          Navigator.of(context).maybePop();
        },
      ),
      OutlinedButton.icon(
        key: const Key('hostGame'),
        icon: const Icon(Icons.wifi_tethering),
        label: const Text('Host a game'),
        onPressed: () async {
          // Read before the dialog: after it, this widget may be gone.
          final hosting = ref.read(hostingProvider.notifier);
          final choice = await showHostStartSheet(context);
          if (choice == null || !context.mounted) return;
          final host = hosting.start();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HostScreen(host: host, choice: choice),
            ),
          );
        },
      ),
    ],
  );
}

/// A connection on its way: the first one, or another after a drop.
class _Waiting extends ConsumerWidget {
  const _Waiting({required this.snapshot, required this.reconnecting});

  final ClientSnapshot snapshot;

  /// True after a drop, when the screen also counts the attempts.
  final bool reconnecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final host = s.hostLabel;
    final text = Theme.of(context).textTheme;
    final disconnect = ref.read(connectionActionsProvider).disconnect;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          reconnecting ? 'Connection lost. Reconnecting to $host…' : 'Connecting to $host…',
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (reconnecting) Text('Attempt ${s.attempt}', style: text.bodySmall),
        TextButton(onPressed: disconnect, child: Text(reconnecting ? 'Stop' : 'Cancel')),
      ],
    );
  }
}

class _Connected extends ConsumerWidget {
  const _Connected({required this.snapshot});

  final ClientSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = snapshot;
    final host = s.hostLabel;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.read(connectionActionsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }
}

/// A connection that failed: why, and the ways to try again.
class _Failed extends ConsumerWidget {
  const _Failed({required this.snapshot, required this.problem});

  final ClientSnapshot snapshot;
  final String? problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.read(connectionActionsProvider);
    final target = snapshot.target;
    final detail = snapshot.detail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 40, color: scheme.error),
        const SizedBox(height: 8),
        Text(problem ?? 'Not connected', textAlign: TextAlign.center, style: text.bodyLarge),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (target != null) FilledButton(onPressed: () => actions.connect(target), child: const Text('Try again')),
            TextButton(onPressed: actions.disconnect, child: const Text('Cancel')),
          ],
        ),
        const SizedBox(height: 16),
        const _NoTvActions(),
      ],
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
