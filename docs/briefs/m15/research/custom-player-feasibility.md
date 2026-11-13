# Custom WebCodecs player ("Option 1"): feasibility

Written Nov 13, 2026. Sources: three web-research jobs and one code-reading job, all flash-worker (full reports with URLs in `docs/briefs/m15/opt1/`: `o1-1-web-codecs-report.md`, `o1-2-web-secure-report.md`, `o1-3-probe-report.md`, `o1-4-host-read-report.md`). Pages were fetched 2026-11-13. "primary" = spec, WebKit/MDN/vendor page, bug tracker; "secondary" = blog/forum; "inference" = our reasoning. Nothing here was run on an iPhone.

## Summary

- **Verdict: go with conditions.** Worth one cheap decisive step (the probe page, built, see answer 8) before any build. Do not start a build batch until the owner has opened the probe on the phone.
- **Deciding fact 1 (medium confidence, unverified on device):** WebCodecs is `[SecureContext]` in the spec and in Chrome, but WebKit's own IDL does not carry the gate, so iOS Safari may expose `VideoDecoder` on today's plain `http://192.168.1.124:45782/`. If it does, a Safari LAN prototype needs no certificate. Chrome (Android, desktop) will not; they need https. The probe answers this in seconds.
- **Deciding fact 2 (high):** if Safari does gate it, the only zero-ceremony route for guests is a real domain whose A record points at the LAN IP plus a Let's Encrypt DNS-01 certificate (the Plex pattern): about 10 EUR a year, key on the host, broken by routers with DNS-rebinding protection. A private CA on every guest phone (about 6 taps plus a Settings trust step) is fine only for the owner's own phones. In the cloud, https is normal and the problem disappears.
- **Deciding fact 3 (high):** a custom player removes only the RTP jitter buffer and part of the decode path. Safari ignores `optimizeForLatency` (WebKit bug 325278, open), `isConfigSupported` does not report hardware honestly, decode()-to-output on a WebKitGTK build measured 35 ms median at 1080p60 (bug 329695; Chrome 7.8 ms; no iOS figure exists). Encoded Transform does NOT bypass the jitter buffer. `jitterBufferTarget` arrives only in Safari 27.0 (Sep 2026).
- **Recommended transport:** WebSocket (TCP) for the first slice on the LAN, drop-on-backlog at the sender, video only, sound left on the existing WebRTC path; DataChannel (unordered, `maxRetransmits=0`, 16 KB fragments) as the second step if TCP stalls show on Wi-Fi; WebTransport only later (Safari 26.4+, needs HTTP/3 and https; `datagrams` reported undefined on iOS 26.6, bug 322201).
- **Host side is cheap:** the pipeline already ends `nvautogpuh264enc` (no B-frames, 1 s GOP, Annex B, AUD), `h264parse`, `webrtcsink`; a `tee` to `appsink` in a Python GStreamer sender shares the single encode; the image needs one apt line (`python3-gi`).
- **Expected gain: 20 to 80 ms press-to-screen, most likely 30 to 60** (about 200 down to about 140-170). Not the half that "Safari's share" suggests: display and compositor time stay, and TCP/decoder queueing is added. Inference, low-medium confidence; only a phone measurement settles it.
- **Effort:** 7 flash phases of 100-140 turns; first slice (host tap, page decoder and canvas, WebSocket, marker, bench) is phases 1-4. Add 1-2 phases if https is needed.
- **Sound** is the weak spot: Web Audio is muted by the iPhone silent switch unless `navigator.audioSession.type="playback"`; `AudioDecoder` only on iOS 26+; AudioWorklet is secure-context only. Keep sound on a separate WebRTC media connection.
- **Next step:** open `/probe.html` on the iPhone (answer 8). If `VideoDecoder` is present on http and 1080p60 H.264 is supported, authorise the first slice; if absent, decide whether the https route (a domain) is acceptable.
- **No-go triggers:** VideoDecoder absent on http and no wish for a domain/cert; or a phone prototype showing under about 30 ms gain.
- Side finding: if the owner's iPhone is on iOS 27, `RTCRtpReceiver.jitterBufferTarget` could be tried at once on the existing player (one-line experiment, not tested).

