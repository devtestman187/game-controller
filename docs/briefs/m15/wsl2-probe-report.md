# WSL2 + Docker Engine (no Docker Desktop) + NVENC/GL probe report

History: the first attempt on Nov 11 was blocked because WSL was not installed. The owner installed WSL and rebooted; this is the full rerun (Nov 11, 2026).

## 1. Verdict

| Test | Result |
|---|---|
| A native NVENC in WSL (ffmpeg + GStreamer) | WORKS with caveat: ffmpeg h264/hevc_nvenc fine; GStreamer `nvh264enc` FAILS ("Selected preset not supported"), use `nvautogpuh264enc` / `nvcudah264enc` |
| B NVENC in a container (Docker Engine in WSL) | WORKS with only `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all` (no extra mounts) |
| C-a GPU render in WSL (no container) | WORKS with caveat: GL is D3D12 (NVIDIA RTX 3080) only with `GALLIUM_DRIVER=d3d12`; default is llvmpipe. Vulkan = llvmpipe only |
| C-b GPU render in container | WORKS with caveat: needs `--device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib -e GALLIUM_DRIVER=d3d12`; GL only, Vulkan = llvmpipe |
| C-c render+encode headless 1080p60 | WORKS with caveat: runs, ~68 fps unthrottled with trivial gltestsrc (reaches 60 but little headroom; readback bound) |
| D session cap | 12 concurrent NVENC sessions (13th and beyond fail) |
| Stretch weston headless GL + GL client | UNPROVEN: weston headless uses `D3D12 (NVIDIA GeForce RTX 3080)`, but weston-simple-egl produced no frames/fps |

Summary:
1. Yes: Docker Engine inside plain WSL2 can run containers that encode with NVENC (1080p60 H.264 at ~475 fps unthrottled) and render GL on the RTX 3080 via Mesa's D3D12 driver, at the same time.
2. Catch 1: GL goes through D3D12 translation (Mesa `d3d12`), not native NVIDIA GL/EGL. No NVIDIA Vulkan (only llvmpipe). Wayland/GL clients through weston headless did not work in my short test.
3. Catch 2: GL readback (gldownload, GPU to CPU to NVENC) limits one stream to ~68 fps for a trivial scene; zero-copy GL-to-NVENC was not tried.
4. Catch 3: hard cap of 12 simultaneous NVENC sessions on this GeForce driver, all containers combined.
5. Catch 4: `nvh264enc` is broken on this driver/GStreamer 1.24; use `nvautogpuh264enc` or `nvcudah264enc`.

## 2. Environment
- Windows 11 Pro 10.0.26300.9974; GPU NVIDIA GeForce RTX 3080 10 GiB; Windows driver 610.88 (nvidia-smi in WSL shows 610.57.01 userland, KMD 610.88, CUDA 13.3)
- WSL 3.0.5.0, kernel 6.18.58.1-1 (in-distro `6.18.58.1-microsoft-standard-WSL2`), WSLg 1.0.79, Direct3D 1.611.1, DXCore 10.0.26100.1
- Distro `tp-stream`: Ubuntu 24.04.5 LTS, WSL version 2, systemd enabled via /etc/wsl.conf
- Docker Engine 29.9.3 (get.docker.com); nvidia-container-toolkit 1.20.2
- ffmpeg 6.1.1-3ubuntu5; GStreamer 1.24.2; Mesa 25.2.8-0ubuntu0.24.04.4 (llvmpipe LLVM 20.1.2), same in the image
- Docker Desktop: not installed.

## 3. Step by step
Linux commands were run as `MSYS_NO_PATHCONV=1 wsl -d tp-stream -u root -- bash <script>`.

Step 0: `wsl --version` -> WSL 3.0.5.0 (above); `wsl -l -v` -> no distros; `cmd /c ver` -> 10.0.26300.9974; `nvidia-smi` -> driver 610.88.

Step 1: `wsl --install -d Ubuntu-24.04 --name tp-stream --no-launch` -> "Distribution successfully installed." `wsl -l -v`: `tp-stream  Stopped  2`.

Step 2: inside distro `nvidia-smi` works (RTX 3080). `ls -la /usr/lib/wsl/lib` contains `libnvidia-encode.so.1` (272528), `libnvcuvid.so.1`, `libcuda.so.1`, `libnvidia-ml.so.1`, `libd3d12.so`, `libdxcore.so`. `/dev/dxg` is `crw-rw-rw- 10, 258`.

