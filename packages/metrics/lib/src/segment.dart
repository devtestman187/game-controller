import 'dart:math';

import 'geometry.dart';

/// Thresholds from the PRD's analytics requirements.
abstract final class Thresholds {
  /// An empty tap this close to a control's touch area is a near miss.
  static const nearMissMm = 8.0;

  /// This many taps on one spot within [rapidWindowMs] are a rapid repeat.
  static const rapidCount = 4;
  static const rapidWindowMs = 1000;

  /// "One spot": within this distance of the newest tap.
  static const rapidRadiusMm = 6.0;

  /// A stick or tilt at least this far out is at full deflection.
  static const full = 0.95;

  /// Steering reversals count only past this far out, so jitter around the
  /// middle doesn't count.
  static const reversal = 0.3;
}

/// The touch counters for one mode segment: a stretch of time in one input
/// mode on one phone (PRD v2 C17). The phone feeds it, and sends
/// [toJson] to the host in metrics batches.
///
/// Times are on the phone's monotonic clock in ms. Touch positions are in
/// millimetres from the top left of the controller area. Only counts are
/// kept: never a touch trace, and empty taps only as counts on a coarse grid.
class SegmentRecorder {
  SegmentRecorder({
    required this.id,
    required this.mode,
    required this.startMs,
    this.offsetMs = 0,
    this.settings = const {},
    TouchMap? map,
  }) : map = map ?? TouchMap.empty;

  /// Unique segment ID.
  final String id;

  /// `dpad`, `gyro` or `sticks`.
  final String mode;

  /// When the segment started.
  final int startMs;

  /// How long after the phone started recording this segment began (for
  /// "switched modes within the first minute").
  final int offsetMs;

  /// The settings in effect: numbers and booleans only.
  final Map<String, Object> settings;

  int _touches = 0;
  final _presses = <String, int>{};
  final _pressMs = <String, int>{};
  final _pressMaxMs = <String, int>{};
  final _empty = <String, int>{};
  final _near = <String, int>{};
  final _slide = <String, int>{};
  final _rapid = <String, int>{};
  final _multi = <String, int>{};
  final _haptics = <String, int>{};
  final _heldSince = <String, int>{};
  Set<String> _held = const {};
  final _recent = <({double x, double y, int t, String target})>[];
  final _sticks = <String, _AxisTimes>{};
  _AxisTimes? _gyro;
  int _recalibrations = 0;

  /// The touch areas. Set again when the layout changes (window resized,
  /// button size changed).
  TouchMap map;

  int get touches => _touches;

  /// A finger touched down.
  void touchDown(double x, double y, int atMs) {
    _touches++;
    final hit = map.hit(x, y);
    final target = hit.control ?? Controls.empty;
    if (hit.control == null) {
      _add(_empty, map.cell(x, y));
      if (hit.nearest != null && hit.distanceMm <= Thresholds.nearMissMm) _add(_near, hit.nearest!);
    }
    _recent.removeWhere((r) => atMs - r.t > Thresholds.rapidWindowMs);
    _recent.add((x: x, y: y, t: atMs, target: target));
    final onSpot = _recent.where((r) => sqrt(pow(r.x - x, 2) + pow(r.y - y, 2)) <= Thresholds.rapidRadiusMm).length;
    // Counted once per burst, when it reaches the threshold.
    if (onSpot == Thresholds.rapidCount) _add(_rapid, target);
  }

  /// What is held right now: button names, [Controls.dpad] while a direction
  /// is held, and [Controls.leftStick] / [Controls.rightStick] while a thumb
  /// is on a stick.
  void held(Set<String> controls, int atMs) {
    final pressed = controls.difference(_held);
    final released = _held.difference(controls);
    for (final c in released) {
      final since = _heldSince.remove(c);
      if (since == null) continue;
      final ms = max(0, atMs - since);
      _add(_pressMs, c, ms);
      _pressMaxMs[c] = max(_pressMaxMs[c] ?? 0, ms);
    }
    for (final c in pressed) {
      _add(_presses, c);
      _heldSince[c] = atMs;
      // How many controls are held together, counting the new one.
      _add(_multi, '${min(controls.length, 5)}');
    }
    _held = Set.of(controls);
  }

  /// A finger that started on [control] slid off it while still down.
  void slideOff(String control) => _add(_slide, control);

  /// A stick's value ([Controls.leftStick] or [Controls.rightStick]), and
  /// whether a thumb is on it.
  void stick(String side, double x, double y, {required bool touched, required int atMs}) =>
      (_sticks[side] ??= _AxisTimes(atMs)).update(x, y, touched: touched, atMs: atMs);

  /// The gyro tilt (gyro mode).
  void tilt(double x, double y, int atMs) => (_gyro ??= _AxisTimes(atMs)).update(x, y, touched: true, atMs: atMs);

  /// The player pressed Calibrate (gyro mode).
  void recalibrated() => _recalibrations++;

  /// A haptic event from the host arrived.
  void haptic(String event) => _add(_haptics, event);

  int durationMs(int atMs) => max(0, atMs - startMs);

