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
| `packages/sim_controller/` (M1) | Command-line simulated controller | Windows/macOS/Linux |
| `packages/test_game/` (M4) | Sprite test game, kept separate so it can grow | Flutter |
| `assets/` | `game_assets` package: images, audio, `CREDITS.md`, asset manifest | Flutter |
| `docs/` | PRD, decisions, setup guides, per-milestone checklists | |

## Principles
- **Protocol is platform-independent.** Nothing in `packages/protocol` knows about Android TV, Windows or Flutter, so Apple TV or smart-TV hosts can be added later.
- **Hardware behind interfaces.** Haptics, sensors, discovery and transport each sit behind a Dart interface with a fake implementation, so logic is testable on Windows.
- **Minimal native iOS code.** One small haptics platform channel (M2) plus Info.plist configuration. Everything else uses well-established Flutter packages.
- **No paid-account capabilities.** No push notifications, App Groups, extensions, iCloud or associated domains.
- **No stuck inputs.** On disconnect or app backgrounding the controller sends "release all", and the TV also releases all inputs for a controller whose connection drops.

## Message flow (planned for M1+)
1. Phone discovers `_gamectl._tcp` via mDNS (or the user types the IP).
2. Phone opens a WebSocket and sends `hello` (controllerId, name, platform, appVersion).
3. TV replies with a pairing challenge. The phone sends the code shown on the TV, and the TV accepts or rejects.
4. Both sides exchange heartbeats. The TV measures round-trip time.
5. Input messages flow phone → TV. Haptic events flow TV → phone.
