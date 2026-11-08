# M13 design: Look and sound ("Toy Box Toon")

Status: **design, for the owner's review with the mock-ups** (docs/design/look-mockups.html). No code changes until the owner approves (owner, Nov 8, 2026: "Do not start implementation until I give the Ok. I want to review mock ups of the look and feel before moving on.").

Sources: the PRD's M13 and L1 to L5; the plan noted in project-notes.md ("brighter colours, Canvas outlines and shadows, then the Toy Box Toon shader (Arena first), the 3 extra sounds with looping, and a mute or volume setting"); the flash worker's two surveys (docs/briefs/m12/look-sources-report.md, look-inventory-report.md). The first "Toy Box Toon" design file (`game-controller-shaders/DESIGN.md`) is on the owner's other PC and was not available, so this design starts again from the plan. If the owner sends that file, anything in it that conflicts with this design is decided by the owner.

## 1. The look in one paragraph

Everything looks like a well-made plastic toy on a playroom table. Shapes are bright and saturated, each has a **bold dark-ink outline** with rounded joins, a **hard drop shadow** that sits down and to the right (a sticker, not a blur), and **cel shading**: a lighter band on the top-left, the base colour, and a darker band on the bottom-right, with one small white glint. Text is a **rounded, chunky font**. Buttons are fat pills that **squish** when pressed and **bounce** when the controller's focus lands on them. Cards are cream paper with the same ink outline and shadow. It stays calm enough for a 2-minute race: no shaking screen, no busy backgrounds during play.

## 2. Decisions

| # | Decision | Why |
| --- | --- | --- |
| D1 | Two palettes are mocked up, **Sunny** (light sky background, cream boards) and **Night** (deep grape background, as today but brighter). **Recommended: Sunny.** One ships; the other is not kept | The plan asks for "brighter colours" and the players are 6 and up. Ink outlines keep yellow and white pieces readable on a light background, which is what outlines are for. Night is the safe option for dark living rooms |
| D2 | The look is mostly **drawn with Canvas**: outlines, shadows and banded shading (a gradient with hard stops). The shader adds the finishing touches on top: a rounded, dome-like shading that follows the shape, the glint, a soft rim light and the animated background | Canvas works on every target today, so the whole look is safe even where a shader can't run. The shader is never needed for the game to look right (L4's fallback) |
| D3 | Shaders are used only as a **paint on one shape or one background** (`FragmentShader` set on a `Paint`), never as a filter over the whole screen | A paint shader runs on both of Flutter's renderers (Impeller and Skia), so on iOS, Android, Android TV and Windows. A whole-screen filter (`ImageFilter.shader`) needs Impeller and costs a full-screen pass every frame |
| D4 | One new package, **`packages/toy_look`**, holds the whole look (L1). Rules code never imports it | review-rules.md row C1 and code-health.md's "Look-and-sound" row: a later change of look touches one package |
| D5 | Painters get the look as a **`ToyLook` value passed in** (no `BuildContext`); widgets read it from a `ToyLookScope` above `MaterialApp` | The board is drawn by the same painter on the TV, the host phone and joined phones (`FrameView`), so the look must be plain input, identical on all three |
| D6 | `playerColors` stays in `protocol` (one source for "who is which colour"), with new, brighter values; `toy_look` reads it | The colour of a player is shared meaning between host and phones, not style. The protocol doc lists the new values |
| D7 | Fonts: **Fredoka** (headings, numbers, buttons) and **Nunito** (body text), both SIL Open Font License, bundled in `toy_look` and listed in CREDITS.md | Rounded and chunky, easy for children to read, free to ship. No font is bundled today, so each platform shows a different one |
| D8 | The **effects setting** (on/off, default on) is local to each device and turns off the shaders and the menu motion. It is never sent to other phones | A joined phone on an old device can turn effects off without changing anyone else's screen. The board's colours and shapes are the same either way |
| D9 | Puzzle piece colours are re-picked from the toy palette (data change in the puzzle files, not a rule change). Easy-level outlines keep matching their pieces; Medium and Hard keep a neutral outline | PRD-v2: "Easy outlines are coloured to match their pieces. Medium and Hard outlines are grey, so only the shape helps" |
| D10 | Right and wrong keep their ✓ and ✗, and players keep their numbers on badges and dots | PRD-v2: colour-blind players can play. Colour never carries meaning alone |
| D11 | The phone's pad keeps every size and touch area (C14 to C16, C28's opacity); only colour, outline, shadow and the press squish change | The pad's sizes are tested and tuned; a restyle must not move a thumb target |

## 3. Design tokens (in `toy_look`)

Names are by meaning, not colour, so a later change moves every use at once. Values below are **Sunny**; Night's are in the mock-ups.

