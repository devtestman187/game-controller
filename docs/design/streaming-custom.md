# Thumb Party cloud streaming: the custom stack (M15 design, draft 1)

Status: draft for the owner, Nov 11, 2026. It replaces the Sunshine + Moonlight proposal in cloud-streaming.md (kept for the comparison and the measuring ideas). Evidence: docs/briefs/m15/research-custom-stack-report.md (48 web sources, fetched Nov 11, 2026) and docs/briefs/m15/scan-stream-touchpoints-report.md (our code).

## 1. What the owner asked for

A custom server and client (not Sunshine), built to learn how production game streaming works and to grow into a product: lowest latency, play across the internet, **several households in separate sessions at once**, the server **in containers** so it scales, open-source parts wherever they exist, running on the home PC (RTX 3080) first and cloud GPUs later, with latency logged at every stage (input, host, encode, network, decode, display).

## 2. The stack

```
            one Linux container per household session
 ┌────────────────────────────────────────────────────────────────┐
 │ Thumb Party host (our Flutter app, Linux build)                │
 │        │ draws into                                            │
 │ gst-wayland-display   a tiny virtual screen that is also the   │
 │ (MIT)                 video source: no desktop, no extra copy  │
 │        │                                                       │
 │ GStreamer (LGPL): NVENC H.264 encode (low-latency settings)    │
 │        │            + game sound → Opus                        │
 │ webrtcsink (gst-plugins-rs): WebRTC send, congestion control,  │
 │        │            loss repair, adaptive bitrate              │
 │ our WebSocket (as today): pairing, menus, controller input,    │
 │                     and the WebRTC handshake ("signalling")    │
 └───────────────┬────────────────────────────────────────────────┘
                 │ WebRTC video + sound (encrypted, UDP)
     coturn (BSD) relay, only when a home network blocks direct
                 │
   clients: a browser page · the Thumb Party apps (flutter_webrtc)
                 ▲
 session service (ours, small): "new session" → starts a container
 on a GPU machine → returns a session code; the phones and the
 screen join by that code
```

| Part | We reuse | We build |
| --- | --- | --- |
| Virtual screen + capture | gst-wayland-display (MIT, from the Wolf project) | — |
| Encode | GStreamer `nvh264enc` (NVENC) | the settings |
| WebRTC sending, congestion control, loss repair | GStreamer `webrtcsink` | — |
| WebRTC receiving | the browser; `flutter_webrtc` in our apps | the player screen |
| Relay | coturn, or a paid relay (Cloudflare) | — |
| Handshake, pairing, input | our existing WebSocket protocol | new message types; the `display` role S3 reserved |
| Sessions | Docker; later k3s + Agones | a small allocator (session code → container) |
| Per-stage timing | browser/WebRTC stats, GStreamer timers, our S7 stages | the glue and report rows |
| Container recipe | Selkies' GPU container setup as the reference (MPL-2.0) | our image |

**Corrections the research made to my first sketch:** Selkies is no longer a GStreamer sender (it is a Python app now), so we borrow its container recipe, not its code. A plain virtual X screen (Xvfb) cannot work, because Flutter on Linux needs a real GPU surface. And the virtual screen problem is already solved by gst-wayland-display.

**How production services compare:** this is the same shape GeForce NOW, Xbox Cloud Gaming and Luna use: a session on a GPU machine, hardware encode, WebRTC-style transport with congestion control, a relay fallback, and a placement service. Ours is smaller, not different.

## 3. Several households at once

One container = one session = one household (their 2–4 phones and one screen). The session service starts a container per session and hands out a code. Limits: this PC's driver allows **12 video encodes at once** (measured Nov 11; NVIDIA's cap for consumer cards), so the 3080 hosts up to 12 sessions if drawing keeps up; data-centre cards (T4, L4, A10G) have no such cap. No media server (SFU) is needed: each session has one sender and one viewer.

## 4. The home PC problem

**Containers cannot use the graphics card's video encoder on Windows today.** Docker Desktop passes the GPU into Linux containers for computing but not for video encoding (Docker issue #467, open since June 2026). The honest choices:

