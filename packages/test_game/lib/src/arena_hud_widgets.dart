import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import 'arena.dart';
import 'arena_coin_icon_widgets.dart';
import 'arena_mode.dart';
import 'arena_robo.dart';
import 'arena_roster.dart';
import 'arena_session.dart';
import 'arena_snapshot.dart';

/// What the bar says when a player's dash has cooled down: in the pill on a
/// tall box, in ink text on a phone's one-line bar. The dash's name comes from
/// the phone's A label, so the two always say the same word.
const _dashReady = '$arenaDashLabel ready (A)';

/// The ink edge round the dash-ready dot.
const _dotEdge = 1.5;

/// The most of the bar's width one player's name may take in a Bumper Round,
/// in shares (M14 b2): four names, their coin counts and their dashes must fit
/// a phone's bar, so a longer name is cut with an ellipsis and the count never
/// leaves (Claude's design).
const _bumperNameShare = 0.24;

/// The bar over the field: the round, its clock, the best round, and a row of
/// counters for each player in the [roster]. It draws from an [ArenaSnapshot]
/// only (S8). On a short box ([oneLine]) everything goes in one Wrap instead
/// of a row per player, so the whole field still fits a phone (m12-phone-
/// layout §4).
///
/// In a Bumper Round the bar shows what that round is played for (M14 b2):
/// each player's coins before the dash, and the clock as the time left; the
/// race's wins, hits and dashes stay out of it and live in the results and the
/// stats. The race's bar is as it has always been.
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
  /// and its colour dot's size and gap from the name. The coin's picture is a
  /// little bigger than the dot, so it reads as a coin (M14 b2).
  static const _counterGap = 20.0;
  static const _oneLineCounterGap = 10.0;
  static const _counterRunGap = 2.0;
  static const _dot = 14.0;
  static const _oneLineDot = 10.0;
  static const _dotGap = 6.0;
  static const _oneLineDotGap = 4.0;
  static const _coin = 20.0;
  static const _oneLineCoin = 15.0;

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;

  /// Everything in one Wrap rather than the round above each player.
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final byNumber = roster.entries.toList()..sort((a, b) => a.value.number.compareTo(b.value.number));
    final bumper = snapshot.mode == ArenaMode.bumper;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        color: look.colors.paper,
        foregroundDecoration: _edge(look),
        padding: oneLine ? _oneLinePad : _pad,
        child: oneLine
            ? Wrap(
                spacing: _oneLineItemGap,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _items(byNumber, bumper, constraints.maxWidth),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _items(byNumber, bumper, constraints.maxWidth),
              ),
      ),
    );
  }

  /// The paper strip of the look, with its ink line under it drawn as a
  /// foreground border so it takes no height from the field: a phone's bar
  /// height is pinned (m12-phone-layout §4).
  BoxDecoration _edge(ToyLook look) => BoxDecoration(
    border: Border(
      bottom: BorderSide(color: look.colors.ink, width: look.sizes.outlineWidth),
    ),
  );

  /// The round's run, then a run per player. In a Bumper Round a name may take
  /// no more than [_bumperNameShare] of the bar, so every count fits a phone.
  List<Widget> _items(List<MapEntry<String, ({int number, String name})>> byNumber, bool bumper, double width) => [
    _RoundRow(snapshot: snapshot, roster: roster, oneLine: oneLine),
    for (final MapEntry(key: id, value: player) in byNumber)
      if (snapshot.player(id) case final p?)
        _PlayerRow(
          id: id,
          player: player,
          view: p,
          oneLine: oneLine,
          bumper: bumper,
          nameMaxWidth: bumper ? width * _bumperNameShare : null,
        ),
  ];
}

/// The round, its clock and the best round: in the one-line bar's small text,
/// so the runs share a phone's height with the field. A round with a clock of
/// its own — the Bumper Round — shows the time left on it (M14 b2); the race
/// shows the time it has run.
class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.snapshot, required this.roster, required this.oneLine});

  final ArenaSnapshot snapshot;
  final ArenaRoster roster;
  final bool oneLine;

  /// The clock's text: the time left where the round has a limit, else the
  /// time run, both to a tenth of a second.
  String get _clock => switch (snapshot.timeLeftMs) {
    final leftMs? => '${(leftMs / Duration.millisecondsPerSecond).toStringAsFixed(1)} s',
    null => '${snapshot.roundTimeS.toStringAsFixed(1)} s',
  };

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final text = Theme.of(context).textTheme;
    final style = (oneLine ? text.bodySmall : text.titleMedium)?.copyWith(color: look.colors.ink);
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
        Text(_clock, key: const Key('roundTime'), style: tabular),
        Text(
          'Best ${best == null ? '–' : '${best.toStringAsFixed(1)} s${bestBy == null ? '' : ' (P$bestBy)'}'}',
          style: tabular,
        ),
      ],
    );
  }
}

