# M15 streaming: status and hand-over

Written Nov 11, 2026 so that any later session (any model) can pick this up cold. Read this file first, then the two design files it names.

## Where things stand

- **Decided by the owner (Nov 11, 2026):** a **custom** streaming stack (not Sunshine + Moonlight), to learn how production game streaming works and to grow into a product; lowest latency; play across the internet; several households in separate sessions; the server in containers; open-source parts wherever they exist; home PC (RTX 3080) first, cloud GPU later; latency logged per stage (input, host, encode, network, decode, display). Automation features go in shared host code for every build. Milestones: **M14** testing and fixes (owner is testing; fixes land on `m14`), **M15** the streaming prototype (branch `m15`, cut from `m14` on Nov 11), **M16** the friendlier app start (11 UX suggestions, all approved; mock-ups before building).
- **Built on `m15` (Nov 11, 2026), in four jobs:** **p1** the session summary's `stream` record, the report's Streaming section and its CSV (`packages/metrics`); **c1** the Linux session image and the player page, run with `tools/stream.sh build|up|down|url`; **a2** the automation interface in shared host code, off by default (the latency test card, the press probe, the `stats/stream` ingest); **c2** the player, the container's sampler and a benchmark reporting into the stats, with `tools/stream.sh bench` printing the Streaming report. The review of those four reports is the fix batch **f1** (this branch's first fixes).
- **First numbers (c2, 1080p60, viewer on the same PC):** capture-to-screen **126 ms** median (131 p95), of which the jitter buffer is 89 and the encoder 30; **press-to-screen 203 ms** median (323 p95, 114 presses) against gate 1's under-80 ms; 19.9 Mbit/s, no loss, no freezes, 224 % CPU, 635 MB, GPU 46 %. Two sessions at once: 37.5 and 37.6 delivered fps each, GPU 66 %. 720p: total 147 ms median.
- **Reachable from other devices:** WSL runs **mirrored** networking since Nov 11, so a session listens on the PC's own address; a phone or TV elsewhere on the Wi-Fi still waits on the owner's Windows Firewall rule (c1's report says which one).
- **Next:** the f1 fixes, then **fix1/t1 latencies** (the jitter buffer and the encoder's hold come first), then tuning (step 3) and a family test.

## Read in this order

1. `docs/design/streaming-custom.md`: the stack, the measurements on the PC, the plan in steps (§5), latency stages (§6), automation rule (§6a), risks.
2. `docs/design/streaming-roadmap.md`: prototype → production, with gates.
3. `docs/briefs/m15/capture-probe-report.md`: **the working recipe** (compositor + game + NVENC + sound in a container), with scripts in `docs/briefs/m15/capture-probe/`.
4. `docs/briefs/m15/linux-game-probe-report.md`: the Linux build of the TV app, the patches it needed in the test copy, plugin status.
5. `docs/briefs/m15/wsl2-probe-report.md`: WSL2/Docker/NVENC setup recipe and limits (12 encode sessions).
6. Background: `research-custom-stack-report.md` (48 sources), `research-hyperv-gpu-report.md` (50 sources), `scan-stream-touchpoints-report.md` (what our code already has), `docs/design/cloud-streaming.md` (the superseded Sunshine proposal; its measuring ideas still apply).

## The facts that matter (all measured on this PC unless marked)

- Windows 11 Pro build 26300, RTX 3080 10 GB, driver 610.88; WSL 3.0.5; distro **`tp-stream`** (Ubuntu 24.04): Docker Engine 29.9.3, NVIDIA Container Toolkit 1.20.2, Flutter 3.47.8 at `/opt/flutter`, GStreamer 1.24.2, gst-wayland-display built at commit `016b4fc` (needs libwayland 1.24 at `/opt/wayland124`), gst-plugins-rs 0.13.6 (`webrtcsink`), images `tp-test` and `tpapp-img`, the test build of the game under `/work/flash-20261111-141312-1826`.
- NVENC in containers: `--gpus all -e NVIDIA_DRIVER_CAPABILITIES=all`. Use **`nvautogpuh264enc` or `nvcudah264enc`** (`nvh264enc` fails in WSL2). Cap: 12 encodes at once.
- GPU drawing in WSL2 is Mesa's D3D12 layer (`GALLIUM_DRIVER=d3d12`, `--device /dev/dxg`, `/usr/lib/wsl` mounted); the compositor must use `render-node=software`; frames cross system memory (no zero-copy). One session: 1080p60. Two: about 45 fps each.
- Docker **Desktop** cannot pass NVENC to containers; Docker Engine inside WSL2 can. Hyper-V GPU sharing is not a dependable route on Windows 11.
- Open items for step 1: pin encoder settings (bitrate was ignored); the game was a patched profile build started by debug flags and a simulated controller (replace with the automation interface); discovery from a phone to a container untested (publish the controller port 45780); sound works through a PulseAudio null sink.

## How the work is done (the process)

- **Roles:** Claude designs, writes briefs, reviews and decides; **flash-worker** (`tools/flash.sh --brief <file>`, model deepseek-v4-flash, cheap) does the building, scanning and hands-on runs. For small tooling changes or hands-on work flash-worker can't do, a **Sonnet or Haiku subagent** is used. The owner is short on Claude usage: keep Claude's own reading and writing small. Details: `docs/dev-tools.md` (flash section) and the memory notes named below.
- **Working mode:** low-usage, as updated on Nov 11, 2026: see `docs/flash-framework.md` (the runner `tools/run-jobs.sh`, worker reviews, Claude reads only `REVIEW.md`). The first M15 batch was started with the older `run-m15.sh`; later batches use `tools/run-jobs.sh`. The owner can switch back to normal mode.
- **flash-worker modes added on Nov 11:** `web: yes` (research with web access; the job may only write a report under `docs/`; it runs in an empty folder, so the brief must carry its own context) and `wsl: tp-stream` (commands inside a locked-down WSL distro whose name starts with `tp-`; helpers `tools/wsl-sync.sh`, `tools/wsl-fetch.sh`, `tools/wsl-lockcheck.sh`). The distro has no Windows drives and no Windows program launching; it still has internet. Known gaps are listed in the agent report summarised in docs/dev-tools.md.
- **Running jobs:** start with Bash `run_in_background`; briefs must be committed first (job folders are cut from HEAD); result 0 = applied, 3 = protected files changed (review, apply by hand), 4 = files outside `allow:` (apply by hand without them), 5 = checks failed. Before commits: `git checkout -- tv_test_app/windows/flutter/ site/shots/` (generated churn; `site/shots` must keep the build-345 pictures). Commit with `tools/commit-job.sh <brief> --push` or by hand; push with `git push origin refs/heads/m14`.
- **Standing rules from the owner:** never modify `E:\AI\game-controller` (frozen checkout); never print or store the DeepSeek key; touch only processes you started; install nothing on Windows without asking; never `wsl --shutdown`; builds, tags and tester promotion only on the owner's word; downloads need permission.
- **Memory notes** (in `C:\Users\mrman\.claude\projects\E--AI\memory\`): `m15-streaming`, `low-usage-mode`, `orchestrator-model`, `background-jobs`, `m14-progress`.

## In progress (owner, Nov 11, 2026: "Get started on the M15 work. Use flash-worker as much as possible.")

Branch **`m15`**, worktree **`E:\AI\game-controller-m15`**, cut from `m14` at 0a6e5ab. The owner also asked for measurements through the existing stats framework: "audio, video and controller latency, cpu/memory usage of the containers, and anything else you think will be useful".

**The run**: `docs/briefs/m15/run-m15.sh <log-dir>` (same runner as M14: waves, full `tools/check.sh` after each wave, `tools/commit-job.sh --push`, stops with a reason in `docs/briefs/m15/run-m15.log`; safe to rerun, it skips committed jobs):
1. **p1-stream-metrics** (the `stream` record, collector API and the report's "Streaming" section in packages/metrics) beside **c1-session-image** (`wsl:` job: the Linux runner, `streaming/` Dockerfile + entrypoint + web player, `tools/stream.sh build|up|down|url`, reachability notes);
2. **a2-automation** (the automation interface in shared host code for every build, off by default; the latency test card and press probe; the `stats/stream` ingest endpoint);
3. **c2-stream-stats** (`wsl:` job: player and container report into the stats; `tools/stream.sh bench` prints the Streaming report: one session, two sessions, 720p).

**After the run (Claude):** review the reports' "Decisions"/"Blocked" and c2's numbers against gate 1 of docs/design/streaming-roadmap.md; one batch of fixes; then tuning (step 3) and a family test. **Needs the owner:** making the PC's stream reachable from other devices on the Wi-Fi will need a Windows-side change (c1's report says exactly what; likely WSL "mirrored" networking and a firewall rule). Merge `m14` fixes into `m15` as they land.

## Cleaning up, if this is abandoned

`wsl --unregister tp-stream` removes the Linux install and everything in it (about 10 GB by now). The flash-worker modes are inert unless a brief asks for them.
