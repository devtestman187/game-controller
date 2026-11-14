# Native mobile viewer routes (iOS/Android, 1080p60 H.264, LAN + internet)

Research date: 2026-11-13. Legend: [S] = from a fetched source (URL given), [M] = my background knowledge, not verified in this session, [I] = my inference.
Search was shallow on several points; "NOT FOUND" marks gaps. Verify [M] items before relying on them.

## 0. Bottom line (all [I])
- Cheapest path that reuses the current sender: native libwebrtc (via flutter_webrtc or a native plugin) with minimum playout delay forced to 0, plus the playout-delay RTP header extension from the sender. Latency is bounded by the libwebrtc frame assembly + MediaCodec/VideoToolbox decode + texture copy + vsync. No new transport needed.
- Lowest latency path: custom transport + direct VideoToolbox / MediaCodec decode with own frame pacing (Moonlight-style). Largest effort; loses WebRTC NAT traversal and congestion control unless rebuilt.
- Moonlight reuse is attractive technically but GPL-3.0 makes an App-Store release of derived code a legal risk (sec. 7).
- A middle route: libdatachannel (WebRTC transport: ICE/DTLS/SRTP) + own small jitter buffer + direct hardware decoders. Keeps the existing sender, drops libwebrtc's jitter buffer.
- No source found gives glass-to-glass numbers for a flutter_webrtc / native libwebrtc video receiver on phones. Prototype needed.

## 1. Flutter route: flutter_webrtc
Facts
- MIT licence; platform table in README: Android, iOS, Web, macOS, Windows, Linux, Embedded, Fuchsia (audio/video + data channel). Tizen/eLinux community ports. tvOS and Android TV are not mentioned. 713 open issues. [S] https://github.com/flutter-webrtc/flutter-webrtc (fetched 2026-11-13)
- README capture did not mention hardware decode, jitter buffer or latency controls. [S, absent]
- Browser API `RTCRtpReceiver.jitterBufferTarget` (ms) exists; MDN marks it limited availability. Earlier name `playoutDelayHint` (seconds). [S] https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget ; https://groups.google.com/a/chromium.org/g/blink-dev/c/bReU8otUmdk ; Dart web binding: https://api.flutter.dev/flutter/package-web_web/RTCRtpReceiver/jitterBufferTarget.html
- The control is a MINIMUM target delay; there is no way to cap maximum delay, and getting delay back down is slow. [S] W3C webrtc-extensions discussion, https://github.com/w3c/webrtc-extensions/issues/46 (from search snippets, Feb-Mar 2024)
- NOT FOUND: whether flutter_webrtc's Dart `RTCRtpReceiver` forwards jitterBufferTarget/playoutDelayHint to native Android/iOS. Search for a flutter-webrtc issue returned nothing.
Background / inference
- [M] flutter_webrtc on mobile ships libwebrtc binaries; Android uses MediaCodec HW decoder, iOS uses VideoToolbox. Video reaches Flutter as a GPU texture (SurfaceTexture / CVPixelBuffer). The extra copy/latency of the texture path is not quantified anywhere I found.
- [I] If the Dart API lacks the setter, a fork adding a method-channel call to the native receiver is small, but check native method names in the pinned libwebrtc revision.
- [I] tvOS / Android TV: flutter_webrtc does not advertise tvOS, and Flutter has no official tvOS target. An Apple TV client would need native Swift.
Other Flutter options
- [M] media_kit (libmpv/FFmpeg): can play raw H.264 over UDP/RTP/SRT with low-latency mpv options; practical floor perhaps 100-200 ms; NOT researched here.
- [I] Best "one codebase" shape: Flutter UI/menus/gamepad in Dart; transport + decoder in native code behind (a) a custom native Texture plugin, or (b) a PlatformView around AVSampleBufferDisplayLayer / SurfaceView. (b) is usually lower latency but has layout friction (Android platform views have known performance quirks [M]).

## 2. Native libwebrtc: control beyond what Safari gives
- Playout-delay RTP header extension: sender signals min/max smoothing delay, 12 bits each at 10 ms granularity; min=max=0 asks for no smoothing; receiver treats it as best effort. [S] https://webrtc.googlesource.com/src/+/main/docs/native-code/rtp-hdrext/playout-delay/README.md
- A libwebrtc change "Preserve min and max playout delay from RTP header extension" was reverted once because audio could drift out of sync with jittery video; a later fix addressed base-minimum-delay initialisation. [S] https://webrtc.googlesource.com/src//+/85ba9972c42544c4771e394c9aa1d20bf5d09a91 ; https://webrtc.googlesource.com/src/+/3b69817e621f0f8ab3a7002eac3b70ab4b070b49
- Sender side: whether gstreamer `webrtcsink`/`webrtcbin` can negotiate and write this extension: NOT FOUND. [I] Probably doable with an RTP header-extension element or pad probe; prototype.
- [M] Native C++ API has `RtpReceiverInterface::SetJitterBufferMinimumDelay` (seconds), internal `VideoReceiveStream::SetBaseMinimumPlayoutDelayMs`, and field trials like `WebRTC-ZeroPlayoutDelay` and a low-latency-renderer trial. NOT verified from a source; confirm names in libwebrtc source before use.
- [M] Cloud-gaming deployments report roughly 30-60 ms glass-to-glass on LAN with zero playout delay; browsers typically add a 40-100+ ms jitter buffer. No source fetched.
- [I] Even at 0 ms playout, libwebrtc waits for a complete frame, has a decode queue, and renders on vsync: expect 1-2 frames (17-33 ms) above raw decode time.

