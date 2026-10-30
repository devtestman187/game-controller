# Controller app

**Thumb Party**: the phone and tablet game controller, for **Android 12+** and **iOS/iPadOS 26+**, landscape only. App ID: `com.thumbparty.app` (Play never allows changing it). Version 0.8.0 (Milestone 8).

The phone works as a gamepad for the TV test app over the home Wi-Fi. It has three layouts, switched at the top without reconnecting, and the app starts in the one you used last.

| Mode | What you get |
| --- | --- |
| **D-pad** | An 8-way D-pad on the left, Select/Start in the middle and A/B/X/Y on the right, with full multi-touch: hold a direction and press buttons, or slide a thumb between buttons. |
| **Gyro** | Steer by tilting the phone. The D-pad becomes a circle with a dot, the buttons stay, and the screen locks to the way you hold it. The first reading is the center; **Calibrate** sets a new one. The tune icon has sensitivity, dead zone and smoothing. About 60 updates a second. Phones without a usable gyroscope stay on the D-pad with a message. |
| **Sticks** | An Xbox-style layout: two analog sticks, the D-pad, A/B/X/Y, LB/RB, Select and Start. Both thumbs and a finger on a shoulder button work at once. The tune icon has **Floating sticks** (a stick starts where your thumb lands), dead zone and sensitivity. Sticks stay inside the unit circle and return to center the moment you let go. |

## Haptics
- **Ticks**: every press, release and direction change plays a short tick (sticks don't tick).
- **TV events**: in every mode the phone plays what the TV sends: **hit** (one deep thud), **success** (three rising taps and a ring), **error** (two long, harsh buzzes) and **rumble** (a deep throb for as long as the TV asks).
- The haptics switch silences both. Events arriving while the app is in the background are skipped.

## Settings (gear icon)
Everything is saved on the phone and kept between launches:
- **Haptics**: the switch, the **button tick** strength, and a strength for **each TV event** on its own (0% turns that event off), each with a **Try** button. The tick and the events don't affect each other.
- **Gyro**: sensitivity, dead zone, smoothing. (Calibrate from gyro mode.)
- **Sticks**: floating or fixed, dead zone, sensitivity.
- **Defaults** puts everything back.

The quick tune icon in gyro and stick mode opens the same gyro or stick settings next to the controls.

## Connecting
- On launch the app reconnects to the last TV, or opens the Connect screen: TVs found on the Wi-Fi (mDNS), a typed `IP` or `IP:port` as a fallback, and the 4-digit code from the TV (sent as soon as you type the fourth digit).
- After pairing, the phone saves a token, so reconnects and relaunches need no code. The TV saves its side too, so a TV app restart doesn't need the code either.
- **Reconnects** happen on their own after Wi-Fi drops, the TV app restarting or the phone sleeping. Coming back to the app reconnects at once instead of waiting for the heartbeat to time out. While it's been reconnecting for a while, it also searches the network again, in case the TV's address or port changed.
- **Disconnect** (on the Connect screen) forgets the last TV, so the next launch doesn't reconnect on its own.

The top bar shows your player number (**P1**, **P2**…, in your sprite's colour), the TV and ping (tap to connect or switch TVs), and the lowest, average and highest ping over the last 30 s.

## Diagnostics (heart-monitor icon)
Connection (status, TV, addresses, player, ping and its 30 s range), local network permission, TVs found, haptics (support, engine, settings, ticks and TV events played, errors), input, gyro, **reconnects** (each drop, why, and how long it took to come back), the **session** readout (CPU use of this app in % of one core, battery level and drain per hour, heat, input states sent per second) and the log. **Share** and **Copy** send all of it as text.

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
| iOS | Motion sensors for gyro mode (`NSMotionUsageDescription`, required by sensors_plus; reading the gyroscope shows no prompt) | `ios/Runner/Info.plist` |
| iOS | Local network prompt (`NSLocalNetworkUsageDescription`) and the Bonjour service `_gamectl._tcp` (`NSBonjourServices`) | `ios/Runner/Info.plist` |
| Android | `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `VIBRATE`, all granted at install (no runtime prompt on Android 12 and later) | `android/app/src/main/AndroidManifest.xml` |

On iOS the prompt appears the first time the app searches for TVs. If you tap **Don't Allow**, turn it on later in Settings → Privacy & Security → Local Network → Controller. iOS doesn't let apps read this setting, so Diagnostics infers it: **Allowed** once a TV is found, **Probably denied** if connecting fails with "No route to host".

## iPhone
You can't build it locally on Windows. Codemagic builds an unsigned `.ipa` on every tag (or manual start) and you install it with iLoader using a free Apple ID: [../docs/ios-setup.md](../docs/ios-setup.md). Re-install every 7 days.

## Native code rule
Native code is one small platform channel (`com.thumbparty.app/haptics`) plus Info.plist configuration. Every iOS change costs a cloud build and a re-install, so it's kept minimal and reviewed carefully.

| Platform | File | Methods |
| --- | --- | --- |
| iOS | `ios/Runner/AppDelegate.swift` (`HapticsChannel`, in that file so the Xcode project never needs editing without a Mac) | `capabilities`, `tick`, `play` (Core Haptics), `deviceStatus` (battery, heat, CPU time) |
| Android | `android/app/src/main/kotlin/.../Haptics.kt`, `MainActivity.kt` | the same, with VibrationEffect |

The haptic patterns themselves are built in Dart (`lib/src/haptic_patterns.dart`), so tuning them needs no native change. Discovery uses the `bonsoir` plugin.
