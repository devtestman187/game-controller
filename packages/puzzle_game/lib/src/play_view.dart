import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:protocol/protocol.dart';

import 'game.dart';
import 'match.dart';
import 'puzzle.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'view.dart';

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

/// For the demo director only; null in every normal run. Called once, right
/// after the match the view runs is created or received
/// (docs/demo-video-runbook.md 2.2).
void Function(PuzzleMatch match)? onPuzzleMatchCreated;

/// For the demo director only; null in every normal run. Called when the view
/// running that match goes away.
void Function(PuzzleMatch match)? onPuzzleMatchDisposed;

/// For the demo director only; null in every normal run. Every event the
/// running match produced this frame, with the side it came from: pickup,
/// snap, wrong, help, finished, time up. The director mirrors them into the
/// take's event log (docs/demo-video-runbook.md 2.3), so the log says what the
/// game did rather than what a script guessed.
void Function(PuzzleSide side, PuzzleEvent event)? onPuzzleMatchEvent;

/// Plays one match through the game host (PRD v2 P3): every player on a
/// side drives a dot on their side's board, events become haptics and
/// sounds by name (S5), each phone shows the puzzle's button labels and a
/// status panel with the held piece and the time left (P5, P6), and the
/// match is reported for analytics. The rules ([PuzzleMatch]) never draw;
/// this widget hands their snapshot to [MatchView] (S8).
///
/// The phones' buttons are set while the match runs. Once it's over, or
/// while it's [paused], they belong to the host again (the TV's menus), so
/// this widget doesn't reset them when it goes.
class PuzzlePlayView extends StatefulWidget {
  const PuzzlePlayView({
    super.key,
    required this.host,
    required this.puzzle,
    required this.settings,
    required this.teams,
    this.paused = false,
    this.onFinished,
    this.match,
  });

  final GameHost host;
  final Puzzle puzzle;

  /// Read every frame, so playtest changes count at once.
  final PuzzleSettings Function() settings;

  /// Each player's side, from the join screen. Anyone else watches.
  final Map<String, PuzzleSide> teams;

  /// Nothing moves and the clock stops (the pause menu is open).
  final bool paused;

  /// The match ended: a side finished, or time ran out.
  final void Function(MatchResult result)? onFinished;

  /// The match to run. Tests pass one in.
  final PuzzleMatch? match;

  @override
  State<PuzzlePlayView> createState() => PuzzlePlayViewState();
}

class PuzzlePlayViewState extends State<PuzzlePlayView> with SingleTickerProviderStateMixin {
  late final PuzzleMatch match =
      widget.match ?? PuzzleMatch(widget.puzzle, teams: widget.teams, settings: widget.settings());
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  late MatchSnapshot _snapshot = match.snapshot();
  final _withLayout = <String>{};
  final _withStatus = <String>{};
  final _arrived = <String, int>{};
  bool _reported = false;
  int _frames = 0;
  int _late = 0;

  MatchSnapshot get snapshot => _snapshot;

  @override
  void initState() {
    super.initState();
    onPuzzleMatchCreated?.call(match);
    _record(
      'round_start',
      data: {
        'puzzle': widget.puzzle.id,
        'level': widget.puzzle.level.name,
        'format': match.format.label,
        'players': match.teams.length,
      },
    );
    _ticker.start();
  }

  @override
  void didUpdateWidget(PuzzlePlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Back from the pause menu: the phones get the puzzle's buttons again.
    if (oldWidget.paused && !widget.paused) _withLayout.clear();
  }

