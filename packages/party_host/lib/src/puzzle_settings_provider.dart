import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_game/puzzle_game.dart';

import 'prefs.dart';

/// The puzzle's playtest settings (PRD v2 T16), saved on the host.
final puzzleSettingsProvider = NotifierProvider<PuzzleSettingsNotifier, PuzzleSettings>(PuzzleSettingsNotifier.new);

/// The settings a host that has saved none plays with: the library's defaults,
/// but with the cat on A little — the Chaos setting a new host starts on
/// (PRD v2 G3, party-night N12), while the rules' own default stays Off, so a
/// build without a host plays as it always did.
final hostPuzzleDefaults = PuzzleSettings.defaults.withValue('chaos', Chaos.little.name);

/// A device test's `--dart-define=CAT_PRESET=wild` (b006): read here, as the TV
/// app reads its own `SHARE_VIEW` define, so the cat can be tried on a device
/// without the settings screen, and `puzzle_game` keeps no build-mode branch.
/// Empty in a build that names none.
const catPresetDefine = String.fromEnvironment('CAT_PRESET');

/// [settings] with a debug build's CAT_PRESET define applied: the Cat setting
/// the define names when [debug] and [define] name one of them, else [settings]
/// as it was, so a release build and a typo both play the saved setting.
PuzzleSettings withCatPresetDefine(
  PuzzleSettings settings, {
  String define = catPresetDefine,
  bool debug = kDebugMode,
}) {
  if (!debug || define.isEmpty) return settings;
  final preset = CatPreset.values.where((p) => p.name == define).firstOrNull;
  return preset == null ? settings : settings.withValue('catPreset', preset.name);
}

/// Saves and resets the puzzle's playtest settings.
class PuzzleSettingsNotifier extends Notifier<PuzzleSettings> {
  static const _key = 'puzzleSettings';

  @override
  PuzzleSettings build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return withCatPresetDefine(hostPuzzleDefaults);
    try {
      return withCatPresetDefine(PuzzleSettings.fromJson(jsonDecode(raw)));
    } catch (_) {
      return withCatPresetDefine(hostPuzzleDefaults);
    }
  }

  void set(PuzzleSettings settings) {
    state = settings;
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(settings.toJson())));
  }

  void reset() => set(hostPuzzleDefaults);
}
