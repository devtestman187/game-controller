# Emulator probe, 2026-11-27 (plan roadmap item 2)

Verdict: the Android emulator works on this PC today, with no setup. Two AVDs exist and both boot headless in about 35 s. Nothing was installed, created or changed (the emulators were killed afterwards; none left running).

## Findings

| Check | Result |
|---|---|
| CPU / RAM | Ryzen 7 5800X, 31.9 GB |
| Virtualization | Hypervisor present (`HypervisorPresent` True). `emulator -accel-check`: "WHPX (10.0.26300) is installed and usable". (`Get-WindowsOptionalFeature` needs elevation, so feature names were not listed; not needed) |
| Android SDK | `C:\Users\mrman\AppData\Local\Android\Sdk`, `ANDROID_HOME` set to it |
| Tools present | `emulator\emulator.exe`, `platform-tools` (adb), `cmdline-tools\*\bin` with `avdmanager.bat` and `sdkmanager.bat`, build-tools 36.0.0, platforms android-31, 35, 36, ndk, cmake |
| System images installed | Only `android-31/default/x86_64` (Android 12, AOSP, no Play Store) |
| AVDs (`~/.android/avd`) | `m7_android12` (pixel_6 phone, 2400x1080, 420 dpi, 3.3 GB) and `m8_pixel_tablet` (pixel_tablet, 2560x1600, 320 dpi, 2.8 GB). Both on the API 31 image |
| Disk free | C: 92 GB, D: 58 GB, E: 88 GB (the repo drive), G: 3.9 GB |

## Boot test (headless: `-no-window -no-audio -no-snapshot -gpu swiftshader_indirect`)

| AVD | Boot to `sys.boot_completed=1` | `wm size` | `wm density` |
|---|---|---|---|
| m8_pixel_tablet | 37 s (emulator log: 35.6 s) | physical 2560x1600, override 1920x1200 | physical 320, override 240 |
| m7_android12 | 32 s | physical 2400x1080, override 1800x810 | physical 420, override 315 |

- Tablet reports Android 12 (`ro.build.version.release`). The emulator can reach the PC at 10.0.2.2 (ping 0% loss), which is what `tools/emulator.sh connect` uses for the Windows dev TV. Reaching a real TV on the home LAN from the NAT was not tested (plan item 19 stays open; the dev-TV-on-this-PC route works at the network level).
- Both AVDs carry a leftover size and density override (75% of physical: tablet 1920x1200 at 240 dpi is 800x500 logical, not the real Pixel Tablet's 1280x800; phone 1800x810 at 315 dpi is 571x257 logical). These persist in the AVD disk, likely from the demo video work. For layout checks run `adb shell wm size reset` and `adb shell wm density reset` first, or the screens will be tested at the wrong logical size.
- The emulator is an Android 12 tablet, so it does not stand in for the owner's Pixel Tablet (its Android version is recorded at setup). It is good enough for layout and integration runs.

## `tools/emulator.sh` assumptions

- SDK path: `ANDROID_HOME` first, else `%LOCALAPPDATA%/Android/Sdk`; both hold here. adb and emulator `.exe` found.
- Default AVD `m7_android12` exists. The script's flags (`-no-window -gpu swiftshader_indirect -no-snapshot -no-audio`) are what worked here.
- `docs/demo-video-runbook.md:83` lists the AVD path as `C:\Users\singh\.android\avd` (a different PC). Here it is `C:\Users\mrman\.android\avd`. Docs only; the script does not use it.
- `install` builds the debug APK with flutter if missing (`--build`), which hits the flutter tool crash (`docs/dev-tools.md:403`). Run it from an agent terminal tab, or prebuild the APK. Not tried (no flutter run, per instructions).
- The script does not reset the wm size/density override (see above); worth adding a `reset-display` step before layout runs.

## Not verified

- `flutter test integration_test -d emulator-5554` was not run (flutter tool crash risk; plan wants it from a terminal tab).
- Windows optional feature names (needs elevation); WHPX is confirmed usable by the emulator itself.

## Needs the owner's OK

Nothing for the current setup. If a modern or Play-like image were wanted later (not required): a Pixel Tablet-like landscape AVD on a newer image, for example `system-images;android-35;google_apis;x86_64`, roughly 1.5 GB download, plus a new AVD; a phone AVD likewise. Android TV emulator (optional, plan item 12): `system-images;android-35;android-tv;x86` about 1.5 GB. Sizes are estimates, not checked against the repository.
