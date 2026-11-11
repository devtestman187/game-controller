# M15 G0 scan — streaming touchpoints

Read-only scan (G0, `pub: no`); the only file changed is this report. Facts are read from the code at HEAD `f3b58ef` unless marked **unsure**. Assumptions are under "Decisions".

Shorthand: `PRD` = `docs/PRD-v2.md` · `D` = `docs/decisions.md` · `N` = `docs/project-notes.md` · `P` = `docs/protocol.md` · `GH` = `packages/connection/lib/src/game_host.dart` · `SGH` = `.../server_game_host.dart` · `HC` = `.../host_connection.dart` · `HL` = `.../host_server.dart` · `GT` = `.../game_types.dart` · `VS` = `.../viewer_stats.dart` · `FV` = `packages/game_kit/lib/src/frame_view.dart` · `GS` = `.../game_session.dart` · `HS` = `.../hosting_settings.dart` · `HA` = `packages/connection/lib/src/host_address.dart` · `WSL` = `.../transport/web_socket_listener.dart` · `WSC` = `.../transport/web_socket_connector.dart` · `SS` = `packages/metrics/lib/src/session.dart` · `SP` = `.../session_player.dart` · `R` = `.../report.dart` · `LS` = `packages/party_host/lib/src/live_stats.dart` · `MAIN` = `tv_test_app/windows/runner/main.cpp` · `WW` = `.../win32_window.cpp` · `PP` = `tv_test_app/lib/src/ui/home/pairing_panel.dart` · `LAT` = `tv_test_app/lib/src/ui/latency_screen.dart` · `JV` = `controller_app/lib/src/ui/joined_view.dart` · `CS` = `.../controller_screen.dart` · `CP` = `.../controller_parts.dart` · `CL` = `.../controls_layer.dart`

## Summary

- **Nothing in the repo streams video, and nothing blocks a capture tool.** The Windows TV app is a normal GPU-drawn window (Skia, 1280×720 logical, resizable), plays sound to the default device, and its pixels are readable without focus (`tools/tv-window.ps1` uses `PrintWindow` today). There is no fullscreen, no borderless mode, no headless mode and no virtual-display code.
- **The stream source has two ceilings:** the window is 1280×720 logical (physical = ×dpi/96), and game frames are produced at most 60/s (`frameRateHz` 20–60). 1080p60 needs a bigger window (one line) or ≥150% Windows scaling; the app itself is capped at 60, which matches 1080p60.
- **A covered or minimized window is expected to stop the game advancing** (`GS:53–56`), so a streamed host needs a live, visible desktop — capture alone does not keep it drawing.
- **The controller path is LAN-shaped but not LAN-locked.** The phone finds the host by mDNS (`_gamectl._tcp`) or a typed address; the 4-digit code is only an auth secret and maps to nothing. Typed input takes `IP`, `IP:port`, `[IPv6]:port`, a bare IPv6 or a hostname; the default port is 45780, WebSocket `/ws`, plain TCP, no TLS.
- **A phone on another network reaches the host only if the socket does** (port forward, Tailscale): the server binds all interfaces dual-stack, and the host lists its VPN/Tailscale IPv4 address too. Nothing in code blocks it; the PRD makes internet play a firm non-goal (`PRD:52`), and the path is unencrypted with a 4-digit code.
- **LAN-tuned timeouts:** 1 s heartbeats, 4 s silence drops, 4 s per connect attempt, 0.25–3 s retry backoff, 5 min pairing window, mDNS multicast.
- **S7 already accepts new stage names end to end.** The metrics protocol keeps unknown stage names, the session summary takes any name up to 32 chars, and `stageSummary` works per name. So encode/network/decode/display need no schema change — but each needs a stamping seam, a definition, and rows in the report and the TV latency screen (which name three stages today).
- **The phone can already show the game under its controls.** `JoinedView` draws the host's game full-screen and the pad sits over it at a saved opacity (0.2–1.0, default 0.6). A video surface would replace one painter; the controls, cards, top bar and flows stay.
- **A thin client must display, not drive.** Phones already work every host screen like a remote (`ControllerMenus`), so once a phone is paired the TV device needs no input; before pairing the client only has to show the pairing code. Device-specific on the host screen: pairing code and name, manual addresses with interface names, the Windows firewall note, the stats consent dialog, host settings.
- **The reuse list** (Q7): off-the-shelf streaming works with a window-size change and no app code; the four stages need stamps plus report/screen rows; a cloud host needs an address path, a live desktop session and TLS/relay, none of which exist.

