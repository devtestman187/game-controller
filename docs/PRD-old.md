# Game Controller + Android TV Test App: PRD

Oct 21, 2026 · @Manveer

## Overview

This project delivers a cross-platform mobile game controller (Android and iOS) and an Android TV test app that the controller drives, built in six milestones that each end in builds you can install and test.

The phone acts as a gamepad over the home Wi-Fi network. It has two input modes, a directional pad with buttons and a gyroscope mode with buttons, and it gives haptic feedback both to confirm inputs and in response to events sent from the TV app.

The TV test app exists so the controller can be verified without building a full game. It shows live input, hosts a small playable test, and sends haptic events back to the phone. Both apps live in one Flutter monorepo, are developed on Windows, and have their iOS builds produced in cloud CI.

## Goals and non-goals

The project succeeds when a phone running either Android or iOS can pair with the TV app, control it in both modes, and exchange haptic feedback with it, all verified on real devices.

**Goals**

- One controller codebase that runs on Android and iOS.
- Two input modes: D-pad with buttons, and gyroscope with buttons.
- Haptics for input confirmation on the phone and for events sent from the TV app.
- A TV test app that exercises every controller feature on a physical Android TV, and also runs as a Windows desktop app for testing on a laptop.
- Every milestone ends with a deployable build of each app, plus a test plan to run on real devices.

**Non-goals and later options**

- Public store releases for now. iOS builds are sideloaded with a free Apple ID for now, but a store release, which needs the paid Apple Developer account, may come later, especially for the controller app.
- Playing over the internet. The controller and TV share a local network. This is a firm non-goal.
- TV platforms other than Android TV or Google TV for now. Apple TV is wanted later, and Samsung and LG smart TV platforms are a much lower priority that may become possible.
- Acting as a Bluetooth gamepad (HID) for other apps. This is a firm non-goal.

The test game may also grow into a real game later. To keep these options open, the protocol stays independent of the TV platform, and the test game stays in its own module so it can grow.

## Users and key scenarios

The primary user is the developer-tester: one person building on a Windows PC and testing with a physical Android phone, an iPhone, and a physical Android TV.

1. **Pair.** Launch the TV app, read the pairing code on screen, enter it on the phone, and see Connected on both devices.
2. **Play with the D-pad.** Hold a direction and press buttons at the same time, feeling a haptic tick on each press.
3. **Play with the gyro.** Switch modes, calibrate the neutral position, and steer by tilting the phone.
4. **Feel the game.** Drive the test sprite into an obstacle and feel the phone respond with a haptic event sent by the TV app.
5. **Recover.** Lose Wi-Fi briefly and have the phone reconnect without any manual steps.

## Constraints and assumptions

The biggest constraint is that iOS apps cannot be built locally, so every iOS build runs in cloud CI, and the result is signed and installed from Windows with a free Apple ID.

- **Windows only.** Development happens on Windows. The available Mac mini (model A1347) is too old to run the Xcode version Apple now requires, so it is not used.
- **iOS builds in the cloud.** Codemagic is the primary build service, with GitHub Actions macOS runners as a documented fallback. CI builds an unsigned .ipa. Apple's Xcode 26 requirement applies to App Store Connect uploads, including TestFlight, so it only matters if the project moves to TestFlight or the store later.
- **Free Apple ID signing.** iOS builds are signed with a free Apple ID instead of a paid Apple Developer account. Apps expire after 7 days and need re-signing, a free account allows three active sideloaded apps at once and roughly 10 new bundle IDs per week, and the signing tools ask for the Apple ID login, so a separate Apple ID is a sensible precaution. TestFlight needs the paid account ($99 per year), so it stays a fallback and a step toward a store release.
- **Build minutes.** Codemagic's free tier offered about 500 macOS build minutes per month as of October 2026 (approximate, verify current limits). Unsigned builds use fewer minutes than the earlier TestFlight plan, but triggers are still limited by file path, superseded builds are cancelled, and builds have a maximum duration.
- **Test devices.** A physical Android phone, an iPhone and a physical Android TV are available.
- **Emulator limits.** Gyro and haptics need real phones, which the test devices cover. An optional TV emulator sits behind NAT, so connecting to it needs manual IP entry.
- **Desktop test build.** The TV test app also runs as a Windows desktop app, so the controller can be tested against the laptop without the TV. It is a testing convenience, not a product target. The laptop and phone must be on the same network, and Windows Firewall must allow the app on private networks.
- **Assets.** Free CC0 assets (such as Kenney.nl packs) and self-generated sound effects (jsfxr, ChipTone). Every asset is logged in a credits file with its source and license.
- **Native iOS code is kept minimal.** Each iOS fix costs a CI build, a download, and a re-sign and install from Windows, so native Swift is limited to a small haptics channel and configuration.

