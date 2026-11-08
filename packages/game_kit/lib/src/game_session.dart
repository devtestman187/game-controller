import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/foundation.dart';
import 'package:protocol/protocol.dart';

import 'game_module.dart';
import 'hosting_settings.dart';

/// One game's rules on the host, in fixed steps (m12 §2.3). Subclasses run the
/// rules and their effects; this class owns time, frames and the view.
///
/// The host's view drives [advance] from its Ticker once per drawn frame. An
/// advance reads the players and their controls once, runs as many 1/60 s
/// steps as the time since the last advance allows (at most [maxCatchUpS]),
/// and publishes a frame to the controllers showing the game (only while
/// [GameHost.hasViewers]), so a phone can draw the game smoothly and measure a
/// touch's trip to its screen (D3).
///
/// Which steps go out depends on the step count alone — a 60 Hz host sends
/// every step, a 30 Hz one every second — and a step clock times them: the
/// anchor's host time plus the steps since, so the few ms by which [GameHost.nowMs]
/// wobbles around the Ticker's elapsed can't drop a step (m12 bug 1108f).
///
/// A step reads its input through [input]: the newest sample, with the buttons
/// pressed since the last step added, so a tap that starts and ends between two
/// steps still reaches exactly one step.
abstract class GameSession {
  GameSession({
    required this.host,
    required this.module,
    required Map<String, Object?> setup,
    HostingSettings? settings,
  }) : settings = settings ?? HostingSettings.fromEnvironment() {
    host.startView(
      ViewStartMessage(
        game: module.id,
        snapshotVersion: module.snapshotVersion,
        setup: setup,
        hz: this.settings.frameRateHz,
      ),
    );
  }

  /// A frame that took longer than this was dropped: it missed the whole next
  /// frame (m12 §3, D3). A 60 Hz frame is 16.7 ms.
  static const lateFrameMs = 25;

  /// A gap between advances longer than this means drawing stopped for a while
  /// (the window was minimised or covered, the PC slept), so an input that
  /// waited through it isn't a delay a player felt (S7).
  static const stallS = 0.1;

  /// The most real time one [advance] simulates. A longer gap doesn't run a
  /// burst of steps when drawing comes back (m12 §3); the game slows down for
  /// that moment instead of jumping.
  static const maxCatchUpS = 0.1;

  final GameHost host;

  /// The game as a viewer draws it (m12 §4).
  final GameModule module;

  /// How the game runs: the step rate and the frame rate
  /// ([HostingSettings.frameRateHz]). A
  /// session built without settings takes this build's debug start option
  /// ([HostingSettings.fromEnvironment]), so every game gets it with no
  /// change of its own.
  final HostingSettings settings;

  Duration _last = Duration.zero;
  double _accS = 0;
  int _stepCount = 0;
  GameSnapshot? _current;
  bool _paused = false;
  bool _disposed = false;
  bool _firstFrameSent = false;

  /// When the round last came back from a pause, on [host.nowMs]. An input
  /// that arrived before it waited out the pause, not for the host, so it is
  /// no received_to_drawn sample (m12 bug 1107e).
  int? _resumedAtMs;

  // The step clock: the host time of step [_anchorStep], and whether the next
  // step anchors again (a resume). A frame's `at` is the anchor plus the steps
  // since it (m12 bug 1108f).
  double? _anchorMs;
  int _anchorStep = 0;
  bool _reanchor = false;

  // The last sent frame's `at`: a frame is never sent at or before it, since
  // a viewer drops a frame that isn't after its newest (m12 bug 1108f).
  int? _lastSentAtMs;
  int _lastFrameIndex = -1;
  // A set, so a sound repeated across the advances of one frame interval (20
  // or 30 Hz) is carried once.
  final _pendingSounds = <String>{};
  final _soundsThisAdvance = <String>{};

  List<GamePlayer> _players = const [];
  final _latest = <String, GamepadState>{};
  final _pendingButtons = <String, Set<GamepadButton>>{};
  final _arrived = <String, int>{};
  Map<String, int> _fresh = const {};
  bool _stalled = false;

  int _frames = 0;
  int _lateFrames = 0;

  /// Advances the rules by exactly [HostingSettings.simStepS]. Applies the
  /// step's effects through the host: haptics, records, layouts, status; plays
  /// each sound through [sound].
  @protected
  void step(double dt);

  /// The rules' state now, for drawing.
  @protected
  GameSnapshot snapshot();

  /// Plays [name] on the host once per [advance], as the views do today, and
  /// adds it to the next frame's `snd`.
  @protected
  void sound(String name) {
    if (_soundsThisAdvance.add(name)) {
      _pendingSounds.add(name);
      host.playSound(name);
    }
  }

  /// The players of the last [advance], by number.
  @protected
  List<GamePlayer> get players => _players;

