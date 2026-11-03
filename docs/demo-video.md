# Demo video plan: script and storyboard

Nov 3, 2026 · Planning only. Nothing here is filmed or built yet.

**Audience:** developers and recruiters, plus testers and families. The video shows the product working, and also that it is well engineered and measured.

**What the video shows**, in this order:
1. **PIN pairing.** A 4-digit code on the TV.
2. **Control schemes.** D-pad, Gyro and Sticks on the phone, and the phone working the whole TV app like a remote.
3. **Multiplayer.** 2 vs 2 Shape Race with big-piece team carries.
4. **Configurability.** Phone settings and the TV's Puzzle settings.
5. **Metrics (the longest section).** Input-delay measurement, per-mode touch stats, a missed-tap heatmap, the report tool, and privacy.
6. **Under the hood.** Monorepo, protocol, tests and store pipelines.

**Production rule: no humans.** Every frame, input, take, edit, caption, chart, voice and mix is made by scripts and AI agents. Nobody holds a device or a camera, and no real people appear on screen. The video says this openly (section 2). For developers and recruiters, the automated pipeline is a feature worth showing.

**Decided (Nov 3, 2026):** stats come from **scripted sessions** (source B in 3.4), always captioned as such. The headline latency is the emulator number, captioned "emulator on the same PC", with no Wi-Fi claim. m11.3 (Bubble Pop sounds and the idle-time fix) ships first. The step-by-step procedure is [demo-video-runbook.md](demo-video-runbook.md).

---

## 1. Review of the DeepSeek cut

