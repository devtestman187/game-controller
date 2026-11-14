# Showing a live H.264 1080p60 game stream on TV platforms (research)

Researched 2026-11-13 with web search/fetch only. Legend: [S] = sourced (URL given), [I] = my inference or recollection, not verified in a source, [?] = could not confirm.
Target: press-to-screen under ~100-150 ms. Sender today: WebRTC H.264 from a home PC. Host could change transport.

Method caveat: search returned summaries; official pages were fetched for engine tables, Samsung game mode, Roku media specs, flutter-tizen, LG forum. Several vendor feature matrices were unreadable, so some rows are [?].

## 0. Key findings up front
1. Samsung Tizen has an official, documented WebRTC low-latency "game mode" for web apps on 2022+ TVs (Web Engine M85+) [S]. It is the only TV-vendor path that is open and documented for exactly our use case.
2. LG webOS: WebRTC is restricted. An LG reply dated 2026-01-07 says "WebRTC is only available on contracted partner apps" [S]. Native apps are not officially supported [S, community]. Moonlight on webOS exists only via homebrew/dev mode.
3. tvOS has no web view [I]; only a native app works, with a native WebRTC build or our own transport + VideoToolbox + AVSampleBufferDisplayLayer. Best technical control, small TV share.
4. Android TV / Google TV / Fire TV (Fire OS): native app with MediaCodec low-latency decode; Moonlight Android proves it [S]. Most controllable, best latency class.
5. Roku: HLS/DASH only for video; live must stay >= 30 s behind the live edge per Roku docs [S]. Not viable for interactive streaming.
6. Casting (AirPlay, Cast) is a fallback only: ~50-300 ms figures come from weak vendor blogs [S weak] and we do not control it.

