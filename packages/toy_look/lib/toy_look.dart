/// The "Toy Box Toon" look (M13, docs/design/look-and-sound.md): the shader
/// and the Canvas fallback that draw every game object the same way.
///
/// The whole look lives here (L1): a later change of look touches this
/// package only, and rules code never imports it.
library;

export 'src/toy_shape.dart';
export 'src/toy_shaders.dart';
