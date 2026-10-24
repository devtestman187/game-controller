# TV test app

Test bench and connection host for the controller. One codebase runs on **Android TV 12+ (API 31)** and as a **Windows desktop app**. App ID: `com.gamecontrollerdev.tvtest`.

Current state (Milestone 0): hello-world screen with three remote-navigable buttons, a visible focus ring and a "last key" readout to verify the remote.

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

Remote controls: arrows move focus, center/OK selects, Back goes back/exits.

## Run as a Windows desktop app
```powershell
cd tv_test_app
flutter run -d windows                         # development
flutter build windows --release
.\build\windows\x64\runner\Release\tvtest.exe  # release build
```
The window is resizable. Arrow keys + Enter act like the TV remote.

### Windows Firewall (from Milestone 1, when the app hosts the server)
The phones connect to the laptop, so Windows must allow incoming connections to the app on your **private** network:
1. Make the Wi-Fi network Private: Settings → Network & internet → Wi-Fi → *your network* → **Network profile type: Private**.
2. Start the app. When Windows Defender Firewall asks, tick **Private networks**, untick Public, and click **Allow**.
3. If you missed or cancelled the prompt: Start → "Allow an app through Windows Firewall" → **Change settings** → find `tvtest.exe` (or click **Allow another app…** and browse to `tv_test_app\build\windows\x64\runner\Release\tvtest.exe`; for `flutter run` builds also allow `...\runner\Debug\tvtest.exe`) → tick **Private** → OK.
4. The phones and the laptop must be on the **same Wi-Fi**. Guest networks and routers with "client/AP isolation" block both discovery and connections. Use manual IP entry if discovery is blocked but connections work.
