import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:toy_look/toy_look.dart';

/// The frame every host screen is drawn in, in frame px (M16 phonehost1 S1,
/// DESIGN section 1, rule 1): the TV's 960x540. Screens are one layout for
/// every device, drawn in this frame and scaled to the screen.
const _designFrameWidthPx = 960.0;
const _designFrameHeightPx = 540.0;

/// The spare dimension that earns Thumby his own edge of the frame, in frame
/// px (DESIGN section 3): 120. Below it he takes the footer's corner instead.
const _thumbyEdgeMinPx = 120.0;

/// One device pixel ratio inside the frame: a frame pixel is a logical pixel,
/// whatever the device draws it at (DESIGN section 2).
const _frameDevicePixelRatio = 1.0;

/// The host app's one layout, scaled to the device (M16 phonehost1 S1, DESIGN
/// sections 2 and 5).
///
/// It takes the device's size, works out `s = min(W/960, H/540)` and lays
/// [child] out at the frame that follows, `(W/s, H/s)`, in a [FittedBox] whose
/// scale is `s`. The frame is 960x540 on a 16:9 device and keeps the device's
/// spare dimension the other way round: extra width on a wide phone, extra
/// height on a tablet, never both. Inside it every screen reads
/// [MediaQuery.size] as the frame's size and a device pixel ratio of 1, so
/// text sizes, hit testing, the focus ring and the TV's d-pad all work in frame
/// px and the transform does the rest. It also drops the device's text scale,
/// which would only overflow the fixed layout, and gives its screens the look
/// it finds above it in [ToyType.frame] (DESIGN section 5).
///
/// The host apps put it above the navigator with [hostFrameBuilder], so every
/// screen, dialog and overlay is in the frame.
class HostFrame extends StatelessWidget {
  const HostFrame({super.key, required this.child});

  /// The host's screens, laid out in the frame and drawn scaled to the device.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final device = MediaQuery.of(context);
    final size = device.size;
    // A minimised window, or the first layout before the device's size
    // arrives, has nothing to scale: s would be 0 and the frame infinite.
    if (size.isEmpty) return const SizedBox.shrink();
    final scale = math.min(size.width / _designFrameWidthPx, size.height / _designFrameHeightPx);
    final frame = Size(size.width / scale, size.height / scale);
    return FittedBox(
      // The frame has the device's shape, so it fills the box exactly; a
      // device that rounds differently is fitted, never stretched.
      child: SizedBox(
        width: frame.width,
        height: frame.height,
        child: MediaQuery(
          data: _frameMedia(device, frame, scale),
          child: HostFrameInfo(scale: scale, frame: frame, child: _frameLook(context, child)),
        ),
      ),
    );
  }
}

/// What a screen inside the frame reads from [MediaQuery]: the frame's own
/// size, one pixel ratio, the device's insets divided by the scale so a safe
/// area still covers the same strip of the screen, and no text scaling.
///
/// The frame is a fixed 960x540 layout (DESIGN section 1, rule 1), so a phone's
/// larger system text would only overflow it: the screens are drawn at their
/// frame sizes and the scale does the rest (DESIGN section 5).
MediaQueryData _frameMedia(MediaQueryData device, Size frame, double scale) => device.copyWith(
  size: frame,
  devicePixelRatio: _frameDevicePixelRatio,
  padding: device.padding / scale,
  viewPadding: device.viewPadding / scale,
  viewInsets: device.viewInsets / scale,
  textScaler: TextScaler.noScaling,
);

/// [child] in the frame's type (DESIGN section 5: "the host picks `frame` when
/// it is inside `HostFrame`").
///
/// The host app's scope holds the phone's look - the same app draws the pad
/// screens - so the frame hands its screens that look with [ToyType.frame] for
/// its type. With no look above it, the child is left as it is: the frame
/// draws the host's screens but does not choose the palette.
Widget _frameLook(BuildContext context, Widget child) {
  final look = ToyLookScope.maybeOf(context);
  if (look == null) return child;
  return ToyLookScope(look: look.withType(ToyType.frame), child: child);
}

