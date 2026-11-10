import 'dart:convert';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'arena.dart';
import 'arena_coin.dart';
import 'arena_map.dart';
import 'arena_mode.dart';

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
    );
  }
}

/// One coin as the view sees it (G9): its place as fractions of the field and
/// how long it has been out, which its spin turns on. A frame carries the
/// coins as `[x, y, age]` triples, so a few of them stay small.
final class ArenaCoinView {
  const ArenaCoinView({required this.x, required this.y, this.ageMs = 0});

  final double x;
  final double y;

  /// Milliseconds since the coin appeared.
  final int ageMs;

  List<Object> toJson() => [_r(x), _r(y), ageMs];

  static ArenaCoinView fromJson(List<Object?> j) =>
      ArenaCoinView(x: (j[0] as num).toDouble(), y: (j[1] as num).toDouble(), ageMs: (j[2] as num).toInt());

  @override
  String toString() => 'ArenaCoinView($x, $y, ${ageMs}ms)';
}

/// The arena as one value the view draws from (PRD v2 S8). Positions and
/// rectangles are fractions of the field (0..1), sizes fractions of its
/// shorter side, so it draws the same in any box. Versioned JSON, so a host
/// can send it to phones that show the game (M12).
///
/// Version 2 (party-night N11, M14 G9) names the map the round plays and its
/// mode, and carries the Bumper Round's coins, each player's coins and the
/// round's clock. The race's frame is the same frame, with those left out.
final class ArenaSnapshot implements GameSnapshot {
  const ArenaSnapshot({
    required this.round,
    required this.roundTimeS,
    required this.phase,
    required this.walls,
    required this.goal,
    required this.hazards,
    required this.players,
    this.winnerId,
    this.start = const Offset(0.07, 0.5),
    this.lastTimeS,
    this.breakLeftS = 0,
    this.bestTimeS,
    this.bestId,
    this.playerRadius = ArenaGame.playerRadius,
    this.hazardRadius = ArenaGame.hazardRadius,
    this.mapId = ArenaMap.playroomId,
    this.mode = ArenaMode.race,
    this.coins = const [],
    this.timeLeftMs,
    this.coinRadius = ArenaCoin.radius,
  });

  static const version = 2;

  final int round;
  final double roundTimeS;
  final ArenaPhase phase;
  final List<Rect> walls;

  /// The goal pad, or [Rect.zero] in the Bumper Round, which has none.
  final Rect goal;
  final List<Offset> hazards;
  final List<ArenaPlayerView> players;

  /// The start pad, or the field's corner in the Bumper Round, which starts
  /// from the map's bumper starts instead.
  final Offset start;
  final String? winnerId;
  final double? lastTimeS;
  final double breakLeftS;
  final double? bestTimeS;
  final String? bestId;
  final double playerRadius;
  final double hazardRadius;

  /// The map the round plays (M14 k1b), by id: a phone draws the field it has
  /// for that id (M14 k2a).
  final String mapId;

  /// The round's mode (G9).
  final ArenaMode mode;

  /// The coins on the field, in the order they came out; none in the race.
  final List<ArenaCoinView> coins;

  /// The Bumper Round's clock in milliseconds, or null in the race.
  final int? timeLeftMs;

  /// A coin's radius as a fraction of the field's shorter side (G9).
  final double coinRadius;

  ArenaPlayerView? player(String id) => players.where((p) => p.id == id).firstOrNull;

  @override
  Map<String, Object?> toJson() => {
    'v': version,
    'mid': mapId,
    if (mode != ArenaMode.race) 'md': mode.index,
    'rd': round,
    't': _r(roundTimeS),
    'ph': phase.index,
    'wl': [for (final w in walls) _rect(w)],
    if (mode == ArenaMode.race) 'g': _rect(goal),
    'hz': [
      for (final h in hazards) [_r(h.dx), _r(h.dy)],
    ],
    'pl': [for (final p in players) p.toJson()],
    if (mode == ArenaMode.race) 'st': [_r(start.dx), _r(start.dy)],
    'win': ?winnerId,
    'last': ?(lastTimeS == null ? null : _r(lastTimeS!)),
    if (breakLeftS > 0) 'br': _r(breakLeftS),
    'best': ?(bestTimeS == null ? null : _r(bestTimeS!)),
    'bestId': ?bestId,
    if (coins.isNotEmpty) 'co': [for (final c in coins) c.toJson()],
    if (timeLeftMs != null) 'tl': timeLeftMs,
    if (mode == ArenaMode.bumper) 'cr': _r(coinRadius),
  };

  String encode() => jsonEncode(toJson());

  static ArenaSnapshot decode(String text) => fromJson(jsonDecode(text) as Map<String, Object?>);

