# o1-3 — the capability probe page (M15 opt1, build)

## Summary

`streaming/player/probe.html` is a self-contained page a phone opens to say what
it can do: inline CSS and JS, no library, no network call of its own, no stream,
and nothing of the player page touched (`index.html`, `player.js`, the options).
It lists `name: value` lines, ok/fail coloured, large enough for a phone, with
**Copy report** (clipboard, else a textarea to select) and **Test audio** (the
only part that needs a tap): the environment, 17 WebCodecs and WebRTC features,
a `VideoDecoder`/`AudioDecoder` `isConfigSupported` matrix at 1080p60, a
data-channel and offer test, a closing legend, and no decode self-test.

`probe.html` is in `serve.py`'s `page_files`, so `GET /probe.html` answers on the
session's player port (45782 by default); a new test in `relay_test.py` proves it
is served, is the page itself, and that a file beside it stays 404 — it failed
on the old code first. The Dockerfile (`COPY streaming/player/`) and the
entrypoint (`cp -r "$player_src/."`) already carry the file; neither was edited.
`streaming/README.md` has the phone URL, the no-session server line and the
rebuild command.

Headless Chromium ran it against a plain `python3 -m http.server` and the whole
report came out (kept in
`docs/briefs/m15/opt1/o1-3-probe/chrome-report.txt`): every H.264 config
supported with optimizeForLatency, none with prefer-hardware, the offer's video
m-line lists H264, the data channel is created. Headless Chrome is not Safari: a
phone still has to run it, and will report `secure context: false` while the
player port is plain HTTP — WebCodecs is then absent, which is the finding.

Checks: relay test 27 checks pass; `tools/check.sh format analyze` PASS; nothing
for `bash -n`; no `node` in the distro, so no `node --check`.

## What the page shows

1. user agent, `navigator.platform`, the iOS/Safari version parsed from it,
   secure context, protocol and host, device pixel ratio, screen and viewport.
2. `typeof` (or `in`) of 17 features: VideoDecoder, AudioDecoder, VideoEncoder,
   EncodedVideoChunk, VideoFrame, WebTransport, RTCRtpScriptTransform,
   RTCPeerConnection, RTCDataChannel, MediaStreamTrackProcessor, AudioWorklet,
   OffscreenCanvas, createImageBitmap, `requestVideoFrameCallback`,
   `jitterBufferTarget`, `playoutDelayHint`, WebSocket — each saying whether a
   missing secure context is the reason it is absent.
3. `VideoDecoder.isConfigSupported` for avc1.42E01F/42E028/4D0028/640028/64002A
   at 1920x1080 60 fps in four settings variants (bare, optimizeForLatency,
   prefer-hardware, both), plus prefer-software on avc1.42E028, plus vp8, VP9 and
   AV1 with optimizeForLatency for information; and `AudioDecoder` for Opus and
   AAC-LC at 48 kHz stereo. The returned config and any throw are shown.
4. No decode self-test: no valid H.264 keyframe is embedded, and none was
   invented — the page says `decode self-test: not included`.
5. A data channel (`ordered:false, maxRetransmits:0`), an offer and a local
   description with `iceServers: []` (no STUN, no network), whether the offer
   has a video m-line and whether it lists H264, `pc.sctp.maxMessageSize`;
   AudioContext state, sampleRate, baseLatency and outputLatency after the tap.
6. A closing legend of what a good result looks like.

## Files changed

- `streaming/player/probe.html` (new, 376 lines) — the probe page: environment,
  feature presence, `isConfigSupported` matrix, decode self-test line, data
  channel/offer test, tap-gated audio test, legend, copy button.
- `streaming/player/serve.py` — `"probe.html"` added to `page_files` (with a
  comment on why), and one line in the module docstring's path list.
- `streaming/player/relay_test.py` — `test_probe_page()` (3 checks, run after
  `test_page()`), also checking `/serve.py` stays 404.
- `streaming/README.md` — a new section "The capability probe (M15 opt1)": the
  phone URL, the no-session `python3 -m http.server` line, the firewall note,
  and the rebuild command.
