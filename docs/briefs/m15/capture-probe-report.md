# Capture probe report (M15): picture and sound out of the headless GPU game, into NVENC

Job: [capture-probe.md](capture-probe.md), Nov 11, 2026. Ran inside the locked-down WSL2 distro `tp-stream` (Ubuntu 24.04.5, kernel 6.18.58.1-microsoft-standard-WSL2, 16 CPUs, RTX 3080). The repository was not changed except this report and the files fetched into `docs/briefs/m15/capture-probe/`; every build, script and log named in §3 lives only in the distro.

The first path won, so paths 2–4 were not run (the brief says stop at the first that holds 55+ fps): **`waylanddisplaysrc` from gst-wayland-display draws the real Arena at 1080p, 60.0 encoded frames a second, with sound in the same file** — in the distro and in a GPU container.

## 1. Verdict

| Path / step | What was run | Result |
| --- | --- | --- |
| **A1. gst-wayland-display**, `waylanddisplaysrc` | gst-wayland-display `016b4fc` built against GStreamer 1.24.2, `render-node=software`, the TV app as its Wayland client, 42.4 s with the Arena round running | **Works — the winner.** App drew **55.0–59.6 fps** (`FRAME_STATS`), the pipeline encoded **60.0 fps for every one of 42 s** (2530 frames, no gap), GPU 45–47 %, encoder 11–12 %, CPU ~1.0 core for the app + ~0.3 for the pipeline, latency tracer **mean 7.99 ms / p95 9.32 ms** |
| A2. weston + capture (`--debug`, pipewire backend, vnc/rdp) | not attempted | **Skipped**: A1 held 60 fps first. The previous probe's weston refused client capture (`Output capture error: unauthorized`, no dmabuf) |
| A3. wlroots headless + wlr-screencopy | not attempted | **Skipped** for the same reason |
| A4. GPU drawing on X (`GDK_BACKEND=x11` + `ximagesrc`) | not attempted | **Skipped**; the previous probe showed every X path here is llvmpipe: Arena 9.6–10.8 fps |
| **B. Sound** | PulseAudio system mode + `module-null-sink` (distro and container), ALSA routed to it, `pulsesrc device=party.monitor ! opusenc` into the same matroska | **Works**: `miniaudio_init: audio device initialized using Linux backend: ALSA`, no `SoLoudBackendNotInitializedException`; the clip has an opus stream and is not silent (mean **−30.8 dB**, max **−8.6 dB**) |
| **C. Two sessions at once** | two containers, each its own compositor + game + encode + null sink, both 1080p60, 77 s | **Partial**: both held 57–60 encoded fps for the first ~25 s, then fell to **40–46 fps each (43–45 mean)** once both Arena rounds were running; app **28–31 fps** each; total GPU **75–78 %**, encoder **24–42 %**, 3.26 GB VRAM, ~190 % CPU per container |
| **D. webrtcsink (stretch)** | gst-plugins-rs 0.13.6 `libgstrswebrtc.so` + `gst-webrtc-signalling-server` | **Works**: pipeline reaches PLAYING, server logs `Listening on: 0.0.0.0:8443` and `registered as a producer`; no web client built |
| **E. Tidy** | containers removed, compositors/apps/servers stopped | Done; where the installs are and disk use: §3.8 |

Five plain lines:

1. **Yes — the whole streaming server runs in containers on this PC's WSL2**: one container per household, each with its own Wayland compositor (inside GStreamer), its own game, its own NVENC encode and its own PulseAudio sink; one household got 1080p60 with sound, two households got 1080p at ~45 fps each.
2. **Catch 1 — "60 fps" is the compositor's rate, not the game's**: the app drew 55–59.6 fps; `waylanddisplaysrc` repeats the last frame to a clean 60. With two sessions encoding at once each drops to 43–45 fps — the second household is not free.
3. **Catch 2 — it only works through the software render node**: WSL's EGL exposes one device with no DRM render node and no `EGL_WL_bind_wayland_display`, so the compositor has to run `render-node=software`; `Supported DMA formats: []` means every frame crosses system memory (game → shm → compositor → `videoconvert` → NVENC) — the GPU (45–47 %) does the drawing, not the capture.
4. **Catch 3 — the capture plugin is hand-built**: pinned commit `016b4fc` (the head wants GStreamer 1.28), built against the distro's 1.24.2 with a 1.24.0 libwayland installed under `/opt/wayland124`; about ten minutes of cargo on this machine, and both files have to be put into the image.
5. **Catch 4 — everything is a root, profile-mode, patched build driven by the simulated controller**, and NVENC ignores the requested `bitrate` (68.5 MB for 34.8 s ≈ 15.7 Mbit/s at default settings); for a real session the encoder settings need to be pinned and checked.

