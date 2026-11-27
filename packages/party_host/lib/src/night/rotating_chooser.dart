/// The Rotating chooser picker (M17 plan 1.2): a different player picks each round, in the order of `playerIds`.
final class RotatingChooser {
  const RotatingChooser();

  /// The player who chooses after [lastChooser]. Wraps round to the first player when [lastChooser] is null or no
  /// longer in [playerIds] (a player who left is skipped that way), and is null when [playerIds] is empty.
  String? next({required List<String> playerIds, String? lastChooser}) {
    if (playerIds.isEmpty) {
      return null;
    }
    final index = lastChooser == null ? -1 : playerIds.indexOf(lastChooser);
    if (index < 0) {
      return playerIds.first;
    }
    return playerIds[(index + 1) % playerIds.length];
  }
}
