import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart';

/// What the on-screen pad is pressing right now.
final class PadInput {
  const PadInput({this.buttons = const {}, this.dx = 0, this.dy = 0, this.ax, this.ay});

  final Set<ControllerButton> buttons;

  /// D-pad: -1 left / up, 1 right / down.
  final int dx;
  final int dy;

  /// Gyro tilt from -1 to 1 (y: -1 forward), null outside gyro mode.
  final double? ax;
  final double? ay;

  bool get isNeutral => buttons.isEmpty && dx == 0 && dy == 0 && (ax ?? 0) == 0 && (ay ?? 0) == 0;

  @override
  bool operator ==(Object other) =>
      other is PadInput &&
      other.dx == dx &&
      other.dy == dy &&
      other.ax == ax &&
      other.ay == ay &&
      other.buttons.length == buttons.length &&
      other.buttons.containsAll(buttons);

  @override
  int get hashCode => Object.hash(dx, dy, ax, ay, Object.hashAllUnordered(buttons));

  @override
  String toString() {
    final vertical = ['up', '', 'down'][dy + 1];
    final horizontal = ['left', '', 'right'][dx + 1];
    final dir = dx == 0 && dy == 0 ? 'centered' : [vertical, horizontal].where((s) => s.isNotEmpty).join('-');
    final held = buttons.map((b) => b.name.toUpperCase()).join('+');
    final stick = ax == null ? 'D-pad $dir' : 'Tilt x ${ax!.toStringAsFixed(2)} y ${ay!.toStringAsFixed(2)}';
    return '$held${buttons.isEmpty ? '' : ' · '}$stick';
  }
}

/// The difference between two [PadInput]s, used to decide on a haptic tick.
final class PadChange {
  const PadChange(this.before, this.after);

  final PadInput before;
  final PadInput after;

  bool get changed => before != after;
  int get presses => after.buttons.difference(before.buttons).length;
  int get releases => before.buttons.difference(after.buttons).length;
  bool get directionChanged => before.dx != after.dx || before.dy != after.dy;

  /// How strong the tick for this change is: presses and new directions
  /// full strength, releases and re-centering lighter. 0 means no tick.
  double get tickStrength {
    // Tilt changes all the time in gyro mode: only buttons and the D-pad tick.
    if (presses == 0 && releases == 0 && !directionChanged) return 0;
    if (presses > 0 || (directionChanged && (after.dx != 0 || after.dy != 0))) return 1;
    return 0.6;
  }
}

/// Tracks every finger on the pad, so a direction and several buttons can be
/// held at once and a thumb can slide from one button to the next.
class PadTracker {
  // Pointer → direction. The most recent finger on the D-pad wins.
  final _dpad = <int, (int, int)>{};
  // Pointer → button under it (null when it slid off every button).
  final _buttons = <int, ControllerButton?>{};
  PadInput _current = const PadInput();
  double? _ax;
  double? _ay;

  PadInput get current => _current;

  /// Gyro tilt, rounded like the wire format (3 decimals), so tiny changes
  /// that wouldn't reach the TV anyway don't count. Null leaves gyro mode.
  PadChange tilt(double? ax, double? ay) {
    _ax = ax == null ? null : (ax * 1000).round() / 1000;
    _ay = ay == null ? null : (ay * 1000).round() / 1000;
    return _update();
  }

  /// A finger on the D-pad went down or moved.
  PadChange dpad(int pointer, (int, int) direction) {
    _buttons.remove(pointer);
    _dpad[pointer] = direction;
    return _update();
  }

  /// A finger on a button area went down or moved. [button] is what's under
  /// it now, or null.
  PadChange button(int pointer, ControllerButton? button) {
    _dpad.remove(pointer);
    _buttons[pointer] = button;
    return _update();
  }

  /// A finger lifted (or the system cancelled it).
  PadChange up(int pointer) {
    _dpad.remove(pointer);
    _buttons.remove(pointer);
    return _update();
  }

  /// Releases everything, e.g. when the app goes to the background.
  PadChange releaseAll() {
    _dpad.clear();
    _buttons.clear();
    // Stay in gyro mode, but centered.
    if (_ax != null) {
      _ax = 0;
      _ay = 0;
    }
    return _update();
  }

  PadChange _update() {
    final before = _current;
    final (dx, dy) = _dpad.isEmpty ? (0, 0) : _dpad.values.last;
    _current = PadInput(
      buttons: _buttons.values.whereType<ControllerButton>().toSet(),
      dx: dx,
      dy: dy,
      ax: _ax,
      ay: _ay,
    );
    return PadChange(before, _current);
  }
}

/// The 8-way direction for a touch at [local] on a square D-pad of side
/// [size]. Up, down, left and right get 60° each and diagonals 30°, so
/// straight directions are easier to hit. The middle is a dead zone.
(int, int) dpadDirection(Offset local, double size, {double deadZone = 0.2}) {
  final center = size / 2;
  final x = local.dx - center;
  final y = local.dy - center;
  if (sqrt(x * x + y * y) < deadZone * center) return (0, 0);
  var degrees = atan2(y, x) * 180 / pi; // 0 = right, 90 = down (screen y grows down).
  if (degrees < 0) degrees += 360;
  final nearestStraight = (degrees / 90).round() * 90;
  if ((degrees - nearestStraight).abs() <= 30) {
    return switch (nearestStraight % 360) {
      0 => (1, 0),
      90 => (0, 1),
      180 => (-1, 0),
      _ => (0, -1),
    };
  }
  return (x > 0 ? 1 : -1, y > 0 ? 1 : -1);
}

/// Face button positions in a square of side 1 (Y top, X left, B right,
/// A bottom, like an Xbox pad).
const Map<ControllerButton, Offset> faceButtonCenters = {
  ControllerButton.y: Offset(0.5, 0.19),
  ControllerButton.x: Offset(0.19, 0.5),
  ControllerButton.b: Offset(0.81, 0.5),
  ControllerButton.a: Offset(0.5, 0.81),
};

/// Drawn radius of a face button, relative to the square's side.
const double faceButtonRadius = 0.16;

/// The face button under a touch at [local] in a square of side [size], or
/// null. The touch area is larger than the drawn button, so thumbs don't
/// miss, but the very middle hits nothing.
ControllerButton? faceButtonAt(Offset local, double size) {
  final p = local / size;
  ControllerButton? best;
  var bestDistance = double.infinity;
  for (final MapEntry(key: button, value: center) in faceButtonCenters.entries) {
    final d = (p - center).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = button;
    }
  }
  return bestDistance <= 0.26 ? best : null;
}
