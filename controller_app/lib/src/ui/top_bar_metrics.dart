import 'package:flutter/widgets.dart';

/// The bar this screen draws over the game (m12-phone-layout §0.7b, m12 §5):
/// its inset inside the safe area — 12 at the left, 8 at the right and 4 above
/// its row — and the 48-high row of icons it holds, which is the touch target a
/// Material icon button gets (C14 to C16 keep the pad's own below this bar).
const barTopPaddingPx = 4.0;
const barPadding = EdgeInsets.fromLTRB(12, barTopPaddingPx, 8, 0);
const barRowHeightPx = 48.0;

/// The bar's height: the pad's body starts below it, and the game shows through
/// it. `leftPadRects` measures the pad's controls from the body's top, so this
/// is the one number the bar and the pad agree on.
const topBarHeightPx = barTopPaddingPx + barRowHeightPx;
