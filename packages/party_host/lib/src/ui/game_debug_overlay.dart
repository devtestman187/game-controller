import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:toy_look/toy_look.dart';

import '../providers.dart';
import '../text/host_text.dart';

/// How far above the bottom edge the arena's note sits, clear of the sprites'
/// play area.
const arenaNoteBottomPx = 48.0;

/// How far from the top edge the debug overlay sits, under the title bars.
const debugOverlayTopPx = 64.0;

/// How wide the debug overlay may grow before its values wrap: wide enough for
/// a latency and a haptic event on one line.
const _debugWidthPx = 460.0;

/// Haptic intensity is a share of full strength (0..1); the overlay shows it
/// as whole percents.
const _percent = 100;

/// The arena's note on a paper card (M13 3b): "No controller connected" in ink
/// over the board, where the old black box used to be.
class ArenaNote extends StatelessWidget {
  const ArenaNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => ToyCard(
    padding: const EdgeInsets.symmetric(horizontal: ToySizes.space24, vertical: ToySizes.space12),
    child: Text(message, style: ToyLookScope.of(context).type.button),
  );
}

/// Each player's mode, controls and latency, and the last haptic event sent
/// (PRD "Test game design": debug info), all from the game host.
class DebugOverlay extends ConsumerWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilt with the host state, so the values stay live.
    ref.watch(hostStateProvider);
    final host = ref.watch(gameHostProvider);
    final players = ref.watch(gamePlayersProvider);
    final last = ref.watch(tvEventsProvider);
    final sounds = ref.watch(soundStatusProvider);
    final rows = <(String, String)>[
      if (players.isEmpty) (HostText.controller, HostText.noneConnected),
      for (final p in players) ...[
        ('P${p.number}', '${p.nickname ?? ''}${p.local ? HostText.onThisDevice : ''}'),
        if (host.latency(p.id) case final l?) ...[
          (
            '  ${HostText.ping}',
            l.pingNowMs == null ? HostText.dash : HostText.pingMs(l.pingNowMs!, l.ping?.avgMs, l.ping?.maxMs),
          ),
          (
            '  ${HostText.inputDelay}',
            l.inputDelay == null ? HostText.dash : HostText.inputDelayMs(l.inputDelay!.avgMs, l.errorMs),
          ),
        ],
        ('  ${HostText.mode}', HostText.modeName(p.mode)),
        ('  ${HostText.values}', HostText.gamepadValues(host.gamepad(p.id))),
        ('  ${HostText.buttons}', HostText.gamepadButtons(host.gamepad(p.id))),
      ],
      (
        HostText.lastHaptic,
        last == null
            ? HostText.dash
            : HostText.hapticEvent(
                last.message.event.name,
                last.source,
                (last.message.intensity * _percent).round(),
                last.message.durationMs,
                last.reached,
              ),
      ),
      (
        HostText.sounds,
        sounds.error != null
            ? HostText.soundsOff(sounds.error!)
            : HostText.soundsLoaded(sounds.loaded, SoundKey.values.length),
      ),
    ];
    return _DebugTable(rows: rows);
  }
}

/// The overlay's table on a paper card (M13 3b): a label and a value for each
/// row, in the look's ink, with tabular figures so the numbers stay put.
class _DebugTable extends StatelessWidget {
  const _DebugTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final mono = look.type.body.copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: look.colors.ink);
    return ToyCard(
      key: const Key('debugOverlay'),
      padding: const EdgeInsets.all(ToySizes.space12),
      popIn: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _debugWidthPx),
        child: Table(
          columnWidths: const {0: IntrinsicColumnWidth()},
          children: [
            for (final (label, value) in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: ToySizes.space12, bottom: 2),
                    child: Text(label, style: mono.copyWith(color: look.colors.inkSoft)),
                  ),
                  Text(value, style: mono),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
