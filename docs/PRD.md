# Game Controller + Android TV Test App: PRD

Oct 21, 2026 · @Manveer · Updated Oct 29, 2026: all seven milestones done on the iPhone, the Android TV and the Windows laptop; Android phone tests pending

## Overview

This project delivers a cross-platform mobile game controller (Android and iOS) and an Android TV test app that the controller drives, built in seven milestones that each end in builds you can install and test.

The phone acts as a gamepad over the home Wi-Fi network. It has three input modes, a directional pad with buttons, a gyroscope mode with buttons, and an Xbox-style layout with two analog sticks, and it gives haptic feedback both to confirm inputs and in response to events sent from the TV app.

The TV test app exists so the controller can be verified without building a full game. It shows live input, hosts a small playable test, and sends haptic events back to the phone. Both apps live in one Flutter monorepo, are developed on Windows, and have their iOS builds produced in cloud CI.

## Goals and non-goals

The project succeeds when a phone running either Android or iOS can pair with the TV app, control it in all three modes, and exchange haptic feedback with it, all verified on real devices.

**Goals**

- One controller codebase that runs on Android and iOS.
- Three input modes: D-pad with buttons, gyroscope with buttons, and Xbox-style analog sticks with buttons.
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
3. **Play with the gyro.** Switch modes, calibrate the neutral position, and steer by tilting the phone. Switch to the analog stick layout and use both thumbs on the two sticks.
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
| C6 | App-driven haptics: play events sent by the TV app (hit, success, error, rumble, with intensity and duration), silenced when the haptics toggle is off | M5 |
| C7 | Native haptics (Core Haptics on iOS, VibrationEffect on Android) behind one interface, with graceful fallback on unsupported devices | M2 |
| C8 | Discovery on the local network (mDNS), with manual IP entry as a fallback | M1 |
| C9 | Pairing with a short code shown on the TV, auto-reconnect after a drop, and visible connection status | M1 |
| C10 | Diagnostics screen: connection state, discovered hosts, local-network permission status, haptics capability, recent log lines, share log | M1 (basic), M6 (full) |
| C11 | Settings screen that saves haptic, sensitivity, dead zone and smoothing choices | M6 |
| C12 | Analog stick mode: Xbox-style landscape layout with two analog sticks, A, B, X and Y, a D-pad, shoulder buttons (LB, RB), Select and Start, with multi-touch across both thumbs. No triggers | M4 |
| C13 | Analog stick input: each stick sends normalized x and y inside a unit circle, with adjustable dead zone and sensitivity, and returns to center on release. Fixed sticks by default, with a floating option. No stick click | M4 |

## TV test app requirements

The TV app is both the host the controller connects to and a test bench that proves each controller feature works.

| ID | Requirement | Milestone |
| --- | --- | --- |
| T1 | Proper Android TV manifest (leanback launcher, banner icon, no touchscreen requirement), fully usable with a standard TV remote | M0 |
| T2 | Hosts the connection server, advertises on the local network (mDNS), shows the pairing code and connection state | M1 |
| T3 | Simulated-controller test client that drives the TV app without a phone | M1 |
| T4 | Live round-trip ping from the heartbeat | M1 |
| T5 | Input visualizer: D-pad direction and each button state, then analog x and y from the gyro, then both sticks | M2, M3, M4 |
| T6 | Haptic test panel that triggers each haptic event type on the connected controller | M5 |
| T7 | Playable test: a movable sprite with obstacles, driven by any input mode, with sound effects and haptic events on hits and wins. One sprite per connected controller | M5, M6 |
| T8 | Latency readout with rolling average (ping and estimated one-way input delay), and log export | M6 |
| T9 | Multiple controllers connected at once, each identified on the TV with a player number and colour. The protocol allows for it from the start | M6 |
| T10 | Windows desktop build of the TV test app, using the same server, pairing and game code with a layout that fits a laptop window, so the controller can be tested without the TV | M1 |

## Test game design

