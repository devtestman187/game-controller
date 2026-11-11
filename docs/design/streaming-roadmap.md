# Thumb Party streaming: from prototype to production

Status: plan, Nov 11, 2026. Companion to streaming-custom.md (the stack and the measurements). Each phase ends at a **gate**: a short list of things that must be true before the next phase starts. If a gate fails, the phase's "if not" line says what to do instead. Time estimates assume the working method in docs/briefs/m15/STATUS.md (flash-worker builds, Claude designs and reviews).

## Phase 0. Feasibility (done, Nov 11, 2026)

Proved on the owner's PC (RTX 3080, Windows 11, WSL2): the TV app builds for Linux; in a GPU container it draws the Arena at 58–60 frames a second at 1080p; gst-wayland-display + NVENC gives 60 encoded frames a second with sound and about 8 ms from capture to encoded frame; two sessions run at about 45 frames a second each; `webrtcsink` builds and starts. Reports: docs/briefs/m15/*-report.md.

## Phase 1. Prototype (M15): one household, home network

Steps 1–3 of streaming-custom.md §5, all in WSL2 containers on the PC.
- **Build:** the session container image (compositor, game, encoder, sound, `webrtcsink`); a web player page; the handshake over our WebSocket (the `display` role); the automation interface (design §6a) so a session starts and reports "ready" with no person; the four new latency stages (encode, network, decode, display) in the session stats and report; a latency test card; encoder settings pinned and tuned.
- **Gate 1:**
  1. A family plays Shape Race and a Bumper Round on a TV browser and on a laptop, with phones as controllers, on home Wi-Fi.
  2. All six latency stages appear in one report for that session.
  3. A press reaches the screen in **under 80 ms** on the home network (filmed and from the stats), and play feels good to the owner's family.
  4. Thirty minutes of play with no stall, no drift between sound and picture.
- **If not:** if the delay is the problem, tune (phase 1 step 3) and, failing that, compare with a Sunshine + Moonlight baseline (cloud-streaming.md) to learn whether the limit is our stack or the idea. If the feel is wrong even at low delay, stop: streaming video is not right for these games, and the snapshot path (below) becomes the product.

## Phase 2. Internet and real Linux

- **Build:** the same image on real Linux with NVIDIA's own driver (a rented cloud GPU): the zero-copy capture path, capacity per GPU measured; a relay (coturn) and connection setup that works through home routers; **security before anything is exposed**: encrypted control link (wss), a signed session ticket instead of only a 4-digit code, rate limits, no open ports on the PC; adaptive bitrate checked on a poor connection; the phones' input moved to WebRTC's fast channel if the numbers call for it.
- **Gate 2:**
  1. A household plays from a different network than the server (and one on mobile data) with a relay in the path at least once.
  2. Under **120 ms** press-to-screen within the same region; the stream recovers from a 2-second network drop without a restart.
  3. One cloud GPU holds a measured number of 1080p60 sessions (target: 8 or more on a T4/L4-class card); cost per session-hour computed from real prices.
  4. A short security review passes (worker first, Claude verifies): no unauthenticated control, no secrets in the image, containers isolated from each other.
- **If not:** if a cloud GPU holds too few sessions, drop to 720p or move drawing off the GPU for our 2D games; if relay costs dominate, restrict relays to paid tiers or regions.

## Phase 3. Several households (the session service)

- **Build:** the session service: create a session → place it on a machine with room → start the container → hand back a code and ticket → clean up when the household leaves or goes idle; a warm pool so a session starts in a few seconds; health checks through the automation interface; per-session logs and stats; the "Play online" entry in our apps with automatic fallback to local play (owner-approved UX); the TV app's "Play online" mode and the phone app's video-under-controls view (flutter_webrtc).
- **Gate 3:**
  1. Two households play at once from different homes, each with its own code, with no cross-talk; a third starts while the first two play.
  2. A session starts in under 10 seconds from "Play online"; an abandoned session is cleaned up within 5 minutes.
  3. When the service or the network is down, the apps fall back to local play with a plain message.
  4. The stream plays inside the Android TV app and on a phone, not only in a browser.
- **If not:** keep one session per PC for demos and stay a single-household product until the service is solid.

## Phase 4. Closed beta

- **Build:** deployment as code (the images, the service, the relay) on one cloud region; autoscaling on a simple rule (sessions waiting, GPUs idle) using k3s + Agones or the provider's own tools, whichever phase 3 showed is enough; monitoring and alerts (session starts, failures, delay percentiles, GPU and relay use, cost per day); crash and error reporting; a budget cap that stops new sessions rather than overspending; privacy review (what the stream and the stats record; the privacy page; the children's-app rules already followed in docs/families-check.md); LG/Samsung browser checks by model year; tester onboarding in the tester guide.
- **Gate 4:**
  1. Ten or more outside households have played; session-start success above 95%; median press-to-screen delay and its worst 5% published in the report.
  2. A week with no manual intervention; a bad release can be rolled back in minutes.
  3. Cost per session-hour is known and has a ceiling.
- **If not:** fix the top failure causes from the data before widening.

## Phase 5. Production

- **Build:** more regions chosen from where testers are (delay is mostly distance); capacity planning and a waiting message when full; accounts or a light household identity only if the product needs them (the PRD has none today); payments only if online play is a paid feature; store packaging for the web player on LG/Samsung, a small Apple TV player; support and status pages; licences reviewed for everything shipped (GStreamer LGPL, no GPL encoders, gst-wayland-display MIT, coturn BSD); load test at several times the expected peak; an incident routine.
- **Gate 5 (launch):** the beta numbers hold at the load-tested scale; legal, privacy and store reviews pass; the owner decides.

## Running beside all phases: snapshot streaming

For screens that can run our game code (Android TV, phones, tablets, Windows), the server can send game state instead of video: no encode or decode delay, a fraction of the bandwidth and no GPU on the server. The apps already do this for joined phones. It is the cheaper path for our own games and should be prototyped after gate 1; video stays for screens that can't run the game and for the learning goal. If streaming video fails gate 1 on feel, this path alone is the online product.

## What stays true throughout

Local play never depends on the server ("local first, online when needed"). Automation and control features are built once in the shared host code for every build (design §6a). Builds, tags and tester promotion happen only on the owner's word. Each phase gets its own milestone, branch and STATUS file; M14-style bug fixes on older branches are merged forward.
