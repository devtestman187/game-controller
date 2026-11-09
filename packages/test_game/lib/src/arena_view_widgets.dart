import 'dart:math';

import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena.dart';
import 'arena_hud_widgets.dart';
import 'arena_moments.dart';
import 'arena_painter.dart';
import 'arena_roster.dart';
import 'arena_snapshot.dart';

/// The look an arena drawn with no [ToyLookScope] above it draws in: Sunny, on
/// a phone, with the effects on. The apps put a scope above every screen;
/// `game_kit`'s frame tests mount a module's viewer on its own, and a board
/// drawn with no look at all would throw.
final defaultArenaLook = ToyLook.build(palette: ToyPalette.sunny, tv: false);

/// The arena as a view draws it: the counters bar over the field. The TV and a
/// phone draw the same box from the same snapshot and roster; on a short box
/// the bar folds to one line so the field keeps the room (m12-phone-layout
/// §4).
///
/// The whole board draws in the [ToyLookScope]'s look — or in
/// [defaultArenaLook] when it is drawn alone — because the bar's pill and the
/// winner's card read the scope themselves.
class ArenaBoard extends StatelessWidget {
  const ArenaBoard({super.key, required this.snapshot, required this.roster, this.onResize});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  /// Called with the field's size every time it is drawn, so the host's rules
  /// can move in it. A viewer has no rules and passes none.
  final ValueChanged<Size>? onResize;

  @override
  Widget build(BuildContext context) => ToyLookScope(
    look: context.dependOnInheritedWidgetOfExactType<ToyLookScope>()?.look ?? defaultArenaLook,
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaHud(snapshot: snapshot, roster: roster, oneLine: constraints.maxHeight < ArenaHud.oneLineBelow),
          Expanded(
            child: ArenaField(snapshot: snapshot, roster: roster, onResize: onResize),
          ),
        ],
      ),
    ),
  );
}

/// The field: fills the box it is given, draws [snapshot] and, while the round
/// is won, overlays the winner's banner.
///
/// It keeps an [ArenaMoments] so the marbles' eyes can look the way they last
/// moved (rule 3): the moments are fed every new snapshot and nothing about
/// them goes into a snapshot or the protocol.
class ArenaField extends StatefulWidget {
  const ArenaField({super.key, required this.snapshot, required this.roster, this.onResize});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;
  final ValueChanged<Size>? onResize;

  @override
  State<ArenaField> createState() => _ArenaFieldState();
}

class _ArenaFieldState extends State<ArenaField> {
  final _moments = ArenaMoments();

  @override
  void initState() {
    super.initState();
    _moments.observe(widget.snapshot);
  }

  @override
  void didUpdateWidget(ArenaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) _moments.observe(widget.snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final look = ToyLookScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.onResize?.call(constraints.biggest);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: const Key('arena'),
                painter: ArenaPainter(s, widget.roster, look: look, moments: _moments),
              ),
              if (s.phase == ArenaPhase.won) Center(child: _winnerBanner(s, look)),
            ],
          ),
        );
      },
    );
  }

  /// Who won and how soon the next round starts, headed in the winner's colour
  /// — or in `good` when no player won — as the look's card.
  Widget _winnerBanner(ArenaSnapshot s, ToyLook look) {
    final id = s.winnerId;
    final winner = id == null ? null : widget.roster[id];
    final timeS = (s.lastTimeS ?? 0).toStringAsFixed(1);
    final whoWon = widget.roster.length > 1 && winner != null;
    return ArenaBanner(
      whoWon ? 'P${winner.number} wins! $timeS s' : 'Goal! $timeS s',
      'Next round in ${max(0, s.breakLeftS).ceil()}…',
      color: winner == null ? look.colors.good : look.colors.player(winner.number),
    );
  }
}

/// The banner over the field between rounds: who won and how soon the next
/// round starts, on a card in the look with its header band in [color].
class ArenaBanner extends StatelessWidget {
  const ArenaBanner(this.title, this.subtitle, {super.key, required this.color});

  /// Who won, in the card's header band.
  final String title;

  /// How soon the next round starts, in ink under the band.
  final String subtitle;

  /// The band's fill: the winner's colour, or `good` when no player won.
  final Color color;

  @override
  Widget build(BuildContext context) => ToyCard(
    header: title,
    headerColor: color,
    child: Text(subtitle, textAlign: TextAlign.center),
  );
}
