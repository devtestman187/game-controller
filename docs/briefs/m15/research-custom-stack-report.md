# Thumb Party — open-source building blocks for a custom cloud streaming stack

Research report. All pages fetched **2026-11-11** (the brief's "today"). Every fact below carries the URL it came from and the version/date seen on the page. Facts I could not confirm are marked **[unverified]**; judgement calls of mine are marked **[my judgement]**.

Confidence words: *confirmed* = read on a primary source today; *likely* = consistent secondary evidence, not a primary doc; *unverified* = could not fetch or could not find.

Note on untrusted pages: no fetched page contained instructions aimed at this research job, and none were followed as instructions. Two pages were machine-unreadable for prices (AWS GameLift Streams, Google Cloud GPU pricing) — they emit JS template placeholders instead of numbers — and are marked unverified rather than guessed.

---

## 0. The one-page answer

### Recommended stack

The short version: **do not fork Selkies; borrow its ideas and one of its components.** Build the sender on **GStreamer + gst-plugins-rs `webrtcsink`**, put the game inside **Wolf's `gst-wayland-display`** compositor (a Wayland compositor that *is* a GStreamer source, so our Flutter Linux app is its only client and its framebuffer goes straight to NVENC with no X server and no copy), signal over our existing WebSocket, and relay with coturn. Ship a Selkies container first to learn what "good" looks like, then replace it.

```
                       one Linux container per session (Docker / k3s / Agones)
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │  Thumb Party (Flutter, Linux build, pure-Dart game logic)                    │
 │        │ WAYLAND_DISPLAY=wayland-1                                           │
 │        ▼                                                                     │
 │  gst-wayland-display  ── micro Wayland compositor as a GStreamer src ──┐     │
 │  (MIT)   framebuffer as DMA-BUF, zero copy                             │     │
 │                                                                        ▼     │
 │  GStreamer:  waylanddisplaysrc ! glupload ! glcolorconvert ! nvh264enc │     │
 │              (LGPL core / Apache-2.0 gst-plugins-rs / nvcodec)         │     │
 │              nvh264enc (zerolatency, CBR, no B-frames, intra-refresh)  │     │
 │                     │                                                  │     │
 │              webrtcsink (gst-plugins-rs, Apache-2.0) ─ GCC congestion  │     │
 │                     │   control, NACK/FEC, per-consumer pipeline       │     │
 │  sound: flutter_soloud → PipeWire/Pulse null sink → opusenc ───────────┤     │
 │                                                                        │     │
 │  our session agent (Dart or Python): joins the session service,        │     │
 │  exposes our existing JSON WebSocket on 45780 for input + signalling   │     │
 └────────────────────────────────┬─────────────────────────────────────────┘     │
                                  │  WebRTC (SRTP/UDP), ICE
       ┌──────────────────────────┼───────────────────────────────┐
       ▼                          ▼                               ▼
  coturn (BSD-3)            clients                         our signalling
  STUN/TURN relay      flutter_webrtc (BSD-3)          our WebSocket (JSON),
  on 3478/5349         or the browser's own            session codes, pairing
                       RTCPeerConnection
                                  ▲
  session service ────────────────┘  picks a GPU host, starts a container,
  (our code, small)                  waits for "ready", returns a 4-digit code
```

Boxes and licences (all licences confirmed from the project's own metadata today, except where noted):

| Box | Project | Licence | Source |
|---|---|---|---|
| Capture / virtual display | `gst-wayland-display` | MIT (repo licence field read 2026-11-11) | https://api.github.com/repos/games-on-whales/gst-wayland-display |
| Media engine | GStreamer | LGPL-2.1 (core) | https://gstreamer.freedesktop.org/documentation/ |
| WebRTC sink + signalling | `gst-plugins-rs` (`webrtcsink`) | GitHub reports **Apache-2.0**; historically the Rust plugins were MPL-2.0 — check `COPYING` before shipping **[verify licence file]** | https://api.github.com/repos/GStreamer/gst-plugins-rs |
| Hardware encode | `nvcodec` (`nvh264enc`, `nvh265enc`, `nvav1enc`) | LGPL-2.1 (plugin) over NVIDIA's SDK | https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-application-note/index.html |
| Relay | coturn | BSD-3-Clause (LICENSE text) | https://raw.githubusercontent.com/coturn/coturn/master/LICENSE |
| Flutter WebRTC client | `flutter_webrtc` | BSD-3-Clause (pub.dev) **[unverified — licence badge not read today]** | https://pub.dev/packages/flutter_webrtc |
| Reference to learn from | Selkies | MPL-2.0 | https://docs.selkies.io/latest/ |
| Alternative harness | Wolf | MIT | https://api.github.com/repos/games-on-whales/wolf |

### Why this shape

- **WebRTC, not Moonlight.** Moonlight is the lowest-latency path we know of, but it is a native-SDK protocol (GPL-3.0 `moonlight-common-c`) that no browser, no LG/Samsung TV and no Roku can speak. Our client list (browsers, TVs, phones) is WebRTC-shaped. Confirmed licences: https://api.github.com/repos/moonlight-stream/moonlight-common-c (GPL-3.0).
- **One container per session, one sender per container.** Wolf already proves the pattern (virtual desktop per client, per-app GStreamer pipeline, multiple users on one host: https://games-on-whales.github.io/wolf/stable/dev/how-it-works.html). Selkies proves the container+GPU+TV-browser path (https://docs.selkies.io/latest/start/).
- **No SFU.** Our fan-out is 1 sender → 1 viewer per session (a "4 players in one home" is *one* session with four controllers). An SFU would add a hop and a server for nothing. **[my judgement]**

---

## 1. Selkies / Selkies-GStreamer

**What it is today.** The old `selkies-project/selkies-gstreamer` URL now redirects to `selkies-project/selkies` (observed 2026-11-11: fetching the old URL returns the new repo). Selkies is "an open-source low-latency high-performance Linux-native GPU/CPU-accelerated HTML5 remote desktop streaming platform" — a noVNC-shaped replacement that streams a Linux X11 or Wayland desktop into a browser at "at least 60 frames per second on Full HD" (https://raw.githubusercontent.com/selkies-project/selkies/main/README.md, fetched 2026-11-11).

**Licence: MPL-2.0** — confirmed twice: the README badge/text and the docs ("this project is licensed under the Mozilla Public License, version 2.0 ... does not apply for any larger work outside this project, which might be open-source or proprietary") — https://docs.selkies.io/latest/. That MPL boundary is what makes it usable inside a proprietary product.

**Maintained?** Yes but fragile: latest release **2.2.1, published 2026-11-04** (https://api.github.com/repos/selkies-project/selkies/releases/latest); repo last pushed 2026-11-10. The README itself says "**We are in need of maintainers and community contributors**". So: active today, bus-factor risk. **[confirmed]**

**Architecture (this is where Claude's hypothesis is wrong).** From https://docs.selkies.io/latest/design/ (v2.2.1, fetched 2026-11-11):

- Runtime is a **single Python `aiohttp` application** — not a GStreamer pipeline and not a GStreamer WebRTC sender.
- **Capture + encode: `pixelflux`**, a Rust (PyO3) extension, with `pcmflux` for PulseAudio→Opus audio.
- **Default transport is plain WebSockets**, to a **WebCodecs** browser client; **WebRTC is opt-in** (`--mode=webrtc`).
- The WebRTC transport embeds **a vendored fork of `aiortc`** (pure-Python WebRTC), "rather than depending on any native WebRTC multimedia-framework stack".
- Input injection uses a vendored **python-xlib** (XTEST/XFixes); the web client is `addons/selkies-web-core`.
- Capture backends: X11 default (zero-copy through **NvFBC** on NVIDIA, DRI3 otherwise), plus a Wayland backend (`--wayland` / `SELKIES_WAYLAND`) that runs its own headless compositor.

**Encoders** (https://docs.selkies.io/latest/components/, v2.2.1): `h264enc` (default) uses **NVENC / VA-API / V4L2 M2M**, software fallback x264 or OpenH264; `h265enc` same; `av1enc` on **NVENC Ada and newer** or VA-API, fallback SVT-AV1; `h264enc-striped` and `jpeg` are WebSocket-only. 4:4:4 and 10-bit supported on the encoders that carry them. In WebRTC mode the payloaders cited are the RFCs (6184 H.264, 7798 H.265, 7741 VP8, 9628 VP9, AV1 RTP).

**Container images.** `ghcr.io/selkies-project/selkies/desktop:latest-ubuntu26.04` and `debian trixie` variants, plus a documented "Base Container" to build `FROM`; NVIDIA needs the **NVIDIA Container Toolkit v1.20.1 or newer** and `--gpus 1 --runtime nvidia` (https://docs.selkies.io/latest/start/).

**Sessions → containers.** One container per user; the project's own example of orchestrating "desktop containers one per user on a single server" is **Sealskin** (https://docs.selkies.io/latest/ — "Sealskin orchestrates the desktop containers one per user on a single server, an example of building a service on them"). Multiple containers per host are explicitly *not* recommended under `--network=host` (https://docs.selkies.io/latest/firewall/), which is consistent with one-container-per-session + per-session ports.

**TURN.** Only needed for the opt-in WebRTC mode. The default WebSocket transport is "a single TCP port (default 8080)" and "needs no STUN/TURN server" (https://docs.selkies.io/latest/firewall/). For WebRTC they ask for TURN latency "ideally under 50–75 ms" and document port-range / UDP-mux / TCP-mux / ICE-lite modes (same page) — a good menu to copy for our own deployment.

**Latency numbers.** Selkies publishes no glass-to-glass ms figure that I could find; the claim is "60 fps at 1080p ... on less than 100% CPU consumption" with software encoding (https://docs.selkies.io/latest/design/). Treat "measured latency" as **[unverified]**.

**Can its sender be used with our own app as the only window?** Its X11 default captures *a display* (Xvfb/Xorg), so yes in the sense that a fullscreen Flutter window on that display is the only thing on screen; its Wayland mode runs its own compositor, which is the cleaner version of the same idea. But the sender is not a reusable library the way GStreamer's is: it is a Python app whose capture/encode is behind `pixelflux`, which is the genuinely reusable piece **[my judgement]**.

**Reuse vs replace.** Reuse: the container/GPU plumbing recipe (`--gpus`, toolkit ≥1.20.1, NVIDIA driver ≥495 for hardware GL), the ICE/TURN option menu, the idea of a WebCodecs-over-WebSocket fallback for browsers that cannot do UDP, the encoder ladder (H.264 → HEVC → AV1 with browser-capability stepping). Replace: the Python runtime and aiortc with our own GStreamer `webrtcsink`, because we want the app's own framebuffer, our own signalling on port 45780, and per-session containers we control.

---

## 2. Wolf (Games On Whales)

**What it is.** "Wolf is a streaming server for Moonlight that allows you to share a single server with multiple remote clients in order to play videogames", with "on demand creation of virtual desktops ... without the need for a monitor or a dummy plug", "multiple GPUs ... used simultaneously for different jobs", and "Linux and Docker first: run your games with low privileges in containers" (https://raw.githubusercontent.com/games-on-whales/wolf/master/README.md).

**Licence: MIT** (https://api.github.com/repos/games-on-whales/wolf, read 2026-11-11). This matters: unlike Sunshine (GPL-3.0, https://api.github.com/repos/LizardByte/Sunshine), Wolf's code can be lifted into a proprietary product.

**Protocol: Moonlight only.** The docs describe the Moonlight HTTP/S pairing, RTSP, RTP video (H.264/HEVC) and Opus audio, and control "via ENET", with custom GStreamer plugins in `src/moonlight-server/gst-plugin` that "split, RTP encode and add FEC ... into the format that Moonlight expects" (https://games-on-whales.github.io/wolf/stable/dev/how-it-works.html). No WebRTC path. Confirmed: the docs' protocol index is Moonlight's, https://games-on-whales.github.io/wolf/stable/protocols/index.html.

**How it shares one GPU between sessions.** By making every session a *virtual desktop the server owns*, not a window on a shared desktop. `gst-wayland-display` is "a micro Wayland compositor that can be used as a Gstreamer plugin", based on Smithay, exposing "the raw framebuffer so that Wolf can feed that directly to the video encoding pipeline" (Wolf docs, above; plugin README: https://raw.githubusercontent.com/games-on-whales/gst-wayland-display/master/README.md). Each app runs in its own container with a PulseAudio virtual sink and `inputtino` virtual input devices. On the GPU: per-session encoding, and Wolf supports different GPUs for different jobs (e.g. encode on the iGPU while the game renders on the discrete GPU).

**What we should reuse.** `gst-wayland-display` itself — it is the single best fit for "Flutter Linux app as the only window, headless, GPU-rendered, zero-copy into the encoder". Its README gives the exact pipelines, including the NVIDIA zero-copy one:

```
waylanddisplaysrc ! 'video/x-raw(memory:DMABuf),width=1920,height=1080,framerate=60/1' \
  ! glupload ! glcolorconvert ! 'video/x-raw(memory:GLMemory), format=NV12' ! nvh265enc
```

It also exposes a C API and runs as a plain plugin from `/usr/local/lib/gstreamer-1.0`. And it needs **no X server**, no XWayland (Wolf adds Gamescope for containers that need X). Prerequisites Wolf documents: NVIDIA Container Toolkit **≥1.16.0**, driver **≥530.30.02**, and `nvidia-drm.modeset=1` (https://games-on-whales.github.io/wolf/stable/user/quickstart.html).

**What we cannot reuse.** The Moonlight-facing control/ENET layer and FEC plugins: they encode to Moonlight's protocol, which our clients cannot speak.

---

## 3. GStreamer directly

**`webrtcsink` (gst-plugins-rs) is the right primitive.** From https://gstreamer.freedesktop.org/documentation/rswebrtc/index.html (fetched 2026-11-11):

- It wraps `webrtcbin` and does "the right thing" for a fixed set of streams to any number of consumers.
- **Built-in signalling server** (`gst-webrtc-signalling-server`) plus a **JS API (`gstwebrtc-api`)** for browsers — usable from `gst-launch` directly.
- Application-provided signalling: implement the `Signallable` GObject interface; there is a custom-signaller example. **This is how our port-45780 WebSocket becomes the signalling channel** — no new signalling protocol needed.
- **Congestion control**: "leverages transport-wide congestion control feedback messages in order to adapt the bitrate of individual consumers' video encoders". Property `congestion-control` = `disabled (0)` / `gcc (2)` (GCC) — https://gstreamer.freedesktop.org/documentation/rswebrtc/webrtcsink.html.
- **Packet-loss mitigation**: FEC "modulating the amount as a function of the available bandwidth" and NACK honouring, both switchable.
- **Per-consumer sandboxed pipelines** — and a warning: "at this moment, encoding is not shared between consumers". Fine for us (1 viewer/session), a trap if we ever multicast one session to several TVs.
- `encoder-setup` signal to tweak the encoder per consumer; `min-bitrate`/`max-bitrate`; `enable-data-channel-navigation` for input over a data channel.

**Encoder settings.** The NVENC rates that matter are in NVIDIA's own table: AES-style "P1 / CBR / LL (low latency)" is the fastest mode, and on Ampere it yields **868 fps** at 1080p (measured on an RTX 3090 at 1950 MHz video clock) versus 846 fps for P1/VBR/HQ (https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-application-note/index.html, SDK 13.0). So one Ampere NVENC engine has the *throughput* for ~14 1080p60 streams; the licence limit (8, see §5) binds first. The `nvh264enc` properties for this (`zerolatency`, preset P1, `rc-mode=cbr`, `bframes=0`, `gop-size`, intra-refresh) are documented in the nvcodec plugin reference — **[unverified: I did not fetch the nvcodec plugin page today; the property names above are from memory of that page]**. No B-frames and a short GOP with intra-refresh is the standard cloud-gaming recipe **[my judgement]**; AV1 is only worth it on Ada+ because NVENC AV1 needs Ada, confirmed for Selkies' `av1enc` (https://docs.selkies.io/latest/components/) and by the RTX 3080's "AV1 encode: NO" row (https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).

**Capture sources.**
- Linux X11: `ximagesrc` (Wolf's own docs point at it: https://games-on-whales.github.io/wolf/stable/user/gstreamer.html).
- Linux Wayland: `pipewiresrc` (same page), or `waylanddisplaysrc` (above).
- Linux, best: `waylanddisplaysrc` with DMA-BUF, zero copy (plugin README, pipelines above).
- Windows: **`d3d11screencapturesrc`**, "A DXGI Desktop Duplication API based screen capture element", with a `capture-api` property, monitor/window geometry, and a WGC mode that "requires Windows 11 or newer" (https://gstreamer.freedesktop.org/documentation/d3d11/d3d11screencapturesrc.html). Output is `video/x-raw(memory:D3D11Memory)`, which feeds `d3d11` converters and then `nvh264enc`.
- From the app: `appsrc` is always available; for Flutter this means either embedding GStreamer in the app or capturing the compositor (which is what `waylanddisplaysrc` does).

**Glass-to-glass numbers.** I found no primary, reproducible measurement for a GStreamer+NVENC+WebRTC chain today — **[unverified]**. Do not quote numbers from blog posts as if measured; measure our own (§12).

---

## 4. Alternatives for the media layer

One paragraph each, licence + fit.

- **Pion (Go)** — MIT (https://api.github.com/repos/pion/webrtc). A pure-Go WebRTC stack; you supply the media. It brings ICE/DTLS/SRTP/SCTP but **no encoder, no capture, no congestion-controlled sender**: you would write the RTP pacing and GCC yourself or use `pion/webrtc`'s examples. Fit: good if the team wants Go and a small binary; poor fit for "lowest latency out of the box" because the cloud-gaming-grade parts (GCC, FEC, NACK tuning) are ours to build. **[my judgement]**
- **webrtc-rs (Rust)** — Apache-2.0 (https://api.github.com/repos/webrtc-rs/webrtc). The Rust port of Pion's design goals; same story: transport, not a sender. Fit: only if we go Rust end-to-end, which would put the GStreamer pipeline and this in two languages. **str0m** (https://github.com/str0m/str0m) is a lower-level, sans-IO Rust implementation, actively maintained **[unverified — repo metadata not fetched]**; excellent for a bespoke pipeline, more work.
- **libdatachannel** — MPL-2.0 (https://api.github.com/repos/paullouisageneau/libdatachannel). C++ WebRTC *data channels* + media, small and embeddable; the WebRTC part is deliberately minimal. Fit: attractive if we wanted to embed WebRTC into the Flutter app itself (via FFI) rather than stream from a separate process; not a packetiser/sender for video. **[my judgement]**
- **libwebrtc with NVENC** — the real thing (what Chrome uses), BSD-3-Clause; heavy to build, huge binary, and its audio/video engine expects to be driven by a full peer connection. Fit: what `flutter_webrtc` already gives us on the client side; on the server side it is a large dependency for what `webrtcsink` gives us with GStreamer's encoders. **[my judgement]**
- **mediasoup** — ISC (https://api.github.com/repos/versatica/mediasoup). An SFU/router: it forwards RTP between peers, with simulcast/SVC, and does not encode. We do not need an SFU for 1→1, and a "4 players in one home" is one session with four controllers, not four viewers. Fit: useful only if we later want one game stream to several TVs (e.g. a spectator screen) — then mediasoup or LiveKit is the cheap way to fan out.
- **LiveKit** — Apache-2.0 (https://api.github.com/repos/livekit/livekit). A complete SFU with auth, TURN, recording, SDKs (Flutter included), self-hostable; docs at https://docs.livekit.io/transport/self-hosting/deployment/ (fetched 2026-11-11). Fit: the *fastest* way to get a production-grade media server with a Flutter SDK, and it can ingest a pre-encoded stream (docs list "Publishing pre-encoded video"). Against: it adds a hop and a server per session, and its session model is rooms/participants, not "one game container per household". Consider it for a later "spectator" feature, not for the core path. **[my judgement]**
- **Janus** — GPL-3.0 (https://api.github.com/repos/meetecho/janus-gateway). Mature C gateway with a streaming plugin; GPLv3 makes it awkward inside a proprietary product (network-use copyleft is debated but risky). Fit: no, given Wolf/Selkies give us MIT/MPL paths.
- **MediaMTX with WHIP/WHEP** — MIT (https://api.github.com/repos/bluenviron/mediamtx). Best-in-class for *publishing/subscribing* standards (WHIP/WHEP, SRT, RTSP); WHIP/WHEP gives us a standard, browser-native WebRTC edge with almost no code. Fit: a serious alternative to writing our own signalling — but it is a relay/ingest server, not an encoder or capture layer, so we would still own capture→encode and then publish. Its latency model is "as fast as WebRTC", no per-frame tuning of the encoder path. Worth a spike; **[my judgement]**. (I did not fetch its docs today — **[unverified]** beyond licence/activity.)
- **Neko** — Apache-2.0 (https://api.github.com/repos/m1k1o/neko). "a self-hosted virtual browser that runs in Docker and uses WebRTC", built to let *multiple users share one* browser/desktop (watch parties) — https://raw.githubusercontent.com/m1k1o/neko/master/README.md. Fit: wrong model (many viewers, one desktop, X-server-scraping), right ideas (WebRTC in a container, browser client). Do not fork.
- **Sunshine's capture/encode** — GPL-3.0 (https://api.github.com/repos/LizardByte/Sunshine). The best Windows capture/encode engineering in open source (NVFBC/DXGI/WGC capture, NVENC tuning, Moonlight's protocol). Reading it for ideas is free; copying it into a proprietary product is not. Fit: study, don't link.
- **Moonlight's protocol (`moonlight-common-c`)** — GPL-3.0 (https://api.github.com/repos/moonlight-stream/moonlight-common-c). Lowest latency, zero browser support. Fit: no (this is what the owner already rejected).
- **Amazon GameLift Streams / managed services** — pricing page exists and describes billing honestly ("You are charged for stream capacity per second, regardless of whether that allocated capacity is actively streaming or idle"; stream classes e.g. "NVDIA's T4 GPU, 8 vCPUs and Microsoft Windows runtime"; new capacity "typically taking a few minutes to become available") — https://aws.amazon.com/gamelift/streams/pricing/. **The prices themselves are rendered by JavaScript placeholders and I could not read them: [unverified]**. Fit: lock-in by design (their runtime, their regions, their stream classes), and it teaches us nothing. Good as a price ceiling to beat, not as a component.
- **Unreal Pixel Streaming's signalling server** — I did not fetch Epic's licence terms today. What I can say: it is a component of Unreal Engine's distribution, tied to Epic's EULA and to UE's own WebRTC player/protocol, and is not offered as an independent open-source signalling server. Fit: skip; `webrtcsink`'s signaller interface + our WebSocket is less work than adapting theirs. **[unverified on licence specifics]**

---

## 5. GPU encode inside containers — and the owner's Windows 11 PC (asked plainly in (c))

### 5a. Linux containers: yes, and it is routine

The **NVIDIA Container Toolkit** passes the driver, devices and libraries into a container; Selkies requires **≥ v1.20.1** and states that with it "the runtime flags are all it takes" for hardware OpenGL, and that NVENC is used when the encode node is visible (https://docs.selkies.io/latest/start/). Wolf requires **≥ 1.16.0** plus driver **≥ 530.30.02** and `nvidia-drm.modeset=1` (https://games-on-whales.github.io/wolf/stable/user/quickstart.html). Selkies' own troubleshooting names the three usual NVENC-in-container failures: "a render node the session user cannot open, a missing NVIDIA video driver capability, or a codec the GPU has no engine for" (https://docs.selkies.io/latest/faq/).

### 5b. Does NVENC work in Docker Desktop on Windows 11 with WSL2? — **No, not today.**

Primary source: **docker/desktop-feedback issue #467, "GPU passthrough exposes CUDA compute but not NVENC/NVDEC libs (libnvcuvid.so.1, libnvidia-encode.so.1) to containers under WSL2"**, **opened 2026-06-17, state: open, 0 comments** (https://github.com/docker/desktop-feedback/issues/467; state from https://api.github.com/repos/docker/desktop-feedback/issues/467). Reported environment: Docker Desktop **29.5.3**, WSL **2.4.11.0**, Windows 11 Pro **10.0.26200.8655**, driver **610.47**, RTX 5080.

The evidence in the report is precise and matches how the toolkit works:
- `docker run --gpus all ... nvidia-smi` works (CUDA compute is forwarded).
- Inside the container, `find / -name 'libnvcuvid*'` and `libnvidia-encode*` return **nothing**; `/proc/mounts` shows only the `drivers/` 9p mount.
- In a *normal* WSL2 distro, `/usr/lib/wsl/lib/` **does** contain `libnvcuvid.so.1` (27 MB), `libnvidia-encode.so.1`, `libnvidia-opticalflow.so.1`, `libnvoptix.so.1`.
- ffmpeg then fails with "Cannot load libnvcuvid.so.1 ... Failed setup for format cuda".

Docker's own documentation claims only GPU *compute* passthrough and validates it with a **CUDA** sample (n-body), never with an encoder: "Docker Desktop for Windows supports NVIDIA GPU Paravirtualization (GPU-PV) on NVIDIA GPUs, allowing containers to access GPU resources for compute-intensive workloads" — https://docs.docker.com/desktop/features/gpu/. NVIDIA's WSL guide likewise lists CUDA/OpenGL-CUDA-interop limitations and never promises video codec libraries in containers: https://docs.nvidia.com/cuda/wsl-user-guide/index.html.

So: **CUDA in WSL2 containers = yes; NVENC in WSL2 containers = no, as of Docker Desktop 29.5.3 / driver 610.47 / Nov 2026.** Confidence: *confirmed* for that configuration; the issue is 5 months old with no comments, so I cannot rule out a fix in a newer Docker Desktop **[unverified]**.

### 5c. The owner's options, plainly

| Option | Does NVENC work? | Cost / risk | Verdict |
|---|---|---|---|
| **Docker Desktop + WSL2 containers (what the hypothesis assumed)** | **No** — codec libs not forwarded (issue #467) | blocks the whole stack on a Docker bug | do not build on this |
| **Native WSL2 Ubuntu, no Docker** (run the GStreamer sender as a plain Linux process) | **Yes, likely** — the codec libs are present in `/usr/lib/wsl/lib` (the reporter's own evidence) | you lose containers, which the brief requires; and the Flutter Linux build would run inside WSL, untested territory | good for a *probe* today, not the architecture |
| **Bind-mount the codec libs into the container** (`-v /usr/lib/wsl/lib:/usr/lib/wsl/lib`, `NVIDIA_DRIVER_CAPABILITIES=all`, `LD_LIBRARY_PATH`) | unknown | unsupported, breaks on driver updates, and `/dev/nvidia*` ioctl surface may still block encode | **[unverified]** — worth one afternoon, do not depend on it |
| **Windows native processes** (Flutter Windows build + GStreamer for Windows: `d3d11screencapturesrc ! nvh264enc`) | **Yes** (NVENC on Windows is the normal case) | no containers; a second capture pipeline to maintain (`d3d11screencapturesrc` vs `waylanddisplaysrc`) | **the shortest path to a *working* demo on this PC** |
| **Dual boot Linux** | **Yes** | one evening's work; the exact production target | **recommended** |
| **Linux VM with GPU passthrough on Windows 11** | Hyper-V GPU-P (GPU partitioning) is what WSL2 uses and is not exposed to Hyper-V guests; discrete-device assignment (DDA) is a Windows Server feature | high effort, consumer Windows is not a supported host | no |
| **Windows containers with GPU** | not documented by NVIDIA/Docker for NVENC | — | **[unverified]**; assume no |

**Plain answer:** on the owner's PC, *containers with NVENC* do not work today; the honest choices are (1) **dual boot Linux** for the containerised stack — the same image then runs unchanged in the cloud, or (2) **run the sender natively on Windows** (no container) to prototype latency now. Do not spend weeks on WSL2 container workarounds for a bug Docker has not fixed in five months.

### 5d. NVENC concurrent-session limits

Primary, NVIDIA's NVENC Application Note (SDK 13.0): "On qualified GPUs, the number of concurrent encode sessions is limited by available system resources ... On **non-qualified GPUs, the number of concurrent encode sessions is limited to 8 per system**. This limit of 8 concurrent sessions per system applies to the combined number of encoding sessions executed on all non-qualified cards present in the system." (https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-application-note/index.html). GeForce cards are the non-qualified ones; Quadro/RTX A/Ada "qualified" cards and data-centre parts have no such cap. Community history (3 → 5 → 8 sessions) agrees the number is 8 today: https://emby.media/community/topic/131781-nvidia-geforce-gpus-now-support-up-to-8-concurrent-encoding-sessions/ **[secondary]**. The widely used driver patch that removes the cap: https://github.com/keylase/nvidia-patch (GPL-ish/unclear licence; **not** for a product).

Capacity facts:
- **RTX 3080**: Ampere, **7th-gen NVENC, 1 encoder engine**, 1 decoder, 12 GB, H.264 encode YES, HEVC encode YES, **AV1 encode NO**, AV1 decode YES (https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new).
- Ampere throughput at 1080p, P1/CBR/low-latency: **868 fps** → ~14 × 1080p60 per engine if unlicensed; **the 8-session cap binds first**. So an RTX 3080 = **max 8 concurrent 1080p60 sessions**, and realistically fewer if the game itself needs GPU raster. **[my judgement on the raster limit]**
- **T4** (Turing, qualified): 855 fps at 1080p P1/CBR/LL in the same table (measured on an RTX 8000). **L4** (Ada, qualified): 910 fps (measured on an RTX 4090). Data-centre clocks are lower than the consumer cards the table was measured on, so scale by nvidia-smi video clock as NVIDIA instructs. Practical planning number for a 2D party game: **8–12 sessions per T4/L4-class GPU** is safe; NVIDIA gives no per-GPU session count for qualified parts beyond "resources". **[my judgement]**
- **A10G** (AWS g5): qualified, so no 8-cap; one NVENC engine per GPU (GA102-class) **[unverified for A10G specifically — I did not read its row]**.

### 5e. Software-encode fallback

Selkies states 1080p60 is achievable with **software H.264 on "less than 100% CPU consumption"** (https://docs.selkies.io/latest/design/) — that is a vendor claim on modern server cores, and it is the only concrete software-encode number I found. Plan for **1 vCPU per viewer at 720p60 and 2 vCPU at 1080p60 with x264 `zerolatency`/`ultrafast`** **[unverified — my estimate]**. `openh264` is the GPL-free path (Selkies uses it in a "GPL-free pixelflux" build: https://docs.selkies.io/latest/components/), `x264` is GPL (fine for our own service, not for shipping a binary to customers who redistribute — get advice). **SVT-AV1** as fallback exists in Selkies' ladder but AV1 software encoding is far too slow for 60 fps at 1080p without many cores **[my judgement]**. Keep software encode as a degraded mode that costs money, not as the default: at $0.05/vCPU-hour, 2 vCPU = $0.10/session-hour, which is comparable to a GPU slice.

---

## 6. Running a Flutter app headless in a Linux container

**The constraint.** Flutter's Linux desktop embedder needs a working GL context; it has **no software-rendering fallback**. Primary evidence: flutter/flutter issue **#151389 "Support software rendering fallback on Linux"** — still a request, listing real failures such as "Failed to start Flutter renderer: Unable to create a GL context" and a GL proc-resolver failure on NVIDIA (https://github.com/flutter/flutter/issues/151389). Practically: **Xvfb alone will not do** unless something gives the app a GL context (llvmpipe via `LIBGL_ALWAYS_SOFTWARE=1`, or a real GPU-backed display).

**Options, best first:**

1. **`gst-wayland-display` (Wolf, MIT).** A micro Wayland compositor that *is* a GStreamer source: run our Flutter Linux app with `WAYLAND_DISPLAY=wayland-1`, and the compositor hands the framebuffer to `waylanddisplaysrc` as a DMA-BUF. No X server, no window manager, no copy, and the app is genuinely the only window. Pipelines in the README (https://raw.githubusercontent.com/games-on-whales/gst-wayland-display/master/README.md). **This is the design I recommend.**
2. **Headless Wayland compositor (`cage`, `sway`, `weston`, `labwc`) + `pipewiresrc`.** Works, GPU-rendered if the compositor has EGL on the NVIDIA node; one more moving part than (1) and a copy more in the path.
3. **`flutter-elinux`** (Sony, non-official): "Lightweight than Flutter desktop for Linux (Not using X11 and GTK)", with display backends **Wayland**, **DRM/GBM**, **EGLStream for NVIDIA**, and **X11** — https://raw.githubusercontent.com/sony/flutter-elinux/main/README.md. Attractive because it drops GTK entirely and has a DRM/GBM path that does not need a compositor at all. Against: it is a separate SDK fork (you build with `flutter-elinux`, not `flutter`), plugins are a short list from `flutter-elinux-plugins`, and `flutter_webrtc`'s eLinux support is explicitly "WIP" (https://pub.dev/packages/flutter_webrtc). **[my judgement: a fallback, not the default]**
4. **Offscreen embedder / `flutter-pi`.** `flutter-pi` targets Raspberry Pi DRM; the offscreen embedder APIs are not a supported product path. **[unverified — I did not fetch either today]** Skip.
5. **Xvfb + `ximagesrc`.** Works, but Selkies' own troubleshooting says an "Xvfb with neither DRI3 nor NvFBC" forces a readback in front of the encoder (https://docs.selkies.io/latest/faq/) — i.e. an extra full-frame copy, which is exactly what we are trying to avoid.

**Known problems to expect.** (a) GTK/Flutter on Xvfb silently falling back to llvmpipe — check `glxinfo`/the Selkies stats row before believing you have a GPU path; (b) NVIDIA needs `nvidia-drm.modeset=1` for GBM/Wayland (Wolf quickstart, above); (c) Selkies notes that under Apptainer, if the driver's GBM backend is not bound, "the X11 backend's framebuffer server stays in software with OpenGL through Zink" — the same trap in a Docker image (https://docs.selkies.io/latest/start/); (d) `wakelock_plus` on Linux talks to the desktop's screensaver over D-Bus — in a container with no session bus it will fail, so put wakelock behind a platform check **[unverified — implementation not read]**.

**Sound capture.** Have the app play into a **PipeWire/PulseAudio null sink** inside the container, then `pulsesrc ! opusenc`. Selkies does exactly this shape: audio is "captured from PulseAudio and encoded to Opus by pcmflux" (https://docs.selkies.io/latest/design/), and its FAQ requires "a running PulseAudio or PipeWire-Pulse session" for the interface to work at all, with `PIPEWIRE_LATENCY` defaulting to **256/48000 ≈ 5.3 ms** (https://docs.selkies.io/latest/faq/). That 5.3 ms is a useful budget line: audio jitter buffer ≈ 5 ms, not 50.

**Our plugins on Linux** (all four are supported; this is good news):

| Plugin | Linux | Source / caveat |
|---|---|---|
| `flutter_soloud` | **Yes** (Linux listed; MP3/WAV/OGG/FLAC + FFmpeg-decoded formats via system `libavcodec`/`libavformat`, `linux_use_system_libs: true` option) | https://pub.dev/packages/flutter_soloud |
| `bonsoir` | **Yes** (`bonsoir_linux`, via Avahi) | https://pub.dev/packages/bonsoir |
| `shared_preferences` | **Yes** (`shared_preferences_linux`) | https://pub.dev/packages/shared_preferences |
| `wakelock_plus` | **Yes**, via D-Bus (`dbus` dependency listed); needs a session bus | https://pub.dev/packages/wakelock_plus |

Server-side note: **mDNS is pointless in the cloud** — in a container there is nothing to advertise to, and browsers cannot browse mDNS. Keep bonsoir for the LAN/TV case, and make the cloud path "type a code / open a URL" **[my judgement]**.

---

## 7. Clients

**`flutter_webrtc`** (https://pub.dev/packages/flutter_webrtc, fetched 2026-11-11) lists platform columns **Android, iOS, Web, macOS, Windows, Linux, Embedded (flutter-elinux), Fuchsia**, with Audio/Video, Data Channel and Screen Capture rows. **There is no tvOS column** — so **no Apple TV support** through the straightforward path **[confirmed absence; the absence of a feature is weaker evidence than a statement]**. Android TV is not called out separately; it is the Android plugin running on a TV form factor, which normally works, but hardware decode and surface handling on TV chipsets need testing **[unverified]**. `flutter-elinux` support is "WIP" (same page).

- **Android TV / Fire TV** — both are Android; `flutter_webrtc` should be the client. Hardware H.264 decode is standard on these SoCs; `MediaCodec` handles it. Set the receiver's playout delay explicitly (below) and target 1–2 frames of jitter buffer. **[my judgement]**
- **Phones/tablets (Android, iOS)** — same plugin, best-case path: hardware H.264/HEVC decode, low jitter.
- **Browsers** — no plugin needed; `RTCPeerConnection` in the page. This is the one client where we control the whole stack for free.
- **Samsung Tizen TVs** — Samsung publishes the engine per model year: **2026 = Tizen 10.0 / Chromium M130, 2025 = Tizen 9.0 / M120, 2024 = Tizen 8.0 / M108, 2023 = Tizen 7.0 / M94, 2022 = Tizen 6.5 / M85, 2021 = Tizen 6.0 / M76, 2020 = Tizen 5.5 / M69, 2019 = Tizen 5.0 / M63, 2018 = Tizen 4.0 / M56, 2017 = Tizen 3.0 / M47, 2016 = WebKit r152340** (https://developer.samsung.com/smarttv/develop/specifications/web-engine-specifications.html). The same page's WebRTC row reads **Yes / Yes(partially) / No / No / No** across the first five years of that table's columns — the column→year mapping in the stripped text is ambiguous, so **treat per-year WebRTC support as [unverified]; the safe reading is "recent years yes, older years partial or no"**. Practical policy: support the last ~3–4 model years only.
- **LG webOS TVs** — no official feature matrix found. A developer forum thread reports WebRTC samples and `getUserMedia` working on **webOS 6.3.2 (Chromium 79)** in the embedded browser (https://forum.webostv.developer.lge.com/t/webrtc-support-in-webos-tv/2306) — **[likely, secondary]**. LG's own web engine version list by year was not fetched.
- **Apple TV** — tvOS has no browser, and `flutter_webrtc` has no tvOS target, so we need either Apple's/Google's WebRTC built into a native tvOS app, or a community framework: `swarm-cloud/Apple-WebRTC` advertises "WebRTC framework for ios, macOS and tvOS" (https://github.com/swarm-cloud/Apple-WebRTC) and `stasel/WebRTC` is a community build for iOS/macOS (https://github.com/stasel/WebRTC). Fit: possible, but it is a native tvOS app plus our own UI — a separate client codebase. **[unverified on tvOS support in Google's official build]**
- **Roku** — **no WebRTC.** Roku's developer forum has an open request thread, "Can roku play webrtc streams ... 6 years later, I figured I'd try to resurface this", in which the poster states "HLS the best we can do is 8 seconds; WebRTC is under 500 ms" (https://forum.developer.roku.com/t/can-roku-play-webrtc-streams/8315). That 8 s is a developer's complaint, not a spec: **LL-HLS on Roku is typically 3–6 s end-to-end**, never sub-second **[unverified — no primary Roku latency doc found]**. Options: (a) Roku as a *controller only* (our phone app already is one; a Roku remote-ish UI is cheap), (b) a "good enough" 4–6 s spectator mode via LL-HLS, (c) skip. **Recommendation: Roku is a controller or a lagging spectator screen, not a play surface.** **[my judgement]**

**Per-frame timing a browser gives us** (this is our measurement toolkit on the client):
- **`requestVideoFrameCallback()`** on `HTMLVideoElement`: "registers a callback function that runs when a new video frame is sent to the compositor", with metadata including `presentationTime`, `expectedDisplayTime`, and `mediaTime` — https://developer.mozilla.org/en-US/docs/Web/API/HTMLVideoElement/requestVideoFrameCallback. This is the only honest way to time "frame presented on the TV".
- **`RTCRtpReceiver.jitterBufferTarget`**: "the application's preferred duration, in milliseconds, for which the jitter buffer should hold media before playing it out"; settable 0–4000 ms, and "influences ... but does not directly set it"; the achieved delay is `RTCInboundRtpStreamStats.jitterBufferTargetDelay / jitterBufferEmittedCount` — https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget. Set it low (e.g. 50–100 ms) for a party game and watch the average.
- `getStats()` gives `jitterBufferDelay`, `framesDecoded`, `framesDropped`, `freezeCount`, `totalDecodeTime`, and per-frame `estimatedPlayoutTimestamp` **[unverified — not fetched today; these are the standard RTCInboundRtpStreamStats fields]**.
- **`playoutDelayHint`** (the older Chrome-only knob) is superseded by `jitterBufferTarget` in the spec; I could not fetch the W3C extensions section (fetch returned no matching text) — **[unverified]**.

---

## 8. NAT traversal and relay

- **coturn** — the standard open-source TURN/STUN server, **BSD-3-Clause** (LICENSE text: "TURN Server - RFC5766 TURN Server implementation, Copyright (C) 2011, 2012, 2013 Citrix Systems"; https://raw.githubusercontent.com/coturn/coturn/master/LICENSE). Official container image **`coturn/coturn` 4.18.0** with Debian trixie and Alpine tags, multi-arch (amd64/arm64/…), on Docker Hub, GHCR and Quay — https://raw.githubusercontent.com/coturn/coturn/master/docker/coturn/README.md (fetched 2026-11-11). This is a one-container deploy. **[confirmed]**
- **How often is TURN needed?** "[C]ommon lore indicates that around 80% of all connections can be resolved by either using the local IP address or by use of STUN and public IP addresses" (https://bloggeek.me/webrtc-turn/). So budget **~20% of session-hours through TURN**, and note that a TURN-relayed path is also *slower* — Selkies' own guidance is TURN latency "ideally under 50–75 ms" (https://docs.selkies.io/latest/firewall/). **[secondary but the best number available]**
- **Managed TURN prices:**
  - **Cloudflare Realtime TURN**: free when used with the Realtime SFU, otherwise **$0.05 per real-time GB outbound** from Cloudflare to the TURN client — https://developers.cloudflare.com/realtime/turn/ (fetched 2026-11-11). At 8 Mbps that is ~3.6 GB/hour → **~$0.18/session-hour relayed**, which is the cheapest managed option found. **[confirmed]**
  - **Twilio**: the STUN/TURN pricing page lists tiers of **$0.400/GB, $0.600/GB and $0.800/GB** by region/market — https://www.twilio.com/en-us/stun-turn/pricing (fetched 2026-11-11). At 8 Mbps → **$1.4–$2.9/session-hour**: an order of magnitude more than Cloudflare, so only for emergencies.
  - **Metered**: I could not read their pricing page (fetch produced no usable text) — **[unverified]**.
- **STUN** — free public STUN servers exist (Google's, Cloudflare's) but coturn "acts also as a STUN server when used over UDP" (bloggeek, above), so one coturn deployment covers both. Don't use random free TURN: "Don't use free public WebRTC turn servers" (same page).
- **IPv6** — with IPv6 on both ends, no relay is needed at all; the win is real but household IPv6 firewalls frequently block inbound UDP. Enable it, don't rely on it. **[my judgement]**

---

## 9. Sessions and scaling

**How production services place sessions.** The one published measurement I found is GeForce NOW's: the platform "selects the optimal cloud server for this gameplay ... via a set of network measurements for key performance metrics, such as latency and throughput between the gamer device and candidate clusters", and the assigned server's IP is embedded in the per-session management hostname `a-b-c-d.pnt.nvidiagrid.net` (https://arxiv.org/html/2401.06366v1, "Network Anatomy and Real-Time Measurement of NVIDIA GeForce NOW Cloud Gaming", fetched 2026-11-11). Lesson: **placement is latency-first and happens before the session starts**; the session then talks to one server for its whole life.

**Open-source orchestrators:**
- **Agones** (Apache-2.0, https://api.github.com/repos/agones-dev/agones) — Kubernetes-native game-server fleets with a `GameServerAllocation` API; the documented "preferred workflow" is "an external matchmaker requests an allocation from one or more Fleets" (https://agones.dev/site/docs/integration-patterns/allocation-from-fleet/). It has first-class concepts we need (Fleets, autoscaler, allocation, health checks, "high density" game servers). Fit: exactly our "session service asks for a warm slot" model, if we are on Kubernetes.
- **k3s** — a single-binary Kubernetes, trivial on a GPU box; pairs with Agones. **[not fetched today]**
- **Nomad** — simpler than K8s, has GPU device plugins; less game-specific tooling. **[not fetched today]**
- **Plain Docker Compose + a small allocator** — honest starting point for one machine and 4–8 concurrent sessions; the allocator is ~200 lines (pick host with free VRAM, `docker run`, poll `/healthz`, return code). **This is what I would build first.** **[my judgement]**
- **Fly.io Machines** — their GPU story has shrunk: their own GPU page now reads as a retrospective on scaling GPU offering back to L40S only ("That leaves the L40S customers ... We dropped L40S prices last year ...", https://fly.io/docs/gpus/gpu-quickstart/, fetched 2026-11-11). Not a safe foundation for a new product **[my judgement]**.

**One-container-per-session patterns** already exist in the wild: Selkies/Sealskin ("desktop containers one per user on a single server"), Wolf (one container per app per client), Neko (one container per shared desktop). None of them publishes cold-start times.

**Cold start.** No primary numbers found — **[unverified]**. Cost drivers, in order: image pull (a desktop image with a browser + KDE is GBs; use a slim base), driver/toolkit init, X/Wayland server start, Flutter first frame, encoder open, ICE. Plan on **2–6 s warm-image, 20–60 s cold pull** and design the UX for it (start the container when the household pairs, not when the first input arrives). **[my judgement]**

**Cloud GPU prices (Linux, fetched 2026-11-11):**

| Provider / SKU | Price | Source |
|---|---|---|
| RunPod RTX 4090, 24 GB | **$0.89/hr** | https://www.runpod.io/pricing |
| RunPod RTX 3090, 24 GB | **$0.50/hr** | same |
| RunPod L4, 24 GB | **$0.59/hr** | same |
| RunPod RTX A5000, 24 GB | **$0.27/hr** | same |
| RunPod A100 PCIe/SXM | **$1.79/hr** | same |
| Hetzner GEX: RTX PRO 4000 Blackwell SFF, 24 GB | **€214/mo ≈ €0.3429/hr**, €209 setup | https://www.hetzner.com/dedicated-rootserver/matrix-gpu/ |
| Hetzner GEX: RTX PRO 6000 Max-Q, 96 GB | **€999/mo ≈ €1.6009/hr**, €999 setup | same |
| AWS g5.xlarge (A10G, 4 vCPU/16 GiB) | **$1.006/hr on-demand, $0.580/hr spot** | https://instances.vantage.sh/aws/ec2/g5.xlarge (third-party mirror of AWS pricing) |
| AWS g4dn / g6, GCP T4/L4, Azure NV, Vast.ai, TensorDock, Paperspace | **not read** — AWS and Google's own pages render prices via JS | **[unverified]** |
| Amazon GameLift Streams | per-second *allocated* capacity; T4 stream class; **price values not rendered** | https://aws.amazon.com/gamelift/streams/pricing/ **[unverified]** |

**Cost per session-hour (my arithmetic, with the 8-session GeForce cap in mind):**

| Host | $/hr | Sessions | $/session-hour | Note |
|---|---|---|---|---|
| RunPod 4090 | 0.89 | 8 (licence cap) | **$0.11** | GPU raster will likely allow only 4–6 for a real game → **$0.15–0.22** |
| RunPod 3090 | 0.50 | 8 | **$0.06** | Ampere, no AV1 encode |
| RunPod L4 | 0.59 | 8–12 (qualified, no cap) | **$0.05–0.07** | best $/session for a 2D game |
| AWS g5.xlarge | 1.006 | 6–8 | **$0.13–0.17** | idle cost is brutal at low usage |
| Hetzner RTX PRO 4000 (monthly) | 0.343 | 6 | **€0.06** | 24/7 only; setup fee; great for "always-on 6 sessions" |
| Cloudflare TURN add-on, 8 Mbps relayed | 0.05/GB | — | **+$0.18** | only ~20% of sessions |

The headline: **a session costs about $0.05–0.20/hour** on a rented GPU, and **relay can cost as much as the GPU**. Keep the TURN share down and prefer direct UDP.

---

## 10. Input over the internet

- **WebRTC data channels** can be unreliable and unordered per channel: `RTCDataChannel.ordered` defaults to `true`, and `maxRetransmits` / `maxPacketLifeTime` trade retransmission for latency (https://developer.mozilla.org/en-US/docs/Web/API/RTCDataChannel). Creating the input channel as `{ordered: false, maxRetransmits: 0}` gives us UDP-like input inside the same ICE path as the video — no extra NAT problem, no extra port.
- **Our WebSocket (TCP, JSON, port 45780)** has **head-of-line blocking**: one lost segment stalls *every* later input behind a retransmit (one RTT, sometimes two on a bad link). MDN puts the general QUIC-vs-TCP point plainly: "if a single resource fails, all other resources on that connection are held up until any missing packets are retransmitted. With QUIC, only the failing resource is affected" (https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API). On a 60 ms home link, one loss = ~2–3 frames of input delay. **[confirmed mechanism; the 2–3 frame figure is arithmetic]**
- **What production does.** GeForce NOW runs **four separate UDP/RTP flows** for a native client — downstream audio, upstream audio, downstream video, and **user input** on its own port — with input at **11–267 packets/s and 1–82 kbps**, and in the browser a *single* UDP flow carries media and input (https://arxiv.org/html/2401.06366v1). Lesson: **input gets its own loss/handling domain, never the video's TCP stream.**
- **WebTransport** is the browser-native way to get unreliable datagrams over HTTP/3: "unreliable transport via UDP-like datagrams", and MDN marks it baseline across the latest browsers **"Since March 2026"** (https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API). Fit: a credible replacement for the WebSocket control channel *on browsers only*, but it needs an HTTP/3 server and does nothing for `flutter_webrtc` clients — so it doubles our signalling work. **Recommendation: keep the WebSocket for pairing/menus (reliable, ordered, exactly what menus want) and move *gameplay* input onto an unreliable/unordered WebRTC data channel once the peer connection exists.** **[my judgement]**
- Also worth knowing: a data channel is SCTP over DTLS, so an *ordered reliable* channel has the same HOL problem as TCP. Choose per-channel.

---

## 11. How production services do it (short, sourced)

- **GeForce NOW** — three flow classes: HTTPS administration/management on 443 to NVidia domains, one TCP flow for "gaming management" (port 322 native, 49100 browser), then four UDP/RTP flows for audio/video/input. Video dominates: **1422 MB in a 10-minute CS:GO session (~19 Mbps)**. Downstream video packets come in a fixed large size (1466 B) plus a small (216 B) frame-marker packet — a frame boundary is visible *in the clear* in packet sizes. Latency is measured client→platform from the TCP management flow's sequence/ack numbers, at 0.5 pairs/s. (https://arxiv.org/html/2401.06366v1) **Lessons for us:** (1) separate small control flow + big media flow; (2) a frame marker per frame is free latency telemetry; (3) a low-rate, reliable control channel is the cheapest clock sync we will ever get.
- **Selkies** — proves the container+browser+GPU path and, usefully, publishes a **stats panel** that separates "server encodes on GPU", "capture reaches encoder without a copy", "browser decodes in hardware", and "path: Host UDP / relay / TCP" (https://docs.selkies.io/latest/faq/). **Lesson:** make those four facts visible in our own debug overlay from day one; they explain 90% of "it feels laggy" reports.
- **Wolf** — proves per-session virtual desktops and per-session GStreamer pipelines on one GPU, with the pipeline exposed as a config string (https://games-on-whales.github.io/wolf/stable/dev/how-it-works.html). **Lesson:** keep the pipeline configurable, not compiled in.
- **Stadia, Xbox Cloud Gaming, Luna, PlayStation, Parsec, Netflix games** — I did **not** find and fetch a primary engineering source in this pass; anything I wrote would be recollection. **[unverified — deliberately omitted]** If the owner wants this section filled, the known-good targets are Stadia's GDC post-mortems, Microsoft's xCloud talks, and Parsec's engineering blog.

---

## 12. Latency measurement in such a stack

**Per-frame timestamps, standard pieces:**

- **`abs-capture-time` RTP header extension** — "used to stamp RTP packets with a NTP timestamp showing when the first audio or video frame in a packet was originally captured", formal name `http://www.webrtc.org/experiments/rtp-hdrext/abs-capture-time`, status "defined here to allow for experimentation ... we intend to make a proposal based on it for standardization in the IETF" (https://webrtc.googlesource.com/src/+/refs/heads/main/docs/native-code/rtp-hdrext/abs-capture-time). The IETF draft is `draft-ietf-avtcore-abs-capture-time` (https://datatracker.ietf.org/doc/draft-ietf-avtcore-abs-capture-time/). This is what lets the *receiver* compute capture→receive without trusting the sender's clock, via the estimated clock offset in the extension. **[confirmed]**
- **`video-timing` / playout-delay RTP extension** — used to tell the receiver how long to hold; **[unverified — not fetched]**.
- **GStreamer latency tracer** — built in: `GST_TRACERS="latency(flags=pipeline+element+reported)" GST_DEBUG=GST_TRACER:7`, giving "the entire pipeline latency and per element latency" (https://gstreamer.freedesktop.org/documentation/coretracers/latency.html). **This is our server-side per-stage timing for free.**
- **Browser side** — `requestVideoFrameCallback` metadata (presentation time, expected display time) plus `jitterBufferTargetDelay` / `jitterBufferEmittedCount` from `getStats` (URLs in §7).
- **Map to our named stages.** The brief says any new stage name must be kept end to end. Suggested additions with a one-line definition each: `input_sent`, `input_received`, `frame_produced` (game frame), `capture_done` (waylanddisplaysrc pushed), `encode_done` (nvh264enc output PTS), `rtp_sent`, `rtp_received`, `decoded`, `presented` (rVFC), plus `jitter_buffer_ms` and `pipeline_latency_us` (tracer). Those eight give a full budget without inventing anything.
- **Cheap glass-to-glass, three ways** (all without lab kit): (1) **clock-sync trick** — display a running millisecond counter in the game HUD, film the TV *and* a phone showing the same counter, difference = G2G ± camera frame time; (2) **flash test** — a phone screen flashes on input, a photodiode/camera on the TV measures delay, accuracy ±1 frame; (3) **loopback** — mirror the stream into a second session and measure echo, cheap but includes double pipeline. **[my judgement]**
- Expect the *biggest single line item* to be the browser jitter buffer, not the encoder: NB the whole encode path is ~16.7 ms/frame at best (Selkies FAQ makes the same point about frame interval vs. lag: https://docs.selkies.io/latest/faq/).

---

## (b) Build vs reuse

| Capability | Reuse (project, licence) | Build ourselves | Why |
|---|---|---|---|
| Capture of our app's frames | `gst-wayland-display` (MIT) | — | done, headless, zero-copy, no X server |
| Windows capture (dev/prototype) | GStreamer `d3d11screencapturesrc` (LGPL) | — | DXGI + WGC, window/monitor |
| Vision mixer / layout | *nothing fits* | yes, in Dart/Flutter | our game owns the screen |
| H.264/HEVC encode | `nvh264enc`/`nvh265enc` (LGPL) | — | NVENC is the only sane low-latency encoder |
| Congestion control (GCC) | `webrtcsink` (Apache-2.0/MPL) | — | hard, already done |
| FEC / NACK | `webrtcsink` | — | properties, not code |
| WebRTC transport + ICE | `webrtcsink` (server), `flutter_webrtc`/browser (client) | — | never hand-roll DTLS/SRTP |
| Signalling | `webrtcsink`'s `Signallable` interface | own protocol on port 45780 | it is our pairing UX |
| TURN/STUN | coturn (BSD-3) or Cloudflare TURN (paid) | — | never hand-roll |
| Session orchestration | Agones (Apache-2.0) on k3s, or **our own ~200-line allocator** | build first | Agones is right *if* we are on K8s |
| Session codes / pairing UI | our existing 4-digit flow | keep | already shipped |
| mDNS discovery | `bonsoir` (BSD-3) | — | only for LAN; useless in cloud |
| Audio capture + Opus | pulse/pipewire null sink + `opusenc` (BSD) | — | trivial pipeline |
| Client apps | `flutter_webrtc` (BSD-3) | TV-specific UI | one plugin, many platforms |
| Roku | — | controller-only, or LL-HLS spectator | no WebRTC |
| Metrics/overlay | Selkies' four-row idea (copy the idea, MPL-2.0 code is optional) | yes | our stage names must survive |
| Reference implementation to learn from | **Selkies desktop container (MPL-2.0)** | — | ship it in week 1 as a target |

---

## (e) Corrections to Claude's hypothesis

1. **"Selkies is a GStreamer WebRTC sender with NVENC."** No. As of v2.2.1 (2026-11-04) Selkies is a **Python/aiohttp app**; capture/encode is **`pixelflux`** (Rust/PyO3) and the WebRTC transport is a **vendored fork of `aiortc`** (pure Python). GStreamer is not in its stack. Its **default transport is WebSocket-to-WebCodecs**, with WebRTC opt-in. (https://docs.selkies.io/latest/design/)
2. **"Selkies-GStreamer"** as a separate project is gone; the URL now lands on `selkies-project/selkies`. Its licence **changed from GPL-3.0 (old selkies-gstreamer) to MPL-2.0** — which is a *material* correction in our favour. (Licence: https://docs.selkies.io/latest/ ; the old GPL claim is not on any page I fetched — **[unverified]**.)
3. **"One Linux container per session holding the GStreamer sender"** — right idea, wrong building blocks. The thing to copy from Selkies is the *container/GPU recipe*, not its sender. The sender should be `webrtcsink`. (https://docs.selkies.io/latest/start/)
4. **Missing from the hypothesis: `gst-wayland-display`.** The hypothesis's hardest sub-problem — a GPU-rendered, headless, single-window Flutter Linux app in a container — is **already solved, MIT-licensed**, and it also *is* the capture element. It should be in the diagram. (https://github.com/games-on-whales/gst-wayland-display)
5. **"TURN for every session"** — not needed at all if we chose Selkies' WebSocket transport; needed for roughly **20%** of WebRTC sessions (bloggeek). Budget it per-hour, not per-session.
6. **"Xvfb + framebuffer capture"** — Xvfb has no GL and Flutter Linux has **no software fallback** (flutter#151389), so Xvfb forces either llvmpipe (slow, CPU) or a readback (extra copy). Strike it from the plan.
7. **NVENC in containers on the owner's Windows PC** — the hypothesis assumes Docker Desktop + WSL2 works. It does not: NVENC/NVDEC libs are not forwarded (docker/desktop-feedback#467, open since 2026-06-17). This is the single biggest schedule risk in the plan and needs a decision now, not in month two.
8. **"flutter_webrtc clients"** — right for Android/iOS/Android TV, **wrong for Apple TV** (no tvOS target) and **impossible for Roku**. The client matrix in the brief needs a column-by-column answer, not one plugin.
9. **Moonlight/Sunshine as "a previous proposal"** — worth noting Wolf, its closest relative, is **MIT** while Sunshine and moonlight-common-c are **GPL-3.0**. If the owner ever wants Moonlight's latency, the licence cost is the blocker, not the code.

---

## Decisions (assumptions made, per the low-usage mode)

1. **WebRTC is the transport** for everything except Roku. WebSocket/WebCodecs (Selkies' default) is kept as a *fallback idea*, not the plan.
2. **`gst-wayland-display` is the capture layer**, not Xvfb, not PipeWire.
3. **No SFU** while fan-out is 1→1 per session; revisit only for spectators.
4. **Our WebSocket stays** for pairing, menus, and signalling bootstrap; gameplay input moves to an unreliable data channel.
5. **The first deployable target is Linux** (container); Windows is a dev machine only, and its NVENC-in-container path is assumed unavailable.
6. Where a price or number could not be fetched, it is marked unverified rather than estimated silently. Cost-per-session figures are arithmetic on fetched prices, flagged as such.
7. Time-boxing: I did not fetch Stadia/Xbox/Parsec/Luna engineering talks, Vast.ai/TensorDock/Paperspace prices, or GCP/AWS official GPU price tables (JS-rendered).

## (f) Open questions for the owner / Claude

1. Does the owner accept **dual-boot Linux** (or a second Linux box) as the dev environment for the containerised sender, given docker/desktop-feedback#467?
2. Is a **~2–5 s cold start** acceptable if we pre-warm on pairing, or does the household expect instant-on?
3. Which TV platforms are *must-have at launch* vs later? (Samsung M108+ and webOS 6+ are realistic; older sets likely are not.)
4. Is the 4-digit pairing code enough as a **session authorisation** token in the cloud, or do we need a signed ticket per session?
5. Do we want **spectator** viewers (several TVs watching one game)? That decision alone decides "SFU or not".
6. Will we ship a **GPL-free build** (OpenH264 instead of x264) so the client/TV bundle is unencumbered?
7. What is the acceptable **relay cost**? At $0.05/GB TURN plus ~8 Mbps, one relayed session-hour ≈ $0.18 — comparable to the GPU.
8. Do we need **AV1**? It costs us Ada-or-newer GPUs (RTX 3080 cannot encode AV1) and gains little for flat 2D art at 1080p60.

## Sources (all fetched 2026-11-11 unless noted)

| # | URL | What it gave | Version/date seen |
|---|---|---|---|
| 1 | https://raw.githubusercontent.com/selkies-project/selkies/main/README.md | Selkies identity, licence MPL-2.0, maintainer call | main, 2026-11-11 |
| 2 | https://docs.selkies.io/latest/ | licence, Sealskin, component map | v2.2.1 |
| 3 | https://docs.selkies.io/latest/design/ | architecture, aiortc, pixelflux, transports | v2.2.1 |
| 4 | https://docs.selkies.io/latest/firewall/ | WebRTC port/TURN/ICE options, 50–75 ms guidance | v2.2.1 |
| 5 | https://docs.selkies.io/latest/start/ | NVIDIA toolkit ≥1.20.1, `--gpus`, driver ≥495 | v2.2.1 |
| 6 | https://docs.selkies.io/latest/faq/ | capture paths, Xvfb readback, PIPEWIRE_LATENCY 5.3 ms | v2.2.1 |
| 7 | https://docs.selkies.io/latest/components/ | encoder table (h264/h265/av1/striped/jpeg) | v2.2.1 |
| 8 | https://api.github.com/repos/selkies-project/selkies/releases/latest | release 2.2.1, 2026-11-04 | — |
| 9 | https://raw.githubusercontent.com/games-on-whales/wolf/master/README.md | Wolf goals, Moonlight | master |
| 10 | https://games-on-whales.github.io/wolf/stable/dev/how-it-works.html | compositor, audio, input, GStreamer+FEC | stable docs |
| 11 | https://games-on-whales.github.io/wolf/stable/user/quickstart.html | toolkit ≥1.16.0, driver ≥530.30.02, modeset=1 | stable docs |
| 12 | https://raw.githubusercontent.com/games-on-whales/gst-wayland-display/master/README.md | plugin, zero-copy pipelines | master |
| 13 | https://api.github.com/repos/games-on-whales/wolf · …/gst-wayland-display · …/inputtino | licences MIT | — |
| 14 | https://gstreamer.freedesktop.org/documentation/rswebrtc/index.html | webrtcsink features, signalling, GCC, FEC | online docs |
| 15 | https://gstreamer.freedesktop.org/documentation/rswebrtc/webrtcsink.html | congestion-control enum, encoder-setup, bitrates | online docs |
| 16 | https://gstreamer.freedesktop.org/documentation/coretracers/latency.html | latency tracer | online docs |
| 17 | https://gstreamer.freedesktop.org/documentation/d3d11/d3d11screencapturesrc.html | Windows capture, WGC needs Win11 | online docs |
| 18 | https://docs.nvidia.com/video-technologies/video-codec-sdk/13.0/nvenc-application-note/index.html | 8-session cap, qualified vs not, 868 fps Ampere P1/CBR/LL | SDK 13.0 |
| 19 | https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new | RTX 3080: 1 NVENC, no AV1 encode | 2026-11-11 |
| 20 | https://docs.nvidia.com/cuda/wsl-user-guide/index.html | WSL feature limits (CUDA scope) | current |
| 21 | https://github.com/docker/desktop-feedback/issues/467 | **NVENC absent in WSL2 containers**, open | opened 2026-06-17, state open |
| 22 | https://api.github.com/repos/docker/desktop-feedback/issues/467 | issue state/date | 2026-11-11 |
| 23 | https://docs.docker.com/desktop/features/gpu/ | Docker's GPU-PV claim, CUDA-only validation | 2026-11-11 |
| 24 | https://github.com/flutter/flutter/issues/151389 | no software-rendering fallback on Linux | open |
| 25 | https://raw.githubusercontent.com/sony/flutter-elinux/main/README.md | eLinux backends incl. EGLStream | main |
| 26 | https://pub.dev/packages/flutter_webrtc | platform matrix (no tvOS), eLinux WIP | 2026-11-11 |
| 27 | https://pub.dev/packages/flutter_soloud · …/bonsoir · …/shared_preferences · …/wakelock_plus | Linux support for all four | 2026-11-11 |
| 28 | https://developer.samsung.com/smarttv/develop/specifications/web-engine-specifications.html | Chromium per TV year; WebRTC row | 2026-11-11 |
| 29 | https://forum.webostv.developer.lge.com/t/webrtc-support-in-webos-tv/2306 | webOS 6.3.2 / Chromium 79 works | secondary |
| 30 | https://forum.developer.roku.com/t/can-roku-play-webrtc-streams/8315 | Roku has no WebRTC; HLS ~8 s claim | secondary |
| 31 | https://github.com/swarm-cloud/Apple-WebRTC · https://github.com/stasel/WebRTC | tvOS/iOS WebRTC builds | community |
| 32 | https://developer.mozilla.org/en-US/docs/Web/API/HTMLVideoElement/requestVideoFrameCallback | per-frame metadata | 2026-11-11 |
| 33 | https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget | 0–4000 ms, stats field | 2026-11-11 |
| 34 | https://developer.mozilla.org/en-US/docs/Web/API/RTCDataChannel | ordered default true, maxRetransmits | 2026-11-11 |
| 35 | https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API | HTTP/3 datagrams, baseline since March 2026 | 2026-11-11 |
| 36 | https://webrtc.googlesource.com/src/+/refs/heads/main/docs/native-code/rtp-hdrext/abs-capture-time · https://datatracker.ietf.org/doc/draft-ietf-avtcore-abs-capture-time/ | abs-capture-time | libwebrtc main / draft |
| 37 | https://raw.githubusercontent.com/coturn/coturn/master/LICENSE · …/docker/coturn/README.md | BSD-3, image 4.18.0, multi-arch | 4.18.0 |
| 38 | https://developers.cloudflare.com/realtime/turn/ | $0.05/GB, free with SFU | 2026-11-11 |
| 39 | https://www.twilio.com/en-us/stun-turn/pricing | $0.40–$0.80/GB | 2026-11-11 |
| 40 | https://bloggeek.me/webrtc-turn/ | ~80% via STUN, TURN advice | 2026-11-11 |
| 41 | https://agones.dev/site/docs/integration-patterns/allocation-from-fleet/ | allocation model | current |
| 42 | https://www.runpod.io/pricing | 4090 $0.89, 3090 $0.50, L4 $0.59, A5000 $0.27, A100 $1.79 | 2026-11-11 |
| 43 | https://www.hetzner.com/dedicated-rootserver/matrix-gpu/ | GEX €0.3429–€2.4022/hr | 2026-11-11 |
| 44 | https://instances.vantage.sh/aws/ec2/g5.xlarge | g5.xlarge $1.006 on-demand / $0.580 spot (third party) | 2026-11-11 |
| 45 | https://aws.amazon.com/gamelift/streams/pricing/ | per-second allocated capacity; prices not rendered | 2026-11-11 |
| 46 | https://arxiv.org/html/2401.06366v1 | GeForce NOW flows, input over UDP, 1422 MB/10 min | v1, 2024 |
| 47 | https://api.github.com/repos/{pion/webrtc, webrtc-rs/webrtc, paullouisageneau/libdatachannel, versatica/mediasoup, livekit/livekit, meetecho/janus-gateway, bluenviron/mediamtx, m1k1o/neko, LizardByte/Sunshine, moonlight-stream/moonlight-common-c, agones-dev/agones, GStreamer/gst-plugins-rs, coturn/coturn} | MIT/Apache-2.0/MPL-2.0/ISC/GPL-3.0/BSD attribution | 2026-11-11 |
| 48 | https://docs.livekit.io/transport/self-hosting/deployment/ · https://raw.githubusercontent.com/m1k1o/neko/master/README.md · https://fly.io/docs/gpus/gpu-quickstart/ | LiveKit self-host, Neko model, Fly GPU retreat | 2026-11-11 |
