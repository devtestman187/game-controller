# M13 design: Look and sound ("Toy Box Toon")

Status: **approved by the owner on Nov 8, 2026** ("Yes it looks good. Make sure this is documented and committed. Also include the mock-up designs. Begin implementation."). The mock-ups are in docs/design/look-mockups/ (22 pictures: each screen in Sunny and Night) and are drawn by docs/design/look-mockups.html, which can redraw them. The approved mock-ups are the target for M13's screens; a change to the look after this goes back to the owner with a new mock-up.

M13 is built on the branch `m13` (a worktree at `E:\AI\game-controller-m13`), cut from `m12`. M12's device-test fixes stay on `m12` and are merged into `m13` as they land, so a build of `m12` never carries half-built M13 work.

| # | Mock-up (docs/design/look-mockups/, `sunny-` and `night-`) | Shows |
| --- | --- | --- |
| 01 | parts | Palette, buttons (normal, focused, pressed), badges, a card, pieces with and without the shader, targets, ✓ and ✗ |
| 02 | game-picker | TV game picker with the controller's focus |
| 03 | join-screen | TV join screen: sides, the code, Start |
| 04 | shape-race | TV Shape Race 1 vs 1: the worker pushing, a wrong drop |
| 05 | results | Results card over the boards |
| 06 | arena | The Arena: marbles with eyes, toy blocks, bumpers, the goal |
| 07 | phone-shape-race | A joined phone: the strip, the worker carrying, the controls at 60% |
| 08 | phone-connect | The phone's connect screen |
| 09 | phone-paused | A card over the game on a phone |
| 10 | worker | The worker's faces and poses |
| 11 | settings | Look and sound settings |

Earlier status, kept for the record: no code changes until the owner approves (owner, Nov 8, 2026: "Do not start implementation until I give the Ok. I want to review mock ups of the look and feel before moving on.").

Sources: the PRD's M13 and L1 to L5; the plan noted in project-notes.md ("brighter colours, Canvas outlines and shadows, then the Toy Box Toon shader (Arena first), the 3 extra sounds with looping, and a mute or volume setting"); the flash worker's two surveys (docs/briefs/m12/look-sources-report.md, look-inventory-report.md). The first "Toy Box Toon" design file (`game-controller-shaders/DESIGN.md`) is on the owner's other PC and was not available, so this design starts again from the plan. If the owner sends that file, anything in it that conflicts with this design is decided by the owner.

## 1. The look in one paragraph

Everything looks like a well-made plastic toy on a playroom table. Shapes are bright and saturated, each has a **bold dark-ink outline** with rounded joins, a **hard drop shadow** that sits down and to the right (a sticker, not a blur), and **cel shading**: a lighter band on the top-left, the base colour, and a darker band on the bottom-right, with one small white glint. Text is a **rounded, chunky font**. Buttons are fat pills that **squish** when pressed and **bounce** when the controller's focus lands on them. Cards are cream paper with the same ink outline and shadow. It stays calm enough for a 2-minute race: no shaking screen, no busy backgrounds during play.

## 2. Decisions

| # | Decision | Why |
| --- | --- | --- |
| D1 | **Both palettes ship**, Sunny (light sky background, cream boards) and Night (deep grape background). A **Look** setting picks **Auto** (the default), Sunny or Night. Auto follows the device's local time: Sunny from 7:00 to 19:00, Night otherwise. Each device decides for itself, and the palette only changes when a new screen opens, never in the middle of a round (owner, Nov 8, 2026: "Can we have both pallets. Have the user choose in settings or go based on the local time of day.") | Bright for daytime play, easy on the eyes in a dark living room at night. The palette is only colour: every size, shape and outline is the same in both, so the screens are designed once |
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
| D12 | Text on a coloured fill (badges, buttons, face buttons) is always ink, never white. Player 3 is `#A66CFF`, not the mock-ups' `#9B5CFF` (Claude, Nov 8, 2026, at the start of step 2) | Ink passes 4.5:1 on every fill in both palettes once player 3 is lightened (lowest: player 3 at 4.94, `bad` at 5.15); white fails on most of them. The change is barely visible |
| D13 | Font files are renamed `Fredoka-Variable.ttf` and `Nunito-Variable.ttf` (Google Fonts names them `Fredoka[wdth,wght].ttf` and `Nunito[wght].ttf`) and ship with their `OFL.txt`, which the apps add to their licence page | Square brackets in asset paths are fragile in YAML and URLs; the OFL requires its text to travel with the font, and renaming the file is allowed |

