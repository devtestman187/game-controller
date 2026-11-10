import 'dart:math';

import 'package:connection/connection.dart';
import 'package:metrics/metrics.dart';
import 'package:protocol/protocol.dart';

/// The game name for ratings asked before the name was known.
const arenaGameName = 'arena';

/// Translates what a running session sees into its [SessionCollector]
/// (PRD v2 T17, T18): a controller's input mode and metrics batches, its
/// ratings, the game's rounds, frames and per-player results, and the rating
/// prompt after a game (M9 to M11).
///
/// Split from the host's [LiveStats], which owns the session's lifetime and
/// files; this part only reads messages and records.
class SessionRecorder {
  /// [session] returns the session to record into, or null when none runs,
  /// so the recorder follows the host's session. [log] gets short lines for
  /// the tester. [random] makes the rating prompts' IDs, injected so tests
  /// are deterministic.
  SessionRecorder({required this.host, required this.session, LogSink? log, Random? random})
    : _log = log ?? ((_) {}),
      _random = random ?? Random.secure();

  /// The game host whose players and records are recorded.
  final ServerGameHost host;

  /// The session being recorded, or null between sessions.
  final SessionCollector? Function() session;

  final LogSink _log;
  final Random _random;
  final _ratings = RatingScheduler();
  final _askedGames = <String, String>{};

  /// Records a controller message: its input state, a metrics batch or an
  /// answer to a rating prompt.
  void onMessage(ControllerMessage m) {
    final s = session();
    if (s == null) return;
    switch (m.message) {
      case InputStateMessage():
        s
          ..input(m.controllerId)
          ..mode(m.controllerId, InputMode.of(m.message as InputStateMessage).name);
      case final MetricsMessage batch:
        // The viewer counted its frames while drawing the host's view: they go
        // under that view's rate, like its stage samples (m12 §0.4).
        s.metrics(m.controllerId, batch, hz: host.viewRateHz);
      case final RatingMessage r:
        s.rating(m.controllerId, r, game: _askedGames.remove(r.id) ?? arenaGameName);
      default:
    }
  }

  /// Records a game's record: rounds, frames, per-player results and every
  /// other event (which also becomes a game event in the summary).
  void onRecord(GameRecord r) {
    final s = session();
    if (s == null) return;
    switch (r.name) {
      case 'round_start':
        // The round's game records the rate of the view it runs (m12 §0.4).
        final hz = r.data['hz'];
        s.roundStarted(hz: hz is int ? hz : null);
      case 'round_end':
        final modes = <String, String>{
          for (final MapEntry(:key, :value) in ((r.data['modes'] as Map?) ?? const {}).entries)
            if (key is String && value is String) key: value,
        };
        final time = r.data['timeS'];
        s.roundEnded(
          r.game,
          timeS: time is num ? time.toDouble() : 0,
          modes: modes,
          winnerId: r.data['winner'] as String?,
          // The puzzle (M11): a side or a team wins together, or a race is a draw.
          winnerIds: {...((r.data['winners'] as List?) ?? const []).whereType<String>()},
          draw: r.data['draw'] == true,
          // The games write an abandoned round with nothing but its reason:
          // nobody played it, so the stats get no round and no time (M14 N1).
          abandoned: r.data['reason'] == ViewEndReason.abandoned,
        );
        // Rounds per format (solo, team, 1v1, 2v1, 2v2). The completion time and
        // pieces placed come with each player's result.
        if (r.data['format'] case final String format) {
          for (final id in modes.keys) {
            s.gameEvent(r.game, 'rounds_$format', id);
          }
        }
        _maybeAskRatings(r.game, modes.keys);
      case 'frames':
        s.frames((r.data['drawn'] as num?)?.toInt() ?? 0, (r.data['late'] as num?)?.toInt() ?? 0);
      case 'player_result':
        // The puzzle's per-player numbers (M10, M11): rotation time, overshoots,
        // pieces placed, completion time, help calls, solo big-piece carries,
        // win and draw, …
        final id = r.playerId;
        if (id == null) return;
        for (final MapEntry(:key, :value) in r.data.entries) {
          if (value is num) s.gameValue(r.game, key, id, value.toDouble());
        }
      default:
        final id = r.playerId;
        if (id == null) return;
        s.gameEvent(r.game, r.name, id);
        // A drop's errors (the puzzle: angle and position at each drop).
        for (final key in const ['angleErrorDeg', 'positionError']) {
          if (r.data[key] case final num v) s.gameValue(r.game, '${r.name}.$key', id, v.toDouble());
        }
    }
  }

  /// Asks each of [players] how the controls felt, when the rating schedule
  /// says it is their turn (M9).
  void _maybeAskRatings(String game, Iterable<String> players) {
    for (final id in players) {
      if (!_ratings.gameEnded(id, host.nowMs)) continue;
      final askId = List.generate(6, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      if (host.askRating(id, id: askId, game: game)) {
        _ratings.asked(id, host.nowMs);
        _askedGames[askId] = game;
        _log('Stats: asked P${host.players.where((p) => p.id == id).firstOrNull?.number ?? '?'} how the controls felt');
      }
    }
  }
}