Step 3 (Test A):
- `apt-get install -y ffmpeg gstreamer1.0-tools gstreamer1.0-plugins-{base,good,bad} gstreamer1.0-gl mesa-utils mesa-utils-extra vulkan-tools mesa-vulkan-drivers`
- `ffmpeg -hide_banner -f lavfi -i testsrc2=size=1920x1080:rate=60 -t 10 -c:v h264_nvenc -preset p1 -tune ull -b:v 15M -f null -` -> `frame=600 fps=521 speed=8.67x`
- same with `hevc_nvenc` -> `frame=600 fps=587 speed=9.77x`
- `gst-inspect-1.0`: nvcodec has `nvh264enc`, `nvh265enc`, `nvautogpuh264enc`, `nvautogpuh265enc`, `nvcudah264enc`, `nvcudah265enc`, nvh264dec etc.
- `gst-launch-1.0 videotestsrc num-buffers=600 ! video/x-raw,width=1920,height=1080,framerate=60/1 ! nvh264enc ! fakesink` -> FAIL: `gst_nv_base_enc_set_format (): ... Selected preset not supported` / `Could not configure supporting library`. Every preset value (default, hp, low-latency-hq, 1, 5) fails the same way.
- Same pipeline with `nvautogpuh264enc` -> OK, `Execution ended after 0:00:01.73` for 600 frames (unthrottled).

Step 4 (Test B):
- `curl -fsSL https://get.docker.com | sh`; NVIDIA apt repo + `apt-get install nvidia-container-toolkit`; `nvidia-ctk runtime configure --runtime=docker`; `printf '[boot]\nsystemd=true\n' > /etc/wsl.conf`; `wsl --terminate tp-stream`. After restart: `systemctl is-system-running` = running, docker active.
- a. `docker run --rm --gpus all ubuntu:24.04 nvidia-smi` -> works, shows RTX 3080.
- b. with `-e NVIDIA_DRIVER_CAPABILITIES=all`: `libnvidia-encode.so.1 => /usr/lib/wsl/drivers/nvmd.inf_amd64_ffd9a18b05442e28/libnvidia-encode.so.1` and `libnvcuvid.so.1` found by ldconfig (the toolkit injects them).
- c. ffmpeg h264_nvenc in container with only `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all`: `frame=600 fps=476 speed=7.92x`. The retry with `-v /usr/lib/wsl/lib` was NOT needed.
- d. `nvautogpuh264enc` 600 frames: 1.75 s; `nvcudah264enc`: 1.82 s (both unthrottled, ~340 fps).
- Test image `tp-test` (Dockerfile: ubuntu:24.04 + ffmpeg, gstreamer plugins, gst-gl, mesa-utils(-extra), vulkan-tools, mesa-vulkan-drivers, libgl1-mesa-dri, libegl1, weston).

Step 5 (Test C):
- a. in distro `eglinfo -B`: default -> `llvmpipe (LLVM 20.1.2, 256 bits)` on GBM/Wayland(WSLg)/Surfaceless/Device platforms. With `GALLIUM_DRIVER=d3d12` (and also with `MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA`) -> `D3D12 (NVIDIA GeForce RTX 3080)` on all platforms. `glxinfo -B` (WSLg, DISPLAY=:0) default -> llvmpipe. `vulkaninfo --summary` (with or without those env vars) -> only `llvmpipe` (no dozen/NVIDIA Vulkan device in these packages).
- b. container with `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib`: default llvmpipe; with `-e GALLIUM_DRIVER=d3d12` surfaceless EGL -> `OpenGL core profile vendor: Microsoft Corporation / renderer: D3D12 (NVIDIA GeForce RTX 3080)`, GL 4.6 core. Vulkan: llvmpipe only. Harmless warnings: `MESA-LOADER: failed to retrieve device information`.
- c. container (flags from 5b plus `-e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA -e GST_GL_PLATFORM=egl -e GST_GL_WINDOW=surfaceless`):
  `gst-launch-1.0 -v gltestsrc num-buffers=600 ! 'video/x-raw(memory:GLMemory),width=1920,height=1080,framerate=60/1' ! gldownload ! videoconvert ! nvautogpuh264enc ! fpsdisplaysink text-overlay=false video-sink=fakesink sync=false`
  -> runs, 600 frames in 8.4 s, `average: 68.4` fps, dropped 0. Control with the llvmpipe renderer: `average: ~121` fps (a trivial pattern renders faster in software than the d3d12 readback path). GStreamer's own GL renderer string was not captured in the debug output (GST_DEBUG=gl*:4 printed none); that d3d12 was used is inferred from the env vars and the eglinfo result in the same container (the fps differs between the two runs). Not paced to real time (sync=false); a real-time 60 fps run was not separately timed, but 68 fps unthrottled means the pipeline can sustain 60.

