import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_kit/game_kit.dart';
import 'package:toy_look/toy_look.dart';

import 'camera.dart';
import 'cat_moments.dart';
import 'match.dart';
import 'piece_moments.dart';
import 'piece_size.dart';
import 'puzzle.dart';
import 'puzzle_session.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'split_layout.dart';
import 'view.dart';
import 'worker_moments.dart';

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
    this.padRects = const [],
    this.pxPerMm = phonePxPerMm,
    this.paused = false,
    this.onFinished,
    this.onClock,
    this.match,
    this.abandon,
    this.round,
    this.rounds,
    this.roundTags = const [],
    this.characters = const {},
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

  /// Where the host app draws its pad over the game, in the box's px, and its
  /// px per millimetre: the same two things a joined phone's app passes its
  /// game, so the other side's mirror keeps clear of the thumb and its marks
  /// read (m12-opponent-mirror rules 7 and 8). A host that draws no pad — the
  /// TV, "Show on this device" — passes none.
  final List<Rect> padRects;
  final double pxPerMm;

  /// Nothing moves and the clock stops (the pause menu is open).
  final bool paused;

  /// The match ended: a side finished, or time ran out.
  final void Function(MatchResult result)? onFinished;

  /// Every frame: the round's clock, in the ms left on the side nearest its
  /// end (a race's two clocks, and the one that ends the round), and the
  /// puzzle's warning in seconds. The host's round music times its tempo by
  /// them (M13 design section 8, rule 3); it is no part of the game.
  final void Function(int timeLeftMs, int warningS)? onClock;

  /// The match to run. Tests pass one in.
  final PuzzleMatch? match;

  /// Seeds the match when none is passed in: the host makes one and hands it
  /// over (S8), so the rules start from what they're given.
  final Random random;

  /// Fires when the host app lost the round (m12 §2.10): the match is
  /// abandoned, and the view ends `abandoned`.
  final Listenable? abandon;

  /// This round's number from 1 and how many the match runs (M16 A2): a phone
  /// shows "Round N of M". Null when the host names no rounds.
  final int? round;
  final int? rounds;

  /// Tags the host adds to the round's summary (M14's "By game and feature"):
  /// a party night's round, `night_2of3`, which no game can know.
  final List<String> roundTags;

  /// Who each player is drawn as, by player number (M16 identity): the host's
  /// own players keep the character their phone chose, so the screen's workers
  /// wear it; a missing entry wears the default its number gives.
  final Map<int, ToyCharacter> characters;

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
    _session =
        PuzzleSession(
            host: widget.host,
            puzzle: widget.puzzle,
            teams: widget.teams,
            random: widget.random,
            playtest: widget.settings,
            target: widget.target,
            settings: widget.hosting,
            match: widget.match,
            round: widget.round,
            rounds: widget.rounds,
            onFinished: widget.onFinished,
          )
          ..paused = widget.paused
          ..roundTags = widget.roundTags;
    widget.abandon?.addListener(_abandoned);
    _ticker.start();
  }

  @override
  void didUpdateWidget(PuzzlePlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _session
      ..paused = widget.paused
      ..roundTags = widget.roundTags;
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
    widget.onClock?.call(_timeLeftMs, match.sides.first.game.settings.warningS);
    if (widget.paused) return;
    setState(() {});
    // The frame was drawn: the inputs it carried are no longer waiting (S7).
    SchedulerBinding.instance.addPostFrameCallback((_) => _session.drawn());
  }

  /// The ms left on the side nearest its end: the clock that ends the round.
  int get _timeLeftMs =>
      match.sides.map((side) => (side.game.timeLeftS * Duration.millisecondsPerSecond).round()).reduce(min);

  @override
  Widget build(BuildContext context) => MatchView(
    puzzle: widget.puzzle,
    snapshot: _session.current,
    timeLimitS: match.sides.first.game.settings.timeLimitS,
    target: widget.target,
    camera: widget.camera,
    padRects: widget.padRects,
    pxPerMm: widget.pxPerMm,
    paused: widget.paused,
    characters: widget.characters,
  );
}

/// Draws a whole match (S8): one board as [PuzzleView] does, or the split
/// screen, with the clock and both sides' counts along the top and each
/// side's board and tray in its own half, the trays at the outer edges. On
/// phones it draws through [camera] (m12-phone-layout §2): one side's world,
/// or the whole match, with the clock area beside the tray. It draws in the
/// look of the [ToyLookScope] above it, as [PuzzleView] does.
///
/// It lives here, beside the round's play view that draws through it, so
/// `view.dart` keeps room for the painters.
class MatchView extends StatefulWidget {
  const MatchView({
    super.key,
    required this.puzzle,
    required this.snapshot,
    this.timeLimitS,
    this.target = LayoutTarget.screen,
    this.camera = const PuzzleCamera.whole(),
    this.padRects = const [],
    this.pxPerMm = phonePxPerMm,
    this.paused = false,
    this.characters = const {},
    this.clock,
  });

