import 'package:connection/connection.dart';
import 'package:game_assets/asset_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_game/test_game.dart';

import '../controls.dart';
import '../local_player_source.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'pause_menu.dart';

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

/// The playable test (PRD T7): the arena, where every player drives their
/// own sprite in their player colour (T9). It runs through the game host
/// interface (PRD v2 P3), like every game. Each game event goes as a haptic
/// event to the controller whose sprite caused it, and plays as a sound on
/// the host. On a desktop, the arrow keys and Space add a keyboard player.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, this.game});

  /// The game to run. Tests pass one in.
  final ArenaGame? game;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _debug = false;
  late final LocalPlayerSource _keyboard;

  @override
  void initState() {
    super.initState();
    // Made here, not lazily: dispose() can't read providers any more.
    final log = ref.read(logProvider);
    _keyboard = ref.read(localPlayerSourceProvider)(
      ref.read(gameHostProvider),
      onJoined: () {
        // The player joined the host a moment ago; its number names it here.
        final who = ref.read(gameHostProvider).players.where((p) => p.local).lastOrNull;
        log.add('game', 'Keyboard player joined${who == null ? '' : ' as P${who.number}'}');
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _keyboard.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_keyboard.handle(event)) return KeyEventResult.handled;
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

  /// The arena already buzzed the phone and played the sound through the
  /// game host (S5): this only notes it for the log and the debug overlay.
  void _onEvent(GameEvent e) {
    final who = ref.read(gamePlayersProvider).where((p) => p.id == e.playerId).firstOrNull;
    ref
        .read(tvEventsProvider.notifier)
        .note(
          e.toMessage(),
          source: 'game: ${e.cause.name}${who == null ? '' : ', P${who.number}'}',
          reached: who == null || who.local ? 0 : 1,
        );
  }

  @override
  Widget build(BuildContext context) {
    final nobody = ref.watch(gamePlayersProvider.select((p) => p.isEmpty));
    final text = Theme.of(context).textTheme;
    final hint = _keyboard.available && !_keyboard.hasPlayer
        ? 'Arrows and Space: play on the keyboard · D: debug info · Esc: leave'
        : 'OK or D: debug info · Start on a phone: pause · Back: leave';
    // The game reads the controllers (no menus); Start pauses (M11).
    return ControlsClaim(
      controls: const Controls.game(),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: SafeArea(
            child: Pausable(
              enabled: true,
              builder: (context, paused) => Stack(
                children: [
                  ArenaView(game: widget.game, host: ref.read(gameHostProvider), onEvent: _onEvent, paused: paused),
                  if (nobody)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 48,
                      child: Center(
                        child: _Note(
                          _keyboard.available
                              ? 'No controller connected. Pair a phone on the main screen, or press an arrow key.'
                              : 'No controller connected. Pair a phone on the main screen.',
                        ),
                      ),
                    ),
                  if (_debug) const Positioned(top: 64, left: 12, child: DebugOverlay()),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: Text(hint, style: text.bodySmall?.copyWith(color: Colors.white60)),
                  ),
                ],
              ),
            ),
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
      if (players.isEmpty) ('Controller', 'none connected'),
      for (final p in players) ...[
        ('P${p.number}', '${p.nickname ?? ''}${p.local ? ' (on this device)' : ''}'),
        if (host.latency(p.id) case final l?) ...[
          (
            '  Ping',
            l.pingNowMs == null
                ? '–'
                : '${l.pingNowMs} ms (30 s avg ${l.ping?.avgMs ?? '–'}, max ${l.ping?.maxMs ?? '–'})',
          ),
          ('  Input delay', l.inputDelay == null ? '–' : '~${l.inputDelay!.avgMs} ms avg (± ${l.errorMs ?? '?'} ms)'),
        ],
        ('  Mode', modeLabel(p.mode)),
        ('  Values', gamepadValues(host.gamepad(p.id))),
        ('  Buttons', gamepadButtons(host.gamepad(p.id))),
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
        sounds.error != null ? 'off (${sounds.error})' : '${sounds.loaded} of ${SoundKey.values.length} loaded',
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

String modeLabel(InputMode mode) => switch (mode) {
  InputMode.dpad => 'D-pad',
  InputMode.gyro => 'Gyro',
  InputMode.sticks => 'Sticks',
  InputMode.keyboard => 'Keyboard',
  InputMode.none => '–',
};

String gamepadValues(GamepadState g) {
  String f(double v) => v.toStringAsFixed(2);
  return switch (g.mode) {
    InputMode.sticks => 'L ${f(g.leftX)}, ${f(g.leftY)}   R ${f(g.rightX)}, ${f(g.rightY)}',
    InputMode.gyro => 'Tilt x ${f(g.tiltX ?? g.leftX)}  y ${f(g.tiltY ?? g.leftY)}',
    InputMode.none => '–',
    _ => 'D-pad ${g.dpadX}, ${g.dpadY}',
  };
}

String gamepadButtons(GamepadState g) {
  final names = [
    for (final b in g.buttons)
      if (!b.name.startsWith('dpad')) b.name.toUpperCase(),
  ];
  return names.isEmpty ? '–' : names.join(' ');
}
