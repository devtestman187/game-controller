import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs.dart';
import 'providers.dart';

/// How many times each puzzle's board keeps (M14 c2, design section 9 N14):
/// the fastest three, each with the names of the players on that board.
const bestTimesPerBoard = 3;

/// The version of the kept best times (B-012): a host below it has the boards
/// of [redoneMediumPuzzleIds] cleared once when [BestTimesNotifier] starts.
const bestTimesVersion = 1;

/// The Medium puzzles redrawn in M14 (B-012): a time kept on an old picture
/// measures a board that no longer exists, so it is cleared the once.
const redoneMediumPuzzleIds = ['boat', 'car', 'robot', 'train', 'castle', 'butterfly'];

/// One board's kept time (design section 9 N14): how long it took, in ms, and
/// who played it.
@immutable
final class BestTime {
  const BestTime({required this.timeMs, required this.names});

  /// The board's time, in milliseconds.
  final int timeMs;

  /// The nicknames of the players who played that board, in their numbers'
  /// order.
  final List<String> names;

  /// This time as the host saves it.
  Map<String, Object?> toJson() => {'ms': timeMs, 'names': names};

  /// The time [json] holds, or null when it isn't one this build understands.
  static BestTime? fromJson(Object? json) {
    if (json is! Map) return null;
    final ms = json['ms'];
    final names = json['names'];
    if (ms is! int || ms < 0 || names is! List) return null;
    return BestTime(timeMs: ms, names: List.unmodifiable(names.whereType<String>()));
  }
}

/// What a finished board did to its best time (design section 9 N14):
/// [isRecord] when it was the board's first time or its fastest, and [best] as
/// the board stands now, for the results card.
@immutable
final class BestTimeResult {
  const BestTimeResult({required this.isRecord, required this.best});

  /// Whether the time just played beat the board's best.
  final bool isRecord;

  /// The board's best now.
  final BestTime? best;
}

/// Every puzzle's best time kept on the host (T15, design section 9 N14): the
/// fastest [bestTimesPerBoard] of each board, with solo and team kept apart so
/// a helper is never measured against one player.
@immutable
final class BestTimes {
  const BestTimes._(this._boards);

  /// A host that has played no board yet.
  static const empty = BestTimes._({});

  final Map<String, List<BestTime>> _boards;

  /// The board a puzzle is kept under: [puzzleId] and whether it was played
  /// [team] or solo.
  static String boardKey(String puzzleId, {required bool team}) => '$puzzleId|${team ? 'team' : 'solo'}';

  /// The times kept for [puzzleId]'s board, fastest first.
  List<BestTime> boardFor(String puzzleId, {required bool team}) => _boards[boardKey(puzzleId, team: team)] ?? const [];

  /// The fastest time [puzzleId]'s board has, or null when it has none.
  BestTime? bestFor(String puzzleId, {required bool team}) {
    final board = boardFor(puzzleId, team: team);
    return board.isEmpty ? null : board.first;
  }

  /// This with [key]'s board replaced by [times].
  BestTimes withBoard(String key, List<BestTime> times) => BestTimes._({..._boards, key: List.unmodifiable(times)});

  /// The times as the host saves them: each board's key to its kept times.
  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in _boards.entries) key: [for (final time in value) time.toJson()],
  };

  /// The times [json] holds; a board this build doesn't understand is left out.
  static BestTimes fromJson(Object? json) {
    if (json is! Map) return empty;
    final boards = <String, List<BestTime>>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key is! String || value is! List) continue;
      final times = <BestTime>[];
      for (final item in value) {
        final time = BestTime.fromJson(item);
        if (time != null) times.add(time);
      }
      if (times.isNotEmpty) boards[key] = List.unmodifiable(times.take(bestTimesPerBoard));
    }
    return BestTimes._(boards);
  }
}

/// The best times, saved on the host (T15) like the puzzle's and the Arena's
/// settings.
final bestTimesProvider = NotifierProvider<BestTimesNotifier, BestTimes>(BestTimesNotifier.new);

/// Keeps each puzzle's best times and saves them in the host's prefs.
class BestTimesNotifier extends Notifier<BestTimes> {
  static const _key = 'bestTimes';

  /// The prefs key holding the [bestTimesVersion] the times were last cleaned
  /// for (B-012). Absent on a host that has never cleaned them.
  static const _versionKey = 'bestTimesVersion';

  @override
  BestTimes build() {
    final prefs = ref.watch(prefsProvider);
    final log = ref.read(logProvider).sink('host');
    try {
      final raw = _clearRedoneBoards(prefs);
      if (raw == null) return BestTimes.empty;
      return BestTimes.fromJson(jsonDecode(raw));
    } on FormatException catch (error) {
      log('Best times: $error');
      return BestTimes.empty;
    }
  }

  /// Clears the boards of the puzzles redrawn since the saved times' version
  /// (B-012), the once, and returns `bestTimes` as it stands now.
  ///
  /// The version is written first, so badly formed times, which throw out to
  /// [build] and its own report of them, still count as cleared: a Medium time
  /// recorded afterwards is kept on the next start.
  String? _clearRedoneBoards(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if ((prefs.getInt(_versionKey) ?? 0) >= bestTimesVersion) return raw;
    final redone = {
      for (final id in redoneMediumPuzzleIds) ...[
        BestTimes.boardKey(id, team: false),
        BestTimes.boardKey(id, team: true),
      ],
    };
    unawaited(prefs.setInt(_versionKey, bestTimesVersion));
    var kept = raw;
    if (raw != null) {
      final times = jsonDecode(raw);
      if (times is Map<String, Object?>) {
        kept = jsonEncode({...times}..removeWhere((key, _) => redone.contains(key)));
        if (kept != raw) unawaited(prefs.setString(_key, kept));
      }
    }
    return kept;
  }

  /// The times kept for [puzzleId]'s board, fastest first: [BestTimes.boardFor].
  List<BestTime> boardFor(String puzzleId, {required bool team}) => state.boardFor(puzzleId, team: team);

  /// The best time [puzzleId]'s board has, or null when it has none:
  /// [BestTimes.bestFor].
  BestTime? bestFor(String puzzleId, {required bool team}) => state.bestFor(puzzleId, team: team);

  /// Saves [timeMs] for [puzzleId]'s board with [names], and says whether it
  /// beat the board's best and what that best is now (N14: only the fastest
  /// [bestTimesPerBoard] are kept). A time level with the best does not beat
  /// it.
  BestTimeResult record({
    required String puzzleId,
    required bool team,
    required int timeMs,
    required List<String> names,
  }) {
    final key = BestTimes.boardKey(puzzleId, team: team);
    final board = [...state.boardFor(puzzleId, team: team)];
    final best = board.isEmpty ? null : board.first;
    final isRecord = best == null || timeMs < best.timeMs;
    board
      ..add(BestTime(timeMs: timeMs, names: List.unmodifiable(names)))
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    final kept = board.take(bestTimesPerBoard).toList();
    state = state.withBoard(key, kept);
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson())));
    return BestTimeResult(isRecord: isRecord, best: kept.first);
  }
}
