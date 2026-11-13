# The Thumb Party session image

One container is one household session: it draws the TV app on a virtual screen
that is also the video source, encodes it with NVENC, sends picture and sound
over WebRTC, and serves the player page a browser opens to watch. The design and
the measurements behind it are in [streaming-custom.md](../docs/design/streaming-custom.md)
and [capture-probe-report.md](../docs/briefs/m15/capture-probe-report.md).

[`tools/stream.sh`](../tools/stream.sh) builds and runs it; this file explains
what is in the image and what the owner has to do outside it.

## What runs inside

| Piece | What it does |
| --- | --- |
| `waylanddisplaysrc` ([gst-wayland-display](https://github.com/games-on-whales/gst-wayland-display)) | A virtual screen with no window: the TV app draws into it and every frame is the video source. `render-node=software` because WSL2 has no DRM node to share buffers through |
| the TV app (`tvtest`) | The Linux release build of `tv_test_app`, a client of that screen, in a window as big as the session |
| PulseAudio | One null sink (`party`); the app's sound goes there because `/etc/asound.conf` points ALSA at Pulse, and the pipeline records its monitor |
| `webrtcsink` (gst-plugins-rs) | NVENC H.264 and Opus into one WebRTC stream, one consumer per connected player |
| `gst-webrtc-signalling-server` | Tells the player and the pipeline how to find each other (it has to be its own process) |
| [`player/serve.py`](player/serve.py) | Serves the player page and the built `gstwebrtc-api` bundle, and is the page's only way to the host (see "The relay" below) |
| [`entrypoint.sh`](entrypoint.sh) | Starts all of the above in order, waits until the game's home screen is up and the pipeline has registered, then prints the `ready:` line and supervises them: anything ending ends the session |

The session runs as the unprivileged user `party`. In a WSL2 GPU container
`/dev/dxg` is world-writable, so the GPU needs no privilege; on a real Linux GPU
nothing changes.

## Ports

Every port is an environment variable, so sessions can sit side by side. The
container is run with `--network host`, so these are the host's ports too.

| Setting | Default inside | `tools/stream.sh up` (session `party`) | What uses it |
| --- | --- | --- | --- |
| `CONTROLLER_PORT` | 45780 | 45780 | The TV app: phones connect here to play |
| `SIGNAL_PORT` | 8443 | 45781 | WebRTC signalling, player and pipeline |
| `PLAYER_PORT` | 8080 | 45782 | The player page over HTTP, and its relay |
| `AUTOMATION_PORT` | 8787 | 45783 | The host's automation interface (M15 a2); the entrypoint asks for `0.0.0.0`, so beside `--network host` it is on the LAN and its token and the owner's firewall keep it closed |

`--port-base P` moves the whole block: the controller is `P`, signalling `P+1`,
player `P+2`, automation `P+3`. Two sessions at once need different bases (or
`--name` plus a base), and `tools/stream.sh url --name <n>` prints each one's
addresses.

The custom player's tap server (M15 opt2) is the one port outside that block:
`TAP_PORT` defaults to the automation port plus one and listens on loopback
only, and the player relay tunnels to it on the player port, so a session opens
nothing new and needs no firewall rule (see "Custom player" below).

The app has the last word on the controller port: it asks for the one it is
given (45780 without settings) and takes any free port when that is busy, so a
second session's phones connect somewhere else. The ready line and `url` say
which port it got, and the app tells it on its own home screen ("Listening on
port …"). Pinning it is a change to the app, not to this image.

The defaults (`8080`, `8443`, `45780`) are what `docker run` without settings
gives, so the image is usable by hand too.

## Switches (M15 fix7)

Each new latency technique in the fix7 batch sits behind a switch of its own, off
until a run asks for it, so the owner can compare phone runs. A session switch is
one `-e KEY=VALUE` on `docker run`, which `tools/stream.sh bench --set KEY=VALUE`
passes (`SESSION_FEC=false`); a player page switch is a `key=value` pair on the
page's URL, which `--player-query x=1` puts on the viewer's URL — the headless
Chrome's, and the one printed for `--viewer external`, so the owner copies one
URL for the phone. `SESSION_PLAYER_OPTIONS=a=1,b=x` gives the page defaults from
the session's environment (entrypoint.sh writes them into `config.js` as
`THUMB_PARTY.options`); the URL query overrides them key by key, and an unknown
key is kept for a later switch. The page exposes what it runs with as
`window.THUMB_PARTY_OPTIONS` and as an `options: x=1` line in the stats overlay.

A bench run opens with one line naming what it was given —
`switches: SESSION_FEC=true, player-query x=1, player-options none` — and writes
it to `<out>/switches.txt`, which `tools/stream.sh bench` fetches beside the
summaries and `stats` prints again. A run with nothing set says `switches: none`,
and the page then behaves exactly as it did before the batch.

`lowdelay=1` is the page's zero-delay option (technique 2 of the batch; off
unless asked for). Besides the one-time `tuneForLowDelay` every page already
does, it puts the receiver hints back every second and after each stream change
(`jitterBufferTarget` and `playoutDelayHint` on every receiver of both
connections, the sound's included), sets the video element's
`disableRemotePlayback` on and its `playbackRate` to 1, and sets a latency hint
on the element when the browser has one. The overlay gains a line reading the
values back, `lowdelay: rate=1 drp=on latency=missing video jbt=0 pdh=0, audio
jbt=0 pdh=0`, with `missing` for a property this browser does not have — the
headless Chrome is not Safari, and only the phone says which of these it has.
The host-side half of technique 2, the playout-delay RTP header extension in the
stream itself, is not in the image: no GStreamer element implements it here, so
there is no session switch for it (evidence in
[fix7/n2-1-delay-build-report.md](../docs/briefs/m15/fix7/n2-1-delay-build-report.md)).

`jbtarget=<ms>` sets the receiver's jitter buffer target where the browser has
the property (M15 opt1b; off unless asked for, and it combines with
`lowdelay=1` and `marker=1`: `?jbtarget=0`, `?marker=1&jbtarget=0`, or
`tools/stream.sh bench --player-query "marker=1&jbtarget=0"`). The value is a
whole number from 0 to 4000 ms — anything else is ignored and the page behaves
as without the option, and a bare `?jbtarget` asks for 1 ms, the value
options.js gives every bare key. Every receiver of both connections (video and
audio) is set at once and again every second and after each stream change,
read back after every apply, and when `lowdelay=1` is on too this option's
value wins over that switch's `jitterBufferTarget = 0` (its
`playoutDelayHint` stays 0). Where the result shows: the Streaming quality
table's last column `jbtarget`, the gauges `jbTargetRequestedMs` and
`jbTargetAppliedMs` (the read-back, only when the receivers agree) in the
summary JSON, and the overlay's line `jbtarget: req 0 has yes read 0` (its
`has` says whether the receivers have the property: yes, no, partial or
`none yet`; pairs are separated by a space because `=` is not a fact
character). A browser may clamp or ignore the value — Safari in particular —
so the read-back, not the request, is the proof that it arrived and stayed.

