import 'dart:ui';

/// The iPad's density, points per inch to px per mm: `controller_app`'s
/// `iPadPxPerMm`, which sizes the pad the app draws on a tablet.
const iPadPxPerMm = 132 / 25.4;

/// The left hand's controls as `controller_app`'s `leftPadRects` reports them
/// in the D-pad mode, in the box's px, to a tenth of a px: the app's own
/// geometry, worked out with [iPadPxPerMm] on a tablet and with the phone's
/// 160 points per inch (`phonePxPerMm`) on a phone, and laid out in the body
/// under the app's 52 px top bar. The game is told where the pad is rather
/// than knowing it (m12-opponent-mirror rules 3 and 6), so the tests pass
/// what the app passes: this iPad is the owner's, in portrait, joined to a
/// phone (device test 3, Nov 9).
const iPadPortraitPad = [
  Rect.fromLTRB(116.7, 1072.6, 211.1, 1211.3),
  Rect.fromLTRB(116.7, 1211.3, 211.1, 1350.0),
  Rect.fromLTRB(25.2, 1164.1, 163.9, 1258.5),
  Rect.fromLTRB(163.9, 1164.1, 302.6, 1258.5),
];

/// The same pad on the smaller iPad in portrait, 820 x 1180: the D-pad sits at
/// the body's bottom left, so its x is the same and only its y moves.
const iPadSmallPad = [
  Rect.fromLTRB(116.7, 886.6, 211.1, 1025.3),
  Rect.fromLTRB(116.7, 1025.3, 211.1, 1164.0),
  Rect.fromLTRB(25.2, 978.1, 163.9, 1072.5),
  Rect.fromLTRB(163.9, 978.1, 302.6, 1072.5),
];

/// The same pad on a phone held upright, 393 x 852, at the phone's density.
const phonePortraitPad = [
  Rect.fromLTRB(53.5, 620.6, 84.0, 665.3),
  Rect.fromLTRB(53.5, 665.3, 84.0, 710.1),
  Rect.fromLTRB(24.0, 650.1, 68.8, 680.5),
  Rect.fromLTRB(68.8, 650.1, 113.5, 680.5),
];
