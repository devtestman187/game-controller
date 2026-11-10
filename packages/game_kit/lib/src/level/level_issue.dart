/// One thing wrong with a level file (M14 k1a), as `tools/level.sh check`
/// prints it: a message a developer can act on, with the level named and, when
/// the issue is about one part of it, that part too.
///
/// Both games' rule books return these — Shape Race's `PuzzleRule` issues and,
/// from M14 k1b, the Arena's map issues — so the tool prints every kind the
/// same way. [rule] stays the game's own enum, which its tests group by.
final class LevelIssue {
  const LevelIssue({required this.level, required this.rule, required this.message, this.part});

  /// The level's id, as the message's prefix names it.
  final String level;

  /// The part of the level the issue is about, when there is one: a puzzle's
  /// piece.
  final String? part;

  /// The game's rule this breaks, from its own rule enum (`PuzzleRule.listing`).
  final Enum rule;

  /// The line the check prints: "rocket/body: …".
  final String message;

  @override
  String toString() => message;
}
