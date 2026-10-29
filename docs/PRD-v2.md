# Game Controller v2: PRD

Oct 29, 2026 · @Manveer · Draft for review. Builds on v1 (docs/PRD.md, milestones M0 to M6)

## Overview

Version 2 turns the working controller and test bench from v1 into something people other than the developer can install, play and learn from.

It makes three changes:

1. **Better controller.** The A, B, X and Y buttons in analog stick mode get bigger and easier to hit, with a size setting for playtests.
2. **Analytics.** The phone and TV record how each control type (D-pad, gyro, sticks) is used and how it performs. This includes latency, empty taps, near misses, button frequency and game results, so we can tell what makes each mode fun or frustrating.
3. **A real game.** A collaborative puzzle game for 1 to 4 players, simple enough for an 8-year-old. Players race the clock, or each other, to carry and rotate shape pieces into an outline.

Testers install everything through the standard app stores: Google Play testing for the Android phone and TV apps, and TestFlight for the iPhone. The Windows host is a download. No sideloading tools are needed.

## Where v1 left off

v1 delivered everything in docs/PRD.md: discovery and pairing, three input modes, input and TV-to-phone haptics, the arena test game, settings, latency tooling and several controllers at once. It passed on the iPhone, the Android TV and the Windows laptop. The Android phone tests are still pending for every v1 milestone, and v2 closes them in M7.

Facts from v1 that v2 relies on:

- The measured input delay was about 6 ms on home Wi-Fi, well under the 50 ms target, so analytics can't be allowed to change it noticeably.
- The phone ignores haptic event names it doesn't know, so new haptic events reach older controllers without errors.
- The protocol is at version 1, and mismatched versions are rejected with a clear message.
- The app IDs are `com.gamecontrollerdev.controller` (phone, Android and iOS) and `com.gamecontrollerdev.tvtest` (TV).

## Goals and non-goals

v2 succeeds when someone who isn't the developer can follow a one-page guide and do the following:

- Install the apps from the stores.
- Play a puzzle match with friends or family.
- Produce analytics that show how each control type felt to them.

**Goals**

- Stick mode A, B, X and Y buttons that are easy to hit, with the size tunable in settings.
- Per-device, per-mode metrics that measure both performance (latency, accuracy) and experience (frustration and enjoyment signals), viewable on the TV and collected from testers' homes with their consent.
- A puzzle game for 1, 2, 3 or 4 players that an 8-year-old can finish on Easy, with tuning values exposed for playtests.
- Installs through Google Play testing tracks, TestFlight and a Windows download, with no sideloading tools.
- Milestones that each end in builds delivered through that pipeline (from M8 on) and a device-test gate.

**Non-goals**

- A public production release on the Play Store or App Store. v2 stays on testing tracks. Production is a later step.
- Internet play. This is still a firm non-goal. The only internet use in v2 is the opt-in analytics upload.
- Acting as a Bluetooth gamepad (HID). Still a firm non-goal.
- Apple TV, Samsung or LG hosts. Android TV and Windows stay the only hosts. A macOS host is a possible later option.
- Online leaderboards. Best times stay on the TV that recorded them.

## Users and key scenarios

The users are now the developer and outside testers: families and friends with an Android or iOS phone and either an Android or Google TV or a Windows PC. Some players are children, around age 8, playing with an adult.

1. **Install.** A tester opens a link, joins the test, and installs the TV app from the Play Store on the TV (or downloads the Windows build). Each player installs the controller from Google Play or TestFlight.
2. **Consent.** On first launch, the TV asks the adult whether to share anonymous gameplay stats. The answer is saved and can be changed in settings.
3. **Set up a match.** On the TV, the players pick Puzzle, then a difficulty. Each player presses A on their phone to join and pushes left or right to pick a side. Start begins a countdown.
4. **Play.** Players move their dots, pick up pieces with A, rotate them with X and Y (or the right stick), and drop them into the outline. Wrong drops turn red. A big piece calls for a teammate's help.
5. **Finish.** A celebration, the results, a new best time if there is one, and a quick "How did the controls feel?" question on each phone.
6. **Review.** The developer opens the stats report and compares D-pad, gyro and stick play across testers and devices.

## Constraints and assumptions

The biggest change from v1 is that the stores are now part of the pipeline. Each brings accounts, fees, review and privacy requirements, and those take time before any build can reach a tester.

