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
| `packages/test_game/` (M4) | Sprite test game, kept separate so it can grow | Flutter |
| `assets/` | `game_assets` package: images, audio, `CREDITS.md`, asset manifest | Flutter |
| `docs/` | PRD, decisions, setup guides, per-milestone checklists | |

## Principles
- **Protocol is platform-independent.** Nothing in `packages/protocol` knows about Android TV, Windows or Flutter, so Apple TV or smart-TV hosts can be added later.
- **Hardware behind interfaces.** Haptics, sensors, discovery and transport each sit behind a Dart interface with a fake implementation, so logic is testable on Windows.
- **Minimal native iOS code.** One small haptics platform channel (M2) plus Info.plist configuration. Everything else uses well-established Flutter packages.
- **No paid-account capabilities.** No push notifications, App Groups, extensions, iCloud or associated domains.
- **No stuck inputs.** On disconnect or app backgrounding the controller sends "release all", and the TV also releases all inputs for a controller whose connection drops.

## Message flow (Milestone 1)
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
- Input messages (phone → TV, M2) and haptic events (TV → phone, M4) will use the same connection.
