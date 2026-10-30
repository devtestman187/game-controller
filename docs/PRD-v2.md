# Thumb Party v2: PRD

Oct 29, 2026 · @Manveer · Draft for review. Builds on v1, the "Game Controller" project (docs/PRD.md, milestones M0 to M6)

## Overview

Version 2 turns the working controller and test bench from v1 into something people other than the developer can install, play and learn from.

It makes four changes, plus groundwork for v3:

1. **Better controller.** The A, B, X and Y buttons in analog stick mode get bigger and easier to hit, with a size setting for playtests.
2. **Analytics.** The phone and TV record how each control type (D-pad, gyro, sticks) is used and how it performs. This includes latency, empty taps, near misses, button frequency and game results, so we can tell what makes each mode fun or frustrating.
3. **A real game.** A collaborative puzzle game for 1 to 4 players, simple enough for an 8-year-old. Players race the clock, or each other, to carry and rotate shape pieces into an outline.
4. **Play without a TV.** One phone hosts the game and the other phones join it. Every phone shows the game with its controls laid over it, at an opacity the player sets. A family with only phones can play.
5. **Platform groundwork.** A written protocol spec, a game-facing host interface that doesn't depend on any engine or device, and controls the game can define on the phone. These are cheap now and hard to add later. The preferred v3 direction is a framework for games that run on a phone and stream to the TV. Phone hosting in v2 is its first half (see Platform direction).

Testers install everything through the standard app stores: Google Play testing for the Android phone and TV apps, and TestFlight for the iPhone. The Windows host is a download. No sideloading tools are needed, and with phone hosting, no TV or PC is needed either.

## Where v1 left off

v1 delivered everything in docs/PRD.md: discovery and pairing, three input modes, input and TV-to-phone haptics, the arena test game, settings, latency tooling and several controllers at once. It passed on the iPhone, the Android TV and the Windows laptop. The Android phone tests are still pending for every v1 milestone, and v2 closes them in M7.

Facts from v1 that v2 relies on:

- The measured input delay was about 6 ms on home Wi-Fi, well under the 50 ms target, so analytics can't be allowed to change it noticeably.
- The phone ignores haptic event names it doesn't know, so new haptic events reach older controllers without errors.
- The protocol is at version 1, and mismatched versions are rejected with a clear message.
- The app IDs are `com.gamecontrollerdev.controller` (phone, Android and iOS) and `com.gamecontrollerdev.tvtest` (TV). v2 renames both apps and changes their IDs in M8 (see Names and IDs).

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
- A protocol and host interface that another engine or a PC bridge could implement from the written spec alone, proven by our own games using nothing else.
- Phone-hosted play for 1 to 4 players on Android and iPhone, with every phone showing the game, so no TV or PC is required.
- Tablets (iPad and Android) work as controllers, as hosts and as a shared screen, and the controller runs on Android 12 and later, so most families' existing devices can join.

**Non-goals**

- A public production release on the Play Store or App Store. v2 stays on testing tracks. Production is a later step.
- Internet play. This is still a firm non-goal. The only internet use in v2 is the opt-in analytics upload.
- Acting as a Bluetooth gamepad (HID). Still a firm non-goal: iPhones can't do it, and free Android apps already do.
- Streaming video, or building the streaming framework, the engine kits (Unity, Godot), the PC bridge or a browser controller. These are v3 candidates, with streaming preferred. v2 only lays the groundwork (P1 to P7, S1 to S9) and phone hosting.
- Apple TV, Samsung, LG, Roku or Fire TV apps. The hosts are Android TV, Windows and, from M12, phones. Fire TV (Fire OS) is a cheap later addition once a test device is available, and the rest are v3 stream-receiver candidates (see Platform direction).
- Online leaderboards. Best times stay on the device that hosted the game.

## Users and key scenarios

The users are now the developer and outside testers: families and friends with an Android or iOS phone or tablet, and optionally an Android or Google TV or a Windows PC. Some players are children, around age 8, playing with an adult.

1. **Install.** A tester opens a link, joins the test, and installs the TV app from the Play Store on the TV (or downloads the Windows build). Each player installs the controller from Google Play or TestFlight.
2. **Consent.** On first launch, the TV asks the adult whether to share anonymous gameplay stats. The answer is saved and can be changed in settings.
3. **Set up a match.** On the TV, the players pick Puzzle, then a difficulty. Each player presses A on their phone to join and pushes left or right to pick a side. Start begins a countdown.
4. **Play.** Players move their dots, pick up pieces with A, rotate them with X and Y (or the right stick), and drop them into the outline. Wrong drops turn red. A big piece calls for a teammate's help.
5. **Finish.** A celebration, the results, a new best time if there is one, and a quick "How did the controls feel?" question on each phone.
6. **Review.** The developer opens the stats report and compares D-pad, gyro and stick play across testers and devices.
7. **No TV.** In the car or at a friend's house, one player taps "Host a game" on their phone and picks Puzzle. The others join with the code shown on the host phone. Each phone shows the game with see-through controls on top, and in the puzzle each phone zooms to its own side's board.

## Constraints and assumptions

The biggest change from v1 is that the stores are now part of the pipeline. Each brings accounts, fees, review and privacy requirements, and those take time before any build can reach a tester.

