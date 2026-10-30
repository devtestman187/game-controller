# Asset credits

Every image and sound in `/assets` (and every platform icon or banner made from them) is listed here.
Only assets whose license allows commercial use are accepted (CC0 preferred, e.g. Kenney.nl).
Update this file in the same commit that adds, replaces or removes an asset.

| File | Used for | Source URL | Creator | License |
| --- | --- | --- | --- | --- |
| `branding/*.png` and every app icon made from them (Android `mipmap-*`, the TV banner, iOS `AppIcon`, the Windows `app_icon.ico`, `site/icon.png`) | Thumb Party and Thumb Party TV icons, the TV banner and the Play store graphics | Drawn by `tools/branding/make-artwork.ps1` (System.Drawing, no third-party content) | Project | CC0 1.0 |
| `branding/screenshots/*.png` | Store screenshots | Captured from the apps (Android 12 emulator, Windows build) | Project | CC0 1.0 |
| `audio/hit.ogg` | TV sound for the **hit** event (from `explosionCrunch_003.ogg`) | https://kenney.nl/assets/sci-fi-sounds | Kenney (Sci-Fi Sounds) | CC0 1.0 |
| `audio/success.ogg` | TV sound for the **success** event (from `computerNoise_003.ogg`) | https://kenney.nl/assets/sci-fi-sounds | Kenney (Sci-Fi Sounds) | CC0 1.0 |
| `audio/error.ogg` | TV sound for the **error** event (from `slime_001.ogg`) | https://kenney.nl/assets/sci-fi-sounds | Kenney (Sci-Fi Sounds) | CC0 1.0 |
| `audio/rumble.ogg` | TV sound for the **rumble** event (from `forceField_003.ogg`) | https://kenney.nl/assets/sci-fi-sounds | Kenney (Sci-Fi Sounds) | CC0 1.0 |

## Audio
The TV plays one sound per haptic event. The files live in `audio/`, named after the event: `hit`, `success`, `error`, `rumble`, as `.ogg` or `.wav` (the TV app decodes both itself, so Windows needs no codecs). `lib/asset_manifest.dart` lists them. Replacing a file with one of the same name needs no code change; a missing file plays nothing.

## Planned sources
- Kenney.nl packs (CC0): sprites, UI, input prompts/gamepad icons, interface sounds.
- Self-generated sound effects (jsfxr, ChipTone). These are original works owned by the project. Record the tool used.
