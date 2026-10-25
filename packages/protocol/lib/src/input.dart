part of 'messages.dart';

/// Controller buttons. The wire name is the enum name. Older peers ignore
/// names they don't know, so buttons can be added without a version bump.
enum ControllerButton {
  a,
  b,
  x,
  y,
  start,
  select,

  /// Left and right shoulder buttons (stick mode, M4).
  lb,
  rb,
}

/// The controller's whole input state: which buttons are held, where the
/// D-pad points, the gyro tilt (gyro mode) and the two analog sticks (stick
/// mode).
///
/// The phone sends the full state on every change instead of separate
/// down/up events, so the TV can never miss a release: the latest message is
/// always the truth, and an empty state releases everything.
///
/// All analog values run from -1 to 1 with y = -1 meaning up/forward, like
/// [dy]. Each pair is either both present or both absent; absent means that
/// input isn't in use in the current mode.
final class InputStateMessage extends Message {
  InputStateMessage({
    required this.seq,
    Set<ControllerButton> buttons = const {},
    this.dx = 0,
    this.dy = 0,
    double? ax,
    double? ay,
    double? lx,
    double? ly,
    double? rx,
    double? ry,
  }) : buttons = Set.unmodifiable(buttons),
       ax = _analog(ax),
       ay = _analog(ay),
       lx = _analog(lx),
       ly = _analog(ly),
       rx = _analog(rx),
       ry = _analog(ry) {
    if (dx < -1 || dx > 1 || dy < -1 || dy > 1) {
      throw ArgumentError('dx and dy must be -1, 0 or 1, got ($dx, $dy)');
    }
    for (final (name, a, b) in [('ax/ay', ax, ay), ('lx/ly', lx, ly), ('rx/ry', rx, ry)]) {
      if ((a == null) != (b == null)) throw ArgumentError('Send both $name, or neither');
    }
  }

  static const String wireType = 'input';

  /// Increases with every state the phone sends on a connection, so the TV
  /// can drop anything out of order.
  final int seq;
  final Set<ControllerButton> buttons;

  /// D-pad direction: -1 left, 1 right.
  final int dx;

  /// D-pad direction: -1 up, 1 down (screen coordinates).
  final int dy;

  /// Gyro tilt (gyro mode only).
  final double? ax;
  final double? ay;

  /// Left analog stick, inside the unit circle (stick mode only).
  final double? lx;
  final double? ly;

  /// Right analog stick, inside the unit circle (stick mode only).
  final double? rx;
  final double? ry;

  bool get hasAnalog => ax != null;

  bool get hasSticks => lx != null;

  bool get isNeutral => buttons.isEmpty && dx == 0 && dy == 0 && [ax, ay, lx, ly, rx, ry].every((v) => (v ?? 0) == 0);

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'seq': seq,
    // Sorted so equal states encode identically.
    'buttons': [
      for (final b in ControllerButton.values)
        if (buttons.contains(b)) b.name,
    ],
    'dx': dx,
    'dy': dy,
    'ax': ?ax,
    'ay': ?ay,
    'lx': ?lx,
    'ly': ?ly,
    'rx': ?rx,
    'ry': ?ry,
  };

  static InputStateMessage fromPayload(Map<String, Object?> p) {
    final raw = p['buttons'];
    if (raw is! List) throw const FormatException('Field "buttons" must be a list');
    final buttons = <ControllerButton>{};
    for (final name in raw) {
      if (name is! String) throw const FormatException('Button names must be strings');
      // Unknown names come from a newer phone. Ignore them.
      final button = ControllerButton.values.where((b) => b.name == name).firstOrNull;
      if (button != null) buttons.add(button);
    }
    final dx = requireInt(p, 'dx');
    final dy = requireInt(p, 'dy');
    if (dx.abs() > 1 || dy.abs() > 1) throw const FormatException('dx and dy must be -1, 0 or 1');
    final values = {
      for (final k in ['ax', 'ay', 'lx', 'ly', 'rx', 'ry']) k: _optionalNumber(p, k),
    };
    for (final (a, b) in [('ax', 'ay'), ('lx', 'ly'), ('rx', 'ry')]) {
      if ((values[a] == null) != (values[b] == null)) throw FormatException('Send both "$a" and "$b", or neither');
    }
    return InputStateMessage(
      seq: requireInt(p, 'seq'),
      buttons: buttons,
      dx: dx,
      dy: dy,
      ax: values['ax'],
      ay: values['ay'],
      lx: values['lx'],
      ly: values['ly'],
      rx: values['rx'],
      ry: values['ry'],
    );
  }

  // Sets aren't compared by value in the base class, so compare here.
  @override
  bool operator ==(Object other) =>
      other is InputStateMessage &&
      other.seq == seq &&
      other.dx == dx &&
      other.dy == dy &&
      other.ax == ax &&
      other.ay == ay &&
      other.lx == lx &&
      other.ly == ly &&
      other.rx == rx &&
      other.ry == ry &&
      other.buttons.length == buttons.length &&
      other.buttons.containsAll(buttons);

  @override
  int get hashCode => Object.hash(seq, dx, dy, ax, ay, lx, ly, rx, ry, Object.hashAllUnordered(buttons));
}

/// Clamps to -1..1 and rounds to 3 decimals: plenty for a stick, and it keeps
/// frames short at 60 per second.
double? _analog(double? v) {
  if (v == null) return null;
  if (v.isNaN) return 0;
  return (v.clamp(-1.0, 1.0) * 1000).round() / 1000;
}

double? _optionalNumber(Map<String, Object?> p, String key) {
  final value = p[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Field "$key" must be a number, got ${value.runtimeType}');
}
