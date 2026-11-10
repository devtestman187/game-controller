import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';
import 'arena_events.dart';
import 'arena_module.dart';
import 'arena_snapshot.dart';

/// One player in the game, as the host sees it this frame.
typedef PlayerFeed = ({String id, int number, String name, Color color, GamepadState gamepad});

/// Every player of [host], with their controls this frame.
List<PlayerFeed> feedsOf(GameHost host) => [
  for (final p in host.players)
    (id: p.id, number: p.number, name: p.nickname ?? '', color: Color(p.color), gamepad: host.gamepad(p.id)),
];

/// The dash's one name, for the phone's A button (P5) and the TV's HUD, which
/// says "Dash ready (A)" while a player can dash again.
const arenaDashLabel = 'Dash';

/// The buttons the Arena's rules read nowhere — a marble moves on the sticks or
/// the D-pad and aims with the right stick, and A is the dash — so the phones
/// show only A and Start (P5).
const _unusedButtons = {
  ControllerButton.b,
  ControllerButton.x,
  ControllerButton.y,
  ControllerButton.lb,
  ControllerButton.rb,
  ControllerButton.select,
};

/// The arena's buttons on the phone (P5), labelled as Shape Race's are: A
/// dashes and Start pauses (M11); the buttons the rules never read are hidden.
final arenaLayout = GameLayoutMessage(
  labels: {ControllerButton.a: arenaDashLabel, ControllerButton.start: 'Pause'},
  hidden: _unusedButtons,
);

/// The Arena on the host (m12 §3): runs [ArenaGame] in fixed steps, gives each
/// phone the arena's buttons, buzzes and plays its events, and records each
/// round (S7). The view only draws [current].
class ArenaSession extends GameSession {
  /// [settings] is how the host runs the round (m12 §3): the frame rate it
  /// sends frames to the phones at, which the round records. Null takes this
  /// build's start option ([HostingSettings.fromEnvironment]).
  ArenaSession({required super.host, required this.onEvent, ArenaGame? game, super.settings})
    : game = game ?? ArenaGame(),
      super(module: arenaModule, setup: arenaSetup);

  /// The rules. Tests pass one in, to look at the game itself.
  final ArenaGame game;

  /// Every game event, for the host app's log and debug overlay.
  final void Function(GameEvent event) onEvent;

  /// The players that were given the arena's buttons, so they get them once.
  final _withLayout = <String>{};
  bool _roundRunning = false;

  /// The arena as the rules left it.
  @override
  ArenaSnapshot get current => game.snapshot();

  /// The window changed size: the rules measure the field in it.
  void resize(Size size) => game.resize(size);

  /// Back from the pause menu: the phones get the arena's buttons again.
  @override
  void resumed() => _withLayout.clear();

  @override
  ArenaSnapshot snapshot() => game.snapshot();

  @override
  void step(double dt) {
    final ids = {for (final p in players) p.id};
    // The phones show the arena's buttons while it runs; afterwards they
    // belong to the host again (the TV's menus).
    for (final id in ids) {
      if (_withLayout.add(id)) host.setLayout(id, arenaLayout);
    }
    _withLayout.removeWhere((id) => !ids.contains(id));
    if (!_roundRunning && ids.isNotEmpty && game.phase == ArenaPhase.playing) {
      _roundRunning = true;
      // The rate the round's frames go out at (m12 §0.4).
      _record('round_start', data: {'hz': settings.frameRateHz});
    }

    final before = game.phase;
    final events = game.update(dt, {for (final id in ids) id: GameInput.fromGamepad(input(id))});
    for (final e in events) {
      // A world event — a coin appearing — is for no controller and plays a
      // sound only (N10).
      if (e.hapticMessage case final message?) host.haptic(e.playerId!, message);
      sound(e.soundName);
      onEvent(e);
      _record(_eventName(e.cause), playerId: e.playerId);
    }
    if (before == ArenaPhase.playing && game.phase != ArenaPhase.playing) {
      _roundRunning = false;
      _record(
        'round_end',
        playerId: game.winnerId,
        data: game.roundEndData({for (final id in ids) id: input(id).mode.name}),
      );
      _record('frames', data: {'drawn': frameCount, 'late': lateFrameCount});
      resetFrameCounts();
    }
  }

  /// The last frame count of a game that ends (someone left the screen). A won
  /// round isn't the end of the session, so the view always ends as `quit`
  /// (m12 §4, Q7).
  @override
  void dispose({bool finished = false}) {
    if (isDisposed) return;
    _recordFrames();
    super.dispose();
  }

  /// The host lost the arena (m12 §2.10): a running round's `round_end` says
  /// why, without a winner, then the frame counts as [dispose] records them.
  @override
  void abandon() {
    if (isDisposed) return;
    if (_roundRunning) {
      _roundRunning = false;
      _record('round_end', data: {'reason': ViewEndReason.abandoned});
    }
    _recordFrames();
    super.abandon();
  }

  void _recordFrames() {
    if (frameCount > 0) _record('frames', data: {'drawn': frameCount, 'late': lateFrameCount});
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      host.record(GameRecord(game: arenaGame, name: name, playerId: playerId, data: data));

  static String _eventName(GameEventCause cause) => switch (cause) {
    GameEventCause.wall => 'wall_hit',
    GameEventCause.hazard => 'hazard_hit',
    GameEventCause.goal => 'goal',
    GameEventCause.dash => 'dash',
    GameEventCause.cooldown => 'failed_dash',
    GameEventCause.bump => 'bump',
    GameEventCause.coin => 'coin',
    GameEventCause.coinAppear => 'coin_appear',
    GameEventCause.timeUp => 'time_up',
    GameEventCause.spring => 'spring',
  };
}
