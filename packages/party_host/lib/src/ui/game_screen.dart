import 'dart:async';

import 'package:game_assets/asset_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:test_game/test_game.dart';
import 'package:toy_look/toy_look.dart';

import '../abandon_signal.dart';
import '../controls.dart';
import '../text/host_text.dart';
import '../local_player_source.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'pause_menu.dart';
import 'play_hint.dart';

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

/// How long the Arena's hint shows at the start of a round.
const _hintShownFor = Duration(seconds: 5);

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _debug = false;

  /// The hint shows for the round's first [_hintShownFor] and then goes, so
  /// it is never over the arena in play (owner, Nov 8, 2026: text over a game
  /// in progress "should not happen"). M14's waiting card takes it over.
  bool _hintShown = true;
  Timer? _hintTimer;
  late final LocalPlayerSource _keyboard;

  /// How this round runs (m12 §3): its frame rate, read when the round starts
  /// so a change of the setting waits for the next one.
  late final HostingSettings _hosting;

  @override
  void initState() {
    super.initState();
    _hosting = ref.read(hostingSettingsProvider);
    _hintTimer = Timer(_hintShownFor, () {
      if (mounted) setState(() => _hintShown = false);
    });
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
    _hintTimer?.cancel();
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
    final hint = _keyboard.available && !_keyboard.hasPlayer ? HostText.arenaHintKeyboard : HostText.arenaHint;
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
                  ArenaView(
                    game: widget.game,
                    host: ref.read(gameHostProvider),
                    settings: _hosting,
                    onEvent: _onEvent,
                    paused: paused,
                    abandon: ref.read(hostAbandonProvider),
                  ),
                  if (nobody)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _noteBottomPx,
                      child: Center(
                        child: _Note(_keyboard.available ? HostText.noControllerKeys : HostText.noController),
                      ),
                    ),
                  if (_debug) const Positioned(top: _debugTopPx, left: ToySizes.space12, child: DebugOverlay()),
                  if (_hintShown) Positioned(right: ToySizes.space12, bottom: ToySizes.space8, child: PlayHint(hint)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far above the bottom edge the arena's note sits, clear of the sprites'
/// play area.
const _noteBottomPx = 48.0;

/// How far from the top edge the debug overlay sits, under the title bars.
const _debugTopPx = 64.0;

/// How wide the debug overlay may grow before its values wrap: wide enough for
/// a latency and a haptic event on one line.
const _debugWidthPx = 460.0;

/// The arena's note on a paper card (M13 3b): "No controller connected" in ink
/// over the board, where the old black box used to be.
class _Note extends StatelessWidget {
  const _Note(this.message);

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
                (last.message.intensity * 100).round(),
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
