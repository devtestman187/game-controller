import 'package:flutter/material.dart';
import 'package:party_host/party_host.dart' show ToyLook;

/// The look's ink for the list tiles on a paper surface that has no card
/// (B-017): the app's theme colours a tile for the text straight on the sky
/// (`onBackground`), which is white in Night, so the 'Floating sticks' switch
/// in the Sticks dialog came out white on cream paper. A card puts what it
/// holds back to ink (ToyCard's own theme); a dialog has no card, so its
/// content takes this.
ListTileThemeData paperTileTheme(ToyLook look) =>
    ListTileThemeData(textColor: look.colors.ink, iconColor: look.colors.ink);
