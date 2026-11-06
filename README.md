# Thumb Party

A phone game controller (Android + iOS) and a TV test app it drives (Android TV + Windows desktop), in one Flutter monorepo. Requirements and milestones: [docs/PRD.md](docs/PRD.md).

| Folder | What |
| --- | --- |
| [controller_app/](controller_app/README.md) | Phone controller app |
| [tv_test_app/](tv_test_app/README.md) | TV test app (Android TV + Windows desktop) |
| [packages/protocol/](packages/protocol) | Shared, versioned message definitions |
| [packages/connection/](packages/connection) | Host server and phone client (pairing, heartbeats, reconnect), plus the command-line simulated controller |
| [packages/metrics/](packages/metrics) | Analytics: the phone's touch counters, session summaries and the report tool |
| [packages/test_game/](packages/test_game) | The Arena game (top-down arena, one sprite per controller) |
| [packages/puzzle_game/](packages/puzzle_game) | Shape Race, the puzzle game: data, rules, snapshots and view |
| [tools/](docs/dev-tools.md) | `check.sh` (every check), `release.sh` (tag and release), `tv-dev.sh` and `tv-window.ps1` (the Windows TV app for checks), `emulator.sh` (the phone app on the Android emulator), release notes, signing and artwork scripts |
| [assets/](assets/CREDITS.md) | Images, audio and their credits |
| [docs/](docs) | PRD, [architecture](docs/architecture.md), [decisions](docs/decisions.md), [building](docs/building.md), [developer tools](docs/dev-tools.md), [project notes](docs/project-notes.md), [release](docs/release.md), [protocol](docs/protocol.md), [checklists](docs/checklists) |

## Quick start (Windows, PowerShell)
```powershell
flutter pub get                               # whole workspace
& "C:\Program Files\Git\bin\bash.exe" tools/check.sh   # every check, one line each (in Git Bash: tools/check.sh)
cd tv_test_app; flutter run -d windows        # TV app on the laptop
```
Then, in a second terminal, pair a simulated controller with it (use the code the app shows):
```powershell
cd packages\connection; dart run connection:sim_controller --code 1234
```
Toolchain setup, Android/TV install steps and the Windows Firewall notes are in [docs/building.md](docs/building.md). The check and release scripts, and what to move to another computer, are in [docs/dev-tools.md](docs/dev-tools.md). Store builds (TestFlight, Google Play testing, the Windows zip) are described in [docs/release.md](docs/release.md); testers follow https://devtestman187.github.io/game-controller/. Older iOS sideloading notes, retired in M8, were: [docs/ios-setup.md](docs/ios-setup.md).

## Status
| Milestone | State |
| --- | --- |
| M0 Foundation and build pipelines | Done (Android phone install test pending) |
| M1 Discovery, pairing, connection, Windows desktop TV app | Done (Android phone tests pending) |
| M2 D-pad mode and input haptics | Done (Android phone tests pending) |
| M3 Gyro mode | Done (Android phone tests pending) |
| M4 Analog stick mode (Xbox-style layout) | Done (Android phone tests pending) |
| M5 TV-to-phone haptics and test game | Done (`m5`, Android phone tests pending) |
| M6 Polish, settings, latency tooling, several controllers | Done (`m6`, Android phone tests pending) |
| **v2** M7 Bigger stick buttons, tablets, Android 12, v1 Android phone tests | Done on iOS (`m7`, Android phone and tablet tests pending) |
| M8 Store testing pipeline (TestFlight, Google Play testing, Windows zip) | Done (`m8`, `m8.1`; Android checks pending, public TestFlight link to come) |
| M9 Analytics and platform groundwork | Done (`m9`, `m9.1`, `m9.2`; Android phone and tablet tests pending) |
| M10 Puzzle game (Shape Race) for 1 player, game-defined controls | Done (`m10` to `m10.3`; Android phone and tablet tests pending) |
| M11 Shape Race for 2 to 4 players, the whole TV app from a controller | Built (`m11` to `m11.3`); device tests carried as tech debt |
| M12 Phone-hosted play | In progress (design: docs/design/m12.md) |

All v1 milestones (docs/PRD.md) are done. v2 (docs/PRD-v2.md) runs from M7 to M13; M7 closes the pending v1 Android phone tests.
