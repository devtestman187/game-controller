import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';

import '../controls.dart';
import '../local_player_source.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'player_badge.dart';
import 'puzzle_screen.dart';

part 'join_screen_widgets.dart';

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
/// from who joined. Simulated controllers join by themselves. On a desktop
/// the keyboard joins with Space and picks a side with the arrows.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.choice, this.teams = const {}, this.keyboard});

  final PuzzleChoice choice;

  /// The sides from the last match (Change teams), for players still here.
  final Map<String, PuzzleSide> teams;

  /// The local player, carried over from the last match.
  final LocalPlayerSource? keyboard;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());
  late final LocalPlayerSource _keyboard;
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
    _keyboard = widget.keyboard ?? ref.read(localPlayerSourceProvider)(ref.read(gameHostProvider), onJoined: _tick);
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
    var changed = _prune(players);
    for (final p in players) {
      if (p.simulated) {
        if (_simulatedJoin(p)) changed = true;
        continue;
      }
      final read = _read(host, p);
      if (read.changed) changed = true;
      // A or B may change the screen: nothing more this time.
      if (read.stop) return;
    }
    _showLayouts(host, players);
    if (changed) setState(() {});
  }

  /// Drops the players who left; true when a side lost a player.
  bool _prune(List<GamePlayer> players) {
    bool gone(String id) => !players.any((p) => p.id == id);
    _before.removeWhere((id, _) => gone(id));
    _labelled.removeWhere((id, _) => gone(id));
    if (!_teams.keys.any(gone)) return false;
    _teams.removeWhere((id, _) => gone(id));
    return true;
  }

  /// Simulated controllers press everything: they just join.
  bool _simulatedJoin(GamePlayer p) {
    final side = _teams.containsKey(p.id) ? null : sideForNewPlayer(_teams);
    if (side == null) return false;
    _teams[p.id] = side;
    return true;
  }

  /// Reads one phone's newly pressed buttons, each one through [_tap].
  ({bool changed, bool stop}) _read(GameHost host, GamePlayer p) {
    final now = _keysOf(host.gamepad(p.id));
    final before = _before[p.id];
    _before[p.id] = now;
    if (before == null) return (changed: false, stop: false);
    var changed = false;
    for (final key in now.difference(before)) {
      final tap = _tap(p, key);
      if (tap.changed) changed = true;
      if (tap.stop) return (changed: changed, stop: true);
    }
    return (changed: changed, stop: false);
  }

  /// What one newly pressed button does: A joins or begins, left and right
  /// pick a side, B leaves, Start begins.
  ({bool changed, bool stop}) _tap(GamePlayer p, _Key key) {
    final side = _teams[p.id];
    switch (key) {
      case _Key.a:
        // A joins; once joined, A begins the match, like Start (m11 device
        // test: A felt like the natural button).
        if (side != null) {
          _start();
          return (changed: false, stop: true);
        }
        final to = sideForNewPlayer(_teams);
        if (to == null) return (changed: false, stop: false);
        _teams[p.id] = to;
        return (changed: true, stop: false);
      case _Key.left || _Key.right:
        final to = key == _Key.left ? PuzzleSide.left : PuzzleSide.right;
        final hasRoom = _teams.values.where((s) => s == to).length < maxPerSide;
        if (side == null || side == to || !hasRoom) return (changed: false, stop: false);
        _teams[p.id] = to;
        return (changed: true, stop: false);
      case _Key.b:
        if (side != null) {
          _teams.remove(p.id);
          return (changed: true, stop: false);
        }
        if (p.local) return (changed: false, stop: false);
        Navigator.of(context).maybePop();
        return (changed: false, stop: true);
      case _Key.start:
        // Only a player who joined begins the match (m11 device test: a
        // phone that hadn't joined started it for the others).
        if (side == null) return (changed: false, stop: false);
        _start();
        return (changed: false, stop: true);
    }
  }

  /// Each phone shows what A does for it now: Join, or Start once joined.
  void _showLayouts(GameHost host, List<GamePlayer> players) {
    for (final p in players) {
      if (p.local) continue;
      final layout = _teams.containsKey(p.id) ? joinedLayout : joinLayout;
      if (!identical(_labelled[p.id], layout)) {
        _labelled[p.id] = layout;
        host.setLayout(p.id, layout);
      }
    }
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
                    _keyboard.available
                        ? 'Press A on your phone to join (Space on the keyboard), then left or right to pick a side. '
                              'Then A or Start begins.'
                        : 'Press A on your phone to join, then left or right to pick a side. Then A or Start begins.',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _Sides(players: players, teams: _teams),
                  ),
                  const SizedBox(height: 12),
                  if (watching.isNotEmpty) _NotJoined(watching: watching),
                  const SizedBox(height: 12),
                  _JoinButtons(teams: _teams, startFocus: _startFocus, onStart: _start),
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