## 2a. The twelve puzzles and their piece colours (M13)

**Decided at device test 3** (owner, Nov 9, 2026): "More puzzles. Can we have 6 easy and 6 medium puzzles?" and "It's not easy to see if the rectangle in the rocket was placed. There's not much contrast between where to place the piece and the piece itself in some cases. We should aim for higher contrast so players know when the piece is down."

Twelve pictures, in `packages/puzzle_game/puzzles`, Easy first and then Medium in this order:

| Level | Puzzles |
| --- | --- |
| Easy | house, rocket, tree, sun, fish, snowman |
| Medium | boat, car, robot, train, castle, butterfly |

Each is a picture a child knows at a glance, made of the shapes the format has. Easy has 4–5 pieces, mostly different shapes, few turned, and never two pieces of the same shape and size. Medium has 6–8 pieces, one or two big (team) pieces, some turned, and at most one pair that shares a shape (the boat's two waves). D9 still holds: Easy outlines match their pieces, Medium and Hard outlines stay neutral.

Three rules hold for every picture. A test in `packages/puzzle_game/test` fails if any piece breaks one, so a new puzzle is checked the moment it is added:

- **A piece stands out on the board in both looks.** Its colour is at least **0.15 OKLab** from the board (Sunny `#FFEFD0`, Night `#30297A`). A piece that fails is recoloured from the toy palette, keeping the picture's meaning: the rocket's body became a stronger silver-blue rather than a pale grey, and the snowman is drawn in pale blues, since white on cream can't pass. The numbers for every piece are in the S17 report.
- **Pieces in one puzzle are told apart by colour.** No two pieces of a puzzle are within **0.08 OKLab** of each other unless they share a shape (the boat's two waves). So the house's walls and door, and the castle's wall and door, can't be near-copies of each other.
- **Every piece is held and turned by a point strictly inside it.** The shape's origin is never on or outside an edge, so the worker always has the piece under the thumb. The boat's sail and flag used to be held on their left edge; both were fixed. The sail now sits on its centroid; the flag keeps a point just inside its trailing edge, because on its centroid its size (twice the farthest point from the origin, which sets how big the piece is drawn) dropped by a third and fell under the 8.5 mm floor on the narrowest phone.

`docs/design/m13-puzzles.png` and `m13-puzzles-night.png` show all twelve finished, in a grid with each picture's name and level, one per look.

## 3. Design tokens (in `toy_look`)

Names are by meaning, not colour, so a later change moves every use at once. The tokens that differ between the palettes have two values; the rest are shared.

| Token | Sunny | Night | Used for |
| --- | --- | --- | --- |
| `ink` | `#1E1646` | `#120D2E` | Every outline, shadow colour (at 35%), text on paper |
| `background` / `backgroundGlow` | `#7CC8F8` / `#C4EAFF` | `#241C5E` / `#3B2F8F` | The screen behind everything, with a soft lighter centre and faint dots |
| `onBackground` | ink | `#FFFFFF` | Text straight on the background |
| `paper` | `#FFF6E3` | `#FFF6E3` | Cards, dialogs, side panels, the results card |
| `board` / `tray` | `#FFEFD0` / `#F5D9A8` | `#30297A` / `#3D3592` | Shape Race's play mat and the tray strip |
| `targetNeutral` | `#B3A285` | `#9289D6` | Medium and Hard outlines |
| `field` / `wall` | `#A9DCFB` / `#7F8FD1` | `#2A2270` / `#8C9BD8` | The Arena's floor and walls |

| Token (shared) | Value | Used for |
| --- | --- | --- |
| `focus` | `#FFD23F` with an ink edge | The controller's focus ring and glow |
| `good` / `caution` / `bad` | `#2FCB74` / `#FFB020` / `#FF4D5E` | Right, link OK, winner; waiting, slow link; wrong, hazard, last 15 s |
| `player(1..6)` | `#2E9BF0`, `#FF8A1F`, `#A66CFF`, `#14C8A0`, `#FF5C8A`, `#F2C200` | Players (D6). Player 3 was `#9B5CFF` in the mock-ups; ink text on it measured 4.27:1, under the 4.5:1 rule, so it was lightened (D12) |
| `faceA/B/X/Y` | `#2FCB74`, `#FF4D5E`, `#2E9BF0`, `#FFD23F` | The pad's A, B, X and Y |

Sizes: outline width 3 px on menus (4 on TV), a piece's outline 0.8 world units; shadow offset 4 px down and 3 px right (0.9 world units in a game); corner radius 16 px for cards, full pill for buttons; spacing scale 4, 8, 12, 16, 24, 32 px (project-notes.md's spacing scale). Type: Fredoka 600 for titles (TV 56, phone 32), buttons (TV 28, phone 18) and the clock; Nunito 700 for body (TV 22, phone 15). TV sizes are for reading from 3 metres.

Contrast: every text and background pair in the tokens is checked at 4.5:1 or better, in both palettes, by a test in `toy_look` (the PRD's acceptance test), so a palette change that breaks it fails. Controls are held to WCAG's 3:1 for their parts: a switch has an ink-outlined track (paper when off, `good` when on) and an ink thumb, and the test checks it against the background, the glow and paper, on and off (owner, Nov 8, 2026: the first switch was hard to see).

## 4. Parts

- **`ToyButton`**: replaces `hostButtonLook` (host_button.dart). A pill with fill, ink outline and hard shadow. Pressed: the shadow goes to 0 and the button moves down by the shadow's size (it is pushed in). Focused: a 4 px focus ring outside the ink edge and a quick 1.0 → 1.06 → 1.04 bounce. Disabled: paper colour with a dashed ink edge.
- **`ToyCard`**: paper, ink edge, hard shadow, 16 px corners, an optional coloured header band (the results card's winner colour, the away card's caution colour). Cards pop in (scale 0.9 → 1.0 with a small overshoot, 180 ms).
- **`ToyBadge`**: the player chip: the player's colour, ink edge, the number in Fredoka. Used on the join screen, the HUD, the top bar and the dots.
- **`ToyBackground`**: the background colour with the glow and faint polka dots. With effects on, the dots drift slowly on menus (shader); in a game the background is still (drawn once and cached).
- **`toyShape(canvas, path, colour, look)`**: the one call that draws a game object: shadow, then the body (shader, or the hard-stop gradient), then the glint, then the ink outline. Every piece, target, dot, sprite, wall and goal goes through it, so the shader and the fallback are changed in one place.
- **`toyTheme(look)`**: the Material `ThemeData` for both apps: the colour scheme from the tokens, the text theme from section 3, and the button, card, dialog, switch, slider, app bar and snack bar themes, so stock Material widgets (settings, stats, dialogs) also look right without each screen being rewritten.

## 5. Screens

Every screen and card in look-inventory-report.md section 1 moves to the new look. The main ones are mocked up:

- **Shape Race** (TV, split screen and one side; phone, joined view): the board is a cream play mat with an ink edge on the sky background; the tray is a darker strip; an empty target is a sunken slot (the rule below); placed pieces lock with a short "boing" (scale overshoot, 150 ms) and a ✓ sparkle; a wrong drop shows a red outline, a ✗ and a 2-frame wobble; the player's dot is a badge-like marble with the number. The HUD uses Fredoka; the clock turns `bad` in the last 15 s. The mirror gets an ink frame in the other side's colour. `PuzzleCamera`'s text-width estimate (`_glyphEm`) is re-measured for Fredoka (a wider font would otherwise break the HUD's placement).
- **An empty target is a sunken slot** (decided at device test 3, owner, Nov 9): it is the board's own colour a little darker in Sunny — a little lighter in Night, where the board is dark — with a soft inner shadow along the edges the look's light reaches (the top and the left), and its edge is the dashed ink line with square caps. On Easy the slot also carries a tint of the piece's own colour, at most 10 %, so a player still knows which piece goes where; Medium and Hard leave it the mat's colour. A placed piece stays as it was: raised, in full colour with its shadow, a solid ink edge and its ✓. A slot is drawn under the picture, so a target drawn over a placed piece — a door's slot over the wall it is cut from — never hides the piece; only its dashed edge crosses it. The mat and the slot are measured apart by a test: every piece of every puzzle is at least 0.10 OKLab from its empty slot in both palettes (the closest is the snowman's head at 0.125 in Sunny, the castle's door at 0.143 in Night).
- **The games stand on the sky** (decided at device test 3, owner, Nov 9, an iPad in Night: "I see no background displayed"): the Shape Race painters and the Arena's no longer fill their box with the palette's colour where a `ToyBackground` is behind the view, so the screen's sky — its glow, its dots and, soon, Night's stars — shows round the board and the tray and behind the arena. A view drawn alone, as the design pictures are, still fills its box, so a picture looks as it did.
- **The worker** (Shape Race's player dot, section 5a) becomes a small character with eyes, arms and faces.
- **Arena** (the shader's first target, as planned): sprites are glossy marbles with two simple eyes that look in the direction of travel (owner: "Keep eyes on the marbles"); walls are toy blocks (two-tone, ink edge); hazards are red bumpers with a white ring; the goal is a green pad with a checkered flag and a gentle glow; the faint grid becomes a dotted play mat.
- **Menus** (game picker, puzzle list, join screen, pause, results, settings, puzzle settings, stats, host start sheet, connect screen): `ToyBackground`, a Fredoka title, `ToyButton`s, `ToyCard`s. The game picker shows each game as a big card with a drawn picture (the Shape Race tree, the Arena marble).
- **Cards over the game** (away, waiting, host away, ready 3-2-1, abandoned, rating): `ToyCard` with a coloured header. The 3-2-1 numbers are huge Fredoka with a pop each second.
- **The phone pad**: A/B/X/Y in the face colours with ink edges and shadows; the D-pad and sticks in paper and ink. Opacity still applies to the whole overlay. Sizes don't change (D11).
- **TV home and test tools** (pairing panel, controllers panel, log, haptic panel, latency): the theme only; their layouts stay as they are.

## 5a. The worker

Owner, Nov 8, 2026: "Can the worker in the shape race game have eyes and arms? Can it also make faces that show it's making effort to push/pull pieces?" Yes: the player's dot becomes **the worker**, a round character in the player's colour with its accessory on top (section 5b, which replaced the number on its tummy; so players still tell each other apart without colour), two eyes and two noodle arms with mitten hands.

| Moment (from the game's state) | Face and body |
| --- | --- |
| Empty-handed, still | Smile, blinks every few seconds, arms down |
| Moving | Eyes look where it's going, a slight lean |
| Carrying a small piece | Hands on the piece's edge, a determined little smile |
| **Pushing** (moving away from the piece's side it holds) | Behind the piece, leaning in, arms straight; effort face: squeezed eyes (> <), gritted teeth |
| **Pulling** (moving towards its own side of the piece) | In front of the piece, leaning back, arms stretched back to it; effort face |
| A big piece alone (slow) | The strongest effort: squashed body, sweat drop, a small shake |
| A big piece with a teammate | Each worker on its own side, focused "o" mouth, less strain |
| Calling the teammate (the call flash) | One arm waves, mouth open |
| Rotating | Arms twist with the piece, tongue out in concentration |
| Right drop (snap) | Happy closed eyes (^ ^), arms up, a small hop, for about half a second |
| Wrong drop | "Oops": wide eyes, wavy mouth, a hand on its head, sweat drop |
| Round won / lost | Cheering jump / a shrug |
| Player away | Eyes closed, faded, "zzz" |

Rules for it:
- **The rules don't change.** The grab point and every tolerance stay as they are; the worker is only how the dot is drawn (its pickup reach is the one exception: the device-test rule below makes the reach the body's radius). Its body is about 1.3 times the dot's drawn size today, and never less than 7 mm across on a phone so its face can be read.
- **Decided at device test 1:** the pickup reach is the worker's body radius, measured to the piece's outline, the same for every shape (owner, Nov 9). A piece is reachable when the distance from the dot to its outline — the turned, scaled shape, 0 when the dot is inside it — is at most `pickupReach × pickupRange`, with `pickupReach` the body's radius (`dotRadius × 1.3`, drawn from the same constant in the rules and the painter). So touching any edge, or standing with the body against it, picks a piece up, whether it is a circle, a door, a triangle or a big piece. Of the pieces in reach, the top one the dot stands in is taken, otherwise the one whose outline is nearest; ties go to the higher layer.
- **Everything is worked out from the snapshot**: the held piece, whether it's big and who else holds it, the dot's movement between frames (push or pull, and which way it looks), the call flash, and the last snap or wrong drop with its time. So a joined phone shows the same faces as the host, with nothing added to the protocol.
- **Push or pull** compares the direction of travel with the side of the piece the worker holds; standing still while carrying uses the small-piece face.
- The worker never covers a target the player is aiming at: when carrying, it sits on the edge of the piece it holds, not in the middle.
- The faces are drawn with simple shapes (arcs, ovals, a few lines), so they read at a phone's size and cost little to draw with 4 players.
- **Decided at device test 2** (owner, Nov 9): a piece stays where it was taken, and the worker keeps its side for the whole carry, moving and turning; it goes round only at the field's edge. So a piece no longer jumps to the dot when it is picked up: the dot holds its grab from the piece's middle, and pushing moves the piece by the push and the dot to its grab, so the field's edge never holds the piece back and a turn doesn't move the dot. The worker is drawn on the piece's edge on the side it took it up on — the dot's, where the grab holds the dot off the middle, else behind its walk, else above — decided once at the pickup, or from the dot by a phone that first sees a player already holding. Empty-handed, nothing marks the grab point: no ring.

## 5b. Characters: a colour and an accessory

Owner, Nov 8, 2026, on the worker with its number on its tummy: "Having the player number in the face doesn't look very good. Would it make more sense to have a unique color per character instead of character number?", then "Let's do color and an accessory. But we need to ensure the accessory is customizable in the future along with character customizations."

A player is shown as a **character**: a colour and an accessory. Colour alone isn't enough: about 1 in 12 boys is colour-blind, and for many of them blue and purple, or orange and pink, look alike. The accessory changes the silhouette, so players tell each other apart without colour, and no number is drawn on a body.

| Player | Colour | Accessory (default) |
| --- | --- | --- |
| 1 | `player(1)` blue | round ears |
| 2 | `player(2)` orange | an antenna with a ball |
| 3 | `player(3)` purple | a bow |
| 4 | `player(4)` teal | a cap |
| 5 | `player(5)` pink | a tuft of hair |
| 6 | `player(6)` yellow | a tiny crown |

Rules, so customising them later is a change of data, not of drawing:
- **One value.** `ToyCharacter` in toy_look holds the colour slot and the `ToyAccessory`. `ToyCharacter.forPlayer(number)` gives the defaults above, and it is the only place a player's number becomes a character.
- **Painters draw a character, never a number.** The worker, the Arena's marble, the menus' badges and (step 8) the pad's badge take a `ToyCharacter`. When players can choose their own, the host will hand each player's choice to the views; only where the character comes from changes.
- **Accessories are drawn in ink and paper only**, plus the body's own colour for the ears. So any accessory works on any colour, today's six and any added later, and in both palettes.
- **Small and simple:** each accessory is a few shapes with the ink edge, readable on a worker 7 mm across, and sits on top of the body, never over the face.
- **Where the number stays:** in words and on the menus' big badges ("P1", the join screen, results), which have room. The badges also show the accessory, so the join screen tells you which worker is yours.
- **Customising** (choosing a colour and an accessory on your phone, more accessories, saved with your nickname) is planned for later, not M13. It will need the host to send each player's character to the phones, through an optional field, as M14's other new fields do.

## 6. The shaders

Two fragment shaders in `packages/toy_look/shaders/`, declared under `flutter: shaders:` and loaded once at start (`ToyShaders.load()`). If either fails to load or compile, `ToyLook.shaders` is null and every caller uses the Canvas fallback, the same as with effects off.

1. **`toy_shade.frag`** (set as a `Paint`'s shader for one shape): uniforms are the shape's bounds, its base colour, the light direction (top-left), the band count (3) and the glint size. It builds a dome-shaped normal from the position inside the bounds, puts the light into 3 hard bands (highlight, base, shade), adds a soft rim light on the shaded side and a small white glint near the top-left. Ink outline and shadow stay Canvas strokes.
2. **`toy_backdrop.frag`** (the background): the background colour, the centre glow, and polka dots on a slow diagonal drift (time uniform). Used on menus with effects on; in a game the background is drawn once into an image and reused.

Decided at step 6 (Claude, Nov 8, 2026):
- The dots drift down and to the right at 6 logical px a second: calm enough to go unnoticed after a moment. The drift follows the effects setting, not the shader: a device without the shader drifts its Canvas dots the same way. The shader and the fallback draw the same sky at the same drift, so losing the shader never makes it jump.
- The sky holds still in a round: on the host's Shape Race and Arena screens, and on a phone's pad and joined view, which saves a phone's battery. It also holds still when the device asks for reduced motion.
- Both programs are drawn once offscreen at start (a warm-up), so the driver compiles them behind the splash.
- What stays flat: menu badges and buttons, because text sits on them and the shade band would take ink-on-colour below 4.5:1 (D12); and the Arena's walls and goal pad, which are flat toy plates.

Decided at step 9 (Claude, Nov 9, 2026):
- Moments stay on the view's own clock: a boing or a sparkle under 0.5 s ages from the view's `Stopwatch`, so it finishes after the round's clock stops (the last piece, time up), and anything longer — M14's pop-ups included — ages from the snapshot the host sent, so two screens fed the same frame show it at the same moment.

Fallback, and how the look is the same without the shader: the body is a `LinearGradient` from top-left to bottom-right with hard stops (highlight to 30%, base to 75%, shade after), and the glint is a small white oval. In the mock-ups, "effects on" and "effects off" can be compared.

What the research found (docs/briefs/m13/research-flutter-shaders-report.md, the flash worker's first web research job, checked by Claude against docs.flutter.dev):
- A shader on a `Paint` works on both Skia and Impeller ("Both the Skia and Impeller backends support writing a custom shader"), so one code path serves all four targets. `ImageFilter.shader` throws on Skia, so it's not used (D3 stands).
- Impeller is the default on iOS, on Android API 29+ with Vulkan (older or Vulkan-less devices, which includes many TV boxes, fall back to OpenGL ES) and, from Flutter 3.47, on Windows.
- So: uniforms by name (`getUniformFloat`), not by index; the background is one full-screen rectangle; both programs are loaded once at start, behind the start screen, because a first use can stall (about 1.5 s reported on Windows); and the spike measures start-up and frame time on the Android TV, where a slow GPU driver can take seconds to compile. If a TV box draws wrong, the Android manifest can force OpenGL ES or turn Impeller off.

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
- `SoundPlayer` gains `playLoop(key)` and `stopLoop()` (flutter_soloud's looping), a volume for the sounds and one for the music (each voice's own, set as it plays; a change reaches the music already playing).
- Lobby music plays on the game picker and join screen of the device that hosts, and stops when a round starts. When phones join a TV or PC, only the TV or PC plays it; a host phone plays it only when no TV is used, which is always the case when a phone hosts. Joined phones never play it (owner, Nov 8, 2026: "Play music on host phone only if the TV is not used."). The countdown plays with every 3-2-1 (the Arena and the ready card). Player joined plays on the host when a phone joins.
- Settings (owner, Nov 9, 2026: "there are two volume controls for music and sounds. But a mute switch should mute volume and sound"): **Mute** (off by default; silences the music and every sound, and keeps both volumes to come back to), **Sounds** (0 to 100%, default 80%) and **Music** (0 to 100%, default 60%, under the sounds so a lobby can talk over it; at 0% the music doesn't play) on the TV's settings and the phone's settings; each device's own, saved with its other settings. A new **Look and sound** settings section holds them with **Look** (Auto, Sunny, Night) and **Effects** (on/off).

**Decided at step 7 (Claude, Nov 9, 2026):**
- **"Picker and join screen"** means the whole lobby. The music plays from the game picker's opening to its closing, through everything pushed over it (the Shape Race list, puzzle settings, the join screen, stats, settings). It doesn't play while a round's screen is open, results and pause included. So it carries on unbroken from the picker to the join screen, and Play again keeps it off.
- It stops at once when the app is hidden and comes back when it's shown again. The TV home (the pairing panel) isn't a lobby.
- **The countdown goes with the "Get ready" beat:** it starts as the card shows 3, and stops if the beat is held, so no "go" sounds over a waiting round. The TV has no beat (m12-host-touch rule 6), so it has no countdown, and the Arena's 2 s break between rounds stays silent.
- **Player joined** plays once per new phone in the host's list, not for a phone coming back from away, and not for the host's own player.
- **The volumes** are each voice's own: the Sounds volume is set as a sound starts, so it covers every game sound on that device, a joined phone's included. The Music volume is set on the loop, so a change reaches music already playing.
- **Mute** silences both through their volumes and leaves the music running, so unmuting carries on where it is. Music at 0% stops it.
- The keys are `sound.volume`, `sound.musicVolume` and `sound.muted`, each this device's own.

**Decided at step 10b (Claude, Nov 9, 2026):**
- **The round's music** (owner, Nov 9, 2026: "Yes I want music during rounds ... As the timer gets closer to running out the music's tempo should speed up."): one 16-bar piece in F major, rendered at three tempos — `round` at 120 BPM (31.997 s), `round_hurry` at 138 (27.823 s) and `round_final` at 156 (24.613 s) — the same key and the same bars, so speeding up never raises the pitch. `SoundKey`s `round`, `roundHurry` (`round_hurry`) and `roundFinal` (`round_final`), with CREDITS rows, mastered about 3 dB under the lobby loop so the game's sounds and the tick read over it.
- It plays on the device that plays the lobby music (the TV or PC, or a host phone with no TV); joined phones never play it. It starts at the round's "go" — `RoundPhase.playing`, which `Pausable` publishes after the 3-2-1, or at once where there is no beat — on Shape Race and the Arena, and the results end it with a 300 ms fade out, so `time_up` and `success` are heard clearly.
- **The speed-up** follows Shape Race's clock (the time left on the side nearest its end) and the puzzle's `warningS` (15 s by default): more than `warningS` left → `round`; `warningS` or less → `round_hurry`; `warningS / 3` or less (5 s by default) → `round_final`; a `warningS` of 0, or no clock at all (the Arena) → `round`. The new loop starts at the same share of its length as the old one had reached, and the two cross-fade over 120 ms, so it sounds like the band speeding up rather than a new song.
- A round that stands still — the 3-2-1, the pause menu, the host-away card, a phone the round waits for — pauses the music where it is and resumes there; only the results end it. The lobby music and the round music never play together: a round still stops the lobby's the moment its screen opens, and Play again may start the round's from the top (a new round) but never stops and starts the lobby's.
- One controller does both — `HostMusic`, in `ui/lobby_music.dart` — settling after the frame and stopping on a hidden app as the lobby music does, and following Mute and the Music volume the same way. The round's screen tells it the clock each frame (`PuzzlePlayView.onClock`) and its results.

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

## 10. Owner's answers (Nov 8, 2026)

1. Palettes: both, chosen in settings or by the time of day (D1).
2. Eyes on the Arena's marbles: yes.
3. Lobby music: on the host phone only when no TV is used (section 8).
4. Shape Race's dot becomes the worker, with eyes, arms and effort faces (section 5a).

Still open: anything from the original "Toy Box Toon" file on the other PC that should override this design.
