# M15 streaming: status and hand-over

Written Nov 11, 2026 so that any later session (any model) can pick this up cold. Read this file first, then the two design files it names.

## Where it stands (Nov 13, 2026, morning) — read this first

- All marker phone runs are done (see the Nov 13 lines in docs/streaming-latency-journey.md "Running notes"). The press measurement is validated by the marker; baseline press-to-screen on iPhone Safari is 197-225 ms; `SESSION_AUDIO=separate` gives no dependable gain (141, 235 with freezes, 197); `SESSION_AUDIO=off` gives about 30 ms (166-181). No defaults changed.
- Waiting on the owner's decision: custom player (WebCodecs), a native viewer, or accept about 170-200 ms and add instant feedback on the controller; and whether the 80 ms gate stands. Do not start a batch before that decision.
- opt1 feasibility (Nov 13): docs/briefs/m15/research/custom-player-feasibility.md, verdict go with conditions; probe page built at /probe.html on the player port (open it on the iPhone first, see answer 8 there); expected gain 20-80 ms; no build started.
- Smaller open items: sound sets a pipeline-wide wait of about 27 ms on the host (try sound in its own pipeline); the marker's two figures disagree when sound is separate; the marker raises slow frames to 12-13% (measuring tool only).
- Phone-run routine: the owner closes every stream tab and says "ready"; then start ONE run in the background, give the printed URL, and after it ends confirm `tools/stream.sh status` shows no sessions and say "Run N is done".
- Working mode: low-usage; batches, research, documents and routine work go to Sonnet agents, flash-worker implements, Claude designs, decides and checks reports. Append dated notes to the journey document after every result, decision or obstacle.

## Resume here (updated Nov 12, 2026, night)

- Branch m15, worktree E:/AI/game-controller-m15. Batches since Nov 11: fix5 (phone-run mode), fix6 (host-leg and encoder measuring), a research report (docs/briefs/m15/research/latency-prior-art.md), fix7 (audio apart from video, sender switches; none made default), the story so far in docs/streaming-latency-journey.md (Running notes, newest last), and fix8 (the independent latency check, below). Working mode: low-usage, with Sonnet agents writing briefs and running batches, flash-worker implementing.
- **The open problem:** on the iPhone the stream chain total (30-130 ms) does not follow press-to-screen (169-223 ms); the audit (docs/briefs/m15/fix8/f8-1-audit-report.md) found no single definite fault. No phone figure is trusted until the marker runs below are done. Reports: docs/briefs/m15/fix8/f8-*-report.md; spec docs/streaming-marker.md.
- **Next, needs the owner:** the three phone runs below. Then read the Independent check table: if the marker's press-to-screen and the card's agree, the press figure is right and the chain is a partial view; if not, the press timing is suspect (first suspects in the audit). After that decide whether any fix7 switch helps on Safari. No defaults changed anywhere.
- Stale parts of this file below (the Nov 11 "In progress" and the fix7 block) are history; the fix7 phone-run list is superseded by the block here.

## fix8: phone runs (marker on)

Routine, per run: the owner closes ALL stream tabs on the phone and says ready; only then is the run started; then the owner opens the URL the command prints (it already carries `?marker=1`) in a fresh page and stays on it until the run ends. One at a time:

```bash
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-base --set SESSION_MARKER=on --player-query marker=1
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-audio-sep --set SESSION_MARKER=on --set SESSION_AUDIO=separate --player-query marker=1
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-audio-off --set SESSION_MARKER=on --set SESSION_AUDIO=off --player-query marker=1
```

Read first: the "Independent check" table and its verdict line (agree / DISAGREE by N ms), then marker press>screen, press>screen (card) and stream total. Details: docs/briefs/m15/fix8/f8-6-proof-run-report.md.

## Where things stand

