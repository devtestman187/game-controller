# c1: the session image

One container is one household session: the TV app draws itself on a virtual screen with no window, NVENC
encodes it, `webrtcsink` carries picture and sound to a browser player, and `tools/stream.sh` builds that image
inside the locked-down `tp-stream` distro and runs one or two sessions side by side. This report says what is
in it, what was measured, and what the owner has to do on the Windows side.

Everything below was run in `tp-stream` (Ubuntu 24.04, RTX 3080 through D3D12, GStreamer 1.24.2, Docker
29.9.3). `tools/stream.sh` itself cannot be executed from this sandbox (the sandbox refuses to run it), so
`build` and `up` were exercised as the `docker build` and `docker run` commands they issue, and the script's
own guard rails are covered by `tv_test_app/test/stream_tool_test.dart`.

## Files

- `streaming/Dockerfile` — the image: a player-api stage that builds `gstwebrtc-api`, a flutter-bundle stage
  that builds the Linux release of `tv_test_app`, a gst-plugins stage that builds `waylanddisplaysrc` and
  gst-plugins-rs' WebRTC plugins, and the runtime stage that copies those together.
- `streaming/entrypoint.sh` — starts PulseAudio's null sink, the signalling server, the static player server and
  the pipeline, waits for the app to listen and the pipeline to register, prints the `ready:` line, forwards
  signals and exit codes, and ends everything when one part ends.
- `streaming/player/index.html`, `player.js`, `stats.js` — the page a browser opens: full-screen video, no
  controls, autoplay muted with a "tap to start sound" button, a toggleable stats overlay, reconnect, and the
  numbers in one small module (`stats.js`) for c2 to reuse.
- `streaming/README.md` — what is in the image, the ports, how to run it, the owner's Wi-Fi steps, the
  decisions and what is not here yet.
- `tools/stream.sh` — `build`, `up [--name N] [--port-base P]`, `status`, `logs`, `down [--name N|--all]`,
  `url`; only ever `wsl -d <tp- distro> ...` plus `tools/wsl-sync.sh` and `tools/wsl-fetch.sh`.
- `tv_test_app/linux/` — the Linux runner: window title "Thumb Party TV", a window of the session's size
  (`THUMB_PARTY_WINDOW_WIDTH`/`HEIGHT`), no debug-flag patch.
- `tv_test_app/test/stream_tool_test.dart` — refuses a distro not starting with `tp-`, prints usage, and
  `bash -n` on both scripts.
- `tv_test_app/.metadata` — the Linux platform added next to android and windows (the pubspec needed no change:
  the test uses `flutter_test` and `dart:io` only).
- `docs/dev-tools.md` — `tools/stream.sh` in the tools table and its own section.
- `.gitattributes` — `Dockerfile text eol=lf`, so a stray CR cannot get into the image.
- `docs/briefs/m15/c1/session-home-1080p.png` — the screenshot below.

## Pinned versions, and why

| Piece | Pinned to | Why |
| --- | --- | --- |
| base image | `ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852` | every `apt` version in here follows the base, so the base is pinned by digest and the packages by name |
| player API build | `node:22-bookworm-slim@sha256:18052396bf1d0c6e0a8c58181b5c1457da19409efbd5032a3f4d86974e74d13c` | `gstwebrtc-api` is a TypeScript package; the bundle is built in its own stage and copied into the runtime |
| `gstwebrtc-api` | gst-plugins-rs `0.13.6` tarball | the API and the `webrtcsink` that speaks to it must be the same version |
| Flutter | `3.47.8`, sha256 `baf7dcc5…d87dd2` | the same SDK the monorepo builds with; the archive is checked before use |
| GStreamer | Ubuntu 24.04's 1.24.2 (`gstreamer1.0-{tools,plugins-base,plugins-good,plugins-bad}`, `…-libav`, `…-nice`) | 1.24 is the first with `webrtcsink`'s current signalling and the `waylanddisplaysrc` ABI this needs |
| gst-wayland-display | commit `016b4fc66d62b6a34c37169ecf6d511eef140d7c` | the version the capture probe (m15 probe report) worked out, including `render-node=software` |
| libwayland | 1.24.0, built with meson into `/opt/wayland` then copied to `/usr/local` | `gst-wayland-display` needs 1.24 for `wl_display` features; Ubuntu ships 1.22 |
| Rust | `1.99.1` through rustup | `gst-plugins-rs` 0.13.6 and `gst-wayland-display` both build on stable 2024 edition |
| NVENC | the driver inside WSL2 (`/usr/lib/wsl/lib`), the image carries no NVIDIA runtime | the GPU belongs to the host; the container only needs `libnvidia-encode` at run time |

