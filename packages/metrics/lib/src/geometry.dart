import 'dart:math';

/// A control's touch area on the phone, in millimetres from the top left of
/// the controller area: a rectangle or a circle.
final class TouchShape {
  const TouchShape.rect(this.control, this.left, this.top, this.width, this.height) : circle = false;

  TouchShape.circle(this.control, double centerX, double centerY, double radius)
    : circle = true,
      left = centerX - radius,
      top = centerY - radius,
      width = radius * 2,
      height = radius * 2;

  /// The control's metrics name ([Controls]).
  final String control;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool circle;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  /// How far a point is from the shape's edge: 0 inside it.
  double distance(double x, double y) {
    if (circle) return max(0, _hypot(x - centerX, y - centerY) - width / 2);
    final dx = max(max(left - x, 0.0), x - right);
    final dy = max(max(top - y, 0.0), y - bottom);
    return _hypot(dx, dy);
  }

  bool contains(double x, double y) => distance(x, y) == 0;

  @override
  String toString() =>
      '$control ${circle ? 'circle' : 'rect'} (${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${width.toStringAsFixed(1)} x ${height.toStringAsFixed(1)} mm)';
}

double _hypot(double a, double b) => sqrt(a * a + b * b);

/// Metrics names for the controls. Buttons use the protocol's names (a, b,
/// x, y, lb, rb, select, start).
abstract final class Controls {
  static const dpad = 'dpad';
  static const leftStick = 'ls';
  static const rightStick = 'rs';

  /// Gyro mode's tilt view and Calibrate button.
  static const tilt = 'tilt';

  /// A touch on no control.
  static const empty = 'empty';
}

/// Where a touch landed.
typedef TouchHit = ({String? control, String? nearest, double distanceMm});

/// The controller area's touch shapes, for one layout.
final class TouchMap {
  TouchMap(this.shapes, {required this.widthMm, required this.heightMm});

  static final empty = TouchMap(const [], widthMm: 1, heightMm: 1);

  /// In order: where shapes overlap, the last one wins (it's drawn on top).
  final List<TouchShape> shapes;
  final double widthMm;
  final double heightMm;

  /// The control under ([TouchHit.control]), or the nearest one and how far
  /// away it is.
  TouchHit hit(double x, double y) {
    for (final s in shapes.reversed) {
      if (s.contains(x, y)) return (control: s.control, nearest: s.control, distanceMm: 0);
    }
    String? nearest;
    var best = double.infinity;
    for (final s in shapes) {
      final d = s.distance(x, y);
      if (d < best) {
        best = d;
        nearest = s.control;
      }
    }
    return (control: null, nearest: nearest, distanceMm: best);
  }

  /// The coarse grid cell for an empty tap: "column,row" on a
  /// [gridColumns] by [gridRows] grid over the whole controller area.
  String cell(double x, double y) {
    final c = (x / widthMm * gridColumns).floor().clamp(0, gridColumns - 1);
    final r = (y / heightMm * gridRows).floor().clamp(0, gridRows - 1);
    return '$c,$r';
  }

  static const gridColumns = 6;
  static const gridRows = 3;
}
