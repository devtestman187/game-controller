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

/// The left hand's controls as the app draws them in stick mode, which a
/// tablet starts in (a phone starts in the D-pad mode above): the left stick's
/// disc, then the D-pad's four arms. A tablet's one-board round keeps its
/// board clear of these (m13 s18); each iPad's three pads are the app's own
/// geometry at its density, in its box.
const iPadLandscapePad = [
  Rect.fromLTRB(13.9, 758.2, 165.8, 910.0),
  Rect.fromLTRB(240.0, 916.6, 275.1, 968.3),
  Rect.fromLTRB(240.0, 968.3, 275.1, 1020.0),
  Rect.fromLTRB(205.8, 950.7, 257.5, 985.9),
  Rect.fromLTRB(257.5, 950.7, 309.2, 985.9),
];

/// The same pad on the smaller iPad in landscape, 1180 x 820.
const iPadSmallLandscapePad = [
  Rect.fromLTRB(13.9, 554.2, 165.8, 706.0),
  Rect.fromLTRB(240.0, 712.6, 275.1, 764.3),
  Rect.fromLTRB(240.0, 764.3, 275.1, 816.0),
  Rect.fromLTRB(205.8, 746.7, 257.5, 781.9),
  Rect.fromLTRB(257.5, 746.7, 309.2, 781.9),
];

/// The same pad on the owner's iPad in portrait, 1024 x 1366.
const iPadPortraitStickPad = [
  Rect.fromLTRB(13.9, 1100.2, 165.8, 1252.0),
  Rect.fromLTRB(240.0, 1258.6, 275.1, 1310.3),
  Rect.fromLTRB(240.0, 1310.3, 275.1, 1362.0),
  Rect.fromLTRB(205.8, 1292.7, 257.5, 1327.9),
  Rect.fromLTRB(257.5, 1292.7, 309.2, 1327.9),
];

/// The same pad on a phone held on its side, 852 x 393, at the phone's
/// density: a phone keeps the picture it had (m13 s18).
const phoneLandscapePad = [
  Rect.fromLTRB(16.0, 108.0, 179.0, 271.0),
  Rect.fromLTRB(274.3, 279.0, 311.7, 334.0),
  Rect.fromLTRB(274.3, 334.0, 311.7, 389.0),
  Rect.fromLTRB(238.0, 315.3, 293.0, 352.7),
  Rect.fromLTRB(293.0, 315.3, 348.0, 352.7),
];
