# Decisions

Architecture and tooling decisions, newest last. The PRD (`docs/PRD.md`) is the source of truth for requirements.

| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-24 | **Flutter/Dart** for both apps (Flutter 3.47.8 stable, Dart 3.13) | The only mainstream stack that covers Android, iOS, Android TV and Windows desktop from one codebase while keeping native iOS code to one small file, which matters with no Mac. |
| 2026-10-24 | **Dart pub workspace** at the repo root (`pubspec.yaml` → `workspace:`) | One `flutter pub get`, one lockfile, and the shared `protocol` package resolved by path. |
| 2026-10-24 | **State management: Riverpod** (`flutter_riverpod`, added in M1 when there is state to manage) | Testable without widgets, no code generation, and haptics, transport and sensors are easy to swap for fakes in tests (`ProviderScope(overrides: ...)`). |
| 2026-10-24 | **Protocol: JSON text frames over WebSocket**, envelope `{"v":1,"t":"type",...}`, sealed Dart classes | Easy to debug and log. JSON at ~60 Hz is small. The version field detects mismatched builds, and unknown types are ignored for forward compatibility. `hello` carries `controllerId`, so multiple controllers work without a redesign. UDP for gyro only if M5 latency measurements require it. |
| 2026-10-24 | **Transport:** `dart:io` HttpServer/WebSocket (TV side), `dart:io` WebSocket (phone side) | Same code on Android TV and Windows, no extra packages, TCP_NODELAY settable on the upgraded socket. |
| 2026-10-24 | **Discovery: `bonsoir`** (mDNS/DNS-SD, service `_gamectl._tcp`) | pub.dev lists Android, iOS, macOS, Windows and Linux. Windows advertising is verified at the start of M1, with manual IP entry as the fallback. |
| 2026-10-24 | **App IDs** `com.gamecontrollerdev.controller` (phone, Android + iOS) and `com.gamecontrollerdev.tvtest` (TV) | Chosen once. Free Apple IDs allow only ~10 new bundle IDs per week, so these never change. Nothing ties them to a paid account, so TestFlight later is unaffected. |
| 2026-10-24 | **Minimum versions:** phone Android 16 (minSdk 36), iOS 26.0, TV minSdk 31 (Android TV 12) | PRD decision (Oct 23, 2026). |
| 2026-10-24 | **CI split:** GitHub Actions (Ubuntu/Windows) for analyze, test and Android/Windows builds; **Codemagic** for unsigned iOS only; GitHub Actions macOS = manual fallback | Saves the ~500 free Codemagic macOS minutes per month for iOS. The repo is public, so GitHub Actions minutes are free. |
| 2026-10-24 | **Sideloadly** is the standard iOS install tool; AltStore is documented as optional auto-refresh | PRD open question answered. It's the simplest way to start. |
| 2026-10-24 | iOS uses **Swift Package Manager** (Flutter default), so there is no Podfile. The deployment target is set in `Runner.xcodeproj` | Flutter 3.47 template default. The CocoaPods cache stays configured in CI in case a plugin needs it. |
| 2026-10-24 | **/assets is a Flutter package (`game_assets`)** | Flutter can't bundle files from outside an app's folder. Both apps depend on this package, and assets are looked up by logical key through `lib/asset_manifest.dart`. |
| 2026-10-24 | TV manifest declares `leanback` and `touchscreen` as **not required** | The app still shows in the TV launcher (LEANBACK_LAUNCHER + banner) but can also be sideloaded on emulators for quick checks. |
