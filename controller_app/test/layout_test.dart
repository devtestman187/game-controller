import 'dart:ui';

import 'package:controller/src/layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protocol/protocol.dart';

/// A screen to test on: the body size (below the top bar, inside the safe
/// area) and its pixels per millimetre.
typedef Screen = ({Size body, double mm, bool tablet});

/// Phones in landscape: both test phones (an iPhone 15-class iPhone and a
/// Pixel-class Android phone), others for range, a small 16:9 phone and the
/// smallest window the controller lays out in.
const Map<String, Screen> phones = {
  'iPhone SE': (body: Size(667, 300), mm: phonePxPerMm, tablet: false),
  'iPhone 15': (body: Size(734, 318), mm: phonePxPerMm, tablet: false),
  'iPhone 15 Pro Max': (body: Size(814, 355), mm: phonePxPerMm, tablet: false),
  'Pixel 7': (body: Size(869, 352), mm: phonePxPerMm, tablet: false),
  'Galaxy S24': (body: Size(780, 330), mm: phonePxPerMm, tablet: false),
  'small 16:9 phone': (body: Size(640, 304), mm: phonePxPerMm, tablet: false),
  'smallest window': (body: minBodySize, mm: phonePxPerMm, tablet: false),
};

/// Tablets, an unfolded foldable, and half-screen split windows.
const Map<String, Screen> tablets = {
  'iPad 11-inch': (body: Size(1180, 740), mm: iPadPxPerMm, tablet: true),
  'iPad Pro 13-inch': (body: Size(1376, 952), mm: iPadPxPerMm, tablet: true),
  'iPad mini': (body: Size(1133, 670), mm: iPadPxPerMm, tablet: true),
  'Android tablet 11-inch': (body: Size(1280, 744), mm: phonePxPerMm, tablet: true),
  'Android tablet 8-inch': (body: Size(1024, 544), mm: phonePxPerMm, tablet: true),
  'unfolded foldable': (body: Size(841, 645), mm: phonePxPerMm, tablet: true),
  'Android tablet, half split screen': (body: Size(640, 744), mm: phonePxPerMm, tablet: true),
  'iPad, half split screen': (body: Size(590, 740), mm: iPadPxPerMm, tablet: true),
};

const buttonSizes = [0.6, 0.7, 0.75, 0.8, 0.9, 1.0];

void expectOnScreen(Map<String, ControlShape> controls, Size size) {
  final screen = Offset.zero & size;
  for (final MapEntry(key: name, value: shape) in controls.entries) {
    final r = shape.bounds;
    expect(
      r.left >= -1e-6 && r.top >= -1e-6 && r.right <= screen.right + 1e-6 && r.bottom <= screen.bottom + 1e-6,
      isTrue,
      reason: '$name $r is outside $size',
    );
  }
}

void expectNoOverlaps(Map<String, ControlShape> controls) {
  final list = controls.entries.toList();
  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      expect(
        list[i].value.distanceTo(list[j].value),
        greaterThanOrEqualTo(-1e-6),
        reason: '${list[i].key} overlaps ${list[j].key}',
      );
    }
  }
}

