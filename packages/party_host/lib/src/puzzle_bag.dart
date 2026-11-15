import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'prefs.dart';
import 'providers.dart';

/// Each level's puzzles in the order they play (B-009, design section 2):
/// every puzzle of a level comes once before any of them comes back, so a
/// night of Shape Race rounds never shows a board twice early.
///
/// A draw takes the next id. A level whose bag is empty fills with every id it
/// ships, shuffled, and the id just played goes to the end, so a new cycle
/// doesn't open with the puzzle just finished. An id a build no longer ships
/// leaves the bag, and an id it adds joins it, shuffled, so a new puzzle is
/// seen before any repeat. Each level has a bag of its own, so Easy, Medium
/// and Hard turn independently. The Look (colour theme) never touches it: no
/// puzzle has a per-look variant, so the palette's turn to night leaves the
/// order alone.
///
/// It is a value: a draw hands back the bag that follows it, and the host
/// saves that one.
@immutable
final class PuzzleBag {
  const PuzzleBag._(this._waiting, this._playedLast, this._playedThisCycle);

  /// A host that has played no round yet.
  static const empty = PuzzleBag._({}, {}, {});

  /// Each level's ids still to play, next first, under its [Level.name].
  final Map<String, List<String>> _waiting;

  /// Each level's id played last this session, so a new cycle doesn't open
  /// with it. This one is not saved: after the app closes, a cycle may open
  /// with the puzzle just finished, and the rematch's guard covers that case.
  final Map<String, String> _playedLast;

  /// Each level's ids already played since its bag last filled, so an id a
  /// build adds can be told from one this cycle has had. A bag read back from
  /// the prefs starts it from the ids the build ships and the bag doesn't hold,
  /// which were all played: an id a build adds then waits for the next cycle,
  /// where a repeat could otherwise slip in.
  final Map<String, Set<String>> _playedThisCycle;

  /// The ids of [level] still to play, next first.
  List<String> waitingFor(Level level) => _waiting[level.name] ?? const [];

  /// The id of [level] to play next, among the [ids] this build ships for it,
  /// with the bag that follows the draw: the caller saves that one. Null only
  /// when [level] has no puzzles.
  ///
  /// A draw that finds the bag empty fills it with every id of the level,
  /// shuffled from [random]; a shuffle that puts [avoidId] first moves it
  /// to the end of the bag, so a rematch never gets the round just played while
  /// another puzzle is left.
  ({String? id, PuzzleBag following}) draw({
    required Level level,
    required List<String> ids,
    required Random random,
    String? avoidId,
  }) {
    if (ids.isEmpty) return (id: null, following: this);
    final last = _playedLast[level.name];
    var waiting = [
      for (final id in waitingFor(level))
        if (ids.contains(id)) id,
    ];
    Set<String>? played;
    if (waiting.isEmpty) {
      waiting = [...ids]..shuffle(random);
      if (last != null && waiting.length > 1) {
        waiting
          ..remove(last)
          ..add(last);
      }
    } else {
      played = _playedThisCycle[level.name] ?? _cycleSoFar(ids, waiting);
      final added = [
        for (final id in ids)
          if (!waiting.contains(id) && !played.contains(id)) id,
      ]..shuffle(random);
      for (final id in added) {
        waiting.insert(random.nextInt(waiting.length + 1), id);
      }
    }
    if (waiting.length > 1 && waiting.first == avoidId) {
      final avoided = waiting.removeAt(0);
      waiting.add(avoided);
    }
    final id = waiting.first;
    final cycle = {...?played, id};
    return (
      id: id,
      following: PuzzleBag._(
        {..._waiting, level.name: List.unmodifiable(waiting.sublist(1))},
        {..._playedLast, level.name: id},
        {..._playedThisCycle, level.name: cycle},
      ),
    );
  }

  /// [id] was chosen by hand on [level]: it leaves the bag, so `any <level>`
  /// doesn't come back to it before the level's other puzzles.
  PuzzleBag withPlayed(Level level, String id) {
    final waiting = [...waitingFor(level)]..remove(id);
    final cycle = {...?_playedThisCycle[level.name], id};
    return PuzzleBag._({..._waiting, level.name: List.unmodifiable(waiting)}, {..._playedLast, level.name: id}, {
      ..._playedThisCycle,
      level.name: cycle,
    });
  }

  /// The ids of [level] this cycle has had, when the bag comes from the prefs
  /// and the session has not drawn for it yet: every id the build ships and the
  /// bag doesn't hold was played (or is new, and then it waits for the cycle
  /// after, so no repeat slips in).
  static Set<String> _cycleSoFar(List<String> ids, List<String> waiting) => {
    for (final id in ids)
      if (!waiting.contains(id)) id,
  };

  /// The bag as the host saves it: each level's ids still to play, in order. A
  /// level with none left is left out, so an untouched level keeps no key.
  Map<String, Object?> toJson() => {
    for (final MapEntry(:key, :value) in _waiting.entries)
      if (value.isNotEmpty) key: value,
  };

  /// The bag [json] holds. A level this build has no puzzles for, and an id
  /// that isn't a name, are left out.
  static PuzzleBag fromJson(Object? json) {
    if (json is! Map) return empty;
    final levels = Level.values.asNameMap();
    final waiting = <String, List<String>>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key is! String || !levels.containsKey(key) || value is! List) continue;
      final ids = <String>[];
      for (final id in value.whereType<String>()) {
        if (!ids.contains(id)) ids.add(id);
      }
      if (ids.isNotEmpty) waiting[key] = List.unmodifiable(ids);
    }
    return PuzzleBag._(waiting, const {}, const {});
  }
}

/// Each level's bag of puzzles, saved on the host (B-009) beside the puzzle's
/// best times, so the order survives the app closing.
final puzzleBagProvider = NotifierProvider<PuzzleBagNotifier, PuzzleBag>(PuzzleBagNotifier.new);

/// Draws each level's next puzzle from its bag and saves the bag.
class PuzzleBagNotifier extends Notifier<PuzzleBag> {
  static const _key = 'puzzleBag';

  @override
  PuzzleBag build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return PuzzleBag.empty;
    final log = ref.read(logProvider).sink('host');
    try {
      return PuzzleBag.fromJson(jsonDecode(raw));
    } on FormatException catch (error) {
      log('Puzzle bag: $error');
      return PuzzleBag.empty;
    }
  }

  /// The id [level] plays next among [ids]: [PuzzleBag.draw], with the bag it
  /// leaves saved.
  String? draw({required Level level, required List<String> ids, required Random random, String? avoidId}) {
    final drawn = state.draw(level: level, ids: ids, random: random, avoidId: avoidId);
    if (drawn.id != null) _save(drawn.following);
    return drawn.id;
  }

  /// [id] was chosen by hand on [level]: [PuzzleBag.withPlayed], saved.
  void played(Level level, String id) => _save(state.withPlayed(level, id));

  void _save(PuzzleBag bag) {
    state = bag;
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(bag.toJson())));
  }
}
