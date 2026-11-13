# o1-4 — what it takes on the host to tap encoded H.264 and send it to a WebCodecs player

Read-only study. No repository file was changed but this report; nothing was installed, downloaded or started in the distro.

## Summary

1. **The pipeline is already the one a tap wants.** `waylanddisplaysrc` → `videoconvert` → `nvautogpuh264enc` (CBR, 1 s GOP, no B-frames, `tune=ultra-low-latency`) → `h264parse config-interval=-1` → `webrtcsink` (`streaming/entrypoint.sh:348-388`). The encoder writes Annex B (byte-stream, `alignment=au`, `aud=true`), so access units are already delimited before WebRTC ever sees them.
2. **A tap after the encoder is one `tee` and one `appsink`**, in a second process or a Python GStreamer sender, next to the untouched `webrtcsink` branch. No re-encode: `webrtcsink` shows `video/x-h264` on its `video_%u` sink pad (gst-inspect), so the existing WebRTC viewer and the new tap share one NVENC encode (`streaming/entrypoint.sh:370`).
3. **The sender should be Python GStreamer + a WebSocket server.** In the distro: `python3-gi` with `GstApp` and `GstVideo.video_event_new_upstream_force_key_unit` is present, GStreamer is 1.24.2; `python3-websockets` is not installed but is an Ubuntu `noble` package (candidate 10.4-1), and a stdlib WebSocket handshake is ~40 lines if we want no new package. The session image's runtime stage has `python3` but **no `python3-gi`** (`streaming/Dockerfile:171-181`), so the image needs that one apt line.
4. **`node` is absent and `webrtcsink` has no data channel for custom payload** (only its navigation channel, `net/webrtc/src/webrtcsink/imp.rs:1361`), so candidates (b) and (c) of the brief are dead ends; (d) WebTransport needs HTTP/3 — no `aioquic`, no quinn plugin, Safari only from 26.4 (o1-2).
5. **What blocks the phone is not the host but the origin:** WebCodecs is `[SecureContext]`, so the page must be served over `https:` (or loopback) — o1-2's finding, and it decides the first slice's test rig.
6. **Sound should stay on the existing WebRTC path** for the first slice (o1-2: `AudioDecoder` is iOS 26+, Web Audio is muted by the hardware switch; a second WebRTC connection for audio is the known-working pattern).
7. **Loss handling is three small pieces:** a keyframe request message from the page → `UpstreamForceKeyUnit` pushed from the appsink (helper verified in `gi`) → NVENC IDR (`min-force-key-unit-interval` exists, default 0); drop-to-next-IDR in the page on a gap; a bounded `leaky` queue plus `appsink drop=true` and the page's `bufferedAmount` as the backlog signal.
8. **Estimate:** 7 flash phases, 100-140 turns each; the minimal first slice (host tap + page decoder + WebSocket, video only, marker on) is phases 1-4. Current marker numbers it would be measured against: 197-225 ms press-to-screen on iPhone Safari (STATUS.md).

## Decisions (low-usage: safest choice, no question asked)

1. **No code changed.** The brief is a survey; every design below is a recommendation for a later brief.
2. **Sender = Python GStreamer + WebSocket** (candidate a): it is the only candidate that gets per-frame control (keyframe requests, thinning) with tools already present in the distro, without Node and without a Rust build.
3. **Tap point = right after the encoder, via `tee`, with a second `h264parse` in the tap branch** producing `stream-format=byte-stream, alignment=au`. The existing branch keeps its own parser and `webrtcsink` unchanged; a `SESSION_TAP` switch, default off, keeps today's behaviour byte for byte.
4. **A new port for the tap** (a new `TAP_PORT` env, published implicitly because sessions run `--network host`, `tools/stream.sh:396-400`) instead of teaching `serve.py`'s stdlib `ThreadingHTTPServer` a WebSocket upgrade (`streaming/player/serve.py:334`).
5. **Audio out of scope for the first slice**; the page keeps the existing `TP-Sound` WebRTC consumer (`streaming/player/streams.js:20-21`).
6. **First slice verified on loopback first** (headless Chrome 157 is in the distro at `/opt/chrome-headless-shell/chrome-headless-shell-linux64`, and loopback is a secure context), the phone only once an `https:` origin exists per o1-2.

