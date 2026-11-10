import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abandon_signal.dart';
import 'games_screen.dart';

/// Whether [route] is the game picker, or the first route the app has: the
/// night's screens clear back to it (M14 c1), so a night never piles a phone's
/// back stack with a round's routes.
bool isGamePickerRoute(Route<Object?> route) => route.settings.name == gamesRouteName || route.isFirst;

/// Goes back to the game picker (or the main screen, if the game was opened
/// from somewhere else).
void leaveForGamePicker(BuildContext context) => Navigator.of(context).popUntil(isGamePickerRoute);

/// Ends the round the host can't show any more (m12 §2.10): the session
/// records it and ends its view `abandoned`, then this goes back to the game
/// picker. Quit in the pause menu goes back the same way, but a quit round
/// ends its view `quit`: the players chose to stop.
void abandonRound(BuildContext context) {
  ProviderScope.containerOf(context, listen: false).read(hostAbandonProvider).fire();
  leaveForGamePicker(context);
}
