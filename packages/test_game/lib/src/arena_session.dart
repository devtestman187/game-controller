import 'dart:math';

import 'package:connection/connection.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:protocol/protocol.dart';

import 'arena.dart';
import 'arena_events.dart';
import 'arena_mode.dart';
import 'arena_module.dart';
import 'arena_robo.dart';
import 'arena_snapshot.dart';
import 'cpu_pilot.dart';

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
  ///
  /// [roboLevel] is Robo's level from the waiting card (party-night §7a, M14
  /// b3): a Bumper Round with one player gives it a seat, played by a
  /// [CpuPilot] on the host. A race, or a round with two players or more,
  /// never does.
  ArenaSession({
    required super.host,
    required this.onEvent,
    ArenaGame? game,
    super.settings,
    this.roboLevel = RoboLevel.medium,
  }) : game = game ?? ArenaGame(),
       super(module: arenaModule, setup: arenaSetup);

  /// The rules. Tests pass one in, to look at the game itself.
  final ArenaGame game;

  /// The level Robo plays at when it has a seat.
  final RoboLevel roboLevel;

  /// Robo's hands, made when its seat is first stepped.
  CpuPilot? _robo;

  /// Every game event, for the host app's log and debug overlay.
  final void Function(GameEvent event) onEvent;

  /// The players that were given the arena's buttons, so they get them once.
  final _withLayout = <String>{};
  bool _roundRunning = false;

  /// The players whose marbles the Bumper Round runs, fixed when its first
  /// step runs: a player who joins during the round waits for the next one
  /// (M14 b2, design section 8), so their input drives nothing and no marble
  /// comes out for them. The race has no such wait: everyone joins at once, as
  /// they always have. Null until the round's first step.
  Set<String>? _bumperPlayers;

  /// Whether Robo has a seat this round: the Bumper Round with exactly one
  /// player in it (party-night §7a). The round's players are fixed when it
  /// starts (M14 b2), so a player who joins later does not take the seat away
  /// mid-round and the next round is a round with two.
  bool get _roboIn {
    final round = _bumperPlayers;
    return game.mode == ArenaMode.bumper && round != null && round.length == 1;
  }

  /// Robo's hands for this round, made once: a level's numbers, the map's grid
  /// with its sliding movers in it, and a seed that repeats (party-night §7a).
  CpuPilot? get _pilot {
    if (!_roboIn) return null;
    return _robo ??= CpuPilot(level: roboLevel, grid: cpuGrid(game.map), random: Random(roboSeed));
  }

  /// The players the rules step this frame.
  Iterable<GamePlayer> get _stepping {
    if (game.mode != ArenaMode.bumper) return players;
    final ids = {for (final p in players) p.id};
    final round = _bumperPlayers ??= ids;
    return [
      for (final p in players)
        if (round.contains(p.id)) p,
    ];
  }

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
    // Every phone that is here gets the arena's buttons, a player waiting for
    // the next round too: their pad still shows the round they watch.
    for (final id in ids) {
      if (_withLayout.add(id)) host.setLayout(id, arenaLayout);
    }
    _withLayout.removeWhere((id) => !ids.contains(id));
    final stepping = {for (final p in _stepping) p.id};
    if (!_roundRunning && stepping.isNotEmpty && game.phase == ArenaPhase.playing) {
      _roundRunning = true;
      // The rate the round's frames go out at (m12 §0.4).
      _record('round_start', data: {'hz': settings.frameRateHz});
    }

    final before = game.phase;
    final inputs = {for (final id in stepping) id: GameInput.fromGamepad(input(id))};
    if (_pilot case final pilot?) inputs[roboPlayerId] = pilot.step(game, dt);
    final events = game.update(dt, inputs);
    for (final e in events) {
      // A world event — a coin appearing — is for no controller and plays a
      // sound only (N10). Robo has no phone to buzz (party-night §7a).
      if (e.hapticMessage case final message? when e.playerId != roboPlayerId) host.haptic(e.playerId!, message);
      sound(e.soundName);
      onEvent(e);
      // Robo is no player of the night's: its events are recorded with no
      // player, so no stats or ratings ever count it (party-night §7a).
      _record(_eventName(e.cause), playerId: e.playerId == roboPlayerId ? null : e.playerId);
    }
    if (before == ArenaPhase.playing && game.phase != ArenaPhase.playing) {
      _roundRunning = false;
      final winner = game.winnerId;
      _record(
        'round_end',
        playerId: winner == roboPlayerId ? null : winner,
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