## 1. The exact pipeline

`streaming/entrypoint.sh:348` `build_pipeline()` builds one `gst-launch-1.0 -e` command line:

| Part | Where | What |
| --- | --- | --- |
| capture | `:353` | `waylanddisplaysrc render-node=software` (WSL2 EGL needs software render node) |
| caps | `:354` | `video/x-raw,width=$width,height=$height,framerate=$frame_rate/1`, i.e. 1920x1080 at 60 fps from `SESSION_WIDTH`/`SESSION_HEIGHT`/`SESSION_FRAME_RATE` (`:19-21`) |
| convert | `:355` | `videoconvert` |
| encoder | `:100`, `:357-364` | default `nvautogpuh264enc` (`nvh264enc` is broken on this driver); `bitrate=$video_kbps rate-control=cbr gop-size=$gop_frames b-frames=0 zero-reorder-delay=true preset=p1 tune=ultra-low-latency rc-lookahead=0`, optional `vbv-buffer-size` + `strict-gop` |
| bitrate maths | `:27`, `:113-116` | wire ceiling `SESSION_BITRATE_KBPS` 10000; encoder gets `(ceiling - audio) / (1 + FEC 110 %)` |
| GOP | `:34` | `gop_frames = frame_rate` → **one IDR per second** at 60 fps |
| parse | `:369` | `h264parse config-interval=-1` → SPS/PPS in band with every IDR |
| send | `:370-377` | `webrtcsink name=ws signaller::uri=ws://127.0.0.1:$signal_port congestion-control=disabled max-bitrate=$video_bps start-bitrate=$video_bps do-fec=… do-retransmission=…` |
| sound | `:325-342` | `pulsesrc device=party.monitor ! queue ! audioconvert ! audioresample ! audio/x-raw,rate=48000,channels=2 ! opusenc bitrate=96000` then either `ws.` (joined) or its own `webrtcsink name=ws-audio` (separate) |
| signalling | `:261`, `:122` | `gst-webrtc-signalling-server --host 0.0.0.0 --port 8443` |
| latency tracer | `:384` | `GST_TRACERS="latency(flags=pipeline+element)" GST_DEBUG="GST_TRACER:7"` into `/run/thumb-party/pipeline.log` |
| metrics | `:313-318` | `stream-sampler` reads that log and posts the stages to the host (`packages/metrics/lib/src/stream_sampler.dart:44-90`) |
| marker (draw) | `:156`, `:424`, `packages/party_host/lib/src/ui/marker_strip.dart:60-80` | `THUMBPARTY_MARKER=1` makes the app draw a frame counter + host clock into the picture's own pixels |
| marker (sample) | `streaming/player/marker_reader.js:1-30`, `reporter.js:20-21`, `serve.py:26` | the page reads the strip from a canvas, batches it, `POST /stats/stream` |

Encoder facts measured in the distro (`gst-inspect-1.0 nvautogpuh264enc`):
* SRC caps: `video/x-h264`, `stream-format: { avc, byte-stream }`, `alignment: au`, profiles main/high/constrained-baseline/baseline/high-4:4:4.
* `aud: Use AU (Access Unit) delimiter … Default: true` — every AU already starts with an AUD.
* `bitrate` and `gop-size` are `changeable in … PLAYING` (runtime reconfiguration is possible).
* `min-force-key-unit-interval … Default: 0` — the element does handle force-key-unit requests.
* No `intra-refresh`, no `profile`, no `repeat-headers`, no `bframes` spelled only `b-frames`. **There is no intra-refresh property in the installed encoder.**

Pipeline-wide latency: the only named wait in the send path is the ~25 ms in `webrtcsink` (`streaming/entrypoint.sh:62-63`); sound joined to the picture adds the ~27 ms noted in STATUS.md.

## 2. What the installed GStreamer offers for a tap

Commands and their answers (distro `tp-stream`, read-only):