- `docs/briefs/m15/opt1/o1-3-probe/chrome-report.txt` (new) — the headless
  Chromium report text, fetched from the distro.
- `docs/briefs/m15/opt1/o1-3-probe-report.md` (new) — this report.

Not touched, after checking they needed nothing: `streaming/Dockerfile` (line
194 copies the whole `streaming/player/` folder into the image) and
`streaming/entrypoint.sh` (line 283 copies `/usr/share/thumb-party/player/.`
into the run folder at every session start).

## Decisions

- **prefer-software is asked of avc1.42E028, not avc1.42E01F.** The brief says
  "the baseline one" once and lists two baseline codecs; 42E028 (constrained
  baseline L4.0) is the one that could carry 1080p60, so its software answer is
  the one worth having.
- **A video m-line had to be asked for.** With only a data channel, an offer has
  no video m-line at all and Chrome lists no codecs, so the H264 question could
  never say yes. The test adds `addTransceiver("video", {direction:"recvonly"})`
  before `createOffer`: local only, receives and sends nothing, no network.
- **The audio context is created once and kept open**, not closed after reading:
  the second tap then reads the same context instead of a new one a phone might
  refuse.
- **Informational rows are grey, not red.** The VP8/VP9/AV1 lines are marked
  `info` whatever the answer, so a phone that lacks AV1 does not look broken;
  everything the custom player needs is ok/fail.
- **`navigator.maxTouchPoints > 1` with a Macintosh user agent is called
  iPadOS**, because an iPad on iOS 13+ no longer says "iPad" in its user agent.
- **No `docs/dev-tools.md` entry.** It is in `allow:` but nothing there gains
  from the page; the brief asked for the README section only.
- **`<pre id="report-text" hidden>` holds the plain-text report.** The copy
  button reads it, and it is what made the headless dump a text I could keep
  instead of a screenshot.

## Checks

- `bash -n`: no shell script was changed (`entrypoint.sh` verified unchanged and
  not edited), so there is nothing to check; the README's snippet is a snippet.
- `python3 streaming/player/relay_test.py` in `tp-stream`: **27 checks passed**
  (24 before + 3 new). The first run, before `probe.html` and the whitelist, ended
  with `FAILED: the capability probe is served at /probe.html` — the test fails on
  the old code.
- `node --check`: **not run**. The distro has no `node` (`command -v node` finds
  nothing) and nothing may be installed. Instead the page ran in the distro's
  headless Chromium and produced a complete report (below), which means the
  script parses and runs there; no Safari or Node parse check was done.
