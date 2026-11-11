import 'dart:math';

/// Which game can earn an award (design section 6's table).
enum NightAwardGame {
  /// Shape Race's rounds only: its counters are the only ones that fill it.
  puzzle,

  /// A Bumper Round only.
  bumper,

  /// Either game: every round fills its counter, so a night of one game still
  /// has something to give (design section 6's draw rule).
  both,
}

/// The picture an award is shown with (design section 6): the start card draws
/// it small beside the award's name and job c2's reveal draws it large, so both
/// name the same picture by this key.
enum NightAwardPicture { sharpshooter, helper, cat, snap, comeback, coin, trophy, retry, shove, bump, gold, steady }

/// One of the twelve awards a night may play for (design section 6): its name,
/// the one line that says who wins it, the picture it is drawn with, the game
/// that can earn it, and whether a player on the losing side can still win it.
///
/// Job c2 qualifies the players and reveals the awards; this job only draws
/// three of them for the night and names them on the start card.
enum NightAward {
  sharpshooter(
    title: 'Sharpshooter',
    line: 'Fewest wrong drops',
    picture: NightAwardPicture.sharpshooter,
    game: NightAwardGame.puzzle,
    losable: false,
  ),
  bestHelper(
    title: 'Best Helper',
    line: 'Most carries home together',
    picture: NightAwardPicture.helper,
    game: NightAwardGame.puzzle,
    losable: true,
  ),
  catCatcher(
    title: 'Cat Catcher',
    line: 'Most cats shooed',
    picture: NightAwardPicture.cat,
    game: NightAwardGame.puzzle,
    losable: true,
  ),
  speedySnapper(
    title: 'Speedy Snapper',
    line: 'Most snaps',
    picture: NightAwardPicture.snap,
    game: NightAwardGame.puzzle,
    losable: false,
  ),
  comeback(
    title: 'Comeback',
    line: 'Most points in the last round',
    picture: NightAwardPicture.comeback,
    game: NightAwardGame.both,
    losable: true,
  ),
  coinCollector(
    title: 'Coin Collector',
    line: 'Most coins picked up',
    picture: NightAwardPicture.coin,
    game: NightAwardGame.bumper,
    losable: false,
  ),
  roundWinner(
    title: 'Round Winner',
    line: 'Most rounds won',
    picture: NightAwardPicture.trophy,
    game: NightAwardGame.both,
    losable: false,
  ),
  tryAgain(
    title: 'Try Again',
    line: 'Most snaps after a wrong drop',
    picture: NightAwardPicture.retry,
    game: NightAwardGame.puzzle,
    losable: true,
  ),
  bigBopper(
    title: 'Big Bopper',
    line: 'Most shoves',
    picture: NightAwardPicture.shove,
    game: NightAwardGame.bumper,
    losable: false,
  ),
  bounceHouse(
    title: 'Bounce House',
    line: 'Bumped the most',
    picture: NightAwardPicture.bump,
    game: NightAwardGame.bumper,
    losable: true,
  ),
  goldRush(
    title: 'Gold Rush',
    line: 'Most gold coins picked up',
    picture: NightAwardPicture.gold,
    game: NightAwardGame.bumper,
    losable: false,
  ),
  steadyRoller(
    title: 'Steady Roller',
    line: 'Fewest coins dropped',
    picture: NightAwardPicture.steady,
    game: NightAwardGame.bumper,
    losable: false,
  );

  const NightAward({
    required this.title,
    required this.line,
    required this.picture,
    required this.game,
    required this.losable,
  });

  /// The award's name, in the game cards' header.
  final String title;

  /// One line saying who wins it, under the name.
  final String line;

  /// The picture the award is drawn with, small here and large in c2's reveal.
  final NightAwardPicture picture;

  /// The game that can earn it.
  final NightAwardGame game;

  /// Whether a player on the losing side of a round can still win it (design
  /// section 6's table): every night keeps one of these, so the reveal never
  /// gives the night's losers nothing.
  final bool losable;

  /// Whether either game can earn it, so a night of one game still has an
  /// award to give.
  bool get eitherGameCanEarnIt => game == NightAwardGame.both;
}

/// How many awards a night plays for (design section 4: "the three awards").
const nightAwardsPerNight = 3;

/// The night's awards, drawn from [random] (design section 6): always
/// [nightAwardsPerNight] of them, one a losing player can still win and one
/// either game can earn, so the start card can name them and the reveal has
/// something to give.
///
/// Only an award one of [games] — the games the night can play — can earn is
/// drawn, and an either-game award always can, so a reveal never names an
/// award its night could not have won (M14 f1, r5 finding 3).
///
/// The three are listed in the catalogue's order, not the order they were
/// drawn, so a screen always shows them the same way round and a seed fixes
/// the set: the same [random] state gives the same three.
List<NightAward> drawAwards(Random random, {required Set<NightAwardGame> games}) {
  bool earnable(NightAward award) => award.game == NightAwardGame.both || games.contains(award.game);
  final pool = [
    for (final award in NightAward.values)
      if (earnable(award)) award,
  ];
  final losable = [
    for (final award in pool)
      if (award.losable) award,
  ];
  final either = [
    for (final award in pool)
      if (award.eitherGameCanEarnIt) award,
  ];
  final drawn = {losable[random.nextInt(losable.length)], either[random.nextInt(either.length)]};
  while (drawn.length < nightAwardsPerNight) {
    drawn.add(pool[random.nextInt(pool.length)]);
  }
  return [
    for (final award in NightAward.values)
      if (drawn.contains(award)) award,
  ];
}
