# Architecture

```
 Phone (controller_app)                         TV / laptop (tv_test_app)
 ┌───────────────────────┐   WebSocket (JSON,   ┌────────────────────────────┐
 │ D-pad / gyro input    │   versioned, with    │ WebSocket server + mDNS    │
 │ haptics (native)      │ ──── heartbeats) ──▶ │ pairing code, ping         │
 │ discovery, pairing    │ ◀── haptic events ── │ visualizer, test game      │
 └──────────┬────────────┘                      └─────────────┬──────────────┘
            └────────── packages/protocol (pure Dart) ────────┘
```

Since M12 a phone or tablet can host too: `controller_app` runs `party_host`, and its own player reaches it over an in-process link. The M12 sections at the end of this page say who draws the game and who gets its frames.

## Repo layout
| Path | What | Platforms |
| --- | --- | --- |
| `controller_app/` | Phone and tablet controller; since M12 it also hosts, with the `party_host` screens behind its own controls | Android (minSdk 36), iOS 26+ |
| `tv_test_app/` | TV test bench: the shell around `party_host` (home screen, test tools) and the TV-only parts | Android TV (minSdk 31), Windows desktop |
| `packages/protocol/` | Message definitions and codec, capabilities and roles. No Flutter dependency | anywhere Dart runs |
| `packages/connection/` | The transports (WebSocket, in-process), the host server, the phone client (pairing, heartbeats, reconnect), `GameHost`, the viewer's timing and stats, and the simulated controller (`bin/sim_controller.dart`). Pure Dart (`dart:io`) | anywhere `dart:io` runs |
| `packages/metrics/` | Analytics (M9 to M12): the phone's touch counters per mode segment, the host's session summary (rounds, battery, heat, where each player watched, frames a second) and the report tool (`bin/report.dart`). Pure Dart | anywhere Dart runs |
| `packages/game_kit/` | The host's game loop (M12): a `GameSession` in fixed steps that publishes frames, the `GameModule` and `GameViewer` a game exports, and `FrameView`, which draws the game a host shows | Flutter |
| `packages/test_game/` | The Arena (M5): rules in `ArenaGame` (no widgets, unit-tested), `ArenaSnapshot`, `ArenaView`, the session and the module | Flutter |
| `packages/puzzle_game/` | Shape Race (M10): puzzle data (`puzzles/`), rules in `PuzzleGame` and `PuzzleMatch`, snapshots, the split layout and the phone cameras, the views and the module | Flutter |
| `packages/party_host/` | The host app's services and screens (M12): `HostService`, advertising, `HostPresence`, stats, sound, and the game picker, join, play, pause, results, Puzzle settings and Stats screens. Both hosts use them | Flutter |
| `assets/` | `game_assets` package: images, audio (`audio/`, bundled as a folder), `CREDITS.md`, asset manifest (`lib/asset_manifest.dart`) | Flutter |
| `docs/` | PRD, decisions, setup guides, per-milestone checklists | |

## Principles
- **Protocol is platform-independent.** Nothing in `packages/protocol` knows about Android TV, Windows or Flutter, so Apple TV or smart-TV hosts can be added later.
- **One host stack (M12).** Everything a host does lives in `party_host`; the TV app and the phone app each supply their identity, folders and platform pieces and nothing else. What a TV host does, a phone host does through the same code (coding guidelines §6).
- **Hardware behind interfaces.** Haptics, sensors, discovery and transport each sit behind a Dart interface with a fake implementation, so logic is testable on Windows.
- **Minimal native iOS code.** One small haptics platform channel (M2) plus Info.plist configuration. Everything else uses well-established Flutter packages.
- **No paid-account capabilities.** No push notifications, App Groups, extensions, iCloud or associated domains.
- **No stuck inputs.** On disconnect or app backgrounding the controller sends "release all", and the TV also releases all inputs for a controller whose connection drops.

## Message flow
Every frame is JSON text: `{"v": 1, "t": "<type>", ...}`. A different `v` closes the connection with code 4000, so mismatched builds fail loudly. Unknown types are ignored.

