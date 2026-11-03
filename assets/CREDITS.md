| `audio/snap.ogg` | Puzzle: a piece locked onto its matching outline | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/wrong.ogg` | Puzzle: a piece dropped where it does not belong | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/tick.ogg` | Puzzle: each of the last 15 seconds | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/pickup.ogg` | Puzzle: picking up a piece | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/time_up.ogg` | Puzzle: the clock reaches zero | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/help.ogg` | Puzzle (M11): a big piece carried alone, calling a teammate | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
# Asset credits

Every image and sound in `/assets` (and every platform icon or banner made from them) is listed here.
Only assets whose license allows commercial use are accepted (CC0 preferred, e.g. Kenney.nl).
Update this file in the same commit that adds, replaces or removes an asset.

| File | Used for | Source URL | Creator | License |
| --- | --- | --- | --- | --- |
| `branding/*.png` and every app icon made from them (Android `mipmap-*`, the TV banner, iOS `AppIcon`, the Windows `app_icon.ico`, `site/icon.png`) | Thumb Party and Thumb Party TV icons, the TV banner and the Play store graphics | Drawn by `tools/branding/make-artwork.ps1` (System.Drawing, no third-party content) | Project | CC0 1.0 |
| `branding/screenshots/*.png` | Store screenshots | Captured from the apps (Android 12 emulator, Windows build) | Project | CC0 1.0 |
| `audio/hit.ogg` | TV sound for the **hit** event (Arena: bumping a wall or edge, a hazard touching you) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/success.ogg` | TV sound for the **success** event (Arena: reaching the goal; Shape Race: all pieces matched) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/error.ogg` | TV sound for the **error** event (Arena: pressing A while the dash recharges) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/rumble.ogg` | TV sound for the **rumble** event (Arena: starting a dash) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |

## Audio
The TV plays sounds by event name (M10: through the game host). The files live in `audio/`, named after the event: `hit`, `success`, `error`, `rumble`, and for the puzzle `snap`, `wrong`, `tick`, `pickup`, `time_up` and `help`, as `.ogg` or `.wav` (the TV app decodes both itself, so Windows needs no codecs). `lib/asset_manifest.dart` lists them. Replacing a file with one of the same name needs no code change; a missing file plays nothing.

## Planned sources
- Kenney.nl packs (CC0): sprites, UI, input prompts/gamepad icons, interface sounds.
- Self-generated sound effects (jsfxr, ChipTone). These are original works owned by the project. Record the tool used.
