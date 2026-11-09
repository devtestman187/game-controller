import 'dart:ui' show FragmentProgram;

import 'look_choice.dart';
import 'toy_colors.dart';
import 'toy_shaders.dart';
import 'toy_sizes.dart';
import 'toy_type.dart';

/// Everything a screen needs to look like a toy (M13, docs/design/look-and-sound.md):
/// which palette it is, its colours, sizes and type, and the shader (or the
/// fallback) that fills a game object's body.
///
/// It's a plain value, so a painter takes one as an argument (design D5) and
/// the board looks the same on the TV and on every phone. Widgets read it from
/// the [ToyLookScope] above them.
final class ToyLook {
  const ToyLook({
    required this.palette,
    required this.colors,
    required this.sizes,
    required this.type,
    required this.shade,
    required this.backdrop,
    required this.effects,
  });

  /// The look for [palette] on a TV ([tv]) or on a phone, with [shaders]'s body
  /// shader when [effects] are on (design D8: effects off drops the shader and
  /// keeps every colour and shape).
  factory ToyLook.build({
    required ToyPalette palette,
    required bool tv,
    ToyShaders shaders = ToyShaders.none,
    bool effects = true,
  }) {
    return ToyLook(
      palette: palette,
      colors: ToyColors.of(palette),
      sizes: tv ? ToySizes.tv : ToySizes.menu,
      type: tv ? ToyType.tv : ToyType.phone,
      shade: effects ? shaders.shade : null,
      backdrop: effects ? shaders.backdrop : null,
      effects: effects,
    );
  }

  /// Which palette this look draws: Sunny or Night (design D1).
  final ToyPalette palette;

  /// The palette's colours (design section 3).
  final ToyColors colors;

  /// The outline and spacing sizes (design section 3).
  final ToySizes sizes;

  /// The fonts and their sizes (design section 3).
  final ToyType type;

  /// The body shader, or null when effects are off or the device couldn't load
  /// it; every caller then uses the Canvas fallback (design section 6).
  final FragmentProgram? shade;

  /// The backdrop shader that fills the sky behind every page, or null when
  /// effects are off or the device couldn't load it; the sky then draws its
  /// Canvas dots at the same drift (design section 6).
  final FragmentProgram? backdrop;

  /// Whether the device's effects setting is on (design D8).
  final bool effects;

  /// Equal when every field is: the fields are const values, so two looks built
  /// the same way hold the same ones.
  @override
  bool operator ==(Object other) =>
      other is ToyLook &&
      other.palette == palette &&
      other.colors == colors &&
      other.sizes == sizes &&
      other.type == type &&
      other.shade == shade &&
      other.backdrop == backdrop &&
      other.effects == effects;

  @override
  int get hashCode => Object.hash(palette, colors, sizes, type, shade, backdrop, effects);
}
