import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol/protocol.dart' show PlayerCharacter;
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs.dart';
import 'night_award_results.dart';
import 'night_awards.dart';
import 'night_state.dart';

/// The party night kept on this host between starts (design section 2 N5): the
/// night is saved after each change, so a host that restarts resumes it, and the
/// save is cleared when the night ends.
final class NightSave {
  const NightSave(this._prefs);

  /// The prefs key the night's JSON is kept under.
  static const _key = 'party_night_v1';

  final SharedPreferences _prefs;

  /// The saved night, or null when none is saved. A save that is corrupt, names
  /// an unknown award or is a night already over is cleared, and the night starts
  /// fresh: nothing is reported, since a host has no use for a broken save.
  NightState? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    final night = _readNight(_decode(raw));
    if (night != null && !night.isOver) return night;
    clear();
    return null;
  }

  /// Saves [night] in place of any saved one.
  void save(NightState night) => unawaited(_prefs.setString(_key, jsonEncode(_nightJson(night))));

  /// Forgets the saved night.
  void clear() => unawaited(_prefs.remove(_key));
}

/// What a saved night holds, as [NightSave] reads it back: every field of a [NightState] (kept here, so the
/// night's file stays under its size limit).
typedef SavedNight = ({
  NightLength length,
  int round,
  List<NightAward> awards,
  Map<String, int> totals,
  Map<String, Map<String, int>> counters,
  Map<String, int> roundsWon,
  Set<String> played,
  Map<String, int> lastRoundPoints,
  Map<String, NightPlayer> seen,
  List<NightAwardOutcome> outcomes,
  List<String> maps,
  bool isEndedEarly,
});

/// The night's save on this host's prefs.
final nightSaveProvider = Provider<NightSave>((ref) => NightSave(ref.watch(prefsProvider)));

/// The night as JSON: every field, so [NightState.restored] rebuilds it as it was.
Map<String, Object?> _nightJson(NightState night) => {
  'length': night.rounds,
  'round': night.round,
  'awards': [for (final award in night.awards) award.name],
  'totals': night.totals,
  'counters': night.counters,
  'roundsWon': night.roundsWon,
  'played': night.played.toList(),
  'lastRoundPoints': night.lastRoundPoints,
  'seen': {
    for (final MapEntry(:key, :value) in night.seen.entries)
      key: {'number': value.number, 'nickname': value.nickname, 'character': value.character?.toJson()},
  },
  'outcomes': [
    for (final outcome in night.outcomes)
      {'award': outcome.award.name, 'winners': outcome.winners, 'value': outcome.value},
  ],
  'maps': night.maps,
  'isEndedEarly': night.isEndedEarly,
};

/// [raw] as JSON, or null when it is not JSON at all.
Object? _decode(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

/// The night [json] holds, or null when any part of it is missing or the wrong kind.
NightState? _readNight(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final length = NightLength.values.where((option) => option.rounds == json['length']).firstOrNull;
  final round = json['round'];
  if (length == null || round is! int || round < 0 || round > length.rounds) return null;
  final awards = _list(json['awards'], _award);
  final played = _list(json['played'], _as<String>);
  final maps = _list(json['maps'], _as<String>);
  final outcomes = _list(json['outcomes'], _outcome);
  final seen = _map(json['seen'], _player);
  final counters = _map(json['counters'], (counter) => _map(counter, _as<int>));
  final totals = _map(json['totals'], _as<int>);
  final roundsWon = _map(json['roundsWon'], _as<int>);
  final lastRoundPoints = _map(json['lastRoundPoints'], _as<int>);
  final isEndedEarly = _as<bool>(json['isEndedEarly']);
  if (awards == null || awards.length != nightAwardsPerNight || played == null || maps == null) return null;
  if (outcomes == null || seen == null || counters == null || totals == null || roundsWon == null) return null;
  if (lastRoundPoints == null || isEndedEarly == null) return null;
  return NightState.restored((
    length: length,
    round: round,
    awards: awards,
    totals: totals,
    counters: counters,
    roundsWon: roundsWon,
    played: played.toSet(),
    lastRoundPoints: lastRoundPoints,
    seen: seen,
    outcomes: outcomes,
    maps: maps,
    isEndedEarly: isEndedEarly,
  ));
}

/// [value] when it is a [T], else null.
T? _as<T>(Object? value) => value is T ? value : null;

/// Each item of the JSON list [json] read by [read], or null when [json] is not
/// a list or one of its items cannot be read.
List<T>? _list<T>(Object? json, T? Function(Object?) read) {
  if (json is! List<Object?>) return null;
  final items = [for (final item in json) read(item)].whereType<T>().toList();
  return items.length == json.length ? items : null;
}

/// Each entry of the JSON object [json] read by [read], or null when [json] is
/// not an object or one of its values cannot be read.
Map<String, V>? _map<V>(Object? json, V? Function(Object?) read) {
  if (json is! Map<String, Object?>) return null;
  final out = <String, V>{};
  for (final MapEntry(:key, :value) in json.entries) {
    final item = read(value);
    if (item == null) return null;
    out[key] = item;
  }
  return out;
}

/// The award named [json], or null when no award has that name.
NightAward? _award(Object? json) => NightAward.values.where((award) => award.name == json).firstOrNull;

/// What an award came to, read from [json]: the award, its winners and the number they share.
NightAwardOutcome? _outcome(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final award = _award(json['award']);
  final winners = _list(json['winners'], _as<String>);
  final value = json['value'];
  if (award == null || winners == null || (value != null && value is! int)) return null;
  return NightAwardOutcome(award: award, winners: winners, value: value is int ? value : null);
}

/// A player the night remembers, read from [json]: their number, nickname and
/// character (a character that cannot be read drops the night, like any field).
NightPlayer? _player(Object? json) {
  if (json is! Map<String, Object?>) return null;
  final number = _as<int>(json['number']);
  final nickname = json['nickname'];
  final character = json['character'];
  final wearing = character == null ? null : _character(character);
  if (number == null || (nickname != null && nickname is! String) || (character != null && wearing == null)) {
    return null;
  }
  return (number: number, nickname: nickname is String ? nickname : null, character: wearing);
}

/// The character [json] holds, or null when it is malformed (PlayerCharacter.fromJson throws on that).
PlayerCharacter? _character(Object? json) {
  try {
    return PlayerCharacter.fromJson(json);
  } on FormatException {
    return null;
  }
}