## 1. LG webOS
**App model** [S]: web app (HTML/JS, Enact etc.) in the TV's Chromium; submitted via LG Seller Lounge. Native NDK is "not officially supported"; community toolchain is reverse-engineered, its meta layer deprecated 2023-07-03 (https://webosbrew.org/pages/native-development , https://www.github.com/webosbrew/meta-lg-webos-ndk). LG gave a non-answer to an NDK request (https://forum.webostv.developer.lge.com/t/access-to-ndk-download/1524).
**Engine by platform release** [S] https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine (fetched 2026-11-13): webOS 3.x 2016-17 Chromium 38; 4.x 2018-19 C53; 5.x 2020 C68; 6.x 2021 C79; 22 (2022) C87; 23 (2023) C94; 24 (2024) C108; 25 (2025) C120; 26 (2026) C132. Table is by platform release; specs vary by model, check on device.
**Flutter** [S]: LG blog (undated) says Flutter apps ship on 2024 Japan TVs, more in 2025/2026; third-party access only via "closed beta", tooling hoped for later; a sidebar teaser says "flutter-webOS SDK officially available", conflicting and unverified (https://webostv.developer.lge.com/news/2024-07-15-new-and-successful-experiment-of-webos-with-flutter). Treat as not usable by a small team yet [I].
**WebRTC** [S]: LG forum 2026-01-07: "WebRTC is only available on contracted partner apps"; contact Seller Lounge 1:1 Q&A > Partnership (https://forum.webostv.developer.lge.com/t/inquiry-regarding-webrtc-support-on-webos-tv/28059). Older thread: samples worked on webOS 6.3.2 (C79), camera/mic only for LG apps (https://forum.webostv.developer.lge.com/t/webrtc-support-in-webos-tv/2306). Receive-only RTCPeerConnection in a non-partner store app: [?] maybe blocked.
**WebCodecs** [I]: Chromium 94+ means webOS 23+ in principle; whether LG enables it and uses hardware decode: [?]. H.264 hardware decode through `<video>`/MSE is normal; HEVC not on webOS 22 [S weak].
**Other routes** [I]: MSE fed over WebSocket (fMP4 frames) works in any web engine but buffers; no raw UDP in web.
**Evidence**: GeForce NOW app on webOS (beta Nov 2021, https://www.lg.com/global/newsroom/news/media-entertainment-solution/lg-to-bring-nvidia-geforce-now-cloud-gaming-to-webos-smart-tvs/ ); Xbox app on webOS 24+ and some 2022/2023 after update (https://www.xbox.com/xbox-on-tvs , https://www.techradar.com/televisions/your-tv-is-now-an-xbox-lg-displays-can-now-cloud-stream-game-pass-games-without-a-console). Web-vs-native build not documented [?]; likely partner status [I]. GFN guidance: under 80 ms RTT to data center, under 40 ms ideal (https://www.thefpsreview.com/2021/11/20/lg-is-bringing-geforce-now-to-webos-smart-os-tvs). No press-to-photon figure published [?].
**Homebrew**: moonlight-tv (mariotaku), GPL-3.0, webOS client, ~1.5k stars, installs through dev-manager-desktop (https://github.com/mariotaku/moonlight-tv). Not store-distributable [I].
**Distribution**: Seller Lounge, individual or corporate seller; fee not on official page; third party says free (https://webostv.developer.lge.com/distribute/app-ecosystem). Developer Mode sessions expire and installed apps are removed if lapsed [S, community].

## 2. Samsung Tizen
**App model** [S]: web app (HTML/JS, packaged .wgt, config.xml) in Chromium; Seller Office submission. Plus WebAssembly with Tizen WASM player/sockets extension (below).
**Engine by model year** [S] https://developer.samsung.com/tv/develop/specifications/web-engine-specifications (fetched 2026-11-13): 2017 M47, 2018 M56, 2019 M63, 2020 M69, 2021 M76, 2022 M85, 2023 M94, 2024 M108, 2025 M120, 2026 M130. Firmware does not bump the engine major [S weak, Floatleft]. WebRTC API row: 2026 "Yes", 2025 "Yes (partially)", older years unreadable in my extraction [?].
**Official WebRTC game mode** [S] https://developer.samsung.com/smarttv/develop/guides/cloud_gaming/cg_implement_webapp.html : config.xml metadata `http://samsung.com/tv/metadata/use.game.mode` = true; 2022+ models with M85+ only (older cannot submit with the key); SDP must carry `a=imageattr` (e.g. fixed 1920x1080@60); one audio + one video track in the same `<video>`; server must answer FIR; disable tracks when app is backgrounded; app needs a connection-diagnostics menu; gamepad guide separate. Codec, ms target and partner programme not stated. Samsung presumably cuts its internal buffering in this mode [I].
**Jitter controls** [?]: unknown whether `jitterBufferTarget`/`playoutDelayHint` are honoured; game mode likely replaces them [I]. In desktop Chromium `jitterBufferTarget` is ms, 0-4000, a preference only (https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget). I recall it shipping around Chromium 114 [I, unverified], so absent on M85-M108 TVs; the older Chromium-only `playoutDelayHint` (seconds) is the likelier knob (https://groups.google.com/a/chromium.org/g/blink-dev/c/4W4orKqA3Rs).
**Field reports** [S weak]: getUserMedia fails in a Tizen 7 packaged app (https://developer.tizen.org/?p=16289); a 2017 TV had data-channel trouble (https://developer.tizen.org/?p=9296). We only receive video, so mostly irrelevant [I].
**WASM raw-socket route** [S] https://developer.samsung.com/smarttv/develop/extension-libraries/webassembly/game-streaming-on-tizen-tv-with-wasm.html : Moonlight-ChromeOS port using Tizen Sockets Extension (raw TCP/UDP, Workers only) and Tizen WASM Player (ElementaryMediaStreamSource, hardware decode, "kLow"/"kUltraLow", media-element rendering preferred). Takes H.264/H.265 NAL units; no latency numbers; support by model year [?].
**Flutter** [S]: flutter-tizen, BSD-3-Clause, sponsored/maintained by Samsung Research, TV supported on Tizen 6.0 (2021)+, CLI only (https://github.com/flutter-tizen/flutter-tizen , https://developer.samsung.com/smarttv/develop/native/flutter.html). A custom low-latency pipeline in Flutter would need a native plugin [I].
**Evidence**: Xbox app on 2020+ Samsung TVs and Gaming Hub (https://www.xbox.com/xbox-on-tvs); GeForce NOW/Luna/Boosteroid in Gaming Hub [S weak, third party]. Likely web WebRTC apps given Samsung's own guide [I].
**Homebrew**: moonlight-chrome-tizen (OneLiberty/brightcraft forks), WASM, Tizen 5.5+, install via dev mode + installer or sdb; licence not shown on page, upstream Moonlight ChromeOS is GPL-3.0 [I] (https://github.com/OneLiberty/moonlight-chrome-tizen). ndriqimlahu/moonlight-tizen listed GPL-3.0 (https://awesome.ecosyste.ms/projects/github.com%2Fndriqimlahu%2Fmoonlight-tizen).
**Distribution**: Seller Office (https://developer.samsung.com/tv-seller-office/overview.html); no fee on official pages; third party says none [S weak]. Dev mode: remote code 12345 + PC IP [S]. Plain WebRTC video reaches 2017+ in theory [?]; game mode 2022+.

## 3. Apple tvOS
**App model** [I]: native Swift/SwiftUI/UIKit/Metal; no WKWebView. Flutter: no official support; community embedder and plugins (https://github.com/fluttertv/plugins , https://pub.dev/packages/flutter_tvos 1.1.x); 2026 blog says no official support (https://ecorpit.com/flutter-webos-lg-tv-cross-platform-sdk-2026/); maintenance state unverified [?].
**Low-latency video** [S/I]: native WebRTC with tvOS slice exists but patchy (swarm-cloud/apple-webrtc builds tvOS arm64; stasel/WebRTC SPM build failed on tvOS in the index) [S weak: https://awesome.ecosyste.ms/projects/github.com%2Fswarm-cloud%2Fapple-webrtc]. Alternative: own UDP transport (Network.framework) + VideoToolbox H.264 decode (low-latency mode documented for encode in https://developer.apple.com/wwdc21/10158) + AVSampleBufferDisplayLayer/Metal, with our own jitter buffer [I].
**Evidence**: Moonlight iOS/tvOS (GPL-3.0) has a tvOS target and App Store listing needing tvOS 12+ (https://github.com/moonlight-stream/moonlight-ios , https://apps.apple.com/py/app/moonlight-game-streaming/id1000551566). GeForce NOW on Apple TV: [?]. Published latency: none found.
**Distribution** [S weak]: Apple Developer Program US$99/yr (third-party; Apple page unreadable); App Review; TestFlight; Xcode install. Few model years, tvOS 12+ [I].
**Reach**: small share of the TV base; not broken out in the market sources below [?].

## 4. Roku
**App model** [S]: BrightScript + SceneGraph XML; Video node plays URLs. No native code or web engine. Flutter: no [I].
**Protocols** [S] https://developer.roku.com/dev/docs/media (fetched 2026-11-13): HLS and DASH (also Smooth); AVC main/high L4.1/4.2, max 1920x1080, <= 10 Mbps; "not all devices support 1080p60"; chunks 4-6 s; live segments under 5 s; apps must stay at least 30 s behind the live edge. UDP/RTP/WebRTC not mentioned, i.e. unsupported for video.
**Sockets**: roStreamSocket/roDataGramSocket exist (https://developer.roku.com/dev/docs/architecture) [S] but no API to feed raw frames to the video pipeline, and software decode in BrightScript is infeasible [I].
**Latency class**: tens of seconds [S]. Game-streaming apps on Roku: none found [?].
**Distribution**: enrolment free per third party (https://newly.app/guides/roku-app-development) [S weak]; developer mode sideload (https://developer.roku.com/dev/docs/developer-setup) [S].
Verdict [I]: not viable; recommend a Fire TV/Google TV stick for Roku households.

## 5. Android TV / Google TV
**App model** [I]: native APK (Kotlin/Java/NDK); Flutter runs on Android TV with D-pad/focus work (https://proandroiddev.com/how-to-port-flutter-sdk-to-set-top-boxes-for-android-tv-apps-running-and-development-eaf36981f903 is about set-top ports).
**Low-latency video** [S]: MediaCodec low-latency decode added in Android 11, needs SoC vendor driver support (https://source.android.com/docs/core/media/low-latency-media). In-app libwebrtc with hardware H.264, or custom UDP, both possible [I].
**Evidence**: moonlight-android (GPL-3.0) is the reference low-latency client for Android TV/Shield/Google TV Streamer, also on Amazon Appstore/F-Droid (https://moonlight-stream.org/ , https://awesome.ecosyste.ms/projects/github.com%2Fmoonlight-stream%2Fmoonlight-android). Published latency: none found.
**Distribution** [I]: Google Play (one-time dev fee, I recall US$25, unverified); trivial sideload. Fragmentation: many models, uneven decoder quality, older TVs below Android 11.
**Reach** [S]: Europe: Google TV leads, under 32% in 2025 (Omdia via https://9to5google.com/?p=712995); US streaming devices + TVs: Roku first, then Fire TV and Google TV (Streamable, July 2026, https://www.sammobile.com/?p=16670956).

## 6. Amazon Fire TV
**App model** [S]: Fire OS (Android-based): same as Android TV. Newer Vega OS devices: React Native/JS with W3C media APIs; Vega 2.0 SDK Oct 2026 (https://developer.amazon.com/apps-and-games/blogs/2026/10/vega-2-0-sdk-launch). Vega WebRTC/low-latency API: [?]. APKs likely do not run on Vega devices [I, unverified].
**Evidence**: Xbox app on select Fire TV sticks/Cube (https://www.xbox.com/xbox-on-tvs); Moonlight in Amazon Appstore (moonlight-stream.org). Cheap sticks have weaker decoders [I].
**Distribution**: Amazon Appstore, ADB sideload [I].

## 7. Casting fallbacks
- AirPlay: 50-100 ms quoted for AirPlay 2 mirroring, wireless mirroring generally 20-600 ms (https://ezcast.com/blog/2387/airplay-latency , https://us.ktcplay.com/blogs/product-comparisons/miracast-vs-airplay-vs-chromecast-latency) [S weak]. Our source is a PC, so we would mirror a browser/phone; sender re-encodes; uncontrolled.
- Chromecast/Cast: mirroring ~100-300 ms (same weak sources). Custom Web Receiver is a hosted HTML5 app using the CAF player for segmented live (https://developers.google.com/cast/docs/caf_receiver/basic) [S]; WebRTC peer connection inside the receiver: [?].
- Use: "cast this web page" fallback at 150-400 ms [I]; label as non-interactive-grade.

## 8. TV-side latency we cannot control
- Outside game mode, processing can add well over 100 ms; game mode usually brings input lag to ~10-20 ms or less at 1080p60; individual processing features add 10-20 ms each (https://www.rtings.com/tv/tests/inputs/input-lag , https://www.soundandvision.com/content/new-display-measurement-input-lag , https://www.thegamer.com/reduce-input-lag-tv-guide/) [S weak]. Exact RTINGS tables not retrievable [?].
- Whether a streaming app triggers game mode automatically is unknown; Samsung `use.game.mode` is the only documented hook found [S]; LG equivalent [?].
- Plan: in-app tip asking players to enable game mode; measure with and without [I].

## 9. Market share / reach
- US in-use TVs (Parks Associates, 2026-04): Roku ~28%, Tizen ~23% (https://www.mactech.com/2026/04/23/roku-os-28-and-samsungs-tizen-os-23-account-for-the-largest-share-of-tv-operating-system-usage-in-the-us/) [S].
- US most-used OS (Parks, 2025): Tizen 34% of smart-TV owners, Roku 18% (https://www.parksassociates.com/blogs/ce-pr/sixty-one-percent-of-us-internet-households-use-their-smart-tv-as-the-primary-streaming-device) [S].
- Europe (Omdia, 2025): Google TV under 32%, Tizen second, Fire TV and Roku ~5% or below (https://9to5google.com/?p=712995) [S].
- Global (CTMA 2024 projection): Tizen 12.9%, VIDAA 7.8%, webOS 7.4%, Roku 6.4%, Fire TV 6.4%, Android TV 5.9% [S weak, secondary summary, older].
- Hisense VIDAA not researched.

## 10. Comparison table
| Platform | App technology | Low-latency route | Expected latency class | Effort (small team) | Reach | Main risk |
|---|---|---|---|---|---|---|
| Samsung Tizen 2022+ | Web app (config.xml) | Documented WebRTC game mode (current sender, SDP imageattr 1080p60) | Low, perhaps 60-120 ms [I] | Low: web player, config key, FIR, diagnostics | US ~23-34%, Europe #2 | Jitter control unknown, Seller Office review |
| Samsung Tizen 2017-21 | Web app | Plain WebRTC `<video>`, MSE, or WASM sockets + WASM player | Medium, 100-250 ms [I] | Medium | Older base | Buffering uncontrollable, WebRTC per year [?] |
| LG webOS | Web app (C79-C132) | WebRTC only for contracted partners; else MSE over WebSocket; homebrew native Moonlight | Medium-high unless partner [I] | High/uncertain | Mid | WebRTC blocked for normal apps |
| Android TV / Google TV | Native APK (Flutter possible) | libwebrtc or custom UDP + MediaCodec low-latency | Low, best [I] | Medium | Europe #1 | Decoder variance |
| Fire TV (Fire OS) | Native APK | Same as Android TV | Low [I] | Low after Android | US large | Weak sticks |
| Fire TV (Vega OS) | React Native/JS | [?] | Unknown | Unknown | Growing | New SDK |
| Apple tvOS | Native Swift (Flutter fork unofficial) | Native WebRTC or UDP + VideoToolbox + display layer | Low, best [I] | Medium-high | Small | tvOS WebRTC builds patchy |
| Roku | BrightScript/SceneGraph | HLS/DASH only | Very high, >= 30 s rule [S] | n/a | Largest in US | Unsuitable |
| AirPlay / Cast | OS receivers | Mirroring | Medium-high, 100-400 ms [S weak] | Near zero | Broad | Uncontrolled latency |

## 11. Recommended order by value for effort [I]
1. Android TV / Google TV + Fire OS: one native APK, Moonlight proves it, best control; fits Flutter. A cheap stick also gives any TV (including LG and Roku households) a path.
2. Samsung Tizen 2022+ web app with game mode: documented, existing WebRTC sender unchanged, large reach. Could be first if a web player is the cheapest build.
3. Apple tvOS native: best quality, good overlap with iPhone-controller households, more effort.
4. Casting fallback for all else, labelled "may lag".
5. LG webOS: only with a WebRTC partnership; otherwise skip.
6. Roku: skip.

## 12. Must be tested on real hardware
1. Tizen: does `use.game.mode` + `imageattr` reach under 100 ms press-to-screen on 2022/2023/2024 TVs? Are `jitterBufferTarget`/`playoutDelayHint` accepted? Measure decode+display delay (slow-motion camera or on-screen timestamp).
2. Tizen 2019-2021: does plain WebRTC play H.264 1080p60? Are Sockets/WASM Player available?
3. webOS: can a non-partner app open RTCPeerConnection and play H.264 60 fps on webOS 6/22/23/24? WebCodecs present and hardware-backed (23+)? MSE feed latency.
4. Android/Fire: MediaCodec low-latency effect per chipset (Fire Stick 4K, Google TV Streamer, cheap boxes); steady 1080p60 on Fire Stick Lite.
5. tvOS: native WebRTC (or custom) builds on tvOS arm64, hardware decode and display-layer latency.
6. Does each TV engage game/ALLM mode for these apps? Measure display lag on/off.
7. Wi-Fi vs Ethernet jitter; AirPlay/Cast measured latency with our content.
8. App lifecycle: background/resume, remote keys, Samsung track enable/disable.
9. Store review acceptance of a player app for a PC game (Samsung, LG, Apple, Google): non-technical rejection risk [I].

## 13. Reusable open source
- moonlight-android (GPL-3.0): Android TV/Fire OS reference for MediaCodec settings.
- moonlight-ios (GPL-3.0): tvOS target; VideoToolbox + display layer reference.
- moonlight-tv (GPL-3.0): native webOS/RPi client; reference only.
- moonlight-chrome-tizen forks: WASM on Tizen 5.5+; licence unconfirmed (upstream GPL-3.0 [I]).
- flutter-tizen (BSD-3-Clause); flutter-tvos plugins (licence unchecked).
- GPL code cannot be linked into a closed app without relicensing; use as study material [I, not legal advice].
- Samsung WebRTC game-mode guide has no sample repo that I found [?].
- Moonlight uses the GameStream/Sunshine protocol, not WebRTC; reuse implies a host transport change [I].

## 14. Main sources (all fetched or seen 2026-11-13)
- LG engine table: https://webostv.developer.lge.com/develop/specifications/web-api-and-web-engine
- LG WebRTC partner reply (2026-01-07): https://forum.webostv.developer.lge.com/t/inquiry-regarding-webrtc-support-on-webos-tv/28059
- LG Flutter: https://webostv.developer.lge.com/news/2024-07-15-new-and-successful-experiment-of-webos-with-flutter
- Samsung engine table: https://developer.samsung.com/tv/develop/specifications/web-engine-specifications
- Samsung WebRTC game mode: https://developer.samsung.com/smarttv/develop/guides/cloud_gaming/cg_implement_webapp.html
- Samsung WASM game streaming: https://developer.samsung.com/smarttv/develop/extension-libraries/webassembly/game-streaming-on-tizen-tv-with-wasm.html
- Roku media: https://developer.roku.com/dev/docs/media
- flutter-tizen: https://github.com/flutter-tizen/flutter-tizen
- Android low latency: https://source.android.com/docs/core/media/low-latency-media
- MDN jitterBufferTarget: https://developer.mozilla.org/en-US/docs/Web/API/RTCRtpReceiver/jitterBufferTarget
