import 'dart:math';
import 'dart:ui';

import 'package:protocol/protocol.dart' show ControllerButton;

/// Where every control goes, for all three modes (PRD C12, and v2 C14 to
/// C16, C31 and C32). Pure functions of the body size (the screen below the
/// top bar), so they're unit tested on many screen sizes.
///
/// Controls are sized in millimetres (C31): each hand's controls fit in a
/// "thumb box" anchored to the bottom outer corner, at most
/// [maxThumbBoxWidthMm] by [maxThumbBoxHeightMm]. On phones the box is the
/// whole half of the screen, so they look as they did in v1. On tablets the
/// controls stay thumb-sized and the middle stays free.

/// Logical pixels per millimetre. Android's dp is 1/160 inch, and iPhone
/// points are close to it (within about 5%).
const double phonePxPerMm = 160 / 25.4;

/// Full-size iPads have about 132 points per inch.
const double iPadPxPerMm = 132 / 25.4;

/// Tablets have a screen whose shorter side is at least 600 dp (or points).
bool isTabletScreen(Size screen) => screen.shortestSide >= 600;

double pxPerMmFor({required bool isIOS, required bool isTablet}) => isIOS && isTablet ? iPadPxPerMm : phonePxPerMm;

/// The largest box one hand's controls use. The biggest phones (a Pixel 7
/// in landscape is about 57 by 56 mm below the top bar) stay under it.
const double maxThumbBoxWidthMm = 60;
const double maxThumbBoxHeightMm = 58;

/// The smallest window the controller lays itself out in. Below it (a phone
/// in split screen, a tiny resizable window) the app shows "Make the window
/// bigger" instead (C32). The smallest supported phone, an iPhone SE, has
/// about 667 by 320 for the whole app.
const double minWindowWidth = 540;

/// The smallest body height: the window below the top bar.
const double minBodyHeight = 250;

/// The smallest body the layouts are tested at.
const Size minBodySize = Size(minWindowWidth, minBodyHeight);

/// Where A, B, X and Y sit in their square, as fractions of its side, and how
/// far beyond each drawn circle a touch still counts.
final class FaceGeometry {
  const FaceGeometry({required this.radius, required this.spread, required this.touch, required this.roundHitArea});

  /// D-pad and gyro modes, as in v1. Touches count up to 0.26 from a button's
  /// center (nearest button wins), up to the square's edge, which still leaves
  /// 19% beyond each drawn circle on the outside.
  static const classic = FaceGeometry(radius: 0.16, spread: 0.31, touch: 0.26, roundHitArea: false);

  /// Stick mode: the buttons closer together (centers 1.7 radii from the
  /// middle), each touch area 15% larger than its button (C15), and the
  /// square exactly holds the touch areas.
  static const compact = FaceGeometry(
    radius: 1 / (2 * (compactSpread + compactTouch)),
    spread: compactSpread / (2 * (compactSpread + compactTouch)),
    touch: compactTouch / (2 * (compactSpread + compactTouch)),
    roundHitArea: true,
  );

  static const double compactSpread = 1.7;
  static const double compactTouch = 1.15;

  /// Drawn radius of each button.
  final double radius;

  /// How far each button's center is from the middle.
  final double spread;

  /// Touch radius around each button's center.
  final double touch;

  /// True if only the circle around the four touch areas takes touches, not
  /// the square's corners (in stick mode they can lie over the right stick).
  final bool roundHitArea;

  /// Y top, X left, B right, A bottom, like an Xbox pad.
  Map<ControllerButton, Offset> get centers => {
    ControllerButton.y: Offset(0.5, 0.5 - spread),
    ControllerButton.x: Offset(0.5 - spread, 0.5),
    ControllerButton.b: Offset(0.5 + spread, 0.5),
    ControllerButton.a: Offset(0.5, 0.5 + spread),
  };

  /// Whether a touch at [local] in a square of side [size] belongs to the
  /// buttons at all (it may still be between them).
  bool takes(Offset local, double size) =>
      !roundHitArea || (local / size - const Offset(0.5, 0.5)).distance <= spread + touch + 1e-9;

