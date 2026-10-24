# Controller app

Phone game controller for **Android 16+** and **iOS 26+**, landscape only. App ID: `com.gamecontrollerdev.controller` (fixed, don't rename).

Current state (Milestone 2): a landscape **D-pad controller**: 8-way D-pad on the left, Select/Start in the middle, A/B/X/Y on the right, with full multi-touch (hold a direction and press buttons, slide a thumb between buttons). Every press, release and direction change goes to the TV and plays a haptic tick. The vibration icon opens haptics on/off and intensity (saved). Gyro mode is shown but arrives in M3.

The chip at the top left shows the TV and ping (tap it to connect or switch TVs), next to the lowest, average and highest ping over the last 30 s. On launch the app reconnects to the last TV, or opens the Connect screen: TVs found on the Wi-Fi (mDNS), a typed address as a fallback, and the 4-digit code from the TV. **Diagnostics** (heart-monitor icon) shows the connection, TVs found, local network permission, haptics support, current input and the log, with **Share** and **Copy**.

How it connects:
- Tap a TV in the list (or type `IP` or `IP:port` from the TV screen) and enter the 4-digit code. It sends the code as soon as you type the fourth digit.
- After pairing, the phone saves a token, so reconnects and relaunches need no code while the TV app keeps running. The app reconnects to the last TV on launch.
- **Disconnect** forgets the last TV, so the next launch doesn't reconnect on its own.

## Windows setup
Toolchain: see [../docs/building.md](../docs/building.md). Then, from the repo root:
```powershell
flutter pub get
```

## Run and test
```powershell
cd controller_app
flutter test
flutter run                                    # on a USB-connected Android phone
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## Permissions
| Platform | What | Where |
| --- | --- | --- |
| iOS | Local network prompt (`NSLocalNetworkUsageDescription`) and the Bonjour service `_gamectl._tcp` (`NSBonjourServices`) | `ios/Runner/Info.plist` |
| Android | `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `VIBRATE`, all granted at install (no runtime prompt on Android 16) | `android/app/src/main/AndroidManifest.xml` |

On iOS the prompt appears the first time the app searches for TVs. If you tap **Don't Allow**, turn it on later in Settings → Privacy & Security → Local Network → Controller. iOS doesn't let apps read this setting, so Diagnostics infers it: **Allowed** once a TV is found, **Probably denied** if connecting fails with "No route to host".

## iPhone
You can't build it locally on Windows. Codemagic builds an unsigned `.ipa` on every tag (or manual start) and you install it with iLoader using a free Apple ID: [../docs/ios-setup.md](../docs/ios-setup.md). Re-install every 7 days.

## Native iOS code rule
Native Swift is limited to one small haptics platform channel plus Info.plist configuration. Every iOS change costs a cloud build and a re-install, so it's kept minimal and reviewed carefully. The channel (`HapticsChannel`, Core Haptics) lives in `ios/Runner/AppDelegate.swift` so the Xcode project file never needs editing without a Mac. Android's side is `android/app/src/main/kotlin/.../Haptics.kt` (VibrationEffect). Discovery uses the `bonsoir` plugin.