```
$ gst-launch-1.0 --version         → gst-launch-1.0 version 1.24.2 / GStreamer 1.24.2
$ gst-inspect-1.0 -b               → Total count: 0 blacklisted files
$ for e in appsink tee queue h264parse rtph264pay … ; do gst-inspect-1.0 $e; done
  YES appsink tee queue h264parse rtph264pay rtph264depay webrtcbin
  YES souphttpsrc souphttpclientsink tcpserversink udpsink rtpsink rtpbin rtspsrc
  YES nvh264enc nvautogpuh264enc nvcudah264enc openh264enc
  NO  x264enc vah264enc fallbacksrc hlssink3 whepsrc rtpbin2
```

`webrtcsink` **is** installed, at `/usr/local/lib/gstreamer-1.0/libgstrswebrtc.so`, but `GST_PLUGIN_PATH` is empty in the distro shell (the image sets it, `streaming/Dockerfile:190`), so only

```
$ GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0 gst-inspect-1.0 webrtcsink
  Plugin Details: rswebrtc 0.13.6-a9f6a26 … net/webrtc …
$ … gst-inspect-1.0 | grep -i webrtc
  rswebrtc: awskvswebrtcsink, janusvrwebrtcsink, livekitwebrtcsink, livekitwebrtcsrc,
            webrtcsink, webrtcsrc, whipclientsink, whipserversrc
  webrtc:   webrtcbin
```

find it. Sink pad template `video_%u` accepts `video/x-raw`, `…GLMemory`, `…CUDAMemory`, `…NVMM`, `…D3D11Memory`, `video/x-vp8`, `video/x-h264`, `video/x-vp9`, `video/x-h265`, `video/x-av1`.

Python and the rest:

```
$ python3 --version                 → Python 3.12.3
$ python3 -c "…from gi.repository import Gst…"  → GStreamer 1.24.2
$ python3 -c "…GstApp…"             → GstApp ok <class 'gi.repository.GstApp.AppSink'>
$ python3 -c "…GstVideo…"           → video_event_new_upstream_force_key_unit, video_event_new_downstream_force_key_unit,
                                      video_event_is_force_key_unit, video_event_parse_*
$ python3 -c "import websockets"    → ModuleNotFoundError      (apt candidate python3-websockets 10.4-1)
$ python3 -c "import aiohttp"       → ModuleNotFoundError      (apt candidate 3.9.1-1ubuntu0.1)
$ python3 -c "import aioquic"       → ModuleNotFoundError      (apt candidate 0.9.25-3build2)
$ python3 -m pip --version          → No module named pip
$ node --version                    → command not found
$ cargo --version / rustc --version → 1.99.1
$ ls /work/gst-plugins-rs/target/release/*.so → libgstrswebrtc.so only (no quinn/quic plugin built)
```

Per candidate sender:

