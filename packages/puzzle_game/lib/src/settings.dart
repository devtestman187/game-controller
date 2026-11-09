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
    );
  }

  /// A copy with one setting changed (by its JSON name).
  PuzzleSettings withValue(String key, Object value) => fromJson({...toJson(), key: value});
}
