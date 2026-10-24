/// The single place where both apps look up images and sounds.
///
/// Code refers to assets by logical key (for example [SoundKey.hit]), never by
/// file path, so art and audio can be swapped without touching app code.
/// Until real assets exist, apps draw placeholder shapes in code and sounds are
/// silent stubs.
library;

/// Package name used when loading assets from this package.
const String assetPackage = 'game_assets';

/// One sound per haptic event type, so audio and haptics fire from the same
/// event (Milestone 4). The loader will look for `audio/tv/<name>.wav` or
/// `.ogg`, so a replacement file only needs the matching name.
enum SoundKey { hit, success, error, rumble }