  final Puzzle puzzle;
  final MatchSnapshot snapshot;
  final int? timeLimitS;

  /// Who each player is drawn as, by player number (M16 identity): the
  /// character the host gave them, a missing entry for the default their
  /// number gives. The boards' workers wear it, on the TV and the phone alike.
  final Map<int, ToyCharacter> characters;

  /// The world the match plays in, from the setup (m12 §0.4).
  final LayoutTarget target;

  /// What the box shows, for a phone (m12-phone-layout §2). The screen always
  /// draws the whole match.
  final PuzzleCamera camera;

  /// Where the app draws this phone's pad, in the box's px, which the other
  /// side's mirror keeps clear of (m12-opponent-mirror rule 3, code-health
  /// N4): the pad is the app's, so the game is told where it is rather than
  /// knowing it (rule 6). Empty where nothing is drawn over the game (the TV,
  /// a tablet, "Show on this device").
  final List<Rect> padRects;

  /// This phone's px per millimetre, which the mirror keeps its marks above
  /// (m12-opponent-mirror rule 7): the app's own reading, as [padRects] is its
  /// own geometry.
  final double pxPerMm;

  /// Whether the round is paused (the pause menu is open): its motion clock
  /// leaves the pause out, so the cat does not jump when play comes back (M14
  /// bugs2 2).
  final bool paused;

  /// Where the view reads the time for the pieces' motion, in milliseconds.
  /// Null: a [Stopwatch] started when the view is built.
  final Stopwatch? clock;

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  final _moments = PieceMoments();
  final _catMoments = CatMoments();
  late final _workers = WorkerMoments(widget.puzzle);

  /// What the boards draw the same way from frame to frame (M14 bugs3 B-016).
  final _cache = BoardCache();
  late final Stopwatch _clock = widget.clock ?? (Stopwatch()..start());

  /// How long the round has spent paused, and since when it has been paused, in
  /// ms on [_clock]: a pause leaves the clock running, so the motion clock takes
  /// the paused time out or the cat's slide-in and reach jump on the first frame
  /// back (M14 bugs2 2).
  int _pausedMs = 0;
  int _pausedFromMs = 0;

  int get _nowMs {
    final clockMs = _clock.elapsedMilliseconds;
    return clockMs - _pausedMs - (widget.paused ? clockMs - _pausedFromMs : 0);
  }

  @override
  void initState() {
    super.initState();
    _note();
  }

  @override
  void didUpdateWidget(MatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another puzzle's board has other slots and pieces: the cache's pictures
    // are this one's (M14 bugs3's still-key finding).
    if (!identical(oldWidget.puzzle, widget.puzzle)) _cache.clear();
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _pausedFromMs = _clock.elapsedMilliseconds;
      } else {
        _pausedMs += _clock.elapsedMilliseconds - _pausedFromMs;
      }
    }
    if (!identical(oldWidget.snapshot, widget.snapshot)) _note();
  }

  void _note() {
    _moments.observe(widget.snapshot, _nowMs);
    _workers.observe(widget.snapshot, _nowMs);
    _catMoments.observe(widget.snapshot.cat, _nowMs);
  }

  @override
  Widget build(BuildContext context) {
    final look = ToyLookScope.of(context);
    final snapshot = widget.snapshot;
    // As [PuzzleView] does: the sky shows round the boards where there is one.
    final fills = !toyStillSkyAbove(context);
    return CustomPaint(
      key: const Key('puzzleView'),
      size: Size.infinite,
      painter: snapshot.split || widget.target == LayoutTarget.phones
          ? MatchPainter(
              widget.puzzle,
              snapshot,
              look: look,
              moments: _moments,
              catMoments: _catMoments,
              workers: _workers,
              cache: _cache,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              target: widget.target,
              camera: widget.camera,
              padRects: widget.padRects,
              pxPerMm: widget.pxPerMm,
              characters: widget.characters,
              fillsBackground: fills,
            )
          : PuzzlePainter(
              widget.puzzle,
              snapshot.boards.single,
              look: look,
              moments: _moments,
              catMoments: _catMoments,
              workers: _workers,
              cache: _cache,
              nowMs: _nowMs,
              timeLimitS: widget.timeLimitS,
              cat: snapshot.cat,
              characters: widget.characters,
              fillsBackground: fills,
            ),
    );
  }
}
