import 'package:flutter/material.dart';

import 'toy_background.dart';

/// The platforms' own page transitions, which [ToyPageTransitionsBuilder]
/// wraps: the look changes what is behind a page, never how it comes in.
const _platformTransitions = PageTransitionsTheme();

/// A page transition that carries a [ToyBackground] with it (M13, docs/design/
/// look-and-sound.md section 5): every page stands on its own sky, so a page
/// sliding over another never shows the one below through it, and the
/// scaffold stays transparent.
///
/// It hands the page to the platform's own transition unchanged
/// ([PageTransitionsTheme]'s default builders). `toyTheme` sets it for every
/// [TargetPlatform]. Dialogs and popups are not page routes, so they keep the
/// app behind them.
class ToyPageTransitionsBuilder extends PageTransitionsBuilder {
  const ToyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => ToyBackground(
    child: _platformTransitions.buildTransitions<T>(route, context, animation, secondaryAnimation, child),
  );
}