## 3. Skipping WebRTC: custom transport + direct decoders
Android
- MediaFormat has `KEY_LOW_LATENCY` ("optional key describing the low latency decoding mode"), `KEY_PRIORITY` (0 = realtime) and `KEY_OPERATING_RATE`. [S] https://developer.android.com/reference/android/media/MediaFormat (API level not read; [M] KEY_LOW_LATENCY is API 30+ and vendor-dependent; Moonlight also sets vendor-specific keys for some SoCs).
- Informal decoder latency (Moonlight users): about 1.7 ms Shield TV (2019), 8.5 ms Galaxy Tab S8+, 11 ms Pixel 6 Pro (Jan 2023, "unscientific"); some MediaTek devices 11-13 ms improved to about 4 ms in a tuned fork. [S] https://lr.eu.psf.lt/r/cloudygamer/comments/104wu95/quick_latency_comparison_for_inhouse_moonlight (Reddit mirror)
- Frame pacing: delay presentation by one frame to absorb jitter; NDK `AMediaCodec_releaseOutputBufferAtTime` for timed presentation. [S] https://besthub.dev/articles/how-to-eliminate-high-latency-decoding-in-moonlight-android-for-smooth-game-streaming-d5dcac6c06bd (secondary source)
- At 120 Hz a device must decode under 8.33 ms per frame; render fps can fall below incoming fps. [S] Reddit threads in the same search (mirrors, weak)
iOS / tvOS
- Apple documents a low-latency mode for the VideoToolbox ENCODER (WWDC21-10158: H.264, hardware only, no frame reordering). [S] https://developer.apple.com/wwdc21/10158 . Decoder low-latency flags: NOT FOUND.
- [M] Decode path: `VTDecompressionSession` with asynchronous decompression and hardware acceleration, or feed CMSampleBuffers (with DisplayImmediately attachment) straight to `AVSampleBufferDisplayLayer`. SPS/PPS go into a CMVideoFormatDescription; Annex B must be converted to AVCC length-prefixed NALs.
- [I] Stream must have no B-frames and no reordering (num_reorder_frames=0 in VUI) so the decoder does not buffer.
- [I] AVSampleBufferDisplayLayer is simplest and low latency; VTDecompressionSession + Metal gives exact present-time control at higher code cost. Measure both.
- [I] Display: 60 Hz vsync adds 0-16.7 ms; ProMotion / 90-120 Hz Android reduces it. Present the newest frame and drop stale ones (CADisplayLink / Choreographer).
Transports
- [I] UDP with own packetisation (Moonlight-like RTP + FEC), QUIC datagrams (needs a QUIC lib both ends), or SRT (libsrt, MPL-2.0 [M], ARQ with configurable latency window). WebSocket/TCP: head-of-line blocking, not recommended for 60 fps over internet.

