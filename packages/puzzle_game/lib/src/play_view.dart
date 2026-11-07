import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'match.dart';
import 'puzzle.dart';
import 'puzzle_session.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'view.dart';

/// Plays one match through the game host (PRD v2 P3): every player on a side
/// drives a dot on their side's board. [PuzzleSession] runs the rules and
/// their effects (haptics, sounds by name, layouts, statuses, the report) and
/// sends frames to the phones showing the game (M12); this widget draws the
/// session's snapshot (S8).
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
    required this.random,
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

  /// Seeds the match when none is passed in: the host makes one and hands it
  /// over (S8), so the rules start from what they're given.
  final Random random;

  @override
  State<PuzzlePlayView> createState() => PuzzlePlayViewState();
}

class PuzzlePlayViewState extends State<PuzzlePlayView> with SingleTickerProviderStateMixin {
  late final PuzzleSession _session;
  late final Ticker _ticker = createTicker(_tick);

  /// The match the session runs. Tests look at it.
  PuzzleMatch get match => _session.match;

  /// The match as the rules left it, for tests.
  MatchSnapshot get snapshot => _session.current;

  @override
  void initState() {
    super.initState();
    _session = PuzzleSession(
      host: widget.host,
      puzzle: widget.puzzle,
      teams: widget.teams,
      random: widget.random,
      playtest: widget.settings,
      match: widget.match,
      onFinished: widget.onFinished,
    )..paused = widget.paused;
    _ticker.start();
  }

  @override
  void didUpdateWidget(PuzzlePlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session.paused = widget.paused;
  }

  @override
  void dispose() {
    _ticker.dispose();
    // A match that ran to its end is the view's end too: a phone drawing it
    // can say "Done!" and stop asking for frames (m12 §3).
    _session.dispose(finished: match.result != null);
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _session.advance(elapsed);
    if (widget.paused) return;
    setState(() {});
    // The frame was drawn: the inputs it carried are no longer waiting (S7).
    SchedulerBinding.instance.addPostFrameCallback((_) => _session.drawn());
  }

  @override
  Widget build(BuildContext context) => MatchView(
    puzzle: widget.puzzle,
    snapshot: _session.current,
    timeLimitS: match.sides.first.game.settings.timeLimitS,
  );
}