## 1. What the PRD and decisions already say

**Streaming is a v3 candidate, not a v2 goal.** "Streaming video, or building the streaming framework, the engine kits (Unity, Godot), the PC bridge or a browser controller. These are v3 candidates, with streaming preferred. v2 only lays the groundwork (P1 to P7, S1 to S9) and phone hosting" (`PRD:54`). "Internet play. This is still a firm non-goal. The only internet use in v2 is the opt-in analytics upload" (`PRD:52`). The preferred direction is "a framework for phone-hosted games that stream to a receiver on the TV … Receivers that can run our game code draw from snapshots, and the others get a low-latency video stream" (`PRD:863`). The platform table puts snapshots first and video as the fallback for receivers that can't run our code, "adds roughly 50–100 ms and needs native encoding on both phone platforms" (`PRD:362`). The 50 ms target stays: latency "still under about 50 ms. Metrics add no more than 1 ms to the median input delay" (`PRD:431`), and for a joined phone the touch-to-screen delay "stays under about 50 ms … (measured with the S7 stages)" (`PRD:433`, acceptance `PRD:686`). Analytics already names "frame drops on the host and on every phone showing the game, snapshot delay and gaps on joined phones" (`PRD:201`). M9 and M12 record the stages (`PRD:564`, `PRD:588`, `PRD:677`).

**Decisions** have no streaming row: the relevant ones are transport (`dart:io` WebSocket, `D:11`), port and `/ws` fallback (`D:24`), pairing code and tokens (`D:23`), mDNS via bonsoir (`D:26`), heartbeats and the 4 s drop (`D:25`), the NTP-style one-way estimate (`D:64`) and flutter_soloud (`D:53`). Project notes add that Windows draws with Skia because Impeller was slow (`N:128`) and that Python isn't installed (`N:143`).

**The rules, and whether the code meets them today:**

| Rule | Quote (PRD) | Met? Evidence |
| --- | --- | --- |
| S1 Host anywhere | "the game host interface (P3), the server and the games run unchanged on a phone. Nothing in them assumes a TV, a remote or a particular screen" (`PRD:400`) | Yes. `GameHost` is pure Dart (`GH:13–114`); the game packages import no `dart:io` and no screen APIs (grep: 0); the phone host runs the same `party_host` and `ServerGameHost` (`packages/party_host/lib/src/host_service.dart:129–145`) |
| S2 Local players | "accepts players whose input comes from the same device, not the network" (`PRD:401`) | Yes. `addLocalPlayer` (`GH:48`), `InProcessListener` (`packages/connection/lib/src/transport/in_process_listener.dart:10`), TV keyboard player (`tv_test_app/lib/src/keyboard_player.dart:11–14, 26–70`), host phone's own player (`controller_app/lib/src/host/phone_host.dart:97–148`) |
| S3 Device roles | "`hello` carries a `role` … `display` is reserved for a v3 receiver … the spec lets a display be the side that connects out … keeps the message channel separate from any future video and audio channel" (`PRD:402`) | Partly. The role exists with `controller`/`display` (`packages/protocol/lib/src/capabilities.dart:32–38`; `packages/protocol/lib/src/messages.dart:60, 80, 106, 117`), but every sender uses `controller` (`packages/connection/lib/src/host_types.dart:56`) and nothing implements `display`; there is no video channel |
| S4 Render to a size | "games draw into the box they are given, with 16:9 as the reference, and never read the device's screen size" (`PRD:403`) | Yes. The view gets the box, pad rects and px/mm, not a screen (`packages/game_kit/lib/src/game_module.dart:42–60`; `FV:302–308`); no `MediaQuery` in the game packages (grep: 0) |
| S5 Sound through the host | "games play sounds by event name through the host interface, not directly through the audio package" (`PRD:404`) | Yes. `playSound(name)` (`GH:60`); the host plays OGG/WAV through SoLoud on the default device (`packages/party_host/lib/src/sound.dart:103–105, 149`); frames carry sound names to viewers (`P:240`) |
| S6 Host-side data | "analytics, best times and playtest settings belong to whichever device hosts, and each session summary records the host type" (`PRD:405`) | Yes. `HostType` in the summary (`SS:12–20, 294`); TV writes `windows`/`android_tv` (`tv_test_app/lib/src/tv_host_setup.dart:26–29`), phone writes `phone`/`tablet` (`controller_app/lib/src/host/phone_host_setup.dart:36`); sessions are saved on the host (`LS:20–22`) |
| S7 Latency in stages | "delay is recorded as named stages … Streaming can add encode, network, decode and display stages later, and the results stay comparable" (`PRD:406`) | Plumbing yes, measurement no: four names exist (`GT:116–133`), any name is stored (Q4), but nothing measures a stream |
| S8 Game state as snapshots | "every game keeps its rules separate from its drawing, and draws only from a state snapshot … versioned per game" (`PRD:407`) | Yes. `snapshot()` (`GS:122`), version in `view_start` (`GS:35–42`; checked at `FV:174`), frames carry the snapshot JSON (`GS:285`), and both games keep a version and a size test |
| S9 Controls as a layer | "the controller screen can sit on top of any view with adjustable opacity" (`PRD:408`) | Yes. `ControlsLayer` over a child at a saved opacity (`CL:9–44`; `CP:60–73`; `controller_app/lib/src/controls_settings.dart:6–15`), used over the game in `CS:209–226` |

