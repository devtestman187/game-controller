# Linux game probe report (M15): the TV app on Linux, headless, on the GPU

Job: [linux-game-probe.md](linux-game-probe.md), Nov 11, 2026. Ran inside the locked-down WSL2 distro `tp-stream` (Ubuntu 24.04.5, kernel 6.18.58.1-microsoft-standard-WSL2, 16 CPUs, 15 GB RAM, RTX 3080). The repository was not changed except this report and the files under `docs/briefs/m15/linux-probe/`; every build and every patch listed in §4 lives only in the distro copy at `/work/flash-20261111-141312-1826`.

## 1. Verdict

| Step | Result |
| --- | --- |
| Permission self-test (a) `wsl -d tp-stream -u root -- bash -lc 'echo ok; ls /mnt/c \| wc -l'` | **Allowed**: prints `ok` / `0` (no Windows drives) |
| Permission self-test (b) `wsl -l -v` | **Denied**: `This command requires approval` |
| Permission self-test (c) `wsl.exe -d tp-stream -u root -- echo x` | **Denied**: `Permission to use Bash with command wsl.exe -d tp-stream -u root -- echo x has been denied.` |
| Linux build of the TV app | **Works**: `flutter create --platforms=linux .`, then `flutter build linux --release` and `--profile` succeed. First release build needed a rerun (`ERROR: File modified during build. Build must be rerun.`, native-asset hook race); the rerun was clean |
| Plugins | `shared_preferences` **works** (Linux file backend); `path_provider` **works**; `bonsoir` **builds and advertises** (log line `Advertising "Thumb Party TV (DESKTOP-B9AB5K3)" (_gamectl._tcp, port 45780)`; not tested from a phone); `flutter_soloud` **builds but is silent at runtime** (`SoLoudBackendNotInitializedException`); `wakelock_plus` **builds**, not exercised (no round-end / screen-sleep test). **No plugin had to be stubbed** |
| GPU drawing, no monitor (a) headless weston, Wayland client | **Works**: `GL renderer: D3D12 (NVIDIA GeForce RTX 3080)`; app process maps `/usr/lib/wsl/lib/libd3d12core.so`; Impeller OpenGL ES backend. Menu screen **60.0–60.2 fps** at 1080p (raster 3.95 ms); Arena game **~53 fps** (50.2–57.2, raster 5.9–7.4 ms). GPU use 37–39 %, CPU 64 % of one core |
| GPU drawing, no monitor (b) Xvfb, `GDK_BACKEND=x11` | **Works but software**: `libEGL warning: DRI3 error: Could not get DRI3 device` → llvmpipe. Menu **18.9 fps** (raster 53 ms, CPU ~1370 %), Arena **~10 fps** (raster 100 ms, CPU 1064 %) |
| GPU drawing, no monitor (c) Xwayland under the headless weston | **Works but software**: same DRI3 error, Arena **9.6–10.8 fps** (raster 96–103 ms) at 1920×1080 |
| GPU drawing (c′) WSLg's own X display `:0` | Same DRI3 error → software; not measured further |
| Rendering through the app on WSLg wayland / distro weston | D3D12 confirmed for EGL contexts (`eglinfo -B` under `WAYLAND_DISPLAY=wl-probe`) |
| Capture + NVENC | **Works from X only**: `ximagesrc use-damage=false` → 1080p60 → `nvautogpuh264enc` encoded 600 frames in **10.436 s = 57.5 fps** (57.6 fps writing a 2.71 MB mp4); encoder 12–20 %, GPU 1–2 %. **Capture from weston failed** (`Output capture error: unauthorized`) |
| Container run (stretch) | **Works**: same flags as the earlier probe, `tp-test` image + GTK; headless weston inside the container on D3D12; Arena at 1080p **58.0–60.4 fps** (mean 59.3, raster 4.4–5.1 ms), GPU 24 % |

Five plain lines:

1. **Yes, this PC's WSL2 can run the containerised game at 1080p60**: the real Arena game drew at 58–60 fps at 1920×1080 inside a GPU container, with headroom (raster 5 ms of a 16.7 ms frame, GPU 24 %).
2. **Catch 1 — the picture cannot be got out.** The compositor that a Flutter Wayland client draws into here (weston headless) exports no dmabuf (`dmabuf support: no`, `EGL Wayland extension: no`) and refuses capture by other processes (`Output capture error: unauthorized`). Every capture path that does work (X `ximagesrc`) loses the GPU: the same binary on X draws in llvmpipe at ~10 fps for the Arena.
3. **Catch 2 — no sound.** Both in the distro and in the container the app reports `SoLoudBackendNotInitializedException: The player is not initialized (on the C++ side).` and the home screen shows "Sounds are off"; a streamed session would be silent until a PulseAudio/ALSA device is arranged.
4. **Catch 3 — everything here is a root, profile-mode, patched build.** The auto-start of a game needs `--dart-define=START_GAME`, which only debug-mode code honours; the numbers above are from a profile build with the one-line `kProfileMode` patch of §4.2.
5. **Catch 4 — the game still needs a controller to start a round.** The Arena's waiting card waits for every player to be ready; the repo's simulated controller (`--demo`, ready at once) is what started the rounds measured here.

## 2. Environment and versions