/// One player's counters in the bar: colour dot, number and name, then the
/// coins it holds in a Bumper Round or, in the race, its wins, hits and dashes;
/// and whether its dash is ready.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.id,
    required this.player,
    required this.view,
    required this.oneLine,
    required this.bumper,
    this.nameMaxWidth,
  });

  final String id;
  final ({int number, String name}) player;
  final ArenaPlayerView view;
  final bool oneLine;
  final bool bumper;

  /// The widest the name may be, in px, or null to take what it needs: a
  /// Bumper Round's bar caps it so four counts still fit a phone.
  final double? nameMaxWidth;

  @override
  Widget build(BuildContext context) {
    final colours = ToyLookScope.of(context).colors;
    final text = Theme.of(context).textTheme;
    final small = (oneLine ? text.bodySmall : text.bodyMedium)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colours.ink,
    );
    return Padding(
      padding: EdgeInsets.only(top: oneLine ? 0 : ArenaHud._runGap),
      child: Wrap(
        key: Key('hud-$id'),
        spacing: oneLine ? ArenaHud._oneLineCounterGap : ArenaHud._counterGap,
        runSpacing: ArenaHud._counterRunGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _name(colours, text, small),
          if (bumper)
            _coins(small)
          else ...[
            Text('Wins ${view.wins}', key: Key('wins-$id'), style: small),
            Text('Hits ${view.hits}', key: Key('hits-$id'), style: small),
            Text(
              'Dashes ${view.dashes}${view.failedDashes == 0 ? '' : ' (${view.failedDashes} too soon)'}',
              key: Key('dashes-$id'),
              style: small,
            ),
          ],
          _dash(colours, small),
        ],
      ),
    );
  }

  /// The coins this player holds, as the round gives them (M14 b2): the look's
  /// coin, then the count, so a pick-up and a drop read at a glance.
  Widget _coins(TextStyle? small) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ArenaCoinIcon(key: Key('coin-$id'), size: oneLine ? ArenaHud._oneLineCoin : ArenaHud._coin),
      SizedBox(width: oneLine ? ArenaHud._oneLineDotGap : ArenaHud._dotGap),
      Text('${view.coins}', key: Key('coins-$id'), style: small),
    ],
  );

  /// The player's colour dot and its number and name: small in the one-line
  /// bar, and a title on a tall box. Robo has no number to wear (party-night
  /// §7a): its dot is the robot's head and its name is its own. A name wider
  /// than [nameMaxWidth] is cut with an ellipsis, never the count.
  Widget _name(ToyColors colours, TextTheme text, TextStyle? small) {
    final robo = id == roboPlayerId;
    final width = nameMaxWidth;
    final name = Text(
      robo ? roboName : 'P${player.number} ${player.name}',
      style: oneLine ? small : text.titleSmall?.copyWith(color: colours.ink),
      maxLines: width == null ? null : 1,
      overflow: width == null ? null : TextOverflow.ellipsis,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          robo ? Icons.smart_toy : Icons.circle,
          size: oneLine ? ArenaHud._oneLineDot : ArenaHud._dot,
          color: colours.player(player.number),
        ),
        SizedBox(width: oneLine ? ArenaHud._oneLineDotGap : ArenaHud._dotGap),
        if (width == null)
          name
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: name,
          ),
      ],
    );
  }

  /// Whether the dash is ready: a `good` dot with the ink edge beside ink
  /// words, as the TV home's statuses are. Text is never `good`, and a pill
  /// would grow the bar (Claude's step 5 review: 88 to 107 px).
  Widget _dash(ToyColors colours, TextStyle? small) {
    final ready = view.cooldown == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ready) ...[
          SizedBox.square(
            dimension: oneLine ? ArenaHud._oneLineDot : ArenaHud._dot,
            child: DecoratedBox(
              key: Key('dashReady-$id'),
              decoration: ShapeDecoration(
                color: colours.good,
                shape: CircleBorder(
                  side: BorderSide(color: colours.ink, width: _dotEdge),
                ),
              ),
            ),
          ),
          SizedBox(width: oneLine ? ArenaHud._oneLineDotGap : ArenaHud._dotGap),
        ],
        Text(
          ready ? _dashReady : 'Dash in ${(view.cooldown * ArenaGame.dashCooldownS).toStringAsFixed(1)} s',
          style: small?.copyWith(color: ready ? colours.ink : colours.inkSoft),
        ),
      ],
    );
  }
}