## 2. Environment and versions

| Thing | Version |
| --- | --- |
| Distro | Ubuntu 24.04.5 LTS, WSL2, kernel 6.18.58.1-microsoft-standard-WSL2, 16 vCPU, RTX 3080, driver 610.88 (`/usr/lib/wsl/lib/nvidia-smi`) |
| GPU stack | Mesa 25.2.8 (D3D12 gallium, `/usr/lib/wsl/lib/libd3d12core.so`, `/dev/dxg`); no `/dev/dri` dmabuf path for EGL |
| GStreamer | 1.24.2 (base, good, bad, gl, libav); NVENC `nvautogpuh264enc` (`nvh264enc` still broken) |
| gst-wayland-display | `games-on-whales/gst-wayland-display` commit `016b4fc66d62b6a34c37169ecf6d511eef140d7c` (Sept 7, 2026), gstreamer-rs 0.23.2 / `v1_24`; built with `cargo build --release`, installed as `/usr/local/lib/gstreamer-1.0/libgstwaylanddisplaysrc.so` |
| libwayland | 1.24.0, built from source (`--prefix=/opt/wayland124`) for the plugin's `wl_client_set_max_buffer_size`; the distro's own is 1.22.0-2.1build1 |
| Rust | rustc 1.99.1 (2026-10-13), cargo from rustup in the distro |
| gst-plugins-rs | 0.13.6 source at `/work/gst-plugins-rs`, `libgstrswebrtc.so` + `gst-webrtc-signalling-server` (release builds) |
| Flutter / Dart | 3.47.8 / 3.13.7 at `/opt/flutter`; app bundle `tv_test_app/build/linux/x64/profile/bundle` from the previous probe's copy at `/work/flash-20261111-141312-1826` |
| Audio | PulseAudio (Ubuntu 24.04), system mode, `module-null-sink sink_name=party`, ALSA `pcm.!default` routed to pulse |
| Docker | Engine 29.9.3, images `tp-test:latest` 1.16 GB, `tpapp-img:latest` 1.3 GB, `ubuntu:24.04` 119 MB |

## 3. Step by step (commands and key output)

Linux commands ran as `wsl -d tp-stream -u root -- bash -lc '<cmd>'` or, when quoting got hairy, a script fed with `wsl -d tp-stream -u root -- bash -s << 'OUTER' ... OUTER`. Long jobs were wrapped in `timeout`. Nothing outside `allow:` was touched and nothing was installed on Windows.

### 3.1 Build the compositor plugin

```
git clone https://github.com/games-on-whales/gst-wayland-display /work/gst-wayland-display
cd /work/gst-wayland-display && git worktree add /work/gwd-124 016b4fc
cd /work/gwd-124 && cargo build --release -p gst-plugin-wayland-display     # ~10 min
cp target/release/libgstwaylanddisplaysrc.so /usr/local/lib/gstreamer-1.0/
GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0 gst-inspect-1.0 waylanddisplaysrc
```

The head of the repository was tried first and refused: its `gstreamer-vulkan` dependency asks for the `v1_28` gstreamer-rs feature, i.e. **GStreamer 1.28**, and this distro has 1.24.2. Commit `016b4fc` is the last one on the 0.23.2 / `v1_24` line.

First `gst-inspect-1.0` failed to load the library:

```
(gst-inspect-1.0:...): GStreamer-WARNING **: Failed to load plugin '.../libgstwaylanddisplaysrc.so':
  .../libgstwaylanddisplaysrc.so: undefined symbol: wl_client_set_max_buffer_size
```

