import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'arena.dart';

/// One player in the game, as the host sees it this frame.
typedef PlayerFeed = ({String id, int number, String name, Color color, GamepadState gamepad});

extension on PlayerFeed {
  String get label => 'P$number $name';
}

/// Every player of [host], with their controls this frame.
List<PlayerFeed> feedsOf(GameHost host) => [
  for (final p in host.players)
    (id: p.id, number: p.number, name: p.nickname ?? '', color: Color(p.color), gamepad: host.gamepad(p.id)),
];

/// The game's name in analytics records.
const arenaGame = 'arena';

/// Plays [ArenaGame] full size: the field fills the space it's given and
/// follows it when the window resizes. A bar on top shows the round, the
/// timer and each player's counters.
///
/// Everything comes from the [host] (PRD v2 P3): the players, their controls
/// (the standard gamepad, P4) and where analytics go. Each player drives
/// their own sprite. [onEvent] gets every game event (with the player who
/// caused it), so the host app can send the haptic event to that controller
/// and play the sound.
///
/// For analytics it reports each round's start and end, every game event,
/// how many frames were late, and the "received to drawn" delay stage (S7):
/// how long a player's new input waited for the first frame built with it.
class ArenaView extends StatefulWidget {
  const ArenaView({super.key, required this.host, required this.onEvent, this.game});

  final GameHost host;
  final void Function(GameEvent event) onEvent;

  /// The game to show. Tests pass one in to inspect it.
  final ArenaGame? game;

  /// A frame that took longer than this was dropped (a 60 Hz frame is 16.7).
  static const lateFrameMs = 25;

  @override
  State<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends State<ArenaView> with SingleTickerProviderStateMixin {
  late final ArenaGame _game = widget.game ?? ArenaGame();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  List<PlayerFeed> _feeds = const [];
  final _arrived = <String, int>{};
  bool _roundRunning = false;
  int _frames = 0;
  int _late = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_frames > 0) _record('frames', data: {'drawn': _frames, 'late': _late});
    super.dispose();
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      widget.host.record(GameRecord(game: arenaGame, name: name, playerId: playerId, data: data));

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final host = widget.host;
    _feeds = feedsOf(host);
    if (_feeds.isNotEmpty) {
      _frames++;
      if (dt * 1000 > ArenaView.lateFrameMs && _frames > 1) _late++;
    }
    if (!_roundRunning && _feeds.isNotEmpty && _game.phase == ArenaPhase.playing) {
      _roundRunning = true;
      _record('round_start');
    }

    // Inputs that are new this frame: their delay to the drawn frame.
    final fresh = <String, int>{};
    for (final f in _feeds) {
      final at = host.inputArrivedAtMs(f.id);
      if (at != null && at != _arrived[f.id]) fresh[f.id] = at;
    }
    _arrived
      ..removeWhere((id, _) => !_feeds.any((f) => f.id == id))
      ..addAll(fresh);

