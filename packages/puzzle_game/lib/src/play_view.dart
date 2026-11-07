import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_kit/game_kit.dart';

import 'camera.dart';
import 'match.dart';
import 'puzzle.dart';
import 'puzzle_session.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'split_layout.dart';
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
    this.target = LayoutTarget.screen,
    this.hosting,
    this.camera = const PuzzleCamera.whole(),
    this.paused = false,
    this.onFinished,
    this.match,
    this.abandon,
  });

  final GameHost host;
  final Puzzle puzzle;

  /// Read every frame, so playtest changes count at once.
  final PuzzleSettings Function() settings;

  /// Each player's side, from the join screen. Anyone else watches.
  final Map<String, PuzzleSide> teams;

  /// The world the match plays in, chosen by the host when the round starts
  /// (m12 §0.4): the split screen, or one side per phone.
  final LayoutTarget target;

  /// How the host runs the round (m12 §3): the frame rate it sends frames at,
  /// which the round records. Null takes this build's start option.
  final HostingSettings? hosting;

  /// What a phone's screen shows of a `phones` match (m12-phone-layout §3):
  /// the host's own side, or the whole match. The host app picks it from its
  /// own player and whether it has the room for both sides.
  final PuzzleCamera camera;

  /// Nothing moves and the clock stops (the pause menu is open).
  final bool paused;

  /// The match ended: a side finished, or time ran out.
  final void Function(MatchResult result)? onFinished;

  /// The match to run. Tests pass one in.
  final PuzzleMatch? match;

  /// Seeds the match when none is passed in: the host makes one and hands it
  /// over (S8), so the rules start from what they're given.
  final Random random;

  /// Fires when the host app lost the round (m12 §2.10): the match is
  /// abandoned, and the view ends `abandoned`.
  final Listenable? abandon;

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
      target: widget.target,
      settings: widget.hosting,
      match: widget.match,
      onFinished: widget.onFinished,
    )..paused = widget.paused;
    widget.abandon?.addListener(_abandoned);
    _ticker.start();
  }

  @override
  void didUpdateWidget(PuzzlePlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session.paused = widget.paused;
  }

  @override
  void dispose() {
    widget.abandon?.removeListener(_abandoned);
    _ticker.dispose();
    // A match that ran to its end is the view's end too: a phone drawing it
    // can say "Done!" and stop asking for frames (m12 §3).
    _session.dispose(finished: match.result != null);
    super.dispose();
  }

  void _abandoned() => _session.abandon();

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
    target: widget.target,
    camera: widget.camera,
  );
}