- **Paid Apple Developer account.** TestFlight needs the Apple Developer Program ($99 a year). Enrollment can take a day or more. External testers join through a public link (up to 10,000). The first build of each version goes through Beta App Review, typically within a day or two, and builds expire after 90 days. TestFlight uploads need Xcode 26 or later, which Codemagic's `xcode: latest` already provides. With the paid account the iLoader sideload and its 7-day expiry are retired.
- **Google Play developer account.** A one-time $25 fee and identity verification, which can take several days. Testers join a closed testing track through a Google Group or an email list and get a join link. Closed test releases are also reviewed by Google, usually within hours to a few days. TV apps must be uploaded as Android App Bundles (AAB), and Android TV builds use their own form-factor track. (The 12-testers-for-14-days rule only applies when a new personal account applies for production, which v2 doesn't do.)
- **Sideloading is getting harder on Android.** Google's developer verification started in four countries on Sep 30, 2026 and reaches all countries in 2027. Installs through Play aren't affected, so v2 doesn't depend on APK sideloading.
- **Privacy.** Both stores need a privacy policy URL and data disclosures (Play's Data safety form, Apple's privacy details). Because children may play, the analytics must be anonymous, opt-in, free of advertising IDs and limited to gameplay data (see Analytics requirements).
- **Windows downloads are unsigned.** Windows SmartScreen warns on the first run ("More info", then "Run anyway"), and Windows Firewall must allow the app on private networks. The tester guide covers both. Code signing is a later option.
- **Development stays on Windows.** iOS builds stay on Codemagic, which now signs them and uploads to TestFlight. Android builds can stay local or move to CI.
- **Store package names are permanent.** The Play Store never allows an app ID to change, so the final IDs were chosen before the first upload (see Names and IDs).
- **Assets.** CC0 assets as before (Kenney packs, jsfxr, ChipTone). The sounds and any music for the puzzle game are logged in assets/CREDITS.md.
- **Minimum versions.** The controller's Android minimum drops from Android 16 to Android 12 (API 31), the same as the TV app. That lifts its reach from about a quarter of active Android devices to about four-fifths (StatCounter, mid-2026, rough). One code change was needed: the M7 emulator check found an Android 13 vibration call, which now falls back to the older form on Android 12. iOS and iPadOS stay at 26.
- **Test devices.** An Android phone, an iPhone, an Android tablet (Android 15), an iPad (iPadOS 26), the Android TV and the Windows laptop. Android 12 itself is checked on an emulator, which can't test haptics or gyro.
- **Tablet platform rules.** On Android 16 and later, the system ignores an app's landscape lock on large screens (600dp and wider) unless the app declares itself a game. On iPadOS 26, apps run in resizable windows and the old "full screen only" setting is ignored, so orientation is locked per window. The controller must handle both, and cope with any window size.

## Names and IDs

The brand is Thumb Party. The phone app is the main app, because from M12 it hosts and shows games as well as controlling them. The rename happens in M8, before the first store upload, because Play never lets an app ID change afterwards.

| | Phone and tablet app | TV and PC app |
| --- | --- | --- |
| Store name | Thumb Party | Thumb Party TV (the Windows build uses the same name) |
| Subtitle (proposed) | Play together on any screen | |
| App ID (Android, and iOS bundle ID) | `com.thumbparty.app` | `com.thumbparty.tv` |
| Before M8 | Controller, `com.gamecontrollerdev.controller` | Controller Test, `com.gamecontrollerdev.tvtest` |

- The puzzle game is called **Shape Race** in the game picker, next to Arena.
- The new IDs make the apps new apps on every device. The developer's devices are uninstalled and reinstalled once, and phones pair again with the code.
- A trademark search for "Thumb Party" (USPTO) is done before the first upload. A web search found no app with that name. The USPTO search ran on Oct 29, 2026 and found no filings for "Thumb Party" or "Shape Race".

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
| C20 | Optional player nickname (up to 10 characters) in settings, shown on the TV and on its best-times board. It never leaves the TV | M13 |
| C21 | Haptic patterns for the new puzzle events (snap, wrong, help, tick, drop-ready), each with its own intensity setting like v1's four events | M10, M11 |
| C22 | Store-ready builds: the new name (Thumb Party) and ID, release signing, version numbers from the tag, icon, privacy policy link in settings, and the "Allow apps from unknown sources" note removed from the docs | M8 |
| C23 | "Try without a TV" demo screen that shows the controls responding with no host connected, for app reviewers and new testers checking their phone works | M8 |
| C24 | Shows game-defined controls (P5) and the status panel (P6) in all three modes, without shrinking any control below its C14 size | M10 |
| C25 | Host a game: "Host a game" on the connect screen runs the host on the phone. It advertises on the network, shows a pairing code and the join screen, and runs the game, with the host phone's owner playing as a local player (S2) | M12 |
| C26 | Join a phone host: phone hosts appear in discovery next to TVs, labelled as phones, and pair with the code shown on the host phone | M12 |
| C27 | Game view: on every phone in a phone-hosted game, the game is drawn from the host's snapshots (S8) with the same game code the TV uses. Game sounds and haptics play on each player's own phone | M12 |
| C28 | Overlay controls: all three input modes drawn on top of the game view (S9), with an opacity setting (proposed 20% to 100%, default 60%) that is saved. Controls keep their C14 to C16 sizes and touch areas, and game-defined controls (P5) still apply | M12 |
| C29 | The host phone keeps the host-side data (S6): consent prompt, stats, best times and playtest settings, the same as on the TV | M12 |
| C30 | Android minimum lowered to Android 12 (API 31). An Android 12 emulator check (starts, pairs, lays out, plays) runs before each milestone tag | M7 |
| C31 | Controls sized by physical size: every layout is sized in millimetres with a maximum size and anchored to the corners the thumbs reach, instead of scaling with the screen. Phones look as they do after C14, and on tablets the controls stay thumb-sized, leaving the middle free for the status panel or the game | M7 |
| C32 | Orientation and window rules: the controller declares itself a game on Android (`android:appCategory="game"`, so the landscape lock still applies on large screens). The iPad orientation list is fixed to landscape only (today it allows portrait), with the per-window orientation lock that iPadOS 26 expects. The layout copes with resized and split-screen windows and shows "Make the window bigger" below a minimum size | M7 |
| C33 | Feedback without haptics: on devices without vibration (every iPad, many Android tablets) controls flash when pressed and an optional click sound plays. Stick mode is the default on tablets. The haptics capability is recorded with the metrics | M7 |
| C34 | Show on this device: a host option where the game fills the host's screen with no controls on top, as on a TV, and every player uses their phone as a controller. Meant for a tablet in the middle of the table, but works on any phone | M12 |

## TV app requirements

v2 adds these to v1's T1 to T10.

| ID | Requirement | Milestone |
| --- | --- | --- |
| T11 | Game picker on the home screen: Shape Race (the puzzle game, new) and Arena (v1 test game). The test tools (visualizer, haptic panel, latency) stay available | M10 |
| T12 | Puzzle game for 1 player (M10), then 2, 3 and 4 players (M11), as described in Puzzle game design | M10, M11 |
| T13 | Join screen: players press A to join and left or right to choose a side or team. Difficulty is chosen with the remote or Player 1's controller | M11 |
| T14 | Results screen with winner, times, pieces placed, and Rematch, Change teams and Back options | M11 |
| T15 | Countdown, celebration, last-15-seconds warning, hint glow, best-times board | M13 |
| T16 | Playtest settings screen with every tuning value in the puzzle design (tolerances, speeds, delays, time limit), saved on the TV, with Reset to defaults | M10 |
| T17 | Analytics collection: receives phone metrics, adds TV-side metrics (latency, game events), writes one summary per session | M9 |
| T18 | Stats screen: summary per session and per input mode, and export of the session files | M9 |
| T19 | Consent prompt on first launch and a setting to change it. Opt-in upload of session summaries when allowed, queued while offline | M9 |
| T20 | Store-ready builds: the new name (Thumb Party TV) and ID, AAB for Play's Android TV track, versioned Windows release zip on GitHub Releases, privacy policy link | M8 |

## Analytics requirements

The aim is to explain why a control type feels good or bad, not just to count usage. Every metric is therefore recorded per device and per input mode, next to the settings in effect at the time, so modes can be compared with everything else held equal.

**How it is collected**

- **The phone measures touch.** Only the phone knows about empty taps, near misses and slide-offs. It keeps counters for each stretch of time spent in one mode (a "mode segment"). It sends a small batch to the TV about every 10 seconds, on every mode switch and at disconnect. The batch goes at low priority, so input messages always go first.
- **The TV measures everything else.** It records latency, connection health and game events for each player.
- **One summary per session.** The TV joins both sides into a session summary (JSON) saved on the TV. The Stats screen reads these files, and they can be exported.
- **Phone hosts do the same.** From M12, a host phone or tablet takes the TV's place in all of this (S6): it collects, saves, shows, exports and, with consent, uploads.
- **Device class.** Every summary records whether each device is a phone, a tablet or a foldable, with its physical screen size and whether it can vibrate, so tablet results are compared with like for like.
- **Opt-in upload.** With the adult's consent, the TV uploads each session summary to a small cloud store and queues them while offline. The store is Firebase Firestore (free plan) through its REST API, in a project owned by the same Google account as the Play developer account, so the same code runs on Android TV and Windows. Security rules allow create only, with no reads from the apps.
- **Report tool.** A command-line report downloads the uploaded summaries (or reads exported files) and prints per-mode and per-device comparison tables and CSV.

**What it records**

| Group | Metrics | What it tells us |
| --- | --- | --- |
| Context | Random install ID per device (not tied to a person), device model, OS and app version, screen size, input mode, settings in effect (sensitivity, dead zone, smoothing, button size, overlay opacity, fixed or floating sticks, haptics on and intensity), game and difficulty, player count, host type, and where the player watched the game (TV or PC screen, host phone, joined phone) | Lets results be compared fairly across phones and settings, and compares playing on a TV with playing on the phone's own screen |
| Mode usage | Time in each mode, mode switches (from, to, and how long after starting), first mode chosen, games played and finished per mode, quits and disconnects mid-game | Which modes people choose and stay with. Switching away within the first minute is a frustration signal |
| Touch accuracy | Presses per control, empty taps (touch that lands on no control) with position binned to a grid, near misses (empty tap within about 8 mm of a control, with the nearest control), slide-offs (touch starts on a button and drifts off it), rapid repeated taps (4 or more on one spot within 1 s), press duration, simultaneous controls held | Buttons that are too small or badly placed show up as near misses and slide-offs clustered around them |
| Sticks | Time at full deflection, time inside the dead zone while touched, touches that start outside a fixed stick's circle, direction reversals while steering | Sticks that are too sensitive or too small, and fixed versus floating |
| Gyro | Recalibrations, time at full tilt, steering oscillation (left-right reversals while aiming), time to settle on a target | Whether gyro steering is controllable or twitchy |
| Responsiveness | Estimated one-way input delay (median, 95th percentile, max), ping, jitter, input messages per second, disconnects and time to reconnect, frame drops on the host and on every phone showing the game, snapshot delay and gaps on joined phones, host phone temperature state and battery drop | Ties a bad experience to the network or the device instead of the controls |
| Haptics | Events sent per type, haptics on or off, intensity | Whether haptics change outcomes or ratings |
| Puzzle results | Completion time, pieces placed, wrong drops, pickups, time carrying each piece, time rotating each piece, rotation overshoots (reversing to correct), angle and position error at drop, hint glows shown, help calls, solo big-piece carries, win, loss or draw | How hard each mode makes the precise parts of play: steering, picking up and rotating |
| Arena results | Wall hits, hazard hits, goals, round time, failed dashes | A second game to compare modes with |
| Rating | The post-game face rating (good, okay, bad) and tags | What players say, set against what the metrics show |

**Derived signals in the report**

- **Frustration:** empty taps and near misses per minute, slide-offs, rapid repeated taps, switching modes within the first minute, wrong-drop rate, rotation overshoots, latency spikes, bad ratings.
- **Enjoyment:** session length, games per session, rematches, finished puzzles, good ratings.
- **Mastery:** completion time and wrong drops falling over a player's games in one mode.

**Privacy rules**

- Upload is off until an adult opts in on the host (the TV, the PC or the host phone). Each phone shows that stats are recorded and can opt out in settings.
- No names, nicknames, email addresses, contacts, location, advertising IDs or Wi-Fi details are recorded or uploaded. Nicknames stay on the host.
- Empty-tap positions are stored only as counts on a coarse grid, never as a touch trace.
- The privacy policy explains all of this in plain language and is linked from both apps and both store listings.

**Overhead**

- Metrics must not raise the median input delay by more than 1 ms. M9 checks this against v1's 6 ms baseline.
- Batches stay under about 4 KB. A session summary stays under about 50 KB.

## Puzzle game design (Shape Race)

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

**On phones (phone-hosted games, M12)**

The rules are the same. Only the view changes, because a phone screen is small and the controls sit on top of it.

- **Own side only.** Each phone zooms to its own side's board and tray. A strip along the top shows the clock and the other side's progress (for example "Right 3/6"). A solo player sees the whole board.
- **Room for thumbs.** In landscape the thumbs cover the lower-left and lower-right corners. The phone view puts the board in the middle and the tray along the top edge, so pieces are rarely under the controls.
- **Minimum size.** Pieces are never drawn smaller than about 9 mm across. Easy and Medium puzzles fit at that size on both test phones, and Hard ones are checked in M12.
- **See-through controls.** Controls are drawn over the game at the player's opacity setting (C28). Game-defined labels (P5) still show.
- **Status panel.** The phone status panel (P6) isn't needed when the game is on the phone itself, so it is hidden.
- **Tablets.** A tablet showing the game with controls on top has room for both sides, so it shows the full split screen. With "Show on this device" (C34), a tablet shows the same view as a TV, and players use their phones as controllers.

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
| Ending | The round ends when a side finishes, or at time-up. The first side to finish wins. At time-up, the side with more correct pieces wins. Equal counts (including none on either side) are a draw. Wrong pieces don't subtract |
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
4. Any player can press Start during play to pause the round for everyone. The player who paused, or Player 1, can resume it, so Player 1 can always override a pause.
5. The results screen shows the winner, times, pieces and any new record, with confetti, the win sound and a success haptic for the winners.
6. The results screen offers Rematch (same teams, new random puzzle), Change teams or Back.
7. Each phone shows the controls rating (C19).

**Best-times board**

The host (TV, PC or host phone) keeps the top 5 completion times for each puzzle and format (solo, 1 vs 1, team). Each entry shows the player colours and nicknames if set. "New record!" appears when one is beaten.

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

- Pieces and outlines are large enough to read from about 3 m on a TV, and at least about 9 mm across on a phone.
- Shapes, and not only colours, tell pieces apart, and right and wrong also show a ✓ or ✗, so colour-blind players can play.
- Text on screen is short, because younger players may not read quickly.

**Playtest settings (all on the host's playtest settings screen)**

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

## Platform direction

The controller is only useful if games can use it. v2 does the cheap groundwork, and v3 picks the main path once the analytics and tester feedback are in.

**Ways the controller could reach games**

| Path | What it is | Verdict |
| --- | --- | --- |
| Games in our host app | Puzzle and Arena, built by us, hosted on the TV or PC | v2 |
| Phone-hosted play | One phone hosts and the other phones join it. Every phone draws the game from the host's state snapshots, with the controls laid over it. No video | **v2 (M12).** No TV or PC needed, delay close to today's |
| Phone-hosted games streamed to a TV | The host phone sends the game to a receiver app on a TV or PC. **Snapshots first:** receivers that can run our game code (Android TV, Windows, and possibly Apple TV, Samsung and LG through Flutter's ports) draw the game from snapshots, with no video. **Video as the fallback:** a low-latency video stream for receivers that can't run our game code (Roku, Fire TV's Vega OS, web-based TV apps) and for games from other engines. Packaged as a framework that other developers can build games with | **Preferred v3 direction.** Snapshots keep the delay close to today's. Video adds roughly 50–100 ms and needs native encoding on both phone platforms (heavy on iOS) |
| Engine kits | Host libraries for Unity (C#) and Godot that follow the spec, so other developers can build phone-controlled games. Each phone appears as a normal gamepad in the engine, with extras on top (haptics, gyro, players joining, game-defined controls) | v3 candidate. The stronger product |
| PC bridge | A Windows app that turns our input into keyboard presses (no driver needed), and later possibly a virtual Xbox controller, so existing PC games work | v3 candidate. Quick usefulness, crowded market. The standard virtual-controller driver (ViGEmBus) was retired in Nov 2023 |
| Browser controller | The TV serves a controller web page that guests open by scanning a QR code, with no install | v3 candidate, as a guest option. iPhone browsers can't vibrate, and iPhone gyro needs HTTPS |
| Bluetooth gamepad | The phone pairs as a standard Bluetooth controller | Non-goal. Android only, already covered by free apps, no gyro or game haptics |
| Consoles | Switch, PlayStation, Xbox | Not possible. They accept only licensed controllers |

**TV platforms**

The main limit on other TV platforms is that most of their apps can make outgoing connections but can't accept incoming ones. Today the TV is the host that phones connect to, so those TVs can't play that role. In the v3 model the phone hosts and the TV connects out to it as a display, which suits them (rule S3).

| Platform | Status | Notes |
| --- | --- | --- |
| Google TV and Android TV (Sony, TCL, Hisense, Philips, Google TV Streamer, Chromecast with Google TV) | v2 host | Already supported |
| Amazon Fire TV (Fire OS 7 and 8) | Later, when a test device is available | Same Android app with a lower minimum Android version (Fire OS 8 is API 30, Fire OS 7 is API 28, the TV app needs 31 today), and Amazon Appstore Live App Testing for testers |
| Amazon Fire TV (Vega OS: Fire TV Stick 4K Select, 2026 Fire TV Stick HD) | v3 receiver candidate | Linux-based, runs React Native or web apps, no Android apps. Video receiver |
| Apple TV | v3 receiver candidate | Flutter has no official Apple TV support, only a community port (`flutter_tvos`). Video decoding is a natural fit. TestFlight covers it with the paid account |
| Samsung (Tizen), LG (webOS) | v3 receiver candidates | Web apps can't accept incoming connections. Samsung maintains a Flutter port for Tizen, and Flutter on webOS was reported for 2026. Tester installs need developer mode or store partnership |
| Roku | Lowest priority | Its own language (BrightScript) and weak graphics. Video receiver at most |

**What v2 does now**

| ID | Requirement | Milestone |
| --- | --- | --- |
| P1 | Protocol spec in docs/protocol.md, covering discovery and its TXT records, pairing, tokens, heartbeats, close codes, every message and field, timing and throttling rules, and versioning. It grows from today's docs/architecture.md, is updated in every milestone that touches the protocol, and is published with the tester guide in M13 | M9, M13 |
| P2 | Capabilities: `hello` and `welcome` list what each side supports (for example `metrics`, `layout`, `status`, `haptics:snap`). New messages stay additive, because unknown types are already ignored. The version number only changes for a breaking change. A host never sends a controller a message it hasn't listed | M9 |
| P3 | Game host interface: one pure-Dart interface in packages/connection that every game and TV screen uses for players joining and leaving (with number, colour and nickname), each player's gamepad state, haptics, layouts, the status panel and latency. Our games use nothing else, so the interface is the template for future engine kits | M9 (Arena), M10 (Puzzle) |
| P4 | Standard gamepad mapping: every input mode maps to one Xbox-style gamepad state (A, B, X, Y, LB, RB, Select, Start, D-pad, two sticks), plus extras such as raw tilt. Gyro maps to the left stick, and D-pad mode's buttons map to the same names. Documented in the spec, so a bridge or engine kit can present the phone as a normal gamepad | M9 |
| P5 | Game-defined controls: a `layout` message lets the game set, for each player, the modes allowed (with the default), the buttons used, a short label for each (for example A "Pick up", X "Rotate ⟲"), and the buttons hidden. The phone shows the labels and dims or hides unused buttons. The player still chooses among the allowed modes | M10 |
| P6 | Phone status panel: a `status` message shows a small panel on the phone with a short text, one simple shape with a colour and angle, and a progress bar. It is limited in size and sent at most 10 times a second. In the puzzle it shows the held piece and the time left | M10 |
| P7 | Conformance check: `sim_controller --check` runs the spec's required exchanges (pairing, heartbeats, input, haptics, capabilities, layout and status) against any host and prints pass or fail, so a future engine kit can test itself | M13 |

**Keeping the host independent of the TV**

v2 builds phone hosting (M12) but no streaming to a TV. These rules keep the host from being tied to the TV, so phone hosting in v2 and the v3 framework don't need breaking changes.

| ID | Rule | Milestone |
| --- | --- | --- |
| S1 | Host anywhere: the game host interface (P3), the server and the games run unchanged on a phone. Nothing in them assumes a TV, a remote or a particular screen. M12 proves it | M9 onward, M12 |
| S2 | Local players: the host interface accepts players whose input comes from the same device, not the network. In M9 this is a keyboard player on the Windows build, which also helps testing. In M12 it's the host phone's own player | M9, M12 |
| S3 | Device roles: `hello` carries a `role`. v2 uses `controller` (a controller that also shows the game lists the `view` capability), and `display` is reserved for a v3 receiver. A role is separate from who connects to whom: the spec lets a display be the side that connects out, because most smart TV apps can't accept incoming connections. The spec keeps the message channel separate from any future video and audio channel | M9 |
| S4 | Render to a given size: games draw into the box they are given, with 16:9 as the reference, and never read the device's screen size. A future host can then draw the game off-screen at the stream's resolution | M10 |
| S5 | Sound through the host: games play sounds by event name through the host interface, not directly through the audio package. A future host can then stream the audio, or tell the receiver to play the event from its own copy of the sound | M10 |
| S6 | Host-side data: analytics, best times and playtest settings belong to whichever device hosts, and each session summary records the host type (Android TV, Windows, phone) | M9 |
| S7 | Latency in stages: delay is recorded as named stages (input sent, input received by the host, frame drawn with that input), not as one number. Phone hosting adds "snapshot received" and "frame drawn on the joined phone". Streaming can add encode, network, decode and display stages later, and the results stay comparable | M9, M12 |
| S8 | Game state as snapshots: every game keeps its rules separate from its drawing, and draws only from a state snapshot that can be sent over the network. Snapshots are compact (proposed: under 2 KB for a 4-player puzzle) and versioned per game. Sound and haptic events travel with them | M10 (Puzzle and Arena) |
| S9 | Controls as a layer: the controller screen can sit on top of any view with adjustable opacity, instead of assuming it owns the whole screen | M12 |

**How v3 will choose**

The custom stream framework is the preferred direction. The v2 results still decide its shape and what comes alongside it:

- **The stream framework** goes ahead if the playtests show people enjoy the native controller (good ratings, low frustration signals). It starts with a latency prototype, because the delay decides whether fast games work over a stream.
- **Engine kits** are the alternative if other developers would rather keep their own engine, or if streaming delay is too high for the games people want.
- **A PC bridge** comes first if testers mostly ask to use the controller with games they already own.
- **A browser controller** comes in if installing the app is the main thing stopping casual guests from joining.

**Other notes for v3**

Ideas kept for later, outside v2's scope:

- **Google Play's Teacher Approved program.** Experts rate apps for kids, and approved apps get a badge and can be featured in Play's Kids tab. Not joined in v2 (decided Oct 30, 2026): closed testing apps aren't shown in the Kids tab, and the app should be judged once Shape Race and the extras are in, not as a controller with test screens. Opt in from Play Console's Target audience section when planning a public release. The app already targets ages 6 and up under the Families policy.

## Non-functional requirements

v1's requirements still apply. These are added or changed.

| Area | Requirement |
| --- | --- |
| Latency | Still under about 50 ms. Metrics add no more than 1 ms to the median input delay |
| Game performance | The puzzle game runs at 60 frames per second on the test TV with 4 players and all effects on. On both test phones it runs at 60 frames per second while hosting 4 players, and while showing the game as a joined phone |
| Phone-hosted delay | On a joined phone, the delay from a touch to the frame that shows it stays under about 50 ms on home Wi-Fi (measured with the S7 stages). Snapshots are sent about 30 times a second (proposed), and joined phones smooth between them |
| Host phone battery and heat | A 15-minute, 4-player session on the host phone finishes without the phone throttling for heat, and its battery drop is recorded in the session summary |
| Kid usability | In a playtest, an 8-year-old finishes an Easy puzzle within 2 minutes after one practice round, in at least one input mode |
| Privacy | Anonymous, opt-in, no advertising IDs, data limited to gameplay, privacy policy published. Meets Google Play's Families policy, because the apps target ages 6 and up |
| Protocol | Metrics batches, ratings, nicknames, layouts, the status panel and the new haptic events are additive messages, announced through capabilities (P2), so slightly older and newer builds still work together. A breaking change raises the version number, which is rejected with a clear "update the app" message, and testers update through the stores |
| Engine independence | packages/protocol and packages/connection stay pure Dart with no Flutter dependency, and games reach the connection only through the game host interface (P3) |
| Host independence | Games and the host interface make no TV-specific assumptions, so a phone can host (S1 to S9) |
| Install | A tester can install every app from the stores or the Windows download without developer tools, USB cables or sideloading apps |
| Store compliance | Builds meet each store's current target-API and SDK rules, and listings include the privacy policy and data disclosures |
| Compatibility | Controller: Android 12 (API 31) and iOS and iPadOS 26 minimum, on phones, tablets and foldables. TV app: Android TV 12 (API 31), unchanged. This replaces v1's "current version minus one" rule for the controller, to reach older tablets and phones |

## Architecture changes

The architecture stays as it is: two Flutter apps, a shared protocol, a WebSocket over the local network. v2 adds two packages, a game-facing interface, phone hosting and one internet connection, used only for the analytics upload.

```
 TV or PC hosts (as today)               Phone hosts (M12)
 ┌───────────┐                           ┌─────────────────────────┐
 │ TV or PC  │ game, host, stats         │ Host phone              │ game, host, stats,
 └─────▲─────┘                           │ + own player (S2)       │ draws the game
       │ input ↑  haptics, layout ↓      └─────▲───────────────────┘
 ┌─────┴─────┐                                 │ input ↑  snapshots, haptics ↓
 │  Phones   │ controls only           ┌───────┴─────────────────┐
 └───────────┘                         │ Joined phones           │ draw the game from
                                       │                         │ snapshots, controls on top
                                       └─────────────────────────┘
```

- **packages/puzzle\_game:** puzzle rules (tolerance with symmetry, snapping, big-piece carrying, scoring and ties), the puzzle data format with the 9 puzzles, and the game screen. It reuses the arena's movement code, moved to a shared place.
- **packages/metrics:** metric models, counters, aggregation and the session summary format, shared by the phone and the TV, with unit tests. It also contains the report command-line tool.
- **packages/protocol:** capabilities in `hello` and `welcome`, `role`, metrics batch, player profile (nickname, install ID), new haptic event names, rating, `layout`, `status` and `snapshot` messages. Written up in docs/protocol.md (P1).
- **packages/connection:** the game host interface (P3) and the standard gamepad mapping (P4). Games and TV screens use only this interface. The simulated controller gains `--check` (P7).
- **TV app:** game picker, join and results screens, playtest settings, Stats screen, consent, and the uploader.
- **Controller app:** stick layout rebalance and size setting, touch metrics, rating prompt, nickname, demo screen. From M12 it also includes the host server, the game packages and their assets, the game view and the overlay controls, so it can host or show a game. iOS needs its Bonjour declaration to cover advertising as well as browsing, and the app grows by the size of the game assets.
- **CI and release:** Codemagic signs the iOS build and uploads it to TestFlight on tags. Android AABs for the phone and TV, and the Windows zip, are built on tags (on Windows or in GitHub Actions) and uploaded to Play and to GitHub Releases. Play uploads are manual at first and automated once stable (proposed).

## Milestone roadmap

Numbering continues from v1, so tags stay unique (m7 and later). Each milestone ends with builds, a gate, and the developer's device test before the next one starts. From M8 on, each milestone's builds go out through the store testing tracks.

| Milestone | What it delivers | Why in this order |
| --- | --- | --- |
| M7 | Bigger stick-mode buttons, tablets, Android 12, and v1's Android phone tests | A quick fix testers will notice. Layout code is being reworked anyway, so tablets come with it, and it closes v1 on the second phone platform |
| M8 | Store testing pipeline | Accounts and reviews take time, and every later milestone ships through it |
| M9 | Analytics and platform groundwork | Collection is in place before testers play the new game, so their first sessions count. The protocol changes anyway, so the spec, capabilities and host interface come with it |
| M10 | Puzzle game, 1 player, with game-defined controls | Proves the core feel of carrying, rotating and dropping before adding players, and is the first game to label the phone's buttons |
| M11 | Puzzle game, 2 to 4 players | Adds sides, teams, big pieces and win rules on top of a proven core |
| M12 | Phone-hosted play | Lets testers without a TV or PC play, in time for the outside playtest, once the game rules are settled |
| M13 | Fun, content and the first outside playtest | Adds the extras, all 9 puzzles and tuning, and puts it in testers' hands |

The Apple and Google account sign-ups should start during M7, because verification can take several days.

## Milestone 7: Bigger buttons, tablets and Android catch-up

Milestone 7 makes the stick-mode face buttons easy to hit, makes the controller work well on tablets and on Android 12 and later, and finishes v1's pending tests on the Android phone.

**Deployable builds**

- Controller: rebalanced stick layout, the button size setting, tablet layouts and Android 12 support. Installed on the Android phone and tablet (local APK) and the iPhone and iPad (iLoader, for the last time).
- TV app: unchanged.

**Scope**

- Stick layout rebalance (C14), larger touch areas (C15) and button size setting (C16).
- Controls sized by physical size (C31), orientation and window rules (C32), and feedback without haptics (C33).
- Android minimum lowered to Android 12, with the emulator check (C30).
- Layout unit tests: no overlaps at every button size, on the screen sizes of both test phones, a small 16:9 phone, both test tablets, an unfolded foldable, and a half-screen split window.
- Run every pending v1 Android phone test (M0 to M6 checklists) and fix what fails.
- Start the Apple Developer Program enrollment and the Google Play developer account sign-up.

**Acceptance tests**

- [X] In stick mode, A, B, X and Y are clearly larger, about 75% of their D-pad-mode size, and nothing overlaps on either phone. (iPhone; Android phone pending)
- [X] The button size setting changes the size live, stays within its range without overlaps, and is saved between launches.
- [X] A press just outside a button's drawn edge still registers, and never triggers a neighbouring control.
- [X] Both sticks, the D-pad, LB, RB, Select and Start still work with two thumbs at once.
- [ ] Every v1 checklist item marked "Android phone pending" passes on the Android phone. (Pending: Android testing is on hold.)
- [X] On the iPad and the Android tablet, the controls are thumb-sized and within reach of both thumbs while holding the tablet, in all three modes. (iPad; Android tablet pending)
- [X] The controller stays in landscape on both tablets with rotation lock off, and a resized or split-screen window still works or shows "Make the window bigger". (iPad; Android tablet pending)
- [X] On the iPad, presses flash and the optional click sound plays, and the app runs without errors with no haptics hardware.
- [X] On the Android 12 emulator, the controller installs, pairs with the TV app and sends input.
- [X] Both store accounts are applied for. (Both approved.)

## Milestone 8: Store testing pipeline

Milestone 8 lets anyone install the apps from a link: Google Play testing for both Android apps, TestFlight for the iPhone, and a download for Windows.

**Deployable builds**

- Controller: on Google Play closed testing and TestFlight (internal group first, then an external group with a public link).
- TV app: on Google Play's Android TV closed testing track, and as a Windows zip on GitHub Releases.

**Scope**

- Rename both apps and change their IDs (see Names and IDs) before the first Play upload: Android application IDs and namespaces, the iOS bundle ID, display names, the Windows executable and window title, and the docs. The service name used for discovery (`_gamectl._tcp`) stays, because testers never see it.
- Release signing: a Play upload key with Play App Signing, and App Store Connect API keys in Codemagic. Secrets stay out of the repo.
- Codemagic signs the iOS build and uploads it to TestFlight on tags. The Beta App Review notes explain that the controller needs a TV or Windows host, link the Windows download and point to the demo screen (C23).
- Android AABs for the phone and TV, uploaded to the closed testing tracks, with testers joining through a Google Group link.
- Windows release zip on GitHub Releases for each tag, with SmartScreen and firewall steps in the guide.
- Store listings: short descriptions, icons, screenshots, the TV banner, Data safety and App privacy forms (no data collected yet), and export compliance (standard encryption only).
- Privacy policy page (first version) and a one-page tester guide, both published on GitHub Pages from this repository: how to join, install, connect to the same Wi-Fi, pair and report problems.
- In-app version shown in Diagnostics and on the TV home screen, so testers can say which build they have.

**Acceptance tests**

- [ ] Someone other than the developer follows the tester guide and installs the controller from Google Play on an Android phone and from TestFlight on an iPhone, without a cable or sideloading tool.
- [ ] The same store links install the controller on the Android tablet and the iPad.
- [ ] The installed apps show as Thumb Party and Thumb Party TV with the new IDs, and a phone pairs with the TV app again after the switch from the old apps.
- [ ] The TV app installs from the Play Store on the Android TV, signed in with a tester account, and appears in the launcher.
- [ ] The Windows zip from GitHub Releases runs after the SmartScreen and firewall steps in the guide.
- [ ] Phones installed from the stores pair with the store-installed TV app and the Windows build, and all v1 features work.
- [ ] Pushing a tag produces the TestFlight build, the AABs and the Windows zip, and installed apps update to it.
- [ ] The demo screen works with no host.

## Milestone 9: Analytics and platform groundwork

Milestone 9 records how each control type is used and how it performs, shows it on the TV, and, with consent, collects it from testers' homes. It also writes the protocol down and puts every game behind one engine-independent interface.

**Deployable builds**

- Controller: touch metrics, the rating prompt and a stats note in settings.
- TV app: collection, Stats screen, export, consent prompt and opt-in upload. The arena game is instrumented.

**Scope**

- packages/metrics with the models, counters and session summary (C17, T17).
- Protocol additions: capabilities (P2), metrics batches and the rating message (C18).
- Game host interface (P3) and standard gamepad mapping (P4) in packages/connection, with the arena game and the TV's test screens moved onto it.
- First version of docs/protocol.md (P1).
- Streaming-ready rules for this milestone: local players with a keyboard player on Windows (S2), `role` in `hello` (S3), host-side data with the host type (S6), latency recorded in stages (S7).
- Phone touch metrics in all three modes: empty taps, near misses, slide-offs, rapid repeated taps, press counts and durations, stick and tilt metrics.
- TV metrics: latency (median, 95th percentile, max), connection health, arena game events.
- Rating prompt after arena rounds (C19).
- Stats screen and export (T18).
- Consent prompt, setting, uploader and offline queue (T19). Cloud store set up with create-only rules.
- Families policy check before release (the apps target ages 6 and up): what is collected, the Data safety form, App Privacy, and the privacy policy updated to describe the opt-in statistics.
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
- [ ] The arena game and the TV's test screens work as before, now through the game host interface. packages/protocol and packages/connection still have no Flutter dependency.
- [ ] The M8 store build of the controller still works with the M9 TV app, and the reverse, thanks to capabilities.
- [ ] docs/protocol.md describes every message the apps send. A reviewer can check each field against the code.
- [ ] On the Windows build, a keyboard player and a phone play the arena game together.
- [ ] The latency screen and the session summary show the delay broken into stages.

## Milestone 10: Puzzle game, 1 player

Milestone 10 builds the core of the puzzle game for one player, so carrying, rotating and dropping can be tuned before more players are added. It is also the first game to tell the phone what its buttons do.

**Deployable builds**

- Controller: the new haptic patterns (snap, wrong, drop-ready) with their intensity settings, and game-defined labels and the status panel.
- TV app: game picker, single-player puzzle with 3 Easy puzzles and 1 Medium puzzle, and the playtest settings screen.

**Scope**

- packages/puzzle\_game: puzzle data format, rules (tolerances with symmetry, snap and lock, red pieces, off-board drops) and the game screen.
- Movement, pickup, continuous rotation with X and Y and the right stick, dropping, and the drop-ready highlight.
- Time limit and results for 1 player (finished time or pieces placed).
- Game picker (T11) and playtest settings screen (T16).
- New haptic events and sounds for snap, wrong and drop-ready (C21).
- `layout` and `status` messages (P5, P6), shown on the phone in every mode (C24). The puzzle labels A "Pick up" and X and Y "Rotate", hides unused buttons, and shows the held piece and the time left on the phone. The puzzle uses only the game host interface (P3).
- The puzzle draws into the box it is given (S4), plays its sounds through the host interface (S5), and keeps its rules separate from its drawing, drawing only from a state snapshot (S8). The arena game is changed to match.
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
- [ ] In the puzzle the phone shows "Pick up" on A and "Rotate" on X and Y, hides buttons the puzzle doesn't use, and shows the held piece turning as it rotates. Back on the arena game, the phone returns to its usual buttons.
- [ ] With labels and the status panel showing, no control is smaller than before in any mode.
- [ ] A widget test draws the puzzle at 1280 by 720 in a box smaller than the window and at TV size, and the layout is the same apart from scale. The puzzle's sounds still play, through the host interface.
- [ ] A unit test encodes a puzzle snapshot, decodes it and draws it, and the result matches the original. A 4-player snapshot stays under the size limit.

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
- Pause with Start: any player pauses, and the player who paused or Player 1 resumes.
- Team and side metrics: help calls, solo big-piece carries, win, loss or draw by mode.
- Unit tests for the end-of-round rules, ties and big-piece movement.
- Simulated controllers can join, so 4-player layouts can be checked with fewer phones.

**Acceptance tests**

- [ ] Two players race side by side, and the first to finish wins with their time shown.
- [ ] At time-up the side with more correct pieces wins, and a staged tie on pieces (including 0 vs 0) ends in a draw.
- [ ] Any player can pause with Start. Another player (not Player 1) can't resume someone else's pause, and Player 1 can resume any pause.
- [ ] In 2 vs 2, a big piece moves at normal speed with both teammates on it, slowly with one, and calls the other with an edge flash and a help haptic.
- [ ] In 2 vs 1, the solo player carries big pieces at full speed.
- [ ] Rematch keeps the teams, and Change teams goes back to the join screen.
- [ ] Four controllers (phones or simulated) play a full match without lag, stuck input or disconnects.

## Milestone 12: Phone-hosted play

Milestone 12 lets a group play with only their phones. One phone hosts, the others join it, and every phone shows the game with its controls on top.

**Deployable builds**

- Controller (Google Play and TestFlight): Host a game, join a phone host, the game view, overlay controls with the opacity setting, and stats on the host phone.
- TV app: unchanged, apart from fixes. Phones can still join a TV or PC as before.

**Scope**

- Host a game (C25): "Host a game" on the connect screen, the game picker, difficulty choice, pairing code and join screen on the host phone, with the host phone's owner as a local player (S2). The phone advertises on the network (Android NSD and Bonjour, with the iOS Bonjour declaration updated for advertising).
- Join a phone host (C26): phone hosts listed in discovery next to TVs and PCs, labelled as phones.
- Snapshot sync (C27, S8): the host sends snapshots about 30 times a second (proposed), and joined phones draw them with the same game code, smoothing between snapshots. Sounds and haptics play on each player's own phone.
- Overlay controls (C28, S9): all three input modes over the game view, with the opacity setting and game-defined controls.
- Phone view of the puzzle: each phone zooms to its own side, a top strip shows the clock and the other side's progress, the tray runs along the top edge, and pieces stay at least about 9 mm across (see Puzzle game design). Tablets show the full split screen.
- Show on this device (C34): a host option for a shared screen with no controls on top, mainly for tablets.
- The arena game on phones: the whole field on every phone, with the same overlay controls.
- Host-side data on the host phone (C29): consent prompt, stats, best times, playtest settings.
- Host leaves or drops: everyone sees "Waiting for host", and the round pauses for up to 30 seconds for the host to come back before it ends. A joined phone that drops can rejoin, as with a TV.
- Latency stages for joined phones (S7) and the host phone's temperature and battery in the session summary.
- Tester guide updated with a "No TV? Host on a phone" section.

**Acceptance tests**

- [ ] A solo puzzle can be played on one phone, both Android and iPhone, in all three input modes, and the opacity setting changes the controls live and is saved.
- [ ] Four devices (the two phones and the two tablets) play a 2 vs 2 puzzle hosted on a phone. Every phone shows its own side smoothly, with the other side's progress in the top strip, and the tablets show the full split screen.
- [ ] With "Show on this device" on the iPad or the Android tablet, the game fills the tablet's screen like a TV and the phones play as controllers only.
- [ ] An iPhone can host Android phones, and an Android phone can host iPhones.
- [ ] On a joined phone, the delay from touch to screen stays under about 50 ms, as shown by the latency stages.
- [ ] Locking the host phone mid-round pauses the game for everyone, and unlocking it within 30 seconds resumes it.
- [ ] A 15-minute, 4-player session finishes without the host phone throttling for heat, and the battery drop appears in the session summary.
- [ ] The session summary records the host as a phone and each player's screen (host phone or joined phone), and the report can compare them with TV play.
- [ ] Phones still join a TV and a PC as before, and nothing in M7 to M11 regresses.

## Milestone 13: Fun, content and the first outside playtest

Milestone 13 adds the touches that make the game fun, completes the puzzle set, and puts the game in outside testers' hands.

**Deployable builds**

- Controller: tick haptic, nickname setting.
- TV app: all 9 puzzles, countdown, celebration, last-15-seconds warning, hint glow, best-times board and music, released to every tester group.

**Scope**

- Countdown, celebration, last-15-seconds warning, hint glow, best-times board (T15).
- Nicknames (C20).
- The remaining puzzles, for 9 in total (3 per level), with tuned starting angles.
- Sounds and optional music, listed in CREDITS.md.
- A playtest round with outside testers, including at least one child around 8 and at least one group playing on phones only, using a short observation sheet in /docs alongside the metrics.
- Tuning: adjust defaults from the playtest and the metrics, and record the final values in docs/decisions.md.
- Final README updates, tester guide, and manual checklists for M7 to M13 in /docs/checklists.
- Protocol spec finished and published with the tester guide (P1) under CC BY 4.0, and `sim_controller --check` (P7). Code published for others to build on is under Apache 2.0, with LICENSE files added.
- A short v3 recommendation in /docs choosing the platform path, based on the playtest, the metrics and tester requests.

**Acceptance tests**

- [ ] Every puzzle on every level can be finished within 2 minutes by an adult, and the Easy ones by an 8-year-old after one practice round.
- [ ] The countdown, celebration, warning, hint glow and new-record screen all appear at the right moments.
- [ ] Best times survive restarting the TV app or the host phone's app, and show nicknames.
- [ ] At least 3 outside households install from the stores and play, at least one of them on phones only, and their sessions appear in the report.
- [ ] The report compares the three modes on frustration signals, completion time and ratings, and compares TV play with phone play. The findings are written up in /docs.
- [ ] `sim_controller --check` passes against the Android TV, Windows and phone-host builds.
- [ ] The v3 platform recommendation is written and reviewed.

## Test strategy

v1's strategy still holds: logic is tested automatically, and anything about feel, touch and devices is tested on real hardware. v2 adds rules tests, metrics tests, store installs and playtests with people.

| Area | Where it can be tested | Milestone |
| --- | --- | --- |
| Stick layout fit and overlaps at every size | Unit tests, then both phones | M7 |
| Tablet layouts, orientation and windows | Unit tests at tablet, foldable and split-window sizes, then the iPad and the Android tablet | M7 |
| Android 12 support | Android 12 emulator on Windows (start, pair, layout, input). Haptics and gyro on older versions stay untested | M7 onward |
| Store installs and updates | A tester's devices, from the store links | M8 |
| Metric counters and derived signals | Unit tests in packages/metrics | M9 |
| End-to-end metrics, upload and report | Simulated controller and real phones, against the Windows and TV builds | M9 |
| Metrics overhead | Input delay compared with v1's baseline on home Wi-Fi | M9 |
| Puzzle rules (tolerances, symmetry, locking, ties) | Unit tests in packages/puzzle\_game | M10, M11 |
| 4-player layouts and load | Phones plus simulated controllers | M11 |
| Snapshot encoding and size | Unit tests in each game package | M10 |
| Phone hosting (cross-platform joins, delay, host drops, heat and battery) | Both test phones as hosts, with the other phone and simulated controllers joining | M12 |
| Feel of rotation, carrying and haptics | Real phones, in all three modes | M10 to M13 |
| Kid usability and fun | Playtests with an observation sheet, plus the metrics | M13 |

## Risks, decisions, open questions and next steps

The largest new risk is store review and policy. Outside testing depends on two reviews, and a children's game draws extra policy attention.

| Risk | Mitigation |
| --- | --- |
| Apple's reviewer can't test a controller without a host, and rejects the build | Review notes explaining the setup, a link to the Windows build, and the "Try without a TV" demo screen. From M12 the reviewer can also play a solo game on the phone alone |
| Store accounts or reviews take longer than expected | Start the sign-ups in M7, and keep iLoader and local APKs as fallbacks for the developer |
| Google Play's Families policy applies (the app targets ages 6 and up), with stricter and sometimes slower review | No ads, no accounts, no data collected in v2 until M9, no advertising IDs, content and listing suitable for children, and a privacy policy that covers children. M9's analytics stay anonymous and opt-in with an adult's consent, use no third-party analytics SDK, and are checked against the Families policy before they ship |
| Continuous rotation is too hard for young players | Angle tolerance, the drop-ready highlight, few rotated pieces on Easy, hint glow, and tuning in the playtest |
| Bigger face buttons crowd the sticks on small phones | Size setting with a no-overlap rule, and layout tests on a small screen size |
| Older and budget Android devices feel worse (weak vibration, noisy gyros, slow touchscreens) or host poorly | The analytics record the device model and class, so their results can be separated. M12 checks hosting on the slowest device available and warns when a device is too slow to host smoothly |
| iPadOS windowing or Android's large-screen rules break the landscape layout | Declare the controller a game on Android, lock orientation per window on iPad, test resized and split windows in M7, and show "Make the window bigger" below the minimum |
| Metrics slow input down | Low-priority batches every 10 s, a size cap, and a measured overhead check in M9 |
| Testers without an Android TV or a Windows PC can't host | Phone hosting from M12, before the outside playtest. Before M12, the tester guide states the requirement |
| Gyro is hard to use while watching the screen being tilted | Measured by the analytics (phone screen versus TV), and the other two modes are always available. Gyro can be left out of a game's allowed modes on phones (P5) if the data says so |
| Pieces and touch areas are too small on a phone screen | Each phone zooms to its own side, a 9 mm minimum piece size, the tray along the top edge away from the thumbs, and the opacity setting |
| The host phone overheats or drains quickly | A 15-minute heat and battery check in M12, 30 snapshots a second instead of 60, and temperature in the session summary |
| The host phone is interrupted (a call, a lock, the app closed) | The round pauses for 30 seconds and resumes. Host takeover comes in v3. iPhone hosting only works while the app is open, which the guide explains |
| Android's planned local-network permission changes how the phone finds the TV (to verify) | Track it when raising the target SDK, and keep manual IP entry as a fallback |
| Windows SmartScreen and firewall prompts confuse testers | Step-by-step guide with screenshots. Code signing later |
| Codemagic free minutes run low with signing and TestFlight uploads | Keep path filters and tag-only uploads, and upgrade if needed |
| The host interface and spec end up shaped around our own games, so an engine kit would need breaking changes | Keep both game-neutral (no puzzle-specific messages), check the spec against two different games (Arena and Puzzle), and add the conformance check |
| A rule that ties the host to the TV slips in unnoticed, making phone hosting and the v3 framework a rewrite | Rules S1 to S9, with tests in M9 and M10. The keyboard player, the off-screen drawing test and the snapshot test exercise them on every build, before M12 depends on them |
| Game-defined labels and the status panel crowd the controls | Labels sit on or beside existing controls, the panel goes in the top bar, and a test checks control sizes |

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
- v2 stays focused, but does the cheap platform groundwork: protocol spec, capabilities, game host interface, standard gamepad mapping, game-defined controls, status panel and a conformance check. v3 picks the platform path. Bluetooth gamepad mode stays a non-goal.
- The preferred v3 direction is a framework for phone-hosted games that stream to a receiver on the TV, built for other developers to use. Receivers that can run our game code draw from snapshots, and the others get a low-latency video stream. Streaming stays out of v2 except for rules S1 to S9.
- Phone-hosted play is in v2, as M12: one phone hosts, the others join, and every phone shows the game with see-through controls on top (opacity setting). Fun, content and the outside playtest move to M13.
- The brand is Thumb Party: "Thumb Party" (`com.thumbparty.app`) for phones and tablets, "Thumb Party TV" (`com.thumbparty.tv`) for the TV and PC, renamed in M8. The puzzle game is Shape Race.
- Tablets are supported in v2: iPad and Android tablets as controllers (M7), in the store builds (M8), and as hosts or a shared screen (M12). Test devices are an Android tablet on Android 15 and an iPad on iPadOS 26.
- The controller's Android minimum drops from 16 to 12 (API 31), matching the TV app, for about four times the device reach. Android 12 is checked on an emulator, which found one Android 13 call to fix in M7.
- In v2, if the host phone leaves, the round pauses for 30 seconds and then ends. Host takeover, where another phone carries on as host from the latest snapshot, is a v3 item.
- The apps are for families with children aged 6 and up: on Google Play the target age groups are 6–8, 9–12, 13–15, 16–17 and 18+, so Google's Families policy applies (decided Oct 30, 2026, replacing "13 and over"). On the App Store the age rating is 4+ and the app stays outside the "Made for Kids" category, which would need a parental gate in front of every link out of the app.
- The privacy policy and tester guide are published on GitHub Pages from this repository, which is already public.
- The cloud store is Firebase Firestore on the free plan, owned by the same Google account as the Play developer account.
- When the protocol spec is published (M13), it goes out under CC BY 4.0, and code for others to build on goes out under Apache 2.0.
- Any player can pause with Start. The player who paused, or Player 1, can resume, so Player 1 can always override a pause.
- In Shape Race the first side to finish wins. At time-up, the side with more correct pieces wins, and equal counts (including none) are a draw.
- When the host phone leaves, the round waits 30 seconds for it to come back.
- Fire TV (Fire OS) is added once a test device is available. Apple TV, Samsung, LG, Roku and Fire TV's Vega OS are v3 receiver candidates, and a device's role is kept separate from who connects to whom (S3).

**Open questions**

- None. All questions from the October 29 review are answered above.

**Next steps**

- [x] Review this draft and answer the open questions. Done Oct 29, 2026.
- [X] Start the Apple Developer Program enrollment and the Google Play developer account. Both approved Oct 29, 2026.
- [x] Search the US trademark database (USPTO) for "Thumb Party" before the first store upload in M8. Done Oct 29, 2026: no filings for "Thumb Party", "thumbparty" or "Shape Race" (live or dead). The closest mark, THUMB PART, covers wigs. This covers US filings only, not unfiled use or other countries.
- [ ] Give Claude Code the Milestone 7 section, and move on only after its acceptance tests pass.

Sources checked on Oct 29, 2026 for the store constraints: Google's [developer verification timeline](https://www.androidauthority.com/android-sideloading-changes-timeline-3679204/), Play Console Help on [internal testing](https://support.google.com/googleplay/android-developer/answer/9845334) and [Android TV distribution](https://support.google.com/googleplay/android-developer/answer/9844679?hl=en), and Apple's [TestFlight overview](https://developer.apple.com/testflight/). For the platform direction: the [ViGEmBus repository](https://github.com/nefarius/ViGEmBus) (retired Nov 2023) and [AirConsole's Unity plugin](https://developers.airconsole.com/airconsole-unity-plugin).