## 2. The Windows host as a stream source

- **Window.** `MAIN:35–37` creates it at `(10, 10)`, 1280×720, title "Thumb Party TV"; `WW:135–141` multiplies both by `dpi/96` and uses `WS_OVERLAPPEDWINDOW`; `WW:152–154` shows it with `SW_SHOWNORMAL`. Grep for `fullscreen|FullScreen|window_manager|setFullScreen|borderless` in `tv_test_app/lib` and `tv_test_app/windows`: 0 hits. It is a normal, resizable desktop window, so the game draws into whatever size it is given (S4).
- **Resolution.** The content is 1280×720 logical; the physical window is that × dpi/96 (`WW:135–140`). At 100% scaling the window is 1280×720; 1080p content needs a bigger window (one line at `MAIN:36`) or ≥150% Windows scaling. `tools/tv-window.ps1:106–116` reads the physical rect back and captures it with `PrintWindow(…, 2)`, which works while the window is covered (`:112–113`), so a capture tool can read the app's pixels without focus.
- **vsync / frame cap.** The game advances on the view's Ticker, once per drawn frame (`packages/puzzle_game/lib/src/play_view.dart:160–167`, `packages/test_game/lib/src/arena_view.dart:124`) in fixed 1/60 s steps (`GS:206–229`; `HS:41–47`), and publishes at `frameRateHz` 20–60, default 60 (`HS:6, 12–36, 50–66`; `GS:327–356`). The source ceiling is 60 game frames a second; a 60 fps capture matches it, a faster capture duplicates. Dev launches can set 20/30/60 (`tools/tv-dev.sh:72`). A gap between advances means drawing stopped: "the window was minimised or covered, the PC slept" (`GS:53–56`) — the game slows rather than catches up (`GS:58–61`).
- **Audio.** `SoLoudSoundPlayer` calls `SoLoud.init()` with no arguments (`packages/party_host/lib/src/sound.dart:149`), so it plays to the system default output; there is no device picker, no per-app routing and no audio flag. The same OGG/WAV files play on Android TV and Windows (`sound.dart:103–105`; `D:53`). A capture tool must capture that device (or a loopback), not drive it.
- **Flags.** Debug only: `START_GAME`, `SHARE_VIEW`, `FRAME_RATE_HZ` (`tv_test_app/lib/src/debug_start.dart:9–26`; `HS:4–6`); `tools/tv-dev.sh` passes `SHARE_VIEW=true`, `--hz 20|30|60`, `--game arena|shape_race` (`tools/tv-dev.sh:65–77`). No flags for port, window size, fullscreen or headless. The port is chosen at bind — 45780, else any free port (`WSL:46–66`) — and logged (`HL:136`); `tools/tv-dev.sh:38–42` scrapes that line.
- **What would stop a capture tool at 1080p60.** Nothing structural: no DRM, no exclusive fullscreen, GPU-drawn Skia window (Impeller off, `MAIN:22–27`; `N:128`), pixels readable via `PrintWindow` while covered. The real limits are the source's own: 1280×720 logical content, ≤60 produced frames/s, and the game stalls when its window is not drawn (`GS:53–56`), so the host needs a live visible desktop. If the whole screen is captured, the window frame is in the picture; there is no fullscreen mode to remove it.
- **Headless or a virtual display.** Nothing in the runner supports it: it creates and shows a normal window (`WW:138, 152–154`) and Flutter Windows needs a desktop session and a GPU-backed compositor. No virtual-display or headless code exists (grep: 0). The app itself never pauses when hidden — the TV leaves `hostAwayProvider` at `NeverAway` (`packages/party_host/lib/src/host_presence.dart:10–12`), and only the phone host installs `HostPresence` (`controller_app/lib/src/host/phone_host.dart:142–148`) — so being covered does not end a round; the drawing stall is the problem. Whether a Windows VM with no attached monitor (or an RDP-disconnected session) keeps Flutter rendering: **unsure**.

