import 'dart:math';

import 'package:connection/connection.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'match.dart';
import 'puzzle.dart';
import 'puzzle_events.dart';
import 'puzzle_module.dart';
import 'puzzle_report.dart';
import 'puzzle_status.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'split_layout.dart';

/// The game's name in analytics records.
const puzzleGameName = 'puzzle';

/// What the puzzle does with each button, shown on the phone (PRD v2 P5).
/// Start pauses (M11); B, LB, RB and Select aren't used.
final puzzleLayout = GameLayoutMessage(
  labels: {
    ControllerButton.a: 'Pick up',
    ControllerButton.x: 'Rotate ⟳',
    ControllerButton.y: 'Rotate ⟲',
    ControllerButton.start: 'Pause',
  },
  hidden: {ControllerButton.b, ControllerButton.lb, ControllerButton.rb, ControllerButton.select},
);

/// For a player who didn't join a side: nothing to press until the next
/// game.
final puzzleWatchLayout = GameLayoutMessage(
  hidden: {
    ControllerButton.a,
    ControllerButton.b,
    ControllerButton.x,
    ControllerButton.y,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// Shape Race on the host (m12 §3): runs [PuzzleMatch] in fixed steps, gives
/// each player the puzzle's buttons and a status panel with the held piece and
/// the time left (P5, P6), buzzes and plays its events, and reports the match
/// once it ends (PRD v2 M10). The view only draws [current] (S8).
class PuzzleSession extends GameSession {
  /// [settings] is how the host runs the round (m12 §3): the frame rate it
  /// sends frames to the phones at, which the round records. Null takes this
  /// build's start option ([HostingSettings.fromEnvironment]).
  PuzzleSession({
    required GameHost host,
    required Puzzle puzzle,
    required Map<String, PuzzleSide> teams,
    required Random random,
    required PuzzleSettings Function() playtest,
    LayoutTarget target = LayoutTarget.screen,
    HostingSettings? settings,
    PuzzleMatch? match,
    void Function(MatchResult result)? onFinished,
  }) : this._(
         host: host,
         match: match ?? PuzzleMatch(puzzle, teams: teams, settings: playtest(), random: random, target: target),
         playtest: playtest,
         settings: settings,
         onFinished: onFinished,
       );

  PuzzleSession._({required super.host, required this.match, required this.playtest, super.settings, this.onFinished})
    : super(module: shapeRaceModule, setup: shapeRaceSetup(match)) {
    _record('round_start', data: _roundStartData(match, settings));
  }

  /// The rules. Tests pass one in, to look at the match itself.
  final PuzzleMatch match;

  /// The playtest settings, read every step so a change counts at once.
  final PuzzleSettings Function() playtest;

  /// The match ended: a side finished, or time ran out.
  final void Function(MatchResult result)? onFinished;

  /// The players given the puzzle's buttons, so they get them once.
  final _withLayout = <String>{};

  /// The players given a status panel, so dispose can hide it again.
  final _withStatus = <String>{};

  /// The report is written on the step the match ends, and only there (R3).
  bool _reported = false;

  late final _effects = PuzzleEffects(host: host, match: match, game: puzzleGameName, sound: sound);
  late final _report = PuzzleReport(host: host, match: match, game: puzzleGameName, sound: sound);

  /// The match as the rules left it.
  @override
  MatchSnapshot get current => match.snapshot();

  @override
  MatchSnapshot snapshot() => match.snapshot();

  /// Back from the pause menu: the players get the puzzle's buttons again.
  @override
  void resumed() => _withLayout.clear();

  @override
  void step(double dt) {
    match.settings = playtest();
    final here = players;
    final ids = {for (final p in here) p.id};

    // The players get the puzzle's buttons (or nothing to press, if they're
    // only watching) until the match is over.
    if (match.result == null) {
      for (final p in here) {
        if (_withLayout.add(p.id)) {
          host.setLayout(p.id, match.teams.containsKey(p.id) ? puzzleLayout : puzzleWatchLayout);
        }
      }
    }
    _withLayout.removeWhere((id) => !ids.contains(id));

    final events = match.update(
      dt,
      {for (final p in here) p.id: input(p.id)},
      numbers: {for (final p in here) p.id: p.number},
    );
    for (final e in events) {
      _effects.apply(e.side, e.event, here);
    }
    final result = match.result;
    if (result != null && !_reported) {
      _reported = true;
      _report.write(result, players: here, frames: frameCount, late: lateFrameCount);
      onFinished?.call(result);
    }
    for (final p in here) {
      host.setStatus(p.id, puzzleStatusFor(match, match.puzzle, p.id));
      _withStatus.add(p.id);
    }
  }

  /// Ends the view (`finished` when the match ran to its end, else `quit`) and
  /// hides the status panels it showed: they belong to the game (P6).
  @override
  void dispose({bool finished = false}) {
    if (isDisposed) return;
    _hideStatuses();
    super.dispose(finished: finished);
  }

  /// The host lost the match (m12 §2.10): `round_end` says why, without a
  /// winner, unless it had already played to its end and reported itself.
  /// Then the view ends `abandoned`, as [GameSession.abandon] does.
  @override
  void abandon() {
    if (isDisposed) return;
    if (match.result == null) _record('round_end', data: {'reason': ViewEndReason.abandoned});
    _hideStatuses();
    super.abandon();
  }

  void _hideStatuses() {
    for (final id in _withStatus) {
      host.setStatus(id, StatusMessage.hidden());
    }
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      host.record(GameRecord(game: puzzleGameName, name: name, playerId: playerId, data: data));
}

/// The `round_start` record's data: the match's setup and the rate its frames
/// go out at (m12 §0.4).
Map<String, Object?> _roundStartData(PuzzleMatch match, HostingSettings settings) => {
  'puzzle': match.puzzle.id,
  'level': match.puzzle.level.name,
  'format': match.format.label,
  'players': match.teams.length,
  'hz': settings.frameRateHz,
};
