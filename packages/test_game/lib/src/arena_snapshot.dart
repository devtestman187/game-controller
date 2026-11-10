import 'dart:convert';
import 'dart:ui';

import 'package:game_kit/game_kit.dart';

import 'arena.dart';
import 'arena_coin.dart';
import 'arena_field.dart';
import 'arena_map.dart';
import 'arena_mode.dart';
import 'arena_pieces.dart';

part 'arena_snapshot_pieces.dart';
part 'arena_snapshot_views.dart';

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
    this.mirrored = false,
    this.movers = const [],
    this.theme = 'playroom',
    this.springs = const [],
    this.posts = const [],
    this.belts = const [],
    this.decor = const [],
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

  /// Whether the round flips the field left to right (M14 k2a), so a view
  /// mirrors the pieces it draws from the map with the walls.
  final bool mirrored;

  /// Where the movers' bars are this frame, in fractions of the field, as
  /// each one's two ends: the only part of a mover a frame carries (M14 k2a).
  /// A phone draws them without the map; a map without movers leaves it out.
  final List<(Offset, Offset)> movers;

  /// The floor's look (M14 k2a), `"playroom"` when the map names none: a theme
  /// only changes how the field is drawn.
  final String theme;

  /// The pieces fixed to the floor (M14 k2a), as the map file gives them: a
  /// phone draws them from the frame, since it has no copy of the map yet.
  final List<SpringSpec> springs;
  final List<PostSpec> posts;
  final List<BeltSpec> belts;
  final List<DecorSpec> decor;

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
    if (mirrored) 'mi': 1,
    if (movers.isNotEmpty)
      'mv': [
        for (final (a, b) in movers) [_r(a.dx), _r(a.dy), _r(b.dx), _r(b.dy)],
      ],
    if (theme != 'playroom') 'th': theme,
    if (springs.isNotEmpty)
      'sp': [
        for (final spring in springs)
          [_r(spring.at.dx), _r(spring.at.dy), if (spring.radius != springRadius) _r(spring.radius)],
      ],
    if (posts.isNotEmpty)
      'po': [
        for (final post in posts) [_r(post.at.dx), _r(post.at.dy), if (post.radius != postRadius) _r(post.radius)],
      ],
    if (belts.isNotEmpty)
      'bl': [
        for (final belt in belts)
          [
            _r(belt.from.dx),
            _r(belt.from.dy),
            _r(belt.to.dx),
            _r(belt.to.dy),
            if (belt.width != beltWidth) _r(belt.width),
          ],
      ],
    if (decor.isNotEmpty)
      'dc': [
        for (final piece in decor)
          [piece.kind.index, _r(piece.at.dx), _r(piece.at.dy), if (piece.size != decorSize) _r(piece.size)],
      ],
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
    final pieces = _piecesOf(j);
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
      mirrored: pieces.mirrored,
      movers: pieces.movers,
      theme: pieces.theme,
      springs: pieces.springs,
      posts: pieces.posts,
      belts: pieces.belts,
      decor: pieces.decor,
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
      mirrored: mirrored,
      movers: [
        for (final (i, (a, b)) in movers.indexed)
          if (i < next.movers.length)
            (Offset.lerp(a, next.movers[i].$1, t)!, Offset.lerp(b, next.movers[i].$2, t)!)
          else
            (a, b),
      ],
      theme: theme,
      springs: springs,
      posts: posts,
      belts: belts,
      decor: decor,
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
      mirrored: mirrored,
      movers: [for (final (a, b) in moverBars) (frac(a), frac(b))],
      theme: map.theme,
      springs: map.springs,
      posts: map.posts,
      belts: map.belts,
      decor: map.decor,
    );
  }
}
