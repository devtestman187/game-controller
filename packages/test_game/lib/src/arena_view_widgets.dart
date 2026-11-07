import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';
import 'arena_painter.dart';
import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// The arena as a view draws it: the counters bar over the field. The TV and a
/// phone draw the same box from the same snapshot and roster.
class ArenaBoard extends StatelessWidget {
  const ArenaBoard({super.key, required this.snapshot, required this.roster, this.onResize});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  /// Called with the field's size every time it is drawn, so the host's rules
  /// can move in it. A viewer has no rules and passes none.
  final ValueChanged<Size>? onResize;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ArenaHud(snapshot: snapshot, roster: roster),
      Expanded(
        child: ArenaField(snapshot: snapshot, roster: roster, onResize: onResize),
      ),
    ],
  );
}

/// The field: fills the box it is given, draws [snapshot] and, while the round
/// is won, overlays the winner's banner.
class ArenaField extends StatelessWidget {
  const ArenaField({super.key, required this.snapshot, required this.roster, this.onResize});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;
  final ValueChanged<Size>? onResize;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return LayoutBuilder(
      builder: (context, constraints) {
        onResize?.call(constraints.biggest);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(key: const Key('arena'), painter: ArenaPainter(s, roster)),
              if (s.phase == ArenaPhase.won) Center(child: _winnerBanner(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _winnerBanner(ArenaSnapshot s) {
    final id = s.winnerId;
    final winner = id == null ? null : roster[id];
    final timeS = (s.lastTimeS ?? 0).toStringAsFixed(1);
    final whoWon = roster.length > 1 && winner != null;
    return ArenaBanner(
      whoWon ? 'P${winner.number} wins! $timeS s' : 'Goal! $timeS s',
      'Next round in ${max(0, s.breakLeftS).ceil()}…',
      color: winner == null ? Colors.greenAccent : Color(playerColor(winner.number)),
    );
  }
}

/// The bar over the field: the round, its clock, the best round, and a row of
/// counters for each player in the [roster]. It draws from an [ArenaSnapshot]
/// only (S8).
class ArenaHud extends StatelessWidget {
  const ArenaHud({super.key, required this.snapshot, required this.roster});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tabular = text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final s = snapshot;
    final best = s.bestTimeS;
    final bestId = s.bestId;
    final bestBy = roster.length > 1 && bestId != null ? roster[bestId]?.number : null;
    final byNumber = roster.entries.toList()..sort((a, b) => a.value.number.compareTo(b.value.number));
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
              Text('Round ${s.round}', style: text.titleMedium),
              Text('${s.roundTimeS.toStringAsFixed(1)} s', key: const Key('roundTime'), style: tabular),
              Text(
                'Best ${best == null ? '–' : '${best.toStringAsFixed(1)} s${bestBy == null ? '' : ' (P$bestBy)'}'}',
                style: tabular,
              ),
            ],
          ),
          for (final MapEntry(key: id, value: player) in byNumber)
            if (s.player(id) case final p?) _PlayerRow(id: id, player: player, view: p),
        ],
      ),
    );
  }
}

/// One player's counters in the bar: colour dot, number and name, wins, hits,
/// dashes and whether a dash is ready.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.id, required this.player, required this.view});

  final String id;
  final ({int number, String name}) player;
  final ArenaPlayerView view;

  @override
  Widget build(BuildContext context) {
    final p = view;
    final text = Theme.of(context).textTheme;
    final small = text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        key: Key('hud-$id'),
        spacing: 20,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 14, color: Color(playerColor(player.number))),
              const SizedBox(width: 6),
              Text('P${player.number} ${player.name}', style: text.titleSmall),
            ],
          ),
          Text('Wins ${p.wins}', key: Key('wins-$id'), style: small),
          Text('Hits ${p.hits}', key: Key('hits-$id'), style: small),
          Text(
            'Dashes ${p.dashes}${p.failedDashes == 0 ? '' : ' (${p.failedDashes} too soon)'}',
            key: Key('dashes-$id'),
            style: small,
          ),
          Text(
            p.cooldown == 0
                ? 'Dash ready (A)'
                : 'Dash in ${(p.cooldown * ArenaGame.dashCooldownS).toStringAsFixed(1)} s',
            style: text.bodyMedium?.copyWith(color: p.cooldown == 0 ? Colors.greenAccent : scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The banner over the field between rounds: who won and how soon the next
/// round starts.
class ArenaBanner extends StatelessWidget {
  const ArenaBanner(this.title, this.subtitle, {super.key, required this.color});

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
