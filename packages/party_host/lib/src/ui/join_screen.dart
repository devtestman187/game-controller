import 'dart:async';
import 'dart:math' as math;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:toy_look/toy_look.dart';

import '../controls.dart';
import '../text/host_text.dart';
import '../local_player_source.dart';
import '../providers.dart';
import 'controller_menus.dart';
import 'host_button.dart';
import 'host_screen.dart';
import 'play_hint.dart';
import 'puzzle_screen.dart';

part 'join_screen_widgets.dart';

/// The buttons a phone never shows on this screen.
const _hidden = {
  ControllerButton.x,
  ControllerButton.y,
  ControllerButton.lb,
  ControllerButton.rb,
  ControllerButton.select,
};

/// The labels of the buttons on the join screen, before joining.
const _joinLabels = {
  ControllerButton.a: HostText.join,
  ControllerButton.b: HostText.back,
  ControllerButton.start: HostText.start,
};

/// The labels once joined: A or Start begins the match, B leaves the side.
const _joinedLabels = {
  ControllerButton.a: HostText.start,
  ControllerButton.b: HostText.leave,
  ControllerButton.start: HostText.start,
};

/// The buttons on the join screen, before joining.
final joinLayout = GameLayoutMessage(labels: _joinLabels, hidden: _hidden);

/// The buttons once joined: A or Start begins the match, B leaves the side.
final joinedLayout = GameLayoutMessage(labels: _joinedLabels, hidden: _hidden);

/// The most players on one side.
const maxPerSide = 2;

/// The join screen's gaps: under the hint, around the sides, and both where
/// the phone's own bar is above (bug 1107f).
const _hintGapPx = 16.0;
const _gapPx = 12.0;
const _tightGapPx = 8.0;

/// The room inside a side's panel, and where the phone's own bar is above.
const _panelPaddingPx = 16.0;
const _tightPanelPaddingPx = 12.0;

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

/// The format the joined players make: [HostText.formatName]'s words (M13 3b:
/// the screen's texts moved to the string table).
String formatName(MatchFormat format) => HostText.formatName(format);

enum _Key { a, b, left, right, start }

/// The join screen (PRD v2 T13): players press A to join and push left or
/// right (the D-pad, the left stick or a tilt) to pick a side, at most two
/// a side. B leaves a side, or goes back for a player who hasn't joined.
/// Start (or the remote's OK on Start) begins the match; the format follows
/// from who joined. Simulated controllers join by themselves. On a desktop
/// the keyboard joins with Space and picks a side with the arrows.
///
/// The phone that hosts has no pad here (m12-host-touch rules 1, 5): its own
/// player joins by itself and a tap on a side picks or moves it.
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
    // A phone that is away isn't listed and keeps no team (m12 bug 1107d).
    final players = [
      for (final p in host.players)
        if (!p.away) p,
    ];
    var changed = _prune(players);
    if (_ownJoin(players)) changed = true;
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

  /// The host phone's own player joins by itself (m12-host-touch rule 5): it
  /// takes a side whenever it is here and has none, so a phone back from away
  /// joins again. Only a missing side is filled, so a tap's choice stands; a
  /// TV has no own player and nothing happens.
  bool _ownJoin(List<GamePlayer> players) {
    final own = _ownPlayer;
    if (own == null || _teams.containsKey(own) || !players.any((p) => p.id == own)) return false;
    final side = sideForNewPlayer(_teams);
    if (side == null) return false;
    _teams[own] = side;
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

  /// The host phone's own player, when it plays here: in "Play on this
  /// phone", which shares the view. In "Show on this device" the phone is the
  /// screen, so its own player never takes a side (m12-host-touch rule 5).
  String? get _ownPlayer => ref.read(hostServiceProvider).shareView ? ref.watch(ownPlayerIdProvider) : null;

  /// A tap picks a side for the host phone's own player (m12-host-touch rule
  /// 5): only its own, and only when that side has room.
  void _pickSide(String id, PuzzleSide side) {
    final taken = _teams.values.where((s) => s == side).length;
    if (_teams[id] == side || taken >= maxPerSide) return;
    setState(() => _teams[id] = side);
  }

  /// What the screen tells the players. On the host phone a tap is the way in
  /// (m12-host-touch rule 5); on a TV or a joined phone it is still the pad's.
  static String _hint({required bool hasOwnPlayer, required bool hasKeyboard}) {
    if (hasOwnPlayer) return HostText.hintOwnPlayer;
    return hasKeyboard ? HostText.hintWithKeyboard : HostText.hint;
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

  /// "Shape Race · House": the game and the puzzle picked.
  String _title() =>
      HostText.titled(HostText.shapeRace, _choiceName(widget.choice, ref.watch(puzzleLibraryProvider).value));

  @override
  Widget build(BuildContext context) {
    // A phone that is away isn't listed on this screen (m12 bug 1107d).
    final players = [
      for (final p in ref.watch(gamePlayersProvider))
        if (!p.away) p,
    ];
    final look = ToyLookScope.of(context);
    final watching = [
      for (final p in players)
        if (!_teams.containsKey(p.id)) p,
    ];
    final own = _ownPlayer;
    final ownHere = own != null && players.any((p) => p.id == own) ? own : null;
    // Under the phone's own bar the screen is short: tighter gaps and panels,
    // so a side with the own player fits without scrolling (bug 1107f).
    final barHeight = ref.watch(hostBarHeightProvider);
    final tight = barHeight > 0;
    return ControlsClaim(
      controls: const Controls.game(),
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: HostScreen(
          title: _title(),
          body: SafeArea(
            child: Padding(
              padding: hostMenuPadding(barHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _hint(hasOwnPlayer: ownHere != null, hasKeyboard: _keyboard.available),
                    style: look.type.button.copyWith(color: look.colors.onBackground),
                  ),
                  SizedBox(height: tight ? _tightGapPx : _hintGapPx),
                  Expanded(
                    child: _Sides(
                      players: players,
                      teams: _teams,
                      ownPlayerId: ownHere,
                      tight: tight,
                      onPick: ownHere == null ? null : (side) => _pickSide(ownHere, side),
                    ),
                  ),
                  SizedBox(height: tight ? _tightGapPx : _gapPx),
                  if (watching.isNotEmpty) _NotJoined(watching: watching),
                  SizedBox(height: tight ? _tightGapPx : _gapPx),
                  _JoinButtons(teams: _teams, ownPlayerId: ownHere, startFocus: _startFocus, onStart: _start),
                  if (!tight) _RoundHint(keyboard: _keyboard),
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
  final level = HostText.level(choice.level);
  final id = choice.puzzleId;
  return id == null ? HostText.anyPuzzleTitle(level) : library?.byId(id)?.name ?? level;
}