  /// The button under a touch at [local] in a square of side [size], or null.
  /// The nearest button wins, so a touch area never takes a touch from a
  /// neighbour, and the very middle hits nothing.
  ControllerButton? buttonAt(Offset local, double size) {
    final p = local / size;
    ControllerButton? best;
    var bestDistance = double.infinity;
    for (final MapEntry(key: button, value: center) in centers.entries) {
      final d = (p - center).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = button;
      }
    }
    return bestDistance <= touch ? best : null;
  }
}

/// A control's touch area, for overlap checks: a rectangle, or a circle
/// (sticks, and the A/B/X/Y cluster in stick mode).
final class ControlShape {
  const ControlShape.rect(this.bounds) : circle = false;
  const ControlShape.circle(this.bounds) : circle = true;

  final Rect bounds;
  final bool circle;

  Offset get center => bounds.center;
  double get radius => bounds.width / 2;

  /// The gap between the two shapes, negative if they overlap.
  double distanceTo(ControlShape other) {
    if (circle && other.circle) return (center - other.center).distance - radius - other.radius;
    if (!circle && !other.circle) {
      final dx = max(other.bounds.left - bounds.right, bounds.left - other.bounds.right);
      final dy = max(other.bounds.top - bounds.bottom, bounds.top - other.bounds.bottom);
      if (dx < 0 && dy < 0) return max(dx, dy);
      return sqrt(pow(max(dx, 0), 2) + pow(max(dy, 0), 2));
    }
    final (c, r) = circle ? (this, other) : (other, this);
    final nearest = Offset(
      c.center.dx.clamp(r.bounds.left, r.bounds.right),
      c.center.dy.clamp(r.bounds.top, r.bounds.bottom),
    );
    return (c.center - nearest).distance - c.radius;
  }
}

/// D-pad and gyro modes: the D-pad (or the tilt view) on the left, Select,
/// Start and the input readout in the middle, A/B/X/Y on the right.
final class PadLayout {
  const PadLayout({
    required this.leftArea,
    required this.dpad,
    required this.faceButtons,
    required this.select,
    required this.start,
    required this.summary,
  });

  /// Where the D-pad, or in gyro mode the tilt view and Calibrate, go.
  final Rect leftArea;
  final Rect dpad;
  final Rect faceButtons;
  final Rect select;
  final Rect start;

  /// The "Nothing pressed" readout under Start (its top and width).
  final Rect summary;

  /// The drawn radius of A, B, X and Y. Stick mode sizes its buttons
  /// relative to this (C14, C16).
  double get faceButtonRadius => faceButtons.width * FaceGeometry.classic.radius;

  Map<String, ControlShape> get controls => {
    'D-pad': ControlShape.rect(dpad),
    'A/B/X/Y': ControlShape.rect(faceButtons),
    'Select': ControlShape.rect(select),
    'Start': ControlShape.rect(start),
  };
}

PadLayout padLayout(Size size, {double mm = phonePxPerMm}) {
  const centerWidth = 150.0;
  final half = (size.width - centerWidth) / 2;
  final boxWidth = min(half, maxThumbBoxWidthMm * mm);
  final boxHeight = min(size.height, maxThumbBoxHeightMm * mm);
  final boxTop = size.height - boxHeight;
  final leftArea = Rect.fromLTRB(24, boxTop + 8, boxWidth - 8, size.height - 16);
  final rightArea = Rect.fromLTRB(size.width - boxWidth + 8, boxTop + 8, size.width - 24, size.height - 16);

  Rect square(Rect area) {
    final side = max(0.0, min(area.width, area.height));
    return Rect.fromCenter(center: area.center, width: side, height: side);
  }

  // Select, Start and the readout, centered in the thumb boxes' band.
  const pill = Size(96, 44);
  const columnHeight = 44 + 16 + 44 + 24 + 32.0;
  final columnTop = boxTop + (boxHeight - columnHeight) / 2;
  final pillLeft = size.width / 2 - pill.width / 2;
  return PadLayout(
    leftArea: leftArea,
    dpad: square(leftArea),
    faceButtons: square(rightArea),
    select: Rect.fromLTWH(pillLeft, columnTop, pill.width, pill.height),
    start: Rect.fromLTWH(pillLeft, columnTop + 60, pill.width, pill.height),
    summary: Rect.fromLTWH(size.width / 2 - centerWidth / 2, columnTop + 128, centerWidth, 32),
  );
}

