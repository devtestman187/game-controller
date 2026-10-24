# Controller app

Phone game controller for **Android 16+** and **iOS 26+**, landscape only. App ID: `com.gamecontrollerdev.controller` (fixed, don't rename).

Current state (Milestone 0): hello-world screen showing the platform and protocol version.

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

## iPhone
You can't build it locally on Windows. Codemagic builds an unsigned `.ipa` on every tag (or manual start) and you install it with iLoader using a free Apple ID: [../docs/ios-setup.md](../docs/ios-setup.md). Re-install every 7 days.

## Native iOS code rule
Native Swift is limited to one small haptics platform channel (Milestone 2) plus Info.plist configuration. Every iOS change costs a cloud build and a re-install, so it's kept minimal and reviewed carefully.
