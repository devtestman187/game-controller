import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvtest/src/demo/demo_live.dart';
import 'package:tvtest/src/demo/demo_navigation.dart';

/// The TV's `screen` events (docs/demo-video-runbook.md 2.3 and 2.8 step 3):
/// a demo build reports every route change, a store build names no route and
/// installs no observer.
void main() {
  Route<void> route(String? name) => MaterialPageRoute<void>(
    settings: name == null ? null : RouteSettings(name: name),
    builder: (_) => const SizedBox.shrink(),
  );

  test('a store build gives the demo screens no route name', () {
    // demoDirector is false in a test build (demo_flags_test.dart), so every
    // demoRouteSettings call returns null: the routes are exactly as before.
    expect(demoRouteSettings('join'), isNull);
    expect(demoRouteSettings('puzzle list'), isNull);
  });

  test('the observer reports home, games, the puzzle list and join, in order', () {
    final events = <String>[];
    DemoLive.instance.onEvent = (name, [data]) => events.add('$name:${data?['screen']}');
    addTearDown(() {
      DemoLive.instance.onEvent = null;
      DemoLive.instance.currentScreen = 'home';
    });

    final observer = DemoScreenObserver();
    final home = route(null); // MaterialApp's home route has no name.
    final games = route('/games');
    final list = route('puzzle list');
    final join = route('join');
    observer.didPush(home, null);
    observer.didPush(games, home);
    observer.didPush(list, games);
    observer.didPush(join, list);

    expect(events, ['screen:home', 'screen:games', 'screen:puzzle list', 'screen:join']);
    expect(DemoLive.instance.currentScreen, 'join');

    // Back to the puzzle list: the pop reports the screen underneath.
    observer.didPop(join, list);
    expect(events.last, 'screen:puzzle list');
    expect(DemoLive.instance.currentScreen, 'puzzle list');
  });

  test('a replaced screen is reported (join -> match), not the one it replaced', () {
    final screens = <String>[];
    DemoLive.instance.onEvent = (name, [data]) {
      if (name == 'screen') screens.add('${data?['screen']}');
    };
    addTearDown(() {
      DemoLive.instance.onEvent = null;
      DemoLive.instance.currentScreen = 'home';
    });

    final observer = DemoScreenObserver();
    final join = route('join');
    final match = route('match');
    observer.didPush(join, null);
    observer.didReplace(newRoute: match, oldRoute: join);
    expect(screens, ['join', 'match']);
    expect(DemoLive.instance.currentScreen, 'match');
  });

  test('reportEvent does nothing when no director is listening', () {
    DemoLive.instance.onEvent = null;
    // A store build never installs the sink; this must not throw.
    DemoLive.instance.reportEvent('join', {'player': 'P1'});
    DemoLive.instance.reportScreen('games');
    expect(DemoLive.instance.currentScreen, 'games');
    DemoLive.instance.currentScreen = 'home';
  });
}
