/// The two rounds the Arena plays (party-night §7, M14 G9): the race to the
/// goal, which the game has played since M12, and the Bumper Round, where four
/// marbles shove each other for coins.
///
/// The mode is chosen before a round and never changes inside it. The race is
/// the default, so a game built with no mode — and every test written before
/// the Bumper Round — plays exactly as it did.
enum ArenaMode { race, bumper }
