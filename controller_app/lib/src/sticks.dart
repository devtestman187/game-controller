import 'dart:math';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connection/connection.dart' show Stick;

import 'tilt.dart';

export 'package:connection/connection.dart' show Stick;

const Stick stickCenter = (x: 0, y: 0);

enum StickSide { left, right }

/// The user's stick-mode choices (PRD C13 and v2 C16), saved between launches.
final class StickSettings {
  const StickSettings({
    this.deadZone = 0.1,
    this.sensitivity = 1.0,
    this.floating = false,
    this.buttonSize = defaultButtonSize,
  });

  /// A, B, X and Y in stick mode, relative to their size in D-pad mode.
  static const double defaultButtonSize = 0.75;
  static const double minButtonSize = 0.6;
  static const double maxButtonSize = 1.0;

  /// 0 to 0.4 of full deflection, ignored around the center.
  final double deadZone;

  /// 0.5 to 2: at 2, half the travel reaches full deflection.
  final double sensitivity;

  /// Floating sticks appear where the thumb lands in their half of the
  /// screen; fixed sticks stay in their circles.
  final bool floating;

  /// 0.6 to 1: A, B, X and Y's size relative to D-pad mode. The layout uses
  /// less if the screen has no room for it (it never overlaps).
  final double buttonSize;

  StickSettings copyWith({double? deadZone, double? sensitivity, bool? floating, double? buttonSize}) => StickSettings(
    deadZone: deadZone ?? this.deadZone,
    sensitivity: sensitivity ?? this.sensitivity,
    floating: floating ?? this.floating,
    buttonSize: buttonSize ?? this.buttonSize,
  );

  static StickSettings load(SharedPreferences prefs) => StickSettings(
    deadZone: (prefs.getDouble('stickDeadZone') ?? 0.1).clamp(0.0, 0.4),
    sensitivity: (prefs.getDouble('stickSensitivity') ?? 1.0).clamp(0.5, 2.0),
    floating: prefs.getBool('stickFloating') ?? false,
    buttonSize: (prefs.getDouble('stickButtonSize') ?? defaultButtonSize).clamp(minButtonSize, maxButtonSize),
  );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble('stickDeadZone', deadZone);
    await prefs.setDouble('stickSensitivity', sensitivity);
    await prefs.setBool('stickFloating', floating);
    await prefs.setDouble('stickButtonSize', buttonSize);
  }
}

/// The stick value for a thumb [offset] from the stick's center, with a
/// travel of [radius]: scaled by sensitivity, kept inside the unit circle
/// (so a diagonal never exceeds full scale), then the round dead zone.
/// y is negative upwards, like the D-pad.
Stick stickValue(Offset offset, double radius, StickSettings settings) {
  var x = offset.dx / radius * settings.sensitivity;
  var y = offset.dy / radius * settings.sensitivity;
  final length = sqrt(x * x + y * y);
  if (length > 1) {
    x /= length;
    y /= length;
  }
  return applyDeadZone(x, y, settings.deadZone);
}
