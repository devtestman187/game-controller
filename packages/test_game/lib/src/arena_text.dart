/// The Arena's own words a player sees in its bars (M14 bugs2 7). They live in
/// the game rather than in the host's text: a game may not import `party_host`,
/// and the bar is drawn by the game on the TV and on a joined phone alike.
abstract final class ArenaBarText {
  /// How the bar marks the phone's own player row: "P2 Bo (you)", so a player
  /// can tell their own counters from everyone else's at a glance (M14 bugs2 7).
  static String own(String name) => '$name (you)';
}