- **Paid Apple Developer account.** TestFlight needs the Apple Developer Program ($99 a year). Enrollment can take a day or more. External testers join through a public link (up to 10,000). The first build of each version goes through Beta App Review, typically within a day or two, and builds expire after 90 days. TestFlight uploads need Xcode 26 or later, which Codemagic's `xcode: latest` already provides. With the paid account the iLoader sideload and its 7-day expiry are retired.
- **Google Play developer account.** A one-time $25 fee and identity verification, which can take several days. Testers join a closed testing track through a Google Group or an email list and get a join link. Closed test releases are also reviewed by Google, usually within hours to a few days. TV apps must be uploaded as Android App Bundles (AAB), and Android TV builds use their own form-factor track. (The 12-testers-for-14-days rule only applies when a new personal account applies for production, which v2 doesn't do.)
- **Sideloading is getting harder on Android.** Google's developer verification started in four countries on Sep 30, 2026 and reaches all countries in 2027. Installs through Play aren't affected, so v2 doesn't depend on APK sideloading.
- **Privacy.** Both stores need a privacy policy URL and data disclosures (Play's Data safety form, Apple's privacy details). Because children may play, the analytics must be anonymous, opt-in, free of advertising IDs and limited to gameplay data (see Analytics requirements).
- **Windows downloads are unsigned.** Windows SmartScreen warns on the first run ("More info", then "Run anyway"), and Windows Firewall must allow the app on private networks. The tester guide covers both. Code signing is a later option.
- **Development stays on Windows.** iOS builds stay on Codemagic, which now signs them and uploads to TestFlight. Android builds can stay local or move to CI.
- **Store package names are permanent.** The Play Store never allows an app ID to change, so the final IDs must be chosen before the first upload (see Open questions).
- **Assets.** CC0 assets as before (Kenney packs, jsfxr, ChipTone). The sounds and any music for the puzzle game are logged in assets/CREDITS.md.

## Controller app requirements

v2 adds these to v1's C1 to C13.

| ID | Requirement | Milestone |
| --- | --- | --- |
| C14 | Stick mode layout rebalance: A, B, X and Y grow to about 75% of their D-pad-mode size. The right stick and the small D-pad shrink to make room (the right stick by about 20%). Nothing overlaps, and everything fits on both test phones | M7 |
| C15 | Larger touch areas: each face button responds to touches a little outside its drawn circle (proposed: 15% larger radius), without stealing touches from a neighbouring control | M7 |
| C16 | Button size setting for stick mode (proposed range 60% to 100% of D-pad-mode size, default 75%), saved with the other settings. The layout keeps the no-overlap rule at every size | M7 |
| C17 | Touch metrics recorded on the phone for each input mode: presses per control, empty taps and their positions, near misses, slide-offs, rapid repeated taps, simultaneous touches, stick and tilt behaviour. Details are in Analytics requirements | M9 |
| C18 | Metrics sent to the TV over the existing connection in small batches, and buffered on the phone while disconnected | M9 |
| C19 | A "How did the controls feel?" prompt after a game: three faces plus optional tags (buttons too small, laggy, hard to steer, rotation hard). One tap, skippable, shown at most once every few games | M9 |
| C20 | Optional player nickname (up to 10 characters) in settings, shown on the TV and on its best-times board. It never leaves the TV | M12 |
| C21 | Haptic patterns for the new puzzle events (snap, wrong, help, tick, drop-ready), each with its own intensity setting like v1's four events | M10, M11 |
| C22 | Store-ready builds: release signing, version numbers from the tag, app name and icon, privacy policy link in settings, and the "Allow apps from unknown sources" note removed from the docs | M8 |
| C23 | "Try without a TV" demo screen that shows the controls responding with no host connected, for app reviewers and new testers checking their phone works | M8 |

## TV app requirements

v2 adds these to v1's T1 to T10.

| ID | Requirement | Milestone |
| --- | --- | --- |
| T11 | Game picker on the home screen: Puzzle (new) and Arena (v1 test game). The test tools (visualizer, haptic panel, latency) stay available | M10 |
| T12 | Puzzle game for 1 player (M10), then 2, 3 and 4 players (M11), as described in Puzzle game design | M10, M11 |
| T13 | Join screen: players press A to join and left or right to choose a side or team. Difficulty is chosen with the remote or Player 1's controller | M11 |
| T14 | Results screen with winner, times, pieces placed, and Rematch, Change teams and Back options | M11 |
| T15 | Countdown, celebration, last-15-seconds warning, hint glow, best-times board | M12 |
| T16 | Playtest settings screen with every tuning value in the puzzle design (tolerances, speeds, delays, time limit), saved on the TV, with Reset to defaults | M10 |
| T17 | Analytics collection: receives phone metrics, adds TV-side metrics (latency, game events), writes one summary per session | M9 |
| T18 | Stats screen: summary per session and per input mode, and export of the session files | M9 |
| T19 | Consent prompt on first launch and a setting to change it. Opt-in upload of session summaries when allowed, queued while offline | M9 |
| T20 | Store-ready builds: AAB for Play's Android TV track, versioned Windows release zip on GitHub Releases, privacy policy link | M8 |

## Analytics requirements

The aim is to explain why a control type feels good or bad, not just to count usage. Every metric is therefore recorded per device and per input mode, next to the settings in effect at the time, so modes can be compared with everything else held equal.

**How it is collected**

- **The phone measures touch.** Only the phone knows about empty taps, near misses and slide-offs. It keeps counters for each stretch of time spent in one mode (a "mode segment"). It sends a small batch to the TV about every 10 seconds, on every mode switch and at disconnect. The batch goes at low priority, so input messages always go first.
- **The TV measures everything else.** It records latency, connection health and game events for each player.
- **One summary per session.** The TV joins both sides into a session summary (JSON) saved on the TV. The Stats screen reads these files, and they can be exported.
- **Opt-in upload.** With the adult's consent, the TV uploads each session summary to a small cloud store and queues them while offline. The proposed store is Firebase Firestore through its REST API, so the same code runs on Android TV and Windows. Security rules allow create only, with no reads from the apps.
- **Report tool.** A command-line report downloads the uploaded summaries (or reads exported files) and prints per-mode and per-device comparison tables and CSV.

**What it records**

| Group | Metrics | What it tells us |
| --- | --- | --- |
| Context | Random install ID per device (not tied to a person), device model, OS and app version, screen size, input mode, settings in effect (sensitivity, dead zone, smoothing, button size, fixed or floating sticks, haptics on and intensity), game and difficulty, player count | Lets results be compared fairly across phones and settings |
| Mode usage | Time in each mode, mode switches (from, to, and how long after starting), first mode chosen, games played and finished per mode, quits and disconnects mid-game | Which modes people choose and stay with. Switching away within the first minute is a frustration signal |
| Touch accuracy | Presses per control, empty taps (touch that lands on no control) with position binned to a grid, near misses (empty tap within about 8 mm of a control, with the nearest control), slide-offs (touch starts on a button and drifts off it), rapid repeated taps (4 or more on one spot within 1 s), press duration, simultaneous controls held | Buttons that are too small or badly placed show up as near misses and slide-offs clustered around them |
| Sticks | Time at full deflection, time inside the dead zone while touched, touches that start outside a fixed stick's circle, direction reversals while steering | Sticks that are too sensitive or too small, and fixed versus floating |
| Gyro | Recalibrations, time at full tilt, steering oscillation (left-right reversals while aiming), time to settle on a target | Whether gyro steering is controllable or twitchy |
| Responsiveness | Estimated one-way input delay (median, 95th percentile, max), ping, jitter, input messages per second, disconnects and time to reconnect, TV frame drops | Ties a bad experience to the network or the device instead of the controls |
| Haptics | Events sent per type, haptics on or off, intensity | Whether haptics change outcomes or ratings |
| Puzzle results | Completion time, pieces placed, wrong drops, pickups, time carrying each piece, time rotating each piece, rotation overshoots (reversing to correct), angle and position error at drop, hint glows shown, help calls, solo big-piece carries, win, loss or draw | How hard each mode makes the precise parts of play: steering, picking up and rotating |
| Arena results | Wall hits, hazard hits, goals, round time, failed dashes | A second game to compare modes with |
| Rating | The post-game face rating (good, okay, bad) and tags | What players say, set against what the metrics show |

**Derived signals in the report**

- **Frustration:** empty taps and near misses per minute, slide-offs, rapid repeated taps, switching modes within the first minute, wrong-drop rate, rotation overshoots, latency spikes, bad ratings.
- **Enjoyment:** session length, games per session, rematches, finished puzzles, good ratings.
- **Mastery:** completion time and wrong drops falling over a player's games in one mode.

**Privacy rules**

- Upload is off until an adult opts in on the TV. Each phone shows that stats are recorded and can opt out in settings.
- No names, nicknames, email addresses, contacts, location, advertising IDs or Wi-Fi details are recorded or uploaded. Nicknames stay on the TV.
- Empty-tap positions are stored only as counts on a coarse grid, never as a touch trace.
- The privacy policy explains all of this in plain language and is linked from both apps and both store listings.

**Overhead**

- Metrics must not raise the median input delay by more than 1 ms. M9 checks this against v1's 6 ms baseline.
- Batches stay under about 4 KB. A session summary stays under about 50 KB.

## Puzzle game design

Each side builds the same shape picture against a 2-minute clock. Players carry pieces from a tray, rotate them, and drop them into an outline. Correct pieces snap and lock, wrong ones turn red.

**Modes and layout**

| Players | Layout | How to win |
| --- | --- | --- |
| 1 | One board in the middle, tray beside it | Finish before the clock runs out. The time is recorded |
| 2 (1 vs 1) | Screen split into left and right halves, each with the same board and tray | First to finish wins. At time-up, most correct pieces wins |
| 3 (2 vs 1) | Split screen, a team of two against one solo player | As for 2 players. The solo player carries big pieces at full speed |
| 4 (2 vs 2) | Split screen, two teams of two | As for 2 players |

```
+--------------------------------------------------------------+
|  LEFT  4/6 pieces           1:23           RIGHT 3/6 pieces  |
+------------------------------+-------------------------------+
| tray  |                      |                      |  tray  |
| [▲]   |    outline board     |     outline board    |   [▲]  |
| [■]   |        ●P1           |           ●P2        |   [■]  |
| [●]   |              ●P3     |    ●P4               |   [●]  |
+------------------------------+-------------------------------+
```

The trays sit at the outer edges and the boards toward the middle. Players stay inside their own half, and players on the same side pass through each other (proposed).

**Rules**

| Topic | Rule |
| --- | --- |
| Puzzle type | A simple picture made of distinct shapes (for example a house: walls, roof, door, window, sun). Easy outlines are coloured to match their pieces. Medium and Hard outlines are grey, so only the shape helps |
| Character | A dot in the player's colour with the player number, as in the arena game. Movement works as in the arena: the D-pad moves at a fixed speed, and tilt or stick push scales the speed |
| Picking up | When a dot is close enough to a piece, the piece highlights. A picks it up. A player holds one piece at a time, which follows the dot. Any piece in the tray or on the board can be picked up, except locked ones |
| Rotating | Continuous. Holding X turns the held piece clockwise and holding Y turns it counter-clockwise, at a steady speed. In stick mode the right stick also sets the angle: pushed past halfway, the piece turns quickly to face the stick's direction. Only a held piece rotates |
| Dropping | A drops the held piece. If it's within the position and angle tolerance of a matching outline, it snaps to the exact place and angle, locks, flashes green, and plays the snap sound and haptic. If it's on the board but not a match, it stays where it is, turns red (with a ✗ mark), and plays the wrong sound and haptic. If it's dropped off the board, it just sits there |
| Red pieces | Count as not placed. Any player on that side can pick one up again, and it goes back to its normal colour while carried |
| Matching | Identical pieces are interchangeable, so either of two identical windows fits either window outline. The angle tolerance accounts for symmetry: a square matches at every quarter turn, a circle at any angle |
| Drop-ready highlight | While a held piece is within tolerance of a matching outline, the outline brightens and the phone gives a light tick, so players learn what "close enough" means. On by default, a playtest setting |
| Big pieces | Team puzzles (sides with two players) have 1 or 2 big pieces. When both teammates hold one, it moves at normal speed, following the average of their two inputs, and either player can rotate or drop it. One player alone can carry it at a reduced speed. While someone carries it alone, it flashes an edge toward the free teammate, who also feels a "help" haptic (at most every 3 seconds). For a solo player (1 player, 1 vs 1, or the solo side in 2 vs 1), big pieces carry at full speed |
| Time limit | 2 minutes for every level (playtest setting) |
| Ending | The round ends when a side finishes, or at time-up. A finished side always beats an unfinished one. At time-up, the side with more correct pieces wins. A tie on pieces goes to the side that placed its last correct piece first (proposed), and if that's also equal, it's a draw. Wrong pieces don't subtract |
| Last 15 seconds | The clock turns red and ticks, and every phone gets a light pulse each second |
| Hint glow | When a player has held the same piece for a set time (default 10 seconds), its matching outline glows gently until it is placed or dropped |

**Difficulty and content**

| Level | Pieces | Rotated at start | Outlines | Big pieces (teams) |
| --- | --- | --- | --- | --- |
| Easy | About 4 | 1 at most | Coloured | 1 |
| Medium | About 6 | About half | Grey | 1 |
| Hard | About 8 | Most | Grey | 2 |

- There are about 3 puzzles per level, 9 in total. Proposed themes: house, rocket, tree and sun (Easy); boat, car, robot (Medium); castle, cat face, flower garden (Hard).
- Rotated pieces start at random angles at least 30° from correct.
- Each match picks a random puzzle from the chosen level, or a specific one from a menu.
- Puzzles are data files (shapes as polygons or circles, colours, starting angles, big-piece flags), so more can be added without code changes.

**Match flow**

1. The home screen's game picker leads to Puzzle and then the difficulty choice.
2. On the join screen, players press A to join and left or right to pick a side. The mode follows from who joined, and 1, 2, 3 or 4 players are all allowed.
3. Start shows a 3-2-1-Go countdown and the round begins.
4. Start during play pauses the round for everyone (proposed).
5. The results screen shows the winner, times, pieces and any new record, with confetti, the win sound and a success haptic for the winners.
6. The results screen offers Rematch (same teams, new random puzzle), Change teams or Back.
7. Each phone shows the controls rating (C19).

**Best-times board**

The TV keeps the top 5 completion times for each puzzle and format (solo, 1 vs 1, team). Each entry shows the player colours and nicknames if set. "New record!" appears when one is beaten.

**Controls in every mode**

| Action | D-pad mode | Gyro mode | Stick mode |
| --- | --- | --- | --- |
| Move | D-pad | Tilt | Left stick (or D-pad) |
| Pick up and drop | A | A | A |
| Rotate | Hold X or Y | Hold X or Y | Hold X or Y, or right stick |
| Pause | Start | Start | Start |
| Join and pick a side | A, then left or right | A, then tilt | A, then left stick |

**Haptic and sound events (new)**

| Event | When | Sound |
| --- | --- | --- |
| snap | Piece placed correctly | Snap |
| wrong | Piece dropped in a wrong spot | Thud, distinct from snap |
| drop-ready | Held piece comes within tolerance | None (light tick only) |
| help | A teammate carries a big piece alone | Short chime |
| tick | Each second in the last 15 | Clock tick |
| success (v1) | Winning a round | Win jingle |

Pickup, countdown and time-up also get sounds without haptics. All sounds come from Kenney's CC0 packs (the Sci-Fi Sounds pack is already downloaded in /kenney-audio) and are listed in CREDITS.md. Background music is optional, at a low volume, with an on/off setting.

**Readability and accessibility**

- Pieces and outlines are large enough to read from about 3 m on a TV.
- Shapes, and not only colours, tell pieces apart, and right and wrong also show a ✓ or ✗, so colour-blind players can play.
- Text on screen is short, because younger players may not read quickly.

**Playtest settings (all on the TV's playtest settings screen)**

| Setting | Proposed default |
| --- | --- |
| Angle tolerance | ±15° |
| Position tolerance | 25% of the piece's size |
| Rotation speed (X and Y) | 180° per second |
| Right-stick rotation threshold | Half deflection |
| Pickup range | 1 piece radius from the dot's edge |
| Solo big-piece speed | 35% of normal |
| Help haptic interval | 3 seconds |
| Hint glow delay | 10 seconds |
| Drop-ready highlight | On |
| Time limit | 2 minutes |
| Warning period | 15 seconds |

## Non-functional requirements

v1's requirements still apply. These are added or changed.

| Area | Requirement |
| --- | --- |
| Latency | Still under about 50 ms. Metrics add no more than 1 ms to the median input delay |
| Game performance | The puzzle game runs at 60 frames per second on the test TV with 4 players and all effects on |
| Kid usability | In a playtest, an 8-year-old finishes an Easy puzzle within 2 minutes after one practice round, in at least one input mode |
| Privacy | Anonymous, opt-in, no advertising IDs, data limited to gameplay, privacy policy published. Written so it stays compliant if the stores treat the app as one that children use |
| Protocol | Version 2 adds metrics batches, nicknames and the new haptic events. A v1 phone and a v2 TV reject each other with a clear "update the app" message, and testers update through the stores |
| Install | A tester can install every app from the stores or the Windows download without developer tools, USB cables or sideloading apps |
| Store compliance | Builds meet each store's current target-API and SDK rules, and listings include the privacy policy and data disclosures |

## Architecture changes

The architecture stays as it is: two Flutter apps, a shared protocol, a WebSocket over the local network. v2 adds three packages and one internet connection, used only for the analytics upload.

- **packages/puzzle\_game:** puzzle rules (tolerance with symmetry, snapping, big-piece carrying, scoring and ties), the puzzle data format with the 9 puzzles, and the game screen. It reuses the arena's movement code, moved to a shared place.
- **packages/metrics:** metric models, counters, aggregation and the session summary format, shared by the phone and the TV, with unit tests. It also contains the report command-line tool.
- **packages/protocol v2:** metrics batch, player profile (nickname, install ID), new haptic event names, a rating message, and puzzle game hints if needed (for example "holding a piece" to show on the phone).
- **TV app:** game picker, join and results screens, playtest settings, Stats screen, consent, and the uploader.
- **Controller app:** stick layout rebalance and size setting, touch metrics, rating prompt, nickname, demo screen.
- **CI and release:** Codemagic signs the iOS build and uploads it to TestFlight on tags. Android AABs for the phone and TV, and the Windows zip, are built on tags (on Windows or in GitHub Actions) and uploaded to Play and to GitHub Releases. Play uploads are manual at first and automated once stable (proposed).

## Milestone roadmap

Numbering continues from v1, so tags stay unique (m7 and later). Each milestone ends with builds, a gate, and the developer's device test before the next one starts. From M8 on, each milestone's builds go out through the store testing tracks.

| Milestone | What it delivers | Why in this order |
| --- | --- | --- |
| M7 | Bigger stick-mode buttons and v1's Android phone tests | A quick fix testers will notice, and it closes v1 on the second phone platform |
| M8 | Store testing pipeline | Accounts and reviews take time, and every later milestone ships through it |
| M9 | Analytics | Collection is in place before testers play the new game, so their first sessions count |
| M10 | Puzzle game, 1 player | Proves the core feel of carrying, rotating and dropping before adding players |
| M11 | Puzzle game, 2 to 4 players | Adds sides, teams, big pieces and win rules on top of a proven core |
| M12 | Fun, content and the first outside playtest | Adds the extras, all 9 puzzles and tuning, and puts it in testers' hands |

The Apple and Google account sign-ups should start during M7, because verification can take several days.

## Milestone 7: Bigger buttons and Android catch-up

Milestone 7 makes the stick-mode face buttons easy to hit and finishes v1's pending tests on the Android phone.

**Deployable builds**

- Controller: rebalanced stick layout and the button size setting, on the Android phone (local APK) and the iPhone (iLoader, for the last time).
- TV app: unchanged.

**Scope**

- Stick layout rebalance (C14), larger touch areas (C15) and button size setting (C16).
- Layout unit tests: no overlaps at every button size, on the screen sizes of both test phones and a small 16:9 phone.
- Run every pending v1 Android phone test (M0 to M6 checklists) and fix what fails.
- Start the Apple Developer Program enrollment and the Google Play developer account sign-up.

**Acceptance tests**

- [ ] In stick mode, A, B, X and Y are clearly larger, about 75% of their D-pad-mode size, and nothing overlaps on either phone.
- [ ] The button size setting changes the size live, stays within its range without overlaps, and is saved between launches.
- [ ] A press just outside a button's drawn edge still registers, and never triggers a neighbouring control.
- [ ] Both sticks, the D-pad, LB, RB, Select and Start still work with two thumbs at once.
- [ ] Every v1 checklist item marked "Android phone pending" passes on the Android phone.
- [ ] Both store accounts are applied for.

## Milestone 8: Store testing pipeline

Milestone 8 lets anyone install the apps from a link: Google Play testing for both Android apps, TestFlight for the iPhone, and a download for Windows.

**Deployable builds**

- Controller: on Google Play closed testing and TestFlight (internal group first, then an external group with a public link).
- TV app: on Google Play's Android TV closed testing track, and as a Windows zip on GitHub Releases.

**Scope**

- Final app names and IDs decided before the first Play upload (see Open questions).
- Release signing: a Play upload key with Play App Signing, and App Store Connect API keys in Codemagic. Secrets stay out of the repo.
- Codemagic signs the iOS build and uploads it to TestFlight on tags. The Beta App Review notes explain that the controller needs a TV or Windows host, link the Windows download and point to the demo screen (C23).
- Android AABs for the phone and TV, uploaded to the closed testing tracks, with testers joining through a Google Group link.
- Windows release zip on GitHub Releases for each tag, with SmartScreen and firewall steps in the guide.
- Store listings: short descriptions, icons, screenshots, the TV banner, Data safety and App privacy forms (no data collected yet), and export compliance (standard encryption only).
- Privacy policy page (first version) and a one-page tester guide, both published on GitHub Pages (proposed): how to join, install, connect to the same Wi-Fi, pair and report problems.
- In-app version shown in Diagnostics and on the TV home screen, so testers can say which build they have.

**Acceptance tests**

- [ ] Someone other than the developer follows the tester guide and installs the controller from Google Play on an Android phone and from TestFlight on an iPhone, without a cable or sideloading tool.
- [ ] The TV app installs from the Play Store on the Android TV, signed in with a tester account, and appears in the launcher.
- [ ] The Windows zip from GitHub Releases runs after the SmartScreen and firewall steps in the guide.
- [ ] Phones installed from the stores pair with the store-installed TV app and the Windows build, and all v1 features work.
- [ ] Pushing a tag produces the TestFlight build, the AABs and the Windows zip, and installed apps update to it.
- [ ] The demo screen works with no host.

## Milestone 9: Analytics

Milestone 9 records how each control type is used and how it performs, shows it on the TV, and, with consent, collects it from testers' homes.

**Deployable builds**

- Controller: touch metrics, the rating prompt and a stats note in settings.
- TV app: collection, Stats screen, export, consent prompt and opt-in upload. The arena game is instrumented.

**Scope**

- packages/metrics with the models, counters and session summary (C17, T17).
- Protocol v2: metrics batches and the rating message (C18).
- Phone touch metrics in all three modes: empty taps, near misses, slide-offs, rapid repeated taps, press counts and durations, stick and tilt metrics.
- TV metrics: latency (median, 95th percentile, max), connection health, arena game events.
- Rating prompt after arena rounds (C19).
- Stats screen and export (T18).
- Consent prompt, setting, uploader and offline queue (T19). Cloud store set up with create-only rules.
- Report command-line tool: per-mode and per-device tables and CSV.
- Privacy policy and store data disclosures updated for the analytics.
- Unit tests for every counter and derived signal, and a simulated-controller run that produces a known summary.

**Acceptance tests**

- [ ] After a session that uses all three modes, the Stats screen shows time, presses, empty taps, near misses and latency for each mode and each phone.
- [ ] Tapping deliberately just beside B shows up as near misses next to B, and tapping a blank area shows up as empty taps in the right grid cell.
- [ ] Turning the phone's Wi-Fi off mid-session loses no metrics: the batches arrive after reconnecting.
- [ ] With consent off, nothing is uploaded. With consent on, the session appears in the cloud store, and the report tool prints it.
- [ ] An exported session file contains no names, nicknames or network details.
- [ ] The median input delay with metrics on is within 1 ms of v1's baseline.
- [ ] The rating prompt appears after a game, can be skipped, and its answer appears in the session summary.

## Milestone 10: Puzzle game, 1 player

Milestone 10 builds the core of the puzzle game for one player, so carrying, rotating and dropping can be tuned before more players are added.

**Deployable builds**

- Controller: the new haptic patterns (snap, wrong, drop-ready) with their intensity settings.
- TV app: game picker, single-player puzzle with 3 Easy puzzles and 1 Medium puzzle, and the playtest settings screen.

**Scope**

- packages/puzzle\_game: puzzle data format, rules (tolerances with symmetry, snap and lock, red pieces, off-board drops) and the game screen.
- Movement, pickup, continuous rotation with X and Y and the right stick, dropping, and the drop-ready highlight.
- Time limit and results for 1 player (finished time or pieces placed).
- Game picker (T11) and playtest settings screen (T16).
- New haptic events and sounds for snap, wrong and drop-ready (C21).
- Puzzle metrics added to the session summary: completion time, wrong drops, rotation time and overshoots, angle and position error at drop.
- Unit tests: matching with symmetric and identical pieces, tolerance edges, lock and red states, results.

**Acceptance tests**

- [ ] An Easy puzzle can be finished with the D-pad, the gyro and the sticks.
- [ ] A piece dropped within tolerance snaps exactly, locks and buzzes. A piece dropped in the wrong spot stays, turns red and buzzes differently. Both feel distinct on the phone.
- [ ] Changing the angle tolerance in playtest settings changes what counts as correct straight away.
- [ ] Holding X and Y rotates smoothly in each direction, and the right stick points the piece in stick mode.
- [ ] A square piece matches its outline at any quarter turn.
- [ ] Time-up shows the pieces placed, and a finished puzzle shows the time.
- [ ] The arena game is still available from the game picker.

## Milestone 11: Puzzle game, 2 to 4 players

Milestone 11 turns the puzzle into a race between sides and teams, with big pieces that make teammates work together.

**Deployable builds**

- Controller: help haptic.
- TV app: join screen, split screen, 1 vs 1, 2 vs 1 and 2 vs 2, big pieces, the win and tie rules, and the results screen.

**Scope**

- Join screen with side and team choice (T13).
- Split-screen layout with a board and tray per side, and players kept to their own half.
- Big pieces: carried by two players, carried alone at reduced speed, edge flash and help haptic. Full speed for solo players.
- Ending and tie rules, and the results screen with Rematch, Change teams and Back (T14).
- Pause with Start.
- Team and side metrics: help calls, solo big-piece carries, win, loss or draw by mode.
- Unit tests for the end-of-round rules, ties and big-piece movement.
- Simulated controllers can join, so 4-player layouts can be checked with fewer phones.

**Acceptance tests**

- [ ] Two players race side by side, and the first to finish wins with their time shown.
- [ ] At time-up the side with more correct pieces wins, and the tie rules work in a staged tie.
- [ ] In 2 vs 2, a big piece moves at normal speed with both teammates on it, slowly with one, and calls the other with an edge flash and a help haptic.
- [ ] In 2 vs 1, the solo player carries big pieces at full speed.
- [ ] Rematch keeps the teams, and Change teams goes back to the join screen.
- [ ] Four controllers (phones or simulated) play a full match without lag, stuck input or disconnects.

## Milestone 12: Fun, content and the first outside playtest

Milestone 12 adds the touches that make the game fun, completes the puzzle set, and puts the game in outside testers' hands.

**Deployable builds**

- Controller: tick haptic, nickname setting.
- TV app: all 9 puzzles, countdown, celebration, last-15-seconds warning, hint glow, best-times board and music, released to every tester group.

**Scope**

- Countdown, celebration, last-15-seconds warning, hint glow, best-times board (T15).
- Nicknames (C20).
- The remaining puzzles, for 9 in total (3 per level), with tuned starting angles.
- Sounds and optional music, listed in CREDITS.md.
- A playtest round with outside testers, including at least one child around 8, using a short observation sheet in /docs alongside the metrics.
- Tuning: adjust defaults from the playtest and the metrics, and record the final values in docs/decisions.md.
- Final README updates, tester guide, and manual checklists for M7 to M12 in /docs/checklists.

**Acceptance tests**

- [ ] Every puzzle on every level can be finished within 2 minutes by an adult, and the Easy ones by an 8-year-old after one practice round.
- [ ] The countdown, celebration, warning, hint glow and new-record screen all appear at the right moments.
- [ ] Best times survive restarting the TV app and show nicknames.
- [ ] At least 3 outside households install from the stores and play, and their sessions appear in the report.
- [ ] The report compares the three modes on frustration signals, completion time and ratings, and the findings are written up in /docs.

## Test strategy

v1's strategy still holds: logic is tested automatically, and anything about feel, touch and devices is tested on real hardware. v2 adds rules tests, metrics tests, store installs and playtests with people.

| Area | Where it can be tested | Milestone |
| --- | --- | --- |
| Stick layout fit and overlaps at every size | Unit tests, then both phones | M7 |
| Store installs and updates | A tester's devices, from the store links | M8 |
| Metric counters and derived signals | Unit tests in packages/metrics | M9 |
| End-to-end metrics, upload and report | Simulated controller and real phones, against the Windows and TV builds | M9 |
| Metrics overhead | Input delay compared with v1's baseline on home Wi-Fi | M9 |
| Puzzle rules (tolerances, symmetry, locking, ties) | Unit tests in packages/puzzle\_game | M10, M11 |
| 4-player layouts and load | Phones plus simulated controllers | M11 |
| Feel of rotation, carrying and haptics | Real phones, in all three modes | M10 to M12 |
| Kid usability and fun | Playtests with an observation sheet, plus the metrics | M12 |

## Risks, decisions, open questions and next steps

The largest new risk is store review and policy. Outside testing depends on two reviews, and a children's game draws extra policy attention.

| Risk | Mitigation |
| --- | --- |
| Apple's reviewer can't test a controller without a host, and rejects the build | Review notes explaining the setup, a link to the Windows build, and the "Try without a TV" demo screen |
| Store accounts or reviews take longer than expected | Start the sign-ups in M7, and keep iLoader and local APKs as fallbacks for the developer |
| The stores treat the game as one children use and apply stricter rules | Anonymous, opt-in analytics with no advertising IDs or third-party analytics SDKs, and a clear privacy policy. Declare the target audience carefully (open question) |
| Continuous rotation is too hard for young players | Angle tolerance, the drop-ready highlight, few rotated pieces on Easy, hint glow, and tuning in the playtest |
| Bigger face buttons crowd the sticks on small phones | Size setting with a no-overlap rule, and layout tests on a small screen size |
| Metrics slow input down | Low-priority batches every 10 s, a size cap, and a measured overhead check in M9 |
| Testers without an Android TV or a Windows PC can't host | Tester guide states the requirement. A macOS host is a later option |
| Android's planned local-network permission changes how the phone finds the TV (to verify) | Track it when raising the target SDK, and keep manual IP entry as a fallback |
| Windows SmartScreen and firewall prompts confuse testers | Step-by-step guide with screenshots. Code signing later |
| Codemagic free minutes run low with signing and TestFlight uploads | Keep path filters and tag-only uploads, and upgrade if needed |

**Decisions (October 29, 2026)**

- Stick mode keeps two sticks. A, B, X and Y grow to about 75% of their D-pad-mode size, the right stick and the D-pad shrink, and a button size setting allows tuning.
- Analytics are collected by the TV. Phones send touch metrics to it, the TV shows them on a Stats screen and exports them, and it uploads them only with an adult's opt-in consent.
- Testers install through Google Play closed testing (phone and TV), TestFlight with a public link (iPhone) and GitHub Releases (Windows). This needs the paid Apple Developer account and a Google Play developer account.
- The arena game stays, alongside the puzzle game, behind a game picker.
- The puzzle uses shape pictures. Players can pick any piece from their tray.
- A correct drop snaps, locks and gives a success-style buzz. A wrong drop stays where it is, turns red and gives a different buzz.
- Rotation is continuous, with X and Y in every mode and the right stick in stick mode. A drop counts if it is within an angle tolerance, which is a playtest setting.
- Team puzzles have big pieces that two players carry together. One player can carry one alone, more slowly (a playtest setting), while the piece flashes an edge to call the teammate.
- Players set up matches on a join screen. Three players play 2 vs 1, and the solo player carries big pieces at full speed.
- Extras: countdown and celebration, last-15-seconds warning, hint glow and a best-times board.
- The time limit is 2 minutes on every level (a playtest setting). There are 3 levels with about 3 puzzles each.

**Open questions**

- **Final app names and IDs.** Play never allows an ID to change after the first upload, and `com.gamecontrollerdev.tvtest` reads as a test app. Should the TV app become something like `com.gamecontrollerdev.tv`, and what should the apps be called in the stores?
- **Target audience declaration.** Should the store listings declare a general audience ("for families") or include children under 13? Including children brings Google's Families policy and Apple's Kids rules.
- **Privacy policy and tester guide hosting.** GitHub Pages is the proposal. Is a public repository acceptable, or should the pages live elsewhere?
- **Cloud store.** Firebase Firestore (free plan) is the proposal. Is a Google account for the project acceptable?
- **Pause.** Should any player be able to pause with Start, or only Player 1?
- **Tie rule.** Is "the side that placed its last correct piece first wins" the right tie-breaker, or should a tie on pieces be a draw?

**Next steps**

- [ ] Review this draft and answer the open questions.
- [ ] Start the Apple Developer Program enrollment and the Google Play developer account.
- [ ] Give Claude Code the Milestone 7 section, and move on only after its acceptance tests pass.

Sources checked on Oct 29, 2026 for the store constraints: Google's [developer verification timeline](https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/), Play Console Help on [internal testing](https://support.google.com/googleplay/android-developer/answer/9845334) and [Android TV distribution](https://support.google.com/googleplay/android-developer/answer/9844679?hl=en), and Apple's [TestFlight overview](https://developer.apple.com/testflight/).