  /// [playerId]'s controls for the step about to run: the newest sample, with
  /// every button pressed since the last step added. Local players have no
  /// press hold on the host and a 120 Hz display runs half its advances without
  /// a step, so without this a quick tap could vanish between two steps.
  @protected
  GamepadState input(String playerId) {
    final newest = _latest[playerId] ?? GamepadState.neutral;
    final seen = _pendingButtons[playerId];
    return seen == null ? newest : newest.withButtons(seen);
  }

  /// Advances with players (one per drawn frame) so far, or since
  /// [resetFrameCounts]: the `frames` record's `drawn` count.
  int get frameCount => _frames;

  /// Advances that came too late (over [lateFrameMs]): the `frames` record's
  /// `late` count.
  int get lateFrameCount => _lateFrames;

  void resetFrameCounts() {
    _frames = 0;
    _lateFrames = 0;
  }

  /// The rules' state after the last step, or now before the first.
  GameSnapshot get current => _current ??= snapshot();

  /// How many steps have run. The last one's number (from 0, the frame's `n`)
  /// is one less.
  int get stepCount => _stepCount;

  bool get paused => _paused;

  /// While paused nothing steps, nothing accumulates and no frame is sent; the
  /// pause menu can stay open for minutes and the game stands still. Setting it
  /// false calls [resumed], and resuming doesn't catch up: the step clock
  /// re-anchors to the host's clock, since the pause stood it still.
  ///
  /// A session paused before its first step sends its first frame all the same
  /// ([_publishFirstFrame]), whether or not a viewer has paired yet: a round
  /// held for the "Get ready" beat shows its board on every phone showing the
  /// game, including one that pairs during the beat (m12-host-touch rule 3).
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (value) {
      _publishFirstFrame();
      return;
    }
    _resumedAtMs = host.nowMs;
    _reanchor = true;
    resumed();
  }

  /// Called when [paused] goes false: the game can give the phones their
  /// controls back.
  @protected
  void resumed() {}

  /// True once [dispose] ran.
  bool get isDisposed => _disposed;

  /// Called once per drawn frame by the view's Ticker, with the Ticker's
  /// elapsed time.
  ///
  /// Each step goes to [_publishIfDue] with the host's estimate of when it
  /// ran: [GameHost.nowMs] this advance, less the time still in the
  /// accumulator.
  void advance(Duration elapsed) {
    if (_disposed) return;
    final rawS = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (_paused) return;
    _soundsThisAdvance.clear();
    _accS += min(rawS, maxCatchUpS);
    _stalled = rawS > stallS;
    _sample();
    if (_players.isNotEmpty) {
      _frames++;
      if (_frames > 1 && rawS * Duration.millisecondsPerSecond > lateFrameMs) _lateFrames++;
    }
    final nowMs = host.nowMs.toDouble();
    while (_accS >= settings.simStepS) {
      _accS -= settings.simStepS;
      step(settings.simStepS);
      _stepCount++;
      for (final MapEntry(key: id, value: state) in _latest.entries) {
        _pendingButtons[id] = {...state.buttons};
      }
      _current = snapshot();
      _publishIfDue(_stepCount - 1, nowMs - _accS * Duration.millisecondsPerSecond);
    }
  }

  /// The view drew the frame the last advance built: reports received_to_drawn
  /// for the inputs that were fresh in it, unless drawing had stalled.
  void drawn() {
    final fresh = _fresh;
    if (_disposed || _stalled || fresh.isEmpty) return;
    _fresh = const {};
    final now = host.nowMs;
    for (final MapEntry(key: id, value: arrivedAt) in fresh.entries) {
      host.reportStage(id, LatencyStage.receivedToDrawn, now - arrivedAt);
    }
  }

  /// Ends the view (view_end: `finished` if [finished], else `quit`) and stops.
  /// Calling it again does nothing.
  void dispose({bool finished = false}) {
    if (_disposed) return;
    _disposed = true;
    host.endView(ViewEndMessage(reason: finished ? ViewEndReason.finished : ViewEndReason.quit));
  }

  /// Ends the view as abandoned (m12 §2.10) and stops: the host lost the
  /// round, so it stops without running another step. Subclasses record what
  /// the round did first. Calling it again, or a later [dispose], does
  /// nothing.
  void abandon() {
    if (_disposed) return;
    _disposed = true;
    host.endView(const ViewEndMessage(reason: ViewEndReason.abandoned));
  }

  /// Sends the round's first frame while no step has run (m12-host-touch rule
  /// 3): a phone showing the game draws nothing before its first frame (m12
  /// §4), so a round held for the "Get ready" beat would be blank on every
  /// phone until the beat ended. The frame is a step's frame with its step at
  /// -1, so the first step's frame (0) follows it without a gap.
  ///
  /// It goes out whether or not a viewer has paired yet, so the host keeps it
  /// as the view's latest frame and a phone that pairs during the beat gets it
  /// after `view_start` (review R1 findings 2 and 3).
  void _publishFirstFrame() {
    if (_firstFrameSent || _stepCount != 0 || _disposed) return;
    _firstFrameSent = true;
    // No advance has read the players yet, and the frame carries them.
    _readPlayers();
    host.publishFrame(_frame(-1, host.nowMs));
  }

  /// A frame of the game as it stands: step [n] at [atMs], with the players'
  /// acks and the roster, and the [sounds] since the last sent frame. A step's
  /// frame and the round's first frame are built here, so both carry the same.
  FrameMessage _frame(int n, int atMs, {List<String> sounds = const []}) => FrameMessage(
    n: n,
    atMs: atMs,
    snapshot: current.toJson(),
    sounds: sounds,
    acks: _acks(),
    roster: {for (final p in _players) p.id: (number: p.number, name: p.nickname ?? '')},
  );

  /// Reads the players and their controls, and remembers the buttons held.
  void _readPlayers() {
    final now = host.players;
    _players = now;
    final ids = {for (final p in now) p.id};
    _latest.removeWhere((id, _) => !ids.contains(id));
    _pendingButtons.removeWhere((id, _) => !ids.contains(id));
    for (final p in now) {
      final state = host.gamepad(p.id);
      _latest[p.id] = state;
      (_pendingButtons[p.id] ??= <GamepadButton>{}).addAll(state.buttons);
    }
  }

  /// Reads the players and their controls, and remembers the inputs that are
  /// new since the last advance.
  void _sample() {
    _readPlayers();
    final ids = {for (final p in _players) p.id};
    final resumedAt = _resumedAtMs;
    final fresh = <String, int>{};
    final seen = <String, int>{};
    for (final id in ids) {
      final arrivedAt = host.inputArrivedAtMs(id);
      if (arrivedAt == null || arrivedAt == _arrived[id]) continue;
      // Seen either way, so it is never counted later; reported only when it
      // arrived after the round came back, since a pause is no input delay.
      seen[id] = arrivedAt;
      if (resumedAt == null || arrivedAt > resumedAt) fresh[id] = arrivedAt;
    }
    _arrived
      ..removeWhere((id, _) => !ids.contains(id))
      ..addAll(seen);
    _fresh = fresh;
  }

  /// Sends step [n]'s frame when the frame rate is due one: step [n] goes out
  /// once `(n × frameRateHz) ~/ [HostingSettings.simHz]` passes the last sent
  /// index, so 60 Hz sends every step, 30 every second and 20 every third, and
  /// a rate between them spreads its steps evenly. The step count alone
  /// decides it: taken from the host's clock, a frame slot of exactly one step
  /// at 60 Hz put two steps in one slot whenever the clock wobbled, and the
  /// second was dropped on every phone showing the game (m12 bug 1108f).
  /// Sounds wait for the next sent frame.
  ///
  /// [wallMs] is the host's estimate of when the step ran, which [_stepTimeMs]
  /// keeps the step clock near.
  void _publishIfDue(int n, double wallMs) {
    final atMs = _stepTimeMs(n, wallMs);
    final index = (n * settings.frameRateHz) ~/ HostingSettings.simHz;
    if (!host.hasViewers) {
      // Nobody would get the sounds: don't let them pile up for a viewer that
      // joins later (it would play a whole game's sounds at once).
      _pendingSounds.clear();
      return;
    }
    if (index <= _lastFrameIndex) return;
    _lastFrameIndex = index;
    // A re-anchor can pull the clock back by its wobble: never behind a sent
    // frame, or the phones would drop this one.
    final last = _lastSentAtMs;
    final sentAtMs = last != null && atMs <= last ? last + 1 : atMs;
    _lastSentAtMs = sentAtMs;
    host.publishFrame(_frame(n, sentAtMs, sounds: List.of(_pendingSounds)));
    _pendingSounds.clear();
  }

  /// The host time step [n] ran at: the anchor's host time plus the steps
  /// since it, times a step, rounded to a whole ms once at the end. The clock
  /// moves with the steps alone, so consecutive sent frames are one frame
  /// interval apart however [GameHost.nowMs] wobbles (m12 bug 1108f).
  ///
  /// [wallMs] is the host's estimate of the step's time this advance. It
  /// re-anchors the step clock when the two differ by more than a step (a
  /// stall, a slow device, which would drift apart), and on the first step
  /// after a pause, so the clock never strays from the host's.
  int _stepTimeMs(int n, double wallMs) {
    final stepMs = settings.simStepS * Duration.millisecondsPerSecond;
    final anchorMs = _anchorMs;
    var stepTimeMs = anchorMs == null ? wallMs : anchorMs + (n - _anchorStep) * stepMs;
    if (anchorMs == null || _reanchor || (wallMs - stepTimeMs).abs() > stepMs) {
      stepTimeMs = wallMs;
      _anchorMs = wallMs;
      _anchorStep = n;
      _reanchor = false;
    }
    return stepTimeMs.round();
  }

  /// Each player's last applied input seq, for the frame's `acks`.
  Map<String, int> _acks() {
    final acks = <String, int>{};
    for (final p in _players) {
      final seq = host.inputSeq(p.id);
      if (seq != null) acks[p.id] = seq;
    }
    return acks;
  }
}
