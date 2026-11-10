import 'dart:math';
import 'dart:ui' show Offset, Rect;

/// One star of the finish celebration's burst, as the view draws it: where it
/// is in the field's units, its radius, how strongly it shows (0 to 1) and
/// whether it is one of the pale ones (design 3a's mock-up has four in
/// fourteen).
typedef StarBurst = ({Offset at, double radius, double alpha, bool bright});

/// One bit of the finish celebration's confetti: where its middle is in the
/// field's units, its size, how far it is turned, which of the players'
/// colours it takes (1 to 6) and how strongly it shows.
typedef Confetto = ({Offset at, double wide, double tall, double angleDeg, int colour, double alpha});

/// The finish celebration (design section 3a, PRD v2 T15): when a picture is
/// completed its pieces pop in the order they were placed, a ring of stars
/// bursts out round the board, confetti falls round it and the picture glows
/// once, before the results card shows the picture as a photo.
///
/// The values here are the moment's whole timeline and its pieces, worked out
/// from the board's finish age, which [PieceMoments] keeps; the painter draws
/// them and the rules count nothing (S8). Nothing flashes (G5): the glow rises
/// and falls once over the 2.5 s, and with the effects off nothing moves — the
/// pop is gone, the stars and the rim stand still, and no confetti falls
/// (design 3a's comfort rules).
abstract final class Celebration {
  /// How long the whole moment lasts, in milliseconds (design 3a: about 2.5
  /// s).
  static const totalMs = 2500;

  /// How long one piece's pop lasts, in milliseconds, and how big it grows, as
  /// a share of its size: to 110% and back (design 3a).
  static const popMs = 240;
  static const popPeak = 1.10;

  /// How long after the piece before it the next one pops, in milliseconds
  /// (design 3a: 120 ms apart).
  static const popGapMs = 120;

  /// The star ring: how many stars, how far outside the board's edge they
  /// start and how far each drifts out, in field units; how long a star lives,
  /// and how long its fade in and its fade out take, in milliseconds; and its
  /// radius, which grows a step for every third star.
  static const stars = 14;
  static const starGap = 2.5;
  static const starDrift = 8.0;
  static const starMs = 1200;
  static const starFadeInMs = 150;
  static const starFadeOutMs = 300;
  static const starSize = 0.55;
  static const starSizeStep = 0.3;

  /// The confetti: how many bits, how fast they fall (field units a second),
  /// how far they sway either way, their size, and how long their fade out at
  /// the end takes, in milliseconds. They fall in a frame round the board,
  /// [confettiSpread] field units wide, and never over the picture (design 3a).
  static const confettiBits = 22;
  static const confettiFall = 34.0;
  static const confettiSway = 1.5;
  static const confettiWide = 1.2;
  static const confettiTall = 0.65;
  static const confettiSpread = 16.0;
  static const confettiFadeMs = 500;

  /// The confetti's scatter, worked out from the bit's number alone so it falls
  /// the same way on every screen without a random: the share of the frame each
  /// next bit moves across, and the share each next bit starts lower.
  static const _scatterAcross = 0.6180339887;
  static const _scatterStart = 0.3819660113;

  /// How far a bit is turned at the start, one step for every bit, and how far
  /// it turns a second once falling (degrees).
  static const _turnStepDeg = 37;
  static const _turnDegPerS = 90;

  /// How many bits there are to a full turn of the step above, and how many of
  /// the players' colours the confetti takes.
  static const _turnsInCircle = 90;
  static const _playerColours = 6;

  /// The warm rim round the picture: how strong it is at its brightest (a
  /// share of full), how much of that a still rim keeps with the effects off,
  /// how far past a piece's own edge it reaches (a share of the piece's size)
  /// and how soft it is, in field units.
  static const glowPeak = 0.85;
  static const glowStillShare = 0.55;
  static const glowReach = 0.06;
  static const glowBlur = 1.8;

  /// How dark a race's losing board goes while the other side celebrates, and
  /// how long it takes to get there, in milliseconds (design 3a: "its board
  /// dims gently").
  static const dimPeak = 0.28;
  static const dimMs = 600;

  /// Whether a board that finished [ageMs] ago is still celebrating.
  static bool isRunning(int ageMs) => ageMs >= 0 && ageMs < totalMs;

  /// When the piece placed [place]th pops, in milliseconds after the finish:
  /// [popGapMs] after the one before it, and never so late that its pop would
  /// run past [totalMs].
  static int popStartMs(int place) => min(place * popGapMs, totalMs - popMs);

  /// The scale the piece placed [place]th is drawn at [ageMs] after the
  /// finish: 1 outside its own pop, up to [popPeak] half way through it, and 1
  /// with the effects off (design 3a, G5).
  static double popScale(int place, int ageMs, {bool effects = true}) {
    if (!effects) return 1;
    final local = ageMs - popStartMs(place);
    if (local < 0 || local >= popMs) return 1;
    return 1 + (popPeak - 1) * sin(pi * local / popMs);
  }

