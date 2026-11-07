import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart';

import '../pad.dart';
import '../phone_metrics.dart';
import '../sticks.dart';
import 'connection.dart';
import 'feedback.dart';
import 'haptics.dart';
import 'metrics.dart';

final padProvider = NotifierProvider<PadNotifier, PadInput>(PadNotifier.new);

/// The pad's input: tracks fingers, sends every change to the TV and plays a
/// tick for every press, release and direction change.
class PadNotifier extends Notifier<PadInput> {
  final _tracker = PadTracker();

  @override
  PadInput build() {
    // Start the capability check before the first tick. Listening (not
    // watching) keeps it alive without rebuilding this notifier when it
    // finishes.
    ref.listen(hapticsCapabilitiesProvider, (_, _) {});
    // A cancelled cooldown must also be cleared: if it stayed set, every
    // later stick or tilt move would wait for a timer that never fires, and
    // only buttons would reach the TV (found on the Pixel Tablet in M8).
    ref.onDispose(() {
      _cooldown?.cancel();
      _cooldown = null;
      _pending = false;
    });
    return _tracker.current;
  }

  void dpad(int pointer, (int, int) direction) => _apply(_tracker.dpad(pointer, direction));

  void button(int pointer, ControllerButton? button) {
    // A finger that was on a button and is now on none slid off it (M9).
    final before = _tracker.buttonUnder(pointer);
    if (before != null && button == null) ref.read(phoneMetricsProvider).slideOff(before.name);
    _apply(_tracker.button(pointer, button));
  }

  void up(int pointer) => _apply(_tracker.up(pointer));

  /// Called when the app leaves the foreground, so nothing stays held.
  void releaseAll() {
    _leftTouched = false;
    _rightTouched = false;
    _apply(_tracker.releaseAll());
  }

  /// Gyro tilt from gyro mode (about 60 per second).
  void tilt(double ax, double ay) {
    ref.read(phoneMetricsProvider).tilt(ax, ay);
    _apply(_tracker.tilt(ax, ay));
  }

  /// A stick moved, or was let go ([stickCenter], [touched] false).
  void stick(StickSide side, Stick value, {bool touched = true}) {
    final left = side == StickSide.left;
    if (left) {
      _leftTouched = touched;
    } else {
      _rightTouched = touched;
    }
    ref.read(phoneMetricsProvider).stick(left ? 'ls' : 'rs', value.x, value.y, touched: touched);
    _apply(_tracker.stick(side, value), force: true);
  }

  bool _leftTouched = false;
  bool _rightTouched = false;

  /// A new mode starts: nothing from the old layout stays held.
  void switchMode({required bool tilt, required bool sticks}) {
    _leftTouched = false;
    _rightTouched = false;
    _apply(_tracker.switchMode(tilt: tilt, sticks: sticks));
  }

  /// At most one send per [analogInterval] for stick and tilt movement.
  static const analogInterval = Duration(milliseconds: 16);
  Timer? _cooldown;
  bool _pending = false;

  void _apply(PadChange change, {bool force = false}) {
    if (!change.changed) {
      if (force) _recordHeld(change.after);
      return;
    }
    state = change.after;
    _recordHeld(change.after);
    final strength = change.tickStrength;
    if (strength > 0) unawaited(ref.read(hapticsPlayerProvider).tick(strength: strength));
    // The optional click (v2 C33): presses and new directions, not releases.
    if (strength == 1 && ref.read(pressFeedbackProvider).click) ref.read(clickSoundProvider)();

    // Buttons, the D-pad, mode changes and a stick returning to center go
    // out at once. Analog movement is capped at about 60 per second, always
    // sending the latest value.
    final before = change.before;
    final after = change.after;
    final onlyAnalogMoved =
        strength == 0 &&
        before.buttons.length == after.buttons.length &&
        (before.ax == null) == (after.ax == null) &&
        (before.left == null) == (after.left == null) &&
        !_recentered(before.left, after.left) &&
        !_recentered(before.right, after.right);
    if (!onlyAnalogMoved) {
      _send();
    } else if (_cooldown == null) {
      _send();
    } else {
      _pending = true;
    }
  }

  /// What is held, for the touch metrics (M9).
  void _recordHeld(PadInput input) => ref
      .read(phoneMetricsProvider)
      .held(
        heldControls(
          input.buttons,
          dpad: input.dx != 0 || input.dy != 0,
          left: _leftTouched && input.left != null,
          right: _rightTouched && input.right != null,
        ),
      );

  static bool _recentered(Stick? before, Stick? after) => after == stickCenter && before != stickCenter;

  void _send() {
    _pending = false;
    final a = state;
    ref.read(clientProvider).sendInput(a.buttons, dx: a.dx, dy: a.dy, ax: a.ax, ay: a.ay, left: a.left, right: a.right);
    _cooldown ??= Timer(analogInterval, () {
      _cooldown = null;
      if (_pending) _send();
    });
  }
}
