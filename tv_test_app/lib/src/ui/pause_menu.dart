import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';
import 'controller_menus.dart';
import 'games_screen.dart';
import 'latency_screen.dart' show PlayerBadge;
import 'tv_button.dart';

/// The buttons while the game is paused: the menu, and Start to resume.
final pauseLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'OK', ControllerButton.b: 'Resume', ControllerButton.start: 'Resume'},
  hidden: {ControllerButton.x, ControllerButton.y, ControllerButton.lb, ControllerButton.rb, ControllerButton.select},
);

/// Pausing with Start, for any game (PRD v2 M11): any player's Start pauses
/// the game for everyone and opens the pause menu (Resume, Quit). Only the
/// player who paused and Player 1 can work it, or press Start again to
/// resume, so Player 1 can always override a pause. If neither is here any
/// more, anyone can. Quit leaves the game for the game picker. Simulated
/// controllers never pause. [builder] gets whether the game is paused.
class Pausable extends ConsumerStatefulWidget {
  const Pausable({super.key, required this.enabled, required this.builder});

  /// Start pauses only while this is true (not on the results).
  final bool enabled;
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
    if (!mounted) return;
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
      if (widget.enabled) _pause(pressed.first);
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
  Widget build(BuildContext context) => widget.builder(context, _pausedBy != null);
}

/// Goes back to the game picker (or the main screen, if the game was opened
/// from somewhere else).
void leaveForGamePicker(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.settings.name == gamesRouteName || r.isFirst);

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
          TvButton(
            key: const Key('pauseQuit'),
            label: 'Quit',
            icon: Icons.exit_to_app,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          TvButton(
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