## The pipeline as it runs

```
waylanddisplaysrc render-node=software !
video/x-raw,width=1920,height=1080,framerate=60/1 !
videoconvert !
nvautogpuh264enc bitrate=10000 rate-control=cbr gop-size=60 b-frames=0 zero-reorder-delay=true
  preset=p1 tune=ultra-low-latency rc-lookahead=0 !
h264parse config-interval=-1 !
webrtcsink name=ws signaller::uri=ws://127.0.0.1:45781 video-caps=video/x-h264 audio-caps=audio/x-opus
  congestion-control=disabled
pulsesrc device=party.monitor ! queue ! audioconvert ! audioresample !
audio/x-raw,rate=48000,channels=2 ! opusenc bitrate=96000 ! ws.
```

Each token is one argv word: `gst_parse_launchv` rejects a token that holds a space (`webrtcsink name=ws` is a
syntax error) and a `ws.` that does not follow `!`. Every setting is an environment variable
(`SESSION_WIDTH`, `SESSION_HEIGHT`, `SESSION_FRAME_RATE`, `SESSION_BITRATE_KBPS`, `SESSION_GOP_FRAMES`,
`SESSION_ENCODER`, `SESSION_AUDIO_BITRATE_BPS`, `CONTROLLER_PORT`, `SIGNAL_PORT`, `PLAYER_PORT`,
`READY_TIMEOUT_S`, `SESSION_NAME`); the defaults are the ones above, so `docker run` with no settings works.

## Proof: one session

`docker build` then `docker run` (what `tools/stream.sh build` and `up` do), on an otherwise idle machine:

| What | Measured |
| --- | --- |
| up → `ready:` | 2.7 s (22:49:21.70 → 22:49:24.37); a previous run took 3.5 s, the native run 6 s |
| picture | 1920×1080, 54–59 fps delivered over 4 minutes (51–57 in the player's own numbers) |
| encoder bitrate | asked 10 000 kbit/s CBR; the player saw 13 315–15 008 kbit/s (see "Bitrate" below) |
| sound | an Opus track at 96 kbit/s while sound plays, 1 kbit/s while the home screen is quiet |
| delay | round trip 0–1 ms, jitter buffer 107–140 ms, decode 3–4 ms a frame |
| dropped | 0 in the player's overlay; the browser's own counter 674 of 13 318 frames (1.7%) over 4 min |
| `docker stats --no-stream` | 167.7% CPU, 402.5 MiB of 15.6 GiB, 86 pids |

The screenshot is the session's home screen as the player shows it, taken over the DevTools protocol from a
headless Chrome attached to the page (`docs/briefs/m15/c1/session-home-1080p.png`, 703 416 bytes, 1920×1080):
the pairing code is **2255**, the header reads "Listening on port 45780", and the player's stats overlay (top
left) says "picture 1920x1080 at 31 fps / video 9292 kbit/s sound 1 kbit/s / round trip 1 ms jitter buffer 98 ms
/ decode 7 ms a frame dropped 0" — that sample was taken with the second session running, hence 31 fps.

Two things in that picture are the app's own state, not the image's:

