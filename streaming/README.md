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

The app has the last word on the controller port: it asks for the one it is
given (45780 without settings) and takes any free port when that is busy, so a
second session's phones connect somewhere else. The ready line and `url` say
which port it got, and the app tells it on its own home screen ("Listening on
port …"). Pinning it is a change to the app, not to this image.

The defaults (`8080`, `8443`, `45780`) are what `docker run` without settings
gives, so the image is usable by hand too.

## The picture's settings (M15 t1)

Each is one `-e KEY=VALUE` on `docker run`; `tools/stream.sh bench --set
KEY=VALUE` passes them without a rebuild, which is how the tuning was measured.
The comments in [`entrypoint.sh`](entrypoint.sh) carry the numbers behind each
default.

| Setting | Default | What it does, and what M15 t1 measured |
| --- | --- | --- |
| `SESSION_BITRATE_KBPS` | 10000 | The video's ceiling: `webrtcsink`'s `max-bitrate` and `start-bitrate` and NVENC's own bitrate. A 1080p Arena round carried 11.6 Mbit/s with FEC on, 7.2 without |
| `SESSION_GOP_FRAMES` | the frame rate (a keyframe a second) | `-1` is keyframes on request only. Worse: the receiver's jitter buffer 262 ms against 127–170. Left at one a second so a joining player sees a picture at once |
| `SESSION_VBV_KBITS` | 0 (NVENC's default, a second's worth) | The encoder's VBV/HRD buffer, in kbits: `gst-inspect-1.0 nvautogpuh264enc` says "VBV(HRD) Buffer Size in kbits (0 = NVENC default)". One frame's worth (167 at 10 Mbit/s and 60 fps) has measured 144–205 ms total and 213–253 press over six runs; the baseline runs beside them were 161–223 and 230–266, so it never left the 44 ms noise. Off |
| `SESSION_FEC` | true | Forward error correction. No lower delay with it off, and it is the larger part of what is received above the ceiling (11.6 Mbit/s against 7.2) |
| `SESSION_RETRANSMISSION` | true | Resend lost packets; no delay difference either way |
| `SESSION_SPLIT_TRACKS` | false | Play picture and sound on two media elements so the browser stops syncing them. Worse: 42 delivered fps against 53, press 246 ms against 230, so one element stays |
| `SESSION_ENCODER` | `nvautogpuh264enc` | `nvcudah264enc` also works and was no better (press 261 ms against the baseline's 230–266) |
| `SESSION_WIDTH`, `SESSION_HEIGHT`, `SESSION_FRAME_RATE` | 1920, 1080, 60 | The window and the encoder size. 720p was worse (total 186 ms, jitter 151) |

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
reconnects on its own.

The page learns its signalling port from `config.js`, which the entrypoint
writes next to it, and loads the `gstwebrtc-api` bundle the image builds from the
same gst-plugins-rs release as `webrtcsink`.

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
  container's cgroup counters (CPU split by process, memory) and `nvidia-smi`
  (GPU, encoder, memory) every `SAMPLER_INTERVAL_S` seconds, tails the pipeline
  log for the tracer's records, and leaves the latest resource reading in
  `/run/thumb-party/pipeline.json`. `SESSIONS_AT_ONCE` says how many sessions
  the machine runs, so the GPU's numbers can be read per session.
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
(before the body is read), the 502 with no host, the press queue and the 64 KB
cap — fifteen checks, and it exits 1 at the first that does not hold.

The bench's run line reads what the viewers received against the ceiling the
video asks for, and who they were (the ingest keeps a viewer's kind and platform
and no user agent), for example `1 viewer(s) browser/chrome-headless, 2205 kbit/s
received against the 10000 kbit/s ceiling`. Received is the whole wire: video up
to `SESSION_BITRATE_KBPS`, FEC on top of it, and the 96 kbit/s sound, so it sits
above the ceiling whenever the picture fills it (M15 t1 measured 11.6 Mbit/s
with FEC and 7.2 without, same round). The probe's card is nearly still, so its
received rate says nothing about the game's.

`--viewer external` (M15 g1) opens no browser: the bench starts the session and
the round (or the card) first, because the host only accepts a viewer's batch
while a session is playing, then prints the LAN address to open and waits up to
three minutes, a line every ten seconds, until a viewer registers. From then on
it measures that viewer. `--viewer-cpus L` runs the headless Chrome on the cores
in `L` (`taskset`), `--session-cpus L` runs the session container on the cores in
`L` (`docker --cpuset-cpus`): pinning the two apart is how a run asks whether the
viewer's own CPU was starving it. A session pinned to four cores never became
ready in the g1 runs; eight did.

## Watching from another device on the Wi-Fi

The distro runs in WSL2's **mirrored networking** (the owner's
`%USERPROFILE%\.wslconfig`), so it holds this PC's own LAN address: the address
`tools/stream.sh url` prints, the one `ipconfig` shows, and the one the other
device types. What still has to let the traffic in is Windows' firewall, which
the owner adds once (step 2). A phone or tablet on the Wi-Fi then plays the
session; **a browser on this PC does not**, at `localhost` or at the LAN
address — it gets the page and its numbers, but no picture and no sound
(measured Nov 11). Use a device on the Wi-Fi, or the TV app itself.

To time that device rather than the headless Chrome, a bench can wait for it:

```bash
tools/stream.sh bench --viewer external --probe --seconds 60 --label phone
```

It plays the latency card, prints `http://<this PC's LAN address>:<player port>/`,
waits up to three minutes for a viewer to register, and then times the presses
against that viewer; the report's rows say the viewer's kind and platform.

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
