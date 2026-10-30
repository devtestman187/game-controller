# Building and installing (Windows, PowerShell)

All commands are PowerShell, run from the repo root unless noted. iOS is built in the cloud. See [ios-setup.md](ios-setup.md).

## One-time toolchain
Installed on this PC during Milestone 0 (versions as of Oct 2026):
| Tool | How | Notes |
| --- | --- | --- |
| Git | `winget install Git.Git` | |
| GitHub CLI | `winget install GitHub.cli` | `gh auth login` once |
| Flutter 3.47.8 stable | `git clone -b stable https://github.com/flutter/flutter.git C:\src\flutter`, add `C:\src\flutter\bin` to the user PATH | |
| Android Studio (provides the JDK) | `winget install Google.AndroidStudio` | `JAVA_HOME = C:\Program Files\Android\Android Studio\jbr` |
| Android SDK | command-line tools in `%LOCALAPPDATA%\Android\Sdk`, then `sdkmanager platform-tools "platforms;android-36" "build-tools;36.0.0"` | `ANDROID_HOME` set. Licenses accepted. |
| Visual Studio 2022 Community + **Desktop development with C++** | `winget install Microsoft.VisualStudio.2022.Community --override "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"` | Needed for the Windows desktop TV app |
| Windows **Developer Mode** | `start ms-settings:developers` → Developer Mode On | Needed once Flutter plugins are added (symlinks) |
| Android NDK (28.2) | `sdkmanager "ndk;28.2.13676358"` | Needed since M5: `flutter_soloud` compiles its audio engine during the TV app's Android build. The Windows build uses Visual Studio's C++ tools |

Check with `flutter doctor -v`. Everything should be green except optional items.

After a fresh clone:
```powershell
flutter pub get          # resolves the whole workspace
```

## Tests and analysis
```powershell
flutter analyze controller_app tv_test_app packages assets
cd packages\protocol; dart test; cd ..\..
cd packages\connection; dart test; cd ..\..    # real sockets on localhost: pairing, heartbeats, reconnect
cd packages\test_game; flutter test; cd ..\..    # game rules and the game screen
cd controller_app; flutter test; cd ..
cd tv_test_app; flutter test; cd ..
```

Sounds need real audio hardware, so they have their own on-device test (it plays each sound for half a second):
```powershell
cd tv_test_app
flutter test integration_test -d windows                 # Windows build
flutter test integration_test -d 192.168.1.50:5555       # the TV (use its IP), after adb connect
```
The first build of the TV app downloads flutter_soloud's prebuilt codec libraries from GitHub (release pinned in the root `pubspec.yaml`) and caches them.

## Controller app on an Android phone or tablet
1. On the phone: Settings → About phone → tap **Build number** 7 times → back → System → Developer options → **USB debugging** On.
2. Connect by USB and accept the "Allow USB debugging" prompt.
```powershell
adb devices                                   # phone should be listed as "device"
cd controller_app
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
# or, for development with hot reload:
flutter run
```

## TV app on the physical Android TV
1. On the TV: Settings → System → About → click **Android TV OS build** 7 times (enables developer options). Then Settings → System → **Developer options** → **USB debugging** On (some TVs call it **Network debugging** / **ADB debugging**).
2. Find the TV's IP: Settings → Network & Internet → your Wi-Fi network.
3. From the PC (same network):
```powershell
adb connect 192.168.1.50:5555                 # use your TV's IP; accept the prompt on the TV
adb devices                                   # TV listed as 192.168.1.50:5555  device
cd tv_test_app
flutter build apk --release
adb -s 192.168.1.50:5555 install -r build\app\outputs\flutter-apk\app-release.apk
```
4. The app appears in the TV launcher as **Controller Test** with its banner. On Google TV it may be under **Apps** → **Your apps**. Launch it with the remote.
5. Optional: `adb -s 192.168.1.50:5555 shell monkey -p com.gamecontrollerdev.tvtest 1` launches it from the PC.