/// Stick mode, Xbox-style: the left stick upper left with the D-pad below it
/// toward the middle; A/B/X/Y upper right with the right stick below it
/// toward the middle; Select and Start in the middle; LB and RB above.
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
    required this.faceButtonScale,
  });

  final Rect lb;
  final Rect rb;
  final Rect leftStick;
  final Rect dpad;
  final Rect select;
  final Rect start;

  /// The square holding A/B/X/Y and their touch areas ([FaceGeometry.compact]).
  final Rect faceButtons;
  final Rect rightStick;

  /// Where a floating stick may start: its thumb box (the other controls
  /// sit on top and win where they overlap).
  final Rect leftZone;
  final Rect rightZone;

  /// A, B, X and Y's size relative to D-pad mode. It's the button size
  /// setting, unless the screen has no room for that (C16).
  final double faceButtonScale;

  /// The drawn radius of A, B, X and Y.
  double get faceButtonRadius => faceButtons.width * FaceGeometry.compact.radius;

  StickLayout _shifted(Offset by) => StickLayout(
    lb: lb.shift(by),
    rb: rb.shift(by),
    leftStick: leftStick.shift(by),
    dpad: dpad.shift(by),
    select: select.shift(by),
    start: start.shift(by),
    faceButtons: faceButtons.shift(by),
    rightStick: rightStick.shift(by),
    leftZone: leftZone.shift(by),
    rightZone: rightZone.shift(by),
    faceButtonScale: faceButtonScale,
  );

  /// Every control's touch area, for overlap checks. Fixed sticks take
  /// touches a little beyond their circles, but every control drawn after
  /// them wins there, so the drawn circles count here.
  Map<String, ControlShape> get controls => {
    'LB': ControlShape.rect(lb),
    'RB': ControlShape.rect(rb),
    'left stick': ControlShape.circle(leftStick),
    'D-pad': ControlShape.rect(dpad),
    'Select': ControlShape.rect(select),
    'Start': ControlShape.rect(start),
    'A/B/X/Y': ControlShape.circle(faceButtons),
    'right stick': ControlShape.circle(rightStick),
  };
}

/// A fixed stick takes touches up to 15% beyond its circle.
const double stickTouch = 1.15;

/// Stick mode's margin inside the body, as in v1: left, top, right, bottom.
const stickModeMargin = (left: 4.0, top: 8.0, right: 4.0, bottom: 4.0);

/// [size] is the body, the same as for [padLayout]. [buttonSize] is the
/// button size setting: A, B, X and Y relative to their size in D-pad mode on
/// the same screen (0.6 to 1, C16).
StickLayout stickLayout(Size body, {double mm = phonePxPerMm, double buttonSize = 0.75}) {
  const m = stickModeMargin;
  final layout = _stickLayout(
    Size(body.width - m.left - m.right, body.height - m.top - m.bottom),
    mm: mm,
    buttonSize: buttonSize,
    reference: padLayout(body, mm: mm).faceButtonRadius,
  );
  return layout._shifted(Offset(m.left, m.top));
}