  static ArenaSnapshot fromJson(Map<String, Object?> j) {
    if (j['v'] != version) throw FormatException('Arena snapshot version ${j['v']}, expected $version');
    Rect rect(Object? v) {
      final l = (v as List).cast<num>();
      return Rect.fromLTRB(l[0].toDouble(), l[1].toDouble(), l[2].toDouble(), l[3].toDouble());
    }

    final mode = switch (j['md']) {
      null => ArenaMode.race,
      final num i when i >= 0 && i < ArenaMode.values.length => ArenaMode.values[i.toInt()],
      final other => throw FormatException('Arena snapshot mode $other'),
    };
    return ArenaSnapshot(
      round: j['rd'] as int,
      roundTimeS: (j['t'] as num).toDouble(),
      phase: ArenaPhase.values[j['ph'] as int],
      walls: [for (final w in j['wl'] as List) rect(w)],
      goal: j['g'] == null ? Rect.zero : rect(j['g']),
      hazards: [
        for (final h in (j['hz'] as List).cast<List>()) Offset((h[0] as num).toDouble(), (h[1] as num).toDouble()),
      ],
      players: [for (final p in (j['pl'] as List).cast<Map<String, Object?>>()) ArenaPlayerView.fromJson(p)],
      start: switch (j['st']) {
        [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
        _ => const Offset(0.07, 0.5),
      },
      winnerId: j['win'] as String?,
      lastTimeS: (j['last'] as num?)?.toDouble(),
      breakLeftS: (j['br'] as num?)?.toDouble() ?? 0,
      bestTimeS: (j['best'] as num?)?.toDouble(),
      bestId: j['bestId'] as String?,
      mapId: j['mid'] as String? ?? ArenaMap.playroomId,
      mode: mode,
      coins: [for (final c in (j['co'] as List? ?? const [])) ArenaCoinView.fromJson((c as List).cast<Object?>())],
      timeLeftMs: (j['tl'] as num?)?.toInt(),
      coinRadius: (j['cr'] as num?)?.toDouble() ?? ArenaCoin.radius,
    );
  }

  /// The arena at [t] between this frame (0) and [next] (1), for a viewer
  /// drawing between two frames (m12 §4): the sprites, their cooldowns and
  /// aims, the round's clock, the break and the hazards move; the round, the
  /// phase, the field, the map, the coins, the winner and the counters stay
  /// this frame's. A sprite only in [next] isn't drawn yet.
  @override
  ArenaSnapshot lerpTo(GameSnapshot next, double t) {
    if (next is! ArenaSnapshot) {
      throw ArgumentError.value(next, 'next', 'An arena snapshot lerps with another arena snapshot');
    }
    if (t <= 0) return this;
    if (t >= 1) return next;
    double lerp(double from, double to) => from + (to - from) * t;
    return ArenaSnapshot(
      round: round,
      roundTimeS: lerp(roundTimeS, next.roundTimeS),
      phase: phase,
      walls: walls,
      goal: goal,
      hazards: [
        for (final (i, h) in hazards.indexed) i < next.hazards.length ? Offset.lerp(h, next.hazards[i], t)! : h,
      ],
      players: [
        for (final p in players)
          if (next.player(p.id) case final q?) p.lerpTo(q, t) else p,
      ],
      winnerId: winnerId,
      start: start,
      lastTimeS: lastTimeS,
      breakLeftS: lerp(breakLeftS, next.breakLeftS),
      bestTimeS: bestTimeS,
      bestId: bestId,
      playerRadius: playerRadius,
      hazardRadius: hazardRadius,
      mapId: mapId,
      mode: mode,
      coins: coins,
      timeLeftMs: timeLeftMs == null || next.timeLeftMs == null
          ? timeLeftMs
          : lerp(timeLeftMs!.toDouble(), next.timeLeftMs!.toDouble()).round(),
      coinRadius: coinRadius,
    );
  }
}

double _r(double v) => (v * 10000).round() / 10000;

List<double> _rect(Rect r) => [_r(r.left), _r(r.top), _r(r.right), _r(r.bottom)];

extension ArenaSnapshots on ArenaGame {
  /// Everything the view needs, and nothing else (S8).
  ArenaSnapshot snapshot() {
    final s = size;
    final bumper = mode == ArenaMode.bumper;
    Offset frac(Offset p) => Offset(p.dx / s.width, p.dy / s.height);
    Rect fracRect(Rect r) => Rect.fromPoints(frac(r.topLeft), frac(r.bottomRight));
    return ArenaSnapshot(
      round: round,
      roundTimeS: roundTime,
      phase: phase,
      walls: [for (final w in wallRects) fracRect(w)],
      goal: bumper ? Rect.zero : fracRect(goalRect),
      hazards: [for (final h in hazardPositions) frac(h)],
      players: [
        for (final p in players)
          ArenaPlayerView(
            id: p.id,
            x: frac(p.position).dx,
            y: frac(p.position).dy,
            dashing: p.dashing,
            recovering: p.recovering,
            cooldown: p.cooldown,
            aimX: p.aimPoint == null ? null : frac(p.aimPoint!).dx,
            aimY: p.aimPoint == null ? null : frac(p.aimPoint!).dy,
            wins: p.wins,
            hits: p.hits,
            dashes: p.dashes,
            failedDashes: p.failedDashes,
            coins: p.coins,
          ),
      ],
      start: bumper ? Offset.zero : frac(startPx),
      winnerId: winnerId,
      lastTimeS: lastTimeS,
      breakLeftS: breakLeft,
      bestTimeS: bestTimeS,
      bestId: bestId,
      mapId: map.id,
      mode: mode,
      coins: [for (final c in coins) ArenaCoinView(x: c.x, y: c.y, ageMs: (c.ageS * 1000).round())],
      timeLeftMs: timeLeftS == null ? null : (timeLeftS! * 1000).round(),
      coinRadius: ArenaCoin.radius,
    );
  }
}