`marker=1` is the page's half of the streaming marker (M15 fix8, technique in
[docs/streaming-marker.md](../docs/streaming-marker.md); off unless asked for,
and it needs the session's row, `SESSION_MARKER=on`). Every frame it reads only
the row's strip out of the video element, one `getImageData` in the element's
`requestVideoFrameCallback`, decodes it (`marker_decode.js`) and times the
callback on the host's clock through an offset it measures against `/clock`
every 10 s, keeping the shortest round trip (`clock_sync.js`: offset, RTT and
RTT/2 as the uncertainty). A batch then carries, as the sampler's own keys, the
stages `marker_glass` and `marker_glass_p95` (the row's age at the callback), the
press stage `press_to_marker` (the flip cell's frame, less the `probe/press` host
time: an independent press-to-screen that needs no card) and `stream_display`
(decoded to display, `expectedDisplayTime − receiveTime`), the gauges
`markerOffsetMs`, `markerOffsetRttMs`, `markerOffsetUncertaintyMs`,
`markerCallbackLateMs`, `markerDecodeDisplayMs` and `markerReadMs`, the counters
`markerFrames`, `markerReadable`, `markerChecksumBad`, `markerSyncBad`,
`markerCanvasBad` and `markerOtherBad`, and one `rvfc.<field>` fact per
`requestVideoFrameCallback` metadata field (min median max in the field's unit; a
field the browser does not give is absent, not 0). With the switch off the page
sends nothing new. The read costs ~5 ms a frame in headless Chrome (measured in
the [fix8 f8-3 report](../docs/briefs/m15/fix8/f8-3-marker-player-report.md)).

When a summary carries the page's marker keys, the Analytics report's Streaming
section prints an Independent check table under the pipeline: the marker's glass
time and its own press figure beside the card's press and the chain's total,
their differences, a one-line verdict (agree while the two presses differ by
less than max(25 ms, twice the offset's uncertainty), else `DISAGREE by N ms`),
the clock offset and its uncertainty, the frames read and the ones unreadable by
reason, and the rVFC fields the browser gave. A run whose page read no marker
row prints the report it always did (`tools/stream.sh stats --results <dir>`
shows either).

The headless Chrome is not Safari: a headless run says whether a switch works and
what it does to the host side and to Chrome, and the phone decides.

Technique 3 of the batch, the sender's own switches, is `SESSION_CONGESTION`
below. Probing `gst-inspect-1.0 webrtcsink` and the 0.13.6 source for what could
hold a frame in the send path found nothing a property can reach: every element
`webrtcsink` adds to an already-encoded stream measured under 0.5 ms in a 45 s
run (`h264parse` 0.29, the payloader 0.06, FEC and RED 0.02–0.03), the payloader
already runs `aggregate-mode=zero-latency`, the consumer `h264parse` does not
wait for the next access unit, and there is no queue and no receive-side `rtpbin`
latency on the send path — the wait sits in the sink pad's hand-off to the
consumer (`appsink` → `appsrc`), which has no property. So the ~25 ms the encode
stage shows is not something a sink switch shortens, and this is the batch's one
sender switch. Evidence and lines: [fix7/n3-1-sender-build-report.md](../docs/briefs/m15/fix7/n3-1-sender-build-report.md).

## The picture's settings (M15 t1)

Each is one `-e KEY=VALUE` on `docker run`; `tools/stream.sh bench --set
KEY=VALUE` passes them without a rebuild, which is how the tuning was measured.
The comments in [`entrypoint.sh`](entrypoint.sh) carry the numbers behind each
default.

| Setting | Default | What it does, and what M15 t1 measured |
| --- | --- | --- |
| `SESSION_BITRATE_KBPS` | 10000 | The ceiling a viewer's whole stream keeps: video, sound, FEC and RED together, which is what its byte counter reads. The encoder gets less — `(ceiling − 96) / (1 + FEC/100)` — and the ready line prints both (`10000kbit/s (video 4716)`); with FEC off the video gets the ceiling less the sound |
| `SESSION_GOP_FRAMES` | the frame rate (a keyframe a second) | `-1` is keyframes on request only. Worse: the receiver's jitter buffer 262 ms against 127–170. Left at one a second so a joining player sees a picture at once |
| `SESSION_VBV_KBITS` | 0 (NVENC's default, a second's worth) | The encoder's VBV/HRD buffer, in kbits: `gst-inspect-1.0 nvautogpuh264enc` says "VBV(HRD) Buffer Size in kbits (0 = NVENC default)". One frame's worth (167 at 10 Mbit/s and 60 fps) has measured 144–205 ms total and 213–253 press over six runs; the baseline runs beside them were 161–223 and 230–266, so it never left the 44 ms noise. Off |
| `SESSION_FEC` | true | Forward error correction. No lower delay with it off, and it is what a viewer counts above the video: off, an Arena round measured 9693 kbit/s at a 10000 ceiling, and on 20353 (M15 fix5), so the encoder is given 4716 kbit/s when it is on |
| `SESSION_RETRANSMISSION` | true | Resend lost packets; no delay difference either way |
| `SESSION_CONGESTION` | `disabled` (the switch is off) | `webrtcsink`'s `congestion-control` on both sinks (M15 fix7, technique 3). `disabled`: with congestion control off the element gives the encoder `max-bitrate` itself and holds it there, the pipeline as it was. `gcc` (Google Congestion Control) is the element's own algorithm: `max-bitrate` is then the ceiling the estimate may not cross and `start-bitrate` where a consumer starts, so the video can run *below* the wire ceiling — the ceiling is still honoured, the bitrate is no longer fixed. The element's third value `homegrown` is refused with a warning and the session runs `disabled`: on an already-encoded stream `webrtcsink` 0.13.6 has no encoder of its own and the heuristic divides by that count, so the pipeline aborts (panic, divide by zero, `homegrown_cc.rs:386`; measured, see [fix7/n3-1-sender-build-report.md](../docs/briefs/m15/fix7/n3-1-sender-build-report.md)). The ready line's `sink ws:` line prints the value a session ran with; headless Chrome says whether the algorithm engages here, and the phone decides |
| `SESSION_SPLIT_TRACKS` | false | Play picture and sound on two media elements so the browser stops syncing them. Worse: 42 delivered fps against 53, press 246 ms against 230, so one element stays |
| `SESSION_AUDIO` | `joined` (the switch is off) | `joined`: the pipeline as it was, one `webrtcsink`, one peer connection and one stream id for picture and sound. `off`: no sound in the stream at all (no `pulsesrc`/`opusenc` branch and no audio caps), so a viewer shows the picture only. `separate`: the sound runs in a second `gst-launch-1.0` process of its own (M15 opt2-5) — its own `webrtcsink` (`ws-audio`, producer meta `TP-Sound`), its own peer connection and stream id, and its own log `/run/thumb-party/sound-pipeline.log` — so the browser cannot hold the picture back to lip-sync it and the picture pipeline's latency query never sees the sound: host pipeline time 8.0 ms against `joined`'s 41.6, and 7.95 with no sound at all. `joined` and `off` are byte for byte what they were, `--print-sound-pipeline` is the sound's dry run, and the player picks the two producers by their meta (`TP-Picture`, `TP-Sound`), plays the sound on its own element and keeps one viewer row. A player follows what the stream carries, so it needs no setting of its own; headless Chrome says whether a value works here, and the phone decides whether it helps |
| `SESSION_PLAYER_OPTIONS` | empty (the page as it was) | The player page's own switches (M15 fix7), a comma list such as `lowdelay=1` that the entrypoint writes into `config.js`; the page's URL query overrides them key by key, and `tools/stream.sh bench --player-query lowdelay=1` puts one on the viewer's URL. `lowdelay=1` is technique 2's page half: the per-receiver and per-element zero-delay settings put back every second and after each stream change, with an overlay line reading them back (see "Switches") |
| `SESSION_MARKER` | `off` (the switch is off) | `on` makes the app draw the marker row in the top-left corner of its picture — a frame counter, the host's clock and a probe-press flip — so the player reads them out of the video itself (M15 fix8, [docs/streaming-marker.md](../docs/streaming-marker.md)). The entrypoint passes `THUMBPARTY_MARKER=1` to the app and its ready line says `marker=on`; a phone's build has no environment to switch it on, and a run with the row on costs the app its own repaint of 57 cells a frame (measured in the fix8 f8-2 report) |
| `SESSION_ENCODER` | `nvautogpuh264enc` | `nvcudah264enc` also works and was no better (press 261 ms against the baseline's 230–266) |
| `SESSION_WIDTH`, `SESSION_HEIGHT`, `SESSION_FRAME_RATE` | 1920, 1080, 60 | The window and the encoder size. 720p was worse (total 186 ms, jitter 151) |
| `THUMB_PARTY_IMPELLER` (M15 k1-2) | unset: Impeller | The renderer the app draws with; `0` or `false` draws with Skia. Skia halved an Arena frame's raster (4.6 ms against 9.9) and drew 52.1–55.3 fps against the baselines' 48.5–51.9, two runs each: the frame cost is outside the run-to-run noise, the frame rate at its edge (3.5 fps against a 3.4 spread), so it waits for the next phase's pairs before it becomes the default |

## What the encode stage is (M15 k1-4)

The `stream_encode` stage is the latency tracer's `element-latency` record of
the encoder: the time a frame spent between the encoder's sink pad and its src
pad. It is the element's own work plus its internal queue plus whatever its
src-pad push waits for downstream; a wait in a `queue` **before** the encoder is
not in it (that shows in the queue's own record). The whole host path is the
tracer's `pipelineMs`, from `waylanddisplaysrc`'s output to `webrtcsink`'s input.

Measured with [`encoder-bench.sh`](encoder-bench.sh), the session's own
settings on a 1080p60 test source and nothing else in the pipeline (no game, no
viewer): NVENC holds a frame **9.2-11.3 ms** whatever its settings say (nine
changes measured one at a time: `preset` p1/p4, `tune` ultra-low/low/hq,
`zero-reorder-delay`, `rate-control` cbr/vbr/cbr-ld-hq, a one-frame VBV with
`strict-gop`, `nvcudah264enc`, and a one-buffer queue in front; the spread is
2 ms), at 30 fps input as at 60, and inside the image as on the distro. In the session the same
element reads **29-34 ms**. A two-frame queue between the encoder and the parser
dropped the stage to 3 ms while `pipelineMs` stayed at 33 and the delivered fps
at 56, and `webrtcsink`'s internal queues then read 27 ms: the stage is the
encoder waiting for `webrtcsink` to take its output, not the encoder working
(`encoderPct` 6 %). No setting in this file halves it; the queue moved the wait
out of the reported stage without moving the frame any faster, so it is not in
the image. `docs/briefs/m15/fix6/k1-4-encoder-report.md` has the table.

## Building and running it

```bash
tools/stream.sh build                     # copy this checkout into the distro, build tp-session:latest there
tools/stream.sh up                        # start session "party" and wait for its ready line
tools/stream.sh status                    # what runs, its ready line, and the keep-alive
tools/stream.sh logs --name party --follow
tools/stream.sh url                       # the player URL (localhost and LAN) and the controller address
tools/stream.sh up --name kitchen --port-base 46000
tools/stream.sh down --name kitchen       # stop one session
tools/stream.sh down --all                # stop every session
tools/stream.sh keep-alive --stop         # end the keep-alive by hand (down of the last session does)
```

`up` leaves a detached `wsl -d tp-stream -u root -- sleep infinity` running,
because WSL stops the distro a few seconds after the last Windows command
attached to it ends, and that would kill the session with it. The process's pid
is kept in `%TEMP%\tp-stream-keepalive.pid` (`STREAM_KEEPALIVE_FILE` moves it),
`status` prints whether it is alive, and `down` of the last session ends it.
Only that one process is ever ended, and only after its command line is checked
to be that `sleep infinity`.

The image is built inside the locked-down `tp-` WSL distro (see
[wsl-sync.sh](../tools/wsl-sync.sh)), never on the Windows side, and it builds
the app itself: the platform, the two hand-built GStreamer plugins and the
player's JavaScript are all pinned in the [Dockerfile](Dockerfile), with a
comment on every pin.

By hand, from the repository root (a Linux machine or inside the distro):

```bash
docker build -f streaming/Dockerfile -t tp-session:latest .
docker run -d --name thumb-party-party --network host \
  -e CONTROLLER_PORT=45780 -e SIGNAL_PORT=45781 -e PLAYER_PORT=45782 \
  tp-session:latest
```

On WSL2 add `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg
-v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib
-e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA`;
`tools/stream.sh up` adds them when the distro has `/dev/dxg`.

## The player page

`http://localhost:<player port>/` shows the session full screen: no browser
controls, the picture only. The number in the corner (or the `s` key) shows the
live numbers — resolution, frames per second, Mbit/s, round trip, jitter buffer,
decode time, dropped frames — read from WebRTC's own `getStats` in
[`player/stats.js`](player/stats.js). Sound starts with the picture where the
browser allows it; otherwise a "Tap to start sound" screen takes the click,
because browsers only give sound to a page the viewer touched. A lost connection
reconnects on its own, and a drop the page cannot recover from is told apart from
a hiccup: once a picture that played has been gone for 15 seconds, the page says
"The stream has ended. Reload this page to join the next session." and stops
asking for anything, so a tab left open never joins the next session by itself —
only a reload does (M15 fix8). A page that never played keeps waiting, however
long the TV takes: that wait is a start, not an end.

The page also learns the session's own id from `config.js` and sends it with
everything it tells the relay, so a page an earlier session served is told apart
from this one's (M15 fix8): the relay answers it `stale` and names it in
`GET /player`, and its measurements are refused rather than counted as this
session's.

The page learns its signalling port from `config.js`, which the entrypoint
writes next to it, and loads the `gstwebrtc-api` bundle the image builds from the
same gst-plugins-rs release as `webrtcsink`.

## The capability probe (M15 opt1)

[`player/probe.html`](player/probe.html) is a page of its own that answers one
question before any player is designed: what can this phone do? It lists the user
agent and the iOS/Safari version parsed from it, the secure context and the page's
address, `typeof` of the WebCodecs and WebRTC pieces (VideoDecoder, AudioDecoder,
VideoEncoder, EncodedVideoChunk, VideoFrame, WebTransport, AudioWorklet,
OffscreenCanvas, `requestVideoFrameCallback`, `jitterBufferTarget`,
`playoutDelayHint`, …), `VideoDecoder.isConfigSupported` for the H.264 configs at
1920x1080 60 fps (avc1.42E01F, avc1.42E028, avc1.4D0028, avc1.640028,
avc1.64002A) each with `optimizeForLatency`, `prefer-hardware` and both, plus VP8,
VP9 and AV1 for information, the two audio configs (Opus, AAC-LC), and a
data-channel test that also reads the offer's video m-line. It makes no network
call of its own, starts no stream, and nothing links to it: the player page,
`index.html`, `player.js` and the options are untouched. There is no decode
self-test, because no valid H.264 keyframe is embedded in it.

**On the phone, during a session:** open
`http://<this PC's LAN address>:45782/probe.html` — the same player server and
port as the page, since `serve.py` lists it (`page_files`) — wait for the list to
fill, tap **Test audio**, then **Copy report** and paste the text back. A phone
that opened it over plain HTTP is not a secure context, so WebCodecs is absent and
the page says so: that is the finding, not a fault in the page.

**Without a session**, from this checkout (one line, spare port 45900):

```bash
dest="$(tools/wsl-sync.sh tp-stream)" && MSYS_NO_PATHCONV=1 wsl -d tp-stream -u root -- bash -lc "cd $dest/streaming/player && python3 -m http.server 45900 --bind 0.0.0.0"
```

then open `http://<this PC's LAN address>:45900/probe.html`. The Windows firewall
rules above cover TCP 45780-45782 and UDP only, so it may refuse 45900 until the
owner adds a rule for it; **nothing here adds or changes a firewall rule**.

**Getting the file into a session:** the Dockerfile's `COPY streaming/player/`
carries it into the image and the entrypoint's `cp -r "$player_src/."` copies it
into the run folder at each session start, so neither needed a change — but an
image built before the file existed does not have it, and there is no mount from
this checkout. Rebuild and start again:

```bash
tools/stream.sh build && tools/stream.sh up
```

`tools/stream.sh selftest` runs the relay's tests (including that `/probe.html` is
served) from the synced checkout and needs no image.

## Custom player (WebCodecs), off by default

M15 opt2 is a second way to play the picture: the session hands the encoder's own
output to a WebSocket, and the page decodes it with the browser's `VideoDecoder`
and draws it on a canvas in the video element's place. Every part sits behind a
switch, and with nothing set the session and the page run exactly as before.

| Setting | Default | What it does |
| --- | --- | --- |
| `SESSION_TAP` | `off` | `on` runs the session's pipeline inside [`tap/tap_runner.py`](tap/tap_runner.py) instead of `gst-launch-1.0`: GStreamer in the session's own Python process, given the same argument list, with a `tee` right after the encoder. The picture goes on to `webrtcsink` unchanged, and a leaky branch after the tee (`queue leaky=downstream max-size-buffers=2 ! h264parse config-interval=-1 ! appsink name=tap drop=true max-buffers=2 sync=false emit-signals=true async=false`) gives Python the encoded access units. The encode is shared, so the tap costs no second encode, and the branch drops rather than waits, so a reader that falls behind can never hold the encoder back. The ready line says `tap=on:<port>`; a value that is not `on` or `off` warns and runs `gst-launch` as always |
| `TAP_PORT` | the automation port + 1 (`8788` at the defaults) | The tap server's port. It listens on loopback only, and nothing outside the session connects to it |
| `player=wc` | absent (today's page) | The page option that plays the tap's picture (below); every other value, or none, is the WebRTC page |
| `wcmode=annexb` | AVCC, with an `avcC` description | Hands the decoder in-band Annex B bytes instead of the converted AVCC |

**The tunnel.** The phone never connects to `TAP_PORT`: the relay that already
serves the page ([`player/serve.py`](player/serve.py)) upgrades a WebSocket on
path `/tap` and forwards it to the tap server on loopback, so the page reaches
the tap on the player port it already uses. Nothing new is opened and no
firewall rule is added; a plain GET on `/tap` is answered 400, and a relay
started without a tap port answers 404.

**The message.** One binary message is a 24-byte big-endian header (magic `T`,
version, flags with the keyframe and discontinuity bits, the frame number, the
pipeline's `pts` and the host's send time) and then one access unit in Annex B;
the server also sends a `hello` and an `end` as JSON text, and a client may ask
for a keyframe. The two formats and the backlog rule are in
[`docs/briefs/m15/opt2/PROTOCOL.md`](../docs/briefs/m15/opt2/PROTOCOL.md).

**The page.** `?player=wc` plays that way; `tools/stream.sh bench --player-query
"marker=1&player=wc"` puts it and the marker on the viewer's URL, and with both
the page reads the marker row out of the canvas rather than the video element.
The decoder is configured from the stream's own SPS and PPS on a keyframe; a gap
in the frame numbers, or a decoder queue deeper than two frames, drops what was
waiting and asks for a keyframe (at most once every 500 ms), so delay cannot
pile up, and a lost socket reconnects on its own. `wcmode=annexb` is for in-band
bytes; the default is AVCC with an `avcC` description.

**Sound in this mode** stays the page's existing sound-only WebRTC link: the
picture consumer is left unattached, so the sound arrives as it does today and
the tap carries the picture alone. `SESSION_AUDIO=separate` is how that sound
comes from its own process (the row in "The picture's settings" above); with a
stream that carries no sound, the overlay says `sound: this session sends no
sound stream`.

**What a bench run shows.** A viewer whose page played this way sends one `wc`
fact and six gauges, and the report prints a "Custom player (wc)" table under
the stream's own: `session viewer recv-dec ms dec-draw ms dropped backlog max
keys queue max decode`, one row per such viewer, with the two medians' means,
the maxima of what it dropped, held and asked for, and the decoder's
configuration (`cfg hw dec ok`). A run whose page played the WebRTC way prints
exactly the report it always did.

**The image** carries what `tap_runner.py` needs: `python3-gi`,
`gir1.2-gstreamer-1.0` and `gir1.2-gst-plugins-base-1.0` in its apt group, and
`streaming/tap/` copied to `/usr/local/bin/tap/`.

**What it does not do yet:**

- Video only: the tap carries the encoded picture, and the sound stays on
  WebRTC. There is no sound in the WebSocket.
- One TCP socket: a lost packet holds every frame behind it (head-of-line), so
  a bad link is worse here than over WebRTC's UDP.
- WebCodecs needs a secure context, and a phone opening the page at this PC's
  LAN address over plain HTTP has none: the decoder is then absent, exactly as
  the capability probe above reports.
- Proven headless so far: the page's own tests pass in the distro's headless
  Chrome, and that Chrome is not Safari. A phone run is what says whether the
  mode is kept, against the 150 ms or less gate.

## What the session measures (M15 c2)

The session reports into the host's stats framework, so a benchmark can time a
whole stream without a person watching it:

- **The player page** sends one batch every two seconds: WebRTC's own inbound
  numbers (jitter buffer, decode, frames, freezes, bitrate, loss, jitter, round
  trip, NACK/PLI, codec, relay), what `requestVideoFrameCallback` adds, and the
  audio's concealed samples. It also times a press: the latency card's colour
  flips, the page sees the flip in a small patch of the picture and sends the
  host-clock time it was presented.
- **The sampler** (`stream-sampler`, started by the entrypoint) reads the
  container's cgroup counters (CPU split by process, memory), `nvidia-smi`
  (GPU, encoder, memory) and the host's own `GET status` every
  `SAMPLER_INTERVAL_S` seconds, tails the pipeline log for the tracer's records,
  and leaves the latest resource reading in `/run/thumb-party/pipeline.json`.
  `SESSIONS_AT_ONCE` says how many sessions the machine runs, so the GPU's
  numbers can be read per session. From the status answer it also takes the
  game's frame times (`frameBuildMs`, `frameRasterMs`, `gameFrameMs`,
  `slowFramePct`) and each probe press's way through the host, which it writes
  as the `host_tick`, `host_build` and `host_raster` stages beside the
  pipeline's (M15 k1).
- **The tracer**: the pipeline runs with
  `GST_TRACERS="latency(flags=pipeline+element)"`, which writes one record per
  element per frame into `pipeline.log`; the sampler turns those into the
  capture, encode and pipeline times.
- **The relay**: the player page's web server (`serve.py`) answers the page
  itself for `/player`, `/presses`, `/flips` and `/pipeline` (the queue of
  presses and flips, and the sampler's latest reading), and makes exactly two
  calls to the host's automation interface with the session's token: `GET
  /status`, for `/clock` (the press probe needs the host's own clock), and
  `POST /stats/stream`, the measurements. Every other path — the host's
  `/players`, `game/start`, `probe/press` and the rest — answers 404, so the
  page can measure a session and nothing more. A POST body over 64 KB is
  refused with 413 before it is read; that is room for a whole batch of a
  viewer's numbers.

The token is the session's own, in `/run/thumb-party/automation.token`, unless
`AUTOMATION_TOKEN` gave it one. The interface is not loopback-only inside a
session: the entrypoint asks for `0.0.0.0`, so with `--network host` it is
reachable on this PC's LAN address, and the token (every call needs it) and the
owner's firewall rules are what keep it closed. `tools/stream.sh bench` starts a session headless,
adds a simulated player and lets a round run; in the `tp-stream` distro on WSL2
the whole run has to happen inside one `wsl` call, because the distro's VM stops
when no command is running in it and takes the session with it.

The relay has its own test, `streaming/player/relay_test.py`, run inside the
distro by `tools/stream.sh selftest`: it starts `serve.py` with no host behind it
and checks the page's files, the four POST paths, the 404 for everything else
(before the body is read), the 502 with no host, the press queue, the 64 KB cap
and a page's session (`--session-id`, M15 fix8): a page of an earlier session is
answered `stale`, named once in `GET /player`, and its batch refused with 403 —
twenty-four checks, and it exits 1 at the first that does not hold.

The bench's run line reads what the viewers received against the ceiling the
session was given, and who they were (the ingest keeps a viewer's kind and
platform and no user agent), for example `1 viewer(s) browser/chrome-headless,
9850 kbit/s received against the 10000 kbit/s ceiling`. Received is the whole
wire: the video `SESSION_BITRATE_KBPS` less the sound and FEC leaves for the
encoder, FEC and RED on top of it, and the 96 kbit/s sound. A viewer's row is
only listed when it reported a gauge, a counter or a stage of its own; a page
that connected and never showed a picture holds only the host's stages, and the
section ends with `N viewer row(s) with no receive data left out` when there
were any (M15 fix5). The probe's card is nearly still, so its received rate says
nothing about the game's. The line ends with the game's own drawing when the
sampler read it (M15 k1): `game 48.2 fps, 20.8 ms/frame, build 5.1 + raster
12.3 ms, 62% slow`. A run that timed presses prints the host leg table as well
(`press>tick`, `tick>built`, `built>raster`, the derived `raster>capture*`,
`press>screen` and `total`), with no extra flag. The derived cell is a
subtraction, not a measurement: `press>screen` less the three stages and
`total`, and both of those are end-to-end numbers taken different ways (the
viewer finds the flip in the picture, the relay adds up the player's stages and
its clock offset). Four 45 s probe runs read 11, 48, 48 and 51 ms there and one
queue run read −16 ms, so the cell says how far the two ends disagreed on that
run, not what the compositor and the capture cost (M15 k3).

`--viewer external` (M15 g1) opens no browser: the bench starts the session and
the round (or the card) first, because the host only accepts a viewer's batch
while a session is playing, then prints the LAN address to open and waits up to
three minutes, a line every ten seconds, until a viewer with receive data
registers. From then on it measures that viewer. A phone run then ends with a
press phase: the round's numbers are kept, the latency card goes up over the
same session and viewer for `--press-seconds` (30 by default), and the presses
are timed against the card. `--viewer-cpus L` runs the headless Chrome on the
cores in `L` (`taskset`), `--session-cpus L` runs the session container on the
cores in `L` (`docker --cpuset-cpus`): pinning the two apart is how a run asks
whether the viewer's own CPU was starving it. In the g1 runs a session pinned to
`0-7` (eight cores) never became ready and `0-11` (twelve) did. `--viewer-cpus`
is refused with `--viewer external`: the bench can pin only the browser it
starts, so a viewer a person opens is pinned on that device.

`--viewer-host ADDR` (M15 opt2b) has the headless viewer load the page at
`http://ADDR:<player port>/` instead of `127.0.0.1`, so a proof runs the page the
way a phone gets it: plain http on a LAN address, which is no secure context.
Chrome then has no `VideoDecoder` unless the run also gives
`--viewer-insecure-ok`, which passes `--unsafely-treat-insecure-origin-as-secure`
for that origin — the stand-in for a phone that offers `VideoDecoder` on the
plain-http page anyway. The run logs which page and which of the two it used, and
the session needs no publish change: it runs with `--network host`, so its player
port answers on every interface. Both switches are refused with
`--viewer external` (only the Chrome this run starts can be told), and
`--viewer-insecure-ok` alone is refused: the loopback page is a secure origin
already.

A page loaded before the session started — a tab left open from an earlier one —
reconnects to the signalling server like a fresh one, but it is not this
session's viewer: the relay names it and the bench says so once, `ignored a
viewer loaded before this session: <id>; waiting for a fresh page`, then goes on
waiting for a page this session served. Its measurements never reach the host,
so its numbers are not counted (M15 fix8). In either viewer mode the line comes
from `GET /player`; the wait that printed it carries on.

`--end-check` ends a run by stopping its sessions and reading the line the page
it opened shows: a page whose stream has been gone for 15 seconds says "The
stream has ended. Reload this page to join the next session.". The bench reads
it off the page's tab title, which Chrome lists on the viewer's debugging port,
and prints `the page says "<line>"`. It needs `--viewer chrome` — the port is
Chrome's own — and is refused with `--keep`, whose kept session it would stop.

## Watching from another device on the home network

The distro runs in WSL2's **mirrored networking** (the owner's
`%USERPROFILE%\.wslconfig`), so it holds this PC's own LAN address: the address
`tools/stream.sh url` prints, the one `ipconfig` shows, and the one the other
device types. What still has to let the traffic in is Windows' firewall, which
the owner adds once (step 2). A phone or tablet on the home network then plays
the session; **a browser on this PC does not**, at `localhost` or at the LAN
address — it gets the page and its numbers, but no picture and no sound
(measured Nov 11). Use a device on the home network, or the TV app itself.

To time that device rather than the headless Chrome, a bench can wait for it:

```bash
tools/stream.sh bench --viewer external --seconds 60 --label phone     # a round, then 30 s of presses
tools/stream.sh bench --viewer external --probe --seconds 60 --label card  # presses only
```

It starts the round (or the card), prints `http://<this PC's LAN address>:<player
port>/`, waits up to three minutes for a viewer with receive data to register,
and then measures that viewer; the report's rows say its kind and platform. A
round run then flips the latency card up for `--press-seconds` (30 s by default;
0 skips it) on the same session and viewer, so one phone run gives the round's
numbers and a measured press-to-screen, and the run line's bitrate comes from
the round's own snapshot.

A stale browser tab left open on a session's player URL on this PC (localhost)
used to reconnect to every new session and show up as a viewer; it no longer
does (M15 fix8): a page whose session ended says so and stops asking, and a page
that reconnects anyway is named by the relay and ignored by the bench, its
measurements refused. A page that never shows a picture reports nothing either,
and a row that holds only the host's pipeline stages is left out of the report.

1. **Mirrored networking is already on.** A fresh PC needs this in
   `%USERPROFILE%\.wslconfig`, then one restart of WSL from PowerShell:

   ```ini
   [wsl2]
   networkingMode=mirrored
   ```

   In this mode the distro answers on the PC's LAN address instead of a private
   one, which is what the other device can reach. (Without it, `netsh interface
   portproxy` carries TCP only — the page and signalling — and WebRTC, which is
   UDP, does not connect: mirrored mode is the one that works for both.)
2. **Let the firewall through**, in an Administrator PowerShell (adjust the
   subnet to yours; the ports are the three above plus UDP for the media):

   ```powershell
   New-NetFirewallRule -DisplayName "Thumb Party stream (TCP)" -Direction Inbound -Protocol TCP -LocalPort 45782,45781,45780 -Action Allow -Profile Private
   New-NetFirewallRule -DisplayName "Thumb Party stream (WebRTC)" -Direction Inbound -Protocol UDP -Action Allow -Profile Private -Program "$env:SystemRoot\System32\wslrelay.exe"
   ```

   WebRTC picks its UDP ports when it starts, so the rule names the program, not
   a port. If Windows 11 warns that a rule for `wslrelay.exe` is unusual, the
   narrower version is a `-RemoteAddress <your subnet>` on the same rule. With
   these two rules an iPhone's Safari on the home network played picture and
   sound from the PC's LAN address (Nov 11).
3. **Open the player on the other device:** `http://<this PC's LAN address>:45782/`.
   `tools/stream.sh url` prints that address (and `localhost`); the PC's Wi-Fi
   address and the distro's are the same in mirrored mode. If media still does
   not flow (the picture stays black, the numbers show 0 frames), the two devices
   are on different networks or the network blocks the traffic: the next rung is
   a TURN server, which the session does not carry yet.
4. **Tap to start sound** if the browser asks, and turn the phone's screen
   rotation to landscape: the page fills whatever it is given.

## Logs

`docker logs thumb-party-<name>` (or `tools/stream.sh logs`) has one line per
event: each part starting, the `ready:` line, and the reason the session ended.
Inside the container every part keeps its own log under `/run/thumb-party/`:
`pipeline.log` (GStreamer), `app.log` (the TV app's stderr; a release build keeps
its own lines in memory, so the pairing code is on the screen, not in a file),
`signalling.log`, `player.log` and `sound.log`.

```bash
docker exec thumb-party-party tail -n 50 /run/thumb-party/pipeline.log
```

With the tap on, two more lines go there once a second while a client or a
tunnel is open (M15 opt2c):

```
tapdiag: t=<unix s> fr=<n> kb=<n> key=<n> keymax=<KB> dmax=<KB> q=<max depth> drop=<n> kreq=<n> sent=<KB> sendmax=<ms> slow=<n> outq=<KB max>
tunnel: t=<unix s> up=<KB> down=<KB> sendmax=<ms> slow=<n> outq=<KB max>
```

`tapdiag:` is the tap server's own view — the encoder's frames and bytes, each
client's queue depth, drops and keyframe requests, and the bytes still unsent in
its socket — and `tunnel:` the relay's — bytes both ways and the unsent bytes of
the phone-facing socket. `sendmax` and `slow` time the writes toward the phone;
a backlog that only `outq` shows is in the kernel's buffer, not the encoder,
which is where a phone that stops reading hides it. A bench keeps both kinds of
line in `<results>/<label>-tapdiag.log` and says one `tap diagnostics:` line
with their worst second.

## Cleaning up

```bash
tools/stream.sh down --all
docker rmi tp-session:latest          # in the distro; the image is 1.6 GB
```

## Decisions, and what is not here yet

- **Host networking** instead of published ports: WebRTC media is UDP from the
  container's own address, which a browser on Windows cannot reach through
  Docker's bridge. With `--network host` the player, the signalling server and
  the media all sit on the distro's network, one rule for all of them.
- **`congestion-control=disabled`**: the design asks for a bitrate that is held,
  not negotiated, so a busy network shows as dropped frames in the player's
  numbers rather than as a resolution that quietly falls. The number has to
  reach `webrtcsink` too (`max-bitrate`, `start-bitrate`) and not only the
  encoder: webrtcsink sets the encoder's bitrate itself, so c2 measured 19.9
  Mbit/s on the wire with 10 000 kbit/s asked of the encoder alone, while the
  same number on the element carried 11.6 Mbit/s of video and FEC for a busy
  Arena round (7.2 with FEC off).
- **A new session opens on the app's first-run consent dialog.** The app has no
  settings stored yet, so "Share anonymous gameplay stats?" is up over the home
  screen with the pairing code beside it; nothing carries a click or a key from
  the player back into the app yet, so it stays up for the life of the session.
- **Two sessions share one GPU:** with both running, each delivered about 31
  fps at 1080p instead of the 55–59 one session manages (c1 report, measured
  through the players), so a second session on the same box costs picture rate.
- **Not here yet:** creating and stopping sessions from the app or the server
  (that needs the server side, job a2), TURN for networks that need a relay,
  more than one player per session watching the same stream (it works, but
  nothing tests it), and a Linux GPU machine to check the non-WSL2 run on.
