import 'dart:convert';
import 'dart:io';

/// A scene script: one shot's choreography (docs/demo-video-runbook.md 2.3).
/// Parsed from the JSON in `tools/demo/scenes/`, it says which game, which
/// puzzle and seed, which seat plays which side, what each seat does, and when
/// the shot ends.
final class Scene {
  const Scene({
    required this.game,
    required this.seed,
    required this.teams,
    required this.seats,
    this.puzzle,
    this.screenStart = 'home',
    this.pace = const {},
    this.endAfter = 'results',
    this.endAfterS,
  });

  /// `puzzle` or `arena`.
  final String game;

  /// The puzzle id, for a puzzle scene.
  final String? puzzle;

  /// The game's seed, so a take is repeatable.
  final int seed;

  /// Where the shot starts: `home`, `join`, `play`, `menus`.
  final String screenStart;

  /// Side name (`left`, `right`) to the seat ids on it.
  final Map<String, List<String>> teams;

  /// Seat id (`P1`, `Bot 2`, …) to what it does.
  final Map<String, Seat> seats;

  /// Side name to the moment that side should finish, in ms after
  /// `game_start`.
  final Map<String, int> pace;

  /// What ends the shot: `results`, or `seconds` (with [endAfterS]).
  final String endAfter;

  /// Seconds of play, when [endAfter] is `seconds`.
  final int? endAfterS;

  /// The side [seat] plays on, or null if it isn't on one.
  String? sideOf(String seat) {
    for (final MapEntry(key: side, value: ids) in teams.entries) {
      if (ids.contains(seat)) return side;
    }
    return null;
  }

  /// The seat in the phone slot, if the scene has one.
  String? get phoneSeat {
    for (final MapEntry(key: id, value: seat) in seats.entries) {
      if (seat.via == 'phone') return id;
    }
    return null;
  }

  /// Reads and parses a scene file, with the file name in any error.
  static Scene fromFile(String path) {
    final String text;
    try {
      text = File(path).readAsStringSync();
    } on FileSystemException catch (e) {
      throw FormatException('cannot read scene $path: ${e.message}');
    }
    return parse(text, source: path);
  }

  /// Parses scene JSON. Throws [FormatException] with a clear message for
  /// anything unknown, so a typo fails at load time, not mid-take.
  static Scene parse(String text, {String source = 'scene'}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('$source: not valid JSON (${e.message})');
    }
    if (decoded is! Map<String, dynamic>) throw FormatException('$source: the scene must be a JSON object');
    final raw = decoded;

    String str(String key, {String? fallback, bool required = false}) {
      final v = raw[key];
      if (v == null) {
        if (required) throw FormatException('$source: missing "$key"');
        return fallback!;
      }
      if (v is! String || v.isEmpty) throw FormatException('$source: "$key" must be a non-empty string');
      return v;
    }

    int integer(Object? v, String where) {
      if (v is int) return v;
      if (v is double && v == v.roundToDouble()) return v.round();
      throw FormatException('$source: $where must be a whole number');
    }

    final game = str('game', required: true);
    if (game != 'puzzle' && game != 'arena') {
      throw FormatException('$source: unknown game "$game" (expected "puzzle" or "arena")');
    }

    final seed = raw.containsKey('seed') ? integer(raw['seed'], '"seed"') : 0;

    final teams = <String, List<String>>{};
    final rawTeams = raw['teams'];
    if (rawTeams is Map<String, dynamic>) {
      for (final MapEntry(:key, :value) in rawTeams.entries) {
        if (key != 'left' && key != 'right') {
          throw FormatException('$source: unknown team side "$key" (expected "left" or "right")');
        }
        if (value is! List) throw FormatException('$source: team "$key" must be a list of seat ids');
        teams[key] = [for (final id in value) id as String];
      }
    } else if (rawTeams != null) {
      throw FormatException('$source: "teams" must be an object of side to seats');
    }

    final seats = <String, Seat>{};
    final rawSeats = raw['seats'];
    if (rawSeats is! Map<String, dynamic> || rawSeats.isEmpty) {
      throw FormatException('$source: "seats" must be an object with at least one seat');
    }
    for (final MapEntry(:key, :value) in rawSeats.entries) {
      seats[key] = Seat._parse(value, source, key, integer);
    }

    for (final MapEntry(key: side, value: ids) in teams.entries) {
      for (final id in ids) {
        if (!seats.containsKey(id)) {
          throw FormatException('$source: team "$side" names seat "$id", which "seats" does not define');
        }
      }
    }

    final pace = <String, int>{};
    final rawPace = raw['pace'];
    if (rawPace is Map<String, dynamic>) {
      for (final MapEntry(:key, :value) in rawPace.entries) {
        if (!teams.containsKey(key)) throw FormatException('$source: pace for unknown side "$key"');
        pace[key] = integer(value, 'pace "$key"');
      }
    } else if (rawPace != null) {
      throw FormatException('$source: "pace" must be an object of side to milliseconds');
    }

    final endAfter = str('endAfter', fallback: 'results');
    if (endAfter != 'results' && endAfter != 'seconds') {
      throw FormatException('$source: unknown endAfter "$endAfter" (expected "results" or "seconds")');
    }
    final endAfterS = endAfter == 'seconds' ? integer(raw['endAfterS'], '"endAfterS"') : null;
    if (endAfter == 'seconds' && (endAfterS == null || endAfterS <= 0)) {
      throw FormatException('$source: endAfter "seconds" needs a positive "endAfterS"');
    }