The test game is a top-down arena where one sprite crosses a field of walls and moving hazards to reach a goal, built to exercise every input mode and every haptic event.

| Decision | Choice |
| --- | --- |
| Game type | Top-down arena with walls, moving hazards and a goal |
| Movement | The D-pad moves the sprite at one fixed speed. Gyro tilt and stick push scale the speed |
| Buttons and right stick | A dashes, a short speed boost with a cooldown. The right stick moves an aim cursor with no gameplay effect yet. Other buttons only show on the visualizer |
| Haptic events | Hit: the sprite bumps a wall or a hazard touches it. Success: the sprite reaches the goal. Error: dash pressed while on cooldown. Rumble: while dashing |
| Round flow | Reaching the goal wins, and a new round starts after about two seconds. Hazards never end a round. A timer and counters show on screen |
| Field | Fills the window and resizes with it. Speeds are set relative to the field size so movement feels comparable across screens (proposed) |
| Look | Plain coloured shapes first, replaced later by CC0 art as the assets plan says |
| Debug info | A toggleable overlay, off by default, showing connection state, live ping, input mode, stick or tilt values and the last haptic event sent. A remote key or keyboard key toggles it |
| Several controllers | One sprite per controller, in the player's colour. Haptic events go only to the player who caused them, and the first player to reach the goal wins the round (M6) |

Left for the build: the arena layout, hazard paths and counts, speeds, dash duration and cooldown, and the exact haptic patterns. Claude Code proposed values (recorded in docs/decisions.md), and they passed the device tests unchanged. The haptic patterns were reworked in M6 so the four events differ in rhythm and length, not just strength.

## Non-functional requirements

The main quality bar is responsiveness: input should reach the TV in under about 50 ms on a typical home Wi-Fi network. This is a target to measure in Milestone 6, not a guarantee.

| Area | Requirement |
| --- | --- |
| Latency | Under about 50 ms from input to TV on typical home Wi-Fi. Met in Milestone 6: the TV estimates the one-way input delay from the heartbeats, and a 31-minute run from the PC averaged about 6 ms, and the iPhone latency test passed |
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

- **Stack:** Flutter and Dart for both apps. The TV test app also builds as a Windows desktop app from the same code. State management is Riverpod, recorded with the other build choices in docs/decisions.md.
- **Repo layout:** one GitHub repository with /controller\_app, /tv\_test\_app, /packages/protocol, /packages/connection (server, phone client and simulated controller), /packages/test\_game, /docs and /assets.
- **Discovery:** mDNS (NSD on Android, Bonjour on iOS), with manual IP entry as a fallback.
- **Transport:** bidirectional WebSocket with versioned messages and heartbeats. UDP is considered for the gyro stream only if measured latency requires it.
- **Haptics:** a Dart interface with native implementations behind platform channels (Core Haptics on iOS, VibrationEffect on Android) and a fake implementation for tests.
- **Builds:** Android builds run locally on Windows. iOS builds run on Codemagic, which produces an unsigned .ipa that is signed with a free Apple ID and installed from Windows.
- **Tests:** unit tests for the protocol and input processing, plus a simulated-controller client that drives the TV app.

## Milestone roadmap

Each milestone ends in installable builds and a gate that must pass before the next one starts.

&#91;embedded content: milestone roadmap · 7 milestones, each with a gate\]

M0 proves the build pipelines, M1 to M5 each add one capability, and M6 measures and hardens the whole system.

**Status (Oct 29, 2026).** Every milestone passed its device tests on the iPhone, the physical Android TV and, where it applies, the Windows laptop. The Android phone tests are still pending for every milestone. The Android phone build is made in CI for each milestone but hasn't been tested on the phone. The results for each milestone are in /docs/checklists.

