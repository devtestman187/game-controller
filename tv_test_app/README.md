# TV test app

Test bench and connection host for the controller. One codebase runs on **Android TV 12+ (API 31)** and as a **Windows desktop app**. App ID: `com.gamecontrollerdev.tvtest`.

Current state (Milestone 4): hosts the controller server, advertises itself on the network (mDNS), shows the pairing code, the address for manual entry, and each controller's state, live ping and **input** (a small picture of its D-pad and buttons, lit while held; in gyro mode a stick with a dot and "Tilt x … y …"; in stick mode the Xbox-style layout with both sticks, LB/RB and "L x, y   R x, y"), plus a log. It has a built-in simulated controller.

## The screen
| Area | What it shows |
| --- | --- |
| Pairing code | The 4-digit code to enter on the phone. After 5 wrong codes in a row it changes on its own. |
| Address for manual entry | `IP:port` to type on the phone if discovery doesn't find the TV |
| Discovery line | Green when phones can find the TV via mDNS. If it fails, manual entry still works. |
| Controllers | Each phone with its state (**Connected**, **Waiting for code**, **Disconnected**), its input (D-pad, Select/Start, A/B/X/Y lit while held), the round-trip ping and the average and highest ping over the last 30 s |
| Log | Recent connection events, newest at the bottom |

Buttons (arrows to move, center/OK to press):
- **New code**: shows a different code. Phones that are already paired stay paired.
- **Simulate controller**: starts a controller inside the app that pairs on its own, exchanges heartbeats (PRD T3) and presses every button and direction in a loop. Press again to stop.
- **Drop connections**: closes every connection as if Wi-Fi dropped, so you can watch the phones reconnect by themselves.

Pairings are kept in memory: after the TV app restarts, phones need the code again.

## Windows setup
Toolchain: see [../docs/building.md](../docs/building.md) (needs Visual Studio 2022 with **Desktop development with C++** for the Windows build). Then, from the repo root:
```powershell
flutter pub get
cd tv_test_app
flutter test
```

## Install on the physical Android TV
1. TV: Settings → System → About → click **Android TV OS build** 7 times. Then Settings → System → Developer options → turn on **USB debugging** (or **Network/ADB debugging**).
2. TV IP: Settings → Network & Internet → your network.
3. PC, same network:
```powershell
adb connect <TV-IP>:5555                       # accept the "Allow debugging" prompt on the TV
cd tv_test_app
flutter build apk --release
adb -s <TV-IP>:5555 install -r build\app\outputs\flutter-apk\app-release.apk
```
4. Open **Controller Test** from the launcher (banner tile; on Google TV look under Apps → Your apps).

Remote controls: arrows move focus, center/OK selects, Back exits.

## Run as a Windows desktop app
```powershell
cd tv_test_app
flutter run -d windows                         # development
flutter build windows --release
.\build\windows\x64\runner\Release\tvtest.exe  # release build
```
The window is resizable. Arrow keys + Enter act like the TV remote.

### Windows Firewall
The phones connect to the laptop, so Windows must allow incoming connections to the app on your **private** network:
1. Make the Wi-Fi network Private: Settings → Network & internet → Wi-Fi → *your network* → **Network profile type: Private**.
2. Start the app. When Windows Defender Firewall asks, tick **Private networks**, untick Public, and click **Allow**.
3. If you missed or cancelled the prompt: Start → "Allow an app through Windows Firewall" → **Change settings** → find `tvtest.exe` (or click **Allow another app…** and browse to `tv_test_app\build\windows\x64\runner\Release\tvtest.exe`; for `flutter run` builds also allow `...\runner\Debug\tvtest.exe`) → tick **Private** → OK.
   Or, in an **administrator** PowerShell, allow the port for every build:
   ```powershell
   New-NetFirewallRule -DisplayName "Controller Test (TCP 45780)" -Direction Inbound -Protocol TCP -LocalPort 45780 -Action Allow -Profile Private
   ```
4. Check from the phone: open `http://<laptop address>:45780` in the phone's browser. A one-line page means connections get through.
5. The phones and the laptop must be on the **same Wi-Fi**. Guest networks and routers with "client/AP isolation" block both discovery and connections. Use manual IP entry if discovery is blocked but connections work.

If the laptop has several network adapters (WSL, Hyper-V, VPN), the screen lists Wi-Fi first. Use that address for manual entry.