    final before = _game.phase;
    final events = _game.update(dt, {for (final f in _feeds) f.id: GameInput.fromGamepad(f.gamepad)});
    for (final e in events) {
      widget.onEvent(e);
      _record(_eventName(e.cause), playerId: e.playerId);
    }
    if (before == ArenaPhase.playing && _game.phase == ArenaPhase.won) {
      _roundRunning = false;
      _record(
        'round_end',
        playerId: _game.winnerId,
        data: {
          'timeS': _game.lastTimeS,
          'modes': {for (final f in _feeds) f.id: f.gamepad.mode.name},
          'winner': _game.winnerId,
        },
      );
      _record('frames', data: {'drawn': _frames, 'late': _late});
      _frames = 0;
      _late = 0;
    }
    setState(() {});
    if (fresh.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final now = host.nowMs;
        for (final MapEntry(key: id, value: at) in fresh.entries) {
          host.reportStage(id, LatencyStage.receivedToDrawn, now - at);
        }
      });
    }
  }

  static String _eventName(GameEventCause cause) => switch (cause) {
    GameEventCause.wall => 'wall_hit',
    GameEventCause.hazard => 'hazard_hit',
    GameEventCause.goal => 'goal',
    GameEventCause.dash => 'dash',
    GameEventCause.cooldown => 'failed_dash',
  };

  PlayerFeed? _feed(String? id) => _feeds.where((f) => f.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final winner = _feed(_game.winnerId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(game: _game, feeds: _feeds),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _game.resize(constraints.biggest);
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      key: const Key('arena'),
                      painter: _ArenaPainter(_game, {for (final f in _feeds) f.id: f}),
                    ),
                    if (_game.phase == ArenaPhase.won)
                      Center(
                        child: _Banner(
                          _feeds.length > 1 && winner != null
                              ? 'P${winner.number} wins! ${_game.lastTimeS!.toStringAsFixed(1)} s'
                              : 'Goal! ${_game.lastTimeS!.toStringAsFixed(1)} s',
                          'Next round in ${max(0, _game.breakLeft).ceil()}…',
                          color: winner?.color ?? Colors.greenAccent,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.feeds});

  final ArenaGame game;
  final List<PlayerFeed> feeds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tabular = text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final small = text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final best = game.bestTimeS;
    final bestBy = feeds.length > 1 ? feeds.where((f) => f.id == game.bestId).firstOrNull?.number : null;
    return Container(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Round ${game.round}', style: text.titleMedium),
              Text('${game.roundTime.toStringAsFixed(1)} s', key: const Key('roundTime'), style: tabular),
              Text(
                'Best ${best == null ? '–' : '${best.toStringAsFixed(1)} s${bestBy == null ? '' : ' (P$bestBy)'}'}',
                style: tabular,
              ),
            ],
          ),
          for (final f in feeds)
            if (game.player(f.id) case final p?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  key: Key('hud-${f.id}'),
                  spacing: 20,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 14, color: f.color),
                        const SizedBox(width: 6),
                        Text(f.label, style: text.titleSmall),
                      ],
                    ),
                    Text('Wins ${p.wins}', key: Key('wins-${f.id}'), style: small),
                    Text('Hits ${p.hits}', key: Key('hits-${f.id}'), style: small),
                    Text(
                      'Dashes ${p.dashes}${p.failedDashes == 0 ? '' : ' (${p.failedDashes} too soon)'}',
                      key: Key('dashes-${f.id}'),
                      style: small,
                    ),
                    Text(
                      p.cooldown == 0
                          ? 'Dash ready (A)'
                          : 'Dash in ${(p.cooldown * ArenaGame.dashCooldownS).toStringAsFixed(1)} s',
                      style: text.bodyMedium?.copyWith(
                        color: p.cooldown == 0 ? Colors.greenAccent : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.title, this.subtitle, {required this.color});

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: text.displaySmall?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            Text(subtitle, style: text.titleMedium?.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Plain coloured shapes for now (PRD: CC0 art comes later).
class _ArenaPainter extends CustomPainter {
  _ArenaPainter(this.game, this.feeds);

  final ArenaGame game;
  final Map<String, PlayerFeed> feeds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14181F));
    final unit = size.shortestSide;

    // Faint grid, so movement reads even on a plain field.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    final step = unit / 10;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Start pad and goal.
    canvas.drawCircle(game.startPx, game.playerRadiusPx * 1.8, Paint()..color = Colors.white.withValues(alpha: 0.08));
    final goal = RRect.fromRectAndRadius(game.goalRect, Radius.circular(unit * 0.02));
    canvas.drawRRect(goal, Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.55));
    canvas.drawRRect(
      goal,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _label(canvas, game.goalRect.center, 'GOAL', unit * 0.04, Colors.greenAccent);

    // Walls.
    final wallPaint = Paint()..color = const Color(0xFF5C6B7A);
    for (final w in game.wallRects) {
      canvas.drawRRect(RRect.fromRectAndRadius(w, Radius.circular(unit * 0.008)), wallPaint);
    }

    // Hazards: red discs with a darker core.
    for (final h in game.hazardPositions) {
      canvas.drawCircle(h, game.hazardRadiusPx, Paint()..color = const Color(0xFFE53935));
      canvas.drawCircle(h, game.hazardRadiusPx * 0.45, Paint()..color = const Color(0xFF7F0000));
    }

    for (final p in game.players) {
      _paintPlayer(canvas, p, feeds[p.id], unit);
    }
  }

  void _paintPlayer(Canvas canvas, ArenaPlayer player, PlayerFeed? feed, double unit) {
    final color = feed?.color ?? const Color(0xFF5AAAFF);

    // Aim cursor (right stick), in the player's colour.
    final aim = player.aimPoint;
    if (aim != null) {
      final cross = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final r = game.playerRadiusPx * 0.7;
      canvas.drawCircle(aim, r, cross);
      canvas.drawLine(aim - Offset(r * 1.6, 0), aim + Offset(r * 1.6, 0), cross);
      canvas.drawLine(aim - Offset(0, r * 1.6), aim + Offset(0, r * 1.6), cross);
    }

    // The sprite: blinks while recovering from a hazard, glows while dashing,
    // and a ring fills back up as the dash cools down.
    final p = player.position;
    final r = game.playerRadiusPx;
    final blinkOff = player.recovering && (game.roundTime * 10).floor().isEven;
    if (player.dashing) {
      canvas.drawCircle(p, r * 1.7, Paint()..color = color.withValues(alpha: 0.35));
    }
    if (!blinkOff) {
      canvas.drawCircle(p, r, Paint()..color = color);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (feed != null && feeds.length > 1) {
        // The player number on the sprite, matching the phone's badge.
        _label(canvas, p, '${feed.number}', r * 1.1, const Color(0xFF14181F));
      }
    }
    if (player.cooldown > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: r * 1.35),
        -pi / 2,
        2 * pi * (1 - player.cooldown),
        false,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _label(Canvas canvas, Offset center, String text, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  // The game changes every frame.
  @override
  bool shouldRepaint(_ArenaPainter old) => true;
}