| Milestone | Tag | Passed | Android phone |
| --- | --- | --- | --- |
| M0 Foundation and build pipelines | m0 | Oct 24, 2026 | Pending |
| M1 Discovery, pairing and connection | m1 | Oct 24, 2026 | Pending |
| M2 D-pad mode and input haptics | m2 | Oct 24, 2026 | Pending |
| M3 Gyro mode | m3.2 | Oct 24, 2026 | Pending |
| M4 Analog stick mode | m4 | Oct 25, 2026 | Pending |
| M5 TV-to-phone haptics and the test game | m5 | Oct 25, 2026 | Pending |
| M6 Polish, settings and latency tooling | m6 | Oct 29, 2026 | Pending |

In the acceptance tests below, a ticked box means the test passed on the iPhone and the TV. Tests that name the Android phone still need to be run on it.

## Milestone 0: Foundation and build pipelines

Milestone 0 proves that every build and install path works, including iOS in the cloud, before any feature depends on it.

**Deployable builds**

- Controller: hello-world app as an Android APK on the Android phone, and as a sideloaded build on the iPhone.
- TV app: hello-world app installed on the physical Android TV, shown in the launcher with a banner icon and navigable with the remote.

**Scope**

- Monorepo scaffold (/controller\_app, /tv\_test\_app, /packages/protocol, /docs, /assets) in a GitHub repository.
- Shared protocol package with one placeholder message and a passing unit test.
- CI: analyze and tests on every pull request and push to main. An unsigned iOS check build runs only when files under /controller\_app or /packages/protocol change. The build also packages an unsigned .ipa as a downloadable artifact on tags and manual triggers, ready to sign and install from Windows. Superseded builds are cancelled, caches are enabled, and builds stop after about 30 minutes.
- /docs/ios-setup.md with the manual steps only the developer can do: installing Apple's iTunes (not the Microsoft Store version) and iLoader on the Windows PC, turning on Developer Mode on the iPhone, connecting the repo to Codemagic, downloading the .ipa artifact, importing it into iLoader to sign and install it with a free Apple ID, trusting the developer profile, and re-installing it every 7 days.
- Android TV manifest, banner icon and remote navigation (T1).
- /assets with CREDITS.md, and placeholder shapes instead of art.

**Acceptance tests**

- [ ] The controller APK installs and launches on the Android phone (pending).
- [x] The CI-built unsigned controller .ipa is signed with a free Apple ID, installs on the iPhone and launches.
- [x] The TV app appears in the launcher and can be navigated with the remote.
- [x] CI is green, and a docs-only change does not start an iOS build.
- [x] The protocol unit test passes locally and in CI.

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

- [x] The phone finds the TV automatically, accepts the pairing code, and both screens show Connected (Android phone and iPhone).
- [x] A wrong pairing code is rejected and the connection is not established.
- [x] Manual IP entry connects when discovery does not work.
- [x] Turning Wi-Fi off and on makes the phone reconnect without manual steps.
- [x] The iPhone shows the local-network permission prompt, and discovery works after allowing it.
- [x] The simulated client pairs with the TV app and keeps the connection alive.
- [x] The TV shows a live round-trip ping.
- [x] The TV test app runs on the Windows laptop, and the Android phone and the iPhone discover it, pair and show Connected, after following the README's Windows Firewall steps.

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

- [x] Each button press and release shows on the TV visualizer and ticks on the phone (Android phone and iPhone).
- [x] Holding a direction while pressing buttons registers both at once.
- [x] Changing haptic intensity, and turning haptics off, changes the behavior on both phones.
- [x] No input stays stuck after the app is backgrounded or the connection drops.
- [x] Diagnostics shows whether haptics are supported, and with haptics turned off or unsupported the app keeps running without errors.
- [x] A first latency impression is noted for comparison in Milestone 6.

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

- [x] After calibrating, holding the phone at the neutral position shows x and y near zero on the TV.
- [x] Tilting left, right, forward and back moves the analog values smoothly in the matching direction (Android phone and iPhone).
- [x] Raising the dead zone removes small jitter, and raising sensitivity makes the same tilt produce a larger value.
- [x] Switching between D-pad and gyro modes works mid-session without disconnecting.
- [x] Buttons and haptic ticks work in gyro mode.
- [x] Streaming gyro data does not cause visible lag or dropped connections on home Wi-Fi.

