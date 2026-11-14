# Native viewer: what exists and what can be reused (Nov 13, 2026)

Read-only inventory of branch m15. Paths are from the repo root. "Not confirmed" marks anything I did not verify in code or a record. Main sources: streaming/README.md, streaming/entrypoint.sh, streaming/player/*.js, streaming/tap/*, docs/briefs/m15/opt2/PROTOCOL.md, docs/protocol.md, docs/design/streaming-*.md.

## 1. The stream stack as built

**Pipeline** (streaming/entrypoint.sh, capture_words / webrtc_branch). One container per household session, run with --network host.
- waylanddisplaysrc (render-node=software on WSL2) -> caps 1920x1080@60 -> videoconvert -> [NV12 caps only when the tap is on] -> nvautogpuh264enc -> h264parse config-interval=-1 -> webrtcsink.
- Sound: PulseAudio null sink "party" -> Opus. Default `SESSION_AUDIO=joined` puts it in the same webrtcsink. `separate` (opt2-5) runs it as a second gst-launch with its own webrtcsink "ws-audio" and its own peer connection.
- Also in the container: the TV app (Linux build of tv_test_app), gst-webrtc-signalling-server, player/serve.py (HTTP relay), a stream sampler. entrypoint.sh prints the `ready:` line once the game home screen is up and the pipeline has registered.

**Encoder settings** (entrypoint.sh ~lines 387-420, README "The picture's settings"): bitrate=video_kbps, rate-control=cbr, gop-size=60 (a keyframe a second, `SESSION_GOP_FRAMES`), b-frames=0, zero-reorder-delay=true, preset=p1, tune=ultra-low-latency, rc-lookahead=0. Wire ceiling 10000 kbit/s (`SESSION_BITRATE_KBPS`); the encoder gets about 4716 kbit/s with FEC on. webrtcsink: do-fec=true, do-retransmission=true, congestion-control=disabled (gcc tested; homegrown panics). Tap on adds a VBV of about 3 frames and strict-gop. Profile with tap on: avc1.42C02A (NV12 forced; without it NVENC made 4:4:4, avc1.F4002A, which Safari cannot decode).

**Signalling.** The stock gst-plugins-rs signalling (gst-webrtc-signalling-server: WebSocket, JSON, producer/consumer roles), not our protocol. Listens 0.0.0.0 on `SIGNAL_PORT` (8443 default; 45781 under tools/stream.sh). webrtcsink registers as producer (`signaller::uri=ws://127.0.0.1:$signal_port`), with meta `TP-Picture` / `TP-Sound` in separate mode. The page uses the gstwebrtc-api JS bundle (streaming/player/player.js ~line 339, streams.js): list producers, start a consumer session. The producer (webrtcsink) makes the offer and the viewer answers; this is standard webrtcsink behaviour, not read from our code (not confirmed). The exact signalling JSON messages are not in this repo; a Dart client must implement them from the gst-plugins-rs 0.13.6 protocol or use a library.

**Session lifecycle.** `tools/stream.sh up|down|status|url|bench` start and stop a named container. Producers register when the game is up; viewers may join at any time and reconnect on producerAdded/Removed. A page that played and then lost the stream for 15 s shows "The stream has ended" and stops (README "The player page"). `SESSION_ID` (in config.js) lets the relay tell a page of an old session from this one's.

**How a viewer joins.** Open `http://<PC LAN ip>:<PLAYER_PORT>/` (45782 under stream.sh, 8080 default). The page reads `config.js` (written by entrypoint.sh: signalingPort, splitTracks, sessionId, options) and connects to `ws://<same host>:<signalingPort>`. No token, no pairing, no code: anyone on the LAN with the address can watch. `tools/stream.sh url` prints it. Phones as controllers are separate: they pair with the game on controller port 45780 (4-digit code, then a saved token, docs/protocol.md section 5). Nothing links "who watches" to "who plays".

**TURN / outside LAN: not wired.** The page sets `webrtcConfig: { iceServers: [] }` (player.js ~line 344, comment "No STUN"). No coturn, STUN or TURN in streaming/Dockerfile, entrypoint.sh, serve.py or the page (grep found nothing). Signalling and the player port are plain ws/http. docs/design/streaming-roadmap.md phase 2 plans coturn, wss, signed session tickets and rate limits; none built. Outside-LAN viewing does not work today.

**The tap path** (M15 opt2, default off; docs/briefs/m15/opt2/PROTOCOL.md; streaming/tap/*.py):
- `SESSION_TAP=on` runs the pipeline in Python (tap_runner.py) with a tee after the encoder; tap branch: `queue leaky=downstream max-size-buffers=2 ! h264parse config-interval=-1 ! appsink drop=true max-buffers=2`.
- Transport: WebSocket on path `/tap` of the player port; serve.py forwards it to the tap server on loopback `TAP_PORT` (automation port + 1). Plain TCP, no TLS.
- Frame message (binary): 24-byte big-endian header: 'T', version 1, flags (bit0 keyframe, bit1 discontinuity), reserved, u32 frame number, u64 pts_us, u64 sent_us (host wall clock, microseconds). Then one access unit in Annex B (AUD first, SPS+PPS before each IDR). JSON text from the server: `hello` (version, width, height, fps, profile) and `end`.
- Client to server: `{"type":"key"}` asks for a keyframe (one outstanding per client, at least 1.5 s apart, encoder takes one force-key-unit at a time, 2.5 s timeout); `{"type":"stats","queue":N}` is ignored.
- Drop rules: per-client queue of at most 4 frames; overflow clears it, waits for a keyframe, and the next frame carries the discontinuity flag; frames older than 2 frame times (34 ms at 60 fps) are dropped before sending; a new client starts at the next keyframe; a client whose socket takes nothing for 5 s is closed; small send buffers (96 KiB phone side).
- Sound is NOT in the tap; it stays on a sound-only WebRTC link.

**Separate sound.** Opus over WebRTC (webrtcsink "ws-audio", meta TP-Sound), own process (/run/thumb-party/sound-pipeline.log), picked by the page by meta name (streams.js). There is no non-WebRTC audio path.

**Stats from viewer to host.** The page sends a batch every 2 s to `POST /stats/stream` on the player relay (serve.py), which adds the session token and forwards to the host's automation interface (docs/automation.md "POST stats/stream"). Body: `viewer {kind, platform}` (then a returned viewer id), `stages [{name, ms, fps}]`, `gauges`, `counters`, `facts`, `resources`. Stage names include stream_capture, stream_encode, stream_network, stream_decode, stream_display, press_to_screen (docs/protocol.md section 13; packages/metrics; packages/party_host/lib/src/automation/stream_ingest.dart). The relay accepts anything from anyone who can open the page. The page also posts `/player` state and `/page/error`, and polls `/presses` and `/flips` (reporter.js, serve.py).

**Bench and marker.** `tools/stream.sh bench` (streaming/bench.sh) runs a session with a headless Chrome viewer, or `--viewer external` for a phone that opens the printed URL. Two independent press-to-screen methods: (a) the latency card: the host's test card flips colour on a probe press, the page watches a small patch and posts the flip time (`/flips`); (b) the marker (docs/streaming-marker.md; `SESSION_MARKER=on`, page `marker=1`): 57 cells of 16 px at the picture's top-left (sync, 16-bit frame counter, low 32 bits of the host clock in ms, press-flip cell, 4-bit xor checksum). A cell is the 3x3 centre average: below 80 dark, above 160 light, else the row is unreadable. The page reads it with one getImageData per requestVideoFrameCallback (marker_decode.js, marker_reader.js) and compares with the host clock through an NTP-style offset (clock_sync.js, `GET /clock`, shortest RTT kept, refreshed every 10 s). Presses are injected with `POST /presses`. Host halves: packages/party_host/lib/src/automation/marker_code.dart, marker_decoder.dart, src/ui/marker_strip.dart. Costs: the app repaints 57 cells a frame; the page about 5 ms a frame in headless Chrome.

## 2. The existing apps

| App | Path | Builds for | Notes |
| --- | --- | --- | --- |
| Phone controller (com.thumbparty.app) | controller_app/ | Android, iOS (dirs android, ios). No web, macOS or tvOS dir | flutter_riverpod ^3.4.3, bonsoir ^7.1.5 (mDNS), sensors_plus ^7.1.1, shared_preferences, path_provider, share_plus, url_launcher; local packages connection, protocol, metrics, game_kit, party_host, puzzle_game, test_game. Version 0.14.0+14 |
| TV / host app "tvtest" (com.thumbparty.tv) | tv_test_app/ | Android (TV), Windows, Linux (dirs android, windows, linux). No iOS, tvOS | Same state management; adds toy_look and game_assets. Its Linux build is the game the stream session draws and captures |
| Shared packages | packages/ | Dart and Flutter | connection (WebSocket client and host, transport/*, viewer_stats.dart, rtt.dart), protocol, metrics (stream record and report), party_host (host logic, automation interface, stream_ingest, marker code; uses flutter_soloud), game_kit, toy_look |

Not present in any pubspec: flutter_webrtc, video_player, media_kit, WebTransport, or any platform channel for video or decode (grep of pubspec.yaml files). The only platform channels found are haptics and device status in the iOS AppDelegate (controller_app/README.md). docs/design/streaming-custom.md section 5 step 8 says flutter_webrtc has no tvOS build, so Apple TV would need a native player. No stream video is displayed in any Flutter app yet.

**How apps connect to the host today** (docs/protocol.md): mDNS service `_gamectl._tcp`, then one WebSocket `ws://host:45780/ws`, JSON envelopes `{v,t,...}`, hello/welcome, pair by 4-digit code or saved token, ping/pong each second, input messages. Unencrypted. No relay or bridge for the apps (the "bridge" in my notes is dev tooling, not confirmed in code). Phones can already show the game itself over this link by snapshot streaming (`view` capability: view_start / frame / view_end, protocol section 10a; docs/design/m12-joined-view.md). That is game state, not video.

**CI / release** (docs/release.md, codemagic.yaml; .github release.yml described in docs, not opened): iOS through Codemagic `ios-testflight` on any tag or manual start (mac_mini_m2, signed App Store build, build number = commit count), TestFlight internal first, external group "Testers" only on the owner's word. Android phone and TV through GitHub Actions release.yml to Play closed testing (TV on the Android TV track). Windows TV zip as a GitHub Release. Codemagic check jobs only run when controller_app, packages/protocol or packages/connection change (a new viewer package would need adding to the changeset list in codemagic.yaml). Tags, builds and tester promotion only on the owner's word.

## 3. Reuse, client counterparts, host changes (my reading)

**Reusable as is**
- The whole host stack: capture, NVENC H.264 1080p60, webrtcsink, signalling server, relay, lifecycle, tools/stream.sh, bench, the host's `stats/stream` ingest and the report tables (packages/metrics).
- The tap server and its protocol unchanged, if the native viewer takes video over WebSocket (frame number, pts, host send time, keyframe and discontinuity flags and a keyframe request already exist).
- The controller side: packages/connection and protocol (pairing, tokens, mDNS) for a combined phone app. packages/connection already has a WebSocket client (transport/web_socket_channel.dart).
- The host's marker row, press probe, `GET /clock`, `POST /presses` and `/flips` on the relay.

**Needs a client-side counterpart**
- Video receive and decode: a WebSocket tap client feeding a native hardware decoder (VideoToolbox on iOS, MediaCodec on Android, via platform channel or texture plugin; nothing exists), OR a WebRTC client (flutter_webrtc or native libwebrtc, not in the repo) speaking the gst signalling JSON.
- Display and pacing with a tiny buffer; keyframe-request logic like the page's (500 ms spacing, rebuild on decoder error, draw only the newest frame). Reference code: streaming/player/wc_player.js, wc_decoder.js, wc_annexb.js.
- Sound: nothing outside WebRTC exists, so either a WebRTC audio receiver (`SESSION_AUDIO=separate`) or a new host path.
- Stats reporter: a Dart port of reporter.js / wc_stats.js posting the same JSON to `/stats/stream` on the player port (plain HTTP works with the relay as is). Whether the report accepts a new `viewer.kind` is not confirmed; check stream_ingest.dart.
- Marker reader: port marker_decode.js and clock_sync.js; natively it reads decoded pixels at the top-left. The card probe's patch reader needs the same.
- Finding the stream: the player address is not advertised by mDNS (only the controller port is, protocol section 1), so a native app needs a typed address or a host change.
- tvOS: no Flutter tvOS target in the repo. Android TV exists only for the TV host app, not as a viewer.

**Host changes that might be needed**
- Sound over something other than WebRTC (the tap is video only), if the viewer should avoid a WebRTC stack.
- A transport better than one TCP socket if Wi-Fi loss matters (head-of-line blocking is listed as a gap in README "What it does not do yet"; custom-player-feasibility.md names an unordered DataChannel as the next step; a UDP/QUIC path is not built).
- Auth: signalling and `/tap` are open on the LAN. A signed ticket or token, plus wss and TURN/STUN (coturn), are prerequisites for anything outside the LAN (roadmap phase 2).
- A second offer path is not needed for WebRTC: a native consumer uses the same signaller and producers.
- Optional: advertise the stream address in mDNS or the controller protocol; make the tap reachable without the relay tunnel (today it binds loopback only).
- Codec: H.264 only, no HEVC/AV1; fine for native hardware decoders.

## 4. Docs that already discuss a native viewer or platform targets
1. docs/design/streaming-custom.md step 7 "Our own client": video inside the apps (Android TV, phones, tablets, iPhone, iPad) via flutter_webrtc, 1-2 weeks; step 8 notes Apple TV needs a native player, Roku has no WebRTC, LG/Samsung browser polish.
2. docs/design/streaming-roadmap.md phase 3: TV app "Play online", phone video under the controls (flutter_webrtc); gate 3 item 4: plays inside the Android TV app and on a phone. Phase 5: a small Apple TV player. Phase 2: coturn, wss, signed tickets.
3. Same roadmap, "snapshot streaming": send game state instead of video to screens that run our code (already done for joined phones); the fallback product if video fails on feel.
4. Roadmap gate 1 item 3: 150 ms or less press-to-screen (was 80, changed Nov 13); custom WebCodecs player tried and dropped.
5. docs/briefs/m15/STATUS.md (Nov 13 late night): latency work on the stream ends; next is instant controller feedback; "a native viewer stays a later option"; no tag or release build without the owner's word.
6. docs/streaming-latency-journey.md (Nov 13 conclusion): the owner's open decision listed three routes: custom player (done, dropped), a native viewer, or accept 170-200 ms plus instant controller feedback. About half of Safari's delay is inside Safari.
7. docs/briefs/m15/research/custom-player-feasibility.md: lists "(f) native wrapper" (a native decoder instead of WebCodecs); WebKit ignores optimizeForLatency; Encoded Transform cannot bypass the jitter buffer; web sound is the weak spot.
8. docs/briefs/m15/research/latency-prior-art.md: native figures only (Parsec LAN pipeline 4-8 ms, encode plus decode under 10 ms; GeForce Now about 56 ms click to draw); casual-game tolerance 100-150 ms. None for Safari.
9. docs/briefs/m15/research-stream-stack-report.md: Moonlight client coverage (Android, iOS, tvOS, LG webOS, Tizen); the Sunshine plan was superseded by the custom stack.
10. No document found that scopes a native viewer's design, size or milestone (not confirmed beyond the files above). Nothing yet in docs/briefs/m15/research/ about native viewers.

## 5. Measured facts worth carrying
(Sources: docs/streaming-latency-journey.md "Running notes"; docs/briefs/m15/opt2c/REPORT.md; docs/briefs/m15/STATUS.md.)

- **Host legs:** capture 2 ms; encoder alone 9.2-11.3 ms, but the labelled encode stage reads 29-34 ms in the session (the wait is webrtcsink taking the output, fix6 k1-4); network on the same Wi-Fi about 2 ms; game answers a press in one frame (about 22 ms in the Nov 12 marker baseline sum: game 22 + capture/encode 32 + network 2). Host pipeline time 33-42 ms with sound joined, **8.0 ms** with sound in its own process or off (opt2-5). Capture to encoded: 8 ms mean in the first probe. The tap adds about 38 microseconds to the other branch (opt2-1).
- **Safari, plain WebRTC video element:** press-to-screen 197-225 ms baseline; the marker agreed within 2 ms, so the figure is right; run-to-run spread about 30 ms. Safari's buffer read 35-98 ms and decode-to-display 39-100 ms in identical runs (unstable). `jbtarget=0` gave 182 and 209 ms (Safari keeps about 50 ms). Sound separate: 141, 235 (freezes), 197. No sound: 166-181. No switch beat the noise.
- **What the phone added:** in the Nov 12 table capture-to-screen was 92 ms against press-to-screen 158; in the marker baseline the missing piece was Safari's decoded-to-glass time of about 62 ms (14 ms with sound separate in one run). Phone decode 4-6 ms.
- **Custom player (WebCodecs + tap + separate sound), iPhone Safari 27.2, third sitting Nov 13:** press-to-screen smoke 203; runs 186, 167, 159 and **105 ms (best)**; freezes in 3 of 4 runs, worst 6 freezes totalling 4727 ms with 160 dropped, 3 key requests, one "EncodingError Decoder failure" and a 2348 ms gap; decoder queue max 40; receive-to-decode rose from about 5 to 35-40 ms (not investigated). Same day the current player: 162/159 and 176/176 ms with 0 freezes. Verdict: dropped. Rule was all four at 150 ms or less and no more freezes than the current player.
- **Headless Chrome (not Safari, software decode):** custom player card 101-112 ms, marker within 0-2 ms; current player 259 ms.
- **Capacity and wire:** 12 NVENC sessions at once on the RTX 3080; two sessions about 45 fps each (WSL2 system-memory copy); mean wire rate 6.5 Mbit/s (peak 11.1), 59.8 delivered fps, no loss on home Wi-Fi.
- **Not measured:** any native client; hardware decode on iPhone (isConfigSupported does not prove it); TCP behaviour on a lossy Wi-Fi beyond the one bad run; any outside-LAN path; Android phones or TVs as viewers (all phone numbers come from one iPhone, Safari 27.2).