| Option | Containers? | Effort | Notes |
| --- | --- | --- | --- |
| **A. Run the sender as plain Windows programs** | No | 1–2 days | Flutter Windows build + GStreamer for Windows. Fastest way to a working stream and real latency numbers. One session at a time is simplest; several are possible with one window each |
| **B. Linux on the PC (dual boot)** | Yes | an evening to set up | The exact production setup; the same image runs in the cloud |
| **C. A rented cloud GPU machine for the container work** | Yes | hours; roughly $0.40–1.00 an hour while in use | No change to the PC; also proves the cloud path. Prices to confirm |
| D. Workaround inside WSL2 (mount the encoder files by hand) | Maybe | an afternoon to try | Unsupported; may break on driver updates. Worth one probe, not a foundation |

**Update, Nov 11 (docs/briefs/m15/research-hyperv-gpu-report.md, 50 sources):** the owner asked about Hyper-V. Sharing the card with a VM (GPU-P) exists on Windows 11 Pro but Microsoft supports it only on Windows Server 2025 with data-centre cards; it works unofficially for Windows guests, and for a Linux guest it is a day of hand-copied drivers that break on every driver update, with no proven container path. Handing the whole card to a VM (DDA) is blocked on Windows 11. The promising find is option D done properly: **plain WSL2 Ubuntu with Docker Engine installed inside it** (not Docker Desktop) plus the NVIDIA Container Toolkit, asking for the `video` capability. Microsoft documents that setup, and the encoder libraries are present in WSL2. Unproven: whether our GPU-drawn app can render inside such a container (WSL2 has no NVIDIA display device; drawing goes through Mesa's D3D12 layer, and frames would pass through system memory before encoding). Worth a 1–2 hour probe before step 4. The two research reports disagree on the GeForce encode-session cap (8 or 12): check on the PC.

**Measured on the PC, Nov 11 (docs/briefs/m15/wsl2-probe-report.md: commands, outputs, a copy-paste recipe, removal steps):** WSL 3.0.5, Ubuntu 24.04 in its own distro `tp-stream`, Docker Engine 29.9.3 inside it, NVIDIA Container Toolkit 1.20.2, driver 610.88.

| Question | Result |
| --- | --- |
| NVENC in a container | **Works** with only `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all` (no library mounts). 1080p H.264 at about 476 frames a second unthrottled |
| GStreamer encoder element | `nvh264enc` fails ("Selected preset not supported"); **use `nvautogpuh264enc` or `nvcudah264enc`** |
| Encodes at once on the 3080 | **12** (the 13th fails with "incompatible client key"); 12 streams of 1080p60 each kept real time |
| GPU drawing (OpenGL) | Works in WSL2 and in a container, but through Mesa's D3D12 translation layer (needs `GALLIUM_DRIVER=d3d12`, `/dev/dxg` and `/usr/lib/wsl` passed in). Vulkan is software only |
| Draw + encode with no screen | Works: 1080p at **68 frames a second** with a trivial test pattern, frames copied through system memory. That is thin headroom over 60, before a real game |
| A Wayland app drawing on a virtual screen | **Unproven**: the compositor starts on the GPU, but a test client drew nothing ("EGL Wayland extension: no"), so the zero-copy path gst-wayland-display relies on is probably unavailable in WSL2 |

**What this means:** on this PC, WSL2 containers are good for building and testing everything **after** the picture exists: encoding, WebRTC sending, the relay, the session service and several sessions at once (up to 12). They are **not yet proven for drawing the game itself**: the drawing path is a translation layer with a memory copy, and the virtual-screen piece of the design may not work there. So the containerised game should be proven on real Linux (a rented cloud GPU, or dual boot), and WSL2 used as the everyday development bench. One cheap follow-up would settle the drawing question for WSL2: run the Flutter Linux build of the game in the `tp-stream` container.

**The real game, measured Nov 11 (docs/briefs/m15/linux-game-probe-report.md; run by flash-worker in its new `wsl:` mode):** the TV app **builds for Linux with no code changes to make it compile** (Flutter 3.47.8; every plugin builds) and, inside a GPU container in WSL2 on a headless Wayland compositor (weston), the Arena drew at **58–60 frames a second at 1920×1080** on the RTX 3080 (5 ms of each 16.7 ms frame, GPU 24%). Capture from an X screen plus NVENC ran at 57.5 frames a second. Open items it found:

1. **Getting the picture out.** Weston's headless screen refuses capture by other programs, and on an X screen (where capture works) the app falls back to software drawing at about 10 frames a second. The design's own piece, gst-wayland-display (a compositor that is itself the video source), is the intended answer and is untested here; weston's PipeWire output is the fallback. **This is the one remaining unknown for running the whole stack in WSL2 containers.**
2. **Sound is silent**: the sound library finds no audio device in the distro or container. Needs a virtual audio device (PulseAudio/PipeWire null sink), which the stream needs anyway.
3. **Starting a game without a person** used debug-only flags and a simulated controller, patched in the test copy. The automation interface of section 6a replaces that.
4. Discovery advertises on Linux but wasn't tried from a phone; a container needs its controller port published.

**Recommendation:** A now (learn and measure this week), then C for the container and multi-session work, with D tried once in passing. B only if you want the PC itself to be the multi-household server.

## 5. The plan, in steps you can test

| Step | What you can test at the end | Where | Size |
| --- | --- | --- | --- |
| **1. First stream** | The game on the PC, video in a browser on a laptop, phone or TV on your Wi-Fi; phones control as today | Windows, option A | 1–2 days |
| **2. Measure** | Encode, network, decode and display times in our stats report beside input and host; a latency test card to film | Windows | 2–3 days |
| **3. Tune** | Lower delay: encoder settings, no client buffering, frame pacing; a target to beat | Windows | 2–3 days |
| **4. Container** | The same stream from a Linux container (Flutter Linux build on the virtual screen) | Cloud GPU (C) or Linux (B) | about a week; the riskiest step |
| **5. Sessions** | Two households at once, each with its own code, started by the session service | same | 3–5 days |
| **6. Internet** | Play from outside your home: relay server, encryption for the control link, session tickets instead of only a 4-digit code | cloud | 3–5 days |
| **7. Our own client** | Video inside the Thumb Party apps (Android TV, phones, tablets, iPhone, iPad) with the controls on top | apps | 1–2 weeks |
| **8. Later** | Controller input over WebRTC's fast channel; snapshot streaming for clients that can run our code; autoscaling; LG/Samsung browser polish; Apple TV (needs a native player, flutter_webrtc has no tvOS build); Roku (no WebRTC: controller-only or a delayed spectator view) | — | — |

## 6. Latency stages in this stack

| Stage | Measured by |
| --- | --- |
| input, host | our existing stages |
| encode | timestamps around capture and encoder in GStreamer |
| network | WebRTC's own round-trip and jitter numbers, plus a capture timestamp carried with each frame |
| decode | the player's stats (browser `getStats`, the same in flutter_webrtc) |
| display | the player's frame-presented callback |

Every client reports its numbers to the host over our WebSocket, so all six stages land in one session record for every device, TVs included. That is the main measuring gain over Moonlight.

## 6a. Automation: one control interface for every build (owner, Nov 11, 2026)

The container work needs the host to be driven without a person: start a game, set options, add players, send inputs, read state, take a picture. The owner's rule: "If there are any remote control feature (eg making the Linux scriptable or remotely controllable via an api), make that available to other builds as well to help with automated testing or making demo videos."

So any such feature is built **once, in the shared host code** (`party_host`/`game_kit`), not in the Linux build: the Windows, Android TV and phone hosts get it too. It stays off unless a build or launch flag turns it on, never ships enabled in store builds, and listens only on the local machine unless told otherwise. Before building, check what exists (the debug start flags `START_GAME`/`SHARE_VIEW`/`FRAME_RATE_HZ`, the keyboard player, `tools/smoke.sh`, `tools/tv-window.ps1` screenshots, the demo-video branch's tooling) and extend that rather than add a second mechanism. Uses: the session service's "ready" check, automated end-to-end tests, latency tests with scripted presses, and scripted demo videos.

## 7. Risks

1. **The Flutter Linux build in a container on the virtual screen** (step 4) is new ground for us; plugins need checking on Linux (sound, discovery). Mitigation: steps 1–3 don't depend on it.
2. **First custom latency will likely be worse than Sunshine's** until tuned (WebRTC buffers by default). Step 3 exists for this.
3. **Security for internet play**: today's control link is unencrypted with a 4-digit code. Must be fixed in step 6 before anything is exposed.
4. **Licences**: GStreamer is LGPL (fine to use as separate libraries); avoid GPL encoders (x264) in anything we ship; confirm webrtcsink's licence file before shipping.
5. **Costs**: relayed sessions cost bandwidth (about $0.18 a session-hour at typical rates); a cloud GPU is shared by 8–12 sessions.

## 8. Decisions needed

1. Start step 1 on Windows (option A)? It needs GStreamer installed on the PC.
2. For the container steps: rent a cloud GPU (C), or put Linux on the PC (B)?
3. Which screens matter first for step 7?
