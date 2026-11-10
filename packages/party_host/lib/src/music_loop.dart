import 'package:game_assets/asset_manifest.dart';

/// Which music the host plays (M13 design section 8): the lobby's loop, or the
/// round's own at one of its three tempos. No music is a null [MusicLoop], so
/// the controller's "none" needs no name of its own.
///
/// The three round loops are the same piece at 120, 138 and 156 BPM, in the
/// same key, so speeding up never raises the pitch. The Arena's three (M14
/// design section 7) are its own piece, at its own three tempos, and follow
/// the Bumper Round's clock at 15 s and 5 s.
enum MusicLoop {
  /// The lobby's loop (design section 8, step 7): the game picker and the join
  /// screen, and nothing else.
  lobby(SoundKey.lobby),

  /// The round's first tempo: more than `warningS` left, a round with no clock
  /// (the race), or a warning of 0.
  round(SoundKey.round),

  /// The round's second tempo: `warningS` or less left on the clock.
  roundHurry(SoundKey.roundHurry),

  /// The round's last tempo: `warningS / 3` or less left on the clock.
  roundFinal(SoundKey.roundFinal),

  /// The Arena's music (M14 design section 7): the race's round, and the
  /// Bumper Round's while more than [arenaHurryS] is left.
  arena(SoundKey.arena),

  /// The Bumper Round's second tempo: [arenaHurryS] or less left.
  arenaHurry(SoundKey.arenaHurry),

  /// The Bumper Round's last tempo: [arenaFinalS] or less left.
  arenaFinal(SoundKey.arenaFinal);

  const MusicLoop(this.key);

  /// The sound the loop plays.
  final SoundKey key;

  /// The name the player plays it by, e.g. `round_hurry`.
  String get eventName => key.eventName;

  /// The stretch before the end that runs at [roundFinal], as a share of
  /// `warningS`: a third of the warning (design section 8, rule 3).
  static const finalShare = 3;

  /// When the Bumper Round's music hurries and runs to its end (M14 design
  /// section 7): 15 s and 5 s left on its 60 s clock.
  static const arenaHurryS = 15;
  static const arenaFinalS = 5;

  /// The round's loop for [timeLeftMs] left on the clock and a [warningS]
  /// warning (the puzzle's setting, 15 s by default):
  ///
  /// - more than `warningS` left, no clock (the Arena's round), or a [warningS]
  ///   of 0: [round];
  /// - `warningS` or less: [roundHurry];
  /// - `warningS / finalShare` or less: [roundFinal].
  static MusicLoop forRound({required int? timeLeftMs, required int warningS}) {
    final left = timeLeftMs;
    if (left == null || warningS <= 0) return round;
    final warningMs = warningS * Duration.millisecondsPerSecond;
    if (left > warningMs) return round;
    if (left > warningMs / finalShare) return roundHurry;
    return roundFinal;
  }

  /// The Arena's loop for [timeLeftMs] left on the Bumper Round's clock (M14
  /// design section 7), or no clock ([timeLeftMs] null, the race's):
  ///
  /// - no clock, or more than [arenaHurryS] left: [arena];
  /// - [arenaHurryS] or less: [arenaHurry];
  /// - [arenaFinalS] or less: [arenaFinal].
  static MusicLoop forArena({required int? timeLeftMs}) {
    final left = timeLeftMs;
    if (left == null) return arena;
    if (left > arenaHurryS * Duration.millisecondsPerSecond) return arena;
    if (left > arenaFinalS * Duration.millisecondsPerSecond) return arenaHurry;
    return arenaFinal;
  }
}