void main() {
  final all = {...phones, ...tablets};

  group('stick mode', () {
    for (final MapEntry(key: name, value: screen) in all.entries) {
      test('$name: every control is on screen and none overlap, at every button size', () {
        for (final size in buttonSizes) {
          final layout = stickLayout(screen.body, mm: screen.mm, buttonSize: size);
          expectOnScreen(layout.controls, screen.body);
          expectNoOverlaps(layout.controls);
        }
      });

      test('$name: A/B/X/Y never take touches from the right stick (C15)', () {
        for (final size in buttonSizes) {
          final l = stickLayout(screen.body, mm: screen.mm, buttonSize: size);
          // The right stick takes touches 15% beyond its circle.
          final stickTouchArea = ControlShape.circle(
            Rect.fromCircle(center: l.rightStick.center, radius: l.rightStick.width / 2 * stickTouch),
          );
          expect(ControlShape.circle(l.faceButtons).distanceTo(stickTouchArea), greaterThanOrEqualTo(-1e-6));
        }
      });

      test('$name: the button size setting is never exceeded, and bigger is never smaller', () {
        var previous = 0.0;
        for (final size in buttonSizes) {
          final l = stickLayout(screen.body, mm: screen.mm, buttonSize: size);
          expect(l.faceButtonScale, lessThanOrEqualTo(size + 1e-9));
          expect(l.faceButtonRadius, greaterThanOrEqualTo(previous - 1e-6));
          previous = l.faceButtonRadius;
        }
      });
    }

    for (final MapEntry(key: name, value: screen) in {...phones, ...tablets}.entries) {
      if (name == 'smallest window') continue;
      test('$name: A, B, X and Y are about 75% of D-pad mode by default (C14)', () {
        final l = stickLayout(screen.body, mm: screen.mm);
        expect(l.faceButtonScale, closeTo(0.75, 0.01));
        final dpadMode = padLayout(screen.body, mm: screen.mm).faceButtonRadius;
        expect(l.faceButtonRadius, closeTo(0.75 * dpadMode, 0.01 * dpadMode));
      });
    }

    for (final MapEntry(key: name, value: screen) in phones.entries) {
      test('$name: thumb-sized controls (C14)', () {
        final l = stickLayout(screen.body, mm: screen.mm);
        expect(l.leftStick.width, greaterThanOrEqualTo(110));
        // The right stick is about 20% smaller than the left one (a little
        // more where the buttons need the room).
        expect(l.rightStick.width, inInclusiveRange(l.leftStick.width * 0.75, l.leftStick.width * 0.8 + 1e-6));
        expect(l.dpad.width, greaterThanOrEqualTo(70));
        // Bigger than v1's stick-mode buttons (0.16 of a square as wide as
        // the D-pad).
        expect(l.faceButtonRadius, greaterThan(0.16 * l.dpad.width * 1.5));
      });
    }

    test('on phones the biggest size is reached, or the right stick and buttons give way without overlapping', () {
      for (final MapEntry(key: name, value: screen) in phones.entries) {
        final l = stickLayout(screen.body, mm: screen.mm, buttonSize: 1);
        expect(l.faceButtonScale, greaterThan(0.8), reason: name);
        expect(l.rightStick.width, greaterThanOrEqualTo(l.leftStick.width * 0.6 - 1e-6), reason: name);
      }
    });

    test('Xbox arrangement: left stick above the D-pad, A/B/X/Y above the right stick, Select left of Start', () {
      for (final screen in all.values) {
        final l = stickLayout(screen.body, mm: screen.mm);
        expect(l.leftStick.center.dy, lessThan(l.dpad.center.dy));
        expect(l.leftStick.center.dx, lessThan(l.dpad.center.dx));
        expect(l.faceButtons.center.dy, lessThan(l.rightStick.center.dy));
        expect(l.faceButtons.center.dx, greaterThan(l.rightStick.center.dx));
        expect(l.select.center.dx, lessThan(l.start.center.dx));
        expect(l.lb.center.dx, lessThan(l.rb.center.dx));
      }
    });
  });

  group('D-pad and gyro modes', () {
    for (final MapEntry(key: name, value: screen) in all.entries) {
      test('$name: every control is on screen and none overlap', () {
        final l = padLayout(screen.body, mm: screen.mm);
        expectOnScreen(l.controls, screen.body);
        expectNoOverlaps(l.controls);
        expect(l.dpad.width, greaterThan(100));
        expect(l.faceButtons.width, greaterThan(100));
      });
    }

    for (final MapEntry(key: name, value: screen) in phones.entries) {
      test('$name: looks as it did in v1', () {
        final l = padLayout(screen.body, mm: screen.mm);
        final half = (screen.body.width - 150) / 2;
        final v1Side = [half - 32, screen.body.height - 24].reduce((a, b) => a < b ? a : b);
        // Only the very largest phones lose a few percent to the size cap.
        expect(l.dpad.width, inInclusiveRange(v1Side * 0.95, v1Side));
        expect(l.faceButtons.width, l.dpad.width);
        expect(l.select.center.dx, closeTo(screen.body.width / 2, 1e-6));
      });
    }
  });

  group('sized in millimetres (C31)', () {
    for (final MapEntry(key: name, value: screen) in tablets.entries) {
      test('$name: controls stay thumb-sized and in the bottom corners, leaving the middle free', () {
        final mm = screen.mm;
        final width = screen.body.width;
        for (final layout in [
          stickLayout(screen.body, mm: mm).controls,
          stickLayout(screen.body, mm: mm, buttonSize: 1).controls,
          padLayout(screen.body, mm: mm).controls,
        ]) {
          for (final MapEntry(key: control, value: shape) in layout.entries) {
            final r = shape.bounds;
            // Within reach of a thumb holding the tablet: near the bottom.
            // (Stick mode keeps a 4-pixel margin from the screen's edges.)
            expect(screen.body.height - r.top, lessThanOrEqualTo(maxThumbBoxHeightMm * mm + 4 + 1e-6), reason: control);
            if (control == 'Select' || control == 'Start') continue;
            // Near one side.
            final fromSide = r.center.dx < width / 2 ? r.right : width - r.left;
            expect(fromSide, lessThanOrEqualTo(maxThumbBoxWidthMm * mm + 4 + 1e-6), reason: control);
          }
        }
        // Sticks and buttons no bigger than on a big phone.
        final l = stickLayout(screen.body, mm: mm);
        expect(l.leftStick.width / mm, lessThanOrEqualTo(32));
        expect(padLayout(screen.body, mm: mm).dpad.width / mm, lessThanOrEqualTo(55));
      });
    }

    test('an iPad and an Android tablet get the same physical sizes', () {
      final ipad = stickLayout(tablets['iPad 11-inch']!.body, mm: iPadPxPerMm);
      final android = stickLayout(tablets['Android tablet 11-inch']!.body, mm: phonePxPerMm);
      expect(ipad.leftStick.width / iPadPxPerMm, closeTo(android.leftStick.width / phonePxPerMm, 0.5));
      expect(ipad.faceButtonRadius / iPadPxPerMm, closeTo(android.faceButtonRadius / phonePxPerMm, 0.5));
    });

    test('tablets and phones are told apart by the shorter screen side', () {
      expect(isTabletScreen(const Size(852, 393)), isFalse); // iPhone 15
      expect(isTabletScreen(const Size(1180, 820)), isTrue); // iPad
      expect(isTabletScreen(const Size(1280, 800)), isTrue); // Android tablet
      expect(pxPerMmFor(isIOS: true, isTablet: true), iPadPxPerMm);
      expect(pxPerMmFor(isIOS: true, isTablet: false), phonePxPerMm);
      expect(pxPerMmFor(isIOS: false, isTablet: true), phonePxPerMm);
    });
  });

  group('face buttons', () {
    for (final geometry in [FaceGeometry.classic, FaceGeometry.compact]) {
      test(
        '${geometry == FaceGeometry.classic ? 'classic' : 'compact'}: each center hits its button, the middle nothing',
        () {
          for (final MapEntry(key: button, value: center) in geometry.centers.entries) {
            expect(geometry.buttonAt(center * 200, 200), button);
          }
          expect(geometry.buttonAt(const Offset(100, 100), 200), isNull);
        },
      );
    }

    test('compact: a touch 14% beyond a drawn edge still counts, and goes to the nearest button (C15)', () {
      const g = FaceGeometry.compact;
      const side = 300.0;
      for (final MapEntry(key: button, value: center) in g.centers.entries) {
        final outward = (center - const Offset(0.5, 0.5)) / (center - const Offset(0.5, 0.5)).distance;
        final touch = (center + outward * g.radius * 1.14) * side;
        expect(g.takes(touch, side), isTrue);
        expect(g.buttonAt(touch, side), button);
        // Beyond the touch area nothing counts.
        expect(g.buttonAt((center + outward * g.radius * 1.2) * side, side), isNull);
      }
      // Halfway between Y and B goes to neither one by accident: whichever is
      // nearer wins.
      final y = g.centers[ControllerButton.y]!;
      final b = g.centers[ControllerButton.b]!;
      expect(g.buttonAt((y * 0.6 + b * 0.4) * side, side), ControllerButton.y);
      expect(g.buttonAt((y * 0.4 + b * 0.6) * side, side), ControllerButton.b);
    });

    test('compact: the square corners take no touches (they can lie over the right stick)', () {
      expect(FaceGeometry.compact.takes(const Offset(5, 5), 300), isFalse);
      expect(FaceGeometry.compact.takes(const Offset(295, 295), 300), isFalse);
      expect(FaceGeometry.classic.takes(const Offset(5, 5), 300), isTrue);
    });
  });

  test('the overlap check measures gaps between rectangles and circles', () {
    const a = ControlShape.rect(Rect.fromLTWH(0, 0, 10, 10));
    const b = ControlShape.rect(Rect.fromLTWH(13, 14, 10, 10));
    const c = ControlShape.circle(Rect.fromLTWH(20, 0, 10, 10));
    expect(a.distanceTo(b), closeTo(5, 1e-9));
    expect(a.distanceTo(c), closeTo(10, 1e-9));
    expect(c.distanceTo(const ControlShape.circle(Rect.fromLTWH(20, 8, 10, 10))), lessThan(0));
    expect(a.distanceTo(const ControlShape.rect(Rect.fromLTWH(5, 5, 10, 10))), lessThan(0));
  });
}
