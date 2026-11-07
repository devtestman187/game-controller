import 'package:connection/connection.dart';
import 'package:protocol/protocol.dart';

import 'match.dart';
import 'puzzle_values.dart';

/// One step's events as the players feel and hear them (S5, S7): the haptics,
/// sounds and records the play view applied inline before (PRD v2 M10).
///
/// A sound goes through [sound], the session's, so it plays once a frame as
/// today and rides the next frame to the phones showing the game (m12 §3).
final class PuzzleEffects {
  const PuzzleEffects({required this.host, required this.match, required this.game, required this.sound});

  final GameHost host;
  final PuzzleMatch match;

  /// The game's name in analytics records.
  final String game;

  final void Function(String name) sound;

  /// Applies one event of [side], for the [players] here now: a tick buzzes
  /// everyone on the side that ran out of warning time.
  void apply(PuzzleSide side, PuzzleEvent event, List<GamePlayer> players) {
    final id = event.playerId;
    switch (event.kind) {
      case PuzzleEventKind.pickup:
        sound('pickup');
      case PuzzleEventKind.snap:
        _haptic(id!, HapticEvent.snap);
        sound('snap');
        _record('snap', playerId: id, data: event.data);
      case PuzzleEventKind.wrong:
        _haptic(id!, HapticEvent.wrong);
        sound('wrong');
        _record('wrong_drop', playerId: id, data: event.data);
      case PuzzleEventKind.dropReady:
        _haptic(id!, HapticEvent.dropReady, intensity: 0.7);
      case PuzzleEventKind.help:
        // The teammate is called; the call is the carrier's.
        _haptic(id!, HapticEvent.help);
        sound('help');
        if (event.data['from'] case final String from) _record('help_call', playerId: from);
      case PuzzleEventKind.tick:
        for (final p in _onSide(side, players)) {
          _haptic(p.id, HapticEvent.tick, intensity: 0.6);
        }
        sound('tick');
      case PuzzleEventKind.timeUp:
        sound('time_up');
      case PuzzleEventKind.finished:
        sound('success');
    }
  }

  /// The players on a side who are here now.
  List<GamePlayer> _onSide(PuzzleSide side, List<GamePlayer> players) => [
    for (final p in players)
      if (match.teams.containsKey(p.id) && (!match.format.split || match.teams[p.id] == side)) p,
  ];

  void _haptic(String to, HapticEvent event, {double intensity = 1}) =>
      host.haptic(to, HapticEventMessage(event: event, intensity: intensity));

  void _record(String name, {String? playerId, Map<String, Object?> data = const {}}) =>
      host.record(GameRecord(game: game, name: name, playerId: playerId, data: data));
}