## 4. Existing open source and what can be reused
Moonlight (moonlight-stream)
- moonlight-common-c: "Core implementation of Nvidia's GameStream protocol", shared by PC/Android/iOS/embedded clients; GPL-3.0; needs a specific ENet fork; also nanors submodule (Reed-Solomon FEC [M]). [S] https://github.com/moonlight-stream/moonlight-common-c
- moonlight-ios: GPL-3.0; iOS and a "Moonlight TV" tvOS target; on the App Store as "Moonlight Game Streaming". [S] https://github.com/moonlight-stream/moonlight-ios
- moonlight-android: GPL-3.0; "client for NVIDIA GameStream and Sunshine"; Google Play, Amazon, F-Droid. [S] https://github.com/moonlight-stream/moonlight-android
- Protocol docs: none linked on the repo page. [S, absent]. [M] Protocol = HTTPS pairing/launch, RTSP setup, RTP video with FEC, ENet control channel, Opus audio RTP, AES encryption, input over ENet.
- Third-party host: only Sunshine documented. [I] A custom host would need pairing, RTSP/SDP, FEC, encryption, control messages: weeks of work, and referencing GPL code risks derivation.
- Latency: informal. [M] Often 20-40 ms end-to-end on LAN with good hardware. Decoder figures in sec. 3.
Sunshine as host
- GPL-3.0. Hosts: Windows 11+, Linux (Debian 13+, Fedora 43+, Ubuntu 22.04+), macOS 15+, FreeBSD. Capture: Windows DXGI Desktop Duplication (WGC partial), Linux KMS/DRM, NvFBC (X11), wlroots, X11, XDG portal, KWin; encoders NVENC, AMF, QuickSync, VAAPI, Vulkan Video, software. [S] https://github.com/LizardByte/Sunshine
- [I] WSL2: nothing in the fetched page about WSL2; KMS capture of a WSL2 GPU is unlikely to work. Running Sunshine natively on Windows is the documented path. Sunshine + Moonlight would replace the whole pipeline (and any custom input path), but is a quick latency yardstick.
Others
- Parsec: [M] closed source, not reusable. NOT researched.
- Steam Link / Steam Link SDK: NOT FOUND this session. [M] Closed source apps.
- KinoConsole: NOT researched.
- Selkies-GStreamer: MPL-2.0 (single weak source); browser WebRTC client with GStreamer server; latency claims are project claims. [S] https://github.com/selkies-project/selkies-gstreamer ; https://selkies-project.github.io/selkies/design . [I] Server-side GStreamer tuning useful; client is a browser, not reusable for native.
- Neko: NOT researched. [M] Browser-based, Pion server.
- libdatachannel: MPL-2.0 since v0.18 (LGPL-2.1 before); C/C++ with C bindings; Android, iOS, macOS, Linux; RTP/RTCP and RTX retransmission for tracks. [S] https://libdatachannel.org/ ; https://github.com/achingbrain/libdatachannel/blob/master/README.md (mirror). NOT FOUND: a built-in video jitter buffer or H.264 depacketiser details. [I] Good fit for the hybrid route: ICE/DTLS/SRTP + RTP packets in, own reorder buffer, hardware decode out; budget for NACK/PLI handling yourself.
- webrtc-rs / Pion: NOT researched. [M] Permissive licences; mobile use needs FFI/gomobile; no advantage over libdatachannel here [I].
- GStreamer mobile SDK: iOS and tvOS ARM64 device targets; from 1.28 ships as `.xcframework`; min iOS 12. [S] https://gstreamer.freedesktop.org/documentation/installing/for-ios-development.html . Android: NDK prebuilt binaries, plugin selection via `GSTREAMER_PLUGINS_*` to keep size down, `androidmedia` plugin in codecs group. [S] https://gstreamer.freedesktop.org/documentation/installing/for-android-development.html (page examples are old, 1.14/1.16). Licence not on those pages; [M] LGPL-2.1+ core/plugins (avoid GPL "ugly"). webrtcbin availability in the mobile SDK not verified. [I] Same webrtcbin on both ends and a fully tunable `rtpjitterbuffer latency`, at the cost of size and build complexity.

## 5. Audio
- [I] Via WebRTC route: libwebrtc plays Opus through NetEq (adds tens of ms by default; limited tuning). Native low-latency output: Android AAudio/Oboe in LowLatency performance mode (Oboe Apache-2.0 [M]); iOS AVAudioEngine/RemoteIO with a short IO buffer (about 5 ms). libopus (BSD) for decode.
- One report: separate WebRTC streams for audio and video cut sync-induced delay from 150-200 ms to 10-20 ms (other project). [S] https://github.com/m1k1o/neko/issues/339 (search snippet; indicative only)
- [I] Audio must not wait for video; for games accept slightly loose lip sync.

## 6. Internet use
- NAT traversal: WebRTC route has ICE/STUN/TURN built in. [I] TURN relay at 1080p60 (roughly 15-30 Mbit/s) is costly; prefer direct P2P or a VPN/overlay network.
- Congestion control: [M] libwebrtc has transport-wide CC with bandwidth estimation, NACK, PLI/FIR keyframe requests, optional ULPFEC/FlexFEC. libdatachannel gives RTX/NACK primitives; you build bitrate adaptation yourself [I].
- Moonlight: [M] user-configured bitrate, Reed-Solomon FEC per frame, requests IDR/reference invalidation via control channel on unrecoverable loss, no real bandwidth estimation. Great on LAN, fair on good internet.
- [I] A custom transport needs hole punching + relay fallback, loss recovery (FEC + selective NACK + IDR policy) and rate control; WebRTC provides these, Moonlight protocol only the loss part.