## Controller app requirements

The controller runs on Android and iOS in landscape, with each requirement landing in the milestone shown.

| ID | Requirement | Milestone |
| --- | --- | --- |
| C1 | Runtime mode selector, landscape layout | M2 |
| C2 | D-pad mode: directional pad plus A, B, X, Y, Start and Select, with multi-touch (hold a direction while pressing a button) | M2 |
| C3 | Gyro mode: phone tilt sent as normalized analog x and y, with the same buttons | M3 |
| C4 | Gyro calibration (set neutral orientation), adjustable sensitivity and dead zone, smoothing | M3 |
| C5 | Input haptics: short tick on every press, release and direction change, with adjustable intensity and an on/off toggle | M2 |
| C6 | App-driven haptics: play events sent by the TV app (hit, success, error, rumble, with intensity and duration), silenced when the haptics toggle is off | M4 |
| C7 | Native haptics (Core Haptics on iOS, VibrationEffect on Android) behind one interface, with graceful fallback on unsupported devices | M2 |
| C8 | Discovery on the local network (mDNS), with manual IP entry as a fallback | M1 |
| C9 | Pairing with a short code shown on the TV, auto-reconnect after a drop, and visible connection status | M1 |
| C10 | Diagnostics screen: connection state, discovered hosts, local-network permission status, haptics capability, recent log lines, share log | M1 (basic), M5 (full) |
| C11 | Settings screen that saves haptic, sensitivity, dead zone and smoothing choices | M5 |

## TV test app requirements

The TV app is both the host the controller connects to and a test bench that proves each controller feature works.

| ID | Requirement | Milestone |
| --- | --- | --- |
| T1 | Proper Android TV manifest (leanback launcher, banner icon, no touchscreen requirement), fully usable with a standard TV remote | M0 |
| T2 | Hosts the connection server, advertises on the local network (mDNS), shows the pairing code and connection state | M1 |
| T3 | Simulated-controller test client that drives the TV app without a phone | M1 |
| T4 | Live round-trip ping from the heartbeat | M1 |
| T5 | Input visualizer: D-pad direction and each button state, then analog x and y from the gyro | M2, M3 |
| T6 | Haptic test panel that triggers each haptic event type on the connected controller | M4 |
| T7 | Playable test: a movable sprite with obstacles, driven by either input mode, with sound effects and haptic events on hits and wins | M4 |
| T8 | Latency readout with rolling average, and log export | M5 |
| T9 | Multiple controllers connected at once, each identified on the TV. The protocol allows for it from the start | M5 |
| T10 | Windows desktop build of the TV test app, using the same server, pairing and game code with a layout that fits a laptop window, so the controller can be tested without the TV | M1 |

## Non-functional requirements

The main quality bar is responsiveness: input should reach the TV in under about 50 ms on a typical home Wi-Fi network. This is a target to measure in Milestone 5, not a guarantee.