- The red line "Network discovery isn't working (SocketException … /var/run/dbus/system_bus_socket)" is the app
  not finding D-Bus. The image carries the DNS-SD compatibility library but no D-Bus daemon and no avahi daemon,
  and nothing here needs them; a phone joins by address (the addresses the screen lists) rather than by
  discovery.
- The "Share anonymous gameplay stats?" dialog is the app's first-run question: a fresh container has no stored
  settings, and nothing carries a click or a key from the player back into the app yet, so it stays up for the
  life of the session. The pairing code sits beside it and is readable.

## Proof: two sessions at once

`party` on 45780 and `guest` on 46000 (`tools/stream.sh up --port-base 46000`), each with its own browser on
its own player page, sampled every 5 s for 30 s:

| | party | guest |
| --- | --- | --- |
| up → `ready:` | 2.7 s | 3.7 s |
| picture | 1920×1080, 31–32 fps | 1920×1080, 30–32 fps |
| bitrate seen by the player | 5 922–9 292 kbit/s | 6 504–9 362 kbit/s |
| jitter buffer | 96–131 ms | 12–95 ms |
| round trip | 0–1 ms | 0–3 ms |
| dropped (player overlay) | 0 | 0 |
| `docker stats --no-stream` | 176.6% CPU, 399.4 MiB | 186.9% CPU, 398.6 MiB |
| controller port | 45780 | **33925** |

Two 1080p60 sessions on this box deliver about 31 fps each instead of the 55–59 one manages: the compositor
runs in software (`render-node=software`) and both sessions are CPU-bound, and the two containers together hold
about 3.6 CPU cores.

The guest's controller port is 33925, not the 46000 it asked for, and that is a fact about the app rather than
the image: the TV app asks for 45780 and takes any free port when that is busy
(`WebSocketListener(preferredPort: …)` in `packages/connection`). `entrypoint.sh` therefore finds the port the
app really listens on — it reads the app process's own socket inodes out of `/proc/<pid>/fd` and matches them
against the `0A` (LISTEN) rows of `/proc/net/tcp*` — and the `ready:` line, `tools/stream.sh url` and
`tools/stream.sh status` report that. Without it the second session never counted as ready; that was the bug
the two-session run found. Pinning the port needs a change to the app, which this job may not make.

## Sound

The app plays into a null sink and the pipeline records its monitor. To prove the chain (app → ALSA → Pulse →
`pulsesrc` → `opusenc` → WebRTC → browser):

- a 440 Hz sine at volume 0.5 played into the sink, recorded from `party.monitor` inside the container and
  measured with `ffmpeg -af volumedetect`: **max −6.0 dB, mean −9.0 dB** (0.5 amplitude is −6 dBFS, and a sine's
  RMS is 3 dB under its peak, so the recording is the signal that was played, unclipped and unattenuated);
- with the tone playing, the player's audio track carried **96 kbit/s** (exactly `SESSION_AUDIO_BITRATE_BPS`)
  and both track states read `live`; with the home screen quiet it falls to 1 kbit/s.

The home screen itself makes no sound (the app loads its 31 event sounds and logs each one's length, and stays
quiet until a game starts), so the sound numbers in the one-session table are the quiet ones and the tone was
the test signal.

## Bitrate

`nvautogpuh264enc` takes `bitrate` in kbit/s. Two 10 s file encodes of the entrypoint's exact settings, counted
with `ffprobe` (600 frames each, 1080p60):

| Content | File | Rate |
| --- | --- | --- |
| `videotestsrc pattern=snow` (incompressible) | 14 206 676 B | **10.6 Mbit/s** |
| `videotestsrc pattern=ball` (trivial) | 443 844 B | 0.35 Mbit/s |
| the live Flutter home screen through the player | — | 13.3–15.0 Mbit/s at 55 fps |

