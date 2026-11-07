import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';
import 'arena_painter.dart';
import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// The arena as a view draws it: the counters bar over the field. The TV and a
/// phone draw the same box from the same snapshot and roster; on a short box
/// the bar folds to one line so the field keeps the room (m12-phone-layout
/// §4).
class ArenaBoard extends StatelessWidget {
  const ArenaBoard({super.key, required this.snapshot, required this.roster, this.onResize});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  /// Called with the field's size every time it is drawn, so the host's rules
  /// can move in it. A viewer has no rules and passes none.
  final ValueChanged<Size>? onResize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArenaHud(snapshot: snapshot, roster: roster, oneLine: constraints.maxHeight < ArenaHud.oneLineBelow),
        Expanded(
          child: ArenaField(snapshot: snapshot, roster: roster, onResize: onResize),
        ),
      ],
    ),
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
/// only (S8). On a short box ([oneLine]) everything goes in one Wrap instead
/// of a row per player, so the whole field still fits a phone (m12-phone-
/// layout §4).
class ArenaHud extends StatelessWidget {
  const ArenaHud({super.key, required this.snapshot, required this.roster, this.oneLine = false});

  /// The box height, in px, below which the bar folds to one line: landscape
  /// phones are 375–393 high and the TV and tablets 540 and up, so a box
  /// shorter than the phones' tallest is one where the field needs the room
  /// more than the bar does (m12-phone-layout §4).
  static const oneLineBelow = 480.0;

  /// The bar's padding in px: roomy on a tall box, and tight in the one-line
  /// form so its runs share a phone's height with the field.
  static const _pad = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const _oneLinePad = EdgeInsets.symmetric(horizontal: 12, vertical: 2);

  /// The gap between the bar's items in px, and between the round's texts.
  static const _itemGap = 24.0;
  static const _oneLineItemGap = 12.0;
  static const _runGap = 4.0;

  /// A player's counters: the gap between them in px, the gap above its row,
  /// and its colour dot's size and gap from the name.
  static const _counterGap = 20.0;
  static const _oneLineCounterGap = 10.0;
  static const _counterRunGap = 2.0;
  static const _dot = 14.0;
  static const _oneLineDot = 10.0;
  static const _dotGap = 6.0;
  static const _oneLineDotGap = 4.0;

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  /// Everything in one Wrap rather than the round above each player.
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byNumber = roster.entries.toList()..sort((a, b) => a.value.number.compareTo(b.value.number));
    final items = <Widget>[
      _RoundRow(snapshot: snapshot, roster: roster, oneLine: oneLine),
      for (final MapEntry(key: id, value: player) in byNumber)
        if (snapshot.player(id) case final p?) _PlayerRow(id: id, player: player, view: p, oneLine: oneLine),
    ];
    return Container(
      color: scheme.surfaceContainer,
      padding: oneLine ? _oneLinePad : _pad,
      child: oneLine
          ? Wrap(
              spacing: _oneLineItemGap,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: items,
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }
}

/// The round, its clock and the best round: in the one-line bar's small text,
/// so the runs share a phone's height with the field.
class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.snapshot, required this.roster, required this.oneLine});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = oneLine ? text.bodySmall : text.titleMedium;
    final tabular = style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final best = snapshot.bestTimeS;
    final bestId = snapshot.bestId;
    final bestBy = roster.length > 1 && bestId != null ? roster[bestId]?.number : null;
    return Wrap(
      spacing: oneLine ? ArenaHud._oneLineItemGap : ArenaHud._itemGap,
      runSpacing: oneLine ? 0 : ArenaHud._runGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Round ${snapshot.round}', style: style),
        Text('${snapshot.roundTimeS.toStringAsFixed(1)} s', key: const Key('roundTime'), style: tabular),
        Text(
          'Best ${best == null ? '–' : '${best.toStringAsFixed(1)} s${bestBy == null ? '' : ' (P$bestBy)'}'}',
          style: tabular,
        ),
      ],
    );
  }
}

/// One player's counters in the bar: colour dot, number and name, wins, hits,
/// dashes and whether a dash is ready.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.id, required this.player, required this.view, required this.oneLine});

  final String id;
  final ({int number, String name}) player;
  final ArenaPlayerView view;
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = view;
    final small = (oneLine ? text.bodySmall : text.bodyMedium)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: EdgeInsets.only(top: oneLine ? 0 : ArenaHud._runGap),
      child: Wrap(
        key: Key('hud-$id'),
        spacing: oneLine ? ArenaHud._oneLineCounterGap : ArenaHud._counterGap,
        runSpacing: ArenaHud._counterRunGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: oneLine ? ArenaHud._oneLineDot : ArenaHud._dot,
                color: Color(playerColor(player.number)),
              ),
              SizedBox(width: oneLine ? ArenaHud._oneLineDotGap : ArenaHud._dotGap),
              Text('P${player.number} ${player.name}', style: oneLine ? small : text.titleSmall),
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
            style: small?.copyWith(color: p.cooldown == 0 ? Colors.greenAccent : scheme.onSurfaceVariant),
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
