# Look inventory: every screen, painter and colour before the re-skin

Read-only survey (G0), Nov 8, 2026. Read: `packages/puzzle_game`, `packages/party_host`,
`packages/game_kit`, `packages/test_game` (the Arena), `tv_test_app`, `controller_app`,
`packages/protocol/lib/src/messages.dart`, every `pubspec.yaml`, `docs/code-health.md` ("Look-and-sound" row) and
`docs/review-rules.md` row C1. No file changed but this report; nothing was fetched from the web.

Two line references are worth keeping in view: [code-health.md](../../code-health.md) line 75 ("Colours and card
text as literals: the mirror's orange copies `playerColors[1]`; the cards' opacities; 'P2 is away' vs 'Player 2 is
away' already differ. One palette and one string table. Do at its start") and [review-rules.md](../../review-rules.md)
row C1 (a look that swaps "without touching rules").

## 1. Screens and overlays a player sees

Kind: **board** = game board drawn from a snapshot; **menu** = a full screen with focusable buttons; **card** = a
dialog or a card over the game; **pad** = the phone's controls; **bar** = chrome over the game.

### TV app (`tv_test_app/lib/src/ui/`, host screens in `packages/party_host/lib/src/ui/`)

| Screen / overlay | File | Purpose | Kind |
| --- | --- | --- | --- |
| `HomeScreen` | `tv_test_app/lib/src/ui/home/home_screen.dart` | The TV's main screen: title, four buttons, three panels | menu (dashboard) |
| `Panel` (pairing / controllers / log) | `home/panel.dart`, `home/pairing_panel.dart`, `home/controllers_panel.dart`, `home/log_panel.dart` | Pairing code + addresses; each phone's live input; the log | menu (panels) |
| `FirstLaunchConsent` | `home/first_launch_consent.dart` (dialog in `party_host/.../stats_screen.dart:258`) | Adult's stats consent | card |
| `GamesScreen` ("Play") | `party_host/.../games_screen.dart:19` | Home/game picker: Shape Race, Arena, Puzzle settings | menu |
| `ShapeRaceScreen` | `party_host/.../games_screen.dart:140` | Level and puzzle picker | menu |
| `JoinScreen` (+ `_SidePanel`, `_Sides`, `_NotJoined`, `_JoinButtons`) | `party_host/.../join_screen.dart`, `join_screen_widgets.dart` | Lobby: two sides, badges, Start/Back, format line | menu (lobby) |
| `PuzzleScreen` → `PuzzlePlayView` → `MatchView` | `party_host/.../puzzle_screen.dart`, `packages/puzzle_game/lib/src/view.dart` | Shape Race: board(s), tray, dots, clock bar, HUD | board |
| `_Results` over the board | `party_host/.../puzzle_screen_widgets.dart:56` | Winner, each side's time/pieces, Rematch/Change teams/Back | card |
| `_PauseMenu` | `party_host/.../pause_menu.dart:337` | Paused: badge, who can resume, Quit/Resume | card |
| `AwayCard` (+ `_AwayLine`) | `party_host/.../away_card.dart` | Round waits for a dropped phone: countdown, Go on/End round | card |
| `ReadyCard` | `party_host/.../ready_card.dart` | "Get ready" 3-2-1 over the game | card |
| `_PlayHint` | `puzzle_screen_widgets.dart:28` | "Start on a phone: pause · Back: leave" | bar text |
| `GameScreen` (Arena) → `ArenaBoard` (HUD + field + winner banner) | `party_host/.../game_screen.dart`, `packages/test_game/lib/src/arena_view_widgets.dart` | The Arena: counters bar, sprites, goal, hazards, winner banner | board |
| `DebugOverlay` / `_Note` | `game_screen.dart:175`, `:158` | Per-player latency and input; "No controller connected" | card |
| `PuzzleSettingsScreen` | `party_host/.../puzzle_settings_screen.dart` | Playtest tolerances, hint delay, drop-ready switch | menu |
| `StatsScreen` + `SessionView` | `party_host/.../stats_screen.dart`, `stats_screen_widgets.dart` | Sessions per phone/mode, Export, sharing | menu |
| `HapticPanelScreen` | `tv_test_app/lib/src/ui/haptic_panel_screen.dart` | Haptic test | menu |
| `LatencyScreen` | `tv_test_app/lib/src/ui/latency_screen.dart` | Ping/latency readings | menu |
| `_WaitingForController` | `tv_test_app/lib/src/debug_start.dart:62` | Dev `START_GAME` start, before a phone pairs | notice |

### Phone controller (`controller_app/lib/src/ui/`)

| Screen / overlay | File | Purpose | Kind |
| --- | --- | --- | --- |
| `ControllerScreen` | `controller_screen.dart` | The pad: game behind, top bar, controls, notices | pad |
| `_TopBar` / `_ControllerTopBar` / `_GameTopBar` | `controller_top_bar.dart` | Badge + connection; mode, Settings, Diagnostics | bar |
| `BarConnection`, `CompactConnection`, `ConnectionDot`, `PlayerBadge` | `bar_connection.dart` | Link state, ping, status panel, player chip | bar |
| `BarModes`, `ModeMenuButton`, `_ModePicker` | `bar_modes.dart` | D-pad/Gyro/Sticks, tune dialogs | menu (segmented / popup) |
| `DpadView`, `SmallButton` | `pad_widgets.dart` | D-pad, Start/Select/LB/RB pills | pad |
| `FaceButtonsView` | `face_buttons.dart` | A/B/X/Y diamond | pad |
| `StickModeView`, `AnalogStickView` | `stick_widgets.dart` | Two analog sticks (stick mode) | pad |
| `TiltView` / `TiltDot` (+ Calibrate) | `tilt_view.dart` | Tilt position and dead zone (gyro mode) | pad |
| `StatusPanel` / `StatusShapePainter` | `status_panel.dart` | The game's status shape, text, progress | bar |
| `HostChip` + its menu | `host_chip.dart` | Pairing code, address, New code, Stop hosting | bar + popup |
| `ConnectScreen`, `StatusChip`, `_HostList`, `_ManualEntry`, `ConnectionPanel` | `connect_screen.dart`, `connect_panels.dart` | Find a TV, pair, type an address, Host a game | menu |
| `SettingsScreen` (+ `settings_sections.dart`) | `settings_screen.dart` | Haptics, gyro, sticks, game, stats, about | menu (cards) |
| `DiagnosticsScreen` | `diagnostics_screen.dart`, `diagnostics_view_section.dart` | Latency, view, log | menu |
| `JoinedView` (game behind the pad) | `joined_view.dart` → `game_kit` `FrameView` | The host's game on a joined phone | board |
| `WaitingCard` (+ `_AwayLines`) | `waiting_card.dart` | Host away / reconnecting / player away, countdown, Leave game | card |
| `AbandonedNotice` | `abandoned_notice.dart` | "The host was away too long, so the round ended." over the controls | card |
| `RatingPrompt` / `_FaceCard` | `rating_prompt.dart` | "How did the controls feel?" | card |
| `GyroDialog`, `StickDialog` | `gyro_dialog.dart`, `stick_dialog.dart` | Tuning dialogs | card |
| `TooSmallView`, `DemoReadout` | `controller_parts.dart:122`, `:89` | Window too small; demo mode readout | notice |

### Phone host (the same phone hosting: `controller_app/lib/src/host/` + `party_host` screens)

| Screen / overlay | File | Purpose | Kind |
| --- | --- | --- | --- |
| `HostScreen` (the route) | `host/host_screen.dart` | Game picker/game behind this phone's own pad, or alone | board + pad |
| `HostGames` | `host/host_games.dart` | The picker navigator inside the route | menu |
| `HostStartSheet` / `_Choice` | `host/host_start_sheet.dart` | "Play on this phone" or "Show on this device" | card |
| All `party_host` screens above | `party_host/lib/src/ui/*` | Picker, join, Shape Race, Arena, pause, results, away, ready, settings, stats | as above |
| Compact `HostChip` + `_GameTopBar` | `ui/host_chip.dart`, `ui/controller_top_bar.dart` | Pairing code over the game; mode menu | bar |

## 2. How it is drawn

### 2a. CustomPainters

| Painter | File | Paints | Colours, strokes, shadows | Source of the values |
| --- | --- | --- | --- | --- |
| `PuzzlePainter` | `packages/puzzle_game/lib/src/puzzle_painter.dart:3` | Background, board and tray panels, target outlines, pieces, player dots, HUD (clock, count, bar) | `_tray 0xFF1C222B`, `_outlineGrey 0xFF9AA5B1` (own consts); `_background 0xFF14181F`, `_wrong 0xFFE53935`, `_right 0xFF43D17A`, `_board 0xFF242B36` (consts in `view.dart:99-113`); `Colors.white` / `white70` / `white24` / `black` @0.5, 0.55; fills 0.16–0.45 alpha; strokes 0.5 / 0.9 (world units); hint glow `MaskFilter.blur(2.5)`, call flash `blur(0.6)`; text sizes 3.2–5.5 world units in an inline `TextStyle` | literals (consts, not theme) + `Color(spec.color)` from the puzzle data + `playerColor(n)` |
| `MatchPainter` | `match_painter.dart:9` | Split screen: background, both worlds via `PuzzlePainter`, white divider (0.4), clock strip or gap, phone HUD in screen space, the other side's mirror | `_background`, `_wrong`, `_right`, `_hudPanel 0x8C000000`, `_them` (orange); `Colors.white` / `white24`; widths `_stripBar 40`, `_gapBar 10`; HUD text sizes = box height × 0.08 / 0.04 (`PuzzleCamera.hudClockFraction`, `hudScoreFraction`) | literals from `view.dart`; no theme |
| `MirrorPainter` | `mirror_painter.dart:14` | The other side's board small: panel, faint targets, their placed pieces, their dot and held piece, orange frame | `_board`; fills 0.18, lines 0.5; frame `_them` 1.5 px; corner radius 2; white dot ring 1.0 px | literals (consts `_targetPx`, `_framePx`, `_corner`, `_targetFill`, `_targetLine`) |
| `ArenaPainter` | `packages/test_game/lib/src/arena_painter.dart:12` | Field: background, faint grid, start pad, goal, walls, hazards, sprites, aim cross, cooldown arc | `0xFF14181F` background, grid `white`@0.04, start pad `white`@0.08, goal `0xFF2E7D32`@0.55 + `greenAccent` stroke 3, walls `0xFF5C6B7A`, hazard `0xFFE53935` + core `0xFF7F0000`, sprite `playerColor` + `white` ring 2, dash glow `alpha 0.35`, cooldown arc `white54` 3; label sizes fraction of the shorter side (0.04, `r*1.1`) | **all literals**, no theme; `playerColor` only |
| `_ControllerPainter` | `tv_test_app/lib/src/ui/input_visualizer.dart:37` | The mini controller on the TV home | `base`/`lit`/`label` from `colorScheme.surfaceContainerHighest`/`primary`/`onSurface`; face colours `0xFF4CAF50 / E53935 / 1E88E5 / FDD835` (own const map) | theme + literals |
| `_FacePainter` | `controller_app/lib/src/ui/face_buttons.dart:77` | A/B/X/Y, letters, game labels | `FaceButtonsView.colors` = the same four hex values; base from `surfaceContainerHighest`, text from `onSurface`; `Colors.black` when pressed | theme + literals |
| `_FlashPainter` | `controller_app/lib/src/ui/pad_widgets.dart:83` | White flash over a pressed part | `Colors.white` @ 0.75 fading over 180 ms | literal |
| `_DpadPainter` | `pad_widgets.dart:160` | D-pad arms + arrows | `surfaceContainerHighest`, `primary`, `onSurface` @1 / 0.5 / 0.15; radius `s*0.06` | theme |
| `StatusShapePainter` | `controller_app/lib/src/ui/status_panel.dart:85` | The game's status shape (circle or polygon, turned) | `Color(shape.color)` from the status message; `Colors.black`@0.5 edge 1 px | protocol data + literal |
| `_StickPainter` | `controller_app/lib/src/ui/stick_widgets.dart:158` | Stick base, ring, knob | `surfaceContainerHighest`, `primary`, `outline`; alphas 0.4–1; knob `max(14, r*0.42)` | theme |
| `_TiltPainter` | `controller_app/lib/src/ui/tilt_view.dart:91` | Tilt circle, cross lines, dead-zone ring, dot | `surfaceContainerHighest` ring, `primary` dot, alphas 0.25/0.5 | theme |

Test-only: `packages/puzzle_game/test/mirror_png_test.dart` runs `MatchPainter` off-screen and writes the pictures
into `docs/design/m12-mirror-*.png` (`mirror_png_test.dart:81`); `controller_app/test/support/mirror_boards.dart`
builds the made-up boards for it. Nothing to re-skin, but a palette change makes those design pictures stale.

### 2b. The ThemeData each app builds

Both apps build the same theme, and nothing else:

```dart
ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5AAAFF), brightness: Brightness.dark))
```

- `controller_app/lib/main.dart:40-42` and `tv_test_app/lib/main.dart:52-54`; the party_host test harness repeats it
  (`packages/party_host/test/support/host_harness.dart:55`).
- **No** `textTheme`, `fontFamily`, `appBarTheme`, `cardTheme`, `pageTransitionsTheme` or `shadows` anywhere: all
  text sizes are Material 3 defaults (displayLarge 57 … bodySmall 12 at scale 1), all typography is the platform font
  (Roboto on Android, SF on iOS, Segoe UI on Windows), all elevation is Material's.
- The 0xFF5AAAFF seed is `playerColors[0]` (`packages/protocol/lib/src/messages.dart:319`) written out again.
- The TV's screens are the same package as the phone host's, so one theme serves three apps' worth of host UI.

### 2c. Shared constants

- `playerColors` (`messages.dart:319`): 6 colours as 0xAARRGGBB — `5AAAFF, FFA040, D27CFF, 4DE0C0, FF6F91,
  E8E86A`; `playerColor(n)` wraps around. Used by the puzzle dots and outlines, the Arena sprites, `PlayerBadge` on
  both apps and `_them` (the other side's orange). This is the only palette in the repository.
- Puzzle look consts: `_background`, `_wrong`, `_right`, `_hudPanel`, `_board`, `_them` (`view.dart:99-120`) and
  `PuzzlePainter._tray`, `_outlineGrey`; plus world units (`fieldSize = Size(160, 90)` `puzzle.dart:7`,
  `PuzzleGame.dotRadius = 2.6` `game.dart:86`).
- UI look consts: `hostRingPx = 4` and `hostButtonLook` (`host_button.dart:8-28`) — the one shared button style, built
  from `colorScheme.primary`/`primaryContainer`/`surfaceContainerHighest`; `hostMenuPaddingPx/TopPaddingPx`
  (`host_screen.dart:12-13`); `PressFlash.duration = 180 ms`; `ConnectionDot.dotSize = 12`.
- `0xFF14181F` (the "ink" dark) is written in 4 places: `view.dart:_background`, `arena_painter.dart:22`,
  `player_badge.dart:20` (the badge's digit) and `bar_connection.dart:124` (the P1 chip's text).
- `0xFF4CAF50/E53935/1E88E5/FDD835` (the face buttons) are written twice: `face_buttons.dart:10-15` and
  `input_visualizer.dart:45-50`.
- `0xFFE53935` is also `_wrong` (puzzle) and the Arena's hazard colour: one red, three meanings.
- `Colors.greenAccent` / `amberAccent` are the "good / caution" pair: 24 uses in 13 files (connection chips,
  results, ready card, Arena goal and counters, link status, latency, pairing status, haptics).
- No palette, style or spacing file exists; `docs/project-notes.md:55` says the spacing scale waits for this milestone.

### 2d. Colour literals per package (`lib/` only)

| Package | `Color(0x` | `Colors.` | Where the `Colors.` are |
| --- | --- | --- | --- |
| `packages/protocol` | 0 | 0 | (`playerColors` holds 6 raw ints instead) |
| `packages/puzzle_game` | 7 | 22 | match 13, puzzle 8, mirror 1 |
| `packages/party_host` | 1 | 19 | results 8, game screen 6, ready card 3, away card 1, focus scope 1 |
| `packages/game_kit` | 0 | 0 | draws nothing itself |
| `packages/test_game` | 7 | 10 | painter 6, view widgets 4 |
| `tv_test_app` | 5 | 9 | input_visualizer 2, pairing 2, controllers 2, latency 2, haptics 1 |
| `controller_app` | 9 | 11 | bar_connection 2, connect_screen 2, face 2, connect_panels 1, host_chip 1, pad 1, rating 1, status 1 |
| **Total** | **29** | **71** | 100 literals |

Plus one `Color(0x` in `party_host/test/support/host_harness.dart:56` (the seed).

## 3. Existing motion

| What | Where | What it does |
| --- | --- | --- |
| `Ticker` in `PuzzlePlayView` | `packages/puzzle_game/lib/src/play_view.dart:99,143` | Advances the match and calls `setState` each frame — the board redraws every frame |
| `Ticker` in `ArenaView` | `packages/test_game/lib/src/arena_view.dart:56` | Same for the Arena |
| `Ticker` in `FrameView` | `packages/game_kit/lib/src/frame_view.dart:98` | Plays the host's frames out on a joined phone (lerp between snapshots) |
| `PressFlash` | `controller_app/lib/src/ui/pad_widgets.dart:42-100` | 180 ms white flash over a pressed D-pad arm / face button — the only widget animation on the pad |
| `AnimatedOpacity` | `controller_app/lib/src/ui/rating_prompt.dart:212` | The rating faces fading in |
| Call flash | `puzzle_painter.dart:140-172` | A big piece's edge pulses toward each teammate at ~2 Hz (`sin(timeLeftMs/1000·2π·2)`), 1.6 px stroke, `blur(0.6)` |
| Hint glow | `puzzle_painter.dart:78-85` | The matching outline blurred at 2.5 and filled at 0.5 — static, not pulsing |
| Drop-ready | `puzzle_painter.dart:86-93` | The outline's fill 0.16 → 0.45 and stroke 0.5 → 0.9 plus `Colors.white` — a step, not a tween |
| Arena blink / dash glow / cooldown arc | `arena_painter.dart:95-125` | A recovering sprite blinks at 10 Hz; a dash draws a 0.35-alpha ring; the cooldown is an arc |
| Screen transitions | every `MaterialPageRoute` (e.g. `games_screen.dart:78`, `join_screen.dart:276`) | Material's default push; `AlertDialog`/`MenuAnchor`/`SnackBar` their own |
| **Confetti** | — | **Does not exist.** "Confetti" appears only in `docs/PRD-v2.md:268` (M13's results item) and in `docs/decisions.md:86` (the app icons' artwork). Nothing in `lib/`. |
| Shaders, Lottie, Rive | — | None: no `.frag`, no `FragmentProgram`, no `shaders:` in a pubspec, no animation package in `pubspec.lock` |

## 4. Flutter, Impeller, fonts, assets

- **Flutter: 3.47.8**, pinned in CI (`FLUTTER_VERSION`, `.github/workflows/ci.yml:30`, `release.yml:36`,
  `ios-fallback.yml:21`). `codemagic.yaml:21` uses `flutter: stable` (not pinned) and runs `flutter --version` in the
  log. No `.fvmrc`, no `.fvm/`, no version file at the root.
- **Dart: `sdk: ^3.13.0`** in the root and every package (`pubspec.yaml`, `controller_app`, `tv_test_app`,
  `assets`, `packages/*`); `assets/pubspec.yaml` also asks `flutter: '>=3.38.0'`. Workspace resolution.
- **Impeller: not configured anywhere.** No `io.flutter.embedding.android.EnableImpeller` in either
  `AndroidManifest.xml` (`controller_app/android/app/src/main/`, `tv_test_app/android/app/src/main/`), no
  `FLTEnableImpeller` in `controller_app/ios/Runner/Info.plist` (the TV app has no iOS target), and no
  `--enable-impeller`/`--no-enable-impeller` flag in `codemagic.yaml`, the workflows or `tools/`. So the engine
  default applies on both platforms.
- **Fonts: none bundled.** No `fonts:` section in any of the 9 pubspecs; both apps set only
  `uses-material-design: true`. The only font names in code are `'monospace'` (`diagnostics_screen.dart:42`,
  `log_panel.dart:15`) and `host_button.dart:72`, which copies whatever family the theme has.
- **Images: none bundled at runtime.** `assets/pubspec.yaml` declares only `audio/`; `assets/branding/` (icons,
  Play banners, screenshots) is source art for the stores and is not bundled; `assets/images/` holds only a README.
  Every visual is Canvas, a Material icon or a text glyph.
- **Audio** (for the same milestone): 10 `.ogg` files in `assets/audio/` (`error, help, hit, pickup, rumble, snap,
  success, tick, time_up, wrong`), played by `SoLoudSoundPlayer` (`party_host/lib/src/sound.dart`) through
  `flutter_soloud` (root pubspec pins the prebuilt libs, `prebuild_tag: v1.1.0`). No volume or mute setting yet; no
  looping.

## Summary (10 lines)

1. **Where the look lives today: scattered.** There is no palette file and no style file. The colours a player sees
   are 100 literals in `lib/` (29 `Color(0x`, 71 `Colors.`), one 6-colour `playerColors` list in `protocol`, and a
   seed colour typed out three times.
2. Two of the three visual worlds (the Shape Race board, the Arena) are painted in **game packages that own their
   colours privately** and draw with no `BuildContext`: `puzzle_game`'s `view.dart` consts and `test_game`'s painter.
   The third world, the host's menus and cards, takes its colours from the app's **one Material dark theme**.
3. So a re-skin today is a two-language job: a theme change moves every menu, card and pad at once, but moves **none**
   of the board.
4. **Biggest obstacle 1: no context in the painters.** `PuzzlePainter`, `MatchPainter`, `MirrorPainter` and
   `ArenaPainter` are built with data only; a palette has to be passed in (or the consts become a settings object)
   before a theme can reach them.
5. **Biggest obstacle 2: the same painter draws on three surfaces.** A phone joined to a TV draws the host's board
   from frames (`FrameView`), the host draws it locally, and a phone host draws it behind its own pad — all through
   the same `MatchView`/`ArenaBoard`, so every look must be identical input (a palette, sizes from the box, no
   `MediaQuery`), or the two phones would look different.
6. **Biggest obstacle 3: one colour, many meanings, and copies.** `0xFF14181F` in four places, the four face-button
   hexes in two, `0xFFE53935` as "wrong" and "hazard", `greenAccent`/`amberAccent` in 24 places. Changing one now
   changes some and not others.
7. **Shape Race re-skin must touch:** `packages/protocol/lib/src/messages.dart:319` (`playerColors`) ·
   `packages/puzzle_game/lib/src/view.dart:99-120` (background, wrong, right, board, HUD panel, the other side's
   orange) · `puzzle_painter.dart:16-17` (tray, grey outline) and its strokes/alphas/text sizes · `match_painter.dart`
   (HUD, divider, bar) · `mirror_painter.dart` (frame, faint targets) · `packages/puzzle_game/lib/src/camera.dart`
   (HUD fractions, if type changes) · the puzzle's own piece colours (`puzzle_game` puzzle data).
8. **Menus and everything around the board must touch:** both apps' `ThemeData` (`controller_app/lib/main.dart:40`,
   `tv_test_app/lib/main.dart:52`; the host harness copy) · `party_host/lib/src/ui/host_button.dart` (`hostButtonLook`,
   the one shared button look) · `host_screen.dart` (title bar), `games_screen.dart` (cards), `join_screen*.dart`
   (side panels), `puzzle_screen_widgets.dart` (results card and its green/amber), `pause_menu.dart` (dialog),
   `away_card.dart`, `ready_card.dart`, `player_badge.dart` · the phone's `controller_top_bar.dart`,
   `bar_connection.dart` (badge, dot, green/amber), `bar_modes.dart`, `host_chip.dart`, `status_panel.dart`,
   `face_buttons.dart`, `pad_widgets.dart`, `stick_widgets.dart`, `tilt_view.dart`, `waiting_card.dart`,
   `rating_prompt.dart`, `host_start_sheet.dart` · the TV's `home/*` panels, `input_visualizer.dart`, stats and
   haptics screens.
9. **The Arena (the planned first shader target) is the easiest to make theme-aware** — one painter, seven hexes,
   one view widget — and the Shape Race board is the hardest, because it has the most states (outline, ready, hint,
   wrong, locked, held, calling) drawn with alpha overlays rather than a look per state.
10. Nothing in `game_kit` draws, so a shared "look" belongs beside it (a new package or a `game_kit` file) and is
    handed down to both painters and host screens; today there is nothing to hand down.

## Self-check (review-rules part A)

1. **Every host setup:** not affected — read-only survey, no behaviour changed.
2. **When kept state starts and ends:** not affected.
3. **How a new state combines with the others:** not affected.
4. **Stay in the job's folder:** yes — only `docs/briefs/m12/look-inventory-report.md` was written.
5. **Stop rather than overstep:** nothing needed outside `allow:`; the brief asked for facts, and no fact needed a
   guess (the one judgement I could not make from the repository — what the "Toy Box Toon" look should be — belongs
   to `look-sources.md`, not here).

## Questions and suggestions

1. Q: the palette has no home yet. My reading of review-rules C1 and code-health is that a re-skin wants one place
   that both painters and host screens read (a `Look` object in `game_kit` or a new `packages/look`); the brief did
   not ask me to choose, so I only report the gap.
2. Q: `playerColors` lives in `protocol` (a wire-free palette but a UI concern). A re-skin that changes it changes
   both apps at once — good — but it is then a protocol *package* change without a protocol change; is that intended,
   or should the palette move out of `protocol`?
3. Suggestion: the six values that are already shared by meaning (`0xFF14181F`, the four face colours, the
   green/amber pair, the 0xFF5AAAFF seed) are the natural first constants to name, before any look is chosen; they
   would let a future change move all copies together.
4. Suggestion: the painters' text sizes are world units and box-height fractions, not theme sizes — worth a note in
   the design, because a new font would change how those fractions fit (`PuzzleCamera` measures text width by
   `text.length × glyphEm`, a fixed estimate, so a wider face would break the HUD's placement).
5. Note for the design: `Impeller` is on by default and unconfigured, so a fragment shader (`FragmentProgram`) would
   run on both platforms with no build changes; but nothing in the repository has ever compiled one, so the first
   one carries a build-risk check on Windows (the TV app's desktop target) that the design should name.

## Commit message

```
docs(look): inventory every screen, painter and colour before the re-skin

The look has no home: 100 colour literals across 7 packages, one
playerColors palette in protocol and a seed colour typed three times.
The Shape Race board and the Arena paint with private consts and no
BuildContext, so a theme change moves every menu and none of the board.
The report lists every screen by kind, every CustomPainter with its
colours and their source, the motion that exists (and that the confetti
does not exist yet), Flutter 3.47.8, Impeller unconfigured, no bundled
fonts or images, and every place a re-skin must touch.
```

## Status row

| Look inventory (Nov 8) | **Done (read-only)**: every screen and overlay of the TV app, the phone controller and the phone host is catalogued (file, purpose, kind); every CustomPainter with its colours and whether they are literals or theme; both apps' one ThemeData; the shared constants and the colour-literal count per package (29 `Color(0x` + 71 `Colors.` in `lib/`); the existing motion (three Tickers, one 180 ms press flash, in-painter pulses; no confetti, no shaders); Flutter 3.47.8 in CI, Impeller unconfigured, no bundled fonts or images. **Open:** where a palette and a look should live (nothing exists to hand one down), and whether `playerColors` moves out of `protocol`. |

## Delete

- none