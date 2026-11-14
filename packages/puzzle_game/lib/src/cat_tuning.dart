import 'dart:math';

import 'cat_view.dart';
import 'settings.dart';

/// How often the cat comes, by the Cat setting (PRD v2 G3, M14 bug b006): one
/// table of intervals per [CatPreset], from which a round counts its visits and
/// its knocks off its own length, so a longer round sees the cat more often.
///
/// The time the cat may use is the round's window: its time limit less the
/// first [CatRules.graceS] and the last [CatRules.tailS]. The visits are the
/// window's whole [visitEveryLittleS] intervals on A little and
/// [visitEveryPartyS] on Party, one at least where the window has room for one,
/// and never so many that two visits overlap: each visit and the quiet after it
/// need [CatRules.visitS] plus [minQuietS]. On Party the knocks are the window's
/// [knockEveryS] intervals, one at least, and never more than there are visits.
///
/// The intervals are start values (b006), tuned on a device. The one table is
/// [table]: every reader asks [of].
final class CatTuning {
  const CatTuning._({required this.visitEveryLittleS, required this.visitEveryPartyS, required this.knockEveryS});

  /// Seconds between visits on A little, where the cat only bats a loose or
  /// tray piece; the same on every preset.
  final double visitEveryLittleS;

  /// Seconds between visits on Party, where a visit may knock a placed piece.
  final double visitEveryPartyS;

  /// Seconds between the Party visits that may knock a placed piece loose.
  final double knockEveryS;

  /// The least quiet between one visit leaving and the next one's warning, in
  /// seconds: what keeps two visits from overlapping on a short round.
  static const minQuietS = 5.0;

  /// Calm: the cat is a rare guest, about one visit a round at 2 minutes.
  static const calm = CatTuning._(visitEveryLittleS: 85, visitEveryPartyS: 43, knockEveryS: 90);

  /// Lively, the default (b006): a 2 minute Party round visits 3 times and may
  /// knock twice; the owner's 8 minute round 16 times and 10.
  static const lively = CatTuning._(visitEveryLittleS: 85, visitEveryPartyS: 28, knockEveryS: 43);

  /// Wild: a visit every 21 s on Party, a knock every 28 s of the window.
  static const wild = CatTuning._(visitEveryLittleS: 85, visitEveryPartyS: 21, knockEveryS: 28);

  /// The one table of intervals, by the Cat setting a host saved.
  static const table = {CatPreset.calm: calm, CatPreset.lively: lively, CatPreset.wild: wild};

  /// [preset]'s intervals; a preset the table lacks counts as [lively], as an
  /// unknown Chaos name counts as the default chaos (job a2).
  static CatTuning of(CatPreset preset) => table[preset] ?? lively;

  /// The seconds of a [timeLimitS] round the cat may use: the round less its
  /// first [CatRules.graceS] and its last [CatRules.tailS].
  static double windowS(int timeLimitS) => timeLimitS - CatRules.graceS - CatRules.tailS;

  /// The visits a round of [timeLimitS] plans for [chaos]: [windowS]'s whole
  /// [visitEveryLittleS] or [visitEveryPartyS] intervals, and none when the
  /// window has no room for one.
  int visits(Chaos chaos, int timeLimitS) {
    if (chaos == Chaos.off) return 0;
    final every = chaos == Chaos.party ? visitEveryPartyS : visitEveryLittleS;
    return _fit((windowS(timeLimitS) / every).floor(), timeLimitS);
  }

  /// The knocks a round of [timeLimitS] allows for [chaos]: [windowS]'s whole
  /// [knockEveryS] intervals, one at least, on Party only, and never more than
  /// the visits there are to knock on.
  int knocks(Chaos chaos, int timeLimitS) {
    if (chaos != Chaos.party) return 0;
    return min(_fit((windowS(timeLimitS) / knockEveryS).floor(), timeLimitS), visits(chaos, timeLimitS));
  }

  /// [wanted] visits, one at least where the window has room for one, and never
  /// more than the window fits at [CatRules.visitS] plus [minQuietS] each.
  int _fit(int wanted, int timeLimitS) {
    final cap = (windowS(timeLimitS) / (CatRules.visitS + minQuietS)).floor();
    return cap < 1 ? 0 : min(max(1, wanted), cap);
  }
}