## TV app as a Windows desktop app
```powershell
cd tv_test_app
flutter run -d windows                        # development
flutter build windows --release               # release build
.\build\windows\x64\runner\Release\tvtest.exe
```
The window is resizable. The layout scales between a small laptop window and a 16:9 TV screen.

**Windows Firewall:** the first time the app listens on the network, Windows asks whether to allow it. Tick **Private networks** and click **Allow**. Phones and the laptop must be on the **same Wi-Fi**, and that network must be set to *Private* (Settings → Network & internet → Wi-Fi → your network → Network profile type → **Private**). Full steps, including how to fix it if you clicked Cancel, are in [tv_test_app/README.md](../tv_test_app/README.md#windows-firewall).

## Simulated controller (no phone needed)
A command-line controller that pairs with the TV app and keeps the connection alive (PRD T3). It works against the Windows app or the physical TV:
```powershell
cd packages\connection
dart run connection:sim_controller --code 1234                         # TV app on this PC
dart run connection:sim_controller --host 192.168.1.50 --code 1234     # TV app on the TV
dart run connection:sim_controller --help                              # all options
```
It prints each state change and the ping (with the last 30 s summary) every 5 seconds. Without `--code` it asks for one. Add `--demo` to press every button and D-pad direction in a loop, to check the TV's input display. Haptic events the TV sends are printed as they arrive (for example `haptic hit intensity 0.7 100 ms`), so the game and the haptic test can be checked without a phone. The TV app's **Simulate controller** button does the same from inside the app.

For a long-session test (M6), `--stream` sends a gyro-like tilt 60 times a second, as gyro mode does, and `--seconds` stops it. At the end it prints a summary: how long it ran, the input states sent, the drops and the ping over the session. The TV logs the input delay every 30 s; save the log afterwards (see the TV app README).
```powershell
dart run connection:sim_controller --host 192.168.1.100 --code 1234 --stream --seconds 1800   # 30 minutes
```

## Network ports
| What | Port |
| --- | --- |
| Controller connection (WebSocket at `/ws`) | TCP **45780** (if it's taken, the app picks a free port and shows it on screen) |
| Discovery (mDNS, service `_gamectl._tcp`) | UDP 5353 (handled by the OS) |

Opening `http://<TV address>:45780` in the phone's browser shows a one-line page when the connection can get through (a quick firewall check).

## iOS
Built by Codemagic on tags and manual starts. See [ios-setup.md](ios-setup.md). Fallback: GitHub → Actions → **iOS fallback (unsigned)** → Run workflow.

## Optional: Android TV emulator
Android Studio → Device Manager → Create device → **TV** category (e.g. "Television (1080p)") → API 31+ image. It sits behind NAT, so the phone can't discover it. For a quick check, run `adb forward tcp:45780 tcp:45780` and then connect the simulated controller to `127.0.0.1` on the PC. Use it for UI checks only.

## Android 12 emulator check (before each milestone tag, PRD v2 C30)
The controller supports Android 12 (API 31) and later, but the test phones run newer versions, so an emulator checks the oldest one. It caught a crash in M7 that the release build's lint didn't: an Android 13 vibration call made the app close at start.

One-time setup (about 1.5 GB):
```powershell
sdkmanager --install "emulator" "system-images;android-31;default;x86_64"
avdmanager create avd -n m7_android12 -k "system-images;android-31;default;x86_64" -d pixel_6
```
Each check:
1. Start the emulator: `emulator -avd m7_android12 -no-snapshot` and wait until it has booted.
2. Install and open the controller: `adb -s emulator-5554 install -r controller_app\build\app\outputs\flutter-apk\app-release.apk`.
3. Run the Windows TV app on the same PC. The emulator sits behind NAT and can't discover it, so on the controller type the address `10.0.2.2:45780` and the pairing code.
4. Check it starts in landscape, pairs, lays out every mode, and that a held button shows on the TV app. Then read `adb -s emulator-5554 logcat -d -b crash`: it should be empty.

The emulator has no vibration motor or gyroscope, so haptics and gyro mode stay untested on Android 12.