  /// Everything so far, as the `data` of a metrics batch.
  Map<String, Object?> toJson(int atMs) {
    for (final s in _sticks.values) {
      s.advance(atMs);
    }
    _gyro?.advance(atMs);
    // Presses still held count with their time so far.
    final pressMs = Map.of(_pressMs);
    final pressMax = Map.of(_pressMaxMs);
    for (final MapEntry(key: c, value: since) in _heldSince.entries) {
      final ms = max(0, atMs - since);
      pressMs[c] = (pressMs[c] ?? 0) + ms;
      pressMax[c] = max(pressMax[c] ?? 0, ms);
    }
    return {
      'v': 1,
      'start': offsetMs,
      'touches': _touches,
      if (settings.isNotEmpty) 'settings': settings,
      if (_presses.isNotEmpty) 'presses': Map.of(_presses),
      if (pressMs.isNotEmpty) 'pressMs': pressMs,
      if (pressMax.isNotEmpty) 'pressMaxMs': pressMax,
      if (_empty.isNotEmpty) 'empty': Map.of(_empty),
      if (_near.isNotEmpty) 'near': Map.of(_near),
      if (_slide.isNotEmpty) 'slide': Map.of(_slide),
      if (_rapid.isNotEmpty) 'rapid': Map.of(_rapid),
      if (_multi.isNotEmpty) 'multi': Map.of(_multi),
      if (_haptics.isNotEmpty) 'haptics': Map.of(_haptics),
      if (_sticks.isNotEmpty) 'sticks': {for (final MapEntry(:key, :value) in _sticks.entries) key: value.toJson()},
      if (_gyro != null || _recalibrations > 0) 'gyro': {...?_gyro?.toJson(), 'recal': _recalibrations},
    };
  }

  static void _add(Map<String, int> m, String key, [int by = 1]) => m[key] = (m[key] ?? 0) + by;
}

/// Time a stick or the tilt spent touched, centered (in the dead zone) and at
/// full deflection, and how often the steering reversed.
class _AxisTimes {
  _AxisTimes(this._lastMs);

  int _lastMs;
  double _x = 0;
  double _y = 0;
  bool _touched = false;
  int _lastSign = 0;
  int touchMs = 0;
  int deadMs = 0;
  int fullMs = 0;
  int reversals = 0;

  void advance(int atMs) {
    final dt = max(0, atMs - _lastMs);
    _lastMs = atMs;
    if (!_touched) return;
    touchMs += dt;
    final length = sqrt(_x * _x + _y * _y);
    if (length == 0) deadMs += dt;
    if (length >= Thresholds.full) fullMs += dt;
  }

  void update(double x, double y, {required bool touched, required int atMs}) {
    advance(atMs);
    _x = x;
    _y = y;
    if (touched && !_touched) _lastSign = 0; // A new touch starts fresh.
    _touched = touched;
    if (!touched || x.abs() < Thresholds.reversal) return;
    final sign = x > 0 ? 1 : -1;
    if (_lastSign != 0 && sign != _lastSign) reversals++;
    _lastSign = sign;
  }

  Map<String, Object> toJson() => {'touchMs': touchMs, 'deadMs': deadMs, 'fullMs': fullMs, 'reversals': reversals};
}

/// Cleans a metrics batch's data from a phone before the host keeps it, so a
/// faulty or newer phone can't put anything but counters (let alone a name)
/// into a session file: only known keys, numbers and booleans, short keys,
/// and a limited number of entries. Unknown keys are dropped.
Map<String, Object?> sanitizeSegmentData(Map<String, Object?> data) {
  int? n(Object? v) => v is num && v.isFinite && v >= 0 ? min(v.round(), 1 << 40) : null;

  Map<String, int> counts(Object? v) {
    if (v is! Map) return const {};
    final out = <String, int>{};
    for (final MapEntry(:key, :value) in v.entries) {
      if (out.length >= 64) break;
      if (key is! String || key.length > 16 || !_keyPattern.hasMatch(key)) continue;
      final number = n(value);
      if (number != null) out[key] = number;
    }
    return out;
  }

  Map<String, Object> flat(Object? v) {
    if (v is! Map) return const {};
    final out = <String, Object>{};
    for (final MapEntry(:key, :value) in v.entries) {
      if (out.length >= 32) break;
      if (key is! String || key.length > 24 || !_keyPattern.hasMatch(key)) continue;
      if (value is bool) {
        out[key] = value;
      } else if (value is num && value.isFinite) {
        out[key] = value;
      }
    }
    return out;
  }

  final out = <String, Object?>{
    'v': n(data['v']) ?? 1,
    'start': n(data['start']) ?? 0,
    'touches': n(data['touches']) ?? 0,
  };
  for (final key in const ['presses', 'pressMs', 'pressMaxMs', 'empty', 'near', 'slide', 'rapid', 'multi', 'haptics']) {
    final c = counts(data[key]);
    if (c.isNotEmpty) out[key] = c;
  }
  final settings = flat(data['settings']);
  if (settings.isNotEmpty) out['settings'] = settings;
  final sticks = data['sticks'];
  if (sticks is Map) {
    final s = {
      for (final side in const [Controls.leftStick, Controls.rightStick])
        if (counts(sticks[side]) case final c when c.isNotEmpty) side: c,
    };
    if (s.isNotEmpty) out['sticks'] = s;
  }
  final gyro = counts(data['gyro']);
  if (gyro.isNotEmpty) out['gyro'] = gyro;
  return out;
}

// Control names, grid cells ("2,1") and setting names.
final _keyPattern = RegExp(r'^[a-zA-Z0-9_,]+$');
