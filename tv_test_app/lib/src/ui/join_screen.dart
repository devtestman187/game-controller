import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../keyboard_player.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'latency_screen.dart' show PlayerBadge;
import 'puzzle_screen.dart';
import 'tv_button.dart';

/// The buttons on the join screen, before joining.
final joinLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'Join', ControllerButton.b: 'Back', ControllerButton.start: 'Start'},
  hidden: {ControllerButton.x, ControllerButton.y, ControllerButton.lb, ControllerButton.rb, ControllerButton.select},
);

/// Once joined: A or Start begins the match, B leaves the side.
final joinedLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'Start', ControllerButton.b: 'Leave', ControllerButton.start: 'Start'},
  hidden: {ControllerButton.x, ControllerButton.y, ControllerButton.lb, ControllerButton.rb, ControllerButton.select},
);

/// The most players on one side.
const maxPerSide = 2;

/// Where a joining player goes: the side with fewer players (left on a
/// tie), or null when both are full.
PuzzleSide? sideForNewPlayer(Map<String, PuzzleSide> teams) {
  final left = teams.values.where((s) => s == PuzzleSide.left).length;
  final right = teams.length - left;
  if (left >= maxPerSide && right >= maxPerSide) return null;
  if (left >= maxPerSide) return PuzzleSide.right;
  if (right >= maxPerSide) return PuzzleSide.left;
  return right < left ? PuzzleSide.right : PuzzleSide.left;
}

String formatName(MatchFormat format) => switch (format) {
  MatchFormat.solo => '1 player',
  MatchFormat.team => 'A team of 2 on one board',
  MatchFormat.oneVsOne => '1 vs 1',
  MatchFormat.twoVsOne => '2 vs 1',
  MatchFormat.twoVsTwo => '2 vs 2',
};

enum _Key { a, b, left, right, start }

