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
    this.join,
    this.wander = false,
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

  /// What ends the shot: `results`, `seconds` (with [endAfterS]), or
  /// `game_start` (a pre-roll that only has to get the match started).
  final String endAfter;

  /// Seconds of play, when [endAfter] is `seconds`.
  final int? endAfterS;

  /// The join pre-roll, when the scene starts on the join screen: the seats to
  /// put on a side, in order, and who starts the match.
  final JoinPlan? join;

  /// Arena only: the seats weave between waypoints instead of racing to the
  /// goal, so a round is never won and the picture never stops for the round
  /// break (see [ArenaBrain.wander]). The arena takes M2-M4 set it.
  final bool wander;

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
    if (endAfter != 'results' && endAfter != 'seconds' && endAfter != 'game_start') {
      throw FormatException('$source: unknown endAfter "$endAfter" (expected "results", "seconds" or "game_start")');
    }
    final endAfterS = endAfter == 'seconds' ? integer(raw['endAfterS'], '"endAfterS"') : null;
    if (endAfter == 'seconds' && (endAfterS == null || endAfterS <= 0)) {
      throw FormatException('$source: endAfter "seconds" needs a positive "endAfterS"');
    }

    final rawWander = raw['wander'];
    if (rawWander != null && rawWander is! bool) {
      throw FormatException('$source: "wander" must be true or false');
    }
    if (rawWander == true && game != 'arena') {
      throw FormatException('$source: "wander" is arena only');
    }

    JoinPlan? join;
    final rawJoin = raw['join'];
    if (rawJoin != null) {
      if (rawJoin is! Map<String, dynamic>) throw FormatException('$source: "join" must be an object');
      final rawOrder = rawJoin['order'];
      if (rawOrder is! List || rawOrder.isEmpty) {
        throw FormatException('$source: "join" needs a non-empty "order" list of seat ids');
      }
      final order = <String>[];
      for (final s in rawOrder) {
        if (s is! String || !seats.containsKey(s)) {
          throw FormatException('$source: join order names "$s", which "seats" does not define');
        }
        order.add(s);
      }
      final start = rawJoin['start'];
      if (start != null && (start is! String || !seats.containsKey(start))) {
        throw FormatException('$source: join "start" names "$start", which "seats" does not define');
      }
      join = JoinPlan(order: List.unmodifiable(order), start: start as String?);
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
      join: join,
      wander: rawWander == true,
    );
  }
}

/// The join pre-roll from a scene file: `"join": {"order": ["P1", "Bot 2"],
/// "start": "P1"}`. The director puts each seat on a side in this order,
/// confirming each one on the TV before the next, then has [start] press
/// Start.
final class JoinPlan {
  const JoinPlan({required this.order, this.start});

  final List<String> order;

  /// The seat that starts the match; the first seat by default.
  final String? start;

  String get startSeat => start ?? order.first;
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
enum GoalKind { pick, place, wrongDrop, carryBigAlone, joinBigCarry, waitFor, idle, navigate, layout, pace }

/// One step of a seat's script.
final class Goal {
  const Goal(this.kind, {this.piece, this.event, this.timeoutMs, this.ms, this.keys, this.mode, this.finishMs});

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

  /// For [GoalKind.layout]: the input mode to switch the phone to (`sticks`,
  /// `dpad` or `gyro`), at this point in the scene — for a shot whose phone has
  /// to show Sticks once the game is up, while the menus before it only allow
  /// the D-pad.
  final String? mode;

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
      case 'layout':
        if (value is! String || !_modes.contains(value)) {
          throw FormatException(
            '$source: seat "$seat" layout has unknown mode "$value" (expected ${_modes.join(', ')})',
          );
        }
        return Goal(GoalKind.layout, mode: value);
      case 'pace':
        return Goal(GoalKind.pace, finishMs: integer(value, 'pace finishMs'));
      default:
        throw FormatException(
          '$source: seat "$seat" has unknown goal "$key" '
          '(expected pick, place, wrongDrop, carryBigAlone, joinBigCarry, waitFor, idle, navigate, layout, pace)',
        );
    }
  }

  static const _presses = {'up', 'down', 'left', 'right', 'a', 'b', 'start'};

  /// The phone input modes a scene may switch to (the app's own mode switch).
  static const _modes = {'sticks', 'dpad', 'gyro'};

  static String _name(Object? v, String source, String seat, String goal) {
    if (v is! String || v.isEmpty) throw FormatException('$source: seat "$seat" $goal needs a piece name');
    return v;
  }
}
