/// What a counters bar and the board over it need to know beside the snapshot
/// and roster (M16 close c1): whose phone it is, the round's number and how
/// many the match runs, and whether the bar is drawn. A value object so the
/// bar and the board take one argument for these, not four.
class ArenaBoardOptions {
  const ArenaBoardOptions({this.ownId, this.round, this.rounds, this.showHud = true});

  /// The player of the phone this board is drawn on, marked "(you)" in the bar;
  /// null on a TV or the host's own screen, where every player is alike (M14
  /// bugs2 7).
  final String? ownId;

  /// The round's number from 1 and how many the match runs (M16 A2): the bar
  /// reads "Round N of M" when both are set, and "Round N" when either is not.
  final int? round;

  /// How many rounds the match runs (M16 A2), next to [round]; null when the
  /// host names no rounds.
  final int? rounds;

  /// Whether the round strip is drawn. When it is not, its space stays (M16
  /// bugs3 B-036), so the field keeps the size it has.
  final bool showHud;
}
