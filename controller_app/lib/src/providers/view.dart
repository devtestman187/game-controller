import 'package:connection/connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/game_kit.dart';
import 'package:puzzle_game/puzzle_game.dart';
import 'package:test_game/test_game.dart';

import '../providers.dart';

/// Every game this app version can draw (m12 §4): the registry the joined
/// view looks a `view_start`'s module up in. A game this app doesn't know is
/// shown as "Update the app" instead.
final gameRegistryProvider = Provider<GameRegistry>((ref) => GameRegistry([shapeRaceModule, arenaModule]));

/// Whether the host is showing this phone a game (m12 §5): true from a
/// [ViewStarted] until a [ViewEnded].
///
/// It goes back to false whenever the client changes, because the notifier is
/// rebuilt for the new client and starts over: a phone that stops joining a
/// host (its own player takes the screens, m12 §3) shows no game, whatever
/// the last connection was showing.
final viewActiveProvider = NotifierProvider<ViewActiveNotifier, bool>(ViewActiveNotifier.new);

class ViewActiveNotifier extends Notifier<bool> {
  @override
  bool build() {
    final client = ref.watch(clientProvider);
    final sub = client.view.listen((event) {
      switch (event) {
        case ViewStarted():
          state = true;
        case ViewEnded():
          state = false;
        case ViewFrame() || HostAway() || HostBack():
          // A frame is only drawn while a view is on, and the away messages
          // don't change whether there is one (m12 §0.3).
          break;
      }
    });
    ref.onDispose(sub.cancel);
    return false;
  }
}
