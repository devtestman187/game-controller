import 'dart:async';
import 'dart:convert';

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

/// Saves and resets the puzzle's playtest settings.
class PuzzleSettingsNotifier extends Notifier<PuzzleSettings> {
  static const _key = 'puzzleSettings';

  @override
  PuzzleSettings build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return hostPuzzleDefaults;
    try {
      return PuzzleSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return hostPuzzleDefaults;
    }
  }

  void set(PuzzleSettings settings) {
    state = settings;
    unawaited(ref.read(prefsProvider).setString(_key, jsonEncode(settings.toJson())));
  }

  void reset() => set(hostPuzzleDefaults);
}
