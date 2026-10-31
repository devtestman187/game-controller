import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'tv_button.dart';

/// The PRD's latency target: input should reach the TV in about this long.
const latencyTargetMs = 50;

/// Latency readout (PRD T8): for each connected controller, the heartbeat
/// round trip and the estimated one-way input delay, live and as rolling
/// averages, against the ~50 ms target. "Save log" writes everything to a
/// file.
class LatencyScreen extends ConsumerWidget {
  const LatencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt with every heartbeat, so the figures stay live.
    ref.watch(hostStateProvider);
    final host = ref.watch(gameHostProvider);
    final players = ref.watch(gamePlayersProvider).where((p) => !p.local).toList();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Latency'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TvButton(
                label: 'Save log',
                icon: Icons.save_alt,
                autofocus: true,
                onPressed: () => saveLog(context, ref),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Input delay is how long a press or a stick movement takes from the phone to this screen\'s '
                'app, estimated from the heartbeats (one way, not counting the screen itself). The target is '
                'about $latencyTargetMs ms on home Wi-Fi. Ping is the full round trip. The stages break the delay '
                'down: phone to TV, then TV to the first frame drawn with that input (while a game runs).',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (players.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text('No controllers connected.', style: text.titleLarge, textAlign: TextAlign.center),
                ),
              for (final p in players) ...[_ControllerLatency(player: p, host: host), const SizedBox(height: 12)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Saves the log and says where it went.
Future<void> saveLog(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await ref.read(hostControllerProvider).exportLog();
    messenger.showSnackBar(SnackBar(content: Text('Log saved to $path'), duration: const Duration(seconds: 8)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not save the log: $e')));
  }
}

/// One player's latency, from the game host (PRD v2 P3), with the delay in
/// named stages (S7).
class _ControllerLatency extends StatelessWidget {
  const _ControllerLatency({required this.player, required this.host});

  final GamePlayer player;
  final GameHost host;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = host.latency(player.id);
    final rtt = l?.ping;
    final input = l?.inputDelay;
    final session = l?.inputDelaySession;
    final drawn = host.stageSummary(player.id, LatencyStage.receivedToDrawn);
    final id = player.id;
    final (verdict, color) = switch (input) {
      null => ('Not measured yet', scheme.onSurfaceVariant),
      final l when l.avgMs <= latencyTargetMs => ('Within the $latencyTargetMs ms target', Colors.greenAccent),
      _ => ('Above the $latencyTargetMs ms target', Colors.amberAccent),
    };
    return DecoratedBox(
      key: Key('latency-$id'),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerBadge(number: player.number),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(player.nickname ?? '', style: text.titleLarge, overflow: TextOverflow.ellipsis),
                ),
                Text(verdict, style: text.titleMedium?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _Figure(
                  'Input delay, 30 s avg',
                  input == null ? '–' : '${input.avgMs} ms',
                  input == null
                      ? (l?.errorMs == null ? 'not measured (phone app older than 0.6.0?)' : 'waiting for input')
                      : 'p95 ${input.p95Ms} · max ${input.maxMs} ms · ± ${l?.errorMs} ms',
                  valueKey: Key('inputDelay-$id'),
                ),
                _Figure(
                  'Input delay, whole session',
                  session == null ? '–' : '${session.avgMs} ms',
                  session == null ? '' : 'max ${session.maxMs} ms · ${session.samples} states',
                ),
                _Figure('Ping now', l?.pingNowMs == null ? '–' : '${l!.pingNowMs} ms', 'round trip'),
                _Figure(
                  'Ping, 30 s avg',
                  rtt == null ? '–' : '${rtt.avgMs} ms',
                  rtt == null ? '' : 'min ${rtt.minMs} · p95 ${rtt.p95Ms} · max ${rtt.maxMs} ms',
                ),
                _Figure(
                  'Stage: phone to TV',
                  input == null ? '–' : '${input.avgMs} ms',
                  'sent → received, 30 s avg',
                  valueKey: Key('stageSent-$id'),
                ),
                _Figure(
                  'Stage: TV to the screen',
                  drawn == null ? '–' : '${drawn.avgMs} ms',
                  drawn == null ? 'received → drawn, while a game runs' : 'received → drawn, p95 ${drawn.p95Ms} ms',
                  valueKey: Key('stageDrawn-$id'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.detail, {this.valueKey});

  final String label;
  final String value;
  final String detail;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          Text(
            value,
            key: valueKey,
            style: text.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (detail.isNotEmpty) Text(detail, style: muted),
        ],
      ),
    );
  }
}

/// A round badge with the player number in the player's colour.
class PlayerBadge extends StatelessWidget {
  const PlayerBadge({super.key, required this.number, this.size = 32});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Color(playerColor(number)), shape: BoxShape.circle),
    child: Text(
      '$number',
      style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.bold, color: const Color(0xFF14181F)),
    ),
  );
}
