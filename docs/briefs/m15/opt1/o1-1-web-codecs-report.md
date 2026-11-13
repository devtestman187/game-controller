## Summary

- **WebCodecs video arrives with iOS/iPadOS/macOS Safari 16.4 (2023-03-27)**: `VideoDecoder` *and* `VideoEncoder`, video only. Audio (`AudioDecoder`/`AudioEncoder`) only in Safari 26.0 (2025-09-15). caniuse therefore calls 16.4–18.7 "partial — video-only support" and 26.0+ full. [primary, high]
- **H.264 is supported** (`avc1.*` is in WebKit's supported-codec list) and decodes through VideoToolbox ("VTB") on Apple platforms, i.e. normally hardware. [primary, high]
- **`optimizeForLatency` is accepted but ignored by WebKit today**: the IDL parses it, `createVideoDecoderConfig()` never forwards it, and bug 325278 (2026-09-25, still NEW) asks for `kVTDecompressionPropertyKey_RealTime` to be set when it is true. [primary, high]
- **`isConfigSupported()` does not report hardware vs software honestly**: it resolves `supported` from "did `VideoDecoder::create()` succeed" and echoes your config back unchanged, so `support.config.hardwareAcceleration` is your input, not reality. [primary, high]
- **Keyframe rule is strict in WebKit**: after `configure()`, `reset()` *and* `flush()` the next chunk must be `type: "key"`, else `DataError: Key frame is required`. [primary, high]
- **Bitstream**: `description` present ⇒ AVCC byte-stream (length-prefixed NALs, SPS/PPS in avcC); absent ⇒ Annex B with in-band SPS/PPS in every key chunk. That is spec. Whether WebKit's Annex B path is solid is **unverified**; send avcC and keep SPS/PPS in-band per keyframe if the parser allows both. [primary for the spec rule, high; medium for WebKit's Annex B]
- **DataChannel on an insecure `http://192.168.x.x` page: allowed.** Neither WebKit's `RTCPeerConnection.idl` nor `RTCDataChannel.idl` is `SecureContext`, and the W3C IDL is `[Exposed=Window]`. [primary, high]
- **WebCodecs is spec'd `[SecureContext]`** (and Chromium's IDL says so), but WebKit's IDL does *not* — so Safari may expose `VideoDecoder` over plain http on a LAN IP while Chrome/Firefox will not. This single fact decides your transport/decoder architecture; **unverified on device** — test first. [primary source, medium]
- **DataChannel is still SCTP**: `a=max-message-size` (RFC 8841; default 64 KiB when absent), read `pc.sctp.maxMessageSize` at runtime. Keep messages ≤16 KB and fragment keyframes. Unordered/lossy works: WebKit maps `ordered`, `maxRetransmits`, `maxPacketLifeTime` straight into libwebrtc. [primary, high]
- **WebTransport: Safari 26.4 (2026-03-24), iOS included.** HTTP/3+QUIC with an HTTP/2 fallback; requires `https://` (WebKit rejects non-https), `maxDatagramSize` is hard-coded to **1024** in WebKit, `serverCertificateHashes` is only accepted for dedicated (non-pooled) transports. **`WebTransport.datagrams` is reported undefined on iOS 26.6** (bug 322201, 2026-08-20, NEW) — streams work, datagrams don't. [primary, high/medium]
- **Encoded Transform cannot bypass the jitter buffer.** `RTCRtpScriptTransform` (Safari 15.4+) sits *after* depacketisation; in libwebrtc the assembled frame comes out of `packet_buffer_` and only then goes to `frame_transformer_delegate_->TransformFrame()`. [primary, high]
- **Jitter-buffer knobs on iOS**: none before Safari 27.0 (2026-09-17), which adds `RTCRtpReceiver.jitterBufferTarget` and a `targetLatency` attribute. `playoutDelayHint` is not in WebKit at all. [primary, high]
- **Feasibility (inference, medium)**: a custom player removes the *RTP jitter buffer* component of the ~200 ms but not the decode→display and compositor delay, adds transport buffering you must design away, and on iOS you cannot tune the decoder (`optimizeForLatency` ignored). Expected win is real but smaller than the "half is inside Safari" figure suggests; measure decode()→canvas-visible before committing.

## 0. Context, method and caveats

Research for Thumb Party (Flutter; host GStreamer H.264 1080p60, baseline/constrained baseline, no B-frames; viewer = iPhone Safari, currently a plain WebRTC `<video>`, ~200 ms press-to-screen with roughly half inside Safari as jitter buffer + decode-to-display). All pages fetched **2026-11-13** unless stated. Every claim is tagged **primary** (spec / vendor / WebKit source / bug tracker / release notes), **secondary** (blog, forum, aggregator) or **inference**, with a confidence level.

- Sources: WebKit blog release notes, WebKit Bugzilla, WebKit source on GitHub (`WebKit/WebKit@main`), W3C specs, MDN browser-compat-data JSON, caniuse JSON, IETF RFCs, libwebrtc mirror (`webrtc-sdk/webrtc`), one Google issue tracker entry (title only).
- Bugzilla *lists* were fetched; individual bugs were opened where quoted. Bug titles quoted from a list are marked "(title only)".
- DuckDuckGo returned a "complete the challenge/solve the captcha" bot-check page once; nothing else impeded fetching. No fetched page contained instructions; none were followed.
- WebKit source is `main` as of 2026-11-13, i.e. possibly *ahead* of the iOS 27.x shipping build. Treat source-only claims as "current trunk".