| Area | Requirement |
| --- | --- |
| Latency | Under about 50 ms from input to TV on typical home Wi-Fi (target to validate) |
| Gyro stream | About 60 Hz, throttled so it does not flood the network |
| Reliability | Heartbeats on every connection, automatic reconnect after a drop, and no stuck buttons after a disconnect or when the app is backgrounded |
| Pairing | The TV only accepts input from a controller that has entered the correct pairing code |
| iOS permissions | Local-network usage description and Bonjour service declarations set, with the permission prompt handled |
| Android permissions | Network permissions for discovery and connection, declared and requested as needed |
| Protocol | Versioned messages, so older and newer builds can detect a mismatch |
| Graceful degradation | Devices without a gyroscope or with limited haptics still run, with the unsupported features disabled or reduced |
| Compatibility | Phones: Android 16 and iOS 26 minimum (current major release minus one). TV app: Android TV 12 (API level 31), the version on the test TV |
| App size | Assets kept small, because both platform builds bundle them |

## Architecture and tech stack

Both apps are Flutter apps that talk over a local WebSocket connection, using messages defined once in a shared protocol package.

&#91;embedded content: architecture · 2 apps, 1 shared package\]

The controller sends input to the TV over one connection, and the TV sends haptic events back on the same connection.

- **Stack:** Flutter and Dart for both apps. The TV test app also builds as a Windows desktop app from the same code. Claude Code picks the state-management approach during planning and records the choice in the docs.
- **Repo layout:** one GitHub repository with /controller\_app, /tv\_test\_app, /packages/protocol, /docs and /assets.
- **Discovery:** mDNS (NSD on Android, Bonjour on iOS), with manual IP entry as a fallback.
- **Transport:** bidirectional WebSocket with versioned messages and heartbeats. UDP is considered for the gyro stream only if measured latency requires it.
- **Haptics:** a Dart interface with native implementations behind platform channels (Core Haptics on iOS, VibrationEffect on Android) and a fake implementation for tests.
- **Builds:** Android builds run locally on Windows. iOS builds run on Codemagic, which produces an unsigned .ipa that is signed with a free Apple ID and installed from Windows.
- **Tests:** unit tests for the protocol and input processing, plus a simulated-controller client that drives the TV app.

## Milestone roadmap

Each milestone ends in installable builds and a gate that must pass before the next one starts.

&#91;embedded content: milestone roadmap · 6 milestones, each with a gate\]

M0 proves the build pipelines, M1 to M4 each add one capability, and M5 measures and hardens the whole system.

## Milestone 0: Foundation and build pipelines

Milestone 0 proves that every build and install path works, including iOS in the cloud, before any feature depends on it.

**Deployable builds**

- Controller: hello-world app as an Android APK on the Android phone, and as a sideloaded build on the iPhone.
- TV app: hello-world app installed on the physical Android TV, shown in the launcher with a banner icon and navigable with the remote.

**Scope**

- Monorepo scaffold (/controller\_app, /tv\_test\_app, /packages/protocol, /docs, /assets) in a GitHub repository.
- Shared protocol package with one placeholder message and a passing unit test.
- CI: analyze and tests on every pull request and push to main. An unsigned iOS check build runs only when files under /controller\_app or /packages/protocol change. The build also packages an unsigned .ipa as a downloadable artifact on tags and manual triggers, ready to sign and install from Windows. Superseded builds are cancelled, caches are enabled, and builds stop after about 30 minutes.
- /docs/ios-setup.md with the manual steps only the developer can do: installing iTunes and iCloud from Apple (not the Microsoft Store versions) and Sideloadly on the Windows PC, turning on Developer Mode on the iPhone, connecting the repo to Codemagic, downloading the .ipa artifact, signing and installing it with a free Apple ID, trusting the developer profile, and re-signing every 7 days (with AltStore as an option for automatic refresh).
- Android TV manifest, banner icon and remote navigation (T1).
- /assets with CREDITS.md, and placeholder shapes instead of art.

**Acceptance tests**

- [ ] The controller APK installs and launches on the Android phone.
- [ ] The CI-built unsigned controller .ipa is signed with a free Apple ID, installs on the iPhone and launches.
- [ ] The TV app appears in the launcher and can be navigated with the remote.
- [ ] CI is green, and a docs-only change does not start an iOS build.
- [ ] The protocol unit test passes locally and in CI.

## Milestone 1: Discovery, pairing and connection

Milestone 1 delivers a phone that finds the TV, pairs with a code and stays connected, which every later feature builds on.

