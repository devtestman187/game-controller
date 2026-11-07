import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' as party;

/// The game picker and the games, in the box behind the controls (m12 §2.7):
/// the bar and the controls stay on top of everything that happens in here,
/// because they are above this navigator and not inside it.
class HostGames extends StatelessWidget {
  const HostGames({super.key, required this.navigatorKey});

  /// The host's navigator, so "back to the game picker" finds this one.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      // The name is what Quit and an abandoned round pop back to.
      settings: const RouteSettings(name: party.gamesRouteName),
      builder: (_) => const party.GamesScreen(),
    ),
  );
}