## 1. WebCodecs on iOS Safari (high unless marked)

- `VideoDecoder`/`VideoEncoder`: Safari/iOS 16.4 (2023-03-27), video only. `AudioDecoder`/`AudioEncoder`: Safari 26.0 (2025-09-15). MDN compat data, WebKit blog posts 13966 and 17333, caniuse. Primary.
- H.264 (`avc1.*`) is supported and decodes via VideoToolbox, normally hardware. Primary.
- `optimizeForLatency` is parsed but never forwarded; bug 325278 (2026-09-25, NEW) asks for the VideoToolbox real-time key. `isConfigSupported` echoes your config and only checks that a decoder can be created, so it is no evidence of hardware use. Primary.
- After `configure()`, `reset()` and `flush()` the next chunk must be a key frame (`DataError`). With `description` the stream must be AVCC; without it, Annex B with in-band SPS/PPS. WebKit's Annex B path is unverified (medium); the safe choice is to convert to AVCC with a description built from the SPS/PPS, a small job in the page.
- Output delay: WebKit decoders do their own reordering (bug 279753, open). Avoid it with no B-frames and `num_reorder_frames=0`; our encoder already sets `b-frames=0 zero-reorder-delay=true`. WebKitGTK measured 35 ms median decode()-to-output at 1080p60 without B-frames (output collected on the next decode call plus a 2-frame decoder delay); `texImage2D(VideoFrame)` cost about 10 ms there. These are GTK numbers (iOS inference, low-medium).
- Chrome: hardware H.264 holds output until the next keyframe on long GOPs (Chromium issue, title only); our 1 s GOP is mild.
- Android Chrome and desktop Chrome: VideoDecoder since Chrome 94, hardware, `[SecureContext]` enforced, so https is needed there even for a prototype. Desktop Chrome is the place to develop the player.

## 2. Secure context

- Secure means https, wss, file, or loopback (127.0.0.0/8, ::1, localhost, *.localhost). No exception for private IPs or `.local` in Safari or Chrome (primary, high). Clicking through a certificate warning does not make a page secure, and iOS gives no click-through for an untrusted certificate.
- WebCodecs is gated by spec and Chrome; WebKit's IDL is not gated (primary source, medium; the probe tests it). WebTransport and AudioWorklet are gated everywhere.
- DataChannel and WebSocket work in an insecure context on Safari (neither IDL is SecureContext; primary, high).

