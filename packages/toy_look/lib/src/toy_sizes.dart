import 'dart:ui' show Offset;

/// The look's sizes (M13, docs/design/look-and-sound.md section 3), in
/// logical pixels. They're the same in both palettes: the palette is only
/// colour, so a screen is measured once.
///
/// The two instances differ only in the outline's width; every other size is a
/// constant shared by both.
final class ToySizes {
  const ToySizes._({required this.outlineWidth});

  /// A menu's outline: 3 px, the size the mock-ups draw (design section 3).
  static const menu = ToySizes._(outlineWidth: 3);

  /// A TV screen's outline: 4 px, to read from 3 metres (design section 3).
  static const tv = ToySizes._(outlineWidth: 4);

  /// How wide this screen's ink outlines are.
  final double outlineWidth;

  /// How far a widget's hard shadow falls: 3 px right and 4 px down, like a
  /// sticker rather than a blur (design section 3).
  static const shadowOffset = Offset(3, 4);

  /// The corner radius of a card and a dialog (design section 4).
  static const cardCorner = 16.0;

  /// The focus ring outside a button's ink edge (design section 4).
  static const focusRing = 4.0;

  /// The spacing scale (design section 3; project-notes.md's scale): the only
  /// gaps and paddings a look widget uses.
  static const space4 = 4.0;

  /// The spacing scale's second step, 8 px.
  static const space8 = 8.0;

  /// The spacing scale's third step, 12 px.
  static const space12 = 12.0;

  /// The spacing scale's fourth step, 16 px.
  static const space16 = 16.0;

  /// The spacing scale's fifth step, 24 px.
  static const space24 = 24.0;

  /// The spacing scale's last step, 32 px.
  static const space32 = 32.0;
}