**(a) Python GStreamer + appsink + a WebSocket server — viable, recommended.** Everything the sender needs is in the distro except a WebSocket library, and that is one apt package (or a stdlib handshake in `serve.py`'s style). One process per session, `GLib.MainLoop` + `appsink` `new-sample` → parse AU boundaries (AUD) → send binary frames. Cost in the image: `python3-gi` (and optionally `python3-websockets`) added to `streaming/Dockerfile:171-181`.

**(b) gst-launch into a small TCP/WebSocket relay — no.** `tcpserversink` is present and works, but no browser can consume raw TCP; it still needs a WebSocket server, in Node (absent) or Python (same as (a)), plus a second process to hold frame metadata and answer keyframe requests. Strictly more moving parts than (a).

**(c) WebRTC data channel — no.** `webrtcsink` 0.13.6 creates exactly one data channel, for navigation, and only when `enable-data-channel-navigation` is on (`net/webrtc/src/webrtcsink/imp.rs:1361`, property list from gst-inspect confirms there is no other channel property). Driving `webrtcbin` directly would mean writing a second signalling protocol beside the existing one: the page joins the `gst-webrtc-signalling-server` on port 8443 with `GstWebRTCAPI` (`streaming/player/player.js:20,126-128,319-321`) and picks producers by meta name (`streaming/player/streams.js:20-21,68-76`). And SCTP data channels would serialise a 10 Mbit/s video stream behind their own flow control for no gain.

**(d) WebTransport — not now.** It needs HTTP/3: `aioquic` is an apt candidate but not installed, no quinn/quic GStreamer plugin is built (`/work/gst-plugins-rs/target/release` has only `libgstrswebrtc.so`), and Safari ships WebTransport only from 26.4 (o1-2 §3). It is the right long-term transport (no TCP head-of-line) but a phase of its own.

## 3. A tee design

```
nvautogpuh264enc
  ! tee name=t
  t. ! h264parse config-interval=-1 ! webrtcsink name=ws …      (today's branch, unchanged)
  t. ! queue leaky=downstream max-size-buffers=1 max-size-time=0
     ! h264parse config-interval=-1
     ! video/x-h264,stream-format=byte-stream,alignment=au
     ! appsink name=tap drop=true max-buffers=1 sync=false emit-signals=true
```

* **Two parsers, not one.** A parser's `src` pad has one negotiated format; `webrtcsink` wants AVC (its own `rtph264pay` sets `config-interval=-1`, `net/webrtc/src/webrtcsink/imp.rs:708-710`), the tap wants byte-stream. Keeping `h264parse` where it is (`streaming/entrypoint.sh:369`) and adding a second one in the tap branch gives each branch its own format with no change to the existing behaviour. NVENC already emits byte-stream (`stream-format` in its SRC caps), so the second parser is nearly pass-through.
* **Pre-encoded input, shared encoder.** `webrtcsink` accepts `video/x-h264` on `video_%u` and does not re-encode it — that is what the session does today — so the tap adds **no** second encode and the GPU cost stays at one NVENC session (the cap is 12 per GPU, STATUS.md). The tee branch copies no pixels: H.264 buffers are refcounted.
* **The existing branch is untouched by default**: the whole tap lives behind a `SESSION_TAP=off` switch modelled on `SESSION_AUDIO`/`SESSION_MARKER` (`streaming/entrypoint.sh:74-97,156`).
* **Per-frame metadata the sender must add** (all available from the sample, none from the pipeline's internals):
  * `ptsNs` — the buffer's running time (µs in GStreamer; convert), the basis for a per-frame age once the page has a clock offset (`streaming/player/clock_sync.js`, `GET /clock` in `serve.py:17`);
  * `seq` — the sender's own frame counter (the marker row keeps its own counter; the sender's is only for gap detection);
  * `isKey` — `Gst.BufferFlags.DELTA_UNIT` absent;
  * `bytes` — sample size, for the page's own bitrate figure;
  * `capturedHostMs` — optional; the marker row already carries the host clock inside the picture, so the first slice needs nothing more.
* **Where the new stream goes.** Sessions run `--network host` (`tools/stream.sh:396-400`), so a new listener inside the container is reachable on the phone with no publish step. Recommended: the sender owns a new WebSocket port (new `TAP_PORT`, default next to the existing four in `streaming/entrypoint.sh:121-127`); `serve.py` keeps being the page's HTTP relay only (its `ThreadingHTTPServer`, `streaming/player/serve.py:334`, has no upgrade path and its endpoint list is deliberately closed, `serve.py:13-42`). The alternative — a `/stream` upgrade route inside `serve.py` — buys same-origin convenience (`ws://host:45782/stream`) at the cost of teaching the relay a second protocol.
* **Marker and metrics carry over unchanged.** The marker is pixels drawn by the app (`marker_strip.dart:60-80`); the canvas player reads the same strip from its own canvas with the same `marker_reader.js` code and reports the same batch through `POST /stats/stream` (`serve.py:26,253`). What does *not* carry over is `stats.js`'s `getStats()` figures — jitter buffer, dropped frames, incoming bitrate (`streaming/player/stats.js:48,72-75`) — which have no peer connection to come from; the sender's counters (fps, bytes, queue drops) and the page's `VideoDecoder` output timestamps replace them.

## 4. Loss handling without a jitter buffer

* **Keyframe request path.** Page → `{"type":"keyframe"}` on the same WebSocket → sender calls `appsink.send_event(GstVideo.video_event_new_upstream_force_key_unit(...))` (helper present in `gi`, see §2). The event travels upstream through the tee to NVENC, which forces an IDR; `min-force-key-unit-interval` (default 0) is the storm limiter to set, e.g. 100 ms. The same mechanism is what `webrtcsink` already uses for a consumer's PLI/FIR: it sends `UpstreamForceKeyUnitEvent` to the encoder's src pad (`imp.rs:2640`), and its own encoder turns a `ForceKeyUnit` event into `force-IDR` (`imp.rs:570-577`).
* **Current keyframe interval:** 1 s (`streaming/entrypoint.sh:34`, `gop_frames = frame_rate`). For a tap that can ask for IDRs on demand, a longer GOP (2-4 s) would cut the bitrate spikes; that is a tuning decision for a run phase, and it changes the WebRTC viewer too because the encode is shared.
* **Intra-refresh:** not available — the NVENC element has no such property and `x264enc` (which has one) is not installed. The nearest thing is `strict-gop=true` plus `vbv-buffer-size` (already switchable, `streaming/entrypoint.sh:362-364`).
* **On a gap** (a missing `seq`, a decode error, a keyframe request outstanding): the page drops every chunk until the next `isKey` chunk, keeps the last `VideoFrame` on the canvas, and counts the gap in the batch. That is the WebCodecs equivalent of "drop to the next keyframe, show the last frame".
* **Congestion on Wi-Fi.** Over WebSocket the transport is TCP, so loss shows up as delay, not as gaps. Three layers, cheapest first: (i) `queue leaky=downstream max-size-buffers=1` + `appsink drop=true max-buffers=1` so the pipeline never blocks; (ii) the page reports its `bufferedAmount` (and its decode lag) in reply to each keyframe request or on a short periodic message, and while that is over a threshold the sender drops non-key frames up to the next IDR — never mid-GOP without dropping to the IDR, or the decoder shows artefacts forever; (iii) bitrate: the encoder's `bitrate` is changeable in PLAYING, but the encode is *shared* with the WebRTC viewer, so a per-viewer reduction can only come from a second encoder (12-session GPU cap) — worth a phase of its own, not the first slice.

## 5. Phased build estimate (flash-jobs, 80-150 turns each)

| Phase | What it builds | Files touched | Turns |
| --- | --- | --- | --- |
| **1. host tap (build)** | `SESSION_TAP` switch, tee + second `h264parse` + `appsink` branch, a sender process skeleton with a fake sample source; image gains `python3-gi` (+`python3-websockets`) | `streaming/entrypoint.sh`, `streaming/Dockerfile`, `streaming/player/tap_sender.py` (new), `streaming/player/relay_test.py`-style test | ~120 |
| **2. host sender (run)** | real NVENC frames over the WebSocket to a headless client; fps, bytes, AU sizes, keyframe cadence measured; keyframe request proven | `streaming/player/tap_sender.py`, a test client script, report | ~110 |
| **3. page decoder (build)** | `VideoDecoder` (`avc1.4d0028` vs Annex B decision), chunk queue, canvas render, gap logic; behind a page option, old path untouched | `streaming/player/index.html`, `streaming/player/video_decoder.js` (new), `streaming/player/player.js`, `serve.py` page list | ~130 |
| **4. page run (measure)** | headless Chrome 157 on loopback first, then the phone once an `https:` origin exists (o1-2); marker on, `press_to_marker` read from the canvas | report only | ~110 |
| **5. loss + congestion** | keyframe request from the page, drop-to-IDR, `bufferedAmount` feedback, drop counters in the batch | `tap_sender.py`, `video_decoder.js`, `marker_batch.js`/`reporter.js` | ~120 |
| **6. audio** | hybrid: keep `TP-Sound` on WebRTC (default) or `AudioDecoder` on iOS 26+; lip-sync anchored on the video frame's timestamp | `streaming/player/streams.js`, `video_decoder.js`, `index.html` | ~100 |
| **7. measurement + docs** | sender/page stages into the existing `stream` record, README/design updates | `packages/metrics`, `docs/streaming-*`, `streaming/README.md` | ~100 |

**Minimal first slice that shows the latency on the phone:** phases 1, 2, 3 and the headless half of 4 — video only, WebSocket, marker on, old player path untouched behind an option. On loopback that gives a number the same day; on the phone it needs the `https:` origin first (o1-2's "own domain, A record → LAN IP" option), which is the owner's call and outside the host work.

## Unverified

* **NVENC repeats SPS/PPS by itself at every IDR** — it exposes no `repeat-headers` property; the design relies on `h264parse config-interval=-1` (already in the pipeline) instead of on that.
* **`nvautogpuh264enc` honours an `UpstreamForceKeyUnit` pushed from an `appsink`** — the `min-force-key-unit-interval` property proves it handles force-key-unit, but nothing was run (the brief forbids starting a session).
* **Cost of the second `h264parse`** on the session's CPU (measured 224 % CPU for a session, STATUS.md; the extra parse is expected to be a few percent, not measured).
* **Whether a tap branch disturbs `webrtcsink`'s own bitrate adaptation** — with `congestion-control=disabled` it should not, because the element cannot reach the encoder anyway (it gets pre-encoded H.264), but this is reasoning, not a measurement.
* **`QoS`/late-buffer behaviour on the tap branch** (`appsink sync=false max-lateness` untouched) — no run.
* **Whether apt's `python3-websockets` 10.4 is enough** (it is for framing and `serve()`; only the distro cache was read, nothing installed).
* **Building a quinn/WebTransport plugin from `/work/gst-plugins-rs` without network** — the crate cache may already hold the dependencies; not tried.
* Everything o1-1/o1-2 mark as unverified on device stays unverified here: WebCodecs on a plain-http LAN origin, `VideoDecoder` on the family's iPhones, Annex-B payload acceptance.

## Command outputs relied on (short)

```
$ gst-launch-1.0 --version                    → 1.24.2
$ GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0 gst-inspect-1.0 webrtcsink
   Plugin Details: rswebrtc 0.13.6-a9f6a26, /usr/local/lib/gstreamer-1.0/libgstrswebrtc.so
   SINK template 'video_%u': … video/x-h264 …
$ gst-inspect-1.0 nvautogpuh264enc            → aud Default: true; bitrate/gop-size changeable in PLAYING;
                                                 min-force-key-unit-interval Default: 0; no intra-refresh/profile
$ gst-inspect-1.0 appsink                     → drop, emit-signals, max-buffers, sync
$ gst-inspect-1.0 h264parse                   → config-interval (-1 = with every IDR)
$ gst-inspect-1.0 queue                       → leaky, max-size-buffers/bytes/time
$ apt-cache policy python3-websockets python3-aiohttp python3-aioquic → all "Installed: (none)", candidates 10.4-1 / 3.9.1 / 0.9.25
$ /opt/chrome-headless-shell/chrome-headless-shell-linux64/chrome-headless-shell --version → 157.0.8103.50
$ grep create_data_channel /work/gst-plugins-rs/net/webrtc/src/webrtcsink/imp.rs → 1361 (navigation channel only)
$ grep rtph264pay … → 708-710 (config-interval -1 set by webrtcsink)
$ grep UpstreamForceKeyUnitEvent … → 2640, and 570-577 (force-IDR on webrtcsink's own encoder)
```

## Commit message

docs: study of tapping encoded H.264 on the host for a WebCodecs player

Adds the o1-4 read-only report: the encoder's exact settings and where the
tap belongs (a tee after nvautogpuh264enc, a second h264parse and an appsink,
the webrtcsink branch unchanged), what the distro's GStreamer 1.24.2 and its
python-gi actually offer, why a Python GStreamer WebSocket sender is the only
viable candidate (no Node, no custom data channel in webrtcsink, no HTTP/3),
the keyframe/drop/backlog design, and a seven-phase estimate. No code changed.

## Status row

o1-4 host read: done — the host can tap NVENC H.264 after the encoder with tee + appsink and send it from Python GStreamer over a WebSocket, at no extra encode; open: the custom player build (phases 1-7), `python3-gi` in the image, and a secure origin for the phone.

## Delete

- none
