import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Lets the players' phones work a TV menu like the remote: the D-pad or
/// the left stick moves the focus, A presses the focused button and B goes
/// back. Only while [enabled]; a button already held when it turns on (the
/// A that dropped the last piece) has to be let go and pressed again.
class GamepadMenu extends ConsumerStatefulWidget {
  const GamepadMenu({super.key, required this.enabled, required this.onBack, required this.child});

  final bool enabled;
  final VoidCallback onBack;
  final Widget child;

  /// How far the left stick must be pushed to count as a direction.
  static const stickPush = 0.6;

  @override
  ConsumerState<GamepadMenu> createState() => _GamepadMenuState();
}

enum _Key { up, down, left, right, a, b }

class _GamepadMenuState extends ConsumerState<GamepadMenu> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _tick());

  /// What each player held last frame. A player seen for the first time
  /// counts as holding what they hold now, so nothing fires at once.
  final _before = <String, Set<_Key>>{};

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(GamepadMenu old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ticker.isActive) {
      _before.clear();
      _ticker.start();
    } else if (!widget.enabled && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  static Set<_Key> _keysOf(GamepadState g) => {
    if (g.dpadY < 0 || g.leftY < -GamepadMenu.stickPush) _Key.up,
    if (g.dpadY > 0 || g.leftY > GamepadMenu.stickPush) _Key.down,
    if (g.dpadX < 0 || g.leftX < -GamepadMenu.stickPush) _Key.left,
    if (g.dpadX > 0 || g.leftX > GamepadMenu.stickPush) _Key.right,
    if (g.pressed(GamepadButton.a)) _Key.a,
    if (g.pressed(GamepadButton.b)) _Key.b,
  };

  void _tick() {
    final host = ref.read(gameHostProvider);
    final players = host.players;
    _before.removeWhere((id, _) => !players.any((p) => p.id == id));
    for (final p in players) {
      final now = _keysOf(host.gamepad(p.id));
      final before = _before[p.id];
      _before[p.id] = now;
      if (before == null) continue;
      for (final key in now.difference(before)) {
        if (!mounted || !widget.enabled) return;
        _press(key);
        // A or B may leave the screen: nothing more this frame.
        if (key == _Key.a || key == _Key.b) return;
      }
    }
  }

  void _press(_Key key) {
    final focus = FocusManager.instance.primaryFocus;
    switch (key) {
      case _Key.up:
        focus?.focusInDirection(TraversalDirection.up);
      case _Key.down:
        focus?.focusInDirection(TraversalDirection.down);
      case _Key.left:
        focus?.focusInDirection(TraversalDirection.left);
      case _Key.right:
        focus?.focusInDirection(TraversalDirection.right);
      case _Key.a:
        final context = focus?.context;
        if (context != null) Actions.maybeInvoke(context, const ActivateIntent());
      case _Key.b:
        widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
