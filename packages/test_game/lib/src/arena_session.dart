import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';
import 'arena_module.dart';
import 'arena_snapshot.dart';

/// One player in the game, as the host sees it this frame.
typedef PlayerFeed = ({String id, int number, String name, Color color, GamepadState gamepad});

/// Every player of [host], with their controls this frame.
List<PlayerFeed> feedsOf(GameHost host) => [
  for (final p in host.players)
    (id: p.id, number: p.number, name: p.nickname ?? '', color: Color(p.color), gamepad: host.gamepad(p.id)),
];

/// The game's name in analytics records.
const arenaGame = 'arena';

/// The arena's buttons on the phone: the usual ones, with Start to pause (M11).
final arenaLayout = GameLayoutMessage(labels: {ControllerButton.start: 'Pause'});

/// The Arena on the host (m12 §3): runs [ArenaGame] in fixed steps, gives each
/// phone the arena's buttons, buzzes and plays its events, and records each
/// round (S7). The view only draws [current].
class ArenaSession extends GameSession {
  ArenaSession({required GameHost host, required this.onEvent, ArenaGame? game})
    : game = game ?? ArenaGame(),
      super(host: host, module: arenaModule, setup: arenaSetup);

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
      _record('round_start');
    }

    final before = game.phase;
    final events = game.update(dt, {for (final id in ids) id: GameInput.fromGamepad(input(id))});
    for (final e in events) {
      host.haptic(e.playerId, e.toMessage());
      sound(e.event.name);
      onEvent(e);
      _record(_eventName(e.cause), playerId: e.playerId);
    }
    if (before == ArenaPhase.playing && game.phase == ArenaPhase.won) {
      _roundRunning = false;
      _record(
        'round_end',
        playerId: game.winnerId,
        data: {
          'timeS': game.lastTimeS,
          'modes': {for (final id in ids) id: input(id).mode.name},
          'winner': game.winnerId,
        },
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
    if (frameCount > 0) _record('frames', data: {'drawn': frameCount, 'late': lateFrameCount});
    super.dispose();
  }

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      host.record(GameRecord(game: arenaGame, name: name, playerId: playerId, data: data));

  static String _eventName(GameEventCause cause) => switch (cause) {
    GameEventCause.wall => 'wall_hit',
    GameEventCause.hazard => 'hazard_hit',
    GameEventCause.goal => 'goal',
    GameEventCause.dash => 'dash',
    GameEventCause.cooldown => 'failed_dash',
  };
}
