# Game Controller

A phone game controller (Android + iOS) and a TV test app it drives (Android TV + Windows desktop), in one Flutter monorepo. Requirements and milestones: [docs/PRD.md](docs/PRD.md).

| Folder | What |
| --- | --- |
| [controller_app/](controller_app/README.md) | Phone controller app |
| [tv_test_app/](tv_test_app/README.md) | TV test app (Android TV + Windows desktop) |
| [packages/protocol/](packages/protocol) | Shared, versioned message definitions |
| [packages/connection/](packages/connection) | Host server and phone client (pairing, heartbeats, reconnect), plus the command-line simulated controller |
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
| M0 Foundation and build pipelines | Done (Android phone install test deferred) |
| M1 Discovery, pairing, connection, Windows desktop TV app | In verification: [checklist](docs/checklists/m1.md) |
| M2 D-pad mode and input haptics | Not started |
| M3 Gyro mode | Not started |
| M4 TV-to-phone haptics and test game | Not started |
| M5 Polish, settings, latency tooling | Not started |