- `tools/check.sh format analyze`: **PASS format**, **PASS analyze**.
- `git status` also shows `tv_test_app/{linux,windows}/flutter/generated_*` as
  modified (07:34, before this job's checks) and two untracked files under
  `docs/briefs/m15/`; this job wrote none of them and left them alone.
- The page is 376 lines, under the 380-line limit; every function in it is a few
  lines, the longest (`dataChannelRows`) about 25.

### The headless Chromium run (not Safari)

Run in the distro: `cd /work/<job>/streaming/player`, then
`python3 -m http.server 45901 --bind 127.0.0.1`, then
`/opt/chrome-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell
--no-sandbox --disable-gpu --mute-audio --virtual-time-budget=15000 --dump-dom
http://127.0.0.1:45901/probe.html`; the `#report-text` element was extracted with
`python3`. The two servers I started ended with their shell (a `kill $pid` found
an empty `$!` each time, so nothing was killed by name either); `pgrep -af
"python3 -m http.server"` afterwards found none. The AudioContext rows are
missing because they need a real tap, which the dump cannot give. The README's
one-liner was run here in its server part only, with the literal `/work/...`
path: the `MSYS_NO_PATHCONV=1` prefix and the `$dest` expansion are untested.

```
user agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/157.0.8103.50 Safari/537.36
navigator.platform: Linux x86_64
iOS/Safari version (parsed): not an iOS or Safari user agent
secure context: true
protocol and host: http://127.0.0.1:45901
device pixel ratio: 1
screen: 800 x 600 CSS px
viewport: 800 x 600 CSS px
VideoDecoder: function
AudioDecoder: function
VideoEncoder: function
EncodedVideoChunk: function
VideoFrame: function
WebTransport: function
RTCRtpScriptTransform: function
RTCPeerConnection: function
RTCDataChannel: function
MediaStreamTrackProcessor: function
AudioWorklet (AudioContext.prototype.audioWorklet): in (present)
OffscreenCanvas: function
createImageBitmap: function
HTMLVideoElement.prototype.requestVideoFrameCallback: in (present)
RTCRtpReceiver.prototype.jitterBufferTarget: in (present)
RTCRtpReceiver.prototype.playoutDelayHint: in (present)
WebSocket: function
avc1.42E01F 1920x1080 60fps: supported: true · config {"codec":"avc1.42E01F","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","rotation":0}
avc1.42E01F 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"avc1.42E01F","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
avc1.42E01F 1920x1080 60fps +prefer-hardware: supported: false
avc1.42E01F 1920x1080 60fps +optimizeForLatency +prefer-hardware: supported: false
avc1.42E028 1920x1080 60fps: supported: true · config {"codec":"avc1.42E028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","rotation":0}
avc1.42E028 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"avc1.42E028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
avc1.42E028 1920x1080 60fps +prefer-hardware: supported: false
avc1.42E028 1920x1080 60fps +optimizeForLatency +prefer-hardware: supported: false
avc1.4D0028 1920x1080 60fps: supported: true · config {"codec":"avc1.4D0028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","rotation":0}
avc1.4D0028 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"avc1.4D0028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
avc1.4D0028 1920x1080 60fps +prefer-hardware: supported: false
avc1.4D0028 1920x1080 60fps +optimizeForLatency +prefer-hardware: supported: false
avc1.640028 1920x1080 60fps: supported: true · config {"codec":"avc1.640028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","rotation":0}
avc1.640028 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"avc1.640028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
avc1.640028 1920x1080 60fps +prefer-hardware: supported: false
avc1.640028 1920x1080 60fps +optimizeForLatency +prefer-hardware: supported: false
avc1.64002A 1920x1080 60fps: supported: true · config {"codec":"avc1.64002A","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","rotation":0}
avc1.64002A 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"avc1.64002A","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
avc1.64002A 1920x1080 60fps +prefer-hardware: supported: false
avc1.64002A 1920x1080 60fps +optimizeForLatency +prefer-hardware: supported: false
avc1.42E028 1920x1080 60fps +prefer-software: supported: true · config {"codec":"avc1.42E028","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"prefer-software","rotation":0}
vp8 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"vp8","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
vp09.00.10.08 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"vp09.00.10.08","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
av01.0.08M.08 1920x1080 60fps +optimizeForLatency: supported: true · config {"codec":"av01.0.08M.08","codedHeight":1080,"codedWidth":1920,"flip":false,"hardwareAcceleration":"no-preference","optimizeForLatency":true,"rotation":0}
AudioDecoder opus 48000 Hz 2 channels: supported: true · config {"codec":"opus","numberOfChannels":2,"sampleRate":48000}
AudioDecoder mp4a.40.2 (AAC-LC) 48000 Hz 2 channels: supported: true · config {"codec":"mp4a.40.2","numberOfChannels":2,"sampleRate":48000}
decode self-test: not included: no valid H.264 keyframe is embedded, and none was invented
RTCPeerConnection data channel (ordered:false, maxRetransmits:0): created; readyState connecting
offer has a video m-line: yes
offer video m-line lists H264: yes
pc.sctp.maxMessageSize: Infinity bytes
```

## Self-check (review-rules part A, items 1-5)

1. **Every host setup.** Not applicable: no Dart, no app code, no protocol. The
   page is opened by a browser on any device; `navigator.platform`/user agent are
   reported rather than trusted, and no host decides anything from them.
2. **When kept state starts and ends.** The probe's own state is the `rows` array
   and two lists, alive for the life of the page (a reload starts over). The
   AudioContext is made on the first tap and kept until the page closes; nothing
   polls, nothing is timed but the 3 s per-call `withTimeout`. No session state
   is touched: the relay keeps none of what the probe page does.
3. **How a new state combines with the others.** Nothing the page does pauses,
   hides or blocks input; it is a separate page on the same server and shares no
   storage, no timer and no global with `index.html`'s page. The one shared thing
   is the server's `page_files`, which grows by one read-only name.
4. **Stay in the job's folder.** Only files in `allow:` were written: the page,
   two files beside it, the README, and this job's folder (report, chrome log).
   The distro work stayed in `/work/` and `/tmp/`.
5. **Stop rather than overstep.** No stop was needed. Two points were decided
   rather than asked (see Decisions): prefer-software on avc1.42E028, and the
   recvonly video transceiver the H264 question needs.

## Questions and suggestions

1. **Plain HTTP is the wall.** On the LAN the player port is HTTP, so an iPhone
   will report `secure context: false` and no WebCodecs. If the answer matters
   for the design, the next job is an HTTPS route to the same page (a self-signed
   certificate the phone accepts, or a tunnel); the probe page already says it.
2. **`prefer-hardware` is where a phone and this PC part ways.** Chromium here
   has no hardware H.264 decoder and says `false` for every codec with
   prefer-hardware, while the same codec is `true` bare. Worth saying in the
   README or the legend if the owner reads the PC's result first.
3. `tools/stream.sh build` is the whole answer for getting the file into a
   session; a `probe` subcommand that serves the folder without an image would be
   a smaller thing for the owner to remember, if this page is used more than once.
4. Chrome reports `supported: true` for avc1.42E01F (baseline L3.1) at 1080p60,
   which its level should not carry: `isConfigSupported` ignores the level. The
   phone's answer is therefore "the browser will try", not "the GPU can".

## Hand-over

- **What exists:** `streaming/player/probe.html`, served at `/probe.html` by
  `serve.py` on the player port; a relay test for it; a README section.
- **Owner, during a session:** `tools/stream.sh build && tools/stream.sh up`,
  then open `http://<this PC's LAN address>:45782/probe.html` on the phone, wait
  for the list, tap **Test audio**, tap **Copy report**, paste the text back.
- **Owner, without a session:**
  `dest="$(tools/wsl-sync.sh tp-stream)" && MSYS_NO_PATHCONV=1 wsl -d tp-stream -u root -- bash -lc "cd $dest/streaming/player && python3 -m http.server 45900 --bind 0.0.0.0"`
  then `http://<this PC's LAN address>:45900/probe.html`. A firewall rule for
  45900 may be needed; none was added or changed here.
- **A good result:** secure context true (or the fact that it is false);
  VideoDecoder present; avc1.42E028 or avc1.64002A at 1080p60 supported with
  optimizeForLatency and prefer-hardware; the data channel created and the offer's
  video m-line listing H264.
- **Open:** an iPhone has not run it yet; nothing is known about Safari's answers.
  The AudioContext rows were never exercised by a tap in this job. HTTPS to the
  phone is the likely blocker for a secure-context answer.

## Commit message

probe: a phone capability page served by the player relay

Adds streaming/player/probe.html: user agent and parsed iOS/Safari version,
secure context, typeof of the WebCodecs and WebRTC pieces, a VideoDecoder and
AudioDecoder isConfigSupported matrix at 1080p60, a data-channel offer test and
a tap-gated AudioContext test, with a copy button and a good-result legend.
Serves no decode self-test: no valid H.264 keyframe is embedded.
Lists probe.html in serve.py's page_files and adds a relay test for it that
fails without the whitelist entry. No change to index.html, player.js, the
options or any default behaviour; the Dockerfile and entrypoint already carry
the file, so the README says a rebuild is what puts it in a session.

## Status row

M15 opt1 o1-3: probe page built, served at /probe.html with a relay test, README section written; open — the owner's phone run (Safari answers), and plain HTTP means an iPhone reports no secure context on the LAN.

## Delete

- none