| Option | What a guest does | What the host owner does | Verdict |
|---|---|---|---|
| (0) plain http, if Safari allows VideoDecoder | nothing | nothing | best for a Safari-only LAN prototype; Chrome will not work |
| (a) private CA or self-signed on the LAN IP | install a profile, then Settings > General > About > Certificate Trust Settings (about 6 taps, scary warning) | make a CA and a cert (Apple's 398-day cap does not apply to user roots; keep the leaf at or under 397 days to be safe) | fine for the owner's own phones, bad for guests |
| (b) own domain, A record to the LAN IP, Let's Encrypt DNS-01 | open `https://name/` | domain (about 10 EUR a year), DNS API token, renewals (60-90 days now, shrinking to 47 by 2029), DHCP reservation, key on the host | best guest UX; fails behind routers with DNS-rebinding protection; guests on cellular cannot reach it |
| nip.io, sslip.io, IP-literal public cert | not possible: public CAs cannot issue for private IPs and we do not control those zones | | dead end |
| (c) mDNS `.local` | | | no public certificate possible |
| (d) hosted https page talking to the LAN host | Safari blocks http/ws to a LAN IP from an https page (mixed content); Chrome 142+ asks a Local Network Access permission; wss needs a cert for a name resolving to the LAN IP, which is option (b) again | | not a shortcut |
| (e) cloud relay | | | adds a trip; that is the cloud product |
| (f) native wrapper | | | a native app would rather use a native decoder than WebCodecs |

- Recommendation: LAN party now, Safari prototype: try (0). If the probe says gated, use (b) for the owner's test or (a) for the owner's own phones. For the cloud product, normal https. For guests on any platform, plain WebRTC video stays the zero-ceremony default.

## 3. Transports on iOS Safari

- **WebSocket**: TCP head-of-line blocking; on a clean LAN small, on lossy Wi-Fi a retransmit stalls everything behind it. Mitigation: the sender drops frames when the backlog grows; the page reports receive lag. Works insecure.
- **DataChannel unordered/unreliable**: `ordered:false, maxRetransmits:0` maps into libwebrtc; read `pc.sctp.maxMessageSize` (64 KiB assumed when absent); fragment keyframes (20-100 KB) into 16 KB messages with a frame id; a lost fragment means dropping the frame and waiting for the next IDR. Works insecure. Needs a webrtcbin-style sender: `webrtcsink` has no custom-payload data channel, so the host build is larger than WebSocket.
- **WebTransport**: Safari/iOS 26.4 (2026-03-24); https only; HTTP/3 server needed (no aioquic or quinn plugin in the distro); `maxDatagramSize` fixed at 1024 in WebKit; `serverCertificateHashes` only for dedicated transports; `datagrams` undefined on iOS 26.6 (bug 322201). Not for the first slice.
- **Encoded Transform, MediaStreamTrackProcessor, requestVideoFrameCallback (keep WebRTC media)**: `RTCRtpScriptTransform` (Safari 15.4+) runs after depacketisation and the jitter buffer (libwebrtc: packet buffer, then frame transformer), so it cannot bypass the buffer. rVFC only reports. `jitterBufferTarget` from Safari 27.0 (2026-09-17, primary); `playoutDelayHint` is absent in WebKit.

## 4. Prior art (mostly secondary; no iOS figures)

- Selkies uses WebCodecs over WebSockets by default (1080p60). MoonlightWeb: WebCodecs video plus WebRTC audio only, claims under 20 ms on Wi-Fi and iPhone Safari working (claim). A WebCodecs plus WebTransport experiment (webrtcHacks, 2023): 140 ms glass-to-glass at 36 ms RTT, low resolution. A MediaMTX user: browser WebRTC in Safari 100-200 ms against native Parsec 25 ms on the same Wi-Fi (secondary). Helix reports 20-30 ms lower than WebRTC (claimed, no absolute figure).
- Cloud gaming on iOS: GeForce NOW, Xbox and Boosteroid all say to use Safari; I found no primary statement that any uses WebCodecs; the evidence points to the WebRTC receiver (inference, low). No measured WebRTC-video versus WebCodecs-canvas comparison on iOS was found.

## 5. Sound

- iOS: Web Audio defaults to the ambient channel and is silenced by the mute switch; `navigator.audioSession.type = "playback"` (iOS 17+) fixes it (WebKit engineer comment, secondary-ish). A user gesture is needed to start an AudioContext. AudioDecoder needs iOS 26+; AudioWorklet needs a secure context. iOS output latency figures were not found as primary data (unverified); the probe's Test audio button reads `baseLatency` and `outputLatency` on the phone.
- Options: (1) a second WebRTC connection for sound only, in a media element (the MoonlightWeb pattern; not muted by the switch; the repo already has `SESSION_AUDIO=separate`); (2) AudioDecoder plus Web Audio (iOS 26+, secure only); (3) PCM over WebSocket. Pick (1) for the first slice. Lip-sync: sound no longer holds video back, so video arrives early; anchor on one host clock (the marker carries it), add a measured offset, keep audio 20-40 ms early rather than late (webrtcHacks experience; secondary).

## 6. Host side (file:line in the o1-4 report)

- Pipeline: `waylanddisplaysrc`, `videoconvert`, `nvautogpuh264enc` (CBR, one IDR per second, `b-frames=0`, `tune=ultra-low-latency`), `h264parse config-interval=-1`, `webrtcsink` (`streaming/entrypoint.sh:348-388`).
- Tap: a `tee` after the encoder, a second `h264parse` (byte-stream, au) into `appsink drop=true max-buffers=1`, inside a Python GStreamer sender (GStreamer 1.24.2; `python3-gi` with GstApp present in the distro, absent from the session image: one apt line; `python3-websockets` not installed, or about 40 lines of stdlib handshake), behind a `SESSION_TAP` switch default off. `webrtcsink` accepts `video/x-h264`, so one encode serves both viewers.
- Port: a new `TAP_PORT` (sessions run `--network host`), not the stdlib `serve.py`. Keyframes on request via the `UpstreamForceKeyUnit` event. Per-frame metadata: capture timestamp and frame counter; the marker strip is drawn into the picture, so the marker reader works on the canvas unchanged.
- Dead ends: no `node`, no HTTP/3 stack, no custom-payload data channel in `webrtcsink`.
- Loss without a jitter buffer: keyframe request message, drop to the next IDR on a gap, hold the last frame, bounded leaky queue plus `appsink drop=true`, the page's `bufferedAmount`/lag as backlog signal. Intra-refresh availability in the installed encoder: unverified. Congestion: fixed CBR (10 Mbit/s ceiling) first; adaptation later.

## 7. Expected gain, effort, risks, measurement

- Press-to-screen now 197-225 ms: game 22, capture/encode 32, network 2, Safari buffer 30-100, decode 4, display 40-100 (journey notes; Safari's own stage figures are unstable). A canvas player removes the buffer and adds its own queueing (TCP, decoder one or two frames, canvas present at the next vsync). Honest range: **20-80 ms saved, likely 30-60**, landing around 140-170 ms, still above the 80 ms gate. Inference, low-medium.
- Effort (flash jobs of 80-150 turns): 1 host tap and sender; 2 page decoder, canvas draw, AVCC conversion; 3 transport, keyframe request, loss handling; 4 measurement hooks (marker on the canvas, bench viewer switch); 5 sound on a separate connection; 6 https/cert route if required; 7 hardening, tests, docs. First slice is 1-4.
- Risks: Safari gates the API (probe); iOS decoder delay or drops at 1080p60 (no iOS data); TCP stalls on Wi-Fi; sound sync; certificate ceremony; Android Chrome needs https even for a prototype; a second player code path to maintain.
- Measurement: the existing bench and marker apply because the marker is in the picture; the page reads it from the canvas (`marker_reader.js`) and the press-flip cell works as today. A canvas has no `requestVideoFrameCallback`, so display time comes from the marker's frame counter and `performance.now()` after the draw call; respect the 30 ms run-to-run spread (three or more runs per case).

## 8. The probe (built)

- `streaming/player/probe.html`, served by the existing player server at `/probe.html` on the player port (45782). Static, no network calls, no stream; nothing else changed; the relay test proves the whitelist (27 checks pass).
- It reaches a session after the image is rebuilt (`tools/stream.sh build`, then `up`), or without any session: `dest="$(tools/wsl-sync.sh tp-stream)" && MSYS_NO_PATHCONV=1 wsl -d tp-stream -u root -- bash -lc "cd $dest/streaming/player && python3 -m http.server 45900 --bind 0.0.0.0"`, then `http://<PC LAN address>:45900/probe.html` (a Windows firewall rule for 45900 may be needed; none was changed).
- Good result: `VideoDecoder` present even though `isSecureContext` is false on http (false is expected, that is the data); `isConfigSupported` true for `avc1.42E028` and `avc1.64002A` at 1920x1080, 60 fps, with `optimizeForLatency` and prefer-hardware; data channel created and the offer lists H264; Test audio shows `outputLatency`. Tap Copy report and paste it back.
- Headless Chrome (not Safari) reported every config supported except prefer-hardware. No decode self-test: no verified test stream was embedded.

## Not verified

All iOS behaviour on a device; whether Safari exposes VideoDecoder on http; iOS decode and display delay; Safari's real hardware use; production services' internals; Annex B handling in Safari; intra-refresh in the installed encoder; iOS audio output latency.