## Milestone 4: Analog stick mode

Milestone 4 adds the third input mode, an Xbox-style layout with two analog sticks and a full set of buttons, so the controller can handle games that need independent movement and aiming.

**Deployable builds**

- Controller: D-pad, gyro and analog stick modes with runtime switching.
- TV app (Android TV and Windows desktop): input visualizer extended with both sticks and the full button set.

**Scope**

- Xbox-style landscape layout (C12): left stick at the upper left with the D-pad below it, right stick at the lower right with A, B, X and Y above it, Select (left) and Start (right) in the center, and shoulder buttons (LB, RB) along the top edges. Start and Select take the places of Xbox's Menu and View. There are no triggers (LT, RT).
- Two independent analog sticks (C13): drag a thumb inside a fixed circle, with normalized x and y inside the unit circle, adjustable dead zone and sensitivity, and a return to center on release. A setting switches to floating sticks, which appear where the thumb lands. Fixed sticks are the default. Tapping a stick does nothing (no L3 or R3 stick click).
- Stick values and the new buttons travel in the same full-state input message as the other buttons, throttled to about 60 updates per second while a stick moves, with a final center message on release.
- Haptic ticks on button presses, with the same intensity and on/off settings as the other modes.
- TV input visualizer showing both sticks live, plus the state of every button (T5).
- A mode selector with three modes, switchable at runtime without reconnecting.
- Unit tests for stick normalization, unit-circle clamping, dead zone, and serialization of the new messages.

**Acceptance tests**

- [x] Moving each stick moves the matching indicator on the TV smoothly, and releasing it returns the indicator to center (Android phone and iPhone).
- [x] Both sticks and a button work at the same time, using both thumbs and a finger on a shoulder button.
- [x] A diagonal push never exceeds full scale, and the dead zone removes small jitter.
- [x] Every button (A, B, X, Y, LB, RB, Select, Start and the four D-pad directions) shows on the TV and ticks on the phone.
- [x] Switching among D-pad, gyro and stick modes mid-session works without disconnecting, and no input stays stuck after a mode switch, a disconnect or backgrounding the app.
- [x] The layout fits both test phones in landscape with no overlapping controls.

## Milestone 5: TV-to-phone haptics and the test game

Milestone 5 closes the loop: the TV app sends haptic events to the phone, and a small playable game triggers them from real gameplay.

**Deployable builds**

- Controller: plays the four haptic event types sent by the TV app, in all three input modes.
- TV app: haptic test panel and a playable sprite game with sound effects.

**Scope**

- Protocol messages for haptic events: hit, success, error and rumble, each with intensity and duration (C6).
- Haptic test panel on the TV that triggers each event type on the connected controller (T6).
- Playable test: a movable sprite with obstacles, controlled by any of the three input modes. Wall bumps and hazard touches send a hit, reaching the goal sends success, a dash pressed on cooldown sends error, and dashing sends rumble (T7). The full design is in the Test game design section.
- One sound per haptic event on the TV, using Kenney's CC0 Sci-Fi Sounds, loaded through an asset manifest so replacing a file needs no code change.
- Credits file updated for every asset added.
- Distinct, recognizable haptic patterns per event on both platforms, with fallback to a simple vibration where fine control is not available.

**Sound files**

The four sounds are picked from Kenney's Sci-Fi Sounds pack (CC0, kenney.nl) and copied into assets/audio as OGG files. The TV app plays them with an audio package that bundles its own decoder (flutter\_soloud is the first choice), so OGG plays the same on Android TV and Windows without codecs installed on the PC. If that package fails on either platform, convert the files to WAV and update the asset manifest.

| Event | File | Kenney Sci-Fi Sounds source file |
| --- | --- | --- |
| Hit | assets/audio/hit.ogg | explosionCrunch\_003.ogg |
| Success | assets/audio/success.ogg | computerNoise\_003.ogg |
| Error | assets/audio/error.ogg | slime\_001.ogg |
| Rumble | assets/audio/rumble.ogg | forceField\_003.ogg |

