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
| `python3 -m http.server` | Serves the player page and the built `gstwebrtc-api` bundle |
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
| `AUTOMATION_PORT` | 8787 | 45783 | The host's automation interface (M15 a2); loopback only |

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

## Building and running it

```bash
tools/stream.sh build                     # copy this checkout into the distro, build tp-session:latest there
tools/stream.sh up                        # start session "party" and wait for its ready line
tools/stream.sh status                    # what runs, and its ready line
tools/stream.sh logs --name party --follow
tools/stream.sh url                       # the player URL and the controller address
tools/stream.sh up --name kitchen --port-base 46000
tools/stream.sh down --name kitchen       # stop one session
tools/stream.sh down --all                # stop every session
```

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
- **The relay**: the player page's web server (`serve.py`) passes the page's
  calls to the host's automation interface with the session's token, so the
  browser needs none: `/stats/stream`, `/player`, `/clock`, `/presses`,
  `/flips` and `/pipeline`.

The token is the session's own, in `/run/thumb-party/automation.token`, unless
`AUTOMATION_TOKEN` gave it one; the automation interface listens on loopback
inside the container only. `tools/stream.sh bench` starts a session headless,
adds a simulated player and lets a round run; in the `tp-stream` distro on WSL2
the whole run has to happen inside one `wsl` call, because the distro's VM stops
when no command is running in it and takes the session with it.

## Watching from another device on the Wi-Fi

A browser on this PC needs nothing: Windows forwards `localhost` to the distro.
A TV, tablet or phone on the Wi-Fi needs the steps below, because WSL2 keeps the
distro on a private network of its own and WebRTC media is UDP, which published
ports do not carry.

1. **Give the distro the LAN's network.** In Windows 11 (22H2 or newer), put
   this in `%USERPROFILE%\.wslconfig`:

   ```ini
   [wsl2]
   networkingMode=mirrored
   ```

   Then run `wsl --shutdown` in PowerShell and start the session again. In
   mirrored mode the distro answers on this PC's LAN address, so the other
   device can reach it. (Alternative, if the PC can't use mirrored mode: forward
   the ports by hand with `netsh interface portproxy` plus a firewall rule. That
   carries TCP only, which the player page and signalling need, and WebRTC may
   not connect without it — mirrored mode is the one that works for both.)
2. **Let the firewall through**, in an Administrator PowerShell (adjust the
   subnet to yours; the ports are the three above plus UDP for the media):

   ```powershell
   New-NetFirewallRule -DisplayName "Thumb Party stream (TCP)" -Direction Inbound -Protocol TCP -LocalPort 45782,45781,45780 -Action Allow -Profile Private
   New-NetFirewallRule -DisplayName "Thumb Party stream (WebRTC)" -Direction Inbound -Protocol UDP -Action Allow -Profile Private -Program "$env:SystemRoot\System32\wslrelay.exe"
   ```

   WebRTC picks its UDP ports when it starts, so the rule names the program, not
   a port. If Windows 11 warns that a rule for `wslrelay.exe` is unusual, the
   narrower version is a `-RemoteAddress <your subnet>` on the same rule.
3. **Open the player on the other device:** `http://<this PC's LAN address>:45782/`.
   `tools/stream.sh url` prints the address the distro sees; the PC's own Wi-Fi
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
  numbers rather than as a resolution that quietly falls.
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
