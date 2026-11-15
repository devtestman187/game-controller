/// Whether Shape Race's screens before a round are skipped (M14 bugs B-002): a
/// night with exactly one player has nobody to wait for and no sides to pick,
/// so the puzzle pick opens the solo board instead of the join screen.
///
/// [inNight] is whether a party night is running; [players] counts the players
/// who can play this round: the phones that aren't away, and the host's own
/// player only when the host plays on this device, as the join screen counts
/// them (its own player).
///
/// The Arena is never skipped, with one player or more, in a night or outside
/// it (M14 bugs B-020): its waiting card is where the host picks the map, so
/// this rule is Shape Race's alone.
bool skipsLobby({required bool inNight, required int players}) => inNight && players == 1;