That symbol is newer than the distro's libwayland (`libwayland-client0 1.22.0-2.1build1`, which does not export it). Fixed by building wayland 1.24.0 into `/opt/wayland124` (`meson setup build --prefix=/opt/wayland124 -Ddocumentation=false && ninja -C build install`) and exporting `LD_LIBRARY_PATH=/opt/wayland124/lib/x86_64-linux-gnu` wherever the plugin loads.

Second failure: after the copy, `gst-inspect-1.0 waylanddisplaysrc` printed `No such element or plugin 'waylanddisplaysrc'` — a stale GStreamer registry from the earlier failed load. Fixed with `GST_REGISTRY=/tmp/reg.bin`, `rm -f` before re-inspecting.

### 3.2 Make the compositor run on WSL's EGL

With the default render node the source panicked before creating a socket:

```
panicked at ...: Unable to find EGLDevice for drm-node: /dev/dri/renderD128
```

[`patch-renderer-mod.rs`](capture-probe/patch-renderer-mod.rs) kept in the artefact folder is the diagnostic patch that logged what WSL actually exposes:

```
EGL device seen: has render node = false, extension count = 2
no EGL device for this render node; using the software device
```

The patch was only a probe: upstream already has the switch we needed, `render-node=software` (any other value is taken as a DRM node path). The installed library was rebuilt from the pristine source (`git checkout -- wayland-display-core/src/utils/renderer/mod.rs`) and every measurement below uses `render-node=software`.

The compositor's own log then says what this WSL2 can and cannot give it ([full excerpt](capture-probe/session-log-excerpt.txt)):

```
Supported DMA formats: []
Failed to initialize EGL hardware-acceleration err=EglExtensionNotSupported(["EGL_WL_bind_wayland_display"])
Listening on wayland socket. socket_name="wayland-1"
WARN  Error during GetRenderDevice: No such file or directory (os error 2)
```

So: no dmabuf, no EGL-Wayland binding, `video/x-raw` (shm) only, and the compositor acquires frames as CPU copies. The socket name is chosen by the plugin (`wayland-1`), and it must be read back from the log.

### 3.3 Start the game as its client

The app is started as any Wayland client; the compositor is the pipeline:

```
export XDG_RUNTIME_DIR=/tmp/xdgw; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
gst-launch-1.0 -e waylanddisplaysrc render-node=software ! 'video/x-raw,width=1920,height=1080,framerate=60/1' \
  ! videoconvert ! nvautogpuh264enc ! h264parse ! queue ! mux. \
  pulsesrc device=party.monitor ! queue ! audioconvert ! audioresample ! opusenc ! queue ! mux. \
  matroskamux name=mux ! filesink location=/work/out/measure2.mkv &
WAYLAND_DISPLAY=wayland-1 GDK_BACKEND=wayland ./tvtest
```

The app's own log only names the backend (`Using the Impeller rendering backend (OpenGLESSDF)`); the GL renderer string `GL renderer: D3D12 (NVIDIA GeForce RTX 3080)` was read from the same binary under weston in the previous probe, and `nvidia-smi` showing GPU use while it drew (§3.4) confirms the game is still on the D3D12 path, not llvmpipe.

Two things bite here:

- Without `XDG_RUNTIME_DIR` (or with a directory that is not mode 700) the source panics in `ListeningSocketSource::new_auto().unwrap()` with `PermissionDenied`.
- Quote the caps inside the pipeline string. Unquoted, `gst-launch-1.0` reads `no element "video"`, and `video/x-raw(memory:GLMemory)` gives `bash: syntax error near unexpected token '('`.

The game shows its waiting card and draws nothing:

```
FRAME_STATS fps=0.0 frames=0 (nothing drawn)
```

The round has to be started by the repository's simulated controller, which needs the pairing code the app prints:

```
grep -a -o 'code=[0-9]*' /work/gwd-app3.log          -> code=5323
cd /work/flash-20261111-141312-1826/packages/connection
/opt/flutter/bin/dart run connection:sim_controller --host 127.0.0.1 --port 45780 \
  --code 5323 --name Probe --demo --seconds 40
```

`dart` is not on `PATH` in a non-login shell; the full path to `/opt/flutter/bin/dart` is needed.

### 3.4 The 30-second+ measurement

Same command as §3.3, 42.4 s of file, sampled every 2 s with `nvidia-smi --query-gpu=utilization.gpu,utilization.encoder --format=csv,noheader` and `top -b -n 1`:

