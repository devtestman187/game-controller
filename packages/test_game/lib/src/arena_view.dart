import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_kit/game_kit.dart';

import 'arena.dart';
import 'arena_board_options.dart';
import 'arena_events.dart';
import 'arena_robo.dart';
import 'arena_roster.dart';
import 'arena_session.dart';
import 'arena_snapshot.dart';
import 'arena_view_widgets.dart';

/// Plays [ArenaGame] full size: the field fills the space it's given and
/// follows it when the window resizes. A bar on top shows the round, the
/// timer and each player's counters.
///
/// Everything comes from the [host] (PRD v2 P3): the players, their controls
/// (the standard gamepad, P4) and where analytics go. [ArenaSession] runs the
/// rules and their effects and sends frames to the phones showing the game
/// (M12); this widget draws the session's snapshot (S8) and tells the rules
/// the box they're in (S4). [onEvent] also gets every game event, for the host
/// app's log and debug overlay.
class ArenaView extends StatefulWidget {
  const ArenaView({
    super.key,
    required this.host,
    required this.onEvent,
    this.game,
    this.settings,
    this.roboLevel = RoboLevel.medium,
    this.round,
    this.rounds,
    this.roundTags = const [],
    this.paused = false,
    this.abandon,
    this.onClock,
    this.onFinished,
    this.showHud = true,
  });

  final GameHost host;
  final void Function(GameEvent event) onEvent;

  /// Whether the round strip (the counters bar) is drawn. A host hides it while
  /// its results show (M16 bugs3 B-036); its space stays, so the field does not
  /// move.
  final bool showHud;

  /// Robo's level, from the waiting card (party-night §7a): the session gives
  /// Robo a seat at it in a Bumper Round with one player.
  final RoboLevel roboLevel;

  /// This round's number from 1 and how many the match runs (M16 A2): a phone
  /// shows "Round N of M". Null when the host names no rounds.
  final int? round;
  final int? rounds;

  /// Tags the host adds to the round's summary (M14's "By game and feature"):
  /// a party night's round, `night_2of3`, which no game can know.
  final List<String> roundTags;

  /// Every frame of a round with a clock: the Bumper Round's time left, in ms,
  /// for the host's music (M14 design section 7, as Shape Race reports its
  /// clock). The race has none, so nothing is reported.
  final void Function(int timeLeftMs)? onClock;

  /// The Bumper Round's result, once its clock runs out (G9): the host shows
  /// its results card and records the round in a night. Called once.
  final void Function(RoundResult result)? onFinished;

  /// The game to show. Tests pass one in to inspect it.
  final ArenaGame? game;

  /// How the host runs the round (m12 §3): the frame rate it sends frames at.
  /// Null takes this build's start option.
  final HostingSettings? settings;

  /// Nothing moves (the pause menu is open).
  final bool paused;

  /// Fires when the host app lost the round (m12 §2.10): the session
  /// abandons its round, and the view ends `abandoned`.
  final Listenable? abandon;

  @override
  State<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends State<ArenaView> with SingleTickerProviderStateMixin {
  late final ArenaSession _session;
  late final Ticker _ticker = createTicker(_tick);
  late ArenaSnapshot _snapshot;

  /// Whether the round's result has been reported, so it is reported once.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _session = ArenaSession(
      host: widget.host,
      game: widget.game,
      settings: widget.settings,
      roboLevel: widget.roboLevel,
      round: widget.round,
      rounds: widget.rounds,
      roundTags: widget.roundTags,
      onEvent: widget.onEvent,
    )..paused = widget.paused;
    _snapshot = _session.current;
    widget.abandon?.addListener(_abandoned);
    _ticker.start();
  }

  @override
  void didUpdateWidget(ArenaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session
      ..paused = widget.paused
      ..roundTags = widget.roundTags;
  }

  @override
  void dispose() {
    widget.abandon?.removeListener(_abandoned);
    _ticker.dispose();
    _session.dispose();
    super.dispose();
  }

  void _abandoned() => _session.abandon();

  void _tick(Duration elapsed) {
    _session.advance(elapsed);
    if (widget.paused) return;
    setState(() => _snapshot = _session.current);
    // The frame was drawn: the inputs it carried are no longer waiting (S7).
    SchedulerBinding.instance.addPostFrameCallback((_) => _session.drawn());
    if (_snapshot.timeLeftMs case final left?) widget.onClock?.call(left);
    if (widget.onFinished case final finished? when !_finished) {
      if (_session.game.roundResult case final result?) {
        _finished = true;
        finished(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ArenaBoard(
    snapshot: _snapshot,
    roster: arenaRosterFor(_snapshot, arenaRosterOf(widget.host.players)),
    characters: arenaCharactersOf(widget.host.players),
    onResize: _session.resize,
    options: ArenaBoardOptions(showHud: widget.showHud, round: widget.round, rounds: widget.rounds),
  );
}
