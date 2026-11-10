/// How much the cat comes (PRD v2 G3, M14 a2): not at all, once a round and
/// only to bat a loose or tray piece, or twice and once a round a placed piece
/// of the side ahead goes back to its tray.
enum Chaos { off, little, party }

/// The puzzle's tuning values (PRD v2 "Playtest settings"), changed on the
/// host's playtest settings screen and saved there. The game reads them
/// every frame, so a change counts straight away.
final class PuzzleSettings {
  const PuzzleSettings({
    this.angleToleranceDeg = 15,
    this.positionTolerance = 0.25,
    this.rotationSpeedDegPerS = 180,
    this.stickDeadZone = 0.15,
    this.pickupRange = 1.0,
    this.soloBigSpeed = 0.35,
    this.helpIntervalS = 3,
    this.hintDelayS = 10,
    this.dropReadyHighlight = true,
    this.timeLimitS = 120,
    this.warningS = 15,
    this.pointsScale = 1,
    this.night = false,
    this.chaos = Chaos.off,
  });

  /// ± degrees.
  final double angleToleranceDeg;

  /// Of the piece's size.
  final double positionTolerance;
  final double rotationSpeedDegPerS;

  /// The right stick turns the piece once pushed sideways past this; the
  /// further, the faster.
  final double stickDeadZone;

  /// How far beyond a piece's outline the dot still picks it up, in times the
  /// pickup reach ([PuzzleGame.pickupReach], the worker's body radius).
  final double pickupRange;

  /// A big piece carried alone moves at this much of normal speed (M11).
  final double soloBigSpeed;
  final double helpIntervalS;
  final double hintDelayS;
  final bool dropReadyHighlight;
  final int timeLimitS;
  final int warningS;

  /// Every award is multiplied by this (party-night N3): 2 for a night's last
  /// round, 1 otherwise.
  final int pointsScale;

  /// A party night's round (party-night N4): the points are counted anyway,
  /// but only a night round says so in its frames, and only then are the
  /// pop-ups and the points drawn.
  final bool night;

  /// The cat (PRD v2 G3). The library's default is [Chaos.off], so a build
  /// without a night plays as it always did (party-night N12); the host saves
  /// a night's own default, A little (job a2).
  final Chaos chaos;

  static const defaults = PuzzleSettings();

  /// Each setting's range and step, for the settings screen.
  static const ranges = {
    'angleToleranceDeg': (min: 5.0, max: 45.0, step: 1.0),
    'positionTolerance': (min: 0.05, max: 0.6, step: 0.05),
    'rotationSpeedDegPerS': (min: 45.0, max: 540.0, step: 15.0),
    'stickDeadZone': (min: 0.05, max: 0.5, step: 0.05),
    'pickupRange': (min: 0.25, max: 2.0, step: 0.25),
    'soloBigSpeed': (min: 0.1, max: 1.0, step: 0.05),
    'helpIntervalS': (min: 1.0, max: 10.0, step: 0.5),
    'hintDelayS': (min: 3.0, max: 60.0, step: 1.0),
    'timeLimitS': (min: 30.0, max: 600.0, step: 15.0),
    'warningS': (min: 0.0, max: 60.0, step: 5.0),
    // A night's last round is worth double, the others once (N3): the most a
    // round may be worth is kept in reach of a frame's points.
    'pointsScale': (min: 1.0, max: 4.0, step: 1.0),
  };

  Map<String, Object> toJson() => {
    'angleToleranceDeg': angleToleranceDeg,
    'positionTolerance': positionTolerance,
    'rotationSpeedDegPerS': rotationSpeedDegPerS,
    'stickDeadZone': stickDeadZone,
    'pickupRange': pickupRange,
    'soloBigSpeed': soloBigSpeed,
    'helpIntervalS': helpIntervalS,
    'hintDelayS': hintDelayS,
    'dropReadyHighlight': dropReadyHighlight,
    'timeLimitS': timeLimitS,
    'warningS': warningS,
    'pointsScale': pointsScale,
    'night': night,
    'chaos': chaos.name,
  };

  /// Unknown or broken values fall back to the defaults, clamped to range.
  static PuzzleSettings fromJson(Object? json) {
    final m = json is Map ? json : const {};
    double d(String key, double fallback) {
      final v = m[key];
      final r = ranges[key]!;
      return v is num && v.isFinite ? v.toDouble().clamp(r.min, r.max) : fallback;
    }

    return PuzzleSettings(
      angleToleranceDeg: d('angleToleranceDeg', defaults.angleToleranceDeg),
      positionTolerance: d('positionTolerance', defaults.positionTolerance),
      rotationSpeedDegPerS: d('rotationSpeedDegPerS', defaults.rotationSpeedDegPerS),
      stickDeadZone: d('stickDeadZone', defaults.stickDeadZone),
      pickupRange: d('pickupRange', defaults.pickupRange),
      soloBigSpeed: d('soloBigSpeed', defaults.soloBigSpeed),
      helpIntervalS: d('helpIntervalS', defaults.helpIntervalS),
      hintDelayS: d('hintDelayS', defaults.hintDelayS),
      dropReadyHighlight: m['dropReadyHighlight'] is bool ? m['dropReadyHighlight'] as bool : true,
      timeLimitS: d('timeLimitS', defaults.timeLimitS.toDouble()).round(),
      warningS: d('warningS', defaults.warningS.toDouble()).round(),
      // A round's points never go down, and a frame's points stay small: the
      // scale is clamped to its range like the clock is.
      pointsScale: d('pointsScale', defaults.pointsScale.toDouble()).round(),
      // Not a number, so not in [ranges]: a value that isn't a bool counts
      // like a broken one (job a1's question 3).
      night: m['night'] is bool ? m['night'] as bool : defaults.night,
      chaos: _chaos(m['chaos']),
    );
  }

  /// A chaos name this build knows; a name it doesn't counts like a broken one.
  static Chaos _chaos(Object? value) => Chaos.values.where((c) => c.name == value).firstOrNull ?? defaults.chaos;

  /// A copy with one setting changed (by its JSON name).
  PuzzleSettings withValue(String key, Object value) => fromJson({...toJson(), key: value});
}