Files can be .wav or .ogg and are named after the event. Each one gets a line in /assets/CREDITS.md with its source and license, and silent stubs let the game run before the files exist.

**Acceptance tests**

- [x] Each of the four events triggered from the TV panel produces a distinct feel on the iPhone and the Android phone.
- [x] The game is playable end to end with the D-pad, the gyro and the analog sticks.
- [x] Wall bumps, hazard touches, wins, failed dashes and dashes fire hit, success, error and rumble with the matching sound.
- [x] All four sound files exist, play on the TV with their events in both the Android TV and Windows builds, and are listed in CREDITS.md.
- [x] Triggering events repeatedly, and after backgrounding the app, keeps haptics working (the iOS haptic engine restarts when needed).
- [x] With the haptics toggle off, events sent from the TV produce no haptics on the phone.
- [x] Replacing a sound file in /assets changes the sound without code changes.

## Milestone 6: Polish, settings and latency tooling

Milestone 6 makes the system dependable and measurable: saved settings, full diagnostics, and a latency number you can compare against the target.

**Deployable builds**

- Controller: settings screen, full Diagnostics screen and hardened reconnect.
- TV app: latency readout with rolling average, log export, and multi-controller support.

**Scope**

- Settings screen that saves haptic intensity and toggle, gyro and analog stick sensitivity and dead zone, and gyro smoothing, between launches (C11).
- Per-event haptic intensity in settings: hit, success, error and rumble each get their own intensity, separate from the button tick, with a "try it" button for each, so the four events are easier to tell apart (from the M5 device test: "haptics are a little hard to differentiate").
- Full Diagnostics screen with haptics capability and shareable logs (C10).
- Latency tooling on the TV: live round-trip ping, rolling average, and log export (T8).
- Reconnect hardening: sleeping phone, backgrounded app, TV app restart, and changed network.
- Multiple controllers connected at once, each identified on the TV (T9). In the test game each controller drives its own sprite.
- A battery and CPU sanity check of a long gyro-streaming session.
- Final README per app and the manual test checklist for every milestone in /docs.

**Acceptance tests**

- [x] Measured input latency on home Wi-Fi meets the target of about 50 ms, or the gap is documented with a plan.
- [x] Saved settings survive closing and reopening the controller app.
- [x] Each TV haptic event's intensity can be set on its own in settings, changes how that event feels from the TV, and doesn't change the button tick.
- [x] A play session of about 30 minutes (proposed) completes with no dropped connection or stuck input.
- [x] The controller recovers after the TV app restarts and after the phone sleeps and wakes.
- [x] Two controllers connect at the same time, and the TV shows each one's input separately.
- [x] Every milestone's checklist passes on a fresh install from the latest tagged builds.

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
| Input processing (dead zone, smoothing, calibration) | Unit tests | M3, M4 |
| Haptics | Real phones only (Core Haptics and VibrationEffect) | M2, M5 |
| Gyro | Real phones only | M3 |
| Analog sticks (two-thumb multi-touch, layout fit on both phones) | Real phones only | M4 |
| Latency | Real devices on home Wi-Fi | M6 |

**How each milestone reaches the devices.** Android builds are made on Windows and installed over USB. A milestone tag triggers a Codemagic build that produces an unsigned .ipa, which is downloaded, imported into iLoader to be signed with a free Apple ID and installed on the iPhone, and re-installed every 7 days. The TV APK is installed with adb on the TV, and the Windows desktop build runs directly on the laptop.

**Manual checklists.** Each milestone's acceptance tests above are copied into a checklist in /docs, so the same steps are run on the Android phone and the iPhone every time.

## Risks, decisions, open questions and next steps

The largest risk is slow iOS debugging, because every fix needs a cloud build, a download, and a re-sign and install.

