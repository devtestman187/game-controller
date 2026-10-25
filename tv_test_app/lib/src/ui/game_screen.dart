import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:test_game/test_game.dart';

import '../host_controller.dart';
import '../providers.dart';

/// Keys that show or hide the debug overlay: OK on the remote (and Enter),
/// the remote's Info or Menu key if it has one, and D or F3 on a keyboard.
final _debugKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.info,
  LogicalKeyboardKey.contextMenu,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.f3,
};

/// The playable test (PRD T7): the arena, where every connected controller
/// drives its own sprite in its player colour (T9). Each game event goes as a
/// haptic event to the controller whose sprite caused it, and plays as a
/// sound on the TV.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.game});

  /// The game to run. Tests pass one in.
  final ArenaGame? game;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _debug = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_debugKeys.contains(event.logicalKey)) {
      setState(() => _debug = !_debug);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    // Back on the remote is left to the system, which closes the screen.
    return KeyEventResult.ignored;
  }

  void _onEvent(GameEvent e) {
    final who = ref.read(hostStateProvider).players.where((c) => c.controllerId == e.playerId).firstOrNull;
    ref
        .read(tvEventsProvider.notifier)
        .fire(
          e.toMessage(),
          source: 'game: ${e.cause.name}${who?.player == null ? '' : ', P${who!.player}'}',
          controllerId: e.playerId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final nobody = ref.watch(hostStateProvider.select((s) => s.players.isEmpty));
    final text = Theme.of(context).textTheme;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              ArenaView(
                game: widget.game,
                readPlayers: () => playerFeeds(ref.read(hostStateProvider)),
                onEvent: _onEvent,
              ),
              if (nobody)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 48,
                  child: Center(child: _Note('No controller connected. Pair a phone on the main screen.')),
                ),
              if (_debug) const Positioned(top: 64, left: 12, child: DebugOverlay()),
              Positioned(
                right: 12,
                bottom: 8,
                child: Text(
                  'OK or D: debug info · Back: leave',
                  style: text.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.amberAccent)),
    ),
  );
}

/// Connection state, live ping, input mode, stick or tilt values and the
/// last haptic event sent (PRD "Test game design": debug info).
class DebugOverlay extends ConsumerWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostStateProvider);
    final last = ref.watch(tvEventsProvider);
    final sounds = ref.watch(soundStatusProvider);
    final players = state.players;
    final rows = <(String, String)>[
      if (players.isEmpty) ('Controller', 'none connected'),
      for (final c in players) ...[
        ('P${c.player ?? '?'}', '${c.name} (${c.platform} ${c.appVersion}), ${_stateLabel(c.state)}'),
        (
          '  Ping',
          c.rttMs == null
              ? '–'
              : '${c.rttMs} ms (30 s avg ${c.rttStats?.avgMs ?? '–'}, max ${c.rttStats?.maxMs ?? '–'})',
        ),
        (
          '  Input delay',
          c.inputLatency == null ? '–' : '~${c.inputLatency!.avgMs} ms avg (± ${c.latencyErrorMs ?? '?'} ms)',
        ),
        ('  Mode', inputModeLabel(c.input)),
        ('  Values', inputValues(c.input)),
        (
          '  Buttons',
          c.input == null || c.input!.buttons.isEmpty
              ? '–'
              : c.input!.buttons.map((b) => b.name.toUpperCase()).join(' '),
        ),
      ],
      (
        'Last haptic',
        last == null
            ? '–'
            : '${last.message.event.name} (${last.source}), ${(last.message.intensity * 100).round()}%, '
                  '${last.message.durationMs} ms → ${last.reached}',
      ),
      (
        'Sounds',
        sounds.error != null ? 'off (${sounds.error})' : '${sounds.loaded} of ${HapticEvent.values.length} loaded',
      ),
    ];
    final text = Theme.of(context).textTheme;
    final mono = text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: Colors.white);
    return DecoratedBox(
      key: const Key('debugOverlay'),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth()},
            children: [
              for (final (label, value) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 2),
                      child: Text(label, style: mono?.copyWith(color: Colors.white60)),
                    ),
                    Text(value, style: mono),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every connected controller as a player in the game, in its player colour.
List<PlayerFeed> playerFeeds(HostViewState state) => [
  for (final (i, c) in state.players.indexed)
    (
      id: c.controllerId,
      number: c.player ?? i + 1,
      name: c.name,
      color: Color(playerColor(c.player ?? i + 1)),
      input: c.input,
    ),
];

String _stateLabel(ControllerState s) => switch (s) {
  ControllerState.connected => 'Connected',
  ControllerState.pairing => 'Waiting for code',
  ControllerState.disconnected => 'Disconnected',
};

String inputModeLabel(InputStateMessage? i) => i == null
    ? '–'
    : i.hasSticks
    ? 'Sticks'
    : i.hasAnalog
    ? 'Gyro'
    : 'D-pad';

String inputValues(InputStateMessage? i) {
  if (i == null) return '–';
  String f(double v) => v.toStringAsFixed(2);
  if (i.hasSticks) return 'L ${f(i.lx!)}, ${f(i.ly!)}   R ${f(i.rx!)}, ${f(i.ry!)}';
  if (i.hasAnalog) return 'Tilt x ${f(i.ax!)}  y ${f(i.ay!)}';
  return 'D-pad ${i.dx}, ${i.dy}';
}
