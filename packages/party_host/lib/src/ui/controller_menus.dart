import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../providers.dart';

/// What the players' controllers do right now: work the host app's menus like
/// the remote (PRD v2 T21), or play a game, which reads them itself.
final class Controls {
  /// Every screen's menus, for everyone, or only for the players in [only]
  /// (the pause menu: the player who paused and Player 1). [layout] replaces
  /// the usual menu buttons on the phones.
  const Controls.menus({this.only, this.layout}) : menus = true;

  /// A game is reading the controllers.
  const Controls.game() : menus = false, only = null, layout = null;

  final bool menus;
  final Set<String>? only;
  final GameLayoutMessage? layout;
}

/// The buttons while a menu is showing: A "OK" and B "Back".
final menuLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'OK', ControllerButton.b: 'Back'},
  hidden: {
    ControllerButton.x,
    ControllerButton.y,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// The screens' claims on the controllers, newest on top. With none, they
/// work the menus.
class ControlsClaims {
  final _claims = <_Claim>[];

  Controls get current => _claims.lastOrNull?.controls ?? const Controls.menus();
}

class _Claim {
  _Claim(this.controls);

  Controls controls;
}

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
  late final ControlsClaims _claims = ref.read(controlsClaimsProvider);
  late final _Claim _claim = _Claim(widget.controls);

  @override
  void initState() {
    super.initState();
    _claims._claims.add(_claim);
  }

  @override
  void didUpdateWidget(ControlsClaim oldWidget) {
    super.didUpdateWidget(oldWidget);
    _claim.controls = widget.controls;
  }

  @override
  void dispose() {
    _claims._claims.remove(_claim);
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
    final players = [
      for (final p in host.players)
        if (!p.simulated && !p.local) p,
    ];
    final layout = controls.layout ?? menuLayout;
    for (final p in players) {
      if (!identical(_labelled[p.id], layout)) {
        _labelled[p.id] = layout;
        host.setLayout(p.id, layout);
      }
    }
    _labelled.removeWhere((id, _) => !players.any((p) => p.id == id));
    _before.removeWhere((id, _) => !players.any((p) => p.id == id));
    _repeat.removeWhere((id, _) => !players.any((p) => p.id == id));

    final only = controls.only;
    for (final p in players) {
      final now = _keysOf(host.gamepad(p.id));
      final before = _before[p.id];
      _before[p.id] = now;
      if (before == null) continue;
      if (only != null && !only.contains(p.id)) continue;
      final pressed = now.difference(before);
      for (final key in pressed) {
        if (key == _Key.a || key == _Key.b) {
          _repeat.remove(p.id);
          _press(key);
          // A or B may change the screen: nothing more this time.
          return;
        }
        _repeat[p.id] = (key: key, atMs: _clockMs + ControllerMenus.repeatAfter.inMilliseconds);
        _press(key);
      }
      final held = _repeat[p.id];
      if (held != null && pressed.isEmpty) {
        if (!now.contains(held.key)) {
          _repeat.remove(p.id);
        } else if (_clockMs >= held.atMs) {
          _repeat[p.id] = (key: held.key, atMs: _clockMs + ControllerMenus.repeatEvery.inMilliseconds);
          _press(held.key);
        }
      }
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
