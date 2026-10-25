import 'dart:math';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:connection/connection.dart' show Stick;

import 'tilt.dart';

export 'package:connection/connection.dart' show Stick;

const Stick stickCenter = (x: 0, y: 0);

enum StickSide { left, right }

/// The user's stick choices (PRD C13), saved between launches.
final class StickSettings {
  const StickSettings({this.deadZone = 0.1, this.sensitivity = 1.0, this.floating = false});

  /// 0 to 0.4 of full deflection, ignored around the center.
  final double deadZone;

  /// 0.5 to 2: at 2, half the travel reaches full deflection.
  final double sensitivity;

  /// Floating sticks appear where the thumb lands in their half of the
  /// screen; fixed sticks stay in their circles.
  final bool floating;

  StickSettings copyWith({double? deadZone, double? sensitivity, bool? floating}) => StickSettings(
    deadZone: deadZone ?? this.deadZone,
    sensitivity: sensitivity ?? this.sensitivity,
    floating: floating ?? this.floating,
  );

  static StickSettings load(SharedPreferences prefs) => StickSettings(
    deadZone: (prefs.getDouble('stickDeadZone') ?? 0.1).clamp(0.0, 0.4),
    sensitivity: (prefs.getDouble('stickSensitivity') ?? 1.0).clamp(0.5, 2.0),
    floating: prefs.getBool('stickFloating') ?? false,
  );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setDouble('stickDeadZone', deadZone);
    await prefs.setDouble('stickSensitivity', sensitivity);
    await prefs.setBool('stickFloating', floating);
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

/// Where every control of stick mode goes, Xbox-style: the left stick upper
/// left with the D-pad below it toward the middle; A/B/X/Y upper right with
/// the right stick below it toward the middle; Select and Start in the
/// middle; LB and RB along the top edges.
final class StickLayout {
  const StickLayout({
    required this.lb,
    required this.rb,
    required this.leftStick,
    required this.dpad,
    required this.select,
    required this.start,
    required this.faceButtons,
    required this.rightStick,
    required this.leftZone,
    required this.rightZone,
  });

  final Rect lb;
  final Rect rb;
  final Rect leftStick;
  final Rect dpad;
  final Rect select;
  final Rect start;
  final Rect faceButtons;
  final Rect rightStick;

  /// Where a floating stick may start: its whole half (the other controls
  /// sit on top and win where they overlap).
  final Rect leftZone;
  final Rect rightZone;

  /// Every touch control, for overlap checks.
  Map<String, Rect> get controls => {
    'LB': lb,
    'RB': rb,
    'left stick': leftStick,
    'D-pad': dpad,
    'Select': select,
    'Start': start,
    'A/B/X/Y': faceButtons,
    'right stick': rightStick,
  };
}

StickLayout stickLayout(Size size) {
  const gap = 8.0;
  const edge = 12.0;
  const shoulderHeight = 40.0;
  final centerWidth = min(140.0, size.width * 0.18);
  final half = (size.width - centerWidth) / 2;
  final rightStart = half + centerWidth;
  final shoulderWidth = min(130.0, half * 0.45);
  final top = shoulderHeight + gap;
  final available = size.height - top;

  // A big stick and a smaller control share each half's height.
  final big = min(half * 0.56, available * 0.58);
  final small = min(half * 0.46, available - big - gap);

  final leftStick = Rect.fromLTWH(edge, top, big, big);
  final dpad = Rect.fromLTWH(half - small - gap, size.height - small, small, small);
  final faceButtons = Rect.fromLTWH(size.width - edge - small, top, small, small);
  final rightStick = Rect.fromLTWH(rightStart + gap, size.height - big, big, big);

  final pillWidth = (centerWidth - gap) / 2;
  const pillHeight = 40.0;
  final pillTop = top + available * 0.25;

  return StickLayout(
    lb: Rect.fromLTWH(edge, 0, shoulderWidth, shoulderHeight),
    rb: Rect.fromLTWH(size.width - edge - shoulderWidth, 0, shoulderWidth, shoulderHeight),
    leftStick: leftStick,
    dpad: dpad,
    select: Rect.fromLTWH(half, pillTop, pillWidth, pillHeight),
    start: Rect.fromLTWH(half + pillWidth + gap, pillTop, pillWidth, pillHeight),
    faceButtons: faceButtons,
    rightStick: rightStick,
    leftZone: Rect.fromLTWH(0, top, half, available),
    rightZone: Rect.fromLTWH(rightStart, top, half, available),
  );
}
