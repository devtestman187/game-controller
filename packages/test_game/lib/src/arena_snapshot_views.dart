part of 'arena_snapshot.dart';

/// One sprite as the view sees it, positions as fractions of the field.
final class ArenaPlayerView {
  const ArenaPlayerView({
    required this.id,
    required this.x,
    required this.y,
    this.dashing = false,
    this.recovering = false,
    this.cooldown = 0,
    this.aimX,
    this.aimY,
    this.wins = 0,
    this.hits = 0,
    this.dashes = 0,
    this.failedDashes = 0,
    this.coins = 0,
    this.dizzy = false,
    this.safe = false,
  });

  final String id;
  final double x;
  final double y;
  final bool dashing;
  final bool recovering;

  /// 0 (dash ready) to 1 (just dashed).
  final double cooldown;

  /// The aim cursor as a fraction of the field, or null.
  final double? aimX;
  final double? aimY;
  final int wins;
  final int hits;
  final int dashes;
  final int failedDashes;

  /// Coins picked up this round (G9).
  final int coins;

  /// Dizzy after a drop (it can't dash), and safe after one (it drops
  /// nothing): party-night §7, the frame's `dz` and `sf`.
  final bool dizzy;
  final bool safe;

  Map<String, Object?> toJson() => {
    'id': id,
    'x': _r(x),
    'y': _r(y),
    if (dashing) 'd': 1,
    if (recovering) 'r': 1,
    if (cooldown > 0) 'cd': _r(cooldown),
    'ax': ?(aimX == null ? null : _r(aimX!)),
    'ay': ?(aimY == null ? null : _r(aimY!)),
    'w': wins,
    'h': hits,
    'ds': dashes,
    'fd': failedDashes,
    if (coins > 0) 'c': coins,
    if (dizzy) 'dz': 1,
    if (safe) 'sf': 1,
  };

  static ArenaPlayerView fromJson(Map<String, Object?> j) => ArenaPlayerView(
    id: j['id'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    dashing: j['d'] == 1,
    recovering: j['r'] == 1,
    cooldown: (j['cd'] as num?)?.toDouble() ?? 0,
    aimX: (j['ax'] as num?)?.toDouble(),
    aimY: (j['ay'] as num?)?.toDouble(),
    wins: j['w'] as int,
    hits: j['h'] as int,
    dashes: j['ds'] as int,
    failedDashes: j['fd'] as int,
    coins: j['c'] as int? ?? 0,
    dizzy: j['dz'] == 1,
    safe: j['sf'] == 1,
  );

  /// This sprite moved [t] of the way to [next] (m12 §4): its place, its
  /// cooldown and its aim lerp; the flags and counters stay this frame's. An
  /// aim only one frame has is held as it is.
  ArenaPlayerView lerpTo(ArenaPlayerView next, double t) {
    final double? ax = aimX;
    final double? bx = next.aimX;
    final double? ay = aimY;
    final double? by = next.aimY;
    double? aim(double? from, double? to) => from == null || to == null ? from : from + (to - from) * t;
    return ArenaPlayerView(
      id: id,
      x: x + (next.x - x) * t,
      y: y + (next.y - y) * t,
      dashing: dashing,
      recovering: recovering,
      cooldown: cooldown + (next.cooldown - cooldown) * t,
      aimX: aim(ax, bx),
      aimY: aim(ay, by),
      wins: wins,
      hits: hits,
      dashes: dashes,
      failedDashes: failedDashes,
      coins: coins,
      dizzy: dizzy,
      safe: safe,
    );
  }
}

/// One coin as the view sees it (G9): its place as fractions of the field and
/// how long it has been out, which its spin turns on. A frame carries the
/// coins as `[x, y, age]` triples, so a few of them stay small.
final class ArenaCoinView {
  const ArenaCoinView({required this.x, required this.y, this.ageMs = 0, this.gold = false, this.dropper});

  final double x;
  final double y;

  /// Milliseconds since the coin appeared: a field coin younger than
  /// [ArenaCoin.sparkleS] still sparkles, and can't be taken yet.
  final int ageMs;

  /// A gold coin, worth two (party-night §7).
  final bool gold;

  /// The index in the frame's `pl` of the marble that dropped it, or null for
  /// a coin that came out of a zone. A number, so a few coins keep the frame
  /// small; the rules keep the id.
  final int? dropper;

  /// The frame's flags: bit 0 gold, bit 1 dropped.
  static const _gold = 1;
  static const _dropped = 2;

  List<Object> toJson() {
    final flags = (gold ? _gold : 0) | (dropper == null ? 0 : _dropped);
    return [_r(x), _r(y), ageMs, if (flags != 0) flags, ?dropper];
  }

  static ArenaCoinView fromJson(List<Object?> j) {
    final flags = j.length > 3 ? (j[3] as num).toInt() : 0;
    return ArenaCoinView(
      x: (j[0] as num).toDouble(),
      y: (j[1] as num).toDouble(),
      ageMs: (j[2] as num).toInt(),
      gold: flags & _gold != 0,
      dropper: j.length > 4 ? (j[4] as num).toInt() : null,
    );
  }

  @override
  String toString() =>
      'ArenaCoinView($x, $y, ${ageMs}ms${gold ? ', gold' : ''}${dropper == null ? '' : ', $dropper'} )';
}
