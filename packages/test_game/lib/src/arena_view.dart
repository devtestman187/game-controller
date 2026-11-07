import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'arena.dart';
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
  const ArenaView({super.key, required this.host, required this.onEvent, this.game, this.paused = false});

  final GameHost host;
  final void Function(GameEvent event) onEvent;

  /// The game to show. Tests pass one in to inspect it.
  final ArenaGame? game;

  /// Nothing moves (the pause menu is open).
  final bool paused;

  @override
  State<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends State<ArenaView> with SingleTickerProviderStateMixin {
  late final ArenaSession _session;
  late final Ticker _ticker = createTicker(_tick);
  late ArenaSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _session = ArenaSession(host: widget.host, game: widget.game, onEvent: widget.onEvent)..paused = widget.paused;
    _snapshot = _session.current;
    _ticker.start();
  }

  @override
  void didUpdateWidget(ArenaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session.paused = widget.paused;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _session.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _session.advance(elapsed);
    if (widget.paused) return;
    setState(() => _snapshot = _session.current);
    // The frame was drawn: the inputs it carried are no longer waiting (S7).
    SchedulerBinding.instance.addPostFrameCallback((_) => _session.drawn());
  }

  @override
  Widget build(BuildContext context) =>
      ArenaBoard(snapshot: _snapshot, roster: arenaRosterOf(widget.host.players), onResize: _session.resize);
}
