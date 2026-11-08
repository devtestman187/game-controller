import 'package:flutter/widgets.dart';

import 'toy_look.dart';

/// Hands the look down the widget tree (design D5): the apps put one above
/// `MaterialApp`, and every widget below reads it with [of].
///
/// Painters don't use this: a painter takes its [ToyLook] as an argument, so
/// the same painter draws on the TV, the host phone and a joined phone.
final class ToyLookScope extends InheritedWidget {
  const ToyLookScope({super.key, required this.look, required super.child});

  /// The look every widget below this scope reads.
  final ToyLook look;

  /// The look above [context].
  ///
  /// It's an error to call this with no [ToyLookScope] above: the apps put one
  /// above every screen, so a missing one is a wiring mistake that should show
  /// up in the first test rather than draw with no look.
  static ToyLook of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ToyLookScope>();
    assert(scope != null, 'ToyLookScope.of() needs a ToyLookScope above this widget');
    return scope!.look;
  }

  /// Only an equal look leaves the widgets below alone, so a screen rebuilds
  /// when the palette, the device type or the effects setting changes.
  @override
  bool updateShouldNotify(ToyLookScope oldWidget) => look != oldWidget.look;
}
