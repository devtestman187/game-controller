import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart';

import 'layout.dart';
import 'sticks.dart';

/// What the on-screen pad is pressing right now.
final class PadInput {
  const PadInput({this.buttons = const {}, this.dx = 0, this.dy = 0, this.ax, this.ay, this.left, this.right});

  final Set<ControllerButton> buttons;

  /// D-pad: -1 left / up, 1 right / down.
  final int dx;
  final int dy;

  /// Gyro tilt from -1 to 1 (y: -1 forward), null outside gyro mode.
  final double? ax;
  final double? ay;

  /// Analog sticks inside the unit circle, null outside stick mode.
  final Stick? left;
  final Stick? right;

  bool get isNeutral =>
      buttons.isEmpty &&
      dx == 0 &&
      dy == 0 &&
      (ax ?? 0) == 0 &&
      (ay ?? 0) == 0 &&
      (left ?? stickCenter) == stickCenter &&
      (right ?? stickCenter) == stickCenter;

  @override
  bool operator ==(Object other) =>
      other is PadInput &&
      other.dx == dx &&
      other.dy == dy &&
      other.ax == ax &&
      other.ay == ay &&
      other.left == left &&
      other.right == right &&
      other.buttons.length == buttons.length &&
      other.buttons.containsAll(buttons);

  @override
  int get hashCode => Object.hash(dx, dy, ax, ay, left, right, Object.hashAllUnordered(buttons));

  @override
  String toString() {
    final vertical = ['up', '', 'down'][dy + 1];
    final horizontal = ['left', '', 'right'][dx + 1];
    final dir = dx == 0 && dy == 0 ? 'centered' : [vertical, horizontal].where((s) => s.isNotEmpty).join('-');
    final held = buttons.map((b) => b.name.toUpperCase()).join('+');
    String xy(double x, double y) => 'x ${x.toStringAsFixed(2)} y ${y.toStringAsFixed(2)}';
    final parts = [
      if (held.isNotEmpty) held,
      if (left != null) 'L ${xy(left!.x, left!.y)}',
      if (right != null) 'R ${xy(right!.x, right!.y)}',
      if (ax != null) 'Tilt ${xy(ax!, ay!)}' else if (left == null || dx != 0 || dy != 0) 'D-pad $dir',
    ];
    return parts.join(' · ');
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
    // Tilt and sticks change all the time: only buttons and the D-pad tick.
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
  Stick? _left;
  Stick? _right;

  PadInput get current => _current;

  /// The button under a finger on a button area, or null.
  ControllerButton? buttonUnder(int pointer) => _buttons[pointer];

  /// Starts a mode: lets go of every finger (nothing held in the old layout
  /// carries over), and centers the inputs the new mode uses (tilt for gyro,
  /// both sticks for stick mode) or drops them.
  PadChange switchMode({required bool tilt, required bool sticks}) {
    _dpad.clear();
    _buttons.clear();
    _ax = tilt ? 0 : null;
    _ay = tilt ? 0 : null;
    _left = sticks ? stickCenter : null;
    _right = sticks ? stickCenter : null;
    return _update();
  }

  /// A stick moved (rounded like the wire format), or was let go
  /// ([stickCenter]).
  PadChange stick(StickSide side, Stick value) {
    final rounded = (x: (value.x * 1000).round() / 1000, y: (value.y * 1000).round() / 1000);
    if (side == StickSide.left) {
      _left = rounded;
    } else {
      _right = rounded;
    }
    return _update();
  }

  /// Gyro tilt, rounded like the wire format (3 decimals), so tiny changes
  /// that wouldn't reach the TV anyway don't count.
  PadChange tilt(double ax, double ay) {
    _ax = (ax * 1000).round() / 1000;
    _ay = (ay * 1000).round() / 1000;
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
    // Stay in the same mode, but centered.
    if (_ax != null) {
      _ax = 0;
      _ay = 0;
    }
    if (_left != null) {
      _left = stickCenter;
      _right = stickCenter;
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
      left: _left,
      right: _right,
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

/// Face button positions in a square of side 1 in D-pad mode (Y top, X left,
/// B right, A bottom, like an Xbox pad).
Map<ControllerButton, Offset> get faceButtonCenters => FaceGeometry.classic.centers;

/// Drawn radius of a face button in D-pad mode, relative to the square's side.
double get faceButtonRadius => FaceGeometry.classic.radius;

/// The face button under a touch at [local] in a square of side [size], or
/// null. The touch area is larger than the drawn button, so thumbs don't
/// miss, but the very middle hits nothing.
ControllerButton? faceButtonAt(Offset local, double size, [FaceGeometry geometry = FaceGeometry.classic]) =>
    geometry.buttonAt(local, size);
