part of 'arena_field.dart';

/// One sprite, driven by one controller. Players don't collide with each
/// other: each one races the field on its own.
class ArenaPlayer {
  ArenaPlayer._(this._field, this.id, this.slot) : _pos = _field._startFor(slot);

  /// The field it plays on: its size, walls, hazards and start positions.
  final ArenaFieldRules _field;

  /// The controller ID that drives it.
  final String id;

  /// Which start position it uses (0 is the middle one).
  final int slot;

  Offset _pos; // Fraction of the field.
  Offset _facing = const Offset(1, 0);
  Offset _aim = Offset.zero;
  bool _dashHeld = false;
  bool _touchingWall = false;
  double _dashLeft = 0;
  double _cooldownLeft = 0;
  double _graceLeft = 0;
  double _sinceHit = double.infinity;

  int wins = 0;
  int hits = 0;
  int dashes = 0;
  int failedDashes = 0;
  double? bestTimeS;

  /// The sprite's center in pixels.
  Offset get position => _field._px(_pos);

  bool get dashing => _dashLeft > 0;

  /// 0 when a dash is ready, up to 1 right after one starts.
  double get cooldown => _cooldownLeft / ArenaFieldRules.dashCooldownS;

  /// True while it can't be hit again (it blinks).
  bool get recovering => _graceLeft > 0;

  /// The aim cursor, or null when the right stick is centered.
  Offset? get aimPoint =>
      _aim.distance < 0.1 ? null : position + _aim * (ArenaFieldRules.aimRange * _field._size.shortestSide);

  void _reset() {
    _pos = _field._startFor(slot);
    _facing = Offset(_field.mirrored ? -1 : 1, 0);
    _dashLeft = 0;
    _cooldownLeft = 0;
    _graceLeft = 0;
    _touchingWall = false;
  }
}