Step 6 (Test D): 20 s runs of `ffmpeg -re -f lavfi -i testsrc2=size=1920x1080:rate=60 -t 20 -c:v h264_nvenc -preset p1 -tune ull -b:v 15M -f null -`, N processes in parallel (run natively in the distro; the limit is per driver):
- N=4: 4 ok, 0 fail, each speed 1.02x (62 fps shown). nvidia-smi during N=4: `utilization.encoder 47 %` then dmon `enc` 47/56/62 %, GPU 11-22 %.
- N=9: 9 ok.
- N=13: 12 ok, 1 fail. N=16: 12 ok, 4 fail.
- Error text: `[h264_nvenc] OpenEncodeSessionEx failed: incompatible client key (21): (no details)` / `Error while opening encoder - maybe incorrect parameters such as bit_rate, rate, width or height.` Cap = 12 on this driver (610.x). At N=12 every stream still ran at 1.02x real time.
- (My first N=13 summary line reported ok=13 because of a grep bug; the second run counting exit codes is the correct one.)

Step 7 (stretch): in the container (render flags + `GALLIUM_DRIVER=d3d12`): `weston --backend=headless --renderer=gl --width=1920 --height=1080 --socket=wl-probe` starts; log: `GL renderer: D3D12 (NVIDIA GeForce RTX 3080)`, `GL ES 3.1`, plus warnings `failed to query rendering device from EGL`, `Disabling render GPU timeline and explicit synchronization due to missing EGL_ANDROID_native_fence_sync extension`, `EGL Wayland extension: no`. `weston-simple-egl` against it printed only `libEGL warning: failed to get driver name for fd -1` and no fps lines in 13 s. `glimagesink` test also gave no usable result. Verdict: unproven, probably the Wayland client cannot get GPU buffers from headless weston here (no wl_drm/dmabuf path).

Step 8: `wsl --terminate tp-stream` done; distro left registered. Disk: `C:\Users\mrman\AppData\Local\wsl\{a7689b59-ab42-45ac-90ca-4592e4c8a6ed}\ext4.vhdx`, 5.65 GB (includes Docker, packages and the 1.16 GB `tp-test` image).

## 4. Working recipe (fresh machine to NVENC container)
Windows (admin, once; reboot may be needed): `wsl --install --no-distribution` ... `wsl --update`, then:
1. `wsl --install -d Ubuntu-24.04 --name tp-stream --no-launch`
2. In the distro as root: `curl -fsSL https://get.docker.com | sh`
3. Add NVIDIA's apt repo (gpg key `https://nvidia.github.io/libnvidia-container/gpgkey` to /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg, list `https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list` with signed-by), `apt-get update && apt-get install -y nvidia-container-toolkit`
4. `nvidia-ctk runtime configure --runtime=docker`; `printf '[boot]\nsystemd=true\n' > /etc/wsl.conf`; from Windows `wsl --terminate tp-stream`; next start brings up dockerd via systemd.
5. NVENC only:
   `docker run --rm --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all <image>` (image needs ffmpeg with nvenc or GStreamer nvcodec; use element `nvautogpuh264enc` or `nvcudah264enc`, not `nvh264enc`; ffmpeg `-c:v h264_nvenc -preset p1 -tune ull`).
6. NVENC + GL render on the GPU:
   `docker run --rm --gpus all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro -e LD_LIBRARY_PATH=/usr/lib/wsl/lib -e GALLIUM_DRIVER=d3d12 -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA -e GST_GL_PLATFORM=egl -e GST_GL_WINDOW=surfaceless <image with mesa+gstreamer-gl>`
   Pipeline: `gltestsrc ! video/x-raw(memory:GLMemory),... ! gldownload ! videoconvert ! nvautogpuh264enc ! ...`
Caveat: containers must be started from inside the distro (the WSL VM must stay running; keep a session open or configure it so the distro is not idled).

## 5. What failed or is unproven
- `nvh264enc` (GStreamer 1.24.2) fails with "Selected preset not supported" for all presets: the legacy preset API is evidently rejected by driver 610.x. The newer `nvautogpuh264enc`/`nvcudah264enc` work.
- Vulkan: only llvmpipe; NVIDIA Vulkan (dozen) not available in Ubuntu 24.04 Mesa packages here. Vulkan-based apps would be CPU rendered.
- weston headless + GL Wayland client: no frames; not investigated further. A Flutter Linux app (Wayland/X11 GTK) is therefore unproven. Not tested: xvfb/X11 path, zero-copy GL-to-NVENC (`nvcudah264enc` with GL memory via cudaupload), real game-class GL load, multiple containers rendering concurrently, Windows-side load interference (desktop GPU shared with Windows).
- The 68 fps render+encode number is for a trivial test pattern; a real game's cost will be added.

## 6. How to remove everything
- `wsl --terminate tp-stream` then `wsl --unregister tp-stream` (deletes the ext4.vhdx, 5.65 GB, and all of the above: Docker, images, packages).
- Nothing else was installed on Windows. The scratch scripts are in the session scratchpad (temp).
