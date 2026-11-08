/// The "Toy Box Toon" look (M13, docs/design/look-and-sound.md): the palettes
/// and the Look setting, the fonts and their type, the theme, the shader and
/// the Canvas fallback that draw every game object the same way.
///
/// The whole look lives here (L1): a later change of look touches this
/// package only, and rules code never imports it.
library;

export 'src/look_choice.dart';
export 'src/toy_colors.dart';
export 'src/toy_font_licenses.dart';
export 'src/toy_look.dart';
export 'src/toy_look_scope.dart';
export 'src/toy_shape.dart';
export 'src/toy_shaders.dart';
export 'src/toy_sizes.dart';
export 'src/toy_theme.dart';
export 'src/toy_type.dart';
