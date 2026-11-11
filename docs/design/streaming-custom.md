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

One container = one session = one household (their 2–4 phones and one screen). The session service starts a container per session and hands out a code. Limits: a GeForce card allows **8 video encodes at once** (NVIDIA's rule for consumer cards), so the 3080 hosts up to 8 sessions; data-centre cards (T4, L4, A10G) have no such cap. No media server (SFU) is needed: each session has one sender and one viewer.

## 4. The home PC problem

**Containers cannot use the graphics card's video encoder on Windows today.** Docker Desktop passes the GPU into Linux containers for computing but not for video encoding (Docker issue #467, open since June 2026). The honest choices:

| Option | Containers? | Effort | Notes |
| --- | --- | --- | --- |
| **A. Run the sender as plain Windows programs** | No | 1–2 days | Flutter Windows build + GStreamer for Windows. Fastest way to a working stream and real latency numbers. One session at a time is simplest; several are possible with one window each |
| **B. Linux on the PC (dual boot)** | Yes | an evening to set up | The exact production setup; the same image runs in the cloud |
| **C. A rented cloud GPU machine for the container work** | Yes | hours; roughly $0.40–1.00 an hour while in use | No change to the PC; also proves the cloud path. Prices to confirm |
| D. Workaround inside WSL2 (mount the encoder files by hand) | Maybe | an afternoon to try | Unsupported; may break on driver updates. Worth one probe, not a foundation |

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