- **Decided by the owner (Nov 11, 2026):** a **custom** streaming stack (not Sunshine + Moonlight), to learn how production game streaming works and to grow into a product; lowest latency; play across the internet; several households in separate sessions; the server in containers; open-source parts wherever they exist; home PC (RTX 3080) first, cloud GPU later; latency logged per stage (input, host, encode, network, decode, display). Automation features go in shared host code for every build. Milestones: **M14** testing and fixes (owner is testing; fixes land on `m14`), **M15** the streaming prototype (branch `m15`, cut from `m14` on Nov 11), **M16** the friendlier app start (11 UX suggestions, all approved; mock-ups before building).
- **Built on `m15` (Nov 11, 2026), in four jobs:** **p1** the session summary's `stream` record, the report's Streaming section and its CSV (`packages/metrics`); **c1** the Linux session image and the player page, run with `tools/stream.sh build|up|down|url`; **a2** the automation interface in shared host code, off by default (the latency test card, the press probe, the `stats/stream` ingest); **c2** the player, the container's sampler and a benchmark reporting into the stats, with `tools/stream.sh bench` printing the Streaming report. The review of those four reports is the fix batch **f1** (this branch's first fixes).
- **First numbers (c2, 1080p60, viewer on the same PC):** capture-to-screen **126 ms** median (131 p95), of which the jitter buffer is 89 and the encoder 30; **press-to-screen 203 ms** median (323 p95, 114 presses) against gate 1's under-80 ms; 19.9 Mbit/s, no loss, no freezes, 224 % CPU, 635 MB, GPU 46 %. Two sessions at once: 37.5 and 37.6 delivered fps each, GPU 66 %. 720p: total 147 ms median.
- **Reachable from other devices:** WSL runs **mirrored** networking since Nov 11, so a session listens on the PC's own address; a phone or TV elsewhere on the Wi-Fi still waits on the owner's Windows Firewall rule (c1's report says which one).
- **After the fixes (f1, t1, g1):** latency tuned one setting at a time — baseline 183 ms capture-to-screen / 248 ms press, final 161 / 234 (three runs), every change inside the 36–44 ms noise, so no setting was made a default (t1); the one-frame VBV re-run on the corrected reading (the property is in kbits) stayed inside the same band, 195 mean against 220 (g1). `bench --viewer external` now times a phone, tablet or TV a person opens on the Wi-Fi instead of the headless Chrome (g1). Gate 1's 80 ms is still 154 ms away: Chrome's jitter buffer (110–188 ms measured here) and the app's own ~73 ms leg.
- **Next:** a real device (phone/TV) through `bench --viewer external` for its jitter buffer and press numbers, then the app's own frame rate and host leg, or M16's app-start work.

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

## fix7: phone runs

Written Nov 12, 2026, after the fix7 wrap-up
([fix7/n4-matrix-report.md](fix7/n4-matrix-report.md)): the three techniques are
built, each behind its own switch, default off. The headless Chrome in the distro is
not Safari, so a headless run only says whether a switch works and what it does to
the host and to Chrome — **the phone runs below decide**. One 60 s round with a 30 s
press phase each, in this order; type one at a time, open the URL it prints on the
iPhone, and stay on the page until it ends.

```bash
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-base
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-audio-off --set SESSION_AUDIO=off
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-audio-sep --set SESSION_AUDIO=separate
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-lowdelay --player-query lowdelay=1
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-nofec --set SESSION_FEC=false
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-noretx --set SESSION_RETRANSMISSION=false
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-gcc --set SESSION_CONGESTION=gcc
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-all --set SESSION_AUDIO=separate --set SESSION_FEC=false --set SESSION_RETRANSMISSION=false --set SESSION_CONGESTION=gcc --player-query lowdelay=1
```

There is no command for the host playout delay: it does not exist (n2-1). Compare
with the `bash tools/stream.sh stats --results …` line each run prints, and read
press-to-screen median first, then the jitter buffer; anything inside ~40 ms is noise.

## Cleaning up, if this is abandoned

`wsl --unregister tp-stream` removes the Linux install and everything in it (about 10 GB by now). The flash-worker modes are inert unless a brief asks for them.
