import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';

import 'gyro.dart';
import 'layout.dart';
import 'sticks.dart';
import 'tilt.dart';

/// The phone's touch metrics (PRD v2 C17, C18): one [SegmentRecorder] per
/// stretch of time in one mode with one set of settings, sent to the TV in
/// batches about every [interval], on every mode or settings change and at
/// disconnect. The client keeps unacknowledged batches and sends them again
/// after a reconnect.
///
/// It records only while [setActive] says so: connected to a TV (or
/// reconnecting to one), not in the demo, and not opted out in settings.
class PhoneMetrics {
  PhoneMetrics({required this.send, int Function()? now, this.interval = const Duration(seconds: 10), Random? random})
    : _now = now ?? _stopwatchNow(),
      _random = random ?? Random.secure();

  final void Function(MetricsMessage batch) send;
  final int Function() _now;
  final Random _random;
  final Duration interval;

  bool _active = false;
  String _mode = 'dpad';
  Map<String, Object> _settings = const {};
  TouchMap _map = TouchMap.empty;
  SegmentRecorder? _segment;
  int _index = 0;
  int? _firstStartMs;
  int _segments = 0;
  Timer? _timer;
  late final String _prefix = List.generate(4, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  bool get active => _active;

  SegmentRecorder? get segment => _segment;

  /// Segments started since launch, for Diagnostics.
  int get segments => _segments;

  /// Starts or stops recording. Stopping ends and sends the segment.
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    if (active) {
      _start();
    } else {
      _end();
    }
  }

  /// A new mode, or new settings in the same mode: a new segment.
  void setMode(String mode, Map<String, Object> settings) {
    if (mode == _mode && _sameSettings(settings, _settings)) return;
    _mode = mode;
    _settings = Map.unmodifiable(settings);
    if (!_active) return;
    _end();
    _start();
  }

  /// The layout changed (window size, button size, mode).
  set map(TouchMap map) {
    _map = map;
    _segment?.map = map;
  }

  /// The connection dropped: send what there is (it waits in the outbox).
  void disconnected() => _flush();

  void touchDown(double xMm, double yMm) => _segment?.touchDown(xMm, yMm, _now());

  void held(Set<String> controls) => _segment?.held(controls, _now());

  void slideOff(String control) => _segment?.slideOff(control);

  void stick(String side, double x, double y, {required bool touched}) =>
      _segment?.stick(side, x, y, touched: touched, atMs: _now());

  void tilt(double x, double y) => _segment?.tilt(x, y, _now());

  void recalibrated() => _segment?.recalibrated();

  void haptic(String event) => _segment?.haptic(event);

  void dispose() {
    _end();
    _timer?.cancel();
  }

  void _start() {
    final now = _now();
    _firstStartMs ??= now;
    _segments++;
    _index = 0;
    _segment = SegmentRecorder(
      id: '$_prefix-$_segments',
      mode: _mode,
      startMs: now,
      offsetMs: now - _firstStartMs!,
      settings: _settings,
      map: _map,
    );
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _flush());
  }

  void _end() {
    _timer?.cancel();
    _timer = null;
    _flush(ended: true);
    _segment = null;
  }

  void _flush({bool ended = false}) {
    final s = _segment;
    if (s == null) return;
    final now = _now();
    send(
      MetricsMessage(
        segment: s.id,
        index: _index++,
        mode: s.mode,
        durationMs: s.durationMs(now),
        ended: ended,
        data: s.toJson(now),
      ),
    );
  }

  static int Function() _stopwatchNow() {
    final clock = Stopwatch()..start();
    return () => clock.elapsedMilliseconds;
  }
}

bool _sameSettings(Map<String, Object> a, Map<String, Object> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// The settings in effect for a mode, recorded with each segment.
Map<String, Object> metricsSettings({
  required PadMode mode,
  required StickSettings sticks,
  required GyroSettings gyro,
  required bool hapticsOn,
  required double hapticIntensity,
  required bool flash,
  required bool click,
  required bool tablet,
}) => {
  'haptics': hapticsOn,
  'hapticIntensity': _round(hapticIntensity),
  'flash': flash,
  'click': click,
  'tablet': tablet,
  if (mode == PadMode.sticks) ...{
    'deadZone': _round(sticks.deadZone),
    'sensitivity': _round(sticks.sensitivity),
    'floating': sticks.floating,
    'buttonSize': _round(sticks.buttonSize),
  },
  if (mode == PadMode.gyro) ...{
    'deadZone': _round(gyro.deadZone),
    'sensitivity': _round(gyro.sensitivity),
    'smoothing': _round(gyro.smoothing),
  },
};

double _round(double v) => (v * 100).round() / 100;

/// Every control's touch area in [body] (the screen below the top bar), in
/// millimetres, for the metrics: the same rules the controls use, so a touch
/// the metrics count as empty really did nothing.
TouchMap touchMapFor({required PadMode mode, required Size body, required double mm, StickSettings? sticks}) {
  TouchShape rect(String control, Rect r) =>
      TouchShape.rect(control, r.left / mm, r.top / mm, r.width / mm, r.height / mm);
  TouchShape circle(String control, Offset center, double radius, {Rect? clip}) => TouchShape.circle(
    control,
    center.dx / mm,
    center.dy / mm,
    radius / mm,
    clip: clip == null ? null : rect(control, clip),
  );
  // In D-pad and gyro modes the buttons take touches only inside their
  // square; in stick mode inside their round area, which holds the circles.
  List<TouchShape> face(Rect square, FaceGeometry g) => [
    for (final MapEntry(key: button, value: c) in g.centers.entries)
      circle(
        button.name,
        square.topLeft + c * square.width,
        g.touch * square.width,
        clip: g.roundHitArea ? null : square,
      ),
  ];

  final shapes = <TouchShape>[];
  if (mode == PadMode.sticks) {
    final s = sticks ?? const StickSettings();
    final l = stickLayout(body, mm: mm, buttonSize: s.buttonSize);
    // The sticks first: everything else sits on top of them.
    if (s.floating) {
      shapes
        ..add(rect('ls', l.leftZone))
        ..add(rect('rs', l.rightZone));
    } else {
      shapes
        ..add(circle('ls', l.leftStick.center, l.leftStick.width / 2 * stickTouch))
        ..add(circle('rs', l.rightStick.center, l.rightStick.width / 2 * stickTouch));
    }
    shapes
      ..add(rect('dpad', l.dpad))
      ..addAll(face(l.faceButtons, FaceGeometry.compact))
      ..add(rect('lb', l.lb))
      ..add(rect('rb', l.rb))
      ..add(rect('select', l.select))
      ..add(rect('start', l.start));
  } else {
    final l = padLayout(body, mm: mm);
    shapes
      ..add(mode == PadMode.gyro ? rect('tilt', l.leftArea) : rect('dpad', l.dpad))
      ..add(rect('select', l.select))
      ..add(rect('start', l.start))
      ..addAll(face(l.faceButtons, FaceGeometry.classic));
  }
  return TouchMap(shapes, widthMm: body.width / mm, heightMm: body.height / mm);
}

/// What is held, as metrics control names: the buttons, `dpad` while a
/// direction is held, and `ls` / `rs` while a thumb is on a stick.
Set<String> heldControls(Set<ControllerButton> buttons, {required bool dpad, bool left = false, bool right = false}) =>
    {for (final b in buttons) b.name, if (dpad) 'dpad', if (left) 'ls', if (right) 'rs'};
