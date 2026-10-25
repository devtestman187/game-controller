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
| `packages/test_game/` (M5) | Sprite test game, kept separate so it can grow | Flutter |
| `assets/` | `game_assets` package: images, audio, `CREDITS.md`, asset manifest | Flutter |
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
- Haptic events (TV → phone, M5) will use the same connection.

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