## 1. WebCodecs on iOS Safari

### 1.1 First versions

| API | First Safari/iOS | Evidence |
|---|---|---|
| `VideoDecoder` | **16.4** (2023-03-27) | MDN BCD `"safari": {"version_added": "16.4"}`, `safari_ios: mirror` [primary, high] |
| `VideoEncoder` | **16.4** | MDN BCD VideoEncoder.json, same [primary, high] |
| `AudioDecoder` | **26.0** (2025-09-15) | MDN BCD AudioDecoder.json `"26"`; WebKit blog 26.0: "adds AudioEncoder and AudioDecoder" [primary, high] |
| `AudioEncoder` | **26.0** | same [primary, high] |

- WebKit blog, *WebKit Features in Safari 16.4*, 2023-03-27: "Safari 16.4 adds support for the **video portion** of Web Codecs API … especially useful for … video conferencing, or other real-time processing of video." — https://webkit.org/blog/13966/webkit-features-in-safari-16-4/ [primary, high]
- caniuse agrees and explains the "partial" flag: Safari 16.4–18.7 partial, 26.0+ full, note #1 = "Video-only support". https://caniuse.com/webcodecs and https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/webcodecs.json [primary (caniuse data), high]
- Safari 26.0 date: blog header "Sep 15, 2025" — https://webkit.org/blog/17333/webkit-features-for-safari-26-0/ [primary, high]

Practical reading: **iOS 16.4+ is the floor for a WebCodecs video player**; you need iOS 26+ only if you want in-page audio decoding (for a game you can keep audio out of scope, or ship AAC/Opus via `<audio>`/WebAudio, which is a separate problem).

### 1.2 H.264 and hardware decode

- WebKit's decoder-support test is a plain prefix match: `codec.startsWith("avc1.")` is accepted (plus vp8, vp09, hev1/hvc1 behind flags, av01). Source: `Source/WebCore/Modules/webcodecs/WebCodecsVideoDecoder.cpp`, function `isSupportedDecoderCodec`, https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webcodecs/WebCodecsVideoDecoder.cpp [primary, high]
- The Apple decode path is VideoToolbox: bug 325278 is titled "*VTB Decoders should set `kVTDecompressionPropertyKey_RealTime` when `WebCodecsVideoDecoderConfig.optimizeForLatency` is true*", filed 2026-09-25 by a WebKit engineer (youenn fablet), status NEW, P2, rdar://188386047. https://bugs.webkit.org/show_bug.cgi?id=325278 [primary, high]
- `hardwareAcceleration` mapping in WebKit: `prefer-software` ⇒ `HardwareAcceleration::No`, **everything else (including the default `no-preference` and `prefer-hardware`) ⇒ `Yes`**, i.e. WebKit asks for hardware always. `createVideoDecoderConfig()` in the same file. [primary, high]
- Whether a failed hardware create silently falls back to software: not found in the files read — **unverified**. [medium]
- 1080p60 H.264 is well within A-series VideoToolbox capability (H.264 1080p60 is a baseline iPhone decode profile since ~2011); no WebKit bug found complaining about 1080p60 WebCodecs decode. [inference, medium-high]

### 1.3 `optimizeForLatency` and the per-frame output delay

- Spec: "`optimizeForLatency` … Hint that the selected decoder **SHOULD** be configured to minimize the number of EncodedVideoChunks that have to be decoded before a VideoFrame is output." https://w3c.github.io/webcodecs/ (VideoDecoderConfig section) [primary, high]
- WebKit IDL parses it: `boolean optimizeForLatency;` in `WebCodecsVideoDecoderConfig.idl` [primary, high]
- WebKit **drops it**: `createVideoDecoderConfig()` builds `VideoDecoder::Config{ description, width, height, colorSpace, decoding, rotation, isMirrored }` — there is no `optimizeForLatency` field in `VideoDecoder::Config` at all (`Source/WebCore/platform/VideoDecoder.h`). [primary, high]
- Open bug 325278 (above) confirms the intent and the gap: no `kVTDecompressionPropertyKey_RealTime`. [primary, high]
- WebKit decoders each do their own output reordering ("currently each decoder is doing its reordering"), bug 279753, 2024-09-16, still NEW. https://bugs.webkit.org/show_bug.cgi?id=279753 [primary, high]

Consequence (inference, high): with `optimizeForLatency: true` on iOS today you get **no change**; the only lever you have is the bitstream itself.

Measured delay datapoints (none on iOS Safari — this is the gap you must fill by measurement):

- WebKitGTK 2.52.6, 1080p60 HEVC, no B-frames, `num_reorder_pics 0`, one AU per chunk, `optimizeForLatency: true`: **decode()→output 35 ms median / 52 ms p95**, *regardless of decoder*; root-caused in the bug to (a) output only collected on the next `decode()` call (+1 frame) and (b) non-live GStreamer decoders' 2-frame output delay. Chrome 156 on macOS, same page/clip: **7.8 ms median / 16 ms p95**. https://bugs.webkit.org/show_bug.cgi?id=329695 (2026-10-31) [primary, high]
- Same bug: `texImage2D(VideoFrame)` of a 1080p NV12 frame cost **~10 ms/frame** on WebKitGTK (CPU YUV→RGB); manual `copyTo` + R8/RG8 + shader brought it to ~1 ms. GTK-only, but a fair warning that the "draw each frame at once" step can itself cost a frame time. [primary, high for GTK; inference for iOS]
- Chrome (not Safari): H.264 **hardware** decode buffers output until the next keyframe is fed, i.e. very long GOPs are hostile to low latency. https://issues.chromium.org/issues/40857774 (title only, from search result) [primary (title), medium]
- `optimizeForLatency` itself has a documented performance cost and frame-drop side in Chrome (issue 491, 2022, still open) — don't assume it is free. https://github.com/w3c/webcodecs/issues/491 [primary, high]