| Token | Sunny | Used for |
| --- | --- | --- |
| `ink` | `#1E1646` | Every outline, shadow colour (at 35%), text on paper |
| `background` / `backgroundGlow` | `#7CC8F8` / `#BDE6FF` | The screen behind everything, with a soft lighter centre and faint dots |
| `paper` | `#FFF6E3` | Cards, dialogs, side panels, the results card |
| `board` / `tray` | `#FFEFD0` / `#F7DDB0` | Shape Race's play mat and the tray strip |
| `targetNeutral` | `#B9A98E` | Medium and Hard outlines |
| `focus` | `#FFD23F` with an ink edge | The controller's focus ring and glow |
| `good` / `caution` / `bad` | `#2FCB74` / `#FFB020` / `#FF4D5E` | Right, link OK, winner; waiting, slow link; wrong, hazard, last 15 s |
| `player(1..6)` | `#2E9BF0`, `#FF8A1F`, `#9B5CFF`, `#14C8A0`, `#FF5C8A`, `#F2C200` | Players (D6) |
| `faceA/B/X/Y` | `#2FCB74`, `#FF4D5E`, `#2E9BF0`, `#FFD23F` | The pad's A, B, X and Y |

Sizes: outline width 3 px on menus (4 on TV), a piece's outline 0.8 world units; shadow offset 4 px down and 3 px right (0.9 world units in a game); corner radius 16 px for cards, full pill for buttons; spacing scale 4, 8, 12, 16, 24, 32 px (project-notes.md's spacing scale). Type: Fredoka 600 for titles (TV 56, phone 32), buttons (TV 28, phone 18) and the clock; Nunito 700 for body (TV 22, phone 15). TV sizes are for reading from 3 metres.

