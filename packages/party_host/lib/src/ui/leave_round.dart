import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abandon_signal.dart';
import 'games_screen.dart';

/// Goes back to the game picker (or the main screen, if the game was opened
/// from somewhere else).
void leaveForGamePicker(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.settings.name == gamesRouteName || r.isFirst);

/// Ends the round the host can't show any more (m12 §2.10): the session
/// records it and ends its view `abandoned`, then this goes back to the game
/// picker. Quit in the pause menu goes back the same way, but a quit round
/// ends its view `quit`: the players chose to stop.
void abandonRound(BuildContext context) {
  ProviderScope.containerOf(context, listen: false).read(hostAbandonProvider).fire();
  leaveForGamePicker(context);
}