    return Scene(
      game: game,
      puzzle: raw['puzzle'] is String ? raw['puzzle'] as String : null,
      seed: seed,
      screenStart: str('screenStart', fallback: 'home'),
      teams: Map.unmodifiable(teams),
      seats: Map.unmodifiable(seats),
      pace: Map.unmodifiable(pace),
      endAfter: endAfter,
      endAfterS: endAfterS,
    );
  }
}

/// One seat: how it connects and what it does, in order.
final class Seat {
  const Seat({required this.via, required this.mode, required this.goals});

  /// `phone` (the emulator, driven by the touch driver) or `bot`.
  final String via;

  /// The phone's input mode: `sticks`, `dpad` or `gyro`. Bots always use
  /// sticks.
  final String mode;

  final List<Goal> goals;

  static Seat _parse(Object? raw, String source, String id, int Function(Object?, String) integer) {
    if (raw is! Map<String, dynamic>) throw FormatException('$source: seat "$id" must be an object');
    final via = raw['via'] as String? ?? 'bot';
    if (via != 'phone' && via != 'bot') {
      throw FormatException('$source: seat "$id" has via "$via" (expected "phone" or "bot")');
    }
    final mode = raw['mode'] as String? ?? 'sticks';
    if (mode != 'sticks' && mode != 'dpad' && mode != 'gyro') {
      throw FormatException('$source: seat "$id" has mode "$mode" (expected sticks, dpad or gyro)');
    }
    final goals = <Goal>[];
    final rawGoals = raw['goals'];
    if (rawGoals is! List) throw FormatException('$source: seat "$id" needs a "goals" list');
    for (final g in rawGoals) {
      goals.add(Goal._parse(g, source, id, integer));
    }
    return Seat(via: via, mode: mode, goals: goals);
  }
}

/// What a seat does. Each one is a JSON object with exactly one key.
enum GoalKind { pick, place, wrongDrop, carryBigAlone, joinBigCarry, waitFor, idle, navigate, pace }

/// One step of a seat's script.
final class Goal {
  const Goal(this.kind, {this.piece, this.event, this.timeoutMs, this.ms, this.keys, this.finishMs});

  final GoalKind kind;

  /// For [GoalKind.pick], [GoalKind.wrongDrop], [GoalKind.carryBigAlone] and
  /// [GoalKind.joinBigCarry]: the piece's name in the puzzle.
  final String? piece;

  /// For [GoalKind.waitFor]: the event name.
  final String? event;

  /// For [GoalKind.waitFor]: how long to wait before giving up.
  final int? timeoutMs;

  /// For [GoalKind.idle]: how long.
  final int? ms;

  /// For [GoalKind.navigate]: the presses, in order.
  final List<String>? keys;

  /// For [GoalKind.pace]: the finish time, in ms after `game_start`.
  final int? finishMs;

  static Goal _parse(Object? raw, String source, String seat, int Function(Object?, String) integer) {
    if (raw is! Map<String, dynamic> || raw.length != 1) {
      throw FormatException('$source: seat "$seat" has a goal that is not one object with one key: $raw');
    }
    final MapEntry(:key, :value) = raw.entries.first;
    switch (key) {
      case 'pick':
        return Goal(GoalKind.pick, piece: _name(value, source, seat, key));
      case 'place':
        return const Goal(GoalKind.place);
      case 'wrongDrop':
        return Goal(GoalKind.wrongDrop, piece: _name(value, source, seat, key));
      case 'carryBigAlone':
        return Goal(GoalKind.carryBigAlone, piece: _name(value, source, seat, key));
      case 'joinBigCarry':
        return Goal(GoalKind.joinBigCarry, piece: value is String ? value : null);
      case 'waitFor':
        if (value is String) return Goal(GoalKind.waitFor, event: value, timeoutMs: 15000);
        if (value is Map<String, dynamic>) {
          final event = value['event'];
          if (event is! String || event.isEmpty) {
            throw FormatException('$source: seat "$seat" waitFor needs an "event" name');
          }
          return Goal(
            GoalKind.waitFor,
            event: event,
            timeoutMs: value.containsKey('timeoutMs') ? integer(value['timeoutMs'], 'waitFor timeoutMs') : 15000,
          );
        }
        throw FormatException('$source: seat "$seat" waitFor must be an event name or an object');
      case 'idle':
        return Goal(GoalKind.idle, ms: integer(value, 'idle milliseconds'));
      case 'navigate':
        if (value is! List || value.isEmpty) {
          throw FormatException('$source: seat "$seat" navigate needs a non-empty list of presses');
        }
        final keys = <String>[];
        for (final k in value) {
          if (k is! String || !_presses.contains(k)) {
            throw FormatException(
              '$source: seat "$seat" navigate has unknown press "$k" (expected ${_presses.join(', ')})',
            );
          }
          keys.add(k);
        }
        return Goal(GoalKind.navigate, keys: List.unmodifiable(keys));
      case 'pace':
        return Goal(GoalKind.pace, finishMs: integer(value, 'pace finishMs'));
      default:
        throw FormatException(
          '$source: seat "$seat" has unknown goal "$key" '
          '(expected pick, place, wrongDrop, carryBigAlone, joinBigCarry, waitFor, idle, navigate, pace)',
        );
    }
  }

  static const _presses = {'up', 'down', 'left', 'right', 'a', 'b', 'start'};

  static String _name(Object? v, String source, String seat, String goal) {
    if (v is! String || v.isEmpty) throw FormatException('$source: seat "$seat" $goal needs a piece name');
    return v;
  }
}