**Deployable builds**

- Controller: Android APK and sideloaded iOS build with discovery, pairing, connection status and a basic Diagnostics screen.
- TV app: server that advertises on the network, shows the pairing code, connection state and live ping. The same app also runs as a Windows desktop build on the laptop.

**Scope**

- Protocol v1: versioned messages for hello, pairing request and response, heartbeat and ping (C8, C9, T4).
- mDNS discovery on the phone and advertisement on the TV, with manual IP entry as a fallback.
- Pairing code shown on the TV and entered on the phone. Wrong codes are rejected.
- WebSocket connection with heartbeats, automatic reconnect and visible status on both devices.
- Simulated-controller test client that pairs and exchanges heartbeats without a phone (T3).
- Basic Diagnostics screen: connection state, discovered hosts, local-network permission status and recent log lines with a share button (C10). This is how iOS problems get debugged without Xcode.
- iOS local-network and Bonjour declarations, and Android network permissions.
- Windows desktop build of the TV app (T10): the same server, pairing and game code, with a layout that fits a laptop window, run directly on the laptop.
- Windows specifics: check early that the chosen mDNS package works on Windows, keeping manual IP entry as the fallback, and document that Windows Firewall must allow the app on private networks and that the laptop and phone must share the same Wi-Fi.

**Acceptance tests**

- [ ] The phone finds the TV automatically, accepts the pairing code, and both screens show Connected (Android phone and iPhone).
- [ ] A wrong pairing code is rejected and the connection is not established.
- [ ] Manual IP entry connects when discovery does not work.
- [ ] Turning Wi-Fi off and on makes the phone reconnect without manual steps.
- [ ] The iPhone shows the local-network permission prompt, and discovery works after allowing it.
- [ ] The simulated client pairs with the TV app and keeps the connection alive.
- [ ] The TV shows a live round-trip ping.
- [ ] The TV test app runs on the Windows laptop, and the Android phone and the iPhone discover it, pair and show Connected, after following the README's Windows Firewall steps.

## Milestone 2: D-pad mode and input haptics

Milestone 2 turns the phone into a working D-pad controller, with every input visible on the TV and felt on the phone.

**Deployable builds**

- Controller: landscape D-pad mode with buttons, haptic ticks, and haptic settings.
- TV app: input visualizer showing direction and button states.

**Scope**

- Landscape layout and a mode selector, with gyro mode shown but unavailable until Milestone 3 (C1).
- D-pad plus A, B, X, Y, Start and Select, with full multi-touch (C2).
- Input messages for button down and up and direction changes, sent to the TV.
- TV input visualizer showing the current direction and each button state (T5).
- Haptic tick on every press, release and direction change, with an intensity setting and an on/off toggle (C5).
- Haptics behind one Dart interface, with Core Haptics on iOS and VibrationEffect on Android, runtime capability checks, graceful fallback, and a fake implementation for tests (C7).
- Unit tests for input mapping and for the haptics interface.

**Acceptance tests**

- [ ] Each button press and release shows on the TV visualizer and ticks on the phone (Android phone and iPhone).
- [ ] Holding a direction while pressing buttons registers both at once.
- [ ] Changing haptic intensity, and turning haptics off, changes the behavior on both phones.
- [ ] No input stays stuck after the app is backgrounded or the connection drops.
- [ ] Diagnostics shows whether haptics are supported, and with haptics turned off or unsupported the app keeps running without errors.
- [ ] A first latency impression is noted for comparison in Milestone 5.

## Milestone 3: Gyro mode

Milestone 3 adds the second input mode, where tilting the phone steers, with calibration and tuning so it feels controllable.

**Deployable builds**

- Controller: D-pad mode and gyro mode with runtime switching, calibration and tuning controls.
- TV app: visualizer extended with live analog x and y.

**Scope**