  /// How strongly the picture's warm rim shows [ageMs] after the finish: one
  /// breath up and down over [totalMs], or a still rim with the effects off.
  /// Zero once the moment is over.
  static double glowAlpha(int ageMs, {bool effects = true}) {
    if (!isRunning(ageMs)) return 0;
    return effects ? glowPeak * sin(pi * ageMs / totalMs) : glowPeak * glowStillShare;
  }

  /// How dark a race's losing board goes [ageMs] after the other side finished:
  /// up to [dimAlpha] over the first [dimMs], and none once the moment is over
  /// (the results card dims the board then).
  static double dimAlpha(int ageMs) => isRunning(ageMs) ? dimPeak * min(1.0, ageMs / dimMs) : 0;

  /// The stars of the burst [ageMs] after the finish, in [board]'s field units:
  /// a ring of [stars] round the board's edge, outside it, drifting
  /// [starDrift] units outward over [starMs] while they fade in and out. With
  /// the effects off they stand still, where they appeared, until the moment
  /// ends (design 3a: they appear and go, with no motion).
  static List<StarBurst> starsOf(int ageMs, Rect board, {bool effects = true}) {
    final lifeMs = effects ? starMs : totalMs;
    if (!isRunning(ageMs) || ageMs >= lifeMs) return const [];
    final progress = ageMs / starMs;
    final out = effects ? starDrift * (1 - pow(1 - progress, 2)) : starDrift / 2;
    final alpha = effects ? _starAlpha(ageMs) : 1.0;
    return [for (var i = 0; i < stars; i++) _star(i, board, out.toDouble(), alpha)];
  }

  /// One star of the ring [out] units outside [board]'s edge, given by its
  /// place round the ring so the ring stays the same on every screen.
  static StarBurst _star(int i, Rect board, double out, double alpha) {
    final turn = i * 2 * pi / stars - pi / 2;
    final ca = cos(turn);
    final sa = sin(turn);
    // How far the board's edge is this way, so every star starts outside it.
    final edge = 1 / max(ca.abs() / (board.width / 2), sa.abs() / (board.height / 2));
    return (
      at: board.center + Offset(ca, sa) * (edge + starGap + out),
      radius: starSize + (i % 3) * starSizeStep,
      alpha: alpha,
      bright: i % 4 == 0,
    );
  }

  /// How strongly a star shows [ageMs] after the finish: a quick fade in, then
  /// whole, then a fade out at the end of its life.
  static double _starAlpha(int ageMs) {
    if (ageMs < starFadeInMs) return ageMs / starFadeInMs;
    final left = starMs - ageMs;
    return left < starFadeOutMs ? left / starFadeOutMs : 1;
  }

  /// The confetti [ageMs] after the finish, in [board]'s field units: bits
  /// falling in a frame [confettiSpread] units round the board, each at its own
  /// place and speed, drifting as it falls, and turning slowly. None of them
  /// is drawn over the picture, and there is none with the effects off (design
  /// 3a, G5: no motion).
  static List<Confetto> confettiOf(int ageMs, Rect board, {bool effects = true}) {
    if (!effects || !isRunning(ageMs)) return const [];
    final frame = board.inflate(confettiSpread);
    final alpha = ((totalMs - ageMs) / confettiFadeMs).clamp(0.0, 1.0);
    final seconds = ageMs / Duration.millisecondsPerSecond;
    final walked = confettiFall * seconds;
    final bits = <Confetto>[];
    for (var i = 0; i < confettiBits; i++) {
      final across = _spread(i * _scatterAcross);
      final start = frame.top - confettiTall - _spread(i * _scatterStart) * frame.height;
      final sway = confettiSway * sin(seconds * 2 * pi + i);
      final at = Offset(
        (frame.left + confettiWide + across * (frame.width - 2 * confettiWide) + sway).clamp(
          frame.left + confettiWide,
          frame.right - confettiWide,
        ),
        start + walked,
      );
      if (at.dy > frame.bottom - confettiTall || at.dy < frame.top + confettiTall) continue;
      final rect = Rect.fromCenter(center: at, width: confettiWide, height: confettiTall);
      if (rect.overlaps(board)) continue;
      bits.add((
        at: at,
        wide: confettiWide,
        tall: confettiTall,
        angleDeg: i * _turnStepDeg % _turnsInCircle + seconds * _turnDegPerS,
        colour: 1 + i % _playerColours,
        alpha: alpha,
      ));
    }
    return bits;
  }

  /// [value]'s fraction of the way past the whole number below it, 0 to 1: the
  /// confetti's own scatter, so it falls the same way on every screen without
  /// a random.
  static double _spread(double value) => value - value.floorToDouble();
}
