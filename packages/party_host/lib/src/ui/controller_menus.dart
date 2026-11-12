import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../controls.dart';
import '../text/host_text.dart';
import '../providers.dart';

/// The buttons while a menu is showing: A "OK" and B "Back".
final menuLayout = GameLayoutMessage(
  labels: {ControllerButton.a: HostText.ok, ControllerButton.b: HostText.back},
  hidden: {
    ControllerButton.x,
    ControllerButton.y,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// Says what the controllers do while this widget is on screen: a game
/// screen claims them while it plays, the pause menu limits the menus to
/// the players who may resume. The newest claim wins; it ends with the
/// widget.
class ControlsClaim extends ConsumerStatefulWidget {
  const ControlsClaim({super.key, required this.controls, required this.child});

  final Controls controls;
  final Widget child;

  @override
  ConsumerState<ControlsClaim> createState() => _ControlsClaimState();
}

class _ControlsClaimState extends ConsumerState<ControlsClaim> {
  late final ClaimHandle _claim;

  @override
  void initState() {
    super.initState();
    _claim = ref.read(controlsClaimsProvider).claim(widget.controls);
  }

  @override
  void didUpdateWidget(ControlsClaim oldWidget) {
    super.didUpdateWidget(oldWidget);
    _claim.controls = widget.controls;
  }

  @override
  void dispose() {
    _claim.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _Key { up, down, left, right, a, b }

/// Lets the players' phones work every screen of the host like the remote
/// (PRD v2 T21): the D-pad or the left stick moves the focus (held, it
/// repeats), A presses the focused button, B goes back. The phones show A
/// "OK" and B "Back". It pauses while a game claims the controllers
/// ([ControlsClaim]), ignores simulated controllers, and never leaves the
/// focus somewhere A can't press. A button already held when the menus come
/// back (the A that placed the last piece) has to be let go and pressed
/// again.
class ControllerMenus extends ConsumerStatefulWidget {
  const ControllerMenus({super.key, required this.child});

  final Widget child;

  /// How far the left stick must be pushed to count as a direction.
  static const stickPush = 0.6;

  /// How often the controllers are read.
  static const step = Duration(milliseconds: 16);

  /// A held direction repeats after this, then every [repeatEvery].
  static const repeatAfter = Duration(milliseconds: 450);
  static const repeatEvery = Duration(milliseconds: 150);

  @override
  ConsumerState<ControllerMenus> createState() => _ControllerMenusState();
}

class _ControllerMenusState extends ConsumerState<ControllerMenus> {
  late final Timer _timer = Timer.periodic(ControllerMenus.step, (_) => _tick());

  /// What each player held last time. A player seen for the first time
  /// counts as holding what they hold now, so nothing fires at once.
  final _before = <String, Set<_Key>>{};

  /// A held direction: which, and when it repeats next (in ms of [_clockMs]).
  final _repeat = <String, ({_Key key, int atMs})>{};

  /// The buttons each phone was given.
  final _labelled = <String, GameLayoutMessage>{};
  bool _active = false;
  int _clockMs = 0;

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

  static Set<_Key> _keysOf(GamepadState g) => {
    if (g.dpadY < 0 || g.leftY < -ControllerMenus.stickPush) _Key.up,
    if (g.dpadY > 0 || g.leftY > ControllerMenus.stickPush) _Key.down,
    if (g.dpadX < 0 || g.leftX < -ControllerMenus.stickPush) _Key.left,
    if (g.dpadX > 0 || g.leftX > ControllerMenus.stickPush) _Key.right,
    if (g.pressed(GamepadButton.a)) _Key.a,
    if (g.pressed(GamepadButton.b)) _Key.b,
  };

  void _tick() {
    if (!mounted) return;
    _clockMs += ControllerMenus.step.inMilliseconds;
    final controls = ref.read(controlsClaimsProvider).current;
    if (!controls.menus) {
      _active = false;
      return;
    }
    if (!_active) {
      // Back from a game: start afresh, and give every phone the menu's
      // buttons again.
      _active = true;
      _before.clear();
      _repeat.clear();
      _labelled.clear();
    }
    final host = ref.read(gameHostProvider);
    // A phone that is away keeps no menu layout (m12 bug 1107d): it would be
    // sent again on rejoin, over the game's own. A local player works the
    // menus only when the automation interface drives it (M15 a2); a
    // keyboard or touch player is the screens' own business, and a demo
    // simulated controller presses everything at once.
    final players = [
      for (final p in host.players)
        if (!p.simulated && !p.away && (!p.local || p.scripted)) p,
    ];
    _showLayout(host, players, controls.layout ?? menuLayout);
    for (final p in players) {
      // A or B may change the screen: nothing more this time.
      if (_read(host, p, controls.only)) return;
    }
  }

  /// Each phone gets the menu's buttons, or gets them back after a game.
  void _showLayout(GameHost host, List<GamePlayer> players, GameLayoutMessage layout) {
    for (final p in players) {
      if (!identical(_labelled[p.id], layout)) {
        _labelled[p.id] = layout;
        host.setLayout(p.id, layout);
      }
    }
    _forget(players);
  }

  /// Drops what the menus remembered about the phones that left.
  void _forget(List<GamePlayer> players) {
    bool gone(String id) => !players.any((p) => p.id == id);
    _labelled.removeWhere((id, _) => gone(id));
    _before.removeWhere((id, _) => gone(id));
    _repeat.removeWhere((id, _) => gone(id));
  }

  /// Reads one phone's buttons: a new press, and a held direction repeating.
  /// True when A or B was pressed, which may have changed the screen.
  bool _read(GameHost host, GamePlayer p, Set<String>? only) {
    final now = _keysOf(host.gamepad(p.id));
    final before = _before[p.id];
    _before[p.id] = now;
    if (before == null) return false;
    if (only != null && !only.contains(p.id)) return false;
    final pressed = now.difference(before);
    for (final key in pressed) {
      if (key == _Key.a || key == _Key.b) {
        _repeat.remove(p.id);
        _press(key);
        return true;
      }
      _repeat[p.id] = (key: key, atMs: _clockMs + ControllerMenus.repeatAfter.inMilliseconds);
      _press(key);
    }
    _repeatHeld(p.id, now, pressed);
    return false;
  }

  /// A direction still held, with nothing new pressed, repeats once it's due.
  void _repeatHeld(String id, Set<_Key> now, Set<_Key> pressed) {
    final held = _repeat[id];
    if (held == null || pressed.isNotEmpty) return;
    if (!now.contains(held.key)) {
      _repeat.remove(id);
    } else if (_clockMs >= held.atMs) {
      _repeat[id] = (key: held.key, atMs: _clockMs + ControllerMenus.repeatEvery.inMilliseconds);
      _press(held.key);
    }
  }

  /// Whether A would press something where the focus is.
  static bool _pressable(FocusNode? node) {
    final context = node?.context;
    return context != null && Actions.maybeFind<ActivateIntent>(context) != null;
  }

  /// Puts the focus on the first thing A can press on the top screen, if it
  /// isn't on one already.
  bool _focusSomethingPressable() {
    final focus = FocusManager.instance.primaryFocus;
    if (_pressable(focus)) return true;
    final scope = focus?.nearestScope ?? FocusManager.instance.rootScope;
    for (final node in scope.traversalDescendants) {
      if (_pressable(node)) {
        node.requestFocus();
        return true;
      }
    }
    return false;
  }

  void _press(_Key key) {
    // A pad is working the menus, so this host shows the focus look until a
    // thumb touches it (m12 bug 1107f rule A).
    ref.read(hostFocusLookProvider.notifier).padUsed();
    final focus = FocusManager.instance.primaryFocus;
    switch (key) {
      case _Key.up || _Key.down || _Key.left || _Key.right:
        if (!_pressable(focus)) {
          _focusSomethingPressable();
          return;
        }
        focus!.focusInDirection(switch (key) {
          _Key.up => TraversalDirection.up,
          _Key.down => TraversalDirection.down,
          _Key.left => TraversalDirection.left,
          _ => TraversalDirection.right,
        });
        // A direction never leaves the focus where A can't press.
        _focusSomethingPressable();
      case _Key.a:
        if (!_pressable(focus)) {
          _focusSomethingPressable();
          return;
        }
        Actions.maybeInvoke(focus!.context!, const ActivateIntent());
      case _Key.b:
        // The navigator of whatever has the focus: the screen or a dialog.
        final context = focus?.context;
        if (context != null) Navigator.maybeOf(context)?.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