```
nvidia 45 %, 11 %  tvtest=100.0%
nvidia 47 %, 11 %  tvtest= 80.0%
nvidia 45 %, 11 %  tvtest=110.0%
...
FRAME_STATS fps=31.0 frames=155
FRAME_STATS fps=55.0 frames=275 buildAvgMs=0.98 rasterAvgMs=8.11
FRAME_STATS fps=59.2 frames=296 buildAvgMs=0.90 rasterAvgMs=7.01
FRAME_STATS fps=59.4 frames=297 buildAvgMs=0.92 rasterAvgMs=7.92
FRAME_STATS fps=59.6 frames=298 buildAvgMs=0.95 rasterAvgMs=7.49
```

The encoded side, from the file itself: 2530 video packets over 42.38 s, and per-second counts of exactly 60 for seconds 1–41 (48 in the first, 22 in the last). **60.0 fps, no dropped frame in the encode.** No separate `fpsdisplaysink` was used, so "dropped" is measured as packets per second of PTS.

Latency, `GST_TRACERS=latency GST_DEBUG=GST_TRACER:7` over a 20 s run (1032 records, source → `fakesink`):

```
mean=7.99 ms  p50=7.64 ms  p95=9.32 ms  max=213.13 ms   (max = first buffer)
```

A steady-state add of ~8 ms from the frame leaving the compositor to the encoded frame; on top of that, the compositor paints the app's previous frame, and the app's own raster time is 7–8 ms (`rasterAvgMs`), so a press-to-picture estimate is one 60 Hz frame plus ~8 ms of pipeline plus the app's own draw.

The 5 s clip and the screenshot are in `capture-probe/`: `capture-screenshot.png` (1920×1080, the Arena with Round 1 at 8.9 s, P1 Probe/Robo) and `capture-clip-5s.mp4` (882 KB, 301 frames / 5.02 s).

### 3.5 Sound

PulseAudio in system mode with only a null sink, and ALSA pointed at it (`/etc/asound.conf`: `pcm.!default { type pulse }`), because miniaudio goes through ALSA:

```
mkdir -p /tmp/pulse && chmod 777 /tmp/pulse
pulseaudio --system --daemonize=yes --disallow-exit --exit-idle-time=-1 -n \
  --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse/native" \
  --load="module-null-sink sink_name=party sink_properties=device.description=Party" \
  --load="module-always-sink"
export PULSE_SERVER=unix:/tmp/pulse/native
```

The first container attempt failed with `Failed to connect: Connection refused` until `/tmp/pulse` existed and was world-writable (the system-mode daemon drops to the `pulse` user).

With the sink up, the app logs `miniaudio: Linux audio backend set to Auto (ALSA -> PulseAudio -> JACK)` / `miniaudio_init: audio device initialized using Linux backend: ALSA`, there is no `SoLoudBackendNotInitializedException`, and the monitor carries real game audio into the same file: `matroskamux` holds `h264` + `opus` (48 kHz, mono), `volumedetect mean_volume: -30.8 dB max_volume: -8.6 dB`. The excerpt with sound is `capture-clip-5s-with-sound.mp4` (560 KB, h264 + aac, 5.03 s).

### 3.6 Two sessions at once

Two containers from the same image, each with its own `XDG_RUNTIME_DIR`, its own `waylanddisplaysrc` compositor, its own PulseAudio null sink and its own output file, published on different host ports (`-p 45881:45780`, `-p 45891:45780`) and driven by two simulated controllers. Both ran 77 s at 1080p60. Per-second encoded frames, from the two saved files:

| Second | session 1 | session 2 |
| --- | --- | --- |
| 1–12 (menu / waiting card) | 56–59 | 56–59 |
| 13–24 (rounds starting) | 59–60 | 58–60 |
| 26–77 (both rounds running) | 40–48, mostly 43–45 | 40–47, mostly 43–45 |

Totals: `session1.mkv` 3737 frames / 77.72 s, `session2.mkv` 3744 frames / 77.79 s. Live sampling during the last 30 s: GPU 75–78 %, encoder 24–42 %, 3.26 GB VRAM in use, about 190 % CPU per container, app `FRAME_STATS` 28–31 fps in both containers. Audio is in both files and not silent (mean −31.9 / −32.0 dB, max −8.5 / −8.6 dB).