| Risk | Mitigation |
| --- | --- |
| iOS-only bugs are slow to debug without a Mac | Keep native iOS code minimal, build the Diagnostics screen in Milestone 1, and rent a cloud Mac for a few days if stuck |
| The free Apple ID signature expires every 7 days, so the controller stops launching | Re-install the build through iLoader every week, and keep the paid account and TestFlight as the fallback |
| The router blocks device discovery (client isolation) | Manual IP entry as a built-in fallback |
| Gyro noise and drift differ between phones | Calibration, smoothing and dead zone, tuned on both test phones |
| Haptic hardware differs widely across Android devices | Runtime capability checks and a simple-vibration fallback |
| Free CI minutes run out | Path-filtered triggers, cancelled superseded builds and a build time limit |
| Apple blocks the sign-in method that sideloading tools use again (as happened in October 2026), or a tool lags behind a new iOS release | Fall back to a paid Apple Developer account and TestFlight |
| Windows Firewall blocks the desktop app, or the mDNS package does not support Windows | Allow the app on private networks, check package support early in Milestone 1, and keep manual IP entry as a fallback |
| The full Xbox-style layout is cramped on a phone screen, with two sticks, a D-pad, face buttons, shoulders and triggers | Triggers were dropped, and the layout fit the iPhone in Milestone 4. The fit on the Android phone is still to be checked |

**Decisions (October 23, 2026)**

- Minimum versions are Android 16 and iOS 26, the current major release minus one.
- The TV app's minimum is Android TV 12 (API level 31), the version on the physical test TV, so the Android 16 minimum applies to the phones only.
- iOS builds are sideloaded with a free Apple ID, installed from Windows with iLoader (it worked on October 24, 2026, when Sideloadly and Impactor failed to sign in), instead of going through TestFlight. The paid account stays a fallback and a step toward a store release.
- The test game is a top-down arena where hazards never end a round, A dashes, the right stick aims a cursor, and the arena fills the window. Details are in the Test game design section.
- Analog stick mode is Milestone 4, placed before the test game so the game and the polish milestone cover all three input modes. The later milestones are now Milestone 5 and Milestone 6.
- A physical Android TV is available for testing.
- The TV test app also runs as a Windows desktop app, delivered in Milestone 1, so the controller can be tested on a laptop.
- The haptics off setting also silences haptic events sent by the TV app.
- Multi-controller support is part of Milestone 6.
- Internet play and acting as a Bluetooth gamepad are firm non-goals. A store release, Apple TV support and a fuller game are possible later.

**Decisions (October 24 to 29, 2026)**

- The Android phone tests are deferred for every milestone and stay pending. Each milestone was accepted on the iPhone, the TV and the laptop.
- Analog stick mode has two sticks, a D-pad, A, B, X and Y, LB and RB, and Select and Start (in place of View and Menu). There are no triggers and no stick click.
- The sticks can be fixed or floating, switched in settings. Fixed is the default, because it felt best in the M4 device test.
- With several controllers connected, each one drives its own sprite in the test game, only the player who causes a haptic event feels it, and the first to the goal wins the round.
- Each TV haptic event (hit, success, error and rumble) has its own strength setting on the phone, separate from the button tick, because the four events were hard to tell apart in the M5 device test. The patterns were also reworked to differ in rhythm and length.
- The TV app remembers paired phones, so they reconnect without the code after the TV app restarts, and a Forget phones button clears them.
- The TV app keeps the screen on while a controller is connected, because the TV went to sleep after 10 minutes without remote input and dropped the controllers.
- Latency is measured as a one-way input delay estimated from the heartbeats, alongside the round-trip ping. UDP isn't needed, because the WebSocket connection meets the 50 ms target.

**Open questions**

- Should the iPhone build be re-installed by hand each week through iLoader, or should SideStore (which iLoader can install) refresh it automatically? SideStore's sign-in still needed workarounds in October 2026.

**Next steps**

- [ ] Run the Android phone tests for every milestone (pending).
- [ ] Keep a copy of the iLoader installer that worked, in case a newer release breaks sign-in.
- [ ] Answer the open question above.
- [x] Give Claude Code the Milestone 0 section first, and move to the next milestone only after its acceptance tests pass.