## 3. The controller path when the screen is remote

- **Discovery** is mDNS/DNS-SD: service `_gamectl._tcp` (`packages/protocol/lib/src/network.dart:6`), TXT `id`, `v` and `kind` (`network.dart:9–14`; `packages/party_host/lib/src/host_identity.dart:9–11`), advertised at `packages/party_host/lib/src/host_advertising.dart:22`, browsed with bonsoir at `controller_app/lib/src/discovery.dart:106–126, 159–199`. No broadcast, no HTTP discovery, no relay. Multicast is link-local, so discovery only works on the same link (`P:5–20`).
- **The 4-digit code maps to no address.** It is a secret the phone sends after it has already connected to a reachable address: `PairRequestMessage.code` is checked against the host's code, or a saved token is checked against the pairing book (`HC:304–337`). Codes are four digits and never repeat immediately (`packages/connection/lib/src/host_pairings.dart:216–223`); five wrong codes rotate the code (`HL:30`; `host_pairings.dart:127–134`); an unpaired connection closes after 5 minutes (`HL:29`; `HC:152–154`; `P:45`). A saved pairing lets the phone reconnect with no code (`D:23`).
- **What "type the address" accepts** (`HA:25–67`): `192.168.1.50`, `192.168.1.50:45780`, `[fe80::1]:45780`, a bare IPv6, or a hostname such as `tv.local`. A leading `ws://` or `http://` and one trailing `/` are stripped (`:30–34`); anything else — a path such as `:45780/ws`, a scheme like `wss://` — is rejected (`:59–65`). The port defaults to 45780 (`:58`) and the client always connects to `/ws` (`:132`). Hostnames only resolve where their DNS/mDNS does, so `tv.local` is same-link.
- **Ports and protocol.** One WebSocket (TCP) per controller at `ws://<address>:<port>/ws`, JSON text frames (`P:26–33`); no UDP, no TLS/wss, no HTTP API. Any other HTTP request gets a short plain-text page so a browser can check the port (`WSL:78–83`). The host binds dual-stack, all interfaces, with a free-port fallback (`WSL:46–66`).
- **Addresses the host shows:** IPv4 only, loopback and link-local dropped, Wi-Fi first, wired/hotspot next, virtual/VPN/Tailscale last, cellular dropped (`packages/party_host/lib/src/network_addresses.dart:17–31, 39–49, 71–103`); up to three with their interface names (`PP:100–114`). So a Tailscale address is shown, last, with its interface name.
- **LAN-tuned timeouts and assumptions:** 1 s heartbeats and a 4 s silence drop (`HL:27–28`; `packages/connection/lib/src/controller_client.dart:30–31`; `P:125`, `P:294`), 4 s per connect attempt and no overall deadline (`WSC:12–14, 32–58`), retry backoff 0.25/0.5/1/2/3 s (`controller_client.dart:32–37`), pairing window 5 min (`HL:29`), and a reconnect that restarts discovery every 4 attempts (`D:66`) — mDNS link-local, and copy that assumes one Wi-Fi ("on the same Wi-Fi as this phone", `packages/party_host/lib/src/text/phone_text.dart:36, 94`).
- **A phone on another network** can connect if the socket reaches the host: type the host's Tailscale or public `IP:port` (`controller_app/lib/src/ui/connect_screen.dart:141, 278, 295`), let Windows Firewall allow it (`PP:120–127`; `tv_test_app/lib/src/tv_text.dart:54–56`), and the pairing code still applies. The server already listens on every interface (`WSL:46–66`), and a 100.x Tailscale address is a global IPv4, so it is tried first (`HA:112–130`). What does not work: mDNS across networks, listing a public address in the UI (it lists only the host's IPv4 NIC addresses), and any security for the exposed port — `ws://` is unencrypted, the code is 4 digits and tokens live in host memory (`D:23`). The PRD calls internet play a firm non-goal (`PRD:52`), though no code enforces that.