/// What the host's screens read about their frame (M16 phonehost1 S1, DESIGN
/// sections 2 and 3): the scale they are drawn at, the frame they are laid out
/// in, and the room the device has to spare.
///
/// A screen asks [of] or [maybeOf] for it; it is rebuilt when the frame changes
/// (a rotation, a window resize).
class HostFrameInfo extends InheritedWidget {
  const HostFrameInfo({super.key, required this.scale, required this.frame, required super.child});

  /// How many device logical pixels one frame pixel is drawn at.
  final double scale;

  /// The size the host's screens are laid out in, in frame px: 960x540 or that
  /// plus the device's spare dimension.
  final Size frame;

  /// The frame's spare width in frame px, zero unless the device is wider than
  /// 16:9 (DESIGN section 2). Thumby's column takes it (DESIGN section 3).
  double get extraW => math.max(0, frame.width - _designFrameWidthPx);

  /// The frame's spare height in frame px, zero unless the device is taller
  /// than 16:9 (DESIGN section 2). Thumby's strip takes it (DESIGN section 3).
  /// At most one of [extraW] and [extraH] is above zero.
  double get extraH => math.max(0, frame.height - _designFrameHeightPx);

  /// Where Thumby stands in this frame (DESIGN section 3): a side column when
  /// the frame is wider, a bottom strip when it is taller, and the footer's
  /// corner on a 16:9 frame, which has no room to spare.
  ThumbySpot get thumbySpot {
    if (extraW >= _thumbyEdgeMinPx) return ThumbySpot.side;
    if (extraH >= _thumbyEdgeMinPx) return ThumbySpot.strip;
    return ThumbySpot.corner;
  }

  /// The frame this widget is in, or null outside a [HostFrame].
  static HostFrameInfo? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HostFrameInfo>();

  /// The frame this widget is in. A screen that needs one is always inside
  /// [HostFrame] in the app, so a call that finds none is a bug.
  static HostFrameInfo of(BuildContext context) {
    final info = maybeOf(context);
    if (info == null) {
      throw FlutterError('HostFrameInfo.of found no HostFrame above this widget: a host screen is drawn in the frame.');
    }
    return info;
  }

  @override
  bool updateShouldNotify(HostFrameInfo oldWidget) => scale != oldWidget.scale || frame != oldWidget.frame;
}

/// Where Thumby stands in a frame (M16 phonehost1 S1, DESIGN section 3).
enum ThumbySpot {
  /// A column down the right of a frame wider than 16:9, up to 240 px wide.
  side,

  /// A strip along the bottom of a frame taller than 16:9, up to 180 px high.
  strip,

  /// The footer's left slot on a 16:9 frame, which has no room to spare; the
  /// review fix of Nov 20, 2026 keeps him out of the footer's buttons there.
  corner,
}

/// The room Thumby takes in the host's frame (M16 phonehost1 S1, DESIGN
/// sections 3 and 5).
///
/// M16 ships it empty: until M17 draws him the stage keeps the whole frame, so
/// no screen moves when he arrives. It reads [HostFrameInfo], so the spot it
/// will draw in is the frame's, and the screens that place it already rebuild
/// when the frame changes shape.
class ThumbySlot extends StatelessWidget {
  const ThumbySlot({super.key});

  @override
  Widget build(BuildContext context) {
    final spot = HostFrameInfo.maybeOf(context)?.thumbySpot;
    // The key follows the spot, so M17's character starts afresh when he moves
    // from one spot to another (a phone rotated, a window resized) instead of
    // carrying the last shape's state into it.
    return SizedBox.shrink(key: ValueKey<ThumbySpot?>(spot));
  }
}

/// The host apps' `MaterialApp.builder` (M16 phonehost1 S1, DESIGN section 5):
/// one [HostFrame] over the navigator, so every screen, dialog and overlay is
/// drawn in the design frame.
Widget hostFrameBuilder(BuildContext context, Widget? child) => HostFrame(child: child ?? const SizedBox.shrink());
