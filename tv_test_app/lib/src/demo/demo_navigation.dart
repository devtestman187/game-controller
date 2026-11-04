import 'package:flutter/widgets.dart';

import 'demo_flags.dart';
import 'demo_live.dart';

/// The TV screens the director logs (docs/demo-video-runbook.md 2.3: `screen`
/// events on TV navigation). Route names only exist in a demo build, so the
/// app routes exactly as before in every other build.
RouteSettings? demoRouteSettings(String name) => demoDirector ? RouteSettings(name: name) : null;

/// Logs every named route the TV opens, changes or pops back to as a `screen`
/// event, so R1's story check can see home, then games, then the puzzle list,
/// then join. Only installed when `demoDirector` is true (main.dart); until
/// the director is listening [DemoLive.reportEvent] is a no-op.
///
/// The home route is unnamed (it is MaterialApp's `home`), so the first route
/// pushed is recorded as `home`. `/games` (the pause menu's route name) is
/// reported as `games`.
class DemoScreenObserver extends NavigatorObserver {
  final _stack = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(_nameOf(route, first: _stack.isEmpty));
    _reportTop();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _stack.add(_nameOf(newRoute));
    _reportTop();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _reportTop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _reportTop();
  }

  /// The screen's event name: the route's setting without its leading slash,
  /// `home` for the unnamed first route, and empty for an unnamed screen
  /// (dialogs, for example), which is not reported.
  static String _nameOf(Route<dynamic>? route, {bool first = false}) {
    final name = route?.settings.name;
    if (name == null) return first ? 'home' : '';
    return name.startsWith('/') ? name.substring(1) : name;
  }

  void _reportTop() {
    if (_stack.isEmpty) return;
    final top = _stack.last;
    if (top.isEmpty) return;
    DemoLive.instance.reportScreen(top);
  }
}