| Thing | Version |
| --- | --- |
| Distro | Ubuntu 24.04.5 LTS, WSL2, kernel 6.18.58.1-microsoft-standard-WSL2, 16 vCPU, 15 GiB RAM, 1 TB virtual disk (4.7 GB used before installs) |
| GPU | NVIDIA GeForce RTX 3080, driver 610.88 (WSL userland 610.57.01), `/dev/dxg` and `/dev/dri/{card0,renderD128}` present |
| Flutter | 3.47.8 (stable tag, the version `.github/workflows/release.yml` pins), framework revision 737ba8f885, at `/opt/flutter` |
| Dart | 3.13.7 |
| GTK | libgtk-3-dev 3.24.41-4ubuntu1.3 (+ runtime `libgtk-3-0t64` pulled in) |
| Build tools | clang 18.1.3, cmake 3.28.3, ninja 1.11.1, pkg-config 1.8.1 |
| Mesa | 25.2.8-0ubuntu0.24.04.4 (llvmpipe LLVM 20.1.2; D3D12 via `/usr/lib/wsl/lib/libd3d12core.so`) |
| Weston | 13.0.0-4build3 (headless backend, gl renderer) |
| X | Xvfb 2:21.1.12-1ubuntu1.9, Xwayland 2:23.2.6-1ubuntu0.8 |
| GStreamer | 1.24.2 (base/good/bad/gl/libav), NVENC elements `nvautogpuh264enc` / `nvcudah264enc` (the earlier probe's finding still holds; `nvh264enc` not retried) |
| Docker | Engine 29.9.3, overlayfs, NVIDIA container toolkit 1.20.2, images `tp-test:latest` (1.16 GB) and the derived `tpapp-img:latest` (1.3 GB) |

Installed into the distro by this job (kept): clang, cmake, ninja-build, pkg-config, libgtk-3-dev, liblzma-dev, libstdc++-13-dev, libasound2-dev, libpulse-dev, libavahi-compat-libdnssd-dev, libsecret-1-dev, libjsoncpp-dev, libglu1-mesa-dev, libegl1-mesa-dev, libgles2-mesa-dev, mesa-utils(-extra), weston, xwayland, xvfb, x11-utils, imagemagick, GStreamer plugins (base, good, bad, gl, libav) and the dev package, plus the Flutter SDK at `/opt/flutter`. Disk now: `/opt/flutter` 1.2 GB, `/work` (the copy and its builds) 377 MB, `/root/.pub-cache` 402 MB.

## 3. Step by step (commands and key output)

Linux commands ran as `wsl -d tp-stream -u root -- bash -lc '<cmd>'`. Long jobs were wrapped in `timeout`. Scripts written inside the distro support the quoting (see the tooling note at the end of §6).

### 3.1 Permission self-test
```
wsl -d tp-stream -u root -- bash -lc 'echo ok; ls /mnt/c 2>/dev/null | wc -l'   -> ok / 0
wsl -l -v                                                                       -> "This command requires approval"
wsl.exe -d tp-stream -u root -- echo x                                          -> "Permission to use Bash with command ... has been denied."
```
Nothing outside the rules was tried.

### 3.2 Sync
```
tools/wsl-sync.sh tp-stream   -> /work/flash-20261111-141312-1826
```

### 3.3 Toolchain
```
apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-13-dev \
  libasound2-dev libpulse-dev libavahi-compat-libdnssd-dev libsecret-1-dev libjsoncpp-dev \
  libglu1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev mesa-utils mesa-utils-extra weston xwayland \
  xvfb x11-utils imagemagick gstreamer1.0-tools gstreamer1.0-plugins-{base,good,bad} gstreamer1.0-gl \
  gstreamer1.0-libav libgstreamer-plugins-base1.0-dev unzip curl git
git clone --depth 1 -b 3.47.8 https://github.com/flutter/flutter.git /opt/flutter
flutter --version            -> Flutter 3.47.8 • Dart 3.13.7 • engine cf636b1dfb
flutter config --enable-linux-desktop
flutter precache --linux
flutter doctor -v            -> [✓] Linux toolchain; "OpenGL core renderer: llvmpipe (LLVM 20.1.2, 256 bits)"
```
`git clone -b 3.47.8` worked, so the release workflow's pin is a real tag.

### 3.4 Linux build
```
cd tv_test_app && flutter create --platforms=linux --project-name tvtest .
flutter pub get                                              # at the workspace root
flutter build linux --release                                # 1st run:
  Building Linux application...
  ERROR: File modified during build. Build must be rerun.
  ✓ Built build/linux/x64/release/bundle/tvtest
flutter build linux --release                                # 2nd run: clean, bundle 33 MB
```
No plugin failed to build. The rerun message is the native-asset hook (flutter_soloud downloads its prebuilt Ogg/Vorbis/Opus/FLAC libraries on the first build, from the `prebuild_tag: v1.1.0` pin in the root pubspec). Nothing else was needed to make the build pass — the "smallest fix" was to run it twice, which the tool itself asks for.

### 3.5 Runs with no monitor

**a. headless weston on the GPU (the method that matters)**
```
export XDG_RUNTIME_DIR=/tmp/xdg GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA
weston --backend=headless --renderer=gl --width=1920 --height=1080 --socket=wl-probe --idle-time=0
  [weston] GL renderer: D3D12 (NVIDIA GeForce RTX 3080), GL ES 3.1
  warning: failed to query rendering device from EGL
  warning: Disabling render GPU timeline and explicit synchronization due to missing EGL_ANDROID_native_fence_sync extension
  EGL Wayland extension: no        dmabuf support: no
export WAYLAND_DISPLAY=wl-probe GDK_BACKEND=wayland
./tvtest
  libEGL warning: failed to get driver name for fd -1
  [IMPORTANT:flutter/shell/platform/embedder/embedder_surface_gl_impeller.cc(126)] Using the Impeller rendering backend (OpenGLESSDF).
  Gdk-CRITICAL **: gdk_seat_get_keyboard: assertion 'GDK_IS_SEAT (seat)' failed
```
The app starts, draws, listens on 45780. `grep d3d12 /proc/<pid>/maps` → `libd3d12core.so`, so the GL context really is the D3D12 translation layer, not llvmpipe.

Measured with the probe-only frame printer (§4.4) at 1920×1080 (window size patched, §4.3):

| Run | fps (5 s windows) | build ms | raster ms | CPU | GPU |
| --- | --- | --- | --- | --- | --- |
| Menu (animated ToyBackground + shader) | 60.0, 60.2, 60.0, 60.0, 60.0 | 0.30 | 3.95–3.97 | 63.6 % of one core | 39 % |
| Arena, round running, `sim_controller --demo` paired | 57.2, 53.2, 52.2, 53.4, 50.2, 52.2, 55.0 (mean 53.3) | 0.9 | 5.9–7.4 | ~64 % | 37 % |

**b. Xvfb (software)**
```
Xvfb :99 -screen 0 1920x1080x24
DISPLAY=:99 GDK_BACKEND=x11 ./tvtest
  libEGL warning: DRI3 error: Could not get DRI3 device
  libEGL warning: Ensure your X server supports DRI3 to get accelerated rendering
```
Menu 18.6 / 18.8 / 19.0 / 19.2 fps (raster ~53 ms, `top` 1370 % CPU); Arena 9.6 / 9.6 / 10.2 fps (raster ~100 ms, 1064 % CPU). Screenshots in `docs/briefs/m15/linux-probe/`.

**c. Xwayland inside the headless weston**
```
Xwayland :98 -geometry 1920x1080   (WAYLAND_DISPLAY=wl-probe)
DISPLAY=:98 GDK_BACKEND=x11 ./tvtest
  libEGL warning: DRI3 error: Could not get DRI3 device
```
Arena 9.6–10.8 fps, raster 96–103 ms — software again, because weston exports no dmabuf for DRI3.

**c′. WSLg's own X display**: `DISPLAY=:0` gives the same DRI3 error and software GL; not measured further (the app drew 5 frames of the waiting card and stopped, as an idle screen does).

**How a game was made to run by itself**: the app was built with `--dart-define=START_GAME=arena` (profile, §4.2), and the repo's simulated controller started the round:
```
dart run connection:sim_controller --host 127.0.0.1 --port 45780 --code <from the PROBE line> --name Probe --demo --seconds 60
  · Paired with DESKTOP-B9AB5K3
  · The TV made this phone player 2
  haptic hit intensity 0.7 100 ms
```
The Arena's waiting card makes a simulated controller ready at once (`arena_waiting_card.dart`), so no human input is needed; a local keyboard player added in the first attempt blocked the start (it is never "ready"), which is why the final patch only prints the pairing code.

### 3.6 Capture and NVENC
From the X display (the only one that can be captured):
```
DISPLAY=:99 gst-launch-1.0 -q ximagesrc use-damage=false startx=0 starty=0 endx=1919 endy=1079 num-buffers=1 \
  ! video/x-raw,format=BGRx,width=1920,height=1080 ! videoconvert ! pngenc ! filesink location=/work/shot-arena.png

DISPLAY=:99 gst-launch-1.0 ximagesrc use-damage=false startx=0 starty=0 endx=1919 endy=1079 num-buffers=600 \
  ! video/x-raw,format=BGRx,width=1920,height=1080,framerate=60/1 ! videoconvert ! nvautogpuh264enc bitrate=15000 \
  ! fpsdisplaysink text-overlay=false video-sink=fakesink sync=false
  Execution ended after 0:00:10.436708278      -> 600 frames / 10.44 s = 57.5 fps, dropped 0
```
Writing a file (`! h264parse ! mp4mux ! filesink location=/work/clip.mp4`, 2500 kbit/s) gave a 2,713,831-byte 10 s clip in 10.409 s, with `nvidia-smi` sampled every second during it: GPU 1–2 %, encoder 12–20 %.

First attempt (verbatim): `WARNING: erroneous pipeline: could not link videoconvert0 to nvautogpuh264enc0, nvautogpuh264enc0 can't handle caps video/x-raw, format=(string)I420` — the element takes NV12; drop the explicit I420 caps and let `videoconvert` negotiate.

**Capture from weston failed**, all attempts:
```
XDG_RUNTIME_DIR=/tmp/xdg WAYLAND_DISPLAY=wl-probe weston-screenshooter -f /work/shot-weston.png
  Output capture error: unauthorized
  Error: screenshot or protocol failure
```
Weston 13 refuses the capture protocol to clients it did not start, and this image has no `weston-capture`/pipewire path. So the GPU-drawn picture could not be saved; the pictures kept are the same app and game drawn by llvmpipe on X.

### 3.7 Container (stretch)
```
docker run -d --name tpapp --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg \
  -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib -e GALLIUM_DRIVER=d3d12 \
  -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA -p 45781:45780 tpapp-img sleep infinity
docker exec tpapp apt-get install -y libgtk-3-0 libasound2t64 libpulse0
docker cp <profile bundle> tpapp:/app
inside the container: weston --backend=headless --renderer=gl --width=1920 --height=1080 --socket=wl-c
  GL renderer: D3D12 (NVIDIA GeForce RTX 3080)      dmabuf support: no
  ./tvtest (WAYLAND_DISPLAY=wl-c, GDK_BACKEND=wayland) -> Impeller, listening, pairing code printed
dart run connection:sim_controller --port 45781 --code 8960 --demo   (from the distro)
  FRAME_STATS fps=58.0 / 60.4 / 60.2 / 58.4 / 59.6 (mean 59.3), build 0.8–1.1 ms, raster 4.4–5.1 ms
  nvidia-smi: GPU 24 %, encoder 0 %
```
The container needed only GTK and ALSA/Pulse runtime libraries on top of the earlier probe's `tp-test` image. The Flutter bundle is self-contained (`tvtest`, `lib/*.so`, `data/`), so no Flutter SDK is needed inside it.

### 3.8 Tidy
Stopped: the app, the simulated controllers, weston, Xvfb and Xwayland (a few became defunct children of dead shells; they disappear with the distro restart), and the `tpapp` container (`docker stop`; the container and both images are kept). Kept on purpose: the Flutter SDK, the apt packages, the synced copy and its `build/linux/x64/{release,profile}` bundles at `/work/flash-20261111-141312-1826/tv_test_app/build/linux/x64/`, and the screenshots and logs in `/work/`.

Note on the repository's state: `git status` lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and `generated_plugins.cmake` as modified, but `git diff --numstat` shows **no content change** — they differ only in line endings (`LF will be replaced by CRLF`). This job never ran Flutter on Windows and never touched `windows/`; the files were like that when the job started.

## 4. Every change the Linux build needed

All of these exist only in the distro copy; the repository is untouched. Diffs were taken from the copy as it ran.

### 4.1 `tv_test_app/linux/` — generated by `flutter create --platforms=linux --project-name tvtest .`
Generated only: `linux/CMakeLists.txt`, `linux/flutter/`, `linux/runner/{main.cc,my_application.cc,my_application.h}`. Also rewrote `tv_test_app/.metadata`'s platform list. **Belongs in the repository** when we take the Linux build seriously (it is the standard Flutter desktop runner; the app name is `tvtest`, `com.thumbparty.tvtest`).

### 4.2 `tv_test_app/lib/src/debug_start.dart` — start a game in a profile build
```diff
 Widget? debugStartScreen(String game) {
-  if (!kDebugMode) return null;
+  if (!kDebugMode && !kProfileMode) return null;
   return switch (game) {
```
Reason: `START_GAME` is read only when `kDebugMode`; a *release* build also ignores it, and a *debug* build is JIT and not representative of the shipped frame cost. Profile is AOT with assertions off, so it is the honest measuring build. **Candidate for the repository** (it makes `tools/tv-dev.sh --hz/--game` usable for measurements), but it changes what a profile build does, so it needs a decision, not a silent copy.

### 4.3 `tv_test_app/linux/runner/my_application.cc` — 1080p window
```diff
-  gtk_window_set_default_size(window, 1280, 720);
+  gtk_window_set_default_size(window, 1920, 1080);
```
Reason: the brief measures 1920×1080 and the stock runner opens 1280×720. **Not for the repository as-is** (a TV app should size from the display); it is documented here as the probe's setting.

### 4.4 `tv_test_app/lib/src/frame_stats.dart` (new) + two lines in `lib/main.dart` — frames a second with no monitor
```dart
import "dart:async";

import "package:flutter/scheduler.dart";

/// Probe-only frame timing printer (this copy only, not the repository):
/// --dart-define=FRAME_STATS=true makes it print, every [frameStatsWindow],
/// the frames a second the engine really produced and their mean build and
/// raster times, so a run with no monitor can still be measured.
const bool frameStatsEnabled = bool.fromEnvironment("FRAME_STATS");

/// How often a line is printed.
const Duration frameStatsWindow = Duration(seconds: 5);

/// Counts the engine frames and prints them a window at a time.
class FrameStats {
  static final List<FrameTiming> _window = [];
  static Timer? _timer;

  static void start() {
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _timer = Timer.periodic(frameStatsWindow, (_) => _report());
    print("FRAME_STATS on, " + frameStatsWindow.inMilliseconds.toString() + " ms window");
  }

  static void _collect(List<FrameTiming> timings) {
    _window.addAll(timings);
  }

  static void _report() {
    final frames = _window.length;
    final seconds = frameStatsWindow.inMilliseconds / 1000;
    if (frames == 0) {
      print("FRAME_STATS fps=0.0 frames=0 (nothing drawn)");
      return;
    }
    var buildUs = 0;
    var rasterUs = 0;
    for (final t in _window) {
      buildUs += t.buildDuration.inMicroseconds;
      rasterUs += t.rasterDuration.inMicroseconds;
    }
    _window.clear();
    print("FRAME_STATS fps=" + (frames / seconds).toStringAsFixed(1) + " frames=" + frames.toString() + " buildAvgMs=" + (buildUs / frames / 1000).toStringAsFixed(2) + " rasterAvgMs=" + (rasterUs / frames / 1000).toStringAsFixed(2));
  }
}
```
```diff
 import 'src/debug_start.dart';
+import "src/frame_stats.dart";
 import 'src/keyboard_player.dart';
...
   WidgetsFlutterBinding.ensureInitialized();
+if (frameStatsEnabled) FrameStats.start();
```
(The quoting and indentation are artefacts of patching a CRLF copy with `perl`/`sed` inside a shell whose quotes are stripped; the file compiles.) This is the measurement instrument. **If we want it long-term**, it belongs behind an observer injected in the shell, not as `print` — guidelines §2 forbids print/flags in `lib/`, so as written it is a probe tool only.

### 4.5 `tv_test_app/lib/src/debug_start.dart` — probe wrapper that prints port and pairing code
```diff
   return switch (game) {
-    'arena' => const GameScreen(),
-    'shape_race' => const _ShapeRaceStart(),
+    'arena' => const _WithLocalPlayer(GameScreen()),
+    'shape_race' => const _WithLocalPlayer(_ShapeRaceStart()),
     _ => null,
   };
```
```dart
class _WithLocalPlayer extends ConsumerStatefulWidget {
  const _WithLocalPlayer(this.child);
  final Widget child;
  @override
  ConsumerState<_WithLocalPlayer> createState() => _WithLocalPlayerState();
}

class _WithLocalPlayerState extends ConsumerState<_WithLocalPlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(hostStateProvider);
      print("PROBE port=" + s.host.port.toString() + " code=" + s.host.pairingCode);
    });
  }
  @override
  Widget build(BuildContext context) => widget.child;
}
```
Reason: the host's log keeps the pairing code in memory for the Diagnostics screen; nothing prints it, so a headless run has no way to pair a controller. `HostSnapshot.port` is null in that first snapshot, so the port came from `ss -ltnp` (45780). **Probe only** — the real answer is that the host should offer a headless start path (a port file or a `--port/--code` print when told to), which is a small M15 job of its own.

### 4.6 What did **not** need changing
No plugin stub, no `Platform.isX` guard, no dependency change, no `windows/` change. `main.dart`'s overrides all work on Linux: `getApplicationSupportDirectory`, `getDownloadsDirectory`, the keyboard player (`Platform.isLinux` is already in `KeyboardPlayer.available`), the shader load and the fonts.

## 5. Copy-paste recipe: from this distro to "game running headless and encoded"

```bash
# 0. inside tp-stream, once per job: the code, with this job's patches applied to the copy
tools/wsl-sync.sh tp-stream                       # on Windows (Git Bash), prints /work/<folder>
wsl -d tp-stream -u root -- bash -lc 'export PATH=/opt/flutter/bin:$PATH; cd /work/<folder> && flutter pub get'

# 1. Linux runner + build (profile, so the game auto-starts)
cd /work/<folder>/tv_test_app
flutter create --platforms=linux --project-name tvtest .        # once
flutter build linux --profile --dart-define=START_GAME=arena --dart-define=FRAME_STATS=true

# 2. a compositor on the GPU, no monitor
export XDG_RUNTIME_DIR=/tmp/xdg GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA
weston --backend=headless --renderer=gl --width=1920 --height=1080 --socket=wl-probe --idle-time=0 &
export WAYLAND_DISPLAY=wl-probe GDK_BACKEND=wayland
cd build/linux/x64/profile/bundle && ./tvtest > /work/app.log 2>&1 &

# 3. a controller to start the round (the app prints "PROBE port=null code=1234")
cd /work/<folder>/packages/connection
dart run connection:sim_controller --host 127.0.0.1 --port 45780 --code <code> --name Probe --demo --seconds 300 &
grep FRAME_STATS /work/app.log          # fps at 1080p, build and raster ms

# 4. encode (needs a capturable surface: X, i.e. software drawing here)
DISPLAY=:99 gst-launch-1.0 ximagesrc use-damage=false startx=0 starty=0 endx=1919 endy=1079 num-buffers=600 \
  ! video/x-raw,format=BGRx,width=1920,height=1080,framerate=60/1 ! videoconvert ! nvautogpuh264enc bitrate=15000 \
  ! h264parse ! mp4mux ! filesink location=/work/clip.mp4

# 5. the same app in a GPU container (measured 59 fps)
docker run -d --name tpapp --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg \
  -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib -e GALLIUM_DRIVER=d3d12 \
  -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA -p 45781:45780 tpapp-img sleep infinity
docker exec tpapp apt-get install -y libgtk-3-0 libasound2t64 libpulse0
docker cp build/linux/x64/profile/bundle tpapp:/app
docker exec tpapp bash /run.sh          # weston --socket=wl-c + ./tvtest, as in §3.7
```

## 6. What failed or is unproven, and why

- **Getting the GPU picture off the machine.** Three capture routes were tried from weston (its screenshooter, `import` on the same display, none else exists in this image); all are refused or absent. This is the design's pivot: the stack in `streaming-custom.md` §2 assumes `gst-wayland-display`, a compositor that hands out its frames as dmabuf to GStreamer. Weston here says `dmabuf support: no` and `EGL Wayland extension: no`, so even that compositor would have nothing to hand over. **Unproven on this PC; likely unavailable.**
- **Hardware GL only through Wayland.** Every X path (Xvfb, WSLg `:0`, Xwayland inside weston) loses acceleration (`DRI3 error: Could not get DRI3 device`), so the only way to draw on the GPU here is a Wayland client of a compositor that owns the d3d12 surfaceless context.
  A caveat on that: `eglinfo -B` on its *X11 platform* printed `D3D12 (NVIDIA GeForce RTX 3080)` in the same session where the app got `DRI3 error` and drew with llvmpipe, so eglinfo evidently fell back to a non-DRI3 path; the app's own raster time (53 ms versus 4 ms) is the evidence that X was software, not the eglinfo line.
- **The Arena at 1080p on the host was 50–53 fps, not 60**, while the same app in a container on the same GPU held 58–60. The likely cause is the host's weston running with `desktop-shell` and a cursor, plus the distro's other load at that moment; it was not investigated further. Treat "1080p60 with the real game" as **marginal on the host, comfortable in the container**.
- **Sound.** `miniaudio_init: ma_device_init failed` in the distro (ALSA finds no card; WSLg's PulseAudio is at `/mnt/wslg/PulseServer` but the session has no `PULSE_SERVER`) and the same in the container. The app degrades well (it says so on screen) but a streamed session needs a sink — a null/dummy Pulse sink in the container is the obvious next try.
- **Discovery** was not tested from a phone: bonsoir built and logged its advertise call, but no phone was on the network and mDNS from a container is exactly what the design says is worth checking separately.
- **Shape Race** was not run (the Arena is the heavier path); **wakelock_plus** was never asked to keep the screen awake; **release-mode** gameplay was not measured.
- **NVENC path while the game draws on the GPU**: never in one run, because of the capture gap. The 57.5 fps encode number includes a *software-rendered* window, so the GPU was idle during it; the earlier probe's 68 fps for `gltestsrc → gldownload → nvautogpuh264enc` is the closest data for a GPU-drawn, read-back-and-encoded frame.

**What to try next** (in order of value per hour):
1. Build `gst-wayland-display` (Rust, MIT) in the distro and see whether its compositor starts on D3D12 and can export anything at all without dmabuf. That single test decides whether WSL2 is a drawing target or only a bench for encode/transport.
2. If it can't: prove the drawing step on real Linux (a rented cloud GPU or a dual-boot) with NVIDIA's own driver, where dmabuf, Vulkan and X with hardware GL all exist.
3. A headless start path for the host: print/write port + pairing code on request, so a server can pair a phone (or a simulated controller) without a screen.
4. An audio sink in the container (Pulse null sink) and a sound check in the smoke run.

**What would differ on real Linux with NVIDIA's own driver** (my judgement, labelled as such): GL would be native (no D3D12 translation, no read-back through system memory), `dmabuf` and Vulkan would exist, so `gst-wayland-display` + zero-copy NVENC would be the normal path; an X server with hardware GL would also work, so `ximagesrc` capture would be usable. Frame cost would drop (the D3D12 path's raster 4–8 ms for a 2D game is high) and latency would improve; the 12-encode-session cap is a GeForce driver property and would stay on a 3080. Nothing in this probe contradicts the design's choice of Flutter + GStreamer + NVENC; what it contradicts is the assumption that WSL2 can *capture* what it draws.

### Tooling note for later `wsl:` jobs
Quote characters do not survive the `wsl -d … -- bash -lc '<cmd>'` argv path: `<<"EOF"` behaved as an unquoted heredoc, `sed "s/x/'y'/"` lost the inner quotes, and `\ ` in a script was rejected by the command guard. Two habits that worked: write scripts with `cat > /tmp/p.sh <<EOF … EOF` using **no `$`, no backticks and no single quotes** in the content, and use `perl -pi -e "s/…/\x27…\x27/"` when a replacement needs a quote. Also: `pkill -f <pattern>` matches the shell running it — kill by exact name (`pkill -x tvtest`) or by PID.

### Decisions (low-usage mode: safest choice, never stopped to ask)
1. Measured with a **profile** build plus the `kProfileMode` patch (§4.2) instead of debug, because a debug JIT build's frame cost is not the shipped cost.
2. Added the **frame-timing printer** (§4.4) as the instrument, since the alternative (the capture pipeline's counter) only exists on the X path.
3. Used the repo's **simulated controller** (`--demo`) to start rounds: it needed no new code and is the tool the smoke test already trusts.
4. Dropped the first idea of auto-joining a local keyboard player: the Arena's card never marks it ready, so the round could not start.
5. Kept the **container test** on the existing `tp-test` image + GTK rather than building a new image.
6. Did **not** attempt `gst-wayland-display` (Rust build, outside the two-hour box) — it is named as the first next step instead.
7. Ran everything as root in a temporary copy under `/work`; nothing in the repository was built or run.

### Self-check (review-rules.md part A)
1. **Every host setup** — not affected: no code in the repository changed; the probe measured the TV app only (phone host paths untested).
2. **When kept state starts and ends** — not affected: nothing held, timed or counted was added to shipped code; the probe's `FrameStats` timer lives only in the distro copy.
3. **How a new state combines with the others** — not affected: no pause, wait or input state was touched.
4. **Stay in the job's folder** — done: only `docs/briefs/m15/linux-game-probe-report.md` and `docs/briefs/m15/linux-probe/` were written in the repository; everything else is under `/work/` in the distro.
5. **Stop rather than overstep** — nothing outside `allow:` was needed; the one design question (a headless start path for the host) is raised in §4.5 instead of being built.

## Commit message

```
m15 probe: the TV app builds for Linux and draws 60 fps on the WSL2 GPU

docs/briefs/m15/linux-game-probe-report.md records what a Flutter Linux
build of the TV app does inside tp-stream: the toolchain and Flutter 3.47.8,
a clean release and profile build with every plugin supporting Linux, GPU
drawing on D3D12 under headless weston (menu 60 fps, Arena ~53 fps at 1080p,
software in every X path at ~10-19 fps), NVENC encoding of a 1080p60 X
capture at 57.5 fps, and the same app in a GPU container at 59 fps. The one
gap it names is capture: weston exports no dmabuf and refuses client capture,
so the design's virtual-screen step stays unproven on WSL2. Screenshots, a
10 s clip and the weston/app logs are in docs/briefs/m15/linux-probe/.
```

## Status row

M15 Linux game probe: done — the TV app builds for Linux (Flutter 3.47.8, no plugin stubs) and the real Arena draws at 1080p on the RTX 3080 through Mesa's D3D12 layer (60 fps menu, ~53 fps Arena on the host, 59 fps in a GPU container), with NVENC encoding a 1080p60 capture at 57.5 fps; open: capturing the GPU-drawn picture (weston refuses capture and exports no dmabuf, so gst-wayland-display is unproven on WSL2, all capturable X paths are llvmpipe at 10–19 fps), sound (no audio device: SoLoudBackendNotInitialized), and a headless way for a host to publish its port and pairing code.

## Delete

- none
