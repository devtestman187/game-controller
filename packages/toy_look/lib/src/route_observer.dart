import 'package:flutter/widgets.dart';

/// Tells its owner when a page route is pushed, popped or replaced (M13 design D1): the
/// palette is worked out again at those moments, and nowhere in the middle of
/// a round.
///
/// It says nothing about a dialog or a popup, which are not page routes: a
/// pause menu or a waiting card never changes the look under it. The apps put
/// it in their `navigatorObservers`, and the phone host's own navigator too,
/// each with the look's own refresh as its callback.
final class ToyLookRouteObserver extends NavigatorObserver {
  ToyLookRouteObserver(this.onPageRouteChanged);

  /// Called when a page route arrives or leaves: the moment to work the look
  /// out again.
  final VoidCallback onPageRouteChanged;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    super.didPush(route, previousRoute);
    _changed(route);
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    super.didPop(route, previousRoute);
    _changed(route);
  }

  /// A page swapped for another (the join screen handing over to a round with
  /// `pushReplacement`): the round starts in the palette of its moment.
  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _changed(newRoute);
  }

  void _changed(Route<Object?> route) {
    if (route is PageRoute<Object?>) onPageRouteChanged();
  }
}
