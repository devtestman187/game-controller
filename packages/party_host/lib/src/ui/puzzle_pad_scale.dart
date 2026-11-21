import 'package:flutter/widgets.dart';

import '../providers.dart';
import 'host_frame.dart';

/// What a round's board keeps clear of, in the px the board is laid out in
/// (M16 phonehost3 pad): the pad's rects and its px per mm.
typedef PadClearance = ({List<Rect> rects, double pxPerMm});

/// [pad]'s clearances for a board that fills [boardBox], in the px the board
/// draws with (M16 phonehost3 pad).
///
/// `hostPadProvider` answers in device px: its rects and its `pxPerMm` are
/// measured on the phone's screen, where the host draws its pad, in the box it
/// is asked about. The phone app answers for the board's own box, the room
/// below its bar, moved out of the bar the whole screen would add (M16
/// phonehost3 f1). A board inside [HostFrame] draws in frame px, where one
/// device px is `scale` frame px (`device = frame x s`), so the pad is asked
/// about the device-sized box and its answer is divided by the scale. With no
/// frame above (the TV, "Show on this device") the board is the device, and
/// nothing changes.
PadClearance padClearanceFor(BuildContext context, HostPad pad, Size boardBox) {
  final frame = HostFrameInfo.maybeOf(context);
  if (frame == null) return (rects: pad.rects(boardBox), pxPerMm: pad.pxPerMm);
  return (
    rects: [for (final rect in pad.rects(boardBox * frame.scale)) _frames(rect, frame.scale)],
    pxPerMm: pad.pxPerMm / frame.scale,
  );
}

/// [rect] in frame px, from the device px it was measured in at [scale].
Rect _frames(Rect rect, double scale) =>
    Rect.fromLTRB(rect.left / scale, rect.top / scale, rect.right / scale, rect.bottom / scale);