So two households at 1080p60 on this GPU do not both get 60: the encode falls to ~45 fps each once both games are drawing. Neither GPU (75–78 %) nor the encoder (24–42 %) is saturated, so the limit is elsewhere — most likely the single-threaded-per-session compositor and the shm copies — but this run did not isolate which resource it is.

### 3.7 webrtcsink (stretch)

`apt` has no `gstreamer1.0-plugins-rs` for 1.24 with webrtc, so gst-plugins-rs 0.13.6 was built (`cargo build --release -p gst-plugin-webrtc`, ~10 min, source kept at `/work/gst-plugins-rs` 3.5 GB). `GST_PLUGIN_PATH` pointing at `target/release` gives:

```
gst-inspect-1.0 webrtcsink      -> exists (gst-plugins-rs 0.13.6)
```

Two things about it that are not obvious:

- `webrtcsink` wants compressed video, not RTP. With `... ! rtph264pay ! webrtcsink` the pipeline does not even build: `WARNING: erroneous pipeline: could not link rtph264pay0 to ws, ws can't handle caps application/x-rtp, media=(string)video, encoding-name=(string)H264, payload=(int)96`. Feed it `h264parse ! webrtcsink`.
- **The element has no built-in signalling server.** With no signaller the pipeline fails at PLAYING: `Signalling error: Error receiving: IO error: Connection refused (os error 111)`.

The server is a separate binary from the same crate set. Running it (`/work/gst-plugins-rs/target/release/gst-webrtc-signalling-server`, defaults to port 8443) and pointing the element at it works:

```
gst-webrtc-signalling-server            -> INFO Listening on: 0.0.0.0:8443
gst-launch-1.0 ... ! nvautogpuh264enc ! h264parse ! \
  webrtcsink signaller::uri="ws://127.0.0.1:8443"     -> Setting pipeline to PLAYING
server log: Accepting connection from 127.0.0.1:54890 / registered as a producer peer_id=42b83de4-...
```

No web client was built (out of scope per the brief).

### 3.8 Tidy

Containers and their processes are stopped and removed (`docker ps -a` empty, `docker system df`: Containers 0 B, Images 1.307 GB). In the distro no `tvtest`, `gst-launch-1.0`, `pulseaudio` or signalling server is left running. Installs kept:

| What | Where | Size |
| --- | --- | --- |
| gst-wayland-display source + release build | `/work/gwd-124` (worktree of `/work/gst-wayland-display`) | 712 MB |
| installed plugin | `/usr/local/lib/gstreamer-1.0/libgstwaylanddisplaysrc.so` | 356 MB in that folder (includes gst-plugins-rs) |
| libwayland 1.24.0 | `/opt/wayland124` (+ `/work/wayland-src`) | 1.1 MB |
| gst-plugins-rs 0.13.6 source + builds | `/work/gst-plugins-rs` | 3.5 GB |
| recordings, screenshots, logs | `/work/out`, `/work/gwd-*.log` | 230 MB |
| everything under `/work` | | 13 GB |

Root filesystem: 24 GB used of 1007 GB.

## 4. The winning recipe (copy-paste)

### 4.1 The pipeline

```
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export LD_LIBRARY_PATH=/opt/wayland124/lib/x86_64-linux-gnu:/usr/lib/wsl/lib
export GST_PLUGIN_PATH=/usr/local/lib/gstreamer-1.0
export GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA
export PULSE_SERVER=unix:/tmp/pulse/native

gst-launch-1.0 -e \
  waylanddisplaysrc render-node=software ! 'video/x-raw,width=1920,height=1080,framerate=60/1' ! videoconvert \
  ! nvautogpuh264enc ! h264parse ! queue ! mux. \
  pulsesrc device=party.monitor ! queue ! audioconvert ! audioresample ! opusenc ! queue ! mux. \
  matroskamux name=mux ! filesink location=/out/session1.mkv
```

Then `WAYLAND_DISPLAY=<socket from the log> GDK_BACKEND=wayland ./tvtest`. Each session needs its own `XDG_RUNTIME_DIR` (the socket is `wayland-1` under whatever that variable names), its own `GST_REGISTRY` if the plugin path differs, and its own Pulse sink.

