job: web research: verify the facts behind Claude's streaming proposal for Thumb Party (a Windows PC with an RTX 3080 streams the game's window to thin clients; later a cloud GPU)
pub: no
stop: after the report.
read: tools/web_fetch.dart and docs/dev-tools.md (how to fetch pages here) · docs/briefs/m14/research-party-games-report.md (the report style: facts with a source URL each, dated)
decide: low-usage mode: never stop for a question; if a page can't be fetched say so and mark the fact "unverified"; state assumptions under "Decisions".

Claude (the designer) plans to propose **Sunshine (host) + Moonlight (clients)** as the 1–2 day path, with a **WebRTC browser client** as the later path for TVs Moonlight can't reach. Verify or correct each point below from primary sources (project docs, GitHub repos, release notes, store pages), each with its URL and the date/version you saw. Today is Nov 11, 2026. Change no file but the report.
1. **Sunshine** (LizardByte): current version; Windows install; NVENC on an RTX 3080 (H.264/HEVC/AV1 support for that card: the 3080 has no AV1 encode: confirm); can it stream **one application window or only a display**; virtual display / headless options on Windows; audio capture; its web UI / config; **what timing it logs or exposes** (capture time, encode time, per-frame stats, an API or log file we could read); licence.
2. **Moonlight clients**: official and community clients and their state today for: Android phones/tablets, Android TV / Google TV, Fire TV, iOS, iPadOS, Apple TV (tvOS), LG webOS, Samsung Tizen, Roku, Windows/macOS/Linux, a web browser client. For each: where to get it (store link), official or community, any known limits (codec, 4K, HDR, input). **The performance overlay**: which numbers it shows (network latency, decode time, render/queue time, frame drops, jitter) and whether any client can **log them to a file or export them**.
3. **Latency numbers** people measure for Sunshine+Moonlight on a LAN and over the internet (encode ms on NVENC, decode ms on typical TV boxes and phones, total added delay), with sources.
4. **Internet play**: Moonlight Internet Hosting Tool / UPnP / port list; using Tailscale or ZeroTier with Moonlight; any relay options.
5. **Cloud GPU hosts that run Sunshine on Windows**: at least four options (for example AWS EC2 g4dn/g5/g6, Azure NV-series, Google Cloud, Paperspace, TensorDock, Vast.ai, Shadow PC, a GeForce NOW note: can it run our own app? no?), each with GPU, hourly price today, Windows licence included or not, whether a virtual display/NVENC works, minimum billing, and a link to a how-to for Sunshine on it.
6. **WebRTC path**: which TV browsers/platforms support WebRTC playback today (Samsung Tizen, LG webOS, Android TV WebView/Chrome, tvOS (no browser), Roku (confirm: no WebRTC, only HLS/DASH, so high delay)); ready-made low-latency WebRTC screen streamers that use NVENC on Windows (for example Selkies-GStreamer, the Sunshine web client work if any, OBS WHIP + a WHEP player, MediaMTX, Neko, Parsec as a closed alternative) and what per-frame stats the browser exposes (`getStats`: jitterBufferDelay, totalDecodeTime, framesDecoded, `requestVideoFrameCallback` presentation times).
7. **Alternatives in one line each** with why not for a 2-day test: Parsec, Steam Remote Play, Apollo (the Sunshine fork with virtual displays), Wolf, NVIDIA GameStream (ended), Amazon GameLift Streams, Azure/Stadia-style SDKs.
8. **Measuring end to end**: accepted ways to measure glass-to-glass delay cheaply (a phone's slow-motion camera filming both screens, an on-screen timecode/QR clock, NVIDIA LDAT/Reflex analyzer) with a source each.

in the report: a summary table first (platform × client that works today × official/community × notes), then each point with sources, then "Corrections to Claude's assumptions".
rules: change no file but the report · install nothing · download nothing but web pages
allow: docs/briefs/m15/research-stream-stack-report.md
check: format
report: docs/briefs/m15/research-stream-stack-report.md
