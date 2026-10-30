# Game Controller

A phone game controller (Android + iOS) and a TV test app it drives (Android TV + Windows desktop), in one Flutter monorepo. Requirements and milestones: [docs/PRD.md](docs/PRD.md).

| Folder | What |
| --- | --- |
| [controller_app/](controller_app/README.md) | Phone controller app |
| [tv_test_app/](tv_test_app/README.md) | TV test app (Android TV + Windows desktop) |
| [packages/protocol/](packages/protocol) | Shared, versioned message definitions |
| [packages/connection/](packages/connection) | Host server and phone client (pairing, heartbeats, reconnect), plus the command-line simulated controller |
| [packages/test_game/](packages/test_game) | The test game (top-down arena, one sprite per controller), kept separate so it can grow |
| [assets/](assets/CREDITS.md) | Images, audio and their credits |
| [docs/](docs) | PRD, [architecture](docs/architecture.md), [decisions](docs/decisions.md), [building](docs/building.md), [iOS setup](docs/ios-setup.md), [checklists](docs/checklists) |

## Quick start (Windows, PowerShell)
```powershell
flutter pub get                               # whole workspace
cd packages\protocol; dart test; cd ..\..
cd packages\connection; dart test; cd ..\..
cd tv_test_app; flutter run -d windows        # TV app on the laptop
```
Then, in a second terminal, pair a simulated controller with it (use the code the app shows):
```powershell
cd packages\connection; dart run connection:sim_controller --code 1234
```
Toolchain setup, Android/TV install steps and the Windows Firewall notes are in [docs/building.md](docs/building.md). iOS builds come from Codemagic and are sideloaded: [docs/ios-setup.md](docs/ios-setup.md).

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
| **v2** M7 Bigger stick buttons, tablets, Android 12, v1 Android phone tests | Built (0.7.0), awaiting device tests ([checklist](docs/checklists/m7.md)) |

All v1 milestones (docs/PRD.md) are done. v2 (docs/PRD-v2.md) runs from M7 to M13; M7 closes the pending v1 Android phone tests.
