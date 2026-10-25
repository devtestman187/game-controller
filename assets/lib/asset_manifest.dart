/// The single place where both apps look up images and sounds.
///
/// Code refers to assets by logical key (for example [SoundKey.hit]), never by
/// file path, so art and audio can be swapped without touching app code.
/// Images are still drawn as placeholder shapes in code.
library;

import 'package:flutter/services.dart';

/// Package name used when loading assets from this package.
const String assetPackage = 'game_assets';

/// One sound per haptic event type, so audio and haptics fire from the same
/// event (Milestone 5).
enum SoundKey { hit, success, error, rumble }

/// The sound file for each key, relative to this package. Everything in
/// `audio/` is bundled, so replacing a file with one of the same name needs no
/// code change. A file with the same name and the other extension (`.wav`
/// instead of `.ogg`, or the reverse) is found too. Credits: `CREDITS.md`.
const Map<SoundKey, String> soundFiles = {
  SoundKey.hit: 'audio/hit.ogg',
  SoundKey.success: 'audio/success.ogg',
  SoundKey.error: 'audio/error.ogg',
  SoundKey.rumble: 'audio/rumble.ogg',
};

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
