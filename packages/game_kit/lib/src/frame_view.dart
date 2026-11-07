import 'dart:async';

import 'package:connection/connection.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:protocol/protocol.dart';

import 'game_module.dart';
import 'game_registry.dart';
import 'hosting_settings.dart';

/// What a phone shows when it can't draw the game it's sent (m12 §4): this app
/// version has no module for the game, or the game's snapshots are newer. It
/// says what to do next, in words an 8-year-old reads.
const updateAppText = 'Update the app to see this game';

/// One frame as the view keeps it: the host's message and its decoded
/// snapshot.
typedef _PlayedFrame = ({FrameMessage frame, GameSnapshot snapshot});

/// Draws the game a host shows (m12 §4): buffers its frames, draws them
/// smoothly through [ViewerTiming], and measures them in [stats].
///
/// It draws nothing before a [ViewStarted], and ignores frames then and after
/// a [ViewEnded]. A game this app doesn't know, or one whose snapshots are a
/// newer version, is shown as [updateAppText] until the next start. Otherwise
/// it waits for the first frame, then draws each Ticker frame with the playout
/// delay the arrivals ask for: the older frame, lerped towards the newer one,
/// never past the newest.
///
/// [nowMs] must be the same clock the frames' arrivals are taken on
/// (`ControllerClient.nowMs`), so the delay is measured on one clock (D3).
class FrameView extends StatefulWidget {
  const FrameView({
    required this.views,
    required this.registry,
    required this.stats,
    required this.nowMs,
    this.playerId,
    this.settings = HostingSettings.defaults,
    super.key,
  });

  /// The client's view events (`ControllerClient.view`): the game's start,
  /// its frames and its end, in the order the host sent them.
  final Stream<ViewEvent> views;

  /// Every game this app version can draw, by module ID.
  final GameRegistry registry;

  /// The client's measurements: reset on view_start, one sample and one count
  /// per frame.
  final ViewerStats stats;

  /// This phone's clock in ms, taken when a frame is handled
  /// (`ControllerClient.nowMs`).
  final int Function() nowMs;

  /// This phone's player, for the frames it acknowledges and for
  /// [ViewContext.playerId]. Null for a phone that only watches.
  final String? playerId;

  /// How much playout the phone may buffer ([HostingSettings.maxPlayoutFrames]).
  final HostingSettings settings;

  @override
  State<FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends State<FrameView> with SingleTickerProviderStateMixin {
  StreamSubscription<ViewEvent>? _subscription;
  late final Ticker _ticker = createTicker(_tick);

  ViewerTiming? _timing;
  PlayoutBuffer<_PlayedFrame>? _buffer;
  GameViewer? _viewer;
  bool _needsUpdate = false;

  // What the last tick picked: the frames to draw and how far between them.
  _PlayedFrame? _a;
  _PlayedFrame? _b;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(FrameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.views != oldWidget.views) {
      _subscription?.cancel();
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _listen() => _subscription = widget.views.listen(_onEvent);

  void _onEvent(ViewEvent event) {
    switch (event) {
      case ViewStarted(:final start):
        _start(start);
      case ViewFrame(:final frame, :final arrivedAtMs):
        _addFrame(frame, arrivedAtMs);
      case ViewEnded():
        _stop();
    }
  }

  /// Starts over for [start]: a new game, its timing, stats and buffer.
  void _start(ViewStartMessage start) {
    final module = widget.registry.moduleFor(start.game);
    GameViewer? viewer;
    if (module != null && module.snapshotVersion == start.snapshotVersion) {
      try {
        viewer = module.createViewer(start.setup);
      } on FormatException {
        // A setup this viewer can't read is a game it can't draw either.
        viewer = null;
      }
    }
    _viewer = viewer;
    _needsUpdate = viewer == null;
    _timing = viewer == null ? null : ViewerTiming(hz: start.hz, maxPlayoutFrames: widget.settings.maxPlayoutFrames);
    _buffer = viewer == null ? null : PlayoutBuffer<_PlayedFrame>();
    if (viewer != null) widget.stats.reset(hz: start.hz);
    _forgetDrawn();
    if (viewer == null) {
      _ticker.stop();
    } else {
      _ticker.start();
    }
    setState(() {});
  }

  /// Buffers [frame] for the playout, after measuring its arrival.
  void _addFrame(FrameMessage frame, int arrivedAtMs) {
    final timing = _timing;
    final buffer = _buffer;
    final viewer = _viewer;
    if (timing == null || buffer == null || viewer == null) return;
    final jitter = timing.addFrame(atMs: frame.atMs, arrivedAtMs: arrivedAtMs);
    widget.stats.frameArrived(frame.n, jitterMs: jitter);
    final GameSnapshot snapshot;
    try {
      snapshot = viewer.decode(frame.snapshot);
    } on FormatException {
      // The frame doesn't fit this app version's snapshots: drop it and keep
      // drawing the ones that do. The next start says "update the app".
      return;
    }
    buffer.add((frame: frame, snapshot: snapshot), frame.atMs);
  }

  /// Back to drawing nothing: the game ended, or the app couldn't show it.
  void _stop() {
    final wasActive = _viewer != null || _needsUpdate;
    _viewer = null;
    _needsUpdate = false;
    _timing = null;
    _buffer = null;
    _forgetDrawn();
    _ticker.stop();
    if (wasActive) setState(() {});
  }

  void _forgetDrawn() {
    _a = null;
    _b = null;
    _t = 0;
  }

  void _tick(Duration _) {
    final timing = _timing;
    final buffer = _buffer;
    if (timing == null || buffer == null) return;
    final pick = buffer.pick(timing.renderAtMs(widget.nowMs()));
    if (pick == null) return;
    final isNewA = !identical(pick.a, _a);
    if (!isNewA && identical(pick.b, _b) && pick.t == _t) return;
    final a = pick.a;
    _a = a;
    _b = pick.b;
    _t = pick.t;
    if (isNewA) {
      // The draw time is the Flutter frame that shows it, not this tick.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportDrawn(a));
    }
    setState(() {});
  }

  /// Measures the draw of [a], once per frame: the touch_to_frame sample.
  void _reportDrawn(_PlayedFrame a) {
    if (!mounted || !identical(a, _a)) return;
    final playerId = widget.playerId;
    widget.stats.frameDrawn(playerId == null ? null : a.frame.acks[playerId], widget.nowMs());
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    if (viewer == null) return _needsUpdate ? const Center(child: Text(updateAppText)) : const SizedBox.shrink();
    final a = _a;
    if (a == null) return const SizedBox.shrink();
    final b = _b;
    final snapshot = b == null ? a.snapshot : a.snapshot.lerpTo(b.snapshot, _t);
    return viewer.build(context, snapshot, (roster: a.frame.roster, playerId: widget.playerId));
  }
}