StickLayout _stickLayout(Size size, {required double mm, required double buttonSize, required double reference}) {
  // The v1 sizes were in phone pixels: keep them on phones, and the same
  // physical size on an iPad.
  final u = mm / phonePxPerMm;
  final gap = 8.0 * u;
  final edge = 12.0 * u;
  final shoulderHeight = 40.0 * u;
  final centerWidth = min(140.0 * u, size.width * 0.18);
  final half = (size.width - centerWidth) / 2;
  final boxWidth = min(half, maxThumbBoxWidthMm * mm);
  final boxHeight = min(size.height, maxThumbBoxHeightMm * mm);
  final boxTop = size.height - boxHeight;
  final shoulderWidth = min(130.0 * u, boxWidth * 0.45);
  final top = boxTop + shoulderHeight + gap;
  final available = size.height - top;

  // Left hand, as in v1: a big stick and the D-pad share the box's height.
  final big = min(boxWidth * 0.56, available * 0.58);
  final small = min(boxWidth * 0.46, available - big - gap);
  final leftStick = Rect.fromLTWH(edge, top, big, big);
  final dpad = Rect.fromLTWH(boxWidth - small - gap, size.height - small, small, small);

  // Right hand: A/B/X/Y in the top outer corner at the chosen size, and the
  // right stick in the bottom inner corner, 20% smaller than the left one
  // (C14). Where they'd touch, the stick shrinks first (to 60% of the left
  // one), then the buttons.
  final right = Rect.fromLTRB(size.width - boxWidth + gap, top, size.width - edge, size.height);
  final wanted = reference * buttonSize.clamp(0.6, 1.0);
  const discPerRadius = FaceGeometry.compactSpread + FaceGeometry.compactTouch;

  bool fits(double stickRadius, double buttonRadius) {
    final disc = buttonRadius * discPerRadius;
    if (2 * disc > right.width || 2 * disc > right.height) return false;
    if (2 * stickRadius > right.width || 2 * stickRadius > right.height) return false;
    final face = Offset(right.right - disc, right.top + disc);
    final stick = Offset(right.left + stickRadius, right.bottom - stickRadius);
    return (face - stick).distance >= disc + stickRadius * stickTouch + gap;
  }

  /// The largest value in [low, high] for which [ok] holds ([ok] holds at
  /// [low] and gets harder going up).
  double largest(double low, double high, bool Function(double) ok) {
    if (ok(high)) return high;
    for (var i = 0; i < 30; i++) {
      final mid = (low + high) / 2;
      if (ok(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  final preferredStick = big * 0.8 / 2;
  final minStick = big * 0.6 / 2;
  var stickRadius = preferredStick;
  var buttonRadius = wanted;
  if (!fits(stickRadius, buttonRadius)) {
    if (fits(minStick, buttonRadius)) {
      stickRadius = largest(minStick, preferredStick, (r) => fits(r, buttonRadius));
    } else {
      stickRadius = minStick;
      buttonRadius = largest(0, buttonRadius, (r) => fits(stickRadius, r));
    }
  }
  final disc = buttonRadius * discPerRadius;
  final faceButtons = Rect.fromCircle(center: Offset(right.right - disc, right.top + disc), radius: disc);
  final rightStick = Rect.fromCircle(
    center: Offset(right.left + stickRadius, right.bottom - stickRadius),
    radius: stickRadius,
  );

  final pillWidth = (centerWidth - gap) / 2;
  final pillHeight = 40.0 * u;
  final pillTop = top + available * 0.25;
  final pillLeft = size.width / 2 - centerWidth / 2;

  return StickLayout(
    lb: Rect.fromLTWH(edge, boxTop, shoulderWidth, shoulderHeight),
    rb: Rect.fromLTWH(size.width - edge - shoulderWidth, boxTop, shoulderWidth, shoulderHeight),
    leftStick: leftStick,
    dpad: dpad,
    select: Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
    start: Rect.fromLTWH(pillLeft + pillWidth + gap, pillTop, pillWidth, pillHeight),
    faceButtons: faceButtons,
    rightStick: rightStick,
    leftZone: Rect.fromLTWH(0, top, boxWidth, available),
    rightZone: Rect.fromLTWH(size.width - boxWidth, top, boxWidth, available),
    faceButtonScale: reference > 0 ? buttonRadius / reference : 0,
  );
}