**Source:** `C:\Users\singh\Documents\deepseek-harness\default-workspace\` (`Shape-Race-Multiplayer-Demo.mp4`, `DEMO-IDEAS.md`, `build_video.py`, `race_bot.py`, `take_gameplay2.py`, `capture\`). It runs 58.6 s at 1920×1080, 30 fps.

DeepSeek's video was already made entirely by scripts. The approach was right; how it was done caused the problems.

### Worth keeping
- **The story order:** cold open, title, pairing, modes, players join, gameplay, end card.
- **Every layer is the real app.** There are no mock-ups.
- **Bots that speak the real protocol** (`bot.mjs`).
- **The real controller app in an emulator, driven by adb.**
- **Graphics, captions and the edit built by scripts** (ffmpeg).
- **Its other concepts.** The 9:16 "three ways to play" cut and the pairing speed run are reused as cutdowns.

### Why the gameplay is slow and choppy, and what this plan changes
| Problem | Cause | Fix in this plan |
| --- | --- | --- |
| Players move in jerks, then stop | `race_bot.py` steers by screenshot: capture, find the dot, hold a direction 130 ms, capture again. Movement is stop-start. | The **demo director** reads the game's state directly every frame and steers with smooth analog input (section 3) |
| Very little happens | One piece per side in about 40 s. No rotation, wrong drop, team carry, finish or results | **Scene scripts** choreograph every beat and pace a close finish |
| Low frame rate | TV in a 1280×720 window scaled up, 30 fps. Phone from `adb screenrecord` at about 10 to 15 fps | TV full screen at 1080p60 through OBS. Phone through **scrcpy recording** or OBS window capture at 60 fps |
| Phone input looks fake | D-pad holds as single `adb input swipe` calls, and no simultaneous touches | A **touch driver** that sends continuous multi-touch paths at 60 per second, with on-screen touch markers |
| "Gyro" was an unexplained sensor sweep | Virtual sensors set in a loop | Gyro driven through the emulator's virtual sensors from the director's steering, shown next to a 3D phone graphic driven by the same values |
| Mismatched story | Join screen 2 vs 2, match 1 vs 1 | One scene script per shot, so the footage matches the storyboard |
| Out of date | Phone app 0.9.0 | Build both apps from the same commit before every capture run |
| Audio put together afterwards | No system audio | OBS records the TV app's own audio |
| Missing topics | No configurability or metrics | Sections added |

---

## 2. Format

| | Choice |
| --- | --- |
| Master cut | **16:9, 1920×1080, 60 fps, about 2:30** |
| Cutdowns | 60 s recruiter cut, 45 s sizzle, 30 s 9:16 vertical (section 7) |
| Voice | Captions carry the story. Optional **text-to-speech voice-over** from the script in section 4 |
| Music | Calm-upbeat, about 110 to 125 BPM. CC0 or licensed, or AI-generated with a licence that allows this use. Calmer under the metrics section |
| Game audio | The TV app's own sound, captured live |
| Look | Dark like the apps. White captions with player-colour accents. Charts and diagrams styled to match |

**Gameplay pacing rules:**
- Never speed up gameplay beyond 1.5×. Cut instead.
- No gameplay shot is longer than about 4 s unless something happens in it.
- Keep 60 fps from capture to export.

**Disclosure.**
- The title card or the first multiplayer caption says: **"Recorded from the real apps. Every player is a script."**
- Bots appear on the TV as "Bot 1" to "Bot 4". The visible phone is labelled "Android emulator" where it first appears.
- A voice-over made with TTS is fine. Don't present it as a person.

**No AI-generated footage of the product or of people.** Generated video of hands, phones or a family playing would show something that never happened, which is a credibility risk with developers and recruiters. AI is used for orchestration, editing decisions, review, voice and (optionally) music. Every picture of the app is a capture of the app running.

---

## 3. Production: a fully scripted pipeline

### Overview
```
showrunner (one command)
├─ build    : TV app (Windows, profile, DEMO_DIRECTOR on) + controller APK, same commit
├─ stage    : TV app full screen 1080p · emulators booted, data cleared · OBS ready
├─ per shot : reset state → start recorders → run scene script → stop → name files by shot ID
├─ data     : collect stats sessions → metrics:report → CSV → charts
├─ graphics : titles, captions, diagram, heatmap, charts (rendered from code)
├─ voice    : TTS from the script → timed to shots
├─ edit     : assemble per storyboard → mix (game audio, music, VO) → master + cutdowns
└─ QA       : frame-rate and stutter checks, contact sheets, AI review against the storyboard
```
Every stage reruns on its own. A bad take is fixed by rerunning one shot, not the whole video.

### 3.1 Who plays: the demo director (to build)
A small tool in the TV app, used only for the video and tests.

1. **Never in store builds.** It's enabled only with a compile-time flag (for example `--dart-define=DEMO_DIRECTOR=true`) in a **profile** Windows build. Debug builds are too slow for 60 fps capture.
2. **Reads state, not pixels.** It has in-process access to the running `PuzzleMatch` (and Arena state): pieces, angles, carriers, targets, help calls and the clock.
3. **Two kinds of player, one brain:**
   - **Protocol bots (unseen seats):** `ControllerClient`s paired over loopback, like `addSimulatedController`. They're named "Bot 2", "Bot 3" and "Bot 4". Input goes through the real protocol.
   - **The visible phone (seat P1):** the real controller app in an Android emulator. The director doesn't send P1's input itself. It asks the **touch driver** (3.2) to move a finger on the emulator's screen, and the app sends the input as it would on a phone. What the phone screen shows is what drives the game.
4. **Human-like motion:**
   - Analog steering with easing, curved paths and a little noise.
   - Reaction delays of 150 to 350 ms.
   - Occasional overshoot-and-correct.
   - Rotation with X and Y holds.
   - About 60 inputs a second.
5. **Scene scripts (JSON):** the puzzle, the seed, the input mode for each seat, and each seat's goals. Goals include `pick(piece)`, `place`, `wrongDrop(piece)`, `carryBigAlone`, `waitForHelp`, `joinBigCarry`, `idle(s)`, `navigate(menu path)` and `pace(targetFinishSeconds)`. Pacing keeps the race close and makes the scripted side win at the planned time.
6. **Control channel:** a local socket or file the showrunner uses to load a scene, start it, and get "scene done" and event timestamps (snap, wrong drop, help call, finish). The edit uses those timestamps to cut on actions.
7. **Separate data:** director sessions are saved to their own folder, so they never mix with the real stats.
8. **Tests:** steering and the script runner with `MemoryGameHost` and a fixed `dt`, plus one recorded test take.

### 3.2 The visible phone: emulator, touch driver, sensors
- **Devices:** the controller app on Android emulators.
  - The `m7_android12` phone AVD (already set up).
  - An **Android tablet AVD** for the tablet shot.
  - Both on the same build. Clear data before each shot (`tools/emulator.sh launch`).
- **Touch driver (to build; start with a short spike):**
  - It takes a timeline of touches (finger ID, x, y, down/move/up) and plays it at 60 Hz with **multi-touch**: left stick and a face button, or two sticks, at once.
  - Candidates, in order:
    1. The emulator's gRPC control interface (it supports multi-touch).
    2. `adb shell sendevent` to the emulator's virtual touchscreen.
    3. A scrcpy-style control connection.
  - `adb shell input swipe` is the fallback for single-finger shots only.
  - It writes a **touch log** (time, finger, x, y) used to draw clean touch markers in the edit, synced exactly.
- **Gyro:** the director's steering is sent to the emulator's virtual sensors (rotation and acceleration) through the emulator console. The app reads them as a phone's tilt would. The edit shows a **3D phone graphic** tilting with the same logged values next to the screen. Caption: "Tilt input (emulator sensors)".
- **Haptics:** the emulator can't vibrate. The TV log and the director's events record each haptic sent (`help`, `snap`, `wrong`). The edit shows a ripple-and-"bzz" graphic at those timestamps, captioned as the haptic event that was sent.
- **Pairing:** the emulator can't receive the network discovery broadcast (its network sits behind the PC's), so it pairs by **typing the address and the code** (`tools/emulator.sh connect 10.0.2.2:<port> <code>`, driven key by key at a natural pace for the camera). The script says "type the code", never "it finds your TV automatically". See 3.6 for showing discovery.
- **iPhone and iPad:** there's no iOS simulator on Windows. Options, in order:
  - **(a)** Leave iOS out of the footage. The engineering section mentions TestFlight builds.
  - **(b)** Optional extra: a Codemagic macOS job runs the iOS simulator with a scripted integration test and `xcrun simctl io booted recordVideo`. This is possible but a separate piece of work, and the simulator can't do gyro or haptics.

### 3.3 Capture
| Source | Tool | Settings |
| --- | --- | --- |
| Windows TV app | **OBS Studio driven by obs-websocket** (start and stop recording, switch scenes, file names per shot) | 1920×1080, 60 fps, CQP or CRF 16 to 18, Desktop Audio on |
| Emulator screens | **scrcpy `--record`** (60 fps, no window needed), or OBS window capture of the emulator | Phone 2400×1080 landscape; tablet at its native size |
| Terminal and editor | OBS window capture. Commands typed by a script at a natural speed | Windows Terminal at 150% zoom, dark theme; VS Code with a clean layout |
| Browser (GitHub Releases) | Microsoft Edge (full path, not on PATH), scripted scrolling, recorded with OBS window capture | Logged out if the repo is public; otherwise a cropped view |

**Sync:** every recording starts before the scene. The director emits a marker event at scene start, and the phone and TV both show the same first input. Logged timestamps line up all the files. Nothing needs a clap or a person.

### 3.4 Stats data
The stats shots need sessions with real touch behaviour. There are two possible sources; this is an open decision (section 8).

| Source | What it is | Use in the video |
| --- | --- | --- |
| **A. Real sessions from normal device testing** (recommended) | Sessions the owner's phones already record during milestone device tests, exported from the TV | Real human data. The video is still made with no humans; only the data came from earlier play. Caption: "from N real test sessions, M devices, <dates>" |
| B. Scripted sessions | Many director plus emulator sessions, with a "thumb imprecision" model so taps sometimes miss | Shows the pipeline working. Must be captioned **"scripted test sessions"**. Never present it as player behaviour |

Either way:
- **Fix idle-time counting first** (an open item). In the Oct 31 export, Sticks shows 206.9 minutes at 0.2 presses a minute because the app sat open.
- Make charts only from `metrics:report --csv` and the session JSON.
- **Latency:** the emulator talks to the TV over the same PC, so its delay is not a Wi-Fi number. The Latency screen shot is captioned "emulator on the same PC". The headline delay figure comes from real device sessions (source A, currently about 6 ms on home Wi-Fi), with its source shown. Without source A, show only the emulator number with its caption.

### 3.5 Graphics, voice and music
- **Motion graphics from code:** Motion Canvas (MIT) or Remotion (free for individuals and small companies; check its licence). Titles, lower-thirds, the latency diagram, the heatmap and charts are rendered from data and the touch and sensor logs. No hand animation.
- **Device frames:** plain rounded rectangles. No Apple or Google product renders.
- **Voice-over:** TTS from section 4, one file per line, timed to its shots. Pick a calm, clear voice.
- **Music:** a CC0 track, or generated music with a licence that allows this use. Record the source in a credits file next to the video.

### 3.6 Optional: a real Android phone with no human
Plugging a real Android phone in by USB (or adb over Wi-Fi) allows:
- discovery on screen ("the TV appears by itself"),
- a real Wi-Fi delay,
- 60 fps scrcpy capture.

The touch driver uses scrcpy's control connection, because `sendevent` usually isn't allowed on real phones. Gyro still can't be scripted on a real phone, so gyro stays on the emulator. This is a one-time setup, not a person playing.

### 3.7 Quality checks (automatic)
For every captured shot:
- **Frame rate:** ffprobe confirms 60 fps.
- **Stutter:** a duplicate-frame scan counts repeated frames in gameplay. Any run of 3 or more repeats fails the take, and the showrunner retakes it.
- **Story:** the director's event log must contain the events the storyboard needs for that shot (for example shot 25 needs `help` then `joinBigCarry` then `snap`).
- **Picture:** contact sheets (one frame every 0.5 s) for each shot.
- **AI review:** a model compares each contact sheet with the storyboard row and flags mismatches, unreadable text, overlays covering scores, wrong player counts and debug UI showing.
- **Final cut:** every caption number matches its data source (the report, the Latency screen, the test count). The edit agent lists each number and where it came from.

### Footage list (all scripted)
| ID | What | How |
| --- | --- | --- |
| **P1** | TV home: code, "No controllers yet" | OBS |
| **P2** | Emulator: Connect screen, address and code typed key by key, connected, P1 badge | scrcpy and the touch driver |
| **P3** | TV list: Player 1 (emulator), then Bots 2 to 4 join with colours and ping | OBS and director |
| **P4** | Tablet emulator pairing | scrcpy |
| **M1–M3** | Arena with the emulator as the player: D-pad, Gyro (virtual sensors) and Sticks (two-finger multi-touch) | OBS, scrcpy, director and touch driver |
| **M4** | Tablet emulator in Sticks mode, controls at the corners | scrcpy |
| **R1** | Emulator works the TV menus: home, then Play, then Shape Race, then Rocket. Buttons "OK" and "Back" | OBS, scrcpy and director `navigate` |
| **R2** | Game starts, and the labels change to "Pick up", "Rotate ⟲" and "Rotate ⟳" | scrcpy |
| **G1** | Join screen: P1 goes Left, the bots join, one switches sides, 2 vs 2, Start | `join.json` |
| **G2** | 2 vs 2 race, several seeds and takes: pickups, rotations, snaps, a wrong drop | `race.json` |
| **G3** | Big piece: Bot 2 carries it alone (slow, edge flash), a help haptic to P1, P1 joins, faster, snap | `bigpiece.json` |
| **G4** | Pause menu (Start): Resume and Quit | `pause.json` |
| **G5** | Left side finishes first, then the results, then Rematch | `race.json` |
| **C1–C4** | Phone Settings (button size live, gyro and stick settings, Floating sticks, haptic Try). TV Puzzle settings from the phone, then Reset to defaults | Touch driver and director `navigate` |
| **X1** | Rating prompt: a face and a tag tapped | Touch driver |
| **X2** | TV Latency screen during an emulator session | OBS |
| **X3** | TV Stats screen loaded with the chosen dataset (3.4), by mode, then Export | OBS. Copy the dataset into the profile build's sessions folder first |
| **X4** | Consent prompt "Share anonymous gameplay stats?" | OBS, with a fresh preferences file |
| **X5** | Emulator Diagnostics: ping, delay, reconnects, CPU | scrcpy |
| **X6** | Terminal: `dart run metrics:report <dataset>` printing, then `--csv` | OBS and a typing script |
| **X7** | VS Code: a session JSON scrolling (`empty` grid, `near` by button, p95, settings) | OBS and scripted scrolling |
| **D1** | Terminal: `tools/check.sh`, all passing | OBS |
| **D2** | VS Code: monorepo tree, `docs/protocol.md`, `latency.dart` | OBS |
| **D3** | GitHub Release for a tag, with the Play, TestFlight and Windows builds | Edge and OBS window capture |
| **D4** | The pipeline itself: the showrunner log scrolling, and a scene JSON next to the take it produced | OBS (for the "made by scripts" beat) |

---

## 4. Script (about 2:30)

| Time | Section | On-screen caption | Optional TTS voice-over |
| --- | --- | --- | --- |
| 0:00 | Cold open | *(game sound only)* | |
| 0:06 | Title | **Thumb Party.** Your phone is the controller. Small line: *Recorded from the real apps. Every player is a script.* | "This is Thumb Party. The phone is the controller." |
| 0:10 | Pairing | **Type the code. You're in.** | "Open the app, type the 4-digit code from the TV, and you're in." |
| 0:18 | Pairing | **No accounts. No cables. Up to 4 players.** | "No accounts and no cables. Up to four players join the same way." |
| 0:28 | Controls | **D-pad** for precise moves | "Pick how you play: a D-pad…" |
| 0:33 | Controls | **Gyro.** Tilt to steer. Small: *emulator sensors* | "…tilt to steer…" |
| 0:38 | Controls | **Sticks.** Two thumbs, full analog. | "…or twin analog sticks." |
| 0:43 | Controls | **Phones and tablets. Android and iPhone.** | "Phones and tablets, on Android and iPhone." |
| 0:47 | Controls | **Your phone is the remote too.** | "The phone runs the whole TV app." |
| 0:52 | Controls | **Each game labels your buttons.** | "And each game puts its own labels on the buttons." |
| 0:56 | Multiplayer | **2 vs 2.** One emulated phone and three bots, all on the real protocol. | "Here, one emulated phone and three bots play over the same protocol a real phone uses." |
| 1:00 | Multiplayer | **Shape Race.** Carry, rotate, snap. | "Race the other team to finish the picture." |
| 1:08 | Multiplayer | **Big pieces need a teammate.** | "Big pieces need two players. Carry one alone, and your teammate's phone buzzes for help." |
| 1:18 | Multiplayer | **First to finish wins.** | |
| 1:24 | Configurable | **Tune the controls.** Button size, sensitivity, dead zones, haptics. | "Every control can be tuned…" |
| 1:31 | Configurable | **Tune the game.** Every playtest value, from the phone. | "…and so can every game setting." |
| 1:38 | Metrics | **Measured, not guessed.** | "Everything is measured." |
| 1:41 | Metrics | **Input delay without synced clocks.** NTP-style offset from heartbeats. | "Phone and TV clocks aren't synced, so the TV works out the offset from its heartbeats, like NTP, and measures each input's one-way delay." |
| 1:47 | Metrics | **Median _N_ ms. Target: under 50 ms.** Small: *emulator on the same PC, scripted sessions* | "In these test runs that is a few milliseconds, well under the 50 millisecond target." |
| 1:51 | Metrics | **The phone counts what only it can see.** Missed taps, near misses, slide-offs. | "The phone records taps that miss, near misses and thumbs sliding off a button." |
| 1:56 | Metrics | **Where thumbs miss.** Small: *source* | "This is where taps missed, per mode." |
| 2:00 | Metrics | **Every mode compared.** | "The report compares modes and devices side by side." |
| 2:06 | Metrics | **Anonymous. Opt-in. Counts only.** | "It's anonymous and opt-in, and only counts leave the phone." |
| 2:12 | Engineering | **Flutter monorepo · versioned protocol · _N_ tests** | "One Flutter codebase, a written protocol…" |
| 2:17 | Engineering | **Ships to Google Play, TestFlight and Windows from one tag.** | "…and every tag builds for Google Play, TestFlight and Windows." |
| 2:20 | Engineering | **This video: captured, played and edited by scripts.** | "Even this video was played, recorded and edited by scripts." |
| 2:24 | Name card | **Built by Manveer Wasson.** | "Built by Manveer Wasson." |
| 2:27 | End card | **Thumb Party.** _[links]_ | |

**Claims to keep accurate:**
- Don't show or mention phone-only hosting (M12), countdowns, celebrations, best times, nicknames or music (M13).
- Hosts are **Android TV and Windows PCs**. Controllers need **Android 12+** or **iOS 26+**.
- "Android and iPhone" is fine as a fact (TestFlight builds exist) even if iOS isn't in the footage.
- Don't say the app finds the TV by itself unless option 3.6 is used on camera.
- Numbers come from the screen, data and repo on capture day, each with a source. On Nov 3, 2026: about 6 ms measured on home Wi-Fi, 491 tests, 7 test suites, 22 release tags.
- Stats data is labelled real or scripted (3.4). Bots and the emulator are disclosed.

---

## 5. Storyboard

Layouts:
- **FULL:** TV capture fills the frame.
- **SPLIT:** TV left about 65%, device frame right about 35%.
- **PIP:** full frame with an inset.
- **QUAD:** four tiles.
- **GFX:** a code-rendered graphic or chart.
- **TERM:** terminal or editor capture.

"Touch markers" are soft circles drawn from the touch driver's log, in the player colour.

| # | Time | Dur | Layout | Visual | Caption | Audio | Footage | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | 0:00 | 1.5 s | FULL (150% zoom) | A piece rotating into place, mid-motion | | Game sound in, music starts | G2 | Start mid-action |
| 2 | 0:01.5 | 2.0 s | FULL | Two players on the big piece, glide, **snap** | | Snap | G3 | |
| 3 | 0:03.5 | 1.0 s | FULL (zoom) | Other side: a wrong drop turns red | | Wrong | G2 | |
| 4 | 0:04.5 | 1.5 s | SPLIT | The phone's two-finger touch markers sweeping, and the TV dot moving with them | | | G2 and scrcpy | Shows that the phone drives the game |
| 5 | 0:06 | 4.0 s | Title | Logo over blurred gameplay, with the disclosure line | Title | Music hit | | |
| 6 | 0:10 | 3.0 s | FULL | TV home: a big code, "No controllers yet," slow push in | **Type the code. You're in.** | | P1 | |
| 7 | 0:13 | 3.0 s | SPLIT | Emulator: the address and code typed key by key (touch markers on keys). TV: the code | | Key clicks | P2 and P1 | Natural typing pace from the driver |
| 8 | 0:16 | 4.5 s | SPLIT | TV: "Player 1" with blue badge and ping. Phone: controller screen with P1 badge | **No accounts. No cables. Up to 4 players.** | Chime | P3 and P2 | |
| 9 | 0:20.5 | 4.0 s | QUAD | Phone emulator, tablet emulator, and Bot 3 and Bot 4 entries appearing on the TV list | | Chimes | P2, P4 and P3 | |
| 10 | 0:24.5 | 3.5 s | FULL | TV list: Player 1 and Bots 2 to 4, colours and live ping | | | P3 | |
| 11 | 0:28 | 5.0 s | SPLIT | Arena, D-pad: sprite weaves and dashes. Phone with D-pad touch markers | **D-pad** | Arena sound | M1 | |
| 12 | 0:33 | 5.0 s | SPLIT and inset | Arena, Gyro: smooth steering. Phone screen shows the tilt view, with a 3D phone graphic tilting by the same sensor values | **Gyro.** Tilt to steer. | | M2 | The graphic uses the logged values |
| 13 | 0:38 | 5.0 s | SPLIT | Arena, Sticks: two touch markers, floating stick appearing under the left one | **Sticks.** | | M3 | Multi-touch visible |
| 14 | 0:43 | 4.0 s | SPLIT | Tablet emulator, Sticks: controls thumb-sized at the corners, the middle free | **Phones and tablets…** | | M4 | |
| 15 | 0:47 | 5.0 s | SPLIT | Phone works the TV: focus moves, Play, then Shape Race, then Rocket. "OK" and "Back" on the phone | **Your phone is the remote too.** | Clicks | R1 | |
| 16 | 0:52 | 4.0 s | SPLIT | Labels change to "Pick up" and "Rotate". Highlight rings | **Each game labels your buttons.** | Whoosh | R2 | |
| 17 | 0:56 | 4.0 s | FULL | Join screen: P1 goes Left. Bots join, one switches sides, 2 vs 2. Start | **2 vs 2.** One emulated phone and three bots… | Join sounds | G1 | Hold the caption 3 s |
| 18 | 1:00 | 2.5 s | FULL | Race starts | **Shape Race.** Carry, rotate, snap. | Music up | G2 | |
| 19 | 1:02.5 | 2.0 s | SPLIT (zoom) | P1 picks up the nose, rotates it (Rotate tap marker), drops it, **snap** | | Snap | G2 | Cut on the director's `snap` timestamp |
| 20 | 1:04.5 | 1.5 s | FULL | Right side snaps | | Snap | G2 | |
| 21 | 1:06 | 2.0 s | FULL (zoom) | Bot 2's wrong drop turns red, then gets fixed | | Wrong | G2 | |
| 22 | 1:08 | 3.0 s | FULL (zoom) | Bot 2 carries the big piece alone, slowly, edge flashing toward P1 | **Big pieces need a teammate.** | Help sound | G3 | |
| 23 | 1:11 | 2.0 s | SPLIT | Phone frame with ripple and "bzz" graphic, labelled "help haptic" | | Buzz sound | G3 log | At the logged time |
| 24 | 1:13 | 3.0 s | FULL (zoom) | P1 joins, the piece speeds up, drop, **snap** | | Snap and hit | G3 | |
| 25 | 1:16 | 2.0 s | FULL | Both sides on their last piece, clock ticking | | Ticks | G2 | |
| 26 | 1:18 | 3.0 s | FULL | Left side finishes, then the results: winner, time, pieces | **First to finish wins.** | Success | G5 | |
| 27 | 1:21 | 3.0 s | SPLIT | Phone A on **Rematch** | | Click | G5 | |
| 28 | 1:24 | 4.0 s | SPLIT | Button size slider dragged, then Sticks with bigger A, B, X and Y | **Tune the controls.** | Clicks | C1 | Before/after |
| 29 | 1:28 | 3.0 s | Phone | Gyro and stick settings scroll, Floating sticks toggled | | | C2 | |
| 30 | 1:31 | 3.0 s | SPLIT | TV Puzzle settings worked from the phone: Time limit changed, then Reset to defaults | **Tune the game.** | Clicks | C4 | |
| 31 | 1:34 | 4.0 s | SPLIT | Haptic **Try** with "bzz" graphic, then the rating prompt: a face and "Rotation hard" | | Tap | C3 and X1 | |
| 32 | 1:38 | 3.0 s | GFX | "Measured, not guessed." over a faint Stats screen | **Measured, not guessed.** | Music calmer | X3 | |
| 33 | 1:41 | 6.0 s | GFX | Latency diagram: TV pings at t0, phone replies with t1, reply arrives at t2. Offset = t1 − (t0+t2)/2. Then `input.ts` gives the one-way delay | **Input delay without synced clocks.** | VO | `docs/architecture.md` | Two lanes, three arrows |
| 34 | 1:47 | 4.0 s | FULL then GFX | TV Latency screen (captioned "emulator on the same PC"), then a stat card with the median from the scripted dataset and its source | **Median _N_ ms…** | | X2 and data | |
| 35 | 1:51 | 5.0 s | SPLIT | Phone: a touch marker lands just outside A. Labels: "near miss: A", "empty tap", "slide-off". Then the Stats columns highlighted | **The phone counts what only it can see.** | | X3, touch log | Demonstration only; the numbers come from the dataset |
| 36 | 1:56 | 4.0 s | GFX | **Missed-tap heatmap** over each mode's layout (from the `empty` grid counts) | **Where thumbs miss.** | | Chart | Source line |
| 37 | 2:00 | 3.0 s | TERM | `metrics:report` printing, with the frustration/min and input ms columns highlighted | **Every mode compared.** | Typing | X6 | |
| 38 | 2:03 | 3.0 s | GFX | Bars: empty, near-miss and slide-off taps per minute by mode, and ratings | | | Chart | Source line |
| 39 | 2:06 | 3.0 s | TERM | Session JSON scrolling. Callout: "counts only, under 50 KB" | **Anonymous. Opt-in. Counts only.** | | X7 | |
| 40 | 2:09 | 3.0 s | FULL | Consent prompt | | | X4 | |
| 41 | 2:12 | 2.5 s | TERM | Monorepo tree | **Flutter monorepo · versioned protocol · _N_ tests** | | D2 | |
| 42 | 2:14.5 | 2.5 s | TERM | `tools/check.sh` all passing | | | D1 | ≤3× speed is fine for terminal output |
| 43 | 2:17 | 3.0 s | FULL | GitHub Release: Play, TestFlight and Windows builds | **Ships to Google Play, TestFlight and Windows from one tag.** | | D3 | |
| 44 | 2:20 | 4.0 s | SPLIT | A scene JSON (`bigpiece.json`) next to the take it produced, then the showrunner log | **This video: captured, played and edited by scripts.** | | D4 and G3 | Engineering flex |
| 45 | 2:24 | 3.0 s | GFX | Name and role card | **Built by Manveer Wasson.** | | | |
| 46 | 2:27 | 3.0 s | End card | Logo, links, store badges | | Music out | | Check the badge terms |

---

## 6. Edit specs

- **Timeline:** 1920×1080, 60 fps. Export H.264 High, CRF 16 to 18, AAC 48 kHz 320 kbps. Overall −14 LUFS, music ducked about 6 dB under game sounds and voice.
- **Edit tool:** the edit is a script (Motion Canvas or Remotion for graphics, ffmpeg for assembly). A storyboard row becomes a data entry: shot ID, file, in/out from the director's event timestamps, layout, caption, and audio cues.
- **Captions:** bold sans (Inter or similar), lower third at about 82% height on a soft gradient, never over the clock or scores. Hold each one long enough to read twice.
- **Touch markers:** 40 to 60 px soft circles in the player colour, drawn from the touch log, plus a short fading trail for swipes. Turn off Android's own "Show touches" to avoid double markers.
- **Charts:** dark theme, player colours, one idea each, and a source line ("N real test sessions, M devices, <dates>" or "scripted test sessions").
- **Heatmap:** the `empty` grid counts over a flat drawing of each mode's layout, using the same layout functions as the app (`touchMapFor`).
- **Haptic graphic:** ripple rings and "bzz" at the logged event time, with the event's name.
- **Transitions:** hard cuts on beats, and a slide only between sections.

---

## 7. Cutdowns

**60 s recruiter cut:**
- Shots 1, 2 and 5 (6 s).
- Shots 7 and 8 (5 s).
- Shots 11 to 13 at 2.5 s each (7.5 s).
- Shots 15 and 16 (4 s).
- Shots 17 and 22 to 26 (12 s).
- Shots 33, 34, 36 and 37 (13 s).
- Shots 42 and 44 (5 s).
- Shot 45 (3 s).

**45 s sizzle:** shots 1 to 8, 11 to 13, 17, 19, 22 to 24, 26, 34, 36 and 46.

**30 s vertical (9:16):** the phone capture full height with the TV as a tile on top.
- 0 to 3 s: snap.
- 3 to 8 s: code and "You're in."
- 8 to 17 s: the three modes.
- 17 to 25 s: the big-piece help.
- 25 to 30 s: heatmap and end card.

**20 s pairing speed run:** shots 6 to 10 with a stopwatch.

---

## 8. Open decisions

1. **Stats source (3.4):** real sessions from normal device testing (recommended), or scripted sessions labelled as such.
2. **Fix idle-time counting before collecting stats?** Recommended.
3. **iOS footage:** leave it out (recommended), or add a Codemagic iOS simulator job.
4. **A real Android phone over adb (3.6)** for discovery and a real Wi-Fi delay on screen, or emulators only.
5. **When to capture:** after the m11.3 sounds at least. The look-and-sound milestone will change the visuals, but with a scripted pipeline a recapture is one command, so capturing early is cheap.
6. **Name, links and repo visibility** for the name and end cards.
7. **Voice:** captions only, or TTS voice-over.

---

## 9. Build order and prompts for future sessions

Build in this order. Each step ends with a check of the output on screen by the owner, per the milestone workflow.

1. **Touch driver spike:** prove 60 Hz two-finger input on the `m7_android12` emulator moves both sticks smoothly, and record it with scrcpy at 60 fps.
2. **Demo director:** protocol bots, then the touch-driver seat, scene scripts and the event log.
3. **Showrunner and capture:** OBS through obs-websocket, scrcpy, per-shot reset, naming and quality checks.
4. **Data and charts:** dataset, then `metrics:report --csv`, then the heatmap and bar charts.
5. **Graphics, voice and edit:** titles, diagram, markers, TTS, assembly, mix, cutdowns.

**Prompt to build the pipeline (steps 1 to 3):**
> Read `docs/demo-video.md`, sections 3.1 to 3.3 and 3.7. Start with step 1 of section 9 (the touch driver spike) and stop for my check. Then build the demo director and the showrunner as specified: off unless built with the compile-time flag, bots over the real protocol, the visible phone driven only through the touch driver, human-like analog motion, JSON scene scripts for shots G1 to G5, an event log, sessions kept out of the real stats, tests, and automatic stutter and frame-rate checks. One step at a time.

**Prompt to make the video (steps 4 and 5) once footage exists:**
> Read `docs/demo-video.md`. Footage is in `<folder>`, named by shot ID, with the director's event logs and touch logs next to each take. The stats dataset is `<folder>` (source: `<real | scripted>`). Generate the charts and graphics from code and data, the TTS voice-over from section 4, and assemble the 2:30 master per sections 5 and 6, then the cutdowns in section 7. Rules:
> - Use only captured footage of the real apps, and no AI-generated footage of the product or people.
> - Never speed up gameplay beyond 1.5×, and keep 60 fps.
> - Keep the game's own audio.
> - Every number has a named source.
> - Show the disclosure lines.
> - Add no claims beyond section 4.
>
> Run the quality checks in 3.7. Report the file and timecodes used per shot, and list any shot you couldn't fill instead of substituting something else.