- Gyroscope input converted to normalized analog x and y values (C3).
- Calibration that sets the neutral orientation, plus adjustable sensitivity, dead zone and smoothing (C4).
- A throttled stream of about 60 updates per second, sharing the existing connection.
- The same buttons and haptic ticks as D-pad mode, with switching between modes at runtime and no reconnect needed.
- A clear message on devices without a usable gyroscope, with gyro mode disabled.
- TV visualizer showing analog x and y alongside the buttons (T5).
- Unit tests for dead zone, smoothing, calibration and normalization.

**Acceptance tests**

- [ ] After calibrating, holding the phone at the neutral position shows x and y near zero on the TV.
- [ ] Tilting left, right, forward and back moves the analog values smoothly in the matching direction (Android phone and iPhone).
- [ ] Raising the dead zone removes small jitter, and raising sensitivity makes the same tilt produce a larger value.
- [ ] Switching between D-pad and gyro modes works mid-session without disconnecting.
- [ ] Buttons and haptic ticks work in gyro mode.
- [ ] Streaming gyro data does not cause visible lag or dropped connections on home Wi-Fi.

## Milestone 4: TV-to-phone haptics and the test game

Milestone 4 closes the loop: the TV app sends haptic events to the phone, and a small playable game triggers them from real gameplay.

**Deployable builds**

- Controller: plays the four haptic event types sent by the TV app, in both input modes.
- TV app: haptic test panel and a playable sprite game with sound effects.

**Scope**

- Protocol messages for haptic events: hit, success, error and rumble, each with intensity and duration (C6).
- Haptic test panel on the TV that triggers each event type on the connected controller (T6).
- Playable test: a movable sprite with obstacles, controlled by D-pad or gyro. Collisions send a hit event, reaching the goal sends success, and failed actions send error (T7).
- One sound per haptic event on the TV, using free CC0 packs or self-generated effects, loaded through an asset manifest so replacing a file needs no code change.
- Credits file updated for every asset added.
- Distinct, recognizable haptic patterns per event on both platforms, with fallback to a simple vibration where fine control is not available.

**Acceptance tests**

- [ ] Each of the four events triggered from the TV panel produces a distinct feel on the iPhone and the Android phone.
- [ ] The game is playable end to end with the D-pad and with the gyro.
- [ ] Collisions, wins and errors in the game fire the matching haptic event and sound together.
- [ ] Triggering events repeatedly, and after backgrounding the app, keeps haptics working (the iOS haptic engine restarts when needed).
- [ ] With the haptics toggle off, events sent from the TV produce no haptics on the phone.
- [ ] Replacing a sound file in /assets changes the sound without code changes.

## Milestone 5: Polish, settings and latency tooling

Milestone 5 makes the system dependable and measurable: saved settings, full diagnostics, and a latency number you can compare against the target.

**Deployable builds**

- Controller: settings screen, full Diagnostics screen and hardened reconnect.
- TV app: latency readout with rolling average, log export, and multi-controller support.

**Scope**

- Settings screen that saves haptic intensity and toggle, gyro sensitivity, dead zone and smoothing between launches (C11).
- Full Diagnostics screen with haptics capability and shareable logs (C10).
- Latency tooling on the TV: live round-trip ping, rolling average, and log export (T8).
- Reconnect hardening: sleeping phone, backgrounded app, TV app restart, and changed network.
- Multiple controllers connected at once, each identified on the TV (T9).
- A battery and CPU sanity check of a long gyro-streaming session.
- Final README per app and the manual test checklist for every milestone in /docs.

**Acceptance tests**

- [ ] Measured input latency on home Wi-Fi meets the target of about 50 ms, or the gap is documented with a plan.
- [ ] Saved settings survive closing and reopening the controller app.
- [ ] A play session of about 30 minutes (proposed) completes with no dropped connection or stuck input.
- [ ] The controller recovers after the TV app restarts and after the phone sleeps and wakes.
- [ ] Two controllers connect at the same time, and the TV shows each one's input separately.
- [ ] Every milestone's checklist passes on a fresh install from the latest tagged builds.

## Test strategy

Logic is tested automatically on Windows and in CI, while gyro, haptics, discovery and iOS behavior can only be verified on real devices.