Contrast: every text and background pair in the tokens is checked at 4.5:1 or better by a test in `toy_look` (the PRD's acceptance test), so a palette change that breaks it fails.

## 4. Parts

- **`ToyButton`**: replaces `hostButtonLook` (host_button.dart). A pill with fill, ink outline and hard shadow. Pressed: the shadow goes to 0 and the button moves down by the shadow's size (it is pushed in). Focused: a 4 px focus ring outside the ink edge and a quick 1.0 → 1.06 → 1.04 bounce. Disabled: paper colour with a dashed ink edge.
- **`ToyCard`**: paper, ink edge, hard shadow, 16 px corners, an optional coloured header band (the results card's winner colour, the away card's caution colour). Cards pop in (scale 0.9 → 1.0 with a small overshoot, 180 ms).
- **`ToyBadge`**: the player chip: the player's colour, ink edge, the number in Fredoka. Used on the join screen, the HUD, the top bar and the dots.
- **`ToyBackground`**: the background colour with the glow and faint polka dots. With effects on, the dots drift slowly on menus (shader); in a game the background is still (drawn once and cached).
- **`toyShape(canvas, path, colour, look)`**: the one call that draws a game object: shadow, then the body (shader, or the hard-stop gradient), then the glint, then the ink outline. Every piece, target, dot, sprite, wall and goal goes through it, so the shader and the fallback are changed in one place.
- **`toyTheme(look)`**: the Material `ThemeData` for both apps: the colour scheme from the tokens, the text theme from section 3, and the button, card, dialog, switch, slider, app bar and snack bar themes, so stock Material widgets (settings, stats, dialogs) also look right without each screen being rewritten.

## 5. Screens

Every screen and card in look-inventory-report.md section 1 moves to the new look. The main ones are mocked up:

- **Shape Race** (TV, split screen and one side; phone, joined view): the board is a cream play mat with an ink edge on the sky background; the tray is a darker strip; targets are drawn as dashed ink outlines with a faint fill (Easy: in the piece's colour); placed pieces lock with a short "boing" (scale overshoot, 150 ms) and a ✓ sparkle; a wrong drop shows a red outline, a ✗ and a 2-frame wobble; the player's dot is a badge-like marble with the number. The HUD uses Fredoka; the clock turns `bad` in the last 15 s. The mirror gets an ink frame in the other side's colour. `PuzzleCamera`'s text-width estimate (`_glyphEm`) is re-measured for Fredoka (a wider font would otherwise break the HUD's placement).
- **Arena** (the shader's first target, as planned): sprites are glossy marbles with two simple eyes that look in the direction of travel; walls are toy blocks (two-tone, ink edge); hazards are red bumpers with a white ring; the goal is a green pad with a checkered flag and a gentle glow; the faint grid becomes a dotted play mat.
- **Menus** (game picker, puzzle list, join screen, pause, results, settings, puzzle settings, stats, host start sheet, connect screen): `ToyBackground`, a Fredoka title, `ToyButton`s, `ToyCard`s. The game picker shows each game as a big card with a drawn picture (the Shape Race tree, the Arena marble).
- **Cards over the game** (away, waiting, host away, ready 3-2-1, abandoned, rating): `ToyCard` with a coloured header. The 3-2-1 numbers are huge Fredoka with a pop each second.
- **The phone pad**: A/B/X/Y in the face colours with ink edges and shadows; the D-pad and sticks in paper and ink. Opacity still applies to the whole overlay. Sizes don't change (D11).
- **TV home and test tools** (pairing panel, controllers panel, log, haptic panel, latency): the theme only; their layouts stay as they are.

## 6. The shaders

Two fragment shaders in `packages/toy_look/shaders/`, declared under `flutter: shaders:` and loaded once at start (`ToyShaders.load()`). If either fails to load or compile, `ToyLook.shaders` is null and every caller uses the Canvas fallback, the same as with effects off.

1. **`toy_shade.frag`** (set as a `Paint`'s shader for one shape): uniforms are the shape's bounds, its base colour, the light direction (top-left), the band count (3) and the glint size. It builds a dome-shaped normal from the position inside the bounds, puts the light into 3 hard bands (highlight, base, shade), adds a soft rim light on the shaded side and a small white glint near the top-left. Ink outline and shadow stay Canvas strokes.
2. **`toy_backdrop.frag`** (the background): the background colour, the centre glow, and polka dots on a slow diagonal drift (time uniform). Used on menus with effects on; in a game the background is drawn once into an image and reused.

Fallback, and how the look is the same without the shader: the body is a `LinearGradient` from top-left to bottom-right with hard stops (highlight to 30%, base to 75%, shade after), and the glint is a small white oval. In the mock-ups, "effects on" and "effects off" can be compared.

Risk check first (step 1 below): no shader has ever been compiled in this repository. The first job builds one shader and draws it on Windows (the TV app's desktop build), the Android TV emulator, an Android phone and an iPhone (via TestFlight), and measures the frame time with 4 players' pieces on the Android TV emulator. If a target can't run it, that target ships with effects off.

## 7. Architecture

```
protocol (playerColors, values only)
   └── toy_look  ── ToyLook { palette, sizes, type, shaders?, effects }
         │           toyTheme(), ToyButton, ToyCard, ToyBadge, ToyBackground, toyShape()
         ├── puzzle_game painters (PuzzlePainter, MatchPainter, MirrorPainter) take a ToyLook
         ├── test_game ArenaPainter takes a ToyLook
         ├── game_kit FrameView passes the ToyLook it is given to the game's painter
         ├── party_host screens and cards (widgets read ToyLookScope)
         └── controller_app, tv_test_app: build ToyLook at start, wrap the app in ToyLookScope and toyTheme
rules (puzzle_game rules, test_game rules, game_kit sessions) ── never import toy_look
```

- **The rule boundary is checked**: a test fails if a rules file imports `toy_look` or Flutter's `painting`/`material`, and `tools/review.sh` flags a `Color(0x` or `Colors.` outside `toy_look` (the PRD's "no colour written outside the look package" test). Existing literals (100 of them, look-inventory-report.md 2d) are all moved in this milestone.
- **Same picture everywhere**: a painter's output depends only on the snapshot, the box size and the `ToyLook`. Effects only change how a shape is filled (shader or gradient), never where it is or what colour it is.
- **Motion is drawn from time, not stored**: the boing, wobble and eyes are worked out from the snapshot's time and events, so a joined phone draws the same motion from the host's frames.
- **Strings**: code-health.md's "one string table" is done at the start, alongside the palette, because the menus are rewritten anyway ("P2 is away" and "Player 2 is away" become one string).

## 8. Sound (L5)

- New `SoundKey`s: `lobby`, `countdown`, `playerJoined` (from the existing audio package: lobby is a 19.2 s seamless loop, countdown 4.42 s with beeps at 0, 1, 2 s and "go" at 3 s, player joined 1.02 s). They're copied into `assets/audio/` with their CREDITS.md rows.
- `SoundPlayer` gains `playLoop(key)` and `stopLoop()` (flutter_soloud's looping), and a master volume and mute.
- Lobby music plays on the game picker and join screen of whoever hosts (TV or host phone) and stops when a round starts; joined phones don't play it. The countdown plays with every 3-2-1 (the Arena and the ready card). Player joined plays on the host when a phone joins.
- Settings: **Sound volume** (0 to 100%, default 80%) and **Music** (on/off, default on) on the TV's settings and the phone's settings; each device's own, saved with its other settings.

## 9. Implementation order (after the owner's OK)

Each step is a flash-worker job with a brief and a review gate, as in M12.

1. **Spike**: `toy_look` skeleton, Fredoka and Nunito bundled, one shader compiled and drawn on all four targets, fallback and frame time checked.
2. **Look package**: tokens, `toyTheme`, `ToyButton`, `ToyCard`, `ToyBadge`, `ToyBackground`, `toyShape`, the contrast test, the rule-boundary test and the literal check; the string table.
3. **Menus and cards**: both apps' theme and every party_host and phone screen; the literals moved.
4. **Shape Race**: the painters take a `ToyLook`; pieces, targets, tray, dots, HUD (and the text measure), mirror, results; the motion.
5. **Arena**: the toy look and the shader first, as planned.
6. **Shaders on**: pieces and backgrounds everywhere, the effects setting.
7. **Sound**: the three cues, looping, volume and mute.
8. **The pad**: restyled at the same sizes.
9. Full review (worker first, Claude verifies), device tests, then a build on the owner's word.

## 10. Questions for the owner (answered with the mock-ups)

1. **Sunny or Night?** Recommended: Sunny.
2. **Eyes on the Arena's marbles?** Recommended: yes; they're cheap and make it feel like a toy. Shape Race's dots stay plain.
3. **Lobby music on the host phone too**, or only on the TV? Recommended: both, with the Music switch.
4. Anything from the original "Toy Box Toon" file on the other PC that should override this design.