### 4.2 The container command

```
docker run -d --name party1 --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg \
  -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  -e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA \
  -p 45881:45780 -v /work/out:/out party1-img
```

Notes from the run:

- There is no `/dev/dri` in the container, so `render-node=software` is not optional: without it the source fails with `Failed to open drm node , if you want to utilize software rendering set 'render-node=software'`.
- `/usr/lib/wsl/lib` must be mounted and on `LD_LIBRARY_PATH` for the D3D12 driver; `--gpus all` alone is not enough in this WSL2.
- The plugin and libwayland are copied into the image (or bind-mounted): the base image has GStreamer 1.24 and the NVENC elements but not the compositor.
- [`capture-probe/container-session.sh`](capture-probe/container-session.sh) is the exact per-container session script: `XDG_RUNTIME_DIR`, Pulse null sink, pipeline to `/out/session$n.mkv`, wait for the socket, start `./tvtest`, print the pairing code.

### 4.3 Dockerfile sketch

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
      gstreamer1.0-plugins-bad gstreamer1.0-libav pulseaudio alsa-utils \
      libgtk-3-0t64 libasound2t64 libpulse0 && rm -rf /var/lib/apt/lists/*
COPY wayland124 /opt/wayland124
COPY gstreamer-1.0/libgstwaylanddisplaysrc.so /usr/local/lib/gstreamer-1.0/
COPY session.sh /session.sh
COPY bundle /app
ENTRYPOINT ["/session.sh"]
```

(`wayland124` and the plugin `.so` are taken from the distro build; `bundle` is `tv_test_app/build/linux/x64/profile/bundle`.)

## 5. What failed and why

- **The head of gst-wayland-display does not build against GStreamer 1.24.** Its `gstreamer-vulkan` crate needs the `v1_28` feature. Use `016b4fc` (or a newer GStreamer) — recorded so the next person does not lose the 10 minutes.
- **The plugin loads only with libwayland 1.24 present** (`undefined symbol: wl_client_set_max_buffer_size`), so a container image must carry it too.
- **The default render node cannot work here.** WSL's EGL has one device, no DRM render node, no dmabuf. `render-node=software` is the supported switch; it is not a fallback to llvmpipe — the app still draws on the RTX 3080 through D3D12, only the compositor's import path is software.
- **No zero-copy.** `Supported DMA formats: []` and `Dmabuf import extension not available`; every frame is copied through system memory and through `videoconvert` (RGBx → NV12) before NVENC. That costs CPU and adds latency, and it is why GPU use during capture (45–47 %) is all game drawing.
- **The encode rate is the compositor's, not the app's.** `waylanddisplaysrc` produces 60 fps even when the app drew 55; a viewer sees repeated frames, not a 60 fps game.
- **Two sessions drop to ~45 fps each** once both games are running. NVENC is not the limit (12 sessions allowed, 2 used, encoder 24–42 %); the CPU-side path (two compositors, shm copies, `videoconvert`) is the likely one, but this run did not isolate it.
- **`nvautogpuh264enc` ignored `bitrate`.** The file is 68.5 MB for 34.8 s (~15.7 Mbit/s) whatever value was passed; the property needs `preset`/`bitrate` verified, or `nvcudah264enc`, before this is a real streaming setting.
- **PulseAudio's system mode needs its socket directory to exist and be writable** (`Failed to connect: Connection refused` otherwise), and the monitor is mono 48 kHz — fine for the game, worth setting explicitly for a mixed stream.
- **`webrtcsink` needs a separate signalling server process** and compressed input; both were surprises worth writing down (the design doc's stretch step assumed it was self-contained).

## 6. What to try next

1. **Run this exact recipe as the streaming server's session process in a container, and add `webrtcsink` in place of `filesink`** — that is the whole design in one pipeline now. The signalling server is a second container (or a process in the same one) and the browser side is still unbuilt.
2. **Cap the encode rate instead of fighting for 60 with two sessions**: `videorate max-rate=45` or `nvautogpuh264enc` with a pinned bitrate/preset gives a predictable 45 fps at 1080p for two households, and 60 for one.
3. **Measure what the software import costs**: compare this pipeline with the same one on a real Linux + NVIDIA machine (dmabuf path). If the ~8 ms and the CPU copies matter, the design's "virtual screen" is better served by a GPU that can export dmabuf.
4. **Check `nvcudah264enc`** (CUDA upload) as a cheaper path from shm to NVENC than `videoconvert`, and pin `bitrate`/`preset`/`rc-mode`.
5. **The sound chain is proven but mono**: opus stereo needs a stereo sink (`module-null-sink channels=2`) and the app's own mix; `miniaudio` reported ALSA, which here means "through `/etc/asound.conf` to pulse".

## 7. Decisions

- **Stopped at path A1** once it held 60 fps, as the brief orders; A2–A4 are listed as skipped with the previous probe's evidence rather than re-run.
- **Used `render-node=software` instead of shipping the diagnostic patch.** Upstream's switch is the supported answer; the patch file is kept only as evidence of what WSL exposes.
- **Built against GStreamer 1.24 via commit `016b4fc`** rather than upgrading the distro's GStreamer to 1.28 (a much bigger change for a probe).
- **Built gst-plugins-rs 0.13.6 for `webrtcsink`** because no apt package exists for the 1.24 line; kept the source so the signalling server can be reused.
- **Ran containers with the plugin copied in** rather than baking a new image per attempt, to keep the probe inside its time-box; §4.3 is the sketch of the image that should exist.
- **Measured the encoded rate from the saved files** (packets per second of PTS) rather than with `fpsdisplaysink`, so the numbers in §3.4 and §3.6 can be re-derived from files that stay in `/work/out`.
- **Two-session GPU/encoder/CPU numbers were sampled live** with `nvidia-smi` and `top`; the containers were removed in the tidy, so those particular lines are not on disk (the two `.mkv` files are).

## 8. Self-check (review-rules.md part A)

1. **Every host setup** — not affected: no code in the repository changed; the probe used the TV app's existing profile bundle on the TV/host path only.
2. **When kept state starts and ends** — not affected: nothing held, timed or counted was added to shipped code; the scripts in the distro start and stop their own compositor/sink.
3. **How a new state combines with the others** — not affected: no pause, wait or input state was touched; the simulated controller drives the same paths as before.
4. **Stay in the job's folder** — done: only `docs/briefs/m15/capture-probe-report.md` and `docs/briefs/m15/capture-probe/` were written in the repository; everything else is under `/work`/`/opt` in the distro.
5. **Stop rather than overstep** — nothing outside `allow:` was needed. The one thing worth a decision is not mine to take: whether the streaming server ships the gst-wayland-display plugin (hand-built, GStreamer-1.24-pinned) or waits for a GStreamer 1.28 base image; it is raised in §6, not acted on.

## Commit message

```
m15 probe: 1080p60 capture with sound out of the headless GPU game

docs/briefs/m15/capture-probe-report.md records the first capture path
that worked: gst-wayland-display's waylanddisplaysrc (pinned build) as a
GStreamer compositor, the TV app as its Wayland client, render-node=software
because WSL's EGL has no DRM node or dmabuf, and NVENC encoding 60.0 fps for
42 s with the Arena running at 59 fps (GPU 45-47 %, encoder 11-12 %, ~8 ms
latency). Sound comes from a Pulse null sink into the same file. Two
containers at once fall to ~45 fps each. Screenshot, two 5 s clips and the
logs are in docs/briefs/m15/capture-probe/.
```

## Status row

M15 capture probe: done — gst-wayland-display's `waylanddisplaysrc` is the capture path (plugin `016b4fc` built against GStreamer 1.24.2 with libwayland 1.24, `render-node=software`, shm frames only), the real Arena drew 55–59.6 fps at 1080p in the distro (the same recipe ran in a GPU container with the same audio) and the pipeline encoded a clean 60.0 fps for 42 s with opus audio in the same file (non-silent, mean −30.8 dB), at 45–47 % GPU, 11–12 % encoder and ~8 ms added latency; two sessions at 1080p60 fall to ~43–45 fps each (GPU 75–78 %, encoder 24–42 %); `webrtcsink` + its signalling server work; open: two-household 60 fps, the encoder `bitrate` property, and a real Dockerfile/image for the plugin.

## Delete

- none
