import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';

/// Plays [ArenaGame] full size: the field fills the space it's given and
/// follows it when the window resizes. A bar on top shows the round, the
/// timer and the counters.
///
/// [readInput] is called every frame for the driving controller's latest
/// state (null = none), and [onEvent] gets every game event so the host can
/// send the haptic event and play the sound.
class ArenaView extends StatefulWidget {
  const ArenaView({super.key, required this.readInput, required this.onEvent, this.game});

  final InputStateMessage? Function() readInput;
  final void Function(GameEvent event) onEvent;

  /// The game to show. Tests pass one in to inspect it.
  final ArenaGame? game;

  @override
  State<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends State<ArenaView> with SingleTickerProviderStateMixin {
  late final ArenaGame _game = widget.game ?? ArenaGame();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final events = _game.update(dt, GameInput.fromState(widget.readInput()));
    for (final e in events) {
      widget.onEvent(e);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hud(game: _game),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _game.resize(constraints.biggest);
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(key: const Key('arena'), painter: _ArenaPainter(_game, scheme)),
                    if (_game.phase == ArenaPhase.won)
                      Center(
                        child: _Banner(
                          'Goal! ${_game.lastTimeS!.toStringAsFixed(1)} s',
                          'Next round in ${max(0, _game.breakLeft).ceil()}…',
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
  const _Hud({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tabular = text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final best = game.bestTimeS;
    final cooldown = game.cooldown;
    return Container(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 24,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Round ${game.round}', style: text.titleMedium),
          Text('${game.roundTime.toStringAsFixed(1)} s', key: const Key('roundTime'), style: tabular),
          Text('Best ${best == null ? '–' : '${best.toStringAsFixed(1)} s'}', style: tabular),
          Text('Wins ${game.wins}', key: const Key('wins'), style: tabular),
          Text('Hits ${game.hits}', key: const Key('hits'), style: tabular),
          Text(
            'Dashes ${game.dashes}${game.failedDashes == 0 ? '' : ' (${game.failedDashes} too soon)'}',
            key: const Key('dashes'),
            style: tabular,
          ),
          Text(
            cooldown == 0 ? 'Dash ready (A)' : 'Dash in ${(cooldown * ArenaGame.dashCooldownS).toStringAsFixed(1)} s',
            style: text.bodyMedium?.copyWith(color: cooldown == 0 ? Colors.greenAccent : scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.title, this.subtitle);

  final String title;
  final String subtitle;

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
              style: text.displaySmall?.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold),
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
  _ArenaPainter(this.game, this.scheme);

  final ArenaGame game;
  final ColorScheme scheme;

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

    // Aim cursor (right stick).
    final aim = game.aimPoint;
    if (aim != null) {
      final cross = Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final r = game.playerRadiusPx * 0.7;
      canvas.drawCircle(aim, r, cross);
      canvas.drawLine(aim - Offset(r * 1.6, 0), aim + Offset(r * 1.6, 0), cross);
      canvas.drawLine(aim - Offset(0, r * 1.6), aim + Offset(0, r * 1.6), cross);
    }

    // The sprite: blinks while recovering from a hazard, glows while dashing,
    // and a ring fills back up as the dash cools down.
    final p = game.player;
    final r = game.playerRadiusPx;
    final blinkOff = game.recovering && (game.roundTime * 10).floor().isEven;
    if (game.dashing) {
      canvas.drawCircle(p, r * 1.7, Paint()..color = const Color(0xFF5AAAFF).withValues(alpha: 0.35));
    }
    if (!blinkOff) {
      canvas.drawCircle(p, r, Paint()..color = const Color(0xFF5AAAFF));
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (game.cooldown > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: r * 1.35),
        -pi / 2,
        2 * pi * (1 - game.cooldown),
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
