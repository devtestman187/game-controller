part of 'arena_field.dart';

/// One sprite, driven by one controller. In the race players don't collide:
/// each one races the field on its own. In the Bumper Round a touch pushes
/// both marbles (G9).
class ArenaPlayer {
  ArenaPlayer._(this._field, this.id, this.slot) : _pos = _field._startFor(slot);

  /// The field it plays on: its size, walls, hazards and start positions.
  final ArenaFieldRules _field;

  /// The controller ID that drives it.
  final String id;

  /// Which start position it uses (0 is the first of the mode's starts).
  final int slot;

  Offset _pos; // Fraction of the field.
  Offset _facing = const Offset(1, 0);
  Offset _aim = Offset.zero;
  Offset _velocity = Offset.zero;
  Offset _shove = Offset.zero;
  bool _dashHeld = false;
  bool _touchingWall = false;
  double _dashLeft = 0;
  double _cooldownLeft = 0;
  double _graceLeft = 0;
  double _sinceHit = double.infinity;
  double _sinceBump = double.infinity;

  int wins = 0;
  int hits = 0;
  int dashes = 0;
  int failedDashes = 0;
  double? bestTimeS;

  /// Coins picked up this round (G9), how many touches it felt, and how many
  /// marbles it shoved while dashing.
  int coins = 0;
  int bumps = 0;
  int shoves = 0;

  /// The sprite's center in pixels.
  Offset get position => _field._px(_pos);

  bool get dashing => _dashLeft > 0;

  /// 0 when a dash is ready, up to 1 right after one starts.
  double get cooldown => _cooldownLeft / ArenaFieldRules.dashCooldownS;

  /// True while it can't be hit again (it blinks).
  bool get recovering => _graceLeft > 0;

  /// The speed it moved at this step, in pixels per second, the shove
  /// included: a touch faster than a marble can walk is a shove.
  Offset get velocity => _velocity;

  /// The aim cursor, or null when the right stick is centered.
  Offset? get aimPoint =>
      _aim.distance < 0.1 ? null : position + _aim * (ArenaFieldRules.aimRange * _field._size.shortestSide);

  /// Pushes the marble with [velocity] (pixels per second), as another marble
  /// touching it does: it slides that way and the push fades over
  /// [ArenaFieldRules.shoveS].
  void shove(Offset velocity) => _shove = velocity;

  /// Puts the marble's centre at [pixels], already clear of the walls.
  void place(Offset pixels) => _pos = _field._frac(pixels);

  /// Counts another marble touching this one, and says whether it was long
  /// enough after the last touch to feel: a pair resting together doesn't buzz
  /// every step.
  bool countBump() {
    if (_sinceBump < ArenaFieldRules.contactGapS) return false;
    bumps++;
    _sinceBump = 0;
    return true;
  }

  void _reset() {
    _pos = _field._startFor(slot);
    _facing = Offset(_field.mirrored ? -1 : 1, 0);
    _velocity = Offset.zero;
    _shove = Offset.zero;
    _dashLeft = 0;
    _cooldownLeft = 0;
    _graceLeft = 0;
    _touchingWall = false;
  }
}
