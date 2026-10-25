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

## Repo layout
| Path | What | Platforms |
| --- | --- | --- |
| `controller_app/` | Phone controller | Android (minSdk 36), iOS 26+ |
| `tv_test_app/` | TV test bench + server | Android TV (minSdk 31), Windows desktop |
| `packages/protocol/` | Message definitions + codec, no Flutter dependency | anywhere Dart runs |
| `packages/connection/` | Host server, phone client (pairing, heartbeats, reconnect), log buffer and the command-line simulated controller (`bin/sim_controller.dart`). Pure Dart (`dart:io`) | anywhere `dart:io` runs |
| `packages/test_game/` | The test game (M5): rules in `ArenaGame` (no widgets, unit-tested) and the screen in `ArenaView`. Kept separate so it can grow | Flutter |
| `assets/` | `game_assets` package: images, audio (`audio/`, bundled as a folder), `CREDITS.md`, asset manifest (`lib/asset_manifest.dart`) | Flutter |
| `docs/` | PRD, decisions, setup guides, per-milestone checklists | |

## Principles
- **Protocol is platform-independent.** Nothing in `packages/protocol` knows about Android TV, Windows or Flutter, so Apple TV or smart-TV hosts can be added later.
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
| 6 | both | `ping` every second, answered by `pong` echoing `id` and `sentAt`. Each side measures round-trip time on its own clock. |

Rules:
- **Pairing.** The TV accepts nothing but `pair` (and heartbeats) until a controller pairs. A wrong code gets `pair_result` and close code 4001. After 5 wrong codes in a row the TV shows a new code. Unpaired connections close after 5 minutes (4005).
- **Tokens.** The TV issues a random token per controller on a correct code and keeps it in memory. The phone saves it per hostId, so reconnects and app relaunches skip the code until the TV app restarts (`unknown_token` → enter the code again).
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
`lib/src/haptics.dart` defines the `Haptics` interface (capabilities + tick), with `PlatformHaptics` (the channel `com.gamecontrollerdev.controller/haptics`) and `FakeHaptics` for tests. `HapticsPlayer` applies the on/off switch, intensity and hardware limits, and swallows native errors so input keeps working.

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
| hit | One heavy, round tap with a 120 ms tail that fades out | Stretches the pattern |
| success | Three rising, crisp taps 110 ms apart, the last one ringing briefly (320 ms) | Stretches the pattern |
| error | Two short, harsh buzzes with a gap (220 ms) | Stretches the pattern |
| rumble | A low buzz wobbling between two strengths every 50 ms (400 ms) | How long it lasts |

- **Playing**: the TV's intensity × the phone's intensity setting scales every segment. The haptics switch silences TV events as well as ticks. Events arriving while the app isn't in the foreground are skipped.
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

The TV app runs it in `ui/game_screen.dart`. It's driven by the controller that pressed or moved something last (or else the first one connected), and its events go to that controller. OK, Enter, D, F3, or the remote's Info/Menu key toggles a debug overlay: controller, connection, ping, input mode, stick or tilt values, buttons, the last haptic event sent, and the sound status. Back (or Esc) leaves.