| Step | Direction | Message |
| --- | --- | --- |
| 1 | phone | Finds `_gamectl._tcp` via mDNS (TXT: `id` = host ID, `v` = protocol), or the user types `IP[:port]` |
| 2 | phone → TV | Opens `ws://<address>:45780/ws` and sends `hello` (controllerId, name, platform, appVersion) |
| 3 | TV → phone | `welcome` (hostId, hostName, appVersion) |
| 4 | phone → TV | `pair` with the typed `code`, or with the `token` saved from an earlier pairing with this hostId |
| 5 | TV → phone | `pair_result`: `ok` + `token`, or a `reason` (`wrong_code`, `too_many_attempts`, `unknown_token`) |
| 6 | both | `ping` every second, answered by `pong` echoing `id` and `sentAt` (plus `at`, the answering side's clock, from M6). Each side measures round-trip time on its own clock. |
| 7 | TV → phone | `player` with `n`, the controller's player number (M6) |

Rules:
- **Pairing.** The TV accepts nothing but `pair` (and heartbeats) until a controller pairs. A wrong code gets `pair_result` and close code 4001. After 5 wrong codes in a row the TV shows a new code. Unpaired connections close after 5 minutes (4005).
- **Tokens.** The TV issues a random token per controller on a correct code. The phone saves it per hostId, and the TV app saves its pairings too (M6, up to 8), so reconnects, app relaunches and TV app restarts skip the code. A TV that doesn't know the token (forgotten with **Forget phones**, or another install) answers `unknown_token` → enter the code again.
- **Heartbeats.** Silence for 4 seconds counts as a dropped connection on either side (close code 4004 when it can be sent).
- **Reconnect.** After being paired, the phone retries forever with backoff (0.25, 0.5, 1, 2, then every 3 s) and resumes with its token. If discovery finds the same hostId at a new address, the next attempt uses it. It doesn't retry after a version mismatch (4000), being replaced by a newer connection from the same phone (4002) or a protocol error (4003).
- **One connection per controller.** When a controller pairs again (often after a half-open drop), the TV closes the older connection with 4002.
- Haptic events (TV → phone, M5) use the same connection. A phone that sends one is closed with 4003.

## Input (Milestone 2)
- **Full state, not events.** On every change the phone sends `input` with `seq`, the held `buttons` (`a`, `b`, `x`, `y`, `start`, `select`) and the D-pad as `dx`, `dy` (each -1, 0 or 1; `dy` -1 is up). The TV keeps the latest state per controller, so a lost or late release can't leave a button stuck, and an empty state releases everything.
- **Order.** `seq` grows with every state. The TV ignores anything not newer than what it has, and ignores input from controllers that haven't paired.
- **No stuck inputs.** The phone releases everything when the app leaves the foreground (any lifecycle state other than resumed). After a reconnect it sends its current state again. The TV drops a controller's state when its connection ends and reports an all-released state to anything reading the input stream.
- **Ticks.** The phone plays one tick per change: presses and new directions at full strength, releases and re-centering at 60%, scaled by the intensity setting.

## Haptics
`lib/src/haptics.dart` defines the `Haptics` interface (capabilities + tick), with `PlatformHaptics` (the channel `com.thumbparty.app/haptics`) and `FakeHaptics` for tests. `HapticsPlayer` applies the on/off switch, intensity and hardware limits, and swallows native errors so input keeps working.

| Platform | Native code | Tick | Fallback |
| --- | --- | --- | --- |
| iOS | `ios/Runner/AppDelegate.swift` (`HapticsChannel`, kept in that file so the Xcode project needs no edits) | Core Haptics transient event, intensity from the setting, sharpness 0.7. The engine runs while the app is open and restarts after a reset or on return to the app. | `UIImpactFeedbackGenerator` if the engine can't start. No Taptic Engine → reported as unsupported. |
| Android | `android/.../Haptics.kt` + `MainActivity.kt` | `VibrationEffect` composition with the click primitive, scaled by intensity, usage "media" (games) | 12 ms one-shot, with amplitude if the motor allows it, otherwise on/off. No vibrator → unsupported. |

## Gyro mode (Milestone 3)
The pipeline runs on the phone in pure Dart (`controller_app/lib/src/tilt.dart`, unit-tested), fed by `sensors_plus` at 100 Hz:

1. **Up direction (complementary filter).** Each gyroscope sample rotates the estimate of "up" in phone coordinates (`v' = v + (v × ω)·dt`), then nudges it 2% toward the accelerometer, but only while that reads about 1 g. The gyro gives smooth, fast tracking, and the accelerometer removes its drift within about half a second.
2. **Screen axes.** Gyro mode locks the screen to the landscape side the phone is held in, so tilting doesn't rotate the UI and the axes stay put. The side comes from a light accelerometer check (10 per second, also in D-pad mode, changing sides only after about 0.3 s, like iOS), so starting gyro mode lying flat still knows it. Flutter's landscape names follow Android; on iOS the opposite name locks the same physical side (`orientationFor` in `gyro.dart`). `landscapeLeft` (top of the phone on the left): screen right = phone −y, screen up = phone +x.
3. **Two angles that work held flat or upright.** Roll = −asin(up · screen-right): tilting or steering right is positive. Pitch = atan2(up · screen-up, up · out-of-screen): how far the screen faces the sky.
4. **Calibration.** The filter starts fresh every time the sensors start (entering gyro mode or returning to the app) and settles for about 0.3 s with a stronger pull toward the accelerometer. The stick stays centered meanwhile. The first settled reading (and every **Calibrate**) becomes neutral, and values are the difference from it.
5. **Stick values.** `x = Δroll · sensitivity / 30°` and `y = Δpitch · sensitivity / 30°`, clamped to −1..1, then exponential smoothing, then a round dead zone that rescales what's outside it. Tipping forward gives negative y, like "up" on the D-pad.
6. **Sending.** About 60 times a second, and only when the value (rounded to 3 decimals, as on the wire) changes, in the same `input` message as the buttons (`ax`, `ay`). Older TVs ignore the extra fields, and leaving gyro mode drops them.

Leaving the app pauses the sensors and centers the stick. Coming back resumes with the same calibration. Without a working gyroscope (stream error or no reading within 1.5 s) gyro mode stays off with a message, and the D-pad keeps working.

## Stick mode (Milestone 4)
- **Layout** (`controller_app/lib/src/sticks.dart`, `stickLayout`): computed from the available size. LB and RB along the top; the left stick upper left with the D-pad below it toward the middle; A/B/X/Y upper right with the right stick below it toward the middle; Select and Start in the middle. Unit tests check that nothing overlaps and that controls stay thumb-sized on five phone sizes.
- **Sticks**: the thumb's offset from the stick's center is divided by its travel, scaled by sensitivity, kept inside the unit circle, then passed through the round, rescaled dead zone. **Fixed** sticks take touches on their circle. **Floating** sticks take them anywhere in their half and center where the thumb lands; the other controls are stacked on top, so they win where they overlap. Letting go sends the center at once.
- **Wire**: the same `input` message gains `lx`, `ly`, `rx`, `ry` (present only in stick mode) and the buttons `lb` and `rb`. Older TVs ignore both, so the protocol stays v1.
- **Rate**: buttons, the D-pad, mode changes and a stick returning to center go out at once. Stick and tilt movement is capped at one send per 16 ms (about 60 per second), always sending the latest value.
- **Mode switches** let go of every finger and center or drop the old mode's analog inputs, so nothing from the old layout stays held.

## TV-to-phone haptics (Milestone 5)
- **Wire**: the TV sends `{"t": "haptic", "event": "hit" | "success" | "error" | "rumble", "intensity": 0..1, "ms": 20..3000}`. The phone ignores it unless paired, and ignores an event name it doesn't know (a newer TV), so the protocol stays v1. Older phones ignore the whole type.
- **Patterns live in Dart** (`controller_app/lib/src/haptic_patterns.dart`): each event is a list of segments `[startMs, durationMs, intensity, sharpness]`, where duration 0 is a tap. Native code only plays segments, so tuning a pattern needs no Swift change (and no extra cloud build).

| Event | Pattern (natural length) | How `ms` applies |
| --- | --- | --- |
| hit | One short, deep thud: a heavy tap and a 100 ms tail (one pulse) | Stretches the pattern |
| success | Three crisp, rising taps 130 ms apart, the last one ringing out (three pulses, 450 ms) | Stretches the pattern |
| error | Two long, harsh buzzes, 110 ms each with an 80 ms gap (two pulses, 300 ms) | Stretches the pattern |
| rumble | A deep throb, full and 45% strength in turns every 70 ms (400 ms) | How long it lasts |

M6 reworked them after the M5 device test ("a little hard to differentiate"): they now differ in the number of pulses, rhythm and length, not just strength.

- **Playing**: the TV's intensity × that event's own strength setting on the phone (M6, 100% by default, 0% = off) scales every segment. The button tick has its own setting. The haptics switch silences TV events as well as ticks. Events arriving while the app isn't in the foreground are skipped.
- **iOS** (`AppDelegate.swift`, method `play`): one `CHHapticPattern` per event (transient and continuous events). A new rumble stops the one still playing. If the engine was stopped behind the app's back, it restarts and tries once more, then falls back to UIKit (success/error notification feedback, otherwise one heavy impact).
- **Android** (`Haptics.kt`, method `play`): the segments become one `VibrationEffect` waveform. Taps are 15 ms (crisp) or 30 ms (round) pulses, overlapping segments take the stronger amplitude, and a motor without amplitude control gets an on/off pattern. Android plays one vibration at a time, so a tick during a rumble cuts the rumble short.

## Sound on the TV (Milestone 5)
- `tv_test_app/lib/src/sound.dart`: `SoundPlayer` with `play(event)`. The game and the haptic test call only that, so the audio package can be swapped. `SoLoudSoundPlayer` uses **flutter_soloud**, which decodes OGG and WAV itself, on Android TV and Windows alike. A missing file or a failed engine is silent and reported on screen.
- Files come from the asset manifest (`assets/lib/asset_manifest.dart`): `audio/<event>.ogg`, or the same name as `.wav`. Replaying a sound that is still playing restarts it instead of layering.
- **Firing an event** (`tvEventsProvider`): the sound and the haptic event always go out together, and the TV log records each one with what fired it and how many controllers got it.

## Test game (Milestone 5)
`packages/test_game`: a top-down arena (PRD "Test game design"). The field fills the window; positions are fractions of the field, and sizes and speeds are fractions of its shorter side, so it plays the same in any window and survives resizing.

| Rule | Value (first proposal, tune on devices) |
| --- | --- |
| Movement | D-pad: full speed (0.55 field-heights per second), diagonals too. Tilt or left stick: scaled by how far it's pushed |
| Dash (A, on the press) | 2.6× speed for 0.3 s in the direction last moved, 1.2 s cooldown. Sends **rumble** for 300 ms. Pressed during the cooldown: **error** |
| Walls and edges | Bumping one at a quarter of full speed or more sends **hit** (70%, 100% while dashing). Sliding along it or keeping pushing into it doesn't repeat; moving away and bumping it again does, at least 0.3 s apart. Movement is split into small steps so a dash can't pass through a wall |
| Hazards | Four red discs: three slide back and forth, one circles near the goal. A touch sends **hit** (100%), knocks the sprite back and gives 0.8 s of grace (it blinks). Hazards never end a round |
| Goal | Sends **success**. The next round starts after 2 s with the field mirrored, so start and goal swap sides |
| Right stick | Moves an aim cursor around the sprite (no effect yet) |
| On screen | Round, timer, best time, wins, hits, dashes (and how many were too soon), dash ready |

The TV app runs it in `ui/game_screen.dart`. Every connected controller drives its own sprite in its player colour (M6), and each event goes only to the controller whose sprite caused it. OK, Enter, D, F3, or the remote's Info/Menu key toggles a debug overlay: controller, connection, ping, input mode, stick or tilt values, buttons, the last haptic event sent, and the sound status. Back (or Esc) leaves.

## Milestone 6: settings, latency, reconnects and several controllers

### Settings (phone)
One **Settings** screen (`controller_app/lib/src/ui/settings_screen.dart`) holds the haptics switch, the button tick strength, a strength per TV event (with **Try** buttons), and the gyro and stick settings. Each is saved in `shared_preferences` the moment it changes (`hapticsEnabled`, `hapticsIntensity`, `hapticsEvent_<event>`, `gyroSensitivity`, `gyroDeadZone`, `gyroSmoothing`, `stickDeadZone`, `stickSensitivity`, `stickFloating`), and so is the last mode (`padMode`). On launch the app goes back to that mode; gyro mode waits a second first, so the screen locks to a settled landscape side (the M3 lesson).

### Latency (TV)
The two devices' clocks aren't synchronized, so the TV estimates the offset between them from its own heartbeats, as NTP does (`packages/connection/lib/src/latency.dart`):

1. The TV pings at `t0` (its clock). The phone answers with `pong` carrying `at` = its own clock `t1`. The answer arrives at `t2`.
2. If the trip took as long both ways, the phone's clock is ahead by `t1 − (t0 + t2) / 2`. The ping with the shortest round trip in the last 20 s gives the best estimate, and half its round trip bounds the error (the "±" on screen). The short window follows the slow drift between the clocks.
3. Every `input` carries `ts`, the phone's clock when it was sent. Its one-way delay is `arrival − (ts − offset)`.

The TV keeps those delays for the last 30 s (min, average, p95, max) and for the whole connection, and logs a line per controller every 30 s plus a summary when a connection ends. The **Latency** screen shows them against the ~50 ms target, and **Save log** writes them with the whole log to a file. What it doesn't include: the touch-to-app delay on the phone (a few ms), up to 16 ms of the 60-per-second cap for analog movement, and the TV's own display delay. Both new fields are optional, so older phones still work and simply show "not measured".

### Reconnect hardening
| Case | What happens |
| --- | --- |
| Phone sleeps, or the app goes to the background | The TV drops the connection after 4 s without heartbeats and releases that phone's input. On return, the app calls `ControllerClient.resume()`: a connection quiet for more than 2 s (wall-clock time, since the monotonic clock may not advance during sleep) is replaced at once, and a pending retry runs now. |
| TV app restarts | The phone retries (up to every 3 s). The TV app saved its pairings (`pairings` in its preferences), so the token is still valid and no code is needed. |
| TV at a new address or port | Discovery reports it and the next attempt goes there at once. While reconnecting, the phone restarts discovery every 4 attempts in case it missed the change. |
| Changed network | The old socket dies, the heartbeat catches it, and the same retries and discovery apply. |
| The TV dozing off | Nobody touches the remote while playing, so the TV app keeps the screen on while any controller is connected (`tv_test_app/lib/src/screen_awake.dart`, `wakelock_plus`). Found in the 30-minute test run: without it the TV slept after about 10 minutes. |

Diagnostics on the phone lists the last 10 drops with their reason and how long each took to recover.

### Several controllers
The TV gives each paired controller a player number (`player` message): its old number if it's free, otherwise the lowest free one. A number stays reserved for a minute after its controller drops, so a short Wi-Fi drop doesn't swap players. The colours (`playerColors` in the protocol package) are shared by the TV's badges and sprites and the phone's badge. In the game every connected controller drives its own sprite (`ArenaGame.update` takes one input per controller ID; a controller that disconnects leaves, a new one joins at the lowest free start position), events carry the player who caused them, and the first to reach the goal wins the round.

### Battery and CPU
The phone's native channel has one more method, `deviceStatus`: battery level and charging, Low Power Mode, the thermal state, and this app's CPU time (`getrusage` on iOS, `Process.getElapsedCpuTime` on Android). `SessionMonitor` samples it every 10 s, and Diagnostics shows CPU use in % of one core (last minute and since launch), battery drain per hour (after 5 minutes on battery), heat and the input send rate.

## Milestone 9: analytics and platform groundwork
The protocol is written down in [protocol.md](protocol.md) (P1), including capabilities (P2), roles (S3), the metrics and rating messages and the standard gamepad mapping (P4).

- **Game host interface (P3).** `GameHost` in `packages/connection` is all a game or a TV test screen uses: players (number, colour, nickname, local or not), each player's `GamepadState`, haptics, rating prompts, latency, analytics records and named delay stages (S7). `ServerGameHost` wraps the `HostServer` and adds local players (S2: the keyboard player on Windows); `MemoryGameHost` is the in-memory one for tests. The arena (`ArenaView`), the haptic panel, the latency screen, the debug overlay and the input picture all go through it.
- **Phone metrics.** `PhoneMetrics` (controller_app) records one `SegmentRecorder` (packages/metrics) per mode and settings while connected, fed by a listener over the controls, the pad notifier (held controls, slide-offs, sticks, tilt), Calibrate and the TV's haptic events. Touch areas come from the same layout functions as the controls (`touchMapFor`). Batches go through `ControllerClient.sendMetrics`, which keeps unacknowledged ones across reconnects.
- **TV collection.** `LiveStats` (tv_test_app/lib/src/analytics.dart) joins server messages, game records and stages into a `SessionCollector`, saves the summary to the app's support folder (`sessions/`) every minute and when the session ends, asks for ratings (`RatingScheduler`), and with consent uploads finished sessions through `FirestoreUploader` (REST, no SDK; rules in `firebase/firestore.rules`). The Stats screen reads the files and exports them.
- **Privacy.** Only counts leave the phone, only to the TV. The TV keeps known counters only (`sanitizeSegmentData`) and never names or addresses. Upload needs the adult's consent on the TV; each phone can opt out. See [families-check.md](families-check.md).
- **Active time (m11.3).** Each mode segment also reports `activeMs`: time near player activity (touches, presses and releases, a touched stick, a tilt change of 0.05 or more), counting up to 5 s after the last input and all of any hold. The session summary keeps both (`ms`, `activeMs`) per mode and segment, and the report's per-minute figures, the CSV's `minutes` column and the Stats screen's "Time playing" column use active time; the report's `open min` column and the CSV's last column (`open_minutes`) keep the old time. Older phones without `activeMs` count their whole segment.

## Milestone 10: the puzzle game, game-defined controls and the status panel
- **packages/puzzle_game.** `Puzzle` (data from `puzzles/*.json`, listed in `puzzles/index.json`; pieces as polygons, rectangles or circles with their symmetry worked out), `PuzzleSettings` (every playtest value with its range), `PuzzleGame` (the rules: moving, picking up, rotating, dropping, snapping with symmetry and identical pieces, red pieces, the drop-ready highlight, the hint glow, the clock and the metrics; no widgets) and `PuzzleSnapshot` (the compact, versioned state the view draws from, under 2 KB). `PuzzleView` draws a snapshot into whatever box it gets, keeping 16:9 (S4); `PuzzlePlayView` runs a game through the `GameHost` only: it reads gamepads, sends haptics, sounds by name (S5), the phone layout and the status panel, and analytics records. The arena was changed the same way: `ArenaView` now draws only from `ArenaSnapshot` (S8).
- **TV.** The home screen's **Play** opens the game picker (`GamesScreen`): Shape Race (pick a level or a puzzle) and the Arena, plus **Puzzle settings** (saved under `puzzleSettings`, applied from the next frame). Debug runs save sessions to `sessions-debug`, so test sessions don't mix with real ones. Game sounds come through the host's `sounds` stream and play by `SoundKey` event name.
- **Game-defined controls (P5) and the status panel (P6).** Two new host → phone messages, behind the `layout` and `status` capabilities ([protocol.md](protocol.md) §8a, §8b). `ServerGameHost` keeps each player's layout and status and sends them again after a reconnect, and sends status at most 10 times a second. On the phone, `gameLayoutProvider` and `gameStatusProvider` follow the client. Labels are drawn inside the face buttons (or replace Start/Select/LB/RB text), hidden buttons ignore touches, disallowed modes can't be picked and a forced mode isn't saved. The panel sits in the top bar in the ping's place, so no control shrinks (C24, tested in all three modes).
- **Short taps.** Games read each gamepad once a frame, so `ServerGameHost` reports every press as held for at least 50 ms; a tap whose press and release arrive between two frames still counts.
- **New haptics and sounds (C21).** `snap`, `wrong`, `dropReady`, `tick` and `help` events with their own patterns and strength settings on the phone, and matching sounds on the TV (Kenney, CC0; `assets/CREDITS.md`).

## Milestone 11: Shape Race for 2 to 4 players, and the whole TV app from a controller
- **Matches (`PuzzleMatch`, packages/puzzle_game).** The join screen gives each player a side (`PuzzleSide.left` or `right`, at most two a side). The format follows from who joined (`MatchFormat`): one player or a team of two plays on one board, as in M10; otherwise two `PuzzleGame`s race side by side, each in its own world from `SplitLayout` (since m11.1): each side's board is cropped to the puzzle's picture, and the tray goes beside it (at the outer edge) or below it, with the clock in a strip along the top or between the boards, whichever draws the board biggest for that puzzle (m11.2: about 87% to 124% of its one-board size, up from 57% in m11). A game's `PuzzleField.origin` is where the puzzle data's (0, 0) lands. Since m11.2 the layout depends on the match's seed: both sides start with the same angles (`startAngles`), the tray is sized for exactly those, and its rows overlap in a pile (`trayOverlap` 0.5; `packTray` backs the overlap off so every piece keeps at least 55% of its shape in view), its pieces drawn and reached at `trayScale` 0.75 until first picked up, the start angles the most compact allowed ones (`compactStartAngles`; a long piece that starts correct lies along the tray), the clock in a 6-high strip or a 12-wide gap with the boards together in the middle, and A taking the top piece under the dot (pieces have a `layer`; a piece put down goes on top). The match snapshot carries the seed and each board the pieces' draw order, so a phone can rebuild the same picture (M12). The one-board tray is unchanged. Players only play on their own side, so they stay in their half; players who didn't join watch. Both sides get the same tray (one seed), and both clocks run together. The first side to finish wins and the other side stops; at time-up more pieces placed wins; equal counts (including none), or both finishing in the same frame, are a draw.
- **Big pieces.** One piece per puzzle has `"big": true`. On a side with two players it's carried as a team: both on it, it follows the average of their pushes at normal speed, and either can turn it or drop it (one press drops it for both); one alone moves it at the solo big-piece speed (35%), its edge flashes toward the free teammate, and that teammate gets a `help` haptic at once, then every help interval (3 s). Alone on a side it's an ordinary piece at full speed. A teammate takes the other end by pressing A on it; an ordinary held piece still can't be taken.
- **Snapshots.** `MatchSnapshot` holds one or two boards. A piece lists all its carriers and whether it's calling for help (`cl`); a 4-player snapshot of the biggest puzzle stays under 2 KB.
- **Who has the controllers.** `ControllerMenus` sits at the root of the TV app and lets every phone work every screen like the remote: the D-pad or left stick moves the focus (a held direction repeats after 0.45 s, then every 0.15 s), A presses, B goes back on whatever navigator has the focus, and the phones show A "OK" and B "Back". It never leaves the focus where A can't press (it moves it to the first pressable control), and it ignores simulated and local players. A screen that reads the controllers itself (a game, the join screen) wraps itself in `ControlsClaim(Controls.game())`; the newest claim wins. Games set the phone's buttons while they run and don't reset them when they end: the menus take them back.
- **Pausing (`Pausable`).** Any player's Start pauses the game for everyone and opens the pause menu (Resume, Quit). Its claim limits the menus to the player who paused and Player 1 (anyone, if neither is here any more), who can also resume with Start. Quit goes back to the game picker (the route named `/games`). The puzzle and the Arena both use it; the Arena labels Start "Pause".
- **Join and results (T13, T14).** `JoinScreen`: A joins the side with fewer players, left or right (D-pad, stick or tilt) switches sides, B leaves a side or goes back, Start (or the remote's OK) begins. Simulated controllers join by themselves; on Windows the keyboard joins with Space. The results show the winner and each side's time or pieces, with Rematch (Play again on one board: same teams; a random puzzle becomes another random one), Change teams and Back. The keyboard player is handed from screen to screen, so it keeps its side.
- **Simulated controllers.** The TV's home screen adds up to three (`addSimulatedController`), so a 4-player match can be checked with one phone.
- **Analytics.** Each player's result adds pieces placed, completion time, win and draw, and for teams help calls, solo big-piece carries and the time spent on them. The round end has the format and the winners; the session summary counts rounds per format and wins and draws per input mode.

## Milestone 12: phone-hosted play
Play with no TV: a phone or tablet runs the whole host itself, and the other phones join it and see the game. The design is [m12.md](design/m12.md); each step's contract is beside it. The sections below are the shape of the code.

### Two hosts, one stack
- **The TV host** is `tv_test_app`: a shell around `party_host` (home screen, test tools, the Windows keyboard player). `LiveHostService` listens on the network, advertises the service with the `kind` its identity names, and plays the games on its own screen.
- **The phone host** is `controller_app`. "Host a game" builds the same `LiveHostService` with the phone's identity, folders, a `LanListener` on the network and an `InProcessListener` for the phone itself. The `party_host` game picker, Puzzle settings and game screens are the body, with the phone's own `ControlsLayer` over them. "Show on this device" leaves that layer out (C34), so the phone draws the games like a TV: its own player can't press anything then, and the other phones play.
- **The host phone's own player** is an ordinary `ControllerClient` over `InProcessLink`, pairing with the host's code like a phone on the Wi-Fi (D1). It keeps every controller feature — haptics, layouts, status, rating, metrics — and the host marks its channel `local`.
- **What each side draws:**

| Host | `shareView` | Who draws the game | What a joined phone shows |
| --- | --- | --- | --- |
| TV app, PC, or "Show on this device" | false | the host's screen only | its controls, as before |
| "Play on this phone" | true | the host phone, and every joined phone | the game behind its own controls |

`HostService.shareView` decides who gets frames, and a change applies from the next `view_start` (m12-joined-view §0.1). The phone host sets it from the start sheet's choice; the TV app keeps it false, and the dev TV app turns it on with a debug define. The host phone's player pairs without the `view` capability, so it never gets frames of its own game.

### Transport (M12 step 2)
The server and the client no longer name a socket: they talk to a channel, so the host phone's own player can join a game without a network (D1). The contract is in [m12-transport.md](design/m12-transport.md).

- **Three interfaces** (`packages/connection/lib/src/transport/`). `MessageChannel` is one open, ordered, text-only connection with a close code and reason; `ChannelListener` accepts channels for the server; `Connector` opens one for the client and gives up when the client says the session changed. `HostServer({listeners})` starts one or more listeners, `ControllerClient({connector})` opens its channels through one.
- **Two transports.** `WebSocketListener`, `WebSocketConnector` and `WebSocketChannelAdapter` are the LAN transport that was there before, now with the bind, the status page and the connect loop inside them. `InProcessListener`, `InProcessConnector` and `InProcessLink` connect two ends inside one process.
- **Why in-process.** A phone host plays its own games (D1): its player is an ordinary `ControllerClient` over a local channel, so it pairs, sends input, takes haptics, reconnects and shows along the same code path as a phone on the Wi-Fi, with no port to open and no firewall to ask about.
- **Local channels.** An in-process channel reports `isLocal` and no `remoteAddress`, and so does the `ControllerInfo` it produces: the TV leaves the address out for that controller, and a saved pairing keeps the last network address instead of the empty one.

### Sessions and frames (M12 step 3)
- **The loop.** `GameSession` (`packages/game_kit`) owns time and frames for one game. A screen builds `PuzzleSession` or `ArenaSession` with the host, the game's module, the setup and the `HostingSettings`; on construction the session calls `host.startView`. The view's `Ticker` calls `advance(elapsed)`, which runs as many 1/60 s steps as the time allows (at most 0.1 s), and its post-frame callback calls `drawn()`, which reports `received_to_drawn` for the inputs the drawn frame first carried.
- **The games.** `step`, `snapshot` and the effects (haptics, records, layouts, status) live in the session; `PuzzlePlayView` and `ArenaView` only drive it and draw `session.current`, so a phone can draw the same game without the loop.
- **Frames.** After a step that is due at `frameRateHz`, and only while `GameHost.hasViewers`, the session calls `host.publishFrame` with the step number, `at` (the host's clock less the time still to simulate), the snapshot JSON, the sounds played since the last sent frame, each player's last applied input `seq` and the roster. `ServerGameHost` encodes it once for every viewer and keeps the start and newest frame for a viewer that pairs mid-game.
- **Sound and haptics.** The host plays sounds as it always has, and the frame names them too: a phone showing the game plays them from its own copy when it draws them (S5, C27). Haptics stay per-player messages.

### The frame path: step → frame → playout → `FrameView`
1. A 1/60 s step runs in the session; the session takes the snapshot the rules now have.
2. When a frame is due, the host publishes it. The server sends the one encoded `frame` to each controller that listed `view`.
3. The client takes its arrival on the phone's own clock (`ControllerClient.nowMs`) and puts `ViewFrame` on `ControllerClient.view`.
4. `FrameView` (game_kit) measures the frame's skew above the fastest arrival in the last 2 s, decodes the snapshot through the module's `GameViewer` and adds it to the `PlayoutBuffer`.
5. Each Ticker frame it asks `ViewerTiming.renderAtMs(now)` = the phone's clock − the base − the playout delay. The delay is the 95th percentile of the recent frames' lateness, clamped to `maxPlayoutFrames` frame intervals, so it covers what the network holds up without adding much. The buffer picks the frames either side of that host time and the view draws the older one lerped toward the newer (`GameSnapshot.lerpTo`: positions lerp, angles take the shortest arc, everything else from the older frame), and holds at the newest rather than drawing ahead of it.
6. The draw reports `touch_to_frame` (from the frame's `acks` and the phone's own clock) and the arrival `frame_jitter` to `ViewerStats`. They go to the host in the phone's metrics batches, and the session summary keeps them per frame rate. Diagnostics shows them in its "Game view" section.

A game this app version can't draw — no module for it, or a newer snapshot version in its start — is shown as "Update the app to see this game", and a frame that doesn't decode is dropped while the frame before it keeps drawing.

### Host interruptions (M12 step 5)
- **While the host is hidden.** The phone host drives `HostPresence` from an `AppLifecycleListener`. When the app is hidden or the screen locks, the round pauses like an open pause menu (no menu is shown) and the game host sends `host_away` with 30 s.
- **When it comes back.** `HostService.resume()` restarts the server on its port if the system stopped listening, and the advertising, while the round is still paused; then the round goes on and `host_back` tells the phones that show it. Resuming doesn't catch up the missed time.
- **When it stays away.** Over 30 s the round is abandoned: `GameSession.abandon` ends the view with `abandoned` without another step, the round is recorded with reason `abandoned`, and the host returns to the game picker.
- **On the joined phone.** "Waiting for the host" counts down from `host_away`'s seconds, or from 30 s when its link to a host showing a game drops (a suspended host says nothing, and the heartbeat catches it). `host_back`, a new `view_start` or a `view_end` ends the wait; an `abandoned` end shows "The host was away too long, so the round ended." for 4 s. A phone that dropped reconnects with its token and gets the start and the newest frame.

### The puzzle and the Arena on phones (M12 step 7)
- **The layout target.** `LayoutTarget` is `screen` (the picture a TV draws) or `phones` (the tray along the top). The host picks it when the round is made — `phones` when it shares its view, `screen` otherwise — and sends it in the puzzle's setup as `layout`. The rules and every viewer build the same world from the puzzle, the seed and the target, so they agree on where every piece is.
- **A `phones` side.** The tray is one row of pieces at 75% with the most compact start angles, the clock, both sides' counts and the time bar sit to its right, and the cropped board is below; the world is sized to that content, because a phone's height is what limits the scale. A solo match is the one board with the tray on top.
- **Cameras (`PuzzleCamera`).** A phone draws its own side: that side's world fitted to the box, with the spare height on top away from the thumbs, and the strip says "You 2/4" and "Right 3/6". It draws the whole match when its player plays no side, on a tablet (`ViewContext.wholeMatch`), or on a screen layout. The host phone draws with the same rule through `ownPlayerIdProvider`, so a host and a joined phone see the same picture.
- **The Arena** shows the whole field on every phone, under the same layer of controls.
- **The size check.** `minPieceMm` (8.5) is the smallest a piece's circumscribed diameter may draw on a phone; a test in `controller_app` checks every puzzle at the smallest phone screen and prints the table.

### Battery and heat (M12 step 8)
- **The host's own readings.** `party_host` asks `hostDeviceMonitorProvider` for battery, charging, Low Power Mode and thermal state; the phone app supplies an adapter over its `DeviceStatusSource`, and the TV supplies none, so it records nothing.
- **The summary.** The session summary gains where each player watched (`host_screen`, `host_phone` or `joined_phone`), the frame rate of each round (`hz`), each round's battery start and end and thermal state, and the host device's own tally: battery at the start and end, whether it charged, whether the system asked for less work, and the seconds spent in each thermal state. A player's delay samples are kept by the frame rate they arrived under (`stagesByHz`) as well as together.
- **The frame rate.** `HostingSettings.frameRateHz` is 20 to 60, 60 by default, and a round keeps the rate it started at; the dev TV app can take one from a debug start option. The summary schema stays 1: every new field is optional.
