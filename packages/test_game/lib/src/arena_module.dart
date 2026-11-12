import 'package:flutter/widgets.dart';
import 'package:game_kit/game_kit.dart';

import 'arena_roster.dart';
import 'arena_snapshot.dart';
import 'arena_view_widgets.dart';

/// The Arena's view setup: nothing (m12 §4). The field's size comes from the
/// box the view is given, and its players from each frame's roster.
const arenaSetup = <String, Object?>{};

/// The Arena as a viewer draws it (m12 §4): frames of [ArenaSnapshot], drawn
/// from the roster each frame carries.
final class ArenaModule implements GameModule {
  const ArenaModule();

  @override
  String get id => 'arena';

  @override
  int get snapshotVersion => ArenaSnapshot.version;

  @override
  GameViewer createViewer(Map<String, Object?> setup) => const ArenaViewer();
}

/// The one Arena module the apps put in their registry (m12 §0).
const arenaModule = ArenaModule();

/// Draws the arena on a phone showing the game: the same bar and field the TV
/// draws, from the frame's roster.
final class ArenaViewer implements GameViewer {
  const ArenaViewer();

  @override
  GameSnapshot decode(Map<String, Object?> json) => ArenaSnapshot.fromJson(json);

  @override
  Widget build(BuildContext context, GameSnapshot snapshot, ViewContext view) {
    if (snapshot is! ArenaSnapshot) {
      throw ArgumentError.value(snapshot, 'snapshot', 'The arena viewer draws ArenaSnapshot frames');
    }
    // The look comes from the screen's ToyLookScope, which every app puts
    // above its screens; a screen without one throws, as the puzzle's do.
    // The phone's own player is marked in the bar, so a joined player can tell
    // their counters from everyone else's (M14 bugs2 7).
    return ArenaBoard(snapshot: snapshot, roster: arenaRosterFor(snapshot, view.roster), ownId: view.playerId);
  }
}