**Which stream settings avoid output reordering** (design answer, inference/standard, medium-high):

1. **Baseline or constrained baseline, no B-frames** — removes the need for any presentation-order reordering. WebKit/H.264 will then have nothing to hold back.
2. **`num_reorder_frames = 0`** (and `max_dec_frame_buffering` sane) in the VUI `bitstream_restriction` block if your encoder emits it (x264/openh264 do when `--bframes 0` + `--ref` small). This is advisory but VideoToolbox sizes its DPB from it.
3. **No `max_num_ref_frames` games, short GOPs** (e.g. keyframe every 1–2 s, or on demand) because of the Chrome HW-decoder behaviour above and because WebKit requires a key chunk first.
4. **`optimizeForLatency: true` anyway** — costs nothing in Safari today (ignored) and helps the day 325278 lands or on Chrome.
5. Keep `codedWidth/codedHeight` set and matching the SPS; WebKit rejects half-specified display aspect (validity rules in the source).

### 1.4 Annex B vs AVCC, SPS/PPS

Spec (W3C AVC codec registration, https://www.w3.org/TR/webcodecs-avc-codec-registration/) [primary, high]:

- "If the `description` is present, it is assumed to be an `AVCDecoderConfigurationRecord` … and the bitstream is assumed to be in **avc** format."
- "If the `description` is not present, the bitstream is assumed to be in **annexb** format."
- Key chunks in **avc** format must contain an IDR; parameter sets come from `description`. Key chunks in **annexb** must contain the IDR **and all parameter sets** needed for the chunk.

WebKit side:

- `description` is copied verbatim into `VideoDecoder::Config.description` and passed to the platform decoder; there is no format detection in WebCodecs-video code ([source](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webcodecs/WebCodecsVideoDecoder.cpp)). [primary, high]
- A bug titled "Integer underflow leads to crash in **ComputeH264InfoFromAVC**" (bug 308901, title only) implies WebKit has an in-band AVC/SPS-PPS parsing path, so Annex B is probably functional — **but I could not confirm Safari decodes Annex B H.264 from WebCodecs**, and no documentation asserts it. [secondary/inference, low-medium]
- Recommendation (inference, high confidence as engineering advice): have GStreamer output **`video/x-h264,stream-format=avc` (avcC)** with `align=au`, convert with `h264_mp4toannexb`-equivalent knowledge on the page side, and pass the `avcC` bytes as `description`. Also keep SPS/PPS in-band in keyframes if your parser lets you (`avc3` style) so a late joiner can start — but expect WebKit to ignore them when `description` is set. If you must use Annex B, test on a device on day one.
- Do **not** rely on `avc1` vs `avc3` distinctions: WebKit's check is only `startsWith("avc1.")`.

### 1.5 Known WebKit WebCodecs bugs / quirks (Bugzilla + GitHub)

Confirmed by opening the bug:

| Bug | State | What it means for you |
|---|---|---|
| [267121](https://bugs.webkit.org/show_bug.cgi?id=267121) "REGRESSION (iOS 16.3?): WebKit requires keyframes now for video decodes…" (2024-01-04, NEW) | open | every join/reset/reconnect must start at an IDR; no "wait for the next keyframe" inside the decoder. |
| [325278](https://bugs.webkit.org/show_bug.cgi?id=325278) VTB/optimizeForLatency (2026-09-25, NEW, P2) | open | no low-delay decoder flag on iOS. |
| [279753](https://bugs.webkit.org/show_bug.cgi?id=279753) per-decoder frame reordering (2024-09-16, NEW) | open | reordering is real and internal; no B-frames ⇒ no hold. |
| [329695](https://bugs.webkit.org/show_bug.cgi?id=329695) GTK decode→output 35 ms, texImage2D 10 ms (2026-10-31, NEW) | open | shows WebKit's chunk-in/frame-out bookkeeping can add ~1 frame; check iOS. |
| [241124](https://bugs.webkit.org/show_bug.cgi?id=241124) "Support Insertable Streams/MediaStreamTrackProcessor on Safari (both iOS and MacOS)" (2022-05-31, RESOLVED CONFIGURATION CHANGED, last comment 2024-08-15) | closed/fixed | MSTP arrives with Safari 18 (MDN BCD). |

From the Bugzilla list (titles only, not opened, dates not verified):

- 318440 "WebCodecs: AV1 isConfigSupported returns false in windows opened from another page" — feature detection can lie depending on how the page was opened. [primary (title), medium]
- 321880 "WebCodecs: VideoFrame(CanvasImageSource) deterministically mutates some explicit timestamps by −1 µs" — do not compare frame timestamps for equality. [primary (title), medium]
- 329786 "drawImage() and createImageBitmap() draw a VideoFrame whole, ignoring its visibleRect and the source rectangle" — no cropping at draw time; crop in the encoder or use `VideoFrame`'s own crop. [primary (title), medium]
- 258569 "WebCodecs decoders should be able to decode synchronously two frames with the same timestamp" — duplicate/monotonic timestamps are risky; use strictly increasing µs timestamps. [primary (title), medium]
- 309518 "WebCodecs VideoDecoder reports incorrect VideoFrame.colorSpace for BT.2020/HLG" — irrelevant for BT.709 1080p60 game content, but colours can be off for HDR. [primary (title), medium]
- 329242 "GPU process crashes when VideoDecoder decodes 12-bit HEVC" — not your codec. [primary (title), low relevance]

From the W3C webcodecs repo:

- Issue 885 "WebCodecs causing memory leak in macOS VTDecoderXPCService when tab is in background" — Streams feeding a decoder while the tab is hidden grow `VTDecoderXPCService` to GBs. Reported against Chrome 130+ on macOS; the reporter's own workaround is `videoDecoder.close()` on `visibilitychange`. iOS suspends background pages anyway, but the pattern (close on hide, keyframe on show) is worth adopting. https://github.com/w3c/webcodecs/issues/885 [primary (reporter), medium]
- Issue 55 "VideoFrames to VideoDecoderOutputCallback in decoding order, not presentation order" — rejected; the spec keeps **presentation order**, which is *why* a decoder with B-frames must buffer. https://github.com/w3c/webcodecs/issues/55 [primary, high]

Quirks visible directly in WebKit source ([WebCodecsVideoDecoder.cpp](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webcodecs/WebCodecsVideoDecoder.cpp)) [primary, high]:

- `configure()` sets `m_isKeyChunkRequired = true`; `decode()` throws `DataError "Key frame is required"` otherwise.
- **`flush()` sets `m_isKeyChunkRequired = true` again** — after every flush your next chunk must be a keyframe. `flush()` also rejects on the standard "AbortError" path if the decoder is reset/closed.
- `reset()` and `close()` reject pending `flush()` promises with `AbortError`.
- `decode()` of an empty chunk is a decoding error ("Empty chunk", github issue 983 referenced in the source).
- `isConfigSupported()` refuses to answer synchronously: it *creates a decoder*, so a probe is not free (it allocates a VideoToolbox session) and can be slow. Cache the answer.
- `suspend()` is an **empty function** — WebKit does not tear down or pause the decoder when the page is suspended; the OS does the suspending. [primary source, high; consequences inference]
- `VideoDecoder` is `Exposed=(Window,DedicatedWorker)`; both are fine on iOS.

Not confirmed: 1080p60 sustained throughput on any specific iPhone; 4K; behaviour of `decodeQueueSize` under load; whether `VideoFrame.close()` is automatic enough (source has JS-managed lifetime, but I did not read the GC integration). Mark all **unverified**.

## 2. Transports on iOS Safari

### 2.1 WebSocket

- `bufferedAmount` = "number of bytes of application data … queued using send() but **not yet been transmitted to the network** … does not include framing overhead … or buffering done by the operating system or network hardware." https://websockets.spec.whatwg.org/ [primary, high]
- Therefore `bufferedAmount === 0` does **not** mean "the bytes left the phone": kernel socket buffers and the Wi-Fi hop are invisible. On a LAN that is small, but on a congested Wi-Fi it is the part you cannot see. [inference, high]
- WebSocket is **TCP**: any lost packet stalls *all* later data (head-of-line blocking), which for a video stream means one dropped 802.11 frame costs a full retransmit-RTT of video. [primary (RFC 9293/TCP semantics) — stated from general knowledge, inference from spec silence, high]
- Nagle: the WebSocket handshake/API says nothing about `TCP_NODELAY`; Chrome is known to disable Nagle on WebSocket sockets, **I found no document stating what Safari/CFNetwork does** — **unverified**. Practical mitigation: batch one access unit per `send()` and never write a frame in two `send()` calls (that is the classic Nagle/delayed-ACK 40 ms trap).
- WebSocket is not `[SecureContext]` in WebKit's IDL (`Source/WebCore/Modules/websockets/WebSocket.idl`, `EnabledBySetting=WebSocketEnabled` only), so `ws://192.168.x.x` works from an http page. [primary, high]
- No WebSocket API for send-side backpressure other than `bufferedAmount`; no receive-side delivery timestamp. [primary, high]

### 2.2 WebRTC DataChannel (unordered, unreliable)

Availability in an insecure context — **yes**:

- W3C IDL: `[Exposed=Window] interface RTCPeerConnection` (no `SecureContext`), https://w3c.github.io/webrtc-pc/ [primary, high]
- WebKit IDL: `[ActiveDOMObject, Conditional=WEB_RTC, EnabledBySetting=PeerConnectionEnabled, Exposed=Window] interface RTCPeerConnection`, and `RTCDataChannel` is `Exposed=(Window,Worker), Transferable` with **no** `SecureContext`. https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/mediastream/RTCPeerConnection.idl, …/RTCDataChannel.idl [primary, high]
- So the answer to the brief's question is **confirmed: a DataChannel works on an `http://` LAN-IP page in Safari**. (Only `getUserMedia` needs a secure context; you don't use it.) [primary, high]

Reliability modes:

- RFC 8831: SCTP with PR-SCTP gives "ordered and unordered delivery" and "reliable and partially reliable transport". https://www.rfc-editor.org/rfc/rfc8831.txt [primary, high]
- WebKit maps `ordered`, `maxRetransmits` (`init.maxRetransmits`), `maxPacketLifeTime` (`init.maxRetransmitTime`) straight into `webrtc::DataChannelInit` — https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/mediastream/libwebrtc/LibWebRTCDataChannelHandler.cpp [primary, high]
- MDN BCD: `maxRetransmits` since Safari 11 (iOS mirror). https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/RTCDataChannel.json [primary, high]

Message size:

- SDP `a=max-message-size` "indicate[s] the maximum SCTP user message size … If the attribute is not present, the default value is **64K**". RFC 8841 §6.1. https://www.rfc-editor.org/rfc/rfc8841.txt [primary, high]
- The actual value is negotiated (`min(local, remote)`, with 0 meaning "any"), libwebrtc `sdp_offer_answer.cc` ~line 4289. https://raw.githubusercontent.com/webrtc-sdk/webrtc/main/pc/sdp_offer_answer.cc [primary, high]
- WebKit exposes it as `RTCSctpTransport.maxMessageSize`, fed from libwebrtc's `SctpTransportInformation` (`Source/WebCore/Modules/mediastream/RTCSctpTransport.cpp`, `…/libwebrtc/LibWebRTCSctpTransportBackend.cpp`). [primary, high]
- **What number Safari advertises: unverified.** (Commonly ~256 KiB in Chromium, 64 KiB is the RFC floor.) Read `pc.sctp.maxMessageSize` at runtime and never exceed 16 KiB per message by design, i.e. fragment a 20–100 KB keyframe into 4–16 KB pieces yourself. [primary for the mechanism, medium for the number]
- Loss behaviour: with `ordered:false` + `maxRetransmits:0`, a lost fragment is simply gone; SCTP drops the whole message on the receiver. Your fragmentation must therefore carry frame/chunk headers (`frameId`, `idx`, `count`, `key`), never single-message frames, and you must be able to drop a whole frame and carry on. [inference, high]
- Note: DataChannel runs inside SCTP over DTLS over UDP, i.e. it *is* connection-oriented at the DTLS level; "unreliable" here means SCTP's PR mode, not raw UDP. A DTLS retransmit still stalls everything. [primary, high]
- DataChannels are also rate-limited by SCTP congestion control (it is a real transport, sharing the ICE path with nothing else if you use no media tracks). [inference, medium]

### 2.3 WebTransport

- **Safari 26.4, released 2026-03-24**, "adds support for WebTransport, a modern API for low-latency, bidirectional communication"; it "runs over HTTP/3 and QUIC … When the underlying network environment doesn't support QUIC, WebTransport can run over HTTP/2 and TCP as a fallback with the same API." https://webkit.org/blog/17862/webkit-features-for-safari-26-4/ [primary, high]
- MDN BCD agrees: `WebTransport` `"safari": {"version_added": "26.4"}`, `safari_ios: mirror`. https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/WebTransport.json [primary, high]
- This **confirms the secondary sources' "26.4, March 2026"** claim. [primary, high]
- **HTTPS is mandatory in WebKit**: the constructor returns `SyntaxError` unless `parsedURL.protocolIs("https")` (or a fragment is present) — `Source/WebCore/Modules/webtransport/WebTransport.cpp` line ~85. https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webtransport/WebTransport.cpp [primary, high]
- `WebTransport` IDL is `[SecureContext]` in WebKit too. [primary, high]
- **Server**: must speak HTTP/3 + the WebTransport extension (`CONNECT` over H3). WebKit's Cocoa backend is Network.framework (`nw_webtransport_options_*` appears in bug titles). Interop is not perfect: bug 319879 (2026-07-21, NEW) — Meta's mvfst HTTP/3 server returns 200 but **`WebTransport.ready` never resolves in Safari** while Chrome/Firefox are fine. https://bugs.webkit.org/show_bug.cgi?id=319879 [primary, high]
- **Certificates**: `serverCertificateHashes` exists in `WebTransportOptions.idl`, but WebKit throws `NotSupportedError` when it is combined with `allowPooling` — i.e. only *dedicated* transports may pin a self-signed cert. https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webtransport/WebTransport.cpp (line ~89) and `WebTransportOptions.idl`. MDN BCD lists the `options.serverCertificateHashes` parameter as Safari 26.4. Whether the hashes are actually *enforced* by Network.framework — **unverified** (no Bugzilla hits at all for `serverCertificateHashes`). [primary/medium]
- **Datagram size**: WebKit hard-codes `maxDatagramSize` to **1024** bytes with the comment "Chrome currently uses 1024, and it's close to 1200, the minimum max datagram size for quic". `Source/WebCore/Modules/webtransport/WebTransportDatagramDuplexStream.cpp`. [primary, high]
- **Datagrams are broken on iOS as of 26.6**: bug 322201 (2026-08-20, NEW, P2/Major) — "WebTransport.datagrams is undefined on iOS — spec-mandatory attribute missing"; streams and `ready` work, `'datagrams' in wt === false`. Reporter had the feature flag enabled. https://bugs.webkit.org/show_bug.cgi?id=322201 [primary, high for the report; medium that it is still true on 27.x]
  - This contradicts MDN BCD (`datagrams` = 26.4 on iOS). Prefer the bug report and test on the device.
- Other open transport-quality bugs: 319818 "[WebTransport] Flow control never refills", 320232 "Validate abort-after-close semantics", 320704 "outgoingMaxAge" (titles only). [primary, medium]
- For a **LAN host**: HTTPS with a certificate the phone trusts is a real friction point (you'd need a local CA installed, or `serverCertificateHashes`). Combined with the datagram bug, **WebTransport is not the pragmatic first choice for an iPhone LAN party today**. [inference, high]

### 2.4 Secure-context matrix (the deciding table)

| API | Spec | WebKit/iOS IDL | Chrome/Firefox |
|---|---|---|---|
| `VideoDecoder` | `[SecureContext]` (W3C IDL) | **not** `SecureContext` in `WebCodecsVideoDecoder.idl` | Chromium `video_decoder.idl` has `SecureContext` |
| `RTCPeerConnection` / `RTCDataChannel` | not secure-context | not secure-context | not secure-context |
| `WebSocket` | not secure-context | not secure-context | not secure-context |
| `WebTransport` | `[SecureContext]` + https-only | `[SecureContext]` + https-only | same |

Sources: https://w3c.github.io/webcodecs/ (VideoDecoder IDL line 1210), https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webcodecs/WebCodecsVideoDecoder.idl, https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/modules/webcodecs/video_decoder.idl (lines 13–14: `Exposed=(Window,DedicatedWorker), SecureContext`), https://w3c.github.io/webrtc-pc/, https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/Modules/webtransport/WebTransport.idl. All [primary, high].

Meaning (inference, medium-high): on `http://192.168.x.x` you can do **WebSocket or DataChannel everywhere**, but **WebCodecs only where the UA forgot to gate it — maybe Safari, definitely not Chrome**. If you want a custom WebCodecs player on Android Chrome too, you need `https` (self-signed + user-accepted cert, or a real cert with LAN DNS). This deserves a device test *before* any architecture decision.

## 3. Encoded Transform, MediaStreamTrackProcessor, requestVideoFrameCallback

Support by iOS version (all MDN BCD, `safari_ios: mirror`):

| Feature | Safari/iOS | Source |
|---|---|---|
| `RTCRtpScriptTransform` | **15.4** | https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/RTCRtpScriptTransform.json [primary, high] |
| `requestVideoFrameCallback` | **15.4** | …/api/HTMLVideoElement.json; WebKit blog 15.4 confirms rVFC on `<video>` https://webkit.org/blog/12445/new-webkit-features-in-safari-15-4/ [primary, high] |
| `MediaStreamTrackProcessor` | **18** | …/api/MediaStreamTrackProcessor.json; WebKit bug 241124 resolved 2024-08 (see §1.5) [primary, high] |
| `RTCRtpReceiver.jitterBufferTarget` | **27.0** (2026-09-17) | …/api/RTCRtpReceiver.json (`"27"`); WebKit blog 27.0 https://webkit.org/blog/18325/webkit-features-for-safari-27-0/ [primary, high] |
| `playoutDelayHint` | **never** (not in WebKit IDL) | `RTCRtpReceiver.idl` contains `jitterBufferTarget` only [primary, high] |

**Does the Encoded Transform bypass the jitter buffer? No.** [primary, high]

- Spec: the receiver transform consumes frames produced by "the `RTCRtpReceiver`'s underlying depacketizer"; "the depacketizer will typically use RTP packet sequence numbers to reorder RTP packets as needed before enqueuing frames into `transformer.[[readable]]`". https://w3c.github.io/webrtc-encoded-transform/ (§2 and §"readEncodedData") [primary, high]
- libwebrtc, which WebKit uses for all of WebRTC: `RtpVideoStreamReceiver2::OnInsertedPacket(packet_buffer_.InsertPacket(...))` → assembled frame → `OnAssembledFrame(...)` → `frame_transformer_delegate_->TransformFrame(std::move(frame))`. The `packet_buffer_` **is** the jitter buffer; the transform is downstream of it. https://raw.githubusercontent.com/webrtc-sdk/webrtc/main/video/rtp_video_stream_receiver2.cc (lines ~624, ~792, ~851) [primary, high]
- So `RTCRtpScriptTransform` gives you the **encoded frame just before decode**, not before the jitter buffer. It can save you the *decode* and the *renderer*, but the packet buffer, its reordering and its target delay all still apply. [inference from the two sources above, high]
- Worse: attaching a receiver transform replaces the normal decode path with "your worker gets the frame", so you must decode it yourself *and* you have added a worker hop. [primary (spec/libwebrtc), high]

Latency knobs available on iOS:

- **iOS ≤ 26**: nothing standard. No `jitterBufferTarget`, no `playoutDelayHint`, no `targetLatency`. The only sender-side instrument is the **playout-delay RTP header extension** (`urn:3gpp:video-orientation`-style, 12+12 bits, 10 ms granularity, "0 ms: certain gaming scenarios"), which a GStreamer sender can add; whether Safari's libwebrtc honours it is **unverified**. https://webrtc.github.io/webrtc-org/experiments/rtp-hdrext/playout-delay/ [primary for the extension, unverified for Safari]
- **Safari 27.0 (2026-09-17)**: "adds support for the `targetLatency` attribute in WebRTC, for specifying a target latency on a receiver … and `RTCRtpReceiver.jitterBufferTarget`, for tuning the jitter buffer". https://webkit.org/blog/18325/webkit-features-for-safari-27-0/ [primary, high]
- Chrome has had `jitterBufferTarget` since 124, Firefox since 115 (BCD, above) — so a "set jitterBufferTarget low" strategy is cross-browser only on very new iOS.

**The architectural consequence** (inference, high): if you want to beat the jitter buffer, you must **not use RTP video at all** — send access units over a DataChannel (unordered, `maxRetransmits:0`) or a WebSocket, and decode with `VideoDecoder`. The Encoded Transform route keeps the jitter buffer and therefore keeps most of the latency you are trying to remove.

## 4. Android Chrome and desktop

**Android Chrome.** `VideoDecoder`/`VideoEncoder` since Chrome 94 (2021-09), `chrome_android: mirror` in MDN BCD and caniuse; `AudioDecoder` also 94. Decoding goes through MediaCodec (hardware on any modern phone). WebCodecs is `[SecureContext]` (Chromium IDL, cited above), so **an `http://` LAN IP will not have `VideoDecoder` at all** — this is the single biggest portability difference from what might work in Safari. Latency: Chrome's H.264 hardware decoder is known to hold output until the next keyframe on some devices (issues.chromium.org 40857774, title only), so keep GOPs short; Chrome honours `optimizeForLatency` better than Safari (issue 491 shows it has an effect, including a throughput cost). [primary for versions/secure context, medium for latency behaviour]

**Desktop Chrome.** Same as Android: WebCodecs 94+, secure context required, software fallback (ffmpeg) if no hardware, `optimizeForLatency` meaningful. WebTransport 97+, DataChannel/WSS fine. Good place to develop the player. [primary]

**Desktop Firefox.** `VideoDecoder`/`VideoEncoder` from **Firefox 130** (2024-09) on **desktop only — `firefox_android: false`** in MDN BCD and caniuse. Secure context required (same spec). Firefox has WebTransport since 114, `RTCRtpScriptTransform` since 117, `jitterBufferTarget` since 115. WebCodecs is newer and less battle-tested there (it was a long-running bug: bugzilla.mozilla.org "WebCodecs"). Treat Firefox as "works, please verify". [primary for versions, medium for quality]

## 5. What this means for the design (inference; confidence in brackets)

1. **A custom player is feasible on iOS 16.4+** in principle: `VideoDecoder` + `canvas`/WebGL is exactly the intended use, H.264 is the supported codec, and 1080p60 is within hardware. [high]
2. **The transport must not be RTP video** if the goal is to remove the jitter buffer: DataChannel unordered/unreliable (fragment to ≤16 KB, drop whole frames on loss) or WebSocket (simplest, but TCP HOL will show on Wi-Fi). DataChannel is the better fit and needs no HTTPS. [high]
3. **The unknown that decides everything is the secure-context behaviour of WebCodecs in Safari on a plain-http LAN IP.** Test 10 lines of JS on the target iPhone before anything else. If Safari also gates it, you need HTTPS for the whole scheme (and then WebTransport becomes a candidate again — except for the iOS datagram bug). [medium]
4. **You will not get decoder-side low-latency help on iOS**: `optimizeForLatency` is inert; the only lever is bitstream (baseline/CB, no B-frames, `num_reorder_frames=0`, frequent IDRs). [high]
5. **Budget the "last metre"**: WebKit may add ~1 frame of call bookkeeping (GTK datapoint), and drawing a 1080p frame can cost several ms (GTK texImage2D 10 ms). On iOS prefer WebGL2 + `texImage2D(VideoFrame)` (hardware path) over 2D `drawImage`, and consider `VideoFrame.copyTo` + manual YUV if uploads are slow. [medium]
6. **200 ms → ?**: the RTP jitter buffer is plausibly 50–100 ms of the current half; a custom player can reclaim that minus whatever your own transport buffers. The decode→display part stays. A realistic target is 100–130 ms end-to-end on good Wi-Fi, not 60 ms. [inference, medium — must be measured]
7. **Reconnect / join semantics**: every `configure()`, `reset()`, `flush()` requires a key chunk next. Design "request IDR" as a first-class message. [high]
8. **Audio**: `AudioDecoder` needs iOS 26; a separate `<audio>` element fed by MSE/HTTP or WebAudio+Opus is the lower-risk route for game sound. [high]

## 6. Open questions for Claude

1. What is the actual measured decode→screen latency of a WebCodecs canvas player on the target iPhone, versus the current `<video>` path? (Needs a device test page; nothing on the web gives this for iOS.)
2. Does WebCodecs exist on `http://<LAN-IP>` in Safari on iOS 27 (and 16.4/18)? WebKit's IDL says yes, the spec and Chromium say no. This gates the whole design.
3. Would shipping HTTPS on the LAN (mkcert-style local CA, or a real cert on a local hostname) be acceptable for the family setup, given it also unlocks Chrome/Android and WebTransport?
4. Do you need in-page audio? If yes, iOS 26 is a hard floor for WebCodecs audio; if no, iOS 16.4 suffices.
5. Which transport code already exists? DataChannel over WebRTC means adding a signalling path but no TLS; WebSocket means a plain TCP server (maybe already present for controller input).
6. Are you willing to cap the bitrate and shorten the GOP (e.g. 2–3 Mbit/s, IDR every 1 s) to make loss recovery cheap?

## 7. Sources (all fetched 2026-11-13)

Primary — vendor/spec/source:

1. https://webkit.org/blog/13966/webkit-features-in-safari-16-4/ (2023-03-27) — WebCodecs video in Safari 16.4.
2. https://webkit.org/blog/17333/webkit-features-for-safari-26-0/ (2025-09-15) — AudioEncoder/AudioDecoder.
3. https://webkit.org/blog/17862/webkit-features-for-safari-26-4/ (2026-03-24) — WebTransport, HTTP/2 fallback.
4. https://webkit.org/blog/18325/webkit-features-for-safari-27-0/ (2026-09-17) — jitterBufferTarget, targetLatency.
5. https://webkit.org/blog/12445/new-webkit-features-in-safari-15-4/ — requestVideoFrameCallback.
6. https://w3c.github.io/webcodecs/ — IDL, SecureContext, optimizeForLatency definition.
7. https://www.w3.org/TR/webcodecs-avc-codec-registration/ — description ⇒ avc, absent ⇒ annexb.
8. https://w3c.github.io/webrtc-pc/ — RTCPeerConnection IDL (no SecureContext).
9. https://websockets.spec.whatwg.org/ — bufferedAmount semantics.
10. https://w3c.github.io/webrtc-encoded-transform/ — transform after depacketiser.
11. https://www.rfc-editor.org/rfc/rfc8831.txt — SCTP data channels, partial reliability.
12. https://www.rfc-editor.org/rfc/rfc8841.txt — `a=max-message-size`, default 64K.
13. https://bugs.webkit.org/show_bug.cgi?id=325278 — optimizeForLatency/VTB, 2026-09-25.
14. https://bugs.webkit.org/show_bug.cgi?id=267121 — keyframes required, 2024-01-04.
15. https://bugs.webkit.org/show_bug.cgi?id=279753 — per-decoder reordering, 2024-09-16.
16. https://bugs.webkit.org/show_bug.cgi?id=329695 — GTK 35 ms decode→output, 10 ms texImage2D, 2026-10-31.
17. https://bugs.webkit.org/show_bug.cgi?id=322201 — WebTransport.datagrams undefined on iOS, 2026-08-20.
18. https://bugs.webkit.org/show_bug.cgi?id=319879 — WebTransport.ready never resolves (mvfst), 2026-07-21.
19. https://bugs.webkit.org/show_bug.cgi?id=241124 — MSTP request, resolved.
20. https://bugs.webkit.org/buglist.cgi?quicksearch=WebCodecs&order=bug_id%20DESC — bug list (titles used for 318440, 321880, 329786, 258569, 309518, 329242).
21. WebKit source: WebCodecsVideoDecoder.cpp/.idl, WebCodecsVideoDecoderConfig.idl/.h, platform/VideoDecoder.h, platform/VideoDecoder.cpp, VideoDecoder idl — raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/... (URLs inline above).
22. WebKit source: RTCPeerConnection.idl, RTCDataChannel.idl, RTCRtpReceiver.idl, RTCSctpTransport.cpp, LibWebRTCDataChannelHandler.cpp, LibWebRTCSctpTransportBackend.cpp, WebSocket.idl.
23. WebKit source: webtransport/WebTransport.cpp, WebTransport.idl, WebTransportOptions.idl, WebTransportDatagramDuplexStream.cpp.
24. https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/modules/webcodecs/video_decoder.idl — SecureContext.
25. https://raw.githubusercontent.com/webrtc-sdk/webrtc/main/video/rtp_video_stream_receiver2.cc — transform after packet_buffer_.
26. https://raw.githubusercontent.com/webrtc-sdk/webrtc/main/pc/sdp_offer_answer.cc — max message size negotiation.
27. MDN browser-compat-data (raw GitHub): api/VideoDecoder.json, VideoEncoder.json, AudioDecoder.json, WebTransport.json, RTCRtpScriptTransform.json, MediaStreamTrackProcessor.json, RTCRtpReceiver.json, RTCDataChannel.json, HTMLVideoElement.json.
28. https://caniuse.com/webcodecs and https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/webcodecs.json — version ranges + "Video-only support".

Secondary:

29. https://github.com/w3c/webcodecs/issues/885 — VTDecoderXPCService background leak (reporter account).
30. https://github.com/w3c/webcodecs/issues/55 — output order discussion.
31. https://github.com/w3c/webcodecs/issues/491 — optimizeForLatency performance report.
32. https://webrtc.github.io/webrtc-org/experiments/rtp-hdrext/playout-delay/ — playout-delay header extension.
33. https://issues.chromium.org/issues/40857774 — Chrome H.264 HW decoder buffers until next keyframe (title only, from search snippet).

Unverified / could not confirm:

- iOS Safari's `decode()`→frame-visible latency; 1080p60 sustained decode on a specific iPhone.
- Whether Safari's WebCodecs is reachable on an insecure `http://LAN-IP` page (IDL says yes, spec says no).
- Whether WebKit's `VideoDecoder` decodes **Annex B** H.264 reliably; whether `avc3` in-band parameter sets are honoured when `description` is set.
- Safari's advertised `a=max-message-size` value.
- Whether Safari disables Nagle on WebSocket.
- Whether Safari honours the `playout-delay` RTP header extension.
- Whether WebKit enforces `serverCertificateHashes` for dedicated WebTransport (option accepted in source; no docs/bugs).
- Apple's `kVTDecompressionPropertyKey_RealTime` documentation page returned an empty document (JS-rendered), so its exact semantics are unquoted.
- 12-bit HEVC crash bug 329242, HEVC/AV1 details — outside scope.
