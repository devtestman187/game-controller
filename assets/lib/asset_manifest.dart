/// The single place where both apps look up images and sounds.
///
/// Code refers to assets by logical key (for example [SoundKey.hit]), never by
/// file path, so art and audio can be swapped without touching app code.
/// Images are still drawn as placeholder shapes in code.
library;

import 'package:flutter/services.dart';

/// Package name used when loading assets from this package.
const String assetPackage = 'game_assets';

/// The game sounds, played by event name through the game host (PRD v2 S5):
/// one per haptic event type that has a sound (M5, and the puzzle's in M10),
/// plus sounds without a haptic (pickup, time-up), by [eventName].
///
/// The last six are the host's own cues (M13 design section 8, L5), played by
/// the screens rather than by a game: the lobby music (a seamless loop), the
/// 3-2-1 before a round, a phone joining the host, and the round's music at its
/// three tempos (the same piece at 120, 138 and 156 BPM).
///
/// The ten before them are the Arena's (M14 design section 8): its seven
/// one-shots and its own music at three tempos, which the Bumper Round plays.
///
/// The five before those are the party night's (M14 design section 11): the
/// cat's warning, a soft pop under a points pop-up, an award, a won round or
/// the night's winner, and a new best time.
enum SoundKey {
  hit,
  success,
  error,
  rumble,
  snap,
  wrong,
  tick,
  pickup,
  timeUp('time_up'),
  help,
  dash,
  bump,
  bumpBig('bump_big'),
  coin,
  coinGold('coin_gold'),
  coinLost('coin_lost'),
  coinAppear('coin_appear'),
  arena,
  arenaHurry('arena_hurry'),
  arenaFinal('arena_final'),
  meow,
  points,
  fanfare,
  celebration,
  newRecord('new_record'),
  lobby,
  countdown,
  playerJoined('player_joined'),
  round,
  roundHurry('round_hurry'),
  roundFinal('round_final');

  const SoundKey([this._file]);

  final String? _file;

  /// The event name games use, e.g. `time_up`.
  String get eventName => _file ?? name;

  static SoundKey? byEventName(String name) => values.where((k) => k.eventName == name).firstOrNull;
}

/// The sound file for each key, relative to this package. Everything in
/// `audio/` is bundled, so replacing a file with one of the same name needs no
/// code change. A file with the same name and the other extension (`.wav`
/// instead of `.ogg`, or the reverse) is found too. Credits: `CREDITS.md`.
final Map<SoundKey, String> soundFiles = {for (final k in SoundKey.values) k: 'audio/${k.eventName}.ogg'};

/// The key Flutter bundles a file of this package under, for
/// `rootBundle.load` and audio players.
String assetKey(String path) => 'packages/$assetPackage/$path';

/// Finds the bundled file for [key]: the one in [soundFiles], or the same
/// name as `.wav` / `.ogg`. Returns null when neither is bundled, so the app
/// plays nothing for it (a silent stub) instead of failing.
Future<String?> findSound(SoundKey key, {AssetBundle? bundle}) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle ?? rootBundle);
  final bundled = manifest.listAssets().toSet();
  final listed = soundFiles[key]!;
  final stem = listed.substring(0, listed.lastIndexOf('.'));
  for (final path in [listed, '$stem.ogg', '$stem.wav']) {
    if (bundled.contains(assetKey(path))) return assetKey(path);
  }
  return null;
}