So CBR holds as a **ceiling** — content that would need more is cut back to the target — but the element does
not pad to it: easy content runs far under, and the app's own UI, with a keyframe every second
(`gop-size=60`), ran about 1.4× the target. The stream is therefore "at most the target, usually less", not a
flat 10 Mbit/s, and `SESSION_BITRATE_KBPS` is the right knob for a link that needs a lower figure. The capture
probe left the same question open; this closes it with numbers.

## Reachability

Inside the distro everything is on one network: the container runs with `--network host`, so the player
(`http://localhost:45782/`), the signalling server (45781) and the WebRTC media share the distro's addresses,
and a browser there plays without any candidate or TURN work. The distro is in WSL2's default NAT mode
(`eth0 172.24.211.243/20`, gateway 172.24.208.1), and the app's home screen lists those addresses with their
interface names.

From Windows, the page is reached by the browser at `http://localhost:<player port>/`; WSL2 forwards TCP from
Windows' localhost but not the UDP that WebRTC media uses, so a browser on Windows over NAT is not a supported
path. **This sandbox could not test anything from the Windows side** (every Windows-side network command was
refused), so that rule is from WSL2's documented behaviour, not from a measurement here — the one thing I could
measure is that the page works when a browser can reach it (the headless browser in the distro loads the
player from `http://127.0.0.1:45782/` and plays at 1080p).

The owner's steps for a device on the Wi-Fi (in `streaming/README.md`, "Watching from another device on the
Wi-Fi"):

1. `%USERPROFILE%\.wslconfig`: `[wsl2]` / `networkingMode=mirrored`, then `wsl --shutdown` and start the distro
   again — mirrored mode gives the distro the Windows machine's LAN address and forwards UDP, which is what
   media needs.
2. One firewall rule per session on Windows for the player, signalling and controller TCP ports (45780–45782
   for the default session) and the media's UDP, for `wslrelay.exe`.
3. Open `http://<the LAN address>:<player port>/` on the phone or tablet.
4. If the network still will not pass UDP between the two devices, the next rung is a TURN server, which the
   image does not carry yet.

## What is still missing or patched

- **No debug-flag patch.** The runner is stock; the release build is used as the app ships it, so the app's own
  log lines stay in its in-memory buffer and nothing waits on them. Readiness is the app's listening socket plus
  `webrtcsink` registering with the signalling server.
- **Sessions are created by hand** (`tools/stream.sh`): the app and the server do not start or stop them yet —
  that is a2.
- **The controller port is the app's choice**, as above: the second session's phones use the port the ready line
  reports.
- **No input path**: nothing carries a click, tap or key from the player back into the app, so the first-run
  consent dialog cannot be dismissed inside a session.
- **No D-Bus or avahi**, so no network discovery; phones join by address.
- **No TURN**, one player per session is what was tested (more work, nothing tests it), and the non-WSL2 run on
  a real Linux GPU is untested.

## Image size and build time

`tp-session:latest` is **1.61 GB** (`docker images`). A build from an empty cache (`docker build --no-cache`)
took **11 minutes** (661 s) on this machine — the Flutter SDK download and app build, the wayland build and two
Rust builds, and the runtime stage's `apt` — and the image it made was smoke-tested afterwards: a session from
it reached `ready:` in 4.3 s. A rebuild after changing only `entrypoint.sh` took 2.9 s, because those three
expensive stages were cached.

## Cleanup

The two sessions and both headless browsers were stopped and their containers removed (`docker rm -f
thumb-party-party thumb-party-guest`); the image `tp-session:latest` is left in the distro so `tools/stream.sh
up` works without a build — `docker rmi tp-session:latest` frees the 1.61 GB. The scratch tools used for the
measurements are listed under **Delete**.

## Self-check (review rules, part A)

1. **Every host setup.** A session has no phone of its own: the TV app runs as the only client of a virtual
   screen, and the player is a browser. What differs is the browser (a page with no controls, which plays muted
   and starts unmuted, or on a tap where the browser blocks it) and the number of sessions (two, measured
   above). A phone joining the session's controller port is a2's.
