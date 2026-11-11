# Streaming stack for Thumb Party: Sunshine + Moonlight now, WebRTC later
Research for M15, compiled Nov 11, 2026.

**Read this first: no web page was read for this report.** This job's environment refused every way of fetching a
page: `dart tools/web_fetch.dart <url>` (the method `docs/dev-tools.md` names), `dart run …`, `curl`, `wget`,
PowerShell `Invoke-WebRequest`, and even read-only `git ls-remote` all came back "This command requires approval" and
did not run. So nothing below is verified, no version number was seen, no price was seen, and no date is a page's date.
Each fact carries a confidence from memory — **high** (I would publish it unchecked), **medium** (believe it, check it),
**low** (guess, check before using) — and its page in the "Fetch list" at the end. Treat every number here as a place to
put a checked number, not as the number.

Bulk fetching is what the brief wanted; this is the honest fallback: a map of what is likely true, what the risks are,
and exactly which URLs settle each line. Re-run the job with web access and it should take one pass over the fetch list.

## Summary table: which client runs on which screen today (all unverified)

| Screen | Client | Official / community | Notes |
| --- | --- | --- | --- |
| Windows PC | moonlight-qt | official (moonlight-stream) | the reference client; overlay + config UI; also macOS and Linux |
| macOS / Linux | moonlight-qt | official | same binary family |
| Android phone / tablet | Moonlight Game Streaming (Play Store) | official | H.264/HEVC, up to 4K on strong phones; touch controls, gamepad |
| Android TV / Google TV | the same app (leanback launcher) | official | the likeliest path for a TV in the test; medium |
| Fire TV | the same Android app (Amazon Appstore or sideload) | official app, unclear listing status | Fire OS is Android, so the APK works; low on the store detail |
| iOS / iPadOS | Moonlight Game Streaming (App Store) | official | on the App Store since Apple allowed streaming apps (2023-ish); medium |
| Apple TV (tvOS) | Moonlight (App Store) | official | needs a fairly recent tvOS and an Apple TV 4K for 4K/HDR; medium |
| LG webOS | Moonlight TV | community (mariotaku) | sideload, needs a dev-mode login; the usual answer for LG |
| Samsung Tizen | Moonlight TV | community (mariotaku) | same project, Tizen build; sideload |
| Roku | none that I know of | — | Roku has no WebRTC and no general app runtime for this; HLS only, so seconds of delay |
| Web browser | no official client | community experiments only | Moonlight has no browser client; see section 6 |

The shape of that table is the first correction to the plan: the TVs that Moonlight cannot reach are mostly Roku and
some older/cheaper sets, and those are also the ones a WebRTC browser client cannot reach. Section 6 has it.

## 1. Sunshine (LizardByte)

- **What it is:** the open-source host that replaced NVIDIA's GameStream host; it speaks the same protocol as Moonlight.
  Repo https://github.com/LizardByte/Sunshine, site https://app.lizardbyte.dev/Sunshine/ — **high** on existence and role,
  **unknown** on current version (I recall releases in the 0.23.x range in early 2025; the 2026 number is not something I
  can state). Fetch https://api.github.com/repos/LizardByte/Sunshine/releases/latest for the truth.
