import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:protocol/protocol.dart';

import 'game.dart';
import 'puzzle.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'view.dart';

/// The game's name in analytics records.
const puzzleGameName = 'puzzle';

/// What the puzzle does with each button, shown on the phone (PRD v2 P5).
/// B, LB, RB, Select and Start aren't used (pause comes in M11).
final puzzleLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'Pick up', ControllerButton.x: 'Rotate ⟳', ControllerButton.y: 'Rotate ⟲'},
  hidden: {
    ControllerButton.b,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// The buttons once the puzzle is over: the results' menu (Play again, Back)
/// is worked with the D-pad or left stick, A and B.
final puzzleResultsLayout = GameLayoutMessage(
  labels: {ControllerButton.a: 'OK', ControllerButton.b: 'Back'},
  hidden: {
    ControllerButton.x,
    ControllerButton.y,
    ControllerButton.lb,
    ControllerButton.rb,
    ControllerButton.select,
    ControllerButton.start,
  },
);

/// Plays one puzzle through the game host (PRD v2 P3): every player's
/// gamepad drives a dot, events become haptics and sounds by name (S5), each
/// phone shows the puzzle's button labels and a status panel with the held
/// piece and the time left (P5, P6), and the round is reported for
/// analytics. The rules ([PuzzleGame]) never draw; this widget hands their
/// snapshot to [PuzzleView] (S8).
class PuzzlePlayView extends StatefulWidget {
  const PuzzlePlayView({
    super.key,
    required this.host,
    required this.puzzle,
    required this.settings,
    this.onFinished,
    this.game,
  });

  final GameHost host;
  final Puzzle puzzle;

  /// Read every frame, so playtest changes count at once.
  final PuzzleSettings Function() settings;

  /// The round ended (finished or time-up).
  final void Function(PuzzleResult result)? onFinished;

  /// The game to run. Tests pass one in.
  final PuzzleGame? game;

  @override
  State<PuzzlePlayView> createState() => PuzzlePlayViewState();
}

class PuzzlePlayViewState extends State<PuzzlePlayView> with SingleTickerProviderStateMixin {
  late final PuzzleGame game = widget.game ?? PuzzleGame(widget.puzzle, settings: widget.settings());
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  late PuzzleSnapshot _snapshot = game.snapshot();
  final _withLayout = <String>{};
  final _arrived = <String, int>{};
  bool _reported = false;
  bool _resultsLayout = false;
  int _frames = 0;
  int _late = 0;

  PuzzleSnapshot get snapshot => _snapshot;

  @override
  void initState() {
    super.initState();
    _record('round_start', data: {'puzzle': widget.puzzle.id, 'level': widget.puzzle.level.name});
    _current = this;
    _ticker.start();
  }

  /// The newest puzzle on screen. After Play again the old one is disposed
  /// once the new one is already running, and must not undo its buttons.
  static PuzzlePlayViewState? _current;

  @override
  void dispose() {
    _ticker.dispose();
    // Every phone goes back to its usual buttons, and the panel goes,
    // unless another puzzle has already taken over.
    if (_current == this) {
      _current = null;
      for (final id in _withLayout) {
        widget.host.setLayout(id, GameLayoutMessage.standard());
        widget.host.setStatus(id, StatusMessage.hidden());
      }
    }
    super.dispose();
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      widget.host.record(GameRecord(game: puzzleGameName, name: name, playerId: playerId, data: data));

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final host = widget.host;
    game.settings = widget.settings();
    final players = host.players;

    // New players get the puzzle's buttons; once it's over, the results'.
    final over = game.result != null;
    for (final p in players) {
      if (_withLayout.add(p.id)) host.setLayout(p.id, over ? puzzleResultsLayout : puzzleLayout);
    }
    if (over && !_resultsLayout) {
      _resultsLayout = true;
      for (final id in _withLayout) {
        host.setLayout(id, puzzleResultsLayout);
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

    final events = game.update(
      dt,
      {for (final p in players) p.id: host.gamepad(p.id)},
      numbers: {for (final p in players) p.id: p.number},
    );
    for (final e in events) {
      _onEvent(e, players);
    }
    for (final p in players) {
      host.setStatus(p.id, _statusFor(p.id));
    }
    setState(() => _snapshot = game.snapshot());

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

  void _onEvent(PuzzleEvent e, List<GamePlayer> players) {
    final host = widget.host;
    final id = e.playerId;
    void haptic(String to, HapticEvent event, {double intensity = 1}) =>
        host.haptic(to, HapticEventMessage(event: event, intensity: intensity));
    switch (e.kind) {
      case PuzzleEventKind.pickup:
        host.playSound('pickup');
      case PuzzleEventKind.snap:
        haptic(id!, HapticEvent.snap);
        host.playSound('snap');
        _record('snap', playerId: id, data: e.data);
      case PuzzleEventKind.wrong:
        haptic(id!, HapticEvent.wrong);
        host.playSound('wrong');
        _record('wrong_drop', playerId: id, data: e.data);
      case PuzzleEventKind.dropReady:
        haptic(id!, HapticEvent.dropReady, intensity: 0.7);
      case PuzzleEventKind.tick:
        for (final p in players) {
          haptic(p.id, HapticEvent.tick, intensity: 0.6);
        }
        host.playSound('tick');
      case PuzzleEventKind.timeUp:
        host.playSound('time_up');
        _report(players);
      case PuzzleEventKind.finished:
        for (final p in players) {
          haptic(p.id, HapticEvent.success);
        }
        host.playSound('success');
        _report(players);
    }
  }

  /// The round's result and each player's puzzle metrics, for analytics.
  void _report(List<GamePlayer> players) {
    if (_reported) return;
    _reported = true;
    final result = game.result!;
    for (final p in game.players) {
      _record(
        'player_result',
        playerId: p.id,
        data: {
          'pickups': p.pickups,
          'snaps': p.snaps,
          'wrongDrops': p.wrongDrops,
          'rotatingS': (p.rotatingS * 10).round() / 10,
          'overshoots': p.overshoots,
        },
      );
    }
    _record(
      'round_end',
      data: {
        'timeS': result.timeS ?? widget.settings().timeLimitS.toDouble(),
        'finished': result.finished,
        'placed': result.placed,
        'total': result.total,
        'puzzle': widget.puzzle.id,
        'modes': {for (final p in players) p.id: widget.host.gamepad(p.id).mode.name},
        // In one-player puzzles a finish is a win.
        if (result.finished && players.length == 1) 'winner': players.single.id,
      },
    );
    _record('frames', data: {'drawn': _frames, 'late': _late});
    widget.onFinished?.call(result);
  }

  /// The phone's panel: the held piece turning as it turns, and the time.
  StatusMessage _statusFor(String id) {
    final p = game.player(id);
    final limit = game.settings.timeLimitS;
    final progress = limit == 0 ? null : game.timeLeftS / limit;
    final warning = game.timeLeftS < game.settings.warningS;
    final left = game.timeLeftS.ceil();
    final text = switch (game.phase) {
      PuzzlePhase.playing => '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left',
      PuzzlePhase.finished => 'Done!',
      PuzzlePhase.timeUp => 'Time\'s up',
    };
    final held = p?.held;
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
      PuzzleView(puzzle: widget.puzzle, snapshot: _snapshot, timeLimitS: game.settings.timeLimitS);
}
