import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart' show CatPreset, Chaos, Level;
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs.dart';
import 'night_state.dart';

/// The quietest timer a night may set: 1.0 is the rules' own pace, so a night never runs faster than them.
const _timerScaleMin = 1.0;

/// The longest timer a night may set (three times the rules' own pace); a value past it is a broken save.
const _timerScaleMax = 3.0;

/// The timer a Kids night plays with: half as fast again, so younger players have time to act.
const _kidsTimerScale = 1.5;

/// How the night picks each game (M17 plan n1h). The director jobs of later batches fill in the others; [host] is
/// the host taps each game, which is today's behaviour.
enum NightPicker { host, shuffle, playlist, rotating, vote }

/// The party night's settings on this host (M17 plan n1h): how long a night is, which games it may play, how hard
/// they may be, how often the cat comes, how fast the timers run, and who picks each game. A night starts from these.
final class NightSettings {
  const NightSettings({
    this.length = NightLength.three,
    this.pool = const <String>{},
    this.difficultyMin = Level.easy,
    this.difficultyMax = Level.hard,
    this.chaos = Chaos.off,
    this.cat = CatPreset.lively,
    this.timerScale = _timerScaleMin,
    this.picker = NightPicker.host,
  }) : assert(timerScale >= _timerScaleMin && timerScale <= _timerScaleMax, 'the timer is 1.0 to 3.0');

  /// The Kids preset: a short night of easy games, the cat calm, and timers at 1.5 so younger players have time.
  static const kids = NightSettings(
    difficultyMax: Level.easy,
    chaos: Chaos.little,
    cat: CatPreset.calm,
    timerScale: _kidsTimerScale,
  );

  /// How many rounds the night plays.
  final NightLength length;

  /// The ids of the games the night may play; empty means every game.
  final Set<String> pool;

  /// The easiest level a game in the night may have.
  final Level difficultyMin;

  /// The hardest level a game in the night may have; never below [difficultyMin].
  final Level difficultyMax;

  /// What the cat does during the night's games.
  final Chaos chaos;

  /// How often the cat comes.
  final CatPreset cat;

  /// How fast the games' timers run, from 1.0 (the rules' pace) to 3.0.
  final double timerScale;

  /// How each game is picked.
  final NightPicker picker;

  /// Whether these settings are the Kids preset.
  bool get isKids => this == kids;

  /// These settings with the named fields changed.
  NightSettings copyWith({
    NightLength? length,
    Set<String>? pool,
    Level? difficultyMin,
    Level? difficultyMax,
    Chaos? chaos,
    CatPreset? cat,
    double? timerScale,
    NightPicker? picker,
  }) {
    // A const constructor cannot compare the levels by index, so the order is checked here.
    final min = difficultyMin ?? this.difficultyMin;
    final max = difficultyMax ?? this.difficultyMax;
    assert(min.index <= max.index, 'the easiest level is not above the hardest');
    return NightSettings(
      length: length ?? this.length,
      pool: pool ?? this.pool,
      difficultyMin: min,
      difficultyMax: max,
      chaos: chaos ?? this.chaos,
      cat: cat ?? this.cat,
      timerScale: timerScale ?? this.timerScale,
      picker: picker ?? this.picker,
    );
  }

  /// The settings as JSON, with enums by name and the pool sorted, so the saved form is the same each time.
  Map<String, Object?> toJson() => {
    'length': length.name,
    'pool': pool.toList()..sort(),
    'difficultyMin': difficultyMin.name,
    'difficultyMax': difficultyMax.name,
    'chaos': chaos.name,
    'cat': cat.name,
    'timerScale': timerScale,
    'picker': picker.name,
  };

  /// The settings saved as [json], or null when it is not a whole, valid set: a missing or wrong-typed field, an
  /// unknown enum name, a minimum level above the maximum, or a timer out of range. Never throws.
  static NightSettings? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final length = _enumNamed(NightLength.values, json['length']);
    final difficultyMin = _enumNamed(Level.values, json['difficultyMin']);
    final difficultyMax = _enumNamed(Level.values, json['difficultyMax']);
    final chaos = _enumNamed(Chaos.values, json['chaos']);
    final cat = _enumNamed(CatPreset.values, json['cat']);
    final picker = _enumNamed(NightPicker.values, json['picker']);
    final rawPool = json['pool'];
    final timerScale = json['timerScale'];
    if (length == null || difficultyMin == null || difficultyMax == null || chaos == null) return null;
    if (cat == null || picker == null || rawPool is! List<Object?> || timerScale is! num) return null;
    if (rawPool.any((id) => id is! String)) return null;
    // Written so that NaN, which compares false to everything, is also out of range.
    if (!(timerScale >= _timerScaleMin && timerScale <= _timerScaleMax)) return null;
    if (difficultyMin.index > difficultyMax.index) return null;
    return NightSettings(
      length: length,
      pool: rawPool.whereType<String>().toSet(),
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      chaos: chaos,
      cat: cat,
      timerScale: timerScale.toDouble(),
      picker: picker,
    );
  }

  /// The value named [name] among [values], or null when no value has that name.
  static T? _enumNamed<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NightSettings &&
      length == other.length &&
      _samePool(pool, other.pool) &&
      difficultyMin == other.difficultyMin &&
      difficultyMax == other.difficultyMax &&
      chaos == other.chaos &&
      cat == other.cat &&
      timerScale == other.timerScale &&
      picker == other.picker;

  /// The pool compared as a set: the same ids in any order are the same pool.
  static bool _samePool(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  /// The hash of the pool does not depend on its order, to match [_samePool].
  @override
  int get hashCode => Object.hash(
    length,
    pool.fold<int>(0, (hash, id) => hash ^ id.hashCode),
    difficultyMin,
    difficultyMax,
    chaos,
    cat,
    timerScale,
    picker,
  );
}

/// Saves and loads the night's settings on the host's prefs (JSON under [_key]).
final class NightSettingsStore {
  const NightSettingsStore(this._prefs);

  /// The prefs key the settings are kept under.
  static const _key = 'party_night_settings_v1';

  final SharedPreferences _prefs;

  /// The saved settings, or the defaults when none is saved. A saved value that is broken is removed, and the
  /// defaults are used: a host has no use for a broken save.
  NightSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const NightSettings();
    final settings = NightSettings.tryFromJson(_decode(raw));
    if (settings != null) return settings;
    unawaited(_prefs.remove(_key));
    return const NightSettings();
  }

  /// Saves [settings] in place of any saved ones.
  Future<void> save(NightSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  /// The JSON in [raw], or null when it is not JSON at all.
  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// The night's settings, kept on this host and read by the night's start.
final nightSettingsProvider = NotifierProvider<NightSettingsNotifier, NightSettings>(NightSettingsNotifier.new);

/// Holds the night's settings and saves each change.
class NightSettingsNotifier extends Notifier<NightSettings> {
  @override
  NightSettings build() => NightSettingsStore(ref.watch(prefsProvider)).load();

  /// Replaces the settings with [settings] and saves them.
  void update(NightSettings settings) {
    state = settings;
    unawaited(NightSettingsStore(ref.read(prefsProvider)).save(settings));
  }

  /// Sets the Kids preset and saves it.
  void useKids() => update(NightSettings.kids);
}