| Area | Where it can be tested | Milestone |
| --- | --- | --- |
| Protocol serialization and pairing logic | Unit tests on Windows and in CI | M0, M1 |
| Connection and pairing without a phone | Simulated-controller client against the TV app | M1 |
| Full controller-to-TV loop without the TV | Windows desktop TV app with real phones on the same Wi-Fi | M1 onward |
| TV UI and remote navigation | Physical Android TV (an emulator is optional for quick checks) | M0 |
| mDNS discovery | Real phone with the physical TV or the Windows desktop app (an emulator sits behind NAT and needs manual IP) | M1 |
| iOS local-network permission | iPhone (sideloaded build) | M1 |
| Input processing (dead zone, smoothing, calibration) | Unit tests | M3 |
| Haptics | Real phones only (Core Haptics and VibrationEffect) | M2, M4 |
| Gyro | Real phones only | M3 |
| Latency | Real devices on home Wi-Fi | M5 |

**How each milestone reaches the devices.** Android builds are made on Windows and installed over USB. A milestone tag triggers a Codemagic build that produces an unsigned .ipa, which is downloaded, signed with a free Apple ID using Sideloadly (or AltStore), installed on the iPhone, and re-signed every 7 days. The TV APK is installed with adb on the TV, and the Windows desktop build runs directly on the laptop.

**Manual checklists.** Each milestone's acceptance tests above are copied into a checklist in /docs, so the same steps are run on the Android phone and the iPhone every time.

## Risks, decisions, open questions and next steps

The largest risk is slow iOS debugging, because every fix needs a cloud build, a download, and a re-sign and install.

| Risk | Mitigation |
| --- | --- |
| iOS-only bugs are slow to debug without a Mac | Keep native iOS code minimal, build the Diagnostics screen in Milestone 1, and rent a cloud Mac for a few days if stuck |
| The free Apple ID signature expires every 7 days, so the controller stops launching | Re-sign weekly with Sideloadly, or use AltStore auto-refresh while AltServer runs on the PC on the same network as the iPhone |
| The router blocks device discovery (client isolation) | Manual IP entry as a built-in fallback |
| Gyro noise and drift differ between phones | Calibration, smoothing and dead zone, tuned on both test phones |
| Haptic hardware differs widely across Android devices | Runtime capability checks and a simple-vibration fallback |
| Free CI minutes run out | Path-filtered triggers, cancelled superseded builds and a build time limit |
| Sideloading tools lag behind a new iOS release, or Apple changes the free-account rules | Fall back to a paid Apple Developer account and TestFlight |
| Windows Firewall blocks the desktop app, or the mDNS package does not support Windows | Allow the app on private networks, check package support early in Milestone 1, and keep manual IP entry as a fallback |

**Decisions (October 23, 2026)**

- Minimum versions are Android 16 and iOS 26, the current major release minus one.
- The TV app's minimum is Android TV 12 (API level 31), the version on the physical test TV, so the Android 16 minimum applies to the phones only.
- iOS builds are sideloaded with a free Apple ID, signed on Windows with Sideloadly or AltStore, instead of going through TestFlight. The paid account stays a fallback and a step toward a store release.
- A physical Android TV is available for testing.
- The TV test app also runs as a Windows desktop app, delivered in Milestone 1, so the controller can be tested on a laptop.
- The haptics off setting also silences haptic events sent by the TV app.
- Multi-controller support is part of Milestone 5.
- Internet play and acting as a Bluetooth gamepad are firm non-goals. A store release, Apple TV support and a fuller game are possible later.

**Open questions**

- Which sideloading tool to standardize on: Sideloadly (simplest to start, re-signed by hand), AltStore (refreshes automatically while AltServer runs on the PC), or SideStore (refreshes on the phone after setup)?

**Next steps**

- [ ] Install Sideloadly on the Windows PC (with iTunes and iCloud from Apple, not the Microsoft Store versions) and turn on Developer Mode on the iPhone.
- [ ] Answer the open question above.
- [ ] Give Claude Code the Milestone 0 section first, and move to the next milestone only after its acceptance tests pass.