  @override
  void dispose() {
    onPuzzleMatchDisposed?.call(match);
    _ticker.dispose();
    for (final id in _withStatus) {
      widget.host.setStatus(id, StatusMessage.hidden());
    }
    super.dispose();
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      widget.host.record(GameRecord(game: puzzleGameName, name: name, playerId: playerId, data: data));

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (widget.paused) return;
    final host = widget.host;
    match.settings = widget.settings();
    final players = host.players;

    // Players get the puzzle's buttons (or nothing to press, if they're only
    // watching) until it's over.
    if (match.result == null) {
      for (final p in players) {
        if (_withLayout.add(p.id)) {
          host.setLayout(p.id, match.teams.containsKey(p.id) ? puzzleLayout : puzzleWatchLayout);
        }
      }
    }
    _withLayout.removeWhere((id) => !players.any((p) => p.id == id));

    final fresh = <String, int>{};
    for (final p in players) {
      final at = host.inputArrivedAtMs(p.id);
      if (at != null && at != _arrived[p.id]) fresh[p.id] = at;
    }
    _arrived
      ..removeWhere((id, _) => !players.any((p) => p.id == id))
      ..addAll(fresh);
    if (players.isNotEmpty) {
      _frames++;
      if (dt > 0.025 && _frames > 1) _late++;
    }

    final events = match.update(
      dt,
      {for (final p in players) p.id: host.gamepad(p.id)},
      numbers: {for (final p in players) p.id: p.number},
    );
    final sounds = <String>{};
    for (final e in events) {
      onPuzzleMatchEvent?.call(e.side, e.event);
      _onEvent(e.side, e.event, players, sounds);
    }
    if (match.result != null && !_reported) _report(players, sounds);
    for (final s in sounds) {
      host.playSound(s);
    }
    for (final p in players) {
      host.setStatus(p.id, _statusFor(p.id));
      _withStatus.add(p.id);
    }
    setState(() => _snapshot = match.snapshot());

    final stalled = dt > 0.1;
    if (fresh.isNotEmpty && !stalled) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final now = host.nowMs;
        for (final MapEntry(key: id, value: at) in fresh.entries) {
          host.reportStage(id, LatencyStage.receivedToDrawn, now - at);
        }
      });
    }
  }

  /// The players on a side who are here now.
  List<GamePlayer> _onSide(PuzzleSide side, List<GamePlayer> players) => [
    for (final p in players)
      if (match.teams.containsKey(p.id) && (!match.format.split || match.teams[p.id] == side)) p,
  ];

  void _haptic(String to, HapticEvent event, {double intensity = 1}) =>
      widget.host.haptic(to, HapticEventMessage(event: event, intensity: intensity));

  /// Each sound plays once a frame, even when both sides tick together.
  void _onEvent(PuzzleSide side, PuzzleEvent e, List<GamePlayer> players, Set<String> sounds) {
    final id = e.playerId;
    switch (e.kind) {
      case PuzzleEventKind.pickup:
        sounds.add('pickup');
      case PuzzleEventKind.snap:
        _haptic(id!, HapticEvent.snap);
        sounds.add('snap');
        _record('snap', playerId: id, data: e.data);
      case PuzzleEventKind.wrong:
        _haptic(id!, HapticEvent.wrong);
        sounds.add('wrong');
        _record('wrong_drop', playerId: id, data: e.data);
      case PuzzleEventKind.dropReady:
        _haptic(id!, HapticEvent.dropReady, intensity: 0.7);
      case PuzzleEventKind.help:
        // The teammate is called; the call is the carrier's.
        _haptic(id!, HapticEvent.help);
        sounds.add('help');
        if (e.data['from'] case final String from) _record('help_call', playerId: from);
      case PuzzleEventKind.tick:
        for (final p in _onSide(side, players)) {
          _haptic(p.id, HapticEvent.tick, intensity: 0.6);
        }
        sounds.add('tick');
      case PuzzleEventKind.timeUp:
        sounds.add('time_up');
      case PuzzleEventKind.finished:
        sounds.add('success');
    }
  }

  /// The result and each player's puzzle metrics, for analytics, and the
  /// success haptic for the winners.
  void _report(List<GamePlayer> players, Set<String> sounds) {
    _reported = true;
    final result = match.result!;
    final winners = <String>[];
    for (final s in match.sides) {
      final outcome = result.outcomeFor(s.side);
      final sideResult = result.sides[s.side]!;
      for (final p in s.game.players) {
        if (outcome == 'win') winners.add(p.id);
        _record(
          'player_result',
          playerId: p.id,
          data: {
            'pickups': p.pickups,
            'snaps': p.snaps,
            'wrongDrops': p.wrongDrops,
            'rotatingS': (p.rotatingS * 10).round() / 10,
            'overshoots': p.overshoots,
            'placed': sideResult.placed,
            'completionS': ?sideResult.timeS,
            if (s.game.team) ...{
              'helpCalls': p.helpCalls,
              'soloBigCarries': p.soloBigCarries,
              'soloBigS': (p.soloBigS * 10).round() / 10,
            },
            'win': outcome == 'win' ? 1 : 0,
            if (result.format.split) 'draw': outcome == 'draw' ? 1 : 0,
          },
        );
      }
    }
    for (final id in winners) {
      _haptic(id, HapticEvent.success);
    }
    if (winners.isNotEmpty) sounds.add('success');
    final first = match.sides.first.game;
    _record(
      'round_end',
      data: {
        'timeS': first.finishTimeS ?? first.elapsedS,
        'puzzle': widget.puzzle.id,
        'format': result.format.label,
        'modes': {
          for (final p in players)
            if (match.teams.containsKey(p.id)) p.id: widget.host.gamepad(p.id).mode.name,
        },
        'winners': winners,
        if (result.draw) 'draw': true,
      },
    );
    _record('frames', data: {'drawn': _frames, 'late': _late});
    widget.onFinished?.call(result);
  }

  /// The phone's panel: the held piece turning as it turns, and the time.
  StatusMessage _statusFor(String id) {
    final game = match.gameFor(id);
    if (game == null) return StatusMessage(text: 'Watching');
    final limit = game.settings.timeLimitS;
    final progress = limit == 0 ? null : game.timeLeftS / limit;
    final warning = game.timeLeftS < game.settings.warningS;
    final left = game.timeLeftS.ceil();
    final result = match.result;
    final side = match.sideOf(id)!;
    final text = result == null
        ? '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left'
        : !result.format.split
        ? (result.sides.values.first.finished ? 'Done!' : 'Time\'s up')
        : switch (result.outcomeFor(side)) {
            'win' => 'You won!',
            'loss' => 'They won',
            _ => 'Draw',
          };
    final held = game.player(id)?.held;
    if (held == null) return StatusMessage(text: text, progress: progress, warning: warning);
    final spec = widget.puzzle.pieces[held];
    final r = spec.shape.radius;
    final shape = spec.shape.circle
        ? StatusShape.circle(color: spec.color)
        : StatusShape.polygon(
            [for (final pt in spec.shape.points) (pt.dx / r, pt.dy / r)],
            color: spec.color,
            angle: game.pieces[held].angle,
          );
    return StatusMessage(text: text, shape: shape, progress: progress, warning: warning);
  }

  @override
  Widget build(BuildContext context) =>
      MatchView(puzzle: widget.puzzle, snapshot: _snapshot, timeLimitS: match.sides.first.game.settings.timeLimitS);
}
