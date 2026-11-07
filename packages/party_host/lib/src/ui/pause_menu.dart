import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../abandon_signal.dart';
import '../controls.dart';
import '../host_presence.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'games_screen.dart';
import 'host_button.dart';
import 'player_badge.dart';

/// The buttons while the game is paused: the menu, and Start to resume.
final pauseLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'OK', ControllerButton.b: 'Resume', ControllerButton.start: 'Resume'},
  hidden: {ControllerButton.x, ControllerButton.y, ControllerButton.lb, ControllerButton.rb, ControllerButton.select},
);

/// Pausing with Start, for any game (PRD v2 M11): any player's Start pauses
/// the game for everyone and opens the pause menu (Resume, Quit). Only the
/// player who paused and Player 1 can work it, or press Start again to
/// resume, so Player 1 can always override a pause. If neither is here any
/// more, anyone can. Quit leaves the game for the game picker. Only the
/// game's [players] can pause (not someone watching), simulated controllers
/// never do, and Start does nothing for the first [startGrace] of a game, so
/// the press that began it can't pause it. [builder] gets whether the game is
/// paused.
///
/// The game is paused too while the host app is away (m12 §2.10): the
/// builder gets `paused == true` and no menu opens, so the app comes back to
/// the game where it left it.
class Pausable extends ConsumerStatefulWidget {
  const Pausable({super.key, required this.enabled, required this.builder, this.players});

  /// Start pauses only while this is true (not on the results).
  final bool enabled;

  /// Who can pause: the players in the game. Null: everyone (the Arena).
  final Set<String>? players;

  /// Start is ignored this long after the game starts.
  static const startGrace = Duration(milliseconds: 500);
  final Widget Function(BuildContext context, bool paused) builder;

  @override
  ConsumerState<Pausable> createState() => _PausableState();
}

class _PausableState extends ConsumerState<Pausable> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());

  /// Whether each player held Start last time; a new player counts as
  /// holding what they hold now.
  final _startDown = <String, bool>{};
  GamePlayer? _pausedBy;
  BuildContext? _menuContext;
  int _sinceStartMs = 0;

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Who may resume: the player who paused and Player 1, or anyone if
  /// neither is here.
  Set<String>? _resumers(List<GamePlayer> players) {
    final by = _pausedBy;
    final ids = {
      for (final p in players)
        if (p.id == by?.id || p.number == 1) p.id,
    };
    return ids.isEmpty ? null : ids;
  }

  void _tick() {
    // Away, the app is hidden: the game is paused as it is, and nothing
    // opens a menu behind it.
    if (!mounted || ref.read(hostAwayProvider).value) return;
    _sinceStartMs += ControllerMenus.step.inMilliseconds;
    final players = [
      for (final p in ref.read(gameHostProvider).players)
        if (!p.simulated && !p.local) p,
    ];
    final host = ref.read(gameHostProvider);
    final pressed = <GamePlayer>[];
    for (final p in players) {
      final down = host.gamepad(p.id).pressed(GamepadButton.start);
      final before = _startDown[p.id];
      _startDown[p.id] = down;
      if (before == false && down) pressed.add(p);
    }
    _startDown.removeWhere((id, _) => !players.any((p) => p.id == id));
    if (pressed.isEmpty) return;
    final menu = _menuContext;
    if (_pausedBy == null) {
      final can = widget.players;
      final by = pressed.where((p) => can == null || can.contains(p.id)).firstOrNull;
      if (widget.enabled && by != null && _sinceStartMs >= Pausable.startGrace.inMilliseconds) _pause(by);
    } else if (menu != null) {
      final resumers = _resumers(players);
      if (resumers == null || pressed.any((p) => resumers.contains(p.id))) Navigator.of(menu).pop();
    }
  }

  Future<void> _pause(GamePlayer by) async {
    setState(() => _pausedBy = by);
    final quit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _menuContext = context;
        return _PauseMenu(pausedBy: by, resumers: _resumers);
      },
    );
    _menuContext = null;
    if (!mounted) return;
    setState(() => _pausedBy = null);
    if (quit == true) leaveForGamePicker(context);
  }

  @override
  Widget build(BuildContext context) {
    final away = ref.watch(hostAwayProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: away,
      builder: (context, hidden, _) => widget.builder(context, _pausedBy != null || hidden),
    );
  }
}

/// Goes back to the game picker (or the main screen, if the game was opened
/// from somewhere else).
void leaveForGamePicker(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.settings.name == gamesRouteName || r.isFirst);

/// Ends the round the host can't show any more (m12 §2.10): the session
/// records it and ends its view `abandoned`, then this goes back to the game
/// picker. Quit in the pause menu goes back the same way, but a quit round
/// ends its view `quit`: the players chose to stop.
void abandonRound(BuildContext context) {
  ProviderScope.containerOf(context, listen: false).read(hostAbandonProvider).fire();
  leaveForGamePicker(context);
}

class _PauseMenu extends ConsumerWidget {
  const _PauseMenu({required this.pausedBy, required this.resumers});

  final GamePlayer pausedBy;
  final Set<String>? Function(List<GamePlayer> players) resumers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = [
      for (final p in ref.watch(gamePlayersProvider))
        if (!p.simulated && !p.local) p,
    ];
    final only = resumers(players);
    final text = Theme.of(context).textTheme;
    final who = pausedBy.number == 1 ? 'P1' : 'P${pausedBy.number} or P1';
    return ControlsClaim(
      controls: Controls.menus(only: only, layout: pauseLayout),
      child: AlertDialog(
        key: const Key('pauseMenu'),
        title: Row(
          children: [
            PlayerBadge(number: pausedBy.number, size: 30),
            const SizedBox(width: 12),
            const Text('Paused'),
          ],
        ),
        content: Text(
          only == null ? 'Anyone can resume.' : '$who can resume, with Start or Resume.',
          style: text.titleMedium,
        ),
        actions: [
          HostButton(
            key: const Key('pauseQuit'),
            label: 'Quit',
            icon: Icons.exit_to_app,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          HostButton(
            key: const Key('pauseResume'),
            label: 'Resume',
            icon: Icons.play_arrow,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
