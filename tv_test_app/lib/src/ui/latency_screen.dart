import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart';

import '../tv_text.dart';
import 'status_line.dart';

/// The PRD's latency target: input should reach the TV in about this long.
const latencyTargetMs = 50;

/// Latency readout (PRD T8): for each connected controller, the heartbeat
/// round trip and the estimated one-way input delay, live and as rolling
/// averages, against the ~50 ms target. "Save log" writes everything to a
/// file.
///
/// Each controller's figures are a sheet of the look's paper with the ink edge
/// (M13 3d); the verdict on the delay is a dot in the look's status colours
/// beside ink words, never coloured words of its own.
class LatencyScreen extends ConsumerWidget {
  const LatencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt with every heartbeat, so the figures stay live.
    ref.watch(hostStateProvider);
    final host = ref.watch(gameHostProvider);
    // A phone that is away has no latency to show (m12 bug 1107d).
    final players = ref.watch(gamePlayersProvider).where((p) => !p.local && !p.away).toList();
    final look = ToyLookScope.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Scaffold(
        appBar: AppBar(
          title: const Text(TvText.latency),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: ToySizes.space16),
              child: HostButton(
                label: TvText.saveLog,
                icon: Icons.save_alt,
                autofocus: true,
                onPressed: () => saveLog(context, ref),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(ToySizes.space8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ToySizes.space8, vertical: ToySizes.space8),
                child: Text(
                  TvText.latencyIntro(latencyTargetMs),
                  style: look.type.body.copyWith(color: look.colors.onBackground),
                ),
              ),
              if (players.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    TvText.noControllersConnected,
                    style: look.type.title.copyWith(color: look.colors.onBackground),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final p in players) ...[
                _ControllerLatency(player: p, host: host),
                const SizedBox(height: ToySizes.space12),
              ],
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
    final path = await ref.read(hostServiceProvider).exportLog();
    messenger.showSnackBar(SnackBar(content: Text(TvText.logSaved(path)), duration: const Duration(seconds: 8)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(TvText.logSaveFailed(e))));
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
    final colors = ToyLookScope.of(context).colors;
    final input = host.latency(player.id)?.inputDelay;
    final id = player.id;
    final (verdict, color) = switch (input) {
      null => (TvText.notMeasured, colors.inkSoft),
      final l when l.avgMs <= latencyTargetMs => (TvText.withinTarget(latencyTargetMs), colors.good),
      _ => (TvText.aboveTarget(latencyTargetMs), colors.caution),
    };
    return ToyCard(
      key: Key('latency-$id'),
      padding: const EdgeInsets.all(ToySizes.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(player: player, verdict: verdict, verdictColor: color),
          const SizedBox(height: ToySizes.space8),
          _Figures(player: player, host: host),
        ],
      ),
    );
  }
}

/// The player's badge and name, with the verdict on the delay under them.
class _Header extends StatelessWidget {
  const _Header({required this.player, required this.verdict, required this.verdictColor});

  /// The player's badge: the look's own size, a row of figure labels deep.
  static const _badgeDiameter = 40.0;

  final GamePlayer player;
  final String verdict;
  final Color verdictColor;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ToyBadge(number: player.number, diameter: _badgeDiameter),
            const SizedBox(width: ToySizes.space12),
            Expanded(
              child: Text(
                player.nickname ?? '',
                style: look.type.button.copyWith(color: look.colors.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        StatusLine(label: verdict, color: verdictColor),
      ],
    );
  }
}

/// The six figures: the input delay (now and for the whole session), the ping,
/// and the delay broken into stages (S7). Keys name the player, for the tests.
class _Figures extends StatelessWidget {
  const _Figures({required this.player, required this.host});

  final GamePlayer player;
  final GameHost host;

  @override
  Widget build(BuildContext context) {
    final l = host.latency(player.id);
    final rtt = l?.ping;
    final input = l?.inputDelay;
    final session = l?.inputDelaySession;
    final drawn = host.stageSummary(player.id, LatencyStage.receivedToDrawn);
    final id = player.id;
    final figures = <(String, String, String, Key?)>[
      (
        TvText.inputDelayAverage,
        input == null ? HostText.dash : '${input.avgMs} ms',
        input == null
            ? (l?.errorMs == null ? TvText.olderPhoneApp : TvText.waitingForInput)
            : TvText.inputDelayDetail(input.p95Ms, input.maxMs, l?.errorMs),
        Key('inputDelay-$id'),
      ),
      (
        TvText.inputDelaySession,
        session == null ? HostText.dash : '${session.avgMs} ms',
        session == null ? '' : TvText.sessionDetail(session.maxMs, session.samples),
        null,
      ),
      (TvText.pingNow, l?.pingNowMs == null ? HostText.dash : '${l!.pingNowMs} ms', TvText.roundTrip, null),
      (
        TvText.pingAverageLabel,
        rtt == null ? HostText.dash : '${rtt.avgMs} ms',
        rtt == null ? '' : TvText.pingDetail(rtt.minMs, rtt.p95Ms, rtt.maxMs),
        null,
      ),
      (
        TvText.stagePhoneToTv,
        input == null ? HostText.dash : '${input.avgMs} ms',
        TvText.sentToReceived,
        Key('stageSent-$id'),
      ),
      (
        TvText.stageTvToScreen,
        drawn == null ? HostText.dash : '${drawn.avgMs} ms',
        drawn == null ? TvText.receivedToDrawn : TvText.receivedToDrawnP95(drawn.p95Ms),
        Key('stageDrawn-$id'),
      ),
    ];
    return Wrap(
      spacing: ToySizes.space32,
      runSpacing: ToySizes.space12,
      children: [for (final (label, value, detail, key) in figures) _Figure(label, value, detail, valueKey: key)],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.detail, {this.valueKey});

  /// A figure's width: room for a label's words at the TV's type.
  static const width = 260.0;

  final String label;
  final String value;
  final String detail;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final muted = look.type.body.copyWith(color: look.colors.inkSoft);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          Text(
            value,
            key: valueKey,
            style: look.type.button.copyWith(
              color: look.colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detail.isNotEmpty) Text(detail, style: muted),
        ],
      ),
    );
  }
}