## 4. Latency stages today

| Stage | Stamped where | Clock |
| --- | --- | --- |
| `sent_to_received` | Phone sends `InputStateMessage.sentAtMs` (`packages/connection/lib/src/client_input.dart:44–58`; `controller_client.dart:185`) and remembers the send (`packages/connection/lib/src/client_viewer.dart:20–22`). The host estimates the one-way delay on input arrival: `arrival − (sent − offset)` (`HC:264–273`; `packages/connection/lib/src/latency.dart:44–67`), and reports it (`SGH:30–31`) | Phone → host, across clocks: the offset is NTP-style from heartbeats, best ping of the last 20 s, error ±RTT/2 (`latency.dart:1–54`; `D:64`). Phone clock is a `Stopwatch` (`controller_client.dart:74, 274`); host clock is a `Stopwatch` from server start (`HL:87, 257`) |
| `received_to_drawn` | Input arrival on the host (`HC:264–269`, stored as `inputAtMs`; read by `GS:307–325` through `SGH:199`) to the post-frame callback of the draw that carried it (`GS:232–241`; called at `packages/puzzle_game/lib/src/play_view.dart:160–167` and `packages/test_game/lib/src/arena_view.dart:124`) | Host clock only |
| `touch_to_frame` | Phone: input send → the post-frame callback of the first frame whose `acks` cover that seq (`FV:262–266, 287–292`; `VS:127–161`) | Phone clock only |
| `frame_jitter` | Phone: frame arrival vs the fastest frame of the last 2 s (`FV:204–211`; `packages/connection/lib/src/viewer_timing.dart:17–32, 43–60`; recorded at `VS:111–125`) | Phone clock only |

No stage crosses three clocks; only `sent_to_received` crosses two, via the offset estimate. Phone and host clocks are never synchronized, only offset-estimated.

**How stages reach the session summary and the report.** The phone drains its samples into a metrics batch every ~10 s, on mode changes and at disconnect (`VS:163–185`; `packages/connection/lib/src/client_viewer.dart:30–42`; `P:217, 220`); the protocol keeps unknown stage names (`packages/protocol/lib/src/metrics.dart:100–101`) and caps 256 samples per stage (`metrics.dart:31–33`). The host fans them out through `SGH:314–320` into `reportStage` (`SGH:305–310`), which keeps 30 s windows per (player, stage) and a `stages` stream. `LS:65–73` listens once — `host.stages.listen((s) => _session?.stage(s.playerId, s.stage, s.ms, hz: host.viewRateHz))` (`LS:71`) — and `SessionCollector.stage` accepts any name up to 32 chars (`SS:143–152`), filing it under the view rate too. The summary writes per player `stages` and `stagesByHz` (`SP:53–57, 78–97, 119–124`; schema `SS:290–312`), is saved every minute and at the end (`LS:20–22, 220, 223–251`) and uploaded with consent (`LS:273`). Readers name stages individually: the CLI report reads only `sent_to_received`, `touch_to_frame` and `frame_jitter` per mode row (`R:215–217, 244–249`), and the TV latency screen reads `latency` plus `stageSummary(received_to_drawn)` (`LAT:171–210`). `stageSummary` itself works for any stage name (`SGH:230–233`).

