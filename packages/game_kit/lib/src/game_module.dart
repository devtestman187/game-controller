import 'package:flutter/widgets.dart';

/// A game a viewer can draw (m12 §4): its ID, its snapshot version, and how
/// to build a viewer for one game. Each game package exports its own module,
/// so the apps build the registry without a cycle between the games.
abstract interface class GameModule {
  /// The module ID a view_start carries, e.g. `arena`.
  String get id;

  /// The version of the snapshots the viewer decodes. A frame of another
  /// version is shown as "Update the app" instead.
  int get snapshotVersion;

  /// A viewer for one game, from view_start's setup. Throws [FormatException]
  /// when the setup doesn't fit the game.
  GameViewer createViewer(Map<String, Object?> setup);
}

/// Draws one game from the frames of its [GameModule] (m12 §4).
abstract interface class GameViewer {
  /// One frame's snapshot JSON as a [GameSnapshot]. Throws [FormatException]
  /// naming the field that doesn't fit.
  GameSnapshot decode(Map<String, Object?> json);

  /// The game inside [snapshot], drawn for [view]'s roster and player.
  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view);
}

/// A game's drawable state (m12 §4). It holds no rules: a viewer draws it, and
/// [lerpTo] moves it towards the next frame.
abstract interface class GameSnapshot {
  /// The frame's JSON, as the module sends it.
  Map<String, Object?> toJson();

  /// The round's clock in ms left (M16 slice A1), which the session puts on
  /// each frame so a phone shows it. Null when the game has no clock; a
  /// snapshot without a clock keeps this null.
  int? get timeLeftMs => null;

  /// The coins [playerId] holds right now (M16 slice B), for a phone to show
  /// as its own. Null when the game counts no coins (the race, the puzzle), or
  /// when the player isn't in this frame.
  int? coinsOf(String playerId) => null;

  /// [playerId]'s place in the round's live order (M16 slice B), 1 first, for
  /// a game that ranks its players (the Bumper Round by coins). Null when the
  /// game has no such order, or when the player isn't in this frame.
  int? placeOf(String playerId) => null;

  /// The state at [t] between this snapshot (0) and [next] (1): positions
  /// lerp, angles take the shortest arc, and everything else (phase, IDs,
  /// counts, who holds what) is this snapshot's. Players or pieces only in
  /// [next] aren't drawn yet. Rule-free, so a viewer can draw any frame rate.
  GameSnapshot lerpTo(GameSnapshot next, double t);
}

/// What a viewer draws for (m12 §4): the roster (number and name per player
/// ID), this phone's player, if it plays, whether a phone that shows a game
/// laid out for phones draws the whole match instead of its own side (a
/// tablet, which has the room for both: m12-phone-layout §0.6), where the app
/// draws this phone's pad, in the box's px ([padRects]), and how many of those
/// px make a millimetre ([pxPerMm]).
///
/// [padRects] and [pxPerMm] are the app's own readings, which the game can't
/// take for itself: the app passes the controls it draws so the game can keep
/// what it adds (the other side's mirror: m12-opponent-mirror rules 3 and 8)
/// clear of them, and the screen's density so a mark the game draws at a
/// physical size keeps it (rule 7). No pad is drawn where [padRects] is empty.
typedef ViewContext = ({
  Map<String, ({int number, String name})> roster,
  String? playerId,
  bool wholeMatch,
  List<Rect> padRects,
  double pxPerMm,
});
