# Asset credits

Every image and sound in `/assets` (and every platform icon or banner made from them), and every font, is listed here.
Only assets whose license allows commercial use are accepted (CC0 preferred, e.g. Kenney.nl).
Update this file in the same commit that adds, replaces or removes an asset.

| File | Used for | Source URL | Creator | License |
| --- | --- | --- | --- | --- |
| `branding/*.png` and every app icon made from them (Android `mipmap-*`, the TV banner, iOS `AppIcon`, the Windows `app_icon.ico`, `site/icon.png`) | Thumb Party and Thumb Party TV icons, the TV banner and the Play store graphics | Drawn by `tools/branding/make-artwork.ps1` (System.Drawing, no third-party content) | Project | CC0 1.0 |
| `packages/toy_look/fonts/fredoka/Fredoka-Variable.ttf` (Google Fonts' `Fredoka[wdth,wght].ttf`, renamed), with its `OFL.txt` | The look's titles, buttons and numbers (M13) | https://github.com/google/fonts/tree/main/ofl/fredoka | The Fredoka Project Authors | SIL OFL 1.1 |
| `packages/toy_look/fonts/nunito/Nunito-Variable.ttf` (Google Fonts' `Nunito[wght].ttf`, renamed), with its `OFL.txt` | The look's body text (M13) | https://github.com/google/fonts/tree/main/ofl/nunito | The Nunito Project Authors | SIL OFL 1.1 |
| `branding/screenshots/*.png` | Store screenshots | Captured from the apps (Android 12 emulator, Windows build) | Project | CC0 1.0 |
| `audio/hit.ogg` | TV sound for the **hit** event (Arena: bumping a wall or edge, a hazard touching you) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/success.ogg` | TV sound for the **success** event (Arena: reaching the goal; Shape Race: all pieces matched) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/error.ogg` | TV sound for the **error** event (Arena: pressing A while the dash recharges) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/rumble.ogg` | TV sound for the **rumble** event (Arena: starting a dash) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/snap.ogg` | Puzzle: a piece locked onto its matching outline | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/wrong.ogg` | Puzzle: a piece dropped where it does not belong | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/tick.ogg` | Puzzle: each of the last 15 seconds | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/pickup.ogg` | Puzzle: picking up a piece | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/time_up.ogg` | Puzzle: the clock reaches zero | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/help.ogg` | Puzzle (M11): a big piece carried alone, calling a teammate | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/dash.ogg` | Arena (M14): every dash, a short swish with a small pop on its end | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/bump.ogg` | Arena (M14): two marbles meeting, a soft thump with a rubbery rise | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/bump_big.ogg` | Arena (M14): a dash that shoves | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/coin.ogg` | Arena (M14): picking up a coin | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/coin_gold.ogg` | Arena (M14): a gold coin, worth 2 | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/coin_lost.ogg` | Arena (M14): dropping a coin | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/coin_appear.ogg` | Arena (M14): a new coin starting its sparkle | Generated for this project with `tools/audio/arena_sounds.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/arena.ogg` | Arena music (M14): a Bumper Round, the 16-bar G-major piece at 128 BPM, looped | Generated for this project with `tools/audio/arena_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/arena_hurry.ogg` | Arena music (M14): the same piece at ×1.15 (147.2 BPM), with 15 s or less left on the round's clock | Generated for this project with `tools/audio/arena_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/arena_final.ogg` | Arena music (M14): the same piece at ×1.3 (166.4 BPM), with 5 s or less left on the round's clock | Generated for this project with `tools/audio/arena_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/lobby.ogg` | Lobby music (M13): the host's game picker and join screen, looped | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/countdown.ogg` | The 3-2-1 before a round (M13): beeps at 0, 1 and 2 s, then the "go" chord | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/player_joined.ogg` | A phone joining the host (M13) | Generated for this project with `tools/audio/render.py` (numpy synthesis, no sampled material) | Project | CC0 1.0 |
| `audio/round.ogg` | Round music (M13 10b): Shape Race and the Arena from their "go" to their results, at 120 BPM | Generated for this project with `tools/audio/round_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/round_hurry.ogg` | Round music (M13 10b): the same 16-bar piece at 138 BPM, when `warningS` or less is left on the clock | Generated for this project with `tools/audio/round_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |
| `audio/round_final.ogg` | Round music (M13 10b): the same 16-bar piece at 156 BPM, with `warningS / 3` or less left on the clock | Generated for this project with `tools/audio/round_music.dart` (synthesis ported from `render.py`, encoded with ffmpeg; no sampled material) | Project | CC0 1.0 |

## Audio
The TV and the host phone play sounds by event name (M10: through the game host). The files live in `audio/`, named after the event: `hit`, `success`, `error`, `rumble`, and for the puzzle `snap`, `wrong`, `tick`, `pickup`, `time_up` and `help`, and for the Arena (M14) `dash`, `bump`, `bump_big`, `coin`, `coin_gold`, `coin_lost` and `coin_appear`, as `.ogg` or `.wav` (the TV app decodes both itself, so Windows needs no codecs). The host's own cues (M13) are `lobby` (a seamless loop, played under the game picker and join screen), `countdown` (the 3-2-1 before a round), `player_joined` (a phone joining) and the round's music at its three tempos, `round`, `round_hurry` and `round_final` (the same 16-bar piece at 120, 138 and 156 BPM, looped from the round's "go" to its results and sped up as the clock runs out; M13 10b). The Arena's music is `arena`, `arena_hurry` and `arena_final`: one 16-bar piece in G major at 128, 147.2 and 166.4 BPM, looped for a Bumper Round (M14). `lib/asset_manifest.dart` lists them. Replacing a file with one of the same name needs no code change; a missing file plays nothing.

## Planned sources
- Kenney.nl packs (CC0): sprites, UI, input prompts/gamepad icons, interface sounds.
- Self-generated sound effects (jsfxr, ChipTone). These are original works owned by the project. Record the tool used.