## 7. App-store and distribution
- GPL on the App Store: Apple removed VLC for iOS in Jan 2011 after a copyright-holder complaint that App Store terms conflict with GPLv2; FSF agreed. One source says VLC returned after relicensing (unverified). [S] https://www.engadget.com/2011-01-09-the-gpl-the-app-store-and-you.html ; https://www.macrumors.com/2010/10/31/last-chance-to-get-vlc-for-iphone-ipad-likely-to-be-pulled-from-app-store/ ; https://www.computerworld.com/article/1347653/gplv2-blocks-vlc-from-apple-s-app-store.html
- Moonlight iOS is on the App Store under GPL-3.0, published by its own project. [S] https://github.com/moonlight-stream/moonlight-ios . [I] Copyright holders can distribute their own code; a third party forking Moonlight code into a proprietary or differently licensed app cannot rely on that. A fork would have to be GPL-3.0 with source and still carries the original App Store tension. Get legal advice; do not copy Moonlight code into the app tree. Independent re-implementation of the protocol is a different matter.
- Permissive/usable: libwebrtc (BSD-3 [M]), flutter_webrtc (MIT [S]), libdatachannel (MPL-2.0 [S]; publish changes to MPL files), GStreamer (LGPL [M]; relinking concerns on iOS [I]).
- Binary size [M, unverified]: libwebrtc roughly 10-20 MB per arch; GStreamer minimal static 10-30 MB; libdatachannel + TLS a few MB.
- iOS local network permission [M]: iOS 14+ needs `NSLocalNetworkUsageDescription` (and Bonjour types if using mDNS); first LAN connection shows a prompt. Android: INTERNET/ACCESS_NETWORK_STATE; multicast lock for mDNS; Android 13+ NEARBY_WIFI_DEVICES may apply. A video stream does not survive app backgrounding on either OS [M/I]. Not verified this session.

## 8. Comparison (all effort/latency numbers are [I] unless marked)
| Route | Effort (small team) | Glass-to-glass LAN | Risk | Reuses webrtcsink sender | Reach |
|---|---|---|---|---|---|
| A. flutter_webrtc as-is | Low (days) | 100-200 ms (default jitter buffer) | Medium: no known latency knobs | Yes | Android, iOS; tvOS/Android TV not listed |
| B. flutter_webrtc fork (min playout 0 + playout-delay ext from sender) | Medium (1-3 wk) | about 50-90 ms | Medium: libwebrtc internals, texture copy | Yes (add ext at sender) | Android, iOS |
| C. Native libwebrtc app (Swift/Kotlin), Flutter shell where possible | Medium-high | about 50-90 ms | Medium | Yes | Android, iOS, tvOS, Android TV |
| D. libdatachannel + own jitter buffer + VideoToolbox/MediaCodec via FFI | High (1-2 months) | about 35-70 ms | Medium-high: own NACK/pacing code, interop with webrtcbin | Yes, if interop works | Android, iOS, tvOS, Android TV |
| E. Custom UDP/QUIC/SRT + direct decoders | High (2+ months) | about 30-60 ms | High: NAT, congestion, loss all DIY | No (new sender) | All native |
| F. Sunshine host + Moonlight clients | Very low (days) | about 25-50 ms ([M] community) | Licence/product fit; replaces host | No | Android, iOS, tvOS, more |
| G. GStreamer mobile SDK + webrtcbin | Medium-high | about 60-100 ms | Medium: size, LGPL, build pain | Yes | Android, iOS, tvOS |

## 9. What must be prototyped
1. flutter_webrtc: does Dart expose jitterBufferTarget on Android/iOS? Measure baseline 1080p60 glass-to-glass (high-speed camera or LED + photodiode).
2. Same with min playout delay forced to 0 (native patch) and playout-delay extension (0,0) from webrtcsink; check A/V sync and stutter on Wi-Fi.
3. Confirm libwebrtc field-trial names and `SetJitterBufferMinimumDelay` in the exact revision flutter_webrtc ships.
4. Texture path cost: Flutter Texture vs PlatformView (SurfaceView / AVSampleBufferDisplayLayer) on 60 and 120 Hz phones.
5. libdatachannel receiving webrtcsink (SDP/ICE/DTLS interop, RTX/NACK, PLI) feeding MediaCodec (KEY_LOW_LATENCY) and VideoToolbox (DisplayImmediately).
6. Decoder-only microbenchmark on target devices, with sender B-frames off and num_reorder_frames=0.
7. Internet test: 1-3% loss and 30-80 ms RTT (netem): libwebrtc BWE/NACK vs own FEC/IDR policy.
8. Sunshine + Moonlight for a day as a latency yardstick (no code reuse).
9. Legal check on GPL-3.0 before any Moonlight code enters the tree; verify iOS local-network and background behaviour on a real device.

## 10. Gaps
Steam Link, Parsec, KinoConsole, Neko, webrtc-rs/Pion, media_kit not researched; libwebrtc field-trial and native API names, binary sizes and nearly all glass-to-glass figures are [M]/[I] only. Several [S] items come from search snippets or mirrors (Reddit mirrors, secondary blogs), not primary docs.