**Where the four new stages fit with the least change.** None needs a protocol or summary change: `metrics.stages` keeps unknown names (`metrics.dart:100–101`), `stageSummary` takes any name (`SGH:230–233`), and `SessionCollector.stage` stores any name ≤32 chars (`SS:148`). What is needed is a stamp at each end and a definition:

- **encode (host side):** from the frame being handed to the encode path to the first encoded packet for it. Only the encoder can time it. The natural seam is next to the frame publish (`GS:327–356`) plus a call to `reportStage` (`SGH:305–310`); nothing outside a game calls it today (`GH:55`), so a host-side stream adapter would be a small new entry point. A capture tool that encodes must report this itself.
- **network (host + client):** one-way time for one frame, which needs the frame identified on both sides (a send timestamp in the stream's frame metadata) and a clock offset. If the client speaks our protocol, the existing ping/pong offset gives it (`latency.dart:44–54`); a video-only client needs its own. Without frame ids, the alternative is the transport's RTT/jitter, which is a different (round-trip) definition.
- **decode (client):** from the packet's arrival to a decoded frame being available for drawing.
- **display (client):** from the decoded frame to the pixel being presented — the same point the snapshot viewer stamps today (`FV:262–266`). Decode and display both live on the client's own clock, so they need no alignment with the host as long as the same clock stamps both ends of each stage; on the phone they would be extra samples in `VS:163–185`.

What a streaming client or capture tool must report, in one line each: encode = grab/present to packet-out; network = packet-out to packet-in per frame (or RTT); decode = packet-in to decoded; display = decoded to presented. Rows for the new names are needed in the report (`R:215–217` and the column set) and on the latency screen (`LAT:171–210`); both are additive. A display client with no controller record has nowhere to file samples — `stage(id, …)` drops unknown ids (`SS:146–148`) — so a stream client would need a player id (pair as a controller) or a session-level bucket.

## 5. What a thin client must show

- **Every screen is drawn by the host app** — home, pairing, join, settings, stats, the game (`tv_test_app/lib/src/ui/home/*`, `packages/party_host/lib/src/ui/*`). A thin client that shows the host's video shows all of it.
- **Nothing needs input from the TV device once a phone is paired.** `ControllerMenus` lets a phone work every host screen like a remote: D-pad or left stick moves focus, A presses, B goes back (`packages/party_host/lib/src/ui/controller_menus.dart:64–73`), and the remote's OK/gamepad A activate what has focus (`tv_test_app/lib/main.dart:62–64`). The only host-device input left is the Windows keyboard player, which a client that forwards keys can still supply (`tv_test_app/lib/src/keyboard_player.dart:26–70`); a video-only client cannot.
- **Before pairing, the client only has to display the pairing code** (and the host name the phones see): the code is generated on the host (`host_pairings.dart:216–223`) and shown by `PP:73–78`; the phone needs to read it. The consent dialog is a normal focused dialog whose buttons a phone can press (`packages/party_host/lib/src/ui/stats_screen.dart:198–225`).
- **What is device-specific on the host screen:** the pairing code and the name phones find (`PP:26–33, 73–78`), the manual addresses with interface names (`PP:100–114`), the Windows firewall note (`PP:120–127`; `tv_test_app/lib/src/tv_text.dart:54–56`), the stats consent prompt (`tv_test_app/lib/src/ui/home/first_launch_consent.dart:14–20`), and host settings (frame rate and playout buffer via `HS`; sound and volume in `packages/party_host/lib/src/sound_settings.dart`). There is no Wi-Fi name on screen; only interface names next to addresses.
- **The host's own screen is the only place the pairing code is shown**, so a client that does not show the host's picture has to relay it another way.

## 6. Phone as its own display

- **The composition already exists.** `CS:209–226` stacks the game (`JV:114–147`) behind the top bar and controls; the pad is a translucent layer over it at the saved opacity when a game shows, opaque otherwise (`CP:60–73`; `CL:9–44`; `controller_app/lib/src/controls_settings.dart:6–15`: 0.2–1.0, default 0.6). The waiting/abandoned/taken cards already sit over both (`CS:229–248`).
- **What changes is the surface, not the layout.** `FrameView` decodes snapshots and paints them through the game module (`FV:294–316`); a video path would swap that one widget/painter for a video texture, keep the same box, and leave `padRects`/`pxPerMm` as they are (`JV:126–146`). Sounds (`JV:154–161`), the top bar, the cards and the results flow stay.
- **What a video path loses or needs.** The playout/lerp (`FV:246–268`) has no meaning on video. `acks` in each frame are how `touch_to_frame` is known (`VS:127–161`); video has no acks, so that stage would need another signal or be unavailable on a video view. The stream's own decode/display stamps would go into `VS:163–185`. Nothing in `controller_app` reads a video texture today.
- **The TV only shares its picture to phones in debug** (`SHARE_VIEW`, `tv_test_app/lib/src/debug_start.dart:24–26`; `packages/party_host/lib/src/providers.dart:74–76`; `tv_test_app/lib/main.dart:34–37`), so the phone-over-game view of a TV host is a debug feature; video would be the release path.

## 7. Reuse list

**(a) Streaming with an off-the-shelf tool, no code change**

- *As is:* the app runs and draws in a capturable GPU window (Impeller off, `MAIN:22–27`), pixels readable without focus (`tools/tv-window.ps1:106–116`), no DRM or exclusive mode; produces ≤60 frames/s (`HS:50–66`); plays to the system default device (`sound.dart:149`); the phone controller keeps connecting to the same WebSocket (`P:26–33`) while the picture is streamed.
- *Small change:* window size for 1080p (`MAIN:36`, or Windows scaling ≥150%); hiding chrome/fullscreen if wanted (none exists — `WW:137–141, 152–154`); keep the screen awake while capturing (already on while a controller is connected, `packages/party_host/lib/src/keep_awake.dart:27–51`).
- *Missing:* any link between the stream and our stats; the client has no way to report; no stream advertising/discovery; a visible desktop is required or the game stalls (`GS:53–56`).

**(b) The four latency stages in our metrics**

- *As is:* arbitrary stage names end to end (`metrics.dart:100–101`; `SGH:305–310, 230–233`; `SS:143–152`; `SP:53–57, 78–97`), per-view-rate filing (`LS:71`), session save/upload (`LS:220–273`).
- *Small change:* decode/display samples in `VS:163–185` and a stamp in the video surface; encode/network stamps at the frame publish (`GS:327–356`) and on input; one host-side reporter that calls `reportStage` (`SGH:305–310`) — nothing outside a game calls it today; rows in `R:215–217` and `LAT:171–210`.
- *Missing:* any timestamp that crosses the stream (frame id + send/receive time), any clock offset for a non-protocol client, and any definition agreed for "network".

**(c) A cloud GPU host**

- *As is:* the host is an ordinary Windows app; it binds all interfaces dual-stack and falls back to a free port (`WSL:46–66`); the port and code are in the log (`HL:136`); manual addresses work (`HA:25–67`).
- *Small change:* make the public address known to the phone (the panel lists only the VM's NIC addresses, `network_addresses.dart:17–31`), open the firewall (`PP:120–127`), keep a desktop session alive for the renderer, advertise/relay the address.
- *Missing:* TLS/wss, STUN/TURN/relay or any signalling, mDNS across networks, a public address in the UI, remote control of the VM, and any notion of internet play (a firm non-goal, `PRD:52`).

## 8. Risks and unknowns

1. **The budget is tight and not defined for a stream.** Today's target is ~50 ms input-to-screen (`PRD:431–433`); the PRD itself estimates video at +50–100 ms (`PRD:362`). The latency screen's verdict against `latencyTargetMs = 50` (`LAT:11, 105–108`) would call a working stream laggy until the stages are redefined per stage.
2. **"Network" has no single definition.** On the wire it is sub-frame; our only one-way estimate is the heartbeat offset with ±RTT/2 error (`latency.dart:36–54`), and a video-only client has no heartbeat.
3. **Off-the-shelf stats are not ours.** Whether Sunshine/Moonlight exposes its encode/network/decode/render numbers in a machine-readable form (rather than only its overlay) is **unsure**; the sibling stack research covers the tool side.
4. **Capture details are outside the code:** DXGI vs PrintWindow, hardware encoder choice, pacing at 60 fps, and capturing the default audio device rather than a single app. The app only guarantees a normal window and default-device audio.
5. **A covered or minimized window stops advancing** (`GS:53–56`); whether a capture path can keep the window "drawn" (a virtual display, an off-screen position, or a capture API that forces presents) is **unsure**.
6. **Headless/VM rendering** is untested here: no attached monitor or a disconnected RDP session may stop Flutter's compositor.
7. **Security across a network** is missing: plain `ws://`, a 4-digit code (10,000 guesses, rotates after 5), tokens in host memory; an exposed port is a real risk.
8. **Video on the phone** adds a third clock and a surface that may not paint under the pad as snapshots do; the touch areas and round-card flows are tuned to a snapshot view with acks.
9. **New stage names are inert until read:** the report and latency screen name stages individually (`R:215–217`; `LAT:171–210`), so new rows must land with the stamps.
10. **A display client has no place to file stages** unless it pairs as a controller or a session-level bucket is added (`SS:146–148`).
11. **The TV's snapshot view is debug-only** (`debug_start.dart:24–26`), so a thin client fed by snapshots is not a release path; video or a new receiver implementation is.

## Decisions

Assumptions made to keep the scan read-only and to answer without guessing (low-usage mode, no questions asked):

- HEAD is `f3b58ef`. The working tree also has three modified generated Windows plugin files (`generated_plugin_registrant.cc/.h`, `generated_plugins.cmake`) that are unrelated; they were left untouched.
- "The streaming client" is a separate device (TV, phone, tablet) playing a video stream from the Windows host; it may or may not speak our WebSocket protocol. Where a fact depends on which, the answer says so.
- "Network" means the stream's own transport, not the controller WebSocket, since the capture tool runs on the same PC as the host.
- New stages would be reported where the current ones are (the metrics `stages` map and `reportStage`), not through a new pipeline.
- The PRD is taken as the statement of what's planned; `docs/decisions.md` has no streaming decision (grep `stream|video`: none), so nothing there constrains a streaming version yet.
- Items marked **unsure** are outside what the code states: tool behavior, VM/RDP rendering, and the exact pixels a capture API forces.

## Questions

1. For a streamed host, is "50 ms" still measured from touch to the thin client's screen, or per stage with a looser total?
2. Should the thin client be a `display` receiver that speaks the protocol (so stages have an id and a clock offset), or a passive video client?
3. Must the stream also carry the game's sound, or can the thin client play nothing while the PC keeps its own audio?
4. Is a window-size change (and no fullscreen) acceptable for the 1–2 day test, or is fullscreen part of that test?

## Commit message

```
docs(m15): scan what streaming touches in the host and controller

Read-only scan before a testable streamed host: the PRD's v3 direction
and the S1-S9 rules held against the code, the Windows runner's window,
resolution, frame rate, audio and flags, the controller's mDNS, typed
address and pairing path with its LAN timeouts, the four latency stages
and where encode, network, decode and display could be added, what a
thin client must show, the phone-over-game overlay that already exists,
and a reuse list for an off-the-shelf stream, the new stages and a cloud
host.
```

## Status row

| 15 Stream scan | G0 scan done ([scan-stream-touchpoints-report.md](scan-stream-touchpoints-report.md)): host capturable as a 1280×720 logical window (no fullscreen, no headless, ≤60 fps, default audio device); phone path is mDNS + typed IP/hostname + 4-digit code with 1 s/4 s heartbeats, 4 s connect, 5 min pairing; any stage name reaches the summary already; phone already draws the game under its pad; no TLS, no internet-play path, no stream timestamps. Open: Claude's decision | 

## Delete

- none
