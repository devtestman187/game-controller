import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:party_host/party_host.dart' as party;

/// The game picker and the games, in the box behind the controls (m12 §2.7):
/// the bar and the controls stay on top of everything that happens in here,
/// because they are above this navigator and not inside it.
class HostGames extends ConsumerStatefulWidget {
  const HostGames({super.key, required this.navigatorKey});

  /// The host's navigator, so "back to the game picker" finds this one.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<HostGames> createState() => _HostGamesState();
}

class _HostGamesState extends ConsumerState<HostGames> {
  /// This navigator's own observer, so a page pushed or popped in the host
  /// works the look's palette out again, as the app's navigator does (M13
  /// design D1). A navigator takes an observer only once, so this is a second
  /// one rather than the app's.
  late final _observer = party.ToyLookRouteObserver(() => ref.read(party.lookPaletteProvider.notifier).refresh());

  @override
  Widget build(BuildContext context) => Navigator(
    key: widget.navigatorKey,
    observers: [_observer],
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      // The name is what Quit and an abandoned round pop back to.
      settings: const RouteSettings(name: party.gamesRouteName),
      builder: (_) => const party.GamesScreen(),
    ),
  );
}
