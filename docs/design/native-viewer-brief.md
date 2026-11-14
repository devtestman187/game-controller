# Native viewer for the game stream: brief and phased roadmap

Status: plan for the owner, Nov 13, 2026. Nothing is built. No native client has been measured yet.

Sources: three research files in docs/briefs/m15/research/native-viewer/ (reuse-inventory.md, mobile-clients.md, tv-platforms.md) and our own measurements in docs/streaming-latency-journey.md.

How to read the claims. "Sourced" means the research fetched a web page or read our own code or records. "Estimate" means a guess from background knowledge or reasoning. Every latency figure for a native viewer in this brief is an estimate. Our measured figures are only the ones from the iPhone browser.

Plain terms used below:
- **Viewer**: the screen that shows the game picture.
- **Press-to-screen**: time from a button press on the controller to the change showing on the viewer.
- **Decoder**: the chip or code that turns the compressed video back into pictures. A hardware decoder is the phone's own chip for this.
- **Buffer / jitter buffer**: a waiting room that smooths out uneven arrival of video. Smoother picture, more delay.
- **LAN**: the home network.
- **Relay (TURN)**: a server in the middle that passes the stream along when two devices cannot reach each other directly.

## 1. Why
- The browser on the iPhone is stuck at 160-180 ms press-to-screen (measured: 162 to 225 ms across sittings).
- About half of that delay sits inside Safari itself (its buffer and its display step). We cannot change Safari.
- We tried our own player in the browser. Its best run was 105 ms, but three of four runs were over 150 ms and froze. It was dropped.
- A native app (a normal installed app, not a web page) controls its own buffering and decoding.
- Playing outside the home network will add network delay. The viewer has to be lean so that delay has room.

## 2. What "native viewer" means here, and the decision
A native viewer is an installed app that receives the stream and shows it using the device's own video chips, with no browser in between.

Decision made in this brief:
- Build the viewer as a screen inside our existing Flutter apps: the controller app for phones, the TV app for Android TV. The video itself is drawn by a native plugin (a small piece of platform code that Flutter calls).
- First choice for video: WebRTC through the flutter_webrtc package, with the playout delay forced to its minimum. WebRTC is the same technology the browser uses. It needs no host change. It also brings what outside-LAN play needs: connection setup through home routers, recovery from lost packets, and automatic bitrate adjustment.
- Fallback if its buffer cannot be pushed low enough: our existing "tap" frames (the raw video frames the host already offers over a WebSocket) fed straight into the platform hardware decoder. That is VideoToolbox on Apple and MediaCodec on Android, through a small plugin of our own. This reuses the tap. It needs its own sound path and its own internet transport.
- Third option, only if both fail: the libdatachannel library for the network part plus direct decoders.
- Not chosen: adopting Moonlight/Sunshine.

## 3. What we reuse and what is missing
Sourced from the code and records (reuse-inventory.md).