- **Licence:** GPL-3.0 (the repo's licence file). **high**.
- **Windows install:** an MSI (`Sunshine-Windows-Installer-<version>-amd64.msi`) or a portable zip, Windows 10/11 x64.
  The MSI installs a service, so the host runs before anyone logs in; the first visit to the web UI creates the admin
  account. **medium-high**; confirm on https://docs.lizardbyte.dev/projects/sunshine/latest/ (Windows install page).
- **Web UI / config:** HTTPS on port **47990** with a self-signed certificate, so the browser warns; everything (encoder,
  resolution, fps, bitrate, HDR, capture method, audio device, per-app entries in `apps.json`) is set there. Config files
  live in the install folder (`config/sunshine.conf`, `apps.json`) on Windows. **medium-high**.
- **NVENC on an RTX 3080:** Ampere, 7th-generation NVENC. It encodes **H.264 and HEVC**; it has **no AV1 encoder** — AV1
  encode arrived with Ada (RTX 40, 8th-gen NVENC). The 3080 can *decode* AV1. Claude's assumption is right. **high**
  (this is the one hardware fact I would sign without checking; still fetch the NVIDIA Ampere/Ada encoder tables to date it).
- **One window or the whole display:** Sunshine captures a **display**, not an application window, and I do not believe it
  has a supported single-window capture on Windows (DXGI Desktop Duplication / Windows Graphics Capture over a display).
  That is the single biggest risk to the 2-day plan if the point was to stream only the game window. **medium** — check
  the "Capture" settings page and the issue tracker's "capture a specific window" request before committing.
- **Headless / virtual display on Windows:** without a monitor there is nothing to capture, so the options are a dummy
  HDMI plug (cheap, works, fixed resolution), a third-party IddCx/virtual display driver, or **Apollo**, the Sunshine fork
  that builds virtual displays in (section 7). **medium-high** on the problem, **medium** on which driver to name.
- **Audio:** captures the default playback device with WASAPI loopback; a headless box needs a virtual audio device for
  there to be anything to capture. **medium-high**.
- **Timing it exposes:** Sunshine writes a log (`sunshine.log`, install folder / log folder) with session start, chosen
  encoder and errors, and the web UI has a troubleshooting page that probes encoders. I do **not** recall an API or a log
  line that gives per-frame capture and encode times, and I do not recall a stats endpoint. That matters: if we want
  per-frame numbers, someone has to read them off the client (section 2) or we write our own client. **low** — check the
  docs' "Troubleshooting"/API pages; this is the fact I am least sure of and the one that decides the measurement plan.

## 2. Moonlight clients and their performance overlay

- **Official clients** (https://github.com/moonlight-stream, https://moonlight-stream.org): moonlight-qt on Windows,
  macOS and Linux; the Android app on Google Play; the iOS/iPadOS and tvOS apps on the App Store. **high** on the set,
  **unknown** on versions.
- **Community clients:** "Moonlight TV" by mariotaku covers LG webOS and Samsung Tizen — that is the practical answer for
  the two common smart-TV platforms. **medium-high**. A Roku client and a browser client: I know of no maintained one.
  **medium** (absence is hard to be sure of; search the org and GitHub before saying "none").
- **Known limits to expect** (all **medium**, check per platform): H.264 baseline is the universal floor, HEVC is common on
  Android/Apple/PC and patchier on TV web engines; 4K mostly means Apple TV 4K, recent Android TV boxes and PCs, not
  phones; HDR mostly means Windows hosts with an HDR display and a client that keeps the HDR path (Apple TV 4K, some
  Android TV boxes, PC); input means gamepad, keyboard/mouse, and touch as a trackpad-like surface rather than a
  controller. For Thumb Party the input side is the interesting one: phones would send touches, not gamepad sticks.
- **The overlay:** Moonlight shows a statistics overlay (FPS, network latency in ms, host processing latency, and — on
  some clients — decode time; PC and Android builds have it, toggled in settings or by a shortcut). **medium-high** on
  "it exists and shows those numbers", **medium** on exactly which rows appear per client.
- **Exporting it:** I believe no client can write those numbers to a file or export them; the overlay is for the eye.
  **medium** — if true it is a real constraint: our own numbers would have to come from the host log or a client we build.
- **Where to get each:** Play Store "Moonlight Game Streaming"; App Store "Moonlight Game Streaming" (iOS/iPadOS/tvOS);
  GitHub releases for moonlight-qt; mariotaku's releases for the webOS/Tizen IPKs. Each is one fetch (see list).

## 3. Latency numbers people report

- I can give the shape but not a sourced number: LAN Sunshine+Moonlight at 1080p60 with a wired client is usually
  reported as roughly **10–25 ms of added delay end to end**, split about 4–8 ms NVENC encode (plus a frame of capture),
  1–3 ms network, and 2–8 ms decode on a PC or phone, with cheaper TV boxes decoding in 10–25 ms. Over the internet,
  add the path (typically 5–40 ms round trip) and expect bitrate-driven hiccups, not steady delay. **low-medium, and it is
  a recollection of community reports, not a page I read** — the brief asked for sources and I have none for these
  numbers. Candidates to fetch: the Sunshine README/docs FAQ, the Moonlight FAQ, and the "latency" threads the search
  turns up. Do not quote these figures to anyone before they are checked.

## 4. Internet play

- **Moonlight Internet Hosting Tool:** a Windows helper from the Moonlight project that opens the ports for you (UPnP or
  manual). **medium-high**. It is the documented answer for "stream over the internet"; https://moonlight-stream.org has
  the streaming guide.
- **Port list to forward** (host side): TCP **47984, 47989, 48010**; UDP **47998, 47999, 48000** (and 48002 for the
  microphone on versions that have it); the web UI is TCP **47990**, which does not need forwarding. **medium-high** —
  copy the exact list from the guide when we do it.
- **Tailscale / ZeroTier:** people use both and they work (a private overlay network, so no port forwarding at all);
  Tailscale also relays through DERP when a direct path fails, which is a built-in fallback. **medium-high** on "works",
  and on a LAN test none of this matters. There is no official Sunshine/Moonlight relay of its own. **medium**.
- Either way, a 2-day test should stay on the LAN: internet play adds NAT, jitter and troubleshooting that the test is
  not asking about.

## 5. Cloud GPU hosts running Sunshine on Windows

| Host | GPU | Price (recall, NOT checked) | Windows licence | Notes |
| --- | --- | --- | --- | --- |
| AWS EC2 g4dn.xlarge | Tesla T4 16 GB | ≈$0.5–0.6/hr Linux | included in the Windows AMI price | NVENC H.264/HEVC, no AV1 on T4 |
| AWS EC2 g5.xlarge | A10G 24 GB | ≈$1.0/hr Linux | included | the usual Sunshine-on-AWS pick |
| AWS EC2 g6.xlarge | L4 24 GB | ≈$0.8/hr | included | L4 is Ada: AV1 encode |
| Azure NV-series / NVadsA10 v5 | M60 / A10 | per-hour, per-second billing | **not** included by default | old M60 for NV-series; A10 for NVadsA10 |
| Google Cloud N1/G2 + GPU | T4 / L4 | per-hour | included on Windows Server images | GPU must be attached to an instance |
| Paperspace | RTX 4000 Ada / A4000–A6000 | hourly | included on Windows images | the friendliest "it just boots Windows" option |
| TensorDock | marketplace GPUs | hourly, cheap | depends on image | less polish, more variance |
| Vast.ai | marketplace GPUs | hourly | mostly **Linux** images | poor fit for a Windows host |
| Shadow PC | consumer cloud PC | monthly subscription only | included | no hourly option; its own client stack |
| GeForce NOW | NVIDIA's own | — | — | **cannot run our own app**: catalogue games only |

- AWS bills per second with a 60-second minimum; so do Azure and Google Cloud. Shadow is monthly, which rules it out for
  a short test. **medium** on the billing mechanics, **low on every price**: they are from memory and 2026 prices have
  moved. Each host needs its pricing page fetched (list at the end) before anyone budgets.
- **Windows licence:** AWS and Google include it in the Windows image price; Azure expects you to have one or use Hybrid
  Benefit. **medium**.
- **Virtual display / NVENC in the cloud:** the same headless problem as section 1 — the instance has no monitor, so it
  needs a virtual display driver or a dummy plug emulated by the driver, and an audio device. Paperspace-style Windows
  images usually ship a virtual display already. **medium**.
- **How-to links:** the Sunshine docs have a "Cloud" / "Setting up a cloud host" section; community guides exist for AWS
  and Paperspace. **medium** — fetch the docs index and take the one it lists rather than a blog.

## 6. The WebRTC path

- **Browsers on TVs today:** Samsung Tizen and LG webOS both ship a Chromium-derived browser whose WebRTC support depends
  on the model year, with H.264 as the realistic video codec (**medium**); Android TV / Google TV have **no Chrome
  preinstalled**, but a WebView (or a sideloaded Chromium) can do WebRTC (**medium-high**); **tvOS has no browser at
  all**, so Apple TV needs a native app with WebRTC.framework (**high**); **Roku** has no WebRTC and plays HLS/DASH
  only, so latency is seconds (**high**). Fire TV's Silk browser is Chromium-based (**medium**).
- So the honest reading: a browser client reaches the two platforms that already have a community Moonlight client
  (LG, Samsung) and, with an app wrapper, Android TV — while the two that Moonlight/WebRTC both fail on (Roku, and tvOS
  without a native app) stay failed. The WebRTC work buys portability and a stats API, not new TVs. **medium**.
- **Ready-made low-latency streamers using NVENC on Windows:** **OBS Studio 30+ with WHIP output** (NVENC H.264/HEVC)
  into **MediaMTX** (which serves WHIP/WHEP) is the cheapest real path and is entirely Windows-native (**medium-high**);
  **Selkies-GStreamer** and **Neko** are Linux/container WebRTC desktops, good references but not a Windows host
  (**medium**); **Sunshine has no official web client** and I know of no maintained browser client for it (**medium**);
  **Parsec** is the closed, working alternative with its own UDP transport (**high**).
- **Per-frame numbers the browser gives you** (**high**, this is the WebRTC/MDN standard, not a product claim):
  `RTCPeerConnection.getStats()` on inbound video gives `framesReceived`, `framesDecoded`, `framesDropped`,
  `totalDecodeTime` (divide by `framesDecoded` for mean decode), `jitterBufferDelay` and `jitterBufferEmittedCount`
  (divide for mean buffer delay), `packetsLost`, `jitter`; and `HTMLVideoElement.requestVideoFrameCallback()` gives
  `presentationTime`, `expectedDisplayTime`, `processingDuration` and `presentedFrames` per frame. That is the whole
  measurement story for the later path, and it is the reason to prefer it over Moonlight for our own numbers.

## 7. Alternatives, one line each

- **Parsec:** closed source, paid tiers, excellent latency, no protocol control and no per-frame export — a demo, not a
  test bed.
- **Steam Remote Play:** Steam-only (non-Steam shortcuts work), clients on many TVs via the Steam Link app, but latency
  and stats are not ours to change.
- **Apollo** (Sunshine fork, community): Sunshine plus virtual displays and per-client settings — the fix for section 1's
  headless problem if we run without a monitor.
- **Wolf** (games-on-whales): a Docker streaming stack for Linux with Moonlight-style clients; no Windows host, so it is
  out for this PC.
- **NVIDIA GameStream:** gone — NVIDIA ended it and pointed people at GeForce NOW; Sunshine exists because of that.
- **Amazon GameLift Streams:** cloud streaming of your own Windows app with a browser client; per-stream-hour pricing and
  a cloud-only setup, more than a 2-day test needs.
- **Stadia-style SDKs / Azure streaming SDKs:** Stadia is dead and the Azure equivalents are enterprise media services,
  not a drop-in for a Unity/Flutter window.

## 8. Measuring end to end cheaply

- **Slow-motion phone camera on both screens** — film the host monitor and the client screen together with a
  millisecond clock on the host (a web page with a big ms counter), step frame by frame, difference the two readings at
  the same instant. One phone, no hardware, about a minute per measurement. **medium-high**; the technique is standard,
  the page explaining it is one fetch away.
- **NVIDIA LDAT / Reflex Analyzer** — a light sensor plus software that gives click-to-photon, so it measures the whole
  chain including the display; needs the kit (hundreds of euros) and NVIDIA's tooling. **medium**.
- **An Arduino/photodiode rig** does the same as LDAT for a few euros if we want repeated numbers rather than one.
  **medium**.
- A display lag tester (Leo Bodnar) measures the monitor, not the stream, so it does not answer this question. **medium**.

## Corrections to Claude's assumptions

1. **RTX 3080 and AV1:** confirmed — Ampere encodes H.264 and HEVC only, AV1 encode is RTX 40 and later. No correction.
2. **"Streams the game's window":** likely wrong. Sunshine captures a display; single-window capture is not something I
   would plan on. If the test needs only the game visible, run it full-screen on the host and hide everything else, or use
   a second display / virtual display. This is the assumption to check first.
3. **"1–2 day path"** is fair for Sunshine + Moonlight on this PC, with three caveats: the host must be on a display
   (or have a virtual one), audio needs a device to capture, and the client numbers cannot be exported — so plan the
   measurement around the slow-motion camera, not around the overlay.
4. **"A WebRTC browser client for the TVs Moonlight can't reach":** smaller than it sounds. The webOS/Tizen TVs already
   have a community Moonlight client, and Roku/tvOS cannot run a browser at all. The WebRTC path is worth doing for its
   `getStats` numbers and for platform independence, not for reaching new TVs.
5. **GeForce NOW** cannot run our app: catalogue games only. Correct as guessed.

## Not confirmed (and what would confirm it)

- Current Sunshine version, its Windows installer names, and whether it has window capture or an API for timing.
- Whether any Moonlight client can log or export its overlay numbers.
- Which Moonlight clients are on which stores in 2026 (especially Fire TV, and whether the iOS/tvOS apps still exist as
  named).
- Every cloud price in section 5, and whether Windows images include the licence on each host.
- Tizen/webOS WebRTC support by model year, and Roku's "no WebRTC" claim from a primary source.
- Every latency figure in section 3 — I have no page behind any of them.

## Fetch list (one page each, in this order)

```
https://api.github.com/repos/LizardByte/Sunshine/releases/latest
https://docs.lizardbyte.dev/projects/sunshine/latest/
https://github.com/LizardByte/Sunshine
https://raw.githubusercontent.com/LizardByte/Sunshine/master/LICENSE
https://github.com/LizardByte/Sunshine/issues?q=capture+window
https://github.com/ClassicOldSong/Apollo
https://github.com/moonlight-stream/moonlight-qt/releases/latest
https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide
https://moonlight-stream.org/
https://github.com/mariotaku/moonlight-tv
https://play.google.com/store/apps/details?id=com.limelight
https://apps.apple.com/app/moonlight-game-streaming/id1000551566
https://www.nvidia.com/en-us/geforce/news/geforce-gtx-30-series-nvenc-encoder/ (Ampere decoder/encoder tables)
https://aws.amazon.com/ec2/pricing/on-demand/ (g4dn, g5, g6)
https://azure.microsoft.com/en-us/pricing/details/virtual-machines/windows/
https://cloud.google.com/compute/gpus-pricing
https://www.paperspace.com/pricing
https://tensordock.com/pricing
https://vast.ai/pricing
https://shadow.tech/
https://www.nvidia.com/en-us/geforce-now/
https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/getStats
https://w3c.github.io/webrtc-stats/
https://developer.mozilla.org/en-US/docs/Web/API/HTMLVideoElement/requestVideoFrameCallback
https://github.com/bluenviron/mediamtx
https://obsproject.com/kb/whip-output
https://github.com/selkies-project/selkies-gstreamer
https://github.com/m1k1o/neko
https://parsec.app/
https://github.com/games-on-whales/wolf
https://aws.amazon.com/gamelift/streams/
```

## Decisions

- Low-usage mode was on, so I did not stop to ask; the brief says to mark unverified facts instead. With every fetch
  refused I applied that to the whole report rather than dropping the job, and put the fetch list in so the work is cheap
  to finish.
- I kept the numbers that matter for a decision (AV1, licence, ports, which platforms have a client) and hedged the ones
  that move weekly (versions, prices, latency). Where I could not even name a client (Roku, browser) I said so rather
  than inventing one.
- Assumption: "Thumb Party" here means the Windows TV app plus phones as input, so the streaming test compares Sunshine's
  window against the app's own rendering path; nothing below depends on that.

## Questions for you (Claude)

1. If Sunshine cannot capture a single window, is a full-screen host acceptable for the 2-day test, or is window capture
   the actual requirement? That answer changes the recommendation.
2. Do we need per-frame client numbers from the test, or is glass-to-glass by camera enough? If per-frame, the WebRTC path
   is the only one with a real stats API, and Moonlight cannot supply it.
3. Is a smart TV (LG/Samsung) in the test set? If not, the community Moonlight clients matter less and the PC/phone/Apple
   TV clients carry the test.

## Commit message

```
Add M15 research: Sunshine + Moonlight streaming stack, unverified

Every fetch was refused in this job's environment, so the report is a
clearly-labelled memory baseline rather than a checked survey: per-fact
confidence, the pages that would settle each line, and what is still open.
It confirms the RTX 3080 has no AV1 encoder, flags that Sunshine captures a
display rather than a window, and notes that a WebRTC browser client reaches
the TVs Moonlight already covers rather than the ones it misses.
```

## Status row

- M15 streaming research: an unverified baseline report (Sunshine, Moonlight clients, cloud hosts, WebRTC stats, measurement) and a 32-URL fetch list are in `docs/briefs/m15/research-stream-stack-report.md`; **open:** every fact needs one fetch pass (no page could be read on Nov 11, 2026), and the window-vs-display question decides the 2-day plan.

## Delete

- none
