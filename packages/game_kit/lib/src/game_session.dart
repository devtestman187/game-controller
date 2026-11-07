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

  /// How close a step's `at` must be to a send time to count as on it: the `at`
  /// is a double built from the host's clock, so rounding alone can put a step
  /// a tiny fraction of a microsecond early.
  static const frameSlackMs = 0.001;

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

  double? _frameStartMs;
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
  /// false calls [resumed], and resuming doesn't catch up.
  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (!value) resumed();
  }

  /// Called when [paused] goes false: the game can give the phones their
  /// controls back.
  @protected
  void resumed() {}

  /// True once [dispose] ran.
  bool get isDisposed => _disposed;

  /// Called once per drawn frame by the view's Ticker, with the Ticker's
  /// elapsed time.
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
      _publishIfDue(nowMs - _accS * Duration.millisecondsPerSecond);
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

  /// Reads the players and their controls, and remembers the inputs that are
  /// new since the last advance.
  void _sample() {
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
    final fresh = <String, int>{};
    for (final id in ids) {
      final arrivedAt = host.inputArrivedAtMs(id);
      if (arrivedAt != null && arrivedAt != _arrived[id]) fresh[id] = arrivedAt;
    }
    _arrived
      ..removeWhere((id, _) => !ids.contains(id))
      ..addAll(fresh);
    _fresh = fresh;
  }

  /// Sends a frame when the step at [atMs] is on or past the next send time:
  /// every `1000 / settings.frameRateHz` ms, counted from the first step.
  void _publishIfDue(double atMs) {
    final startMs = _frameStartMs ??= atMs;
    final intervalMs = Duration.millisecondsPerSecond / settings.frameRateHz;
    final index = ((atMs - startMs + frameSlackMs) / intervalMs).floor();
    if (!host.hasViewers) {
      // Nobody would get the sounds: don't let them pile up for a viewer that
      // joins later (it would play a whole game's sounds at once).
      _pendingSounds.clear();
      return;
    }
    if (index <= _lastFrameIndex) return;
    _lastFrameIndex = index;
    host.publishFrame(
      FrameMessage(
        n: _stepCount - 1,
        atMs: atMs.round(),
        snapshot: current.toJson(),
        sounds: List.of(_pendingSounds),
        acks: _acks(),
        roster: {for (final p in _players) p.id: (number: p.number, name: p.nickname ?? '')},
      ),
    );
    _pendingSounds.clear();
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