/// The join screen (PRD v2 T13): players press A to join and push left or
/// right (the D-pad, the left stick or a tilt) to pick a side, at most two
/// a side. B leaves a side, or goes back for a player who hasn't joined.
/// Start (or the remote's OK on Start) begins the match; the format follows
/// from who joined. Simulated controllers join by themselves. On Windows
/// the keyboard joins with Space and picks a side with the arrows.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.choice, this.teams = const {}, this.keyboard});

  final PuzzleChoice choice;

  /// The sides from the last match (Change teams), for players still here.
  final Map<String, PuzzleSide> teams;

  /// The keyboard player, carried over from the last match.
  final KeyboardPlayer? keyboard;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());
  late final KeyboardPlayer _keyboard;
  late final _teams = Map<String, PuzzleSide>.of(widget.teams);
  final _before = <String, Set<_Key>>{};
  final _labelled = <String, GameLayoutMessage>{};
  bool _handedOver = false;
  final _startFocus = FocusNode(debugLabel: 'joinStart');

  @override
  void initState() {
    super.initState();
    // The screen's key handler takes the focus first, so the button's autofocus
    // would be ignored: move it to Start, for the remote's OK.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startFocus.requestFocus();
    });
    // Made here, not lazily: dispose() can't read providers any more.
    _keyboard = widget.keyboard ?? KeyboardPlayer(ref.read(gameHostProvider), onJoined: (_) => _tick());
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    _startFocus.dispose();
    if (!_handedOver) _keyboard.dispose();
    super.dispose();
  }

  static Set<_Key> _keysOf(GamepadState g) => {
    if (g.pressed(GamepadButton.a)) _Key.a,
    if (g.pressed(GamepadButton.b)) _Key.b,
    if (g.pressed(GamepadButton.start)) _Key.start,
    if (g.dpadX < 0 || g.leftX < -ControllerMenus.stickPush) _Key.left,
    if (g.dpadX > 0 || g.leftX > ControllerMenus.stickPush) _Key.right,
  };

  void _tick() {
    if (!mounted) return;
    final host = ref.read(gameHostProvider);
    final players = host.players;
    var changed = false;
    if (_teams.keys.any((id) => !players.any((p) => p.id == id))) {
      _teams.removeWhere((id, _) => !players.any((p) => p.id == id));
      changed = true;
    }
    _before.removeWhere((id, _) => !players.any((p) => p.id == id));
    _labelled.removeWhere((id, _) => !players.any((p) => p.id == id));
    for (final p in players) {
      if (p.simulated) {
        // Simulated controllers press everything: they just join.
        final side = _teams.containsKey(p.id) ? null : sideForNewPlayer(_teams);
        if (side != null) {
          _teams[p.id] = side;
          changed = true;
        }
        continue;
      }
      final now = _keysOf(host.gamepad(p.id));
      final before = _before[p.id];
      _before[p.id] = now;
      if (before == null) continue;
      for (final key in now.difference(before)) {
        final side = _teams[p.id];
        switch (key) {
          case _Key.a:
            // A joins; once joined, A begins the match, like Start (m11 device
            // test: A felt like the natural button).
            if (side != null) {
              _start();
              return;
            }
            final to = sideForNewPlayer(_teams);
            if (to != null) {
              _teams[p.id] = to;
              changed = true;
            }
          case _Key.left || _Key.right:
            final to = key == _Key.left ? PuzzleSide.left : PuzzleSide.right;
            if (side != null && side != to && _teams.values.where((s) => s == to).length < maxPerSide) {
              _teams[p.id] = to;
              changed = true;
            }
          case _Key.b:
            if (side != null) {
              _teams.remove(p.id);
              changed = true;
            } else if (!p.local) {
              Navigator.of(context).maybePop();
              return;
            }
          case _Key.start:
            // Only a player who joined begins the match (m11 device test: a
            // phone that hadn't joined started it for the others).
            if (side == null) continue;
            _start();
            return;
        }
      }
    }
    // Each phone shows what A does for it now: Join, or Start once joined.
    for (final p in players) {
      if (p.local) continue;
      final layout = _teams.containsKey(p.id) ? joinedLayout : joinLayout;
      if (!identical(_labelled[p.id], layout)) {
        _labelled[p.id] = layout;
        host.setLayout(p.id, layout);
      }
    }
    if (changed) setState(() {});
  }

  void _start() {
    if (_teams.isEmpty || _handedOver) return;
    _handedOver = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(choice: widget.choice, teams: Map.of(_teams), keyboard: _keyboard),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_keyboard.handle(event)) {
      _tick();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(gamePlayersProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final watching = [
      for (final p in players)
        if (!_teams.containsKey(p.id)) p,
    ];
    return ControlsClaim(
      controls: const Controls.game(),
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Shape Race · ${_choiceName(widget.choice, ref.watch(puzzleLibraryProvider).value)}'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    keyboardPlayerAvailable
                        ? 'Press A on your phone to join (Space on the keyboard), then left or right to pick a side. '
                              'Then A or Start begins.'
                        : 'Press A on your phone to join, then left or right to pick a side. Then A or Start begins.',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, side) in PuzzleSide.values.indexed) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(
                            child: _SidePanel(
                              key: Key('side-${side.name}'),
                              side: side,
                              players: [
                                for (final p in players)
                                  if (_teams[p.id] == side) p,
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (watching.isNotEmpty)
                    Text(
                      'Not joined: ${watching.map((p) => p.label).join(', ')}',
                      key: const Key('notJoined'),
                      style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TvButton(
                        key: const Key('joinStart'),
                        label: 'Start',
                        icon: Icons.play_arrow,
                        focusNode: _startFocus,
                        onPressed: _start,
                      ),
                      const SizedBox(width: 12),
                      TvButton(
                        key: const Key('joinBack'),
                        label: 'Back',
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          _teams.isEmpty
                              ? 'Nobody has joined yet.'
                              : '${formatName(MatchFormat.of(_teams))}. Press A or Start to begin.',
                          key: const Key('joinFormat'),
                          style: _teams.isEmpty
                              ? text.titleMedium
                              : text.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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

String _choiceName(PuzzleChoice choice, PuzzleLibrary? library) {
  final level = switch (choice.level) {
    Level.easy => 'Easy',
    Level.medium => 'Medium',
    Level.hard => 'Hard',
  };
  final id = choice.puzzleId;
  return id == null ? 'any $level puzzle' : library?.byId(id)?.name ?? level;
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({super.key, required this.side, required this.players});

  final PuzzleSide side;
  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              side == PuzzleSide.left ? '◀ Left' : 'Right ▶',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final p in players)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    PlayerBadge(number: p.number, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${p.label}${p.simulated ? ' (simulated)' : ''}',
                        style: text.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (players.length < maxPerSide)
              Text('Room for ${maxPerSide - players.length} more', style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}
