part of 'messages.dart';

/// Host → controller (M10, needs [Capability.layout]): what the game does
/// with each button (PRD v2 P5). The phone shows the labels on its buttons,
/// hides the buttons the game doesn't use, and offers only the allowed modes.
/// The player still picks among the allowed modes. An empty layout
/// ([GameLayoutMessage.standard]) puts the phone back to its usual buttons.
final class GameLayoutMessage extends Message {
  GameLayoutMessage({
    List<String> modes = const [],
    this.defaultMode,
    Map<ControllerButton, String> labels = const {},
    Set<ControllerButton> hidden = const {},
  }) : modes = List.unmodifiable(modes.where(validModes.contains)),
       labels = Map.unmodifiable({for (final MapEntry(:key, :value) in labels.entries) key: _shortLabel(value)}),
       hidden = Set.unmodifiable(hidden);

  /// No game-defined controls: every mode, the usual buttons.
  GameLayoutMessage.standard() : this();

  static const String wireType = 'layout';

  /// Input modes the controller knows.
  static const validModes = ['dpad', 'gyro', 'sticks'];

  /// Labels are cut to this many characters, so they fit under a button.
  static const maxLabelLength = 12;

  /// The modes the player may use (`dpad`, `gyro`, `sticks`). Empty: all.
  final List<String> modes;

  /// The mode to switch to if the current one isn't allowed.
  final String? defaultMode;

  /// A short label per button, e.g. A "Pick up".
  final Map<ControllerButton, String> labels;

  /// Buttons the game doesn't use: the phone dims or hides them.
  final Set<ControllerButton> hidden;

  bool get isStandard => modes.isEmpty && labels.isEmpty && hidden.isEmpty && defaultMode == null;

  bool allows(String mode) => modes.isEmpty || modes.contains(mode);

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'modes': modes,
    'default': ?defaultMode,
    'labels': {for (final b in ControllerButton.values) b.name: ?labels[b]},
    'hidden': [
      for (final b in ControllerButton.values)
        if (hidden.contains(b)) b.name,
    ],
  };

  static GameLayoutMessage fromPayload(Map<String, Object?> p) {
    final rawLabels = p['labels'];
    if (rawLabels != null && rawLabels is! Map) throw const FormatException('Field "labels" must be an object');
    ControllerButton? button(Object? name) => ControllerButton.values.where((b) => b.name == name).firstOrNull;
    final defaultMode = optionalString(p, 'default');
    return GameLayoutMessage(
      modes: stringList(p, 'modes'),
      defaultMode: validModes.contains(defaultMode) ? defaultMode : null,
      labels: {
        if (rawLabels is Map)
          for (final MapEntry(:key, :value) in rawLabels.entries)
            if (button(key) case final b? when value is String) b: value,
      },
      // Unknown buttons (from a newer TV) are ignored.
      hidden: {for (final name in stringList(p, 'hidden')) ?button(name)},
    );
  }
}

String _shortLabel(String s) {
  final t = s.trim();
  return t.length <= GameLayoutMessage.maxLabelLength ? t : t.substring(0, GameLayoutMessage.maxLabelLength);
}

/// One simple shape for the status panel: a polygon (points in -1..1 around
/// the middle) or a circle.
final class StatusShape {
  const StatusShape.polygon(this.points, {required this.color, this.angle = 0}) : circle = false;

  const StatusShape.circle({required this.color}) : points = const [], circle = true, angle = 0;

  /// Corner points, each (x, y) from -1 to 1, y down. At most [maxPoints].
  final List<(double, double)> points;
  final bool circle;

  /// Fill colour as 0xAARRGGBB.
  final int color;

  /// Clockwise, in degrees.
  final double angle;

  static const maxPoints = 16;

  Map<String, Object?> toJson() => {
    if (circle)
      'circle': true
    else
      'points': [
        for (final (x, y) in points) [_r(x), _r(y)],
      ],
    'color': color,
    'angle': _r(angle),
  };

  static StatusShape fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Field "shape" must be an object');
    final color = json['color'];
    if (color is! int) throw const FormatException('Shape "color" must be an integer');
    if (json['circle'] == true) return StatusShape.circle(color: color);
    final raw = json['points'];
    if (raw is! List) throw const FormatException('Shape "points" must be a list');
    final points = <(double, double)>[];
    for (final p in raw.take(maxPoints)) {
      if (p is List && p.length == 2 && p[0] is num && p[1] is num) {
        points.add((((p[0] as num).toDouble()).clamp(-1.0, 1.0), ((p[1] as num).toDouble()).clamp(-1.0, 1.0)));
      }
    }
    final angle = json['angle'];
    return StatusShape.polygon(points, color: color, angle: angle is num ? angle.toDouble() : 0);
  }

  @override
  bool operator ==(Object other) => other is StatusShape && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

double _r(double v) => (v * 100).round() / 100;

/// Host → controller (M10, needs [Capability.status]): a small panel on the
/// phone (PRD v2 P6) with a short [text], one [shape] and a [progress] bar.
/// The puzzle shows the held piece (turning as it rotates) and the time
/// left. Sent at most 10 times a second. An empty status hides the panel.
final class StatusMessage extends Message {
  StatusMessage({String? text, this.shape, double? progress, this.warning = false})
    : text = text == null ? null : (text.length <= maxTextLength ? text : text.substring(0, maxTextLength)),
      progress = progress == null || progress.isNaN ? null : (progress.clamp(0.0, 1.0) * 100).round() / 100;

  /// Hides the panel.
  StatusMessage.hidden() : this();

  static const String wireType = 'status';

  static const maxTextLength = 24;

  /// At most this many status messages a second, per controller.
  static const maxPerSecond = 10;

  final String? text;
  final StatusShape? shape;

  /// 0 to 1, e.g. the time left.
  final double? progress;

  /// Show the bar as a warning (e.g. the last 15 seconds).
  final bool warning;

  bool get isHidden => text == null && shape == null && progress == null;

  @override
  String get type => wireType;

  @override
  Map<String, Object?> toPayload() => {
    'text': ?text,
    'shape': ?shape?.toJson(),
    'progress': ?progress,
    if (warning) 'warning': true,
  };

  static StatusMessage fromPayload(Map<String, Object?> p) {
    final progress = p['progress'];
    if (progress != null && progress is! num) throw const FormatException('Field "progress" must be a number');
    return StatusMessage(
      text: optionalString(p, 'text'),
      shape: p['shape'] == null ? null : StatusShape.fromJson(p['shape']),
      progress: (progress as num?)?.toDouble(),
      warning: p['warning'] == true,
    );
  }
}
