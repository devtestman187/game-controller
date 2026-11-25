import 'package:flutter/widgets.dart';

/// The three buttons on Home, in their fixed on-screen order.
enum HomeRole { join, play, display }

/// What the discovery pass has found so far.
enum HomeFind { searching, found, none }

/// The button to highlight for [find]: a found screen leads with Join a Game,
/// no screen leads with Play here, and nothing is highlighted while searching.
HomeRole? highlightedRole(HomeFind find) => switch (find) {
  HomeFind.found => HomeRole.join,
  HomeFind.none => HomeRole.play,
  HomeFind.searching => null,
};

/// One key per Home button, so the coach marks can find each button's place on
/// screen. Contract (item 8, JOBS.md): the root stays the controller screen; an
/// unpaired launch pushes Home; Back on a launch Home exits the app; Home opened
/// from the pad's menu returns to the pad. Join a Game opens the Connect screen
/// (list and code); Play here hosts on this phone and Display here hosts on this
/// device, with no sheet. Marks run only while Home is idle (consent answered,
/// nothing connecting, no dialog). Consent has one ask function with two entry
/// points, Home and the pad. A failed connect on the pad returns to Home.
class HomeAnchors {
  HomeAnchors() : join = GlobalKey(), play = GlobalKey(), display = GlobalKey();

  final GlobalKey join;
  final GlobalKey play;
  final GlobalKey display;
}