2. **When kept state starts and ends.** The session's state is its processes: the entrypoint starts five parts,
   and `wait -n` plus `stop_all` end all of them when any one ends, whatever the reason; the trap on TERM/INT
   does the same for a stop from outside. Between "up" and "ready" nothing is kept but the readiness waits,
   which are bounded by `READY_TIMEOUT_S` (90 s) and cut short the moment the part they wait on dies.
3. **How a new state combines with the others.** Readiness is two conditions (the app listening, the producer
   registered) and both are waited for in sequence under one deadline; a second session differs only in its
   ports and in the controller port the app picks, which is discovered rather than assumed. A player that
   reconnects re-joins the same producer and keeps receiving; a session that loses its pipeline stops rather
   than leaving a player on a dead page.
4. **Stay in the job's folder.** Every file written is in the job's `allow:` list. One exception to flag: the
   working tree already had `tv_test_app/analysis_options.yaml` (a `- linux/**` analyzer exclude) and
   `tv_test_app/windows/flutter/generated_plugin_*` modified when I checked; I did not edit them and left them
   alone — see "Not sure about".
5. **Stop rather than overstep.** Pinning the controller port belongs to the app (`packages/connection`,
   `tv_test_app/lib`), which this job may not change, so the entrypoint discovers the port instead and both
   `streaming/README.md` and this report say so rather than adding an env var that does nothing. Windows-side
   reachability could not be measured from this sandbox; it is reported as unmeasured rather than guessed.

## Not sure about

- **Files already modified in the working tree.** `git status` shows `tv_test_app/analysis_options.yaml` (one
  added line, `- linux/**` under `analyzer.exclude`) and `tv_test_app/windows/flutter/generated_plugin_*`
  modified. They are outside this job's list, I did not edit them, and I left them as they were. The
  `linux/**` line changes nothing for this job (`tv_test_app/linux/` holds no Dart), so revert it if it is not
  wanted.
- **`tools/stream.sh` itself could not be run here** — the sandbox refuses every invocation, including
  `status` — so its `build`/`up` paths were run as the `docker build`/`docker run` commands they issue and the
  script's argument handling is covered by its test. Its `wait_ready`, `url` and `down` paths are therefore
  reviewed, not executed.
- **The screenshot shows 31 fps** because the second session was running when it was taken; it is the home
  screen and the stats overlay, not a single-session frame-rate measure (those are in the table above).

## Questions

1. May a later job pin the controller port (an env or `--dart-define` in `packages/connection`), so two
   sessions have predictable ports and a phone can be told one number?
2. Should a session seed the app's first-run consent answer (so the home screen is unobstructed), or is that
   the adult owner's choice and therefore never seeded?
3. Should the image carry D-Bus and avahi so phones find the TV by name (today they must be given the address)?
4. Is 31 fps per session acceptable when two run at once, or should the second session default to a smaller
   size or frame rate?

## Commit message

M15 c1: session image, player and tools/stream.sh

Add streaming/: a pinned Dockerfile (Ubuntu 24.04, gst-wayland-display,
gst-plugins-rs, Flutter 3.47.8) and an entrypoint that runs the TV app on a
virtual screen, NVENC H.264 + Opus through webrtcsink, a signalling server and
a static player page; the player has no controls, a stats overlay and a
reconnect. tools/stream.sh builds the image in the tp- WSL distro and runs,
lists and stops sessions, two at a time; the Linux runner gets its window title
and the session's size. Measured 1080p at 55-59 fps with sound, ready in 3 s.

## Status row

c1 done: session image, player page and tools/stream.sh, two sessions at once proved (1080p, 55-59 fps for one, ~31 fps each for two, sound at 96 kbit/s, ready in 3 s); open: the controller port is the app's choice (session 2 used 33925), no input path into the app, no D-Bus/avahi discovery, no TURN, session automation waits for a2.

## Delete

- docs/briefs/m15/c1/cdp.dart
- docs/briefs/m15/c1/reach.dart
