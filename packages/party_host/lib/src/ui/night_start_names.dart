import 'dart:math' show min;

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:toy_look/toy_look.dart';

import '../text/night_text.dart';
import 'award_tile.dart';
import 'player_badge.dart';

/// The most players whose names stand on one line of the night's start card
/// (DESIGN section 4): four 10-character names get 160 px each on the 912 px
/// stage, wider than the 124 px the longest nickname takes.
const nightStartNamesOneLineMax = 4;

/// How many players stand on a line when there are more than
/// [nightStartNamesOneLineMax]: three, so each name gets a 304 px column and
/// 236 px of it for the name itself, the 113-124 px nicknames the S9m report
/// measured drawn whole.
const nightStartNamesSplitColumns = 3;

/// The room a player's badge and name keep after them, in frame px: the look's
/// own step, so two names on a line never run together.
const nightStartNameGapPx = ToySizes.space12;

/// The players who joined tonight, each one's badge and name (design section
/// 4): on one line while four or fewer are in, and on two lines of three when
/// a night holds five or six, so every nickname is drawn whole rather than
/// ellipsised into a sixth of the stage.
class NightStartNames extends StatelessWidget {
  const NightStartNames({super.key, required this.players, this.oldAppIds = const {}});

  /// The players the host has joined, in their numbers' order.
  final List<GamePlayer> players;

  /// The ids of the players whose phone is an old app, which plays with simple
  /// buttons (M17 y0e): one line under the names says so, once.
  final Set<String> oldAppIds;

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    final oldApps = [
      for (final player in players)
        if (oldAppIds.contains(player.id)) player,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, line) in lines.indexed) ...[
          if (i > 0) const SizedBox(height: ToySizes.space8),
          _NamesLine(players: line),
        ],
        if (oldApps.isNotEmpty) ...[const SizedBox(height: ToySizes.space8), _OldAppLine(oldApps: oldApps)],
      ],
    );
  }

  /// The players split into the card's lines: all of them while there are
  /// [nightStartNamesOneLineMax] at most, and [nightStartNamesSplitColumns] to
  /// a line after that, so a fifth and sixth name never squeeze the others.
  List<List<GamePlayer>> _lines() {
    if (players.length <= nightStartNamesOneLineMax) return [players];
    return [
      for (var start = 0; start < players.length; start += nightStartNamesSplitColumns)
        players.sublist(start, min(start + nightStartNamesSplitColumns, players.length)),
    ];
  }
}

/// One line of the joined players: each badge and name in an equal share of the
/// line's width, the name ellipsised only if a slot could not hold it.
class _NamesLine extends StatelessWidget {
  const _NamesLine({required this.players});

  final List<GamePlayer> players;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final style = ToyType.frame.body.copyWith(color: colors.onBackground);
    return Row(
      children: [
        for (final player in players)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: nightStartNameGapPx),
              child: Row(
                children: [
                  PlayerBadge(number: player.number, size: awardTileDiscPx, character: player.character),
                  const SizedBox(width: ToySizes.space8),
                  Flexible(
                    child: Text(
                      NightText.playerName(player.nickname, player.number),
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The one line that says which phones are old apps: the player's own sentence
/// for one, and a count for two or more, so the card never grows a line per
/// player (M17 y0e). Ellipsised if the TV's width cannot hold it.
class _OldAppLine extends StatelessWidget {
  const _OldAppLine({required this.oldApps});

  /// The players whose phones are old apps; never empty.
  final List<GamePlayer> oldApps;

  @override
  Widget build(BuildContext context) {
    final colors = ToyLookScope.of(context).colors;
    final style = ToyType.frame.body.copyWith(color: colors.onBackground);
    final only = oldApps.length == 1 ? oldApps.single : null;
    final text = only == null
        ? NightText.oldAppCount(oldApps.length)
        : NightText.oldApp(NightText.playerName(only.nickname, only.number));
    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
