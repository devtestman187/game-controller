# Prior art on streaming latency (M15)

Research date 2026-11-12. Web pages read with WebFetch/WebSearch only. Confidence notes: "measured" = number measured in the source, "claimed" = source asserts it without method, "inference" = my reasoning.

## Summary

Ranked by expected gain for effort. F1 = encoder waits on webrtcsink, F2 = browser jitter buffer, F3 = game draws 48-52 fps, F4 = host leg.

1. **Split audio and video so the browser does not lip-sync them (F2).** Chromium raises video delay once an audio sender report arrives when both share one MediaStream/msid; separate streams removed it (discuss-webrtc thread, an engineer's report). A Neko/Selkies thread claims 150-200 ms down to 10-20 ms with a separate webrtcbin per media (claimed, not verified). Bilibili says Safari keeps independent jitter buffers per track when attached separately. Cost: a stream-id/SDP change on the host. Safari: only Bilibili's claim; test it. Gain: up to the whole 50-100 ms if A/V sync is the cause; nothing if we send video only.
2. **Playout-delay RTP header extension min=max=0 from the sender (F2).** The libwebrtc spec describes this for exactly our case; Neko contributors call it key. Safari support unconfirmed: a 2019 Firefox bug comment says it works in Chrome and Safari (secondhand); Firefox has an open bug where 0/0 freezes video. Cheap to try. Our earlier playoutDelayHint/jitterBufferTarget tries did nothing on Safari, which fits "WebKit ignores these". Gain unknown.
3. **Find and remove the wait inside webrtcsink (F1, up to about 25 ms).** No source documents this wait. Docs show only `encoder-setup`/`payloader-setup` signals, `congestion-control` (default gcc), `do-fec` and `do-retransmission` (both default true). Try `congestion-control=disabled`, `do-fec=false`, fixed bitrate; or bypass webrtcsink with plain `webrtcbin` or a custom sender (Helix and Bilibili run custom senders). Host side, so Safari is unaffected. Gain: up to about 25 ms (inference).
4. **Fixed-rate frame clock instead of the compositor frame callback (F3).** wlroots notes a missed vblank costs more than a whole frame; Wayland frame callbacks are compositor-paced; capture-vs-compositor clock mismatch causes uneven pacing (WebRTC PipeWire capturer, KDE bug). Gamescope presents the newest frame just before each deadline. Options: run the game unthrottled and sample at 60 Hz, or tick the headless compositor at a steady 16.7 ms. Gain: back to 60 fps and fewer jitter spikes, a few ms (inference). Not browser-related.
5. **Encoder: P-frames only, no B-frames, no lookahead, and check the SPS (decode side).** One article measured about 22 ms combined encode+decode after removing B-frames (claimed). A Selkies issue says B-frames are unusable in WebRTC browsers (2023 claim). I found nothing on whether Safari's decoder holds frames when the SPS lacks a zero-reorder hint (`max_num_reorder_frames=0`); worth inspecting our stream. Gain: possibly a frame or two of decoder hold (inference).
6. **WebCodecs over WebSocket/WebTransport with a custom player (F2).** Helix reports 20-30 ms lower than WebRTC, drawing frames on arrival (claimed, no absolute figure). iOS Safari 26.0+ lists WebCodecs as supported (caniuse); WebTransport shipped in 26.4, March 2026 (secondary sources). Biggest rewrite, loses WebRTC congestion control, but the only route that guarantees no browser jitter buffer. Gain: most of the 52/101 ms, replaced by our own 0-1 frame queue (inference).
7. F4 (host leg, about one frame): no source suggests more.

**Is 80 ms press-to-screen in a phone browser realistic?** Published figures: GeForce Now about 56 ms click-to-draw (Nvidia, Destiny 2), 97.8 ms default and 69 ms competitive mode (GameStar via PCWorld), Parsec LAN pipeline 4-8 ms at 240 fps (native), Bilibili about 50 ms local playback in Chrome after tuning (100 ms on 2.4 GHz Wi-Fi). I found no published press-to-screen figure for iPhone Safari. 80 ms looks reachable in Chrome and plausible on Safari only if the jitter buffer can be bypassed (items 1, 2 or 6); with Safari's 50-100 ms buffer left alone it is not.

## Sources

### The three owner documents

- https://etda.libraries.psu.edu/files/final_submissions/30084 — HTTP 403 on fetch; catalog URL 404; search did not identify the thesis. Nothing read. Confidence: none. Owner should open it by hand or paste text.
- https://lfedge.org/wp-content/uploads/sites/24/2023/08/Akraino-White-Paper-Edge-Cloud-Game-based-on-Arm-architecture-high-performance-CPU-1.pdf — PDF returned as binary; text could not be extracted (no PDF renderer installed). From the LF Edge listing only: a joint paper (Akraino, Arm, Tencent, Zenlayer and others) on edge cloud gaming architecture, cost and operations. Looks like a deployment paper, not latency engineering (inference from the abstract). Nothing pertinent confirmed.
- https://web.cs.wpi.edu/~claypool/papers/game-stream-nossdav-22/paper.pdf — PDF unreadable (same reason). From the landing page: Xu and Claypool, NOSSDAV 2022, measure how Stadia, GeForce Now and Luna react to a congested link shared with TCP (bitrate, loss, latency). About congestion response, not per-stage or browser latency. Nothing pertinent to our 80 ms goal beyond "services adapt bitrate differently". Confidence: abstract only.

### Other sources

- https://groups.google.com/g/discuss-webrtc/c/ZvAHvkHsb0E — Chromium A/V sync adds latency after the first audio sender report; same-msid streams sync, separate streams do not; Stadia reportedly sends no sender reports. Under about 100 ms called normal. Confidence: measured by the poster, Chromium only.
- https://github.com/m1k1o/neko/issues/339 — Chrome's audio jitter buffer cannot be changed; separate webrtcbin for audio and video reported 150-200 ms to 10-20 ms; playout-delay extension called essential; WebTransport suggested. Confidence: claimed.
- https://besthub.dev/articles/design-and-implementation-of-bilibili-s-low-latency-cloud-gaming-platform-using-webrtc-e4f898bbb3dd — Bilibili: default jitter buffer about 500 ms on bad networks; about 50 ms local after tuning three unnamed private Chrome settings (100 ms on 2.4 GHz Wi-Fi); Chrome syncs A/V, Safari with separately attached tracks has independent buffers; x264 zerolatency without B-frames; GCC; unordered unreliable data channel for input. No per-stage numbers. Confidence: claimed.
- https://blog.helix.ml/p/we-killed-webrtc-and-nobody-noticed — raw H.264 over WebSocket plus WebCodecs `VideoDecoder` to canvas: 20-30 ms lower than WebRTC, no absolute figure. Trade-offs: TCP head-of-line blocking, no adaptive bitrate. Safari not tested. Confidence: claimed.
- https://parsec.app/blog/game-streaming-tech-in-the-browser-with-parsec-5b70d0f359bc — Parsec browser client (2018): WebRTC data channels plus MSE low-delay mode, Chrome only; no numbers, no Safari. Little relevance.
- https://parsec.app/blog/description-of-parsec-technology-b2738dcc3842 and Parsec support pages — encode+decode under 10 ms on recent GPUs; client decode target under 15 ms at 60 fps. Native, claimed.
- https://webrtc.googlesource.com/src/+/main/docs/native-code/rtp-hdrext/playout-delay/README.md — spec of the playout-delay extension; min=max=0 means sender wants receiver smoothing off. Says nothing on Safari.
- https://bugzilla.mozilla.org/show_bug.cgi?id=1592988 — Firefox bug thread; secondhand remark that the extension works in Chrome and Safari (2019); a separate open Firefox bug reports a freeze with 0/0. Weak.
- https://groups.google.com/a/chromium.org/g/blink-dev/c/bReU8otUmdk — Intent to Ship `jitterBufferTarget` (2024): WebKit position "no signal", standards-position request filed.
- https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget — says Baseline 2026 / newly available, but the compatibility table did not render, so Safari's entry unread. An earlier MDN data snapshot (via search) showed Safari "No". Conflicting. Also: the value is only a hint.
- https://lists.webkit.org/pipermail/webkit-changes/2024-February/298065.html — WebKit imported WPT tests for `jitterBufferTarget` in Feb 2024. Importing tests does not prove shipping.
- https://caniuse.com/webcodecs — iOS Safari partial 16.4-18.7, supported 26.0+ (via search summary).
- https://webrtc.ventures/2026/04/webtransport-is-now-baseline-what-it-means-for-real-time-media/ — WebTransport shipped in Safari 26.4 (March 2026). Secondary; verify on webkit.org.
- https://bugs.webkit.org/show_bug.cgi?id=287516 — WebKit bug (Feb 2025): frames out of order with B-frames in `VideoDecoder`. Relevant only for the WebCodecs route. Not opened in full.
- https://discourse.gstreamer.org/t/severe-lag-in-webrtc-connection-to-gstreamers-webrtcbin-with-h-264-av1-on-ios-18-3-and-later/4528 — one report (Apr 2025) of severe lag from iOS 18.3+ to webrtcbin; no cause, no fix. Unverified.
- https://lists.freedesktop.org/archives/gstreamer-devel/2021-April/078118.html — 2021 report that on iOS Safari audio ran 250-750 ms behind video; hints at per-track buffering. Old.
- https://gstreamer.freedesktop.org/documentation/rswebrtc/webrtcsink.html — property list (congestion-control default gcc, do-fec and do-retransmission default true, encoder-setup signal). Nothing on pacing, queue or processing deadline.
- https://gitlab.freedesktop.org/gstreamer/gst-plugins-bad/-/merge_requests/1367 — webrtcbin `latency` property sets rtpbin jitterbuffer latency; receiver side, so not relevant to a pure sender.
- https://discourse.gstreamer.org/t/webrtcsink-latency/254 and https://discourse.gstreamer.org/t/high-latency-700-ms-in-webrtcsink-pipeline-with-tsdemux/4055 — user reports of 300-700 ms in webrtcsink pipelines; no root cause for a 25 ms wait.
- wlroots commit "remove wlr_output_impl.schedule_frame" and https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/3493 — missed vblank costs more than a frame; headless backend arms its timer on commit. Via search snippets; claimed in commit messages.
- https://bugs.kde.org/show_bug.cgi?id=524129 and https://gitlab.freedesktop.org/wayland/wayland-protocols/-/merge_requests/328 — capture rate versus compositor rate mismatch gives uneven pacing; throttling capture by delaying requests is uneven. Supports driving capture from the compositor's own frame event.
- https://webrtc.googlesource.com/src/+/6ff7713a706e65ff2dfe2b1fe2fbb82558db9cc3 — WebRTC's PipeWire capturer moved to compositor-driven callbacks to avoid clock-mismatch delay.
- https://lpc.events/event/9/contributions/869/attachments/726/1330/gamescope.pdf — Gamescope talk; PDF unreadable here. Gamescope behaviour taken from search snippets only.
- Sunshine docs (https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2performance__tuning.html) and community guides — NVENC low-latency preset, CBR, pacing "lowest latency" vs "smoothest" (one user: about 2 ms cost). Native clients, no browser numbers. Moonlight web ports (linckosz/moonlight-web) use WebCodecs plus WebRTC/WSS relay with per-stage latency display; no iOS numbers found.
- https://thume.ca/2022/05/15/latency-testing-streaming/ — a remote-browser product at 83-109 ms typing latency (measured) vs 37-42 ms local; H.264 about 10-20 ms faster than H.265. Order of magnitude for a whole remote-display chain.
- Cloud-gaming measurements: Nvidia claim about 56 ms click-to-draw (Destiny 2, RTX 3080 tier); GameStar via PCWorld 97.8 ms default / 69 ms competitive; Nvidia claim 30 ms at 360 fps. Found via search snippets (hothardware.com, pcworld.com, tomsguide.com), not read in full. Vendor-claimed or single-review.
- https://www.arxiv.org/pdf/2511.16902 — "ARC: Consistent, Low-Latency Delivery via Receiver-Side Scheduling" (Luby, 2025). Only title and outline readable; no conclusions drawn.
- Stadia: no primary engineering write-up found. Only secondhand (bloggeek.me says playout delay was part of Stadia's WebRTC work; Parsec corrected that Chrome MSE low-delay was unrelated to Project Stream).

## Not found / uncertain

- Contents of the three owner documents beyond abstracts: PSU file gave 403; the two PDFs were binary and no PDF renderer is installed. Needs the owner or a text copy.
- Whether iOS Safari honours the playout-delay extension, `jitterBufferTarget` or `playoutDelayHint`. Evidence conflicts: MDN data snapshot (2025, via search) shows Safari "No"; Chromium Intent to Ship (2024) shows WebKit "no signal"; the live MDN page claims Baseline 2026 but its table did not render. Our own earlier tests found no effect. Check on the phone with `'jitterBufferTarget' in RTCRtpReceiver.prototype`.
- Whether Safari keeps a separate jitter buffer per track (Bilibili claim only), and whether our stream has an audio track at all.
- Why webrtcsink holds encoder output about 25 ms: no source found. Needs gst-plugins-rs source reading or the GStreamer latency tracer.
- Whether our H.264 SPS signals zero reorder, and whether Safari's decoder buffers without it: nothing found.
- WebCodecs and WebTransport on iOS Safari: dates come from caniuse and a vendor blog; no iPhone latency measurement found; WebCodecs video-decode status in 26.x not confirmed from an Apple page.
- Any published press-to-screen figure for iPhone Safari: none.
- Selkies-GStreamer official latency docs, Stadia/Xbox/Luna engineering talks, Parsec decode-side posts: no useful primary material found.
