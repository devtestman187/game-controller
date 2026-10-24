# Controller app

Phone game controller for **Android 16+** and **iOS 26+**, landscape only. App ID: `com.gamecontrollerdev.controller` (fixed, don't rename).

Current state (Milestone 1): finds TVs on the Wi-Fi (mDNS), connects by typed address as a fallback, pairs with the code shown on the TV, shows the connection status and ping, and reconnects on its own after a drop. A **Diagnostics** screen (heart-monitor icon) shows the connection, the TVs found, the local network permission status and the log, with **Share** and **Copy**. Controls arrive in Milestone 2.

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
| Android | `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, all granted at install (no runtime prompt on Android 16) | `android/app/src/main/AndroidManifest.xml` |

On iOS the prompt appears the first time the app searches for TVs. If you tap **Don't Allow**, turn it on later in Settings → Privacy & Security → Local Network → Controller. iOS doesn't let apps read this setting, so Diagnostics infers it: **Allowed** once a TV is found, **Probably denied** if connecting fails with "No route to host".

## iPhone
You can't build it locally on Windows. Codemagic builds an unsigned `.ipa` on every tag (or manual start) and you install it with iLoader using a free Apple ID: [../docs/ios-setup.md](../docs/ios-setup.md). Re-install every 7 days.

## Native iOS code rule
Native Swift is limited to one small haptics platform channel (Milestone 2) plus Info.plist configuration. Every iOS change costs a cloud build and a re-install, so it's kept minimal and reviewed carefully. Milestone 1 adds no Swift: discovery uses the `bonsoir` plugin.