Reuse as it is:
- **Host pipeline**: capture, hardware H.264 encoding at 1080p60, WebRTC sending. Works today.
- **Signalling server**: the small server that introduces viewer and host. A native viewer uses the same one and the same stream list. Its message format is the stock gst-plugins-rs one, not ours. A Dart client must implement it or use a library.
- **Separate sound**: sound in its own process and its own WebRTC link (`SESSION_AUDIO=separate`). It cut the host's pipeline time from about 41 ms to 8 ms.
- **Tap path**: frames with number, host time and keyframe flags, plus a keyframe request. Works over a WebSocket on the player port.
- **Stats and marker measurement**: the viewer posts stage timings to the host every 2 seconds. The marker (small coloured cells in the picture's corner) lets a viewer work out press-to-screen. Presses are injected through the relay.
- **Bench**: `tools/stream.sh bench` runs a session and writes the report. It can wait for an outside viewer such as a phone.
- **Impairment tool**: adds loss, stalls and a bandwidth cap, for testing bad networks.
- **Flutter apps and release pipelines**: controller app (Android, iOS), TV app (Android TV, Windows, Linux), shared packages for connection and pairing, iOS builds through Codemagic to TestFlight, Android through GitHub Actions to Play testing.

Missing today:
- **No viewer discovery.** Only the controller port is advertised on the network. The stream address must be typed or added to the advertisement.
- **No pairing or token for viewers.** Anyone on the LAN who knows the address can watch. The stats and viewer endpoints accept anything from anyone.
- **No STUN/TURN or secure transport.** The player page uses an empty server list. Signalling and the player port are plain, unencrypted. Outside the LAN nothing works today.
- **No sound path outside WebRTC.** The tap carries video only.
- **No video package in any app.** No flutter_webrtc, video_player or similar in any pubspec. Nothing draws stream video in a Flutter app yet.
- **No tvOS (Apple TV) target.** Neither app has one.

## 4. Ways to build it
Effort and latency columns are estimates from mobile-clients.md; none is measured. The "Reach" column is the platforms the research could confirm.

| Route | Effort (small team) | Press-to-screen on LAN (estimate) | Main risk | Keeps our host | Reach |
|---|---|---|---|---|---|
| A. flutter_webrtc as it ships | Low | 100-200 ms | No known delay control | Yes | Android, iOS |
| B. flutter_webrtc with minimum playout delay forced (and the playout-delay header from the host) | Medium | 50-90 ms | Needs library internals; texture copy | Yes (small host addition for the header) | Android, iOS |
| C. Native libwebrtc app (Swift/Kotlin) | Medium to high | 50-90 ms | Leaves the shared Flutter code | Yes | Android, iOS, tvOS, Android TV |
| D. libdatachannel plus own buffer plus direct decoders | High | 35-70 ms | Own loss-recovery and pacing code; must work with the host's sender | Yes, if it works | Android, iOS, tvOS, Android TV |
| E. Own UDP/QUIC/SRT transport plus direct decoders | High | 30-60 ms | Router traversal, congestion, loss all built by us | No (new sender) | All native |
| F. Sunshine host plus Moonlight clients | Very low | 25-50 ms (community reports) | Licence; replaces the host | No | Android, iOS, tvOS, more |
| G. GStreamer mobile SDK with webrtcbin | Medium to high | 60-100 ms | App size, LGPL, build pain, webrtcbin on mobile unverified | Yes | Android, iOS, tvOS |

Our tap-to-hardware-decoder fallback sits between D and E: our own frames, the platform decoder, our own transport.

Recommendation:
1. Start with route B, measured first as route A. It is the cheapest route that reuses the host unchanged and it gives the internet features for free.
2. If its buffer cannot go low enough, take the tap fallback. It removes Safari's share of the delay. It does not remove the weakness of one TCP connection on bad Wi-Fi, which hurt our browser player. Outside the LAN it needs its own transport.
3. Only then consider libdatachannel (route D).
4. Do not adopt F (see section 6).

Honest note: the research found no published press-to-screen figure for flutter_webrtc on a phone. It also could not confirm that the Dart side of flutter_webrtc can set the minimum delay. A small fork may be needed. That is why Phase 0 measures before anything is committed.

## 5. New things needed
"Needs approval" marks anything that needs your word before it happens.

Packages:
- flutter_webrtc (MIT licence): used first in a throwaway app. **Needs approval** (new package, download).
- A small plugin of our own for the tap fallback, only if the first route fails. Our code; no new third-party package. A decision point at that time.
- libdatachannel (MPL-2.0): only for the third option. **Needs approval** if we get there.
- No GStreamer mobile SDK or media_kit unless a later phase asks. Each would need approval.

Apps and targets:
- A throwaway test app (Phase 0). Not shipped.
- A viewer screen in the controller app (phones) and in the TV app (Android TV, Fire TV).
- A Samsung Tizen web package (Phase 4) and an Apple TV target (Phase 5). Both new.

Servers:
- STUN (a free-to-use address finder) and TURN relay (coturn) for outside-LAN play. A relay carries the whole stream, so it costs real bandwidth money. The research puts a 1080p60 stream at roughly 15-30 Mbit/s (estimate). **Needs approval**: a relay server with a running cost. Direct connections or a private overlay network may avoid it (estimate).
- Secure transport (wss/https) with a certificate for the signalling and player ports.

Accounts and fees (from the research; fees are third-party figures or recollection, unverified):
- Apple Developer Program is already needed for TestFlight. tvOS uses the same one.
- Google Play: already in use. Amazon Appstore, Samsung Seller Office, LG Seller Lounge: separate sign-ups, no fee found on official pages. **Needs approval** to create any new account.
- A relay or cloud server account if we do not run it at home. **Needs approval**.

Devices for testing (see section 9):
- The owner's iPhone (have). At least one Android phone (which one is open).
- Android TV or Google TV device, one cheap Fire TV stick, a Samsung TV from 2022 or later, an Apple TV. A camera that films at high frame rate is useful for checking numbers. Any purchase **needs approval**.

## 6. Open source: what can be used and what cannot
This is not legal advice. The research flags a legal check before any GPL code goes near our tree.

Can use in our apps:
- **flutter_webrtc**: MIT. Sourced.
- **libwebrtc** (the engine inside it): BSD-3. From memory, unverified.
- **libdatachannel**: MPL-2.0 since v0.18. Sourced. If we change its files we must publish those changes.
- **flutter-tizen**: BSD-3-Clause. Sourced.
- **GStreamer mobile SDK**: core is LGPL from memory. Licence not on the pages the research read. Unverified. Linking rules on iOS are a concern.

Cannot copy into our apps:
- **Moonlight (clients) and Sunshine (host)**: GPL-3.0. Sourced. Copying their code into our apps would force our apps under the same licence. Apple removed VLC from the App Store in 2011 over a similar clash (sourced). Moonlight's own App Store listing is published by its owners, which a third party cannot copy.
- **Use only as a yardstick**: run Sunshine on the PC and Moonlight on a phone as a reference for what is possible on the same hardware. No code reuse.
- **Sunshine and our setup**: the research found no sign Sunshine works inside WSL2 (our setup). Its documented route is native Windows. A yardstick test therefore needs a Windows install, not our container. This is an inference.
- Reading GPL code to learn is different from copying. An independent re-implementation of a protocol is a different matter. Take legal advice before relying on that.

## 7. Platforms and trade-offs
Expected latency class and effort are estimates. The "Reach" column cites market figures from tv-platforms.md (sourced but from third parties; Parks Associates for the US, Omdia for Europe).

| Platform | How the app is built | Low-latency route | Expected latency class (estimate) | Effort | Reach | Main risk |
|---|---|---|---|---|---|---|
| iPhone / iPad | Flutter app, native plugin | flutter_webrtc with minimum delay; fallback tap into VideoToolbox | Low, 50-90 ms hoped | Medium | Our main phone users | Library may not expose the delay control |
| Android phones | Flutter app, native plugin | Same; fallback tap into MediaCodec | Low, same hope | Medium | Wide, uneven devices | Decoder quality varies by chip |
| Android TV / Google TV | Native APK, Flutter possible | libwebrtc or tap, MediaCodec low-latency mode (Android 11+, needs chip driver support) | Low, best class | Medium | Europe's largest TV system (under 32%, 2025) | Chipset differences |
| Fire TV (Fire OS sticks) | Same APK as Android TV | Same | Low | Small after Android | Large in US | Weak cheap sticks |
| Samsung Tizen | Web app in config.xml package | Documented WebRTC game mode, 2022+ TVs | Low, perhaps 60-120 ms | Small to medium | US 23-34%, Europe second | Delay control unknown; store review |
| LG webOS | Web app | WebRTC only for contracted partners | Unknown, probably high | High, uncertain | Mid | WebRTC blocked for normal apps |
| Apple tvOS | Native Swift; Flutter only by community | Native WebRTC or own transport plus VideoToolbox | Low, best class | Medium to high | Small | tvOS WebRTC builds are patchy |
| Roku | BrightScript, no native code | HLS/DASH only | Tens of seconds | Not viable | Largest in US | Cannot do it |
| Casting (AirPlay, Cast) | OS receivers | Mirror a page or phone | 100-400 ms, weak sources | Near zero | Broad | Delay not under our control |

Fire TV's newer Vega OS devices are a different system (React Native). Their WebRTC support is unconfirmed. Treat them as unknown.

**LG webOS.** An LG forum reply dated Jan 7, 2026 says WebRTC is only available to contracted partner apps. Native apps are not officially supported either. So an ordinary store app cannot count on WebRTC. The fallback is a cheap Android TV or Fire TV stick plugged into the LG. A partnership enquiry to LG is the only other route. LG's Flutter support is in closed beta (sourced, with a conflicting teaser unverified).

**Roku.** Roku plays video only as HLS or DASH. Its own documentation says apps must stay at least 30 seconds behind the live edge. That is not workable for a game. The fallback is the same stick: a Fire TV or Google TV device on the Roku household's TV.

**Samsung.** Samsung documents a WebRTC "game mode" for web apps on 2022 and newer TVs (a config key, an image-size line in the connection description, one audio and one video track in the same video element, answering keyframe requests). Our existing browser player could be reused. Two points from the documentation need checking against our setup: the one audio plus one video track rule (our separate sound uses a second connection), and whether the delay controls we use are honoured at all. Samsung's own buffering cut in game mode is presumed, not stated.

**Apple tvOS.** There is no web view, so only a native app works. Flutter has no official tvOS support. A community embedder and plugins exist but their upkeep is unverified. The research notes flutter_webrtc has no tvOS build. A native Swift player with our own transport and VideoToolbox is the likely shape, with Moonlight's tvOS client as proof that it can be done (reading only; GPL).

## 8. Phased roadmap
Sizes are relative: small, medium, large. No calendar estimates. A tag, a TestFlight or Play build, and any tester promotion happen only on the owner's word, as always.

### Phase 0. Spike and measure (small to medium)
Goal: find out whether a native viewer beats the browser at all, before building anything real.  
Work:
- A throwaway Flutter app (iPhone and one Android device) with a plain flutter_webrtc viewer against the unchanged host.
- Port the marker reader so the app can measure press-to-screen the same way the browser does.
- Then force the minimum playout delay (and test the library's delay controls).
- Check whether the host's webrtcsink can send the playout-delay header extension. This is a hint from the sender that smoothing is not wanted.
- Only if WebRTC misses the gate: a spike that feeds tap frames into the hardware decoder.  
Test and validate:
- Press-to-screen with the marker and with the latency card, as in the browser sittings.
- Freezes, dropped frames and sound sync.
- Whether the Dart side exposes the delay control or a small fork is needed.  
Gate: 100 ms or less press-to-screen on the LAN in four runs in a row, with no more freezes than the browser player, and the owner says it feels fine. (This is stricter than the 150 ms roadmap gate for the browser. A native app that cannot beat 100 ms is not worth the added work.)  
Stop rule: if neither route passes, stop and keep the browser player.  
Needs the owner: approval of flutter_webrtc in a throwaway app; a way to get a test build onto the iPhone (see section 10); an Android device.

### Phase 1. Phone viewer on the LAN, inside the controller app (medium)
Goal: a phone shows the stream inside the controller app at home.  
Work:
- Stream discovery: advertise the stream next to the existing controller advertisement.
- A signalling client in Dart.
- Sound from the separate sound link.
- Stats reported to the bench, as the browser does.
- App lifecycle: going to the background, rotation, reconnecting. Video does not survive backgrounding on either system (estimate).
- iOS local network permission prompt and the Bonjour entry.  
Test and validate:
- Lifecycle on real phones; reconnect after a Wi-Fi drop; thirty minutes with no stall.
- Press-to-screen against the Phase 0 figure (no regression).  
Gate: thirty minutes of play with no stall or sound drift, press-to-screen within the Phase 0 range, and the owner's family finds it fine.  
Needs the owner: internal TestFlight and Play internal builds, on your word.

### Phase 2. Outside the LAN (large)
Goal: the viewer works from another network and from mobile data.  
Work:
- STUN/TURN relay, secure transport (wss/https) and certificates.
- Viewer pairing and tokens. The stats and viewer endpoints are open today.
- Behaviour under loss and limited bitrate, using the impairment tool.
- Measurement on mobile data and from a second home.  
Test and validate:
- Loss of 1-3% and added round trip of 30-80 ms (the research's suggested test).
- A 2-second network drop and recovery without a restart.
- Whether a direct connection is made without the relay, and how often the relay is needed.  
Gate: a stated press-to-screen target, set from the Phase 0 figure plus the measured network delay, and stable sound.  
Needs the owner: relay server and its running cost; any new cloud account; a second location for testing.

### Phase 3. Android TV, Google TV and Fire TV in the TV app (medium)
Goal: the existing TV app can also show the stream.  
Work:
- A viewer mode in the TV app. Today it is the host app that draws the game, so this is a separate mode.
- MediaCodec low-latency mode per chipset, including one cheap stick.
- The TV's game mode.
- Remote-control navigation.
- Note: flutter_webrtc does not list Android TV; check that it runs there.  
Test and validate:
- Steady 1080p60 on a cheap stick; decoder behaviour per chipset.
- Whether the TV switches to game mode on its own.  
Gate: smooth 1080p60 on a Google TV and on a Fire TV stick, press-to-screen on the LAN within the Phase 0 range plus a stated TV allowance.  
Needs the owner: test devices; Amazon Appstore account if Fire TV is shipped.

### Phase 4. Samsung Tizen, 2022 and newer (small to medium)
Goal: a Samsung app that reuses our browser player.  
Work:
- Package the browser player as a Tizen web app with the documented game mode.
- Make the sound and picture fit Samsung's one-audio-plus-one-video rule.
- Connection diagnostics menu, as Samsung requires.
- Store submission.  
Test and validate: real Samsung TVs from 2022, 2023 and 2024; whether the delay controls are accepted; decode-and-display delay with and without game mode.  
Gate: press-to-screen on a real TV within a figure to be set from the measurement, and the store accepts it.  
Needs the owner: a Samsung TV; Seller Office account.

### Phase 5. Apple TV (medium to large)
Goal: a native tvOS player.  
Work:
- A tvOS target. Decide between the Flutter community embedder and a small native Swift app, using the Phase 0 findings (whether our viewer is plain libwebrtc or our own decoder path).  
Test and validate: a WebRTC build for tvOS, or our own transport; hardware decode and display delay on a real Apple TV.  
Gate: smooth 1080p60 on a real Apple TV within the Phase 0 range plus a TV allowance.  
Needs the owner: an Apple TV; App Review.

### Phase 6. LG and Roku (small)
Goal: decide, not build.  
Work:
- LG: a partnership enquiry through Seller Lounge to ask for WebRTC rights.
- Roku and LG households: recommend a cheap Google TV or Fire TV stick.
- Revisit later if LG answers or the market changes.  
Gate: a written decision.  
Needs the owner: whether to send the LG enquiry (a message on your behalf).

### Running alongside from the start: instant controller feedback
The controller reacts at once and does not wait for the stream. It helps on every platform and is already the next item in the m15 status notes. Size: small to medium.

## 9. Things to test on real hardware
One list from both research files. Nothing here has been measured yet.

Phones and tablets:
- iPhone and an Android phone: flutter_webrtc press-to-screen with the default setting, then with minimum playout delay forced.
- Does the Dart side expose the delay control on Android and iOS, or is a fork needed?
- Do the delay knob names exist in the libwebrtc revision flutter_webrtc ships?
- Can webrtcsink send the playout-delay header and does a phone honour it? Does sound stay in sync with picture?
- Cost of the Flutter texture path against a platform view, on 60 Hz and 120 Hz phones.
- Tap into VideoToolbox (the display-immediately flag) and MediaCodec (the low-latency key); hardware decode really in use.
- Loss of 1-3% and 30-80 ms round trip: libwebrtc's own adaptation against our own handling.
- iOS local network permission, Bonjour, background and resume on a real device.
- Sunshine plus Moonlight for a day as a yardstick on the same PC and phone, if you want it.

TVs and sticks:
- Samsung: game mode plus the image-size line gives under 100 ms on 2022, 2023, 2024 TVs? Are `jitterBufferTarget` or `playoutDelayHint` accepted? Does plain WebRTC play H.264 1080p60 on 2019-2021 models?
- webOS: can a non-partner app open a WebRTC connection on webOS 6, 22, 23, 24? Is WebCodecs there and hardware-backed (webOS 23+)?
- Android and Fire: MediaCodec low-latency effect per chipset (Fire TV Stick 4K, Google TV Streamer, a cheap box); steady 1080p60 on a Fire TV Stick Lite.
- tvOS: a WebRTC build for tvOS arm64, hardware decode and display layer delay.
- Does each TV switch to game mode for these apps? Display lag on and off.
- App lifecycle: background and resume, remote keys, Samsung track enable and disable.

## 10. Risks and open questions
- **No native route is measured.** Every native latency figure in this brief is an estimate. Phase 0 exists to replace them.
- **Library knobs are unverified.** The research did not confirm that flutter_webrtc passes the delay setting to the phone. The libwebrtc function names are from memory and must be checked in the shipped revision.
- **The delay control is only a minimum target.** There is no way to cap the maximum delay, and getting it back down is slow (sourced from a W3C discussion). Even with zero smoothing, libwebrtc waits for a whole frame, has a decode queue and draws on the screen refresh (estimate: one to two frames more).
- **Reading the marker in a Flutter app.** The marker is read from decoded pixels. A video shown as a Flutter texture may not expose pixels easily. The port may need native frame access. This is my inference, not in the research.
- **Getting a test build onto the iPhone.** iOS builds go through Codemagic to TestFlight today. A throwaway app needs the same path or another signing route. Not confirmed from the record whether a local Mac exists.
- **The tap fallback inherits TCP.** Our own sittings showed that stalls on one TCP connection cause the delay to build up in the kernel, out of reach of the sender. A native decoder removes Safari's part, not this one. The tap server also listens on loopback behind the relay, and has no sound.
- **Chipset differences on Android TV.** Decoder delay and 1080p60 steadiness vary by chip. Informal figures run from about 2 ms to 13 ms decode (sourced from user forum posts, weak).
- **Store review.** Apple, Google, Samsung and LG could reject a player app for a PC game. Estimate; unmeasured.
- **GPL.** Do not copy Moonlight or Sunshine code. Take legal advice before relying on any reading of it.
- **Relay running cost.** TURN carries the full stream. The figure is unknown until we measure a real session's bitrate through a relay.
- **TV picture processing outside game mode.** Can add well over 100 ms (weak sources). We cannot fix it, only ask players to turn game mode on and measure.
- **Sound sync.** libwebrtc's sound path may add tens of milliseconds (estimate). Separate sound helped on the host but did not give a dependable gain in the browser.

## 11. What the owner needs to decide now
1. Approve Phase 0 and its new package: flutter_webrtc in a throwaway app.
2. Which Android device is available for testing, and how a test build reaches the iPhone.
3. Whether a yardstick test with Sunshine and Moonlight on the same PC is wanted. It needs installs on Windows (downloads and a native host), not our container.

Everything else waits for the Phase 0 numbers.
