# Thumb Party streaming: proposal (M15 research)

**Superseded Nov 11, 2026 by streaming-custom.md: the owner chose a custom stack. Kept for the comparison and the measuring ideas.**

Status: proposal for the owner, Nov 11, 2026. Sources: docs/briefs/m15/scan-stream-touchpoints-report.md (the code and PRD scan, file:line evidence), docs/briefs/m15/research-stream-stack-report.md (tool notes, from memory: the worker had no web access), and Claude's own checks of the three facts the plan rests on (marked ✔ with a link).

## 1. The proposal in one paragraph

Run the Windows TV app we already ship on the RTX 3080 PC, and stream its screen with **Sunshine** (free, open source, uses the card's NVENC encoder) to the free **Moonlight** client apps on TVs, phones and tablets. The phone controller is untouched: it already talks to the PC over its own connection, and already drives every menu. That gives a playable streamed Thumb Party on day 1 with almost no new code. On day 2 we connect the stream's timing numbers to our own stats, so one report shows input, host, encode, network, decode and display. A Thumb Party client of our own (video inside our app, a browser client for more TVs) and a cloud GPU host come after the test, and only if the numbers say streaming feels good.

## 2. Why this route

| Option | Time to a test | Risk | Why / why not |
| --- | --- | --- | --- |
| **Sunshine + Moonlight (proposed)** | 1–2 days | Low | Mature, built for exactly this, clients exist for most of the owner's device list, exposes per-stage timing. No game code needed |
| Our own WebRTC streamer and clients | 2–4 weeks | Medium–high | The right long-term shape (one app, per-frame stats, browsers on LG/Samsung), but capture, hardware encode, signalling and five client platforms are each real work. Do it after the test proves the feel |
| Parsec / Steam Remote Play | 1 day | Low | Closed, no access to timing data, fewer TV clients. Fails requirement 3 |
| GeForce NOW and similar | — | — | Cannot run our own app (catalogue games only) |
| PRD's v3 idea: the phone hosts and streams video | weeks | High | Needs hardware encoding on both phone platforms. A PC/cloud host is far easier and is what the owner now asks for |

## 3. What already exists (from the scan)

- **The stream source.** The Windows TV app is an ordinary GPU-drawn window with sound on the default device: nothing blocks capture. Two small gaps: it has **no fullscreen mode** (a 1280×720 window with a title bar) and **the game stalls if its window is covered or minimised**, so it must stay visible on a display.
- **The controller.** Works as is. The phone finds the PC by itself on the same Wi-Fi, or by a typed address (IP, IP:port or host name). The 4-digit code is only a password. Every host screen can be driven from the phone, so the client device needs **no input at all**: it only shows the picture (which includes the pairing code).
- **Latency stages (S7).** Stage names are open end to end: the protocol, the session summary and the upload all keep any stage name. Today's four are input sent→received, received→drawn, touch→frame and frame jitter. New stages need only someone to report them, plus rows in the report and the TV's latency screen.
- **The phone as its own screen.** The controller app already draws the game under translucent controls. A video surface would replace one painter (later phase).
- **Streaming-ready rules S1–S9**: all met except S3's `display` role, which is reserved but not implemented.

## 4. Day 1: play it streamed (no stats yet)

1. **One small code job** (flash-worker, about 2 hours): a **fullscreen 1080p mode** for the Windows TV app (a launch flag and F11; borderless, 1920×1080, 60 frames a second), so the stream shows only the game.
2. **Install Sunshine on the PC** (owner approves the install; `winget install LizardByte.Sunshine`; current release v2026.914 ✔). Settings: NVENC, HEVC with H.264 as the fallback (the 3080 has no AV1 encoder), 1080p60, about 20 Mbps on home Wi-Fi/Ethernet.
3. **Install Moonlight on the clients** and pair each with the PC (a one-time PIN):

| Screen | Client today | Notes |
| --- | --- | --- |
| Android TV / Google TV | Moonlight, Play Store (official) | The main TV for the test |
| Android phone / tablet | Moonlight, Play Store (official) | |
| iPhone / iPad | Moonlight, App Store (official) | |
| Apple TV | Moonlight, App Store (official) | |
| Windows / Mac laptop | Moonlight (official desktop client) | **The measuring client** (it logs timings, section 5) |
| LG webOS | moonlight-tv (community, needs the TV's developer mode) | Try if the owner has one; not day 1 |
| Samsung Tizen | community ports only | Same |
| Roku | none | No low-latency video on Roku at all; out of scope until a different technique is worth it |

4. **Play:** start the TV app fullscreen on the PC, open Moonlight on the TV, connect phones with the Thumb Party controller as today (same Wi-Fi). Sound comes through the stream.
5. A short setup guide (docs/streaming.md) so the test can be repeated.

What can go wrong on day 1, and the answer: the PC's monitor must stay on with the game on it (a cheap HDMI dummy plug or a virtual display fixes that later); Wi-Fi quality on the TV decides most of the feel (use Ethernet on the PC at least).

## 5. Day 2: latency at every stage, in our own stats

**Where each stage comes from**

| Stage | Meaning | Source | Exists? |
| --- | --- | --- | --- |
| input | phone press sent → received by the host | our `sent_to_received` | Yes |
| host | received → the frame with that input drawn | our `received_to_drawn` | Yes |
| encode | frame captured → encoded and sent | Sunshine's "host processing latency", which Moonlight receives per frame | New |
| network | host → client | Moonlight's "average network latency" | New |
| decode | packet arrived → frame decoded | Moonlight's "average decoding time" | New |
| display | decoded → on the glass | Moonlight's "frame queue delay" + "rendering time (including V-sync)" | New |

✔ Moonlight's desktop client writes exactly these numbers to its log file when a stream ends ("Global video stats": host processing latency min/max/average, network latency, decoding time, frame queue delay, rendering time, dropped frames). The TV and phone clients show the same numbers in their on-screen overlay but don't save them.

**The job** (flash-worker, about half a day): a small tool that reads Moonlight's log after a session and files the four new stages into that session's summary (as `stream_encode`, `stream_network`, `stream_decode`, `stream_display`, in a session-level "stream" record, since the client isn't a player); new columns in the stats report and rows on the TV's latency screen; and a **latency test card** in the TV app (a block that flips colour on a press, with a running clock) for filming.

**How we measure**
- **Per stage, automatically:** on a laptop running Moonlight (same network as the TV), every session.
- **On the real TV, by hand:** read Moonlight's overlay on the TV for encode/network/decode (two minutes per test), and film the phone and the TV together in slow motion (240 frames a second gives about 4 ms steps) using the test card. That is the honest glass-to-glass number, and it checks that the stages add up.

**What to expect** (from experience with this stack; to be replaced by our measurements): on a home network, encode 4–8 ms, network 1–5 ms, decode 5–15 ms (TV boxes are the slow end), display 8–20 ms. Added to today's input and host stages, a press should reach a streamed TV in roughly **60–80 ms**, against about 25–35 ms on a directly connected TV today. The PRD's 50 ms target was written for a direct screen; for streaming I propose a target of **under 80 ms on a home network**, judged by how Shape Race and the Bumper Round feel in the test.

## 6. After the test (not in the 1–2 days)

1. **Away from home.** The controller needs to reach the PC. Use **Tailscale** (a free private network app on the PC and the phone): the controller's typed-address path already accepts it and nothing is exposed to the internet. Moonlight works over it too. No code. The PRD's "no internet play" rule stays intact for open ports.
2. **Cloud GPU host (the nice-to-have).** The same Windows build plus Sunshine on a rented GPU machine, reached over Tailscale. Open questions to settle with a half-day trial: Flutter needs a display on a machine with no monitor (a virtual display driver), and the price (roughly $0.50–1.20 an hour for a T4/A10-class card: unverified). The delay will be the home numbers plus the internet round trip.
3. **Our own client (the product path).** If the feel is good: a `display` role in our protocol (S3 reserves it), video inside the Thumb Party apps with the controls on top, per-frame timing from the player itself, and a browser client for LG and Samsung TVs. This is weeks, and its design should use the test's numbers.
4. **Roku.** Needs a different approach (it only plays buffered video). Revisit only if Roku matters commercially.

## 7. Risks

| Risk | How likely | Answer |
| --- | --- | --- |
| The game stalls when its window isn't drawn | Certain if minimised | Fullscreen on a live display for the test; virtual display later |
| TV Wi-Fi adds stutter | Likely on weak Wi-Fi | PC on Ethernet, TV on 5 GHz or Ethernet; Moonlight's overlay shows it at once |
| TV/phone Moonlight clients can't export timings | Certain | The laptop client logs them; TVs are read from the overlay and the slow-motion film |
| Streaming feels too slow for the fast games | Possible | That is what the test is for; Shape Race should be fine, the Bumper Round is the hard case |
| Sunshine is GPL software | — | We run it beside our app, we don't ship or link it. A product client later must not copy its code |

## 8. Decisions needed from the owner

1. Go with Sunshine + Moonlight for the 1–2 day test?
2. May Claude install Sunshine on the PC (one `winget` command), and Moonlight on this PC as the measuring client?
3. Which client devices are on hand (Android TV, Apple TV, iPhone/iPad, Android phone/tablet, LG, Samsung, Roku)?
4. Is "under 80 ms on a home network" the right streaming target to test against?
5. Roku out of scope for now?
