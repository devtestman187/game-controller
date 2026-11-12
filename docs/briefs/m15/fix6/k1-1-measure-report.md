# k1-1 measure: the host leg and the game's frame times as stages and gauges

## Summary

Built (tests first; each new test file fails on the code as it was):
- metrics: the three host stages and two resources in `stream_names.dart`; the host-leg table, its derived
  `raster>capture*` and the phantom-row rule in the new `report_stream_hostleg.dart` (report_stream.dart
  380 → 376 lines); the CSV, `stream_stats.dart` and the sample carry the new numbers.
- app: `automation/probe_leg.dart` (ring of 32 legs, `probe.legs` in `status`, wired from `pressProbe` and a
  persistent frame callback) and `automation/frame_timing.dart` (`frames.buildMs/rasterMs/slow/vsyncMs`);
  `automation/stream_ingest.dart` reads the two new fields.
- sampler: new `packages/metrics/lib/src/stream_host_legs.dart` (status answer → stage means + four frame
  gauges), ~14 lines in the bin, `pipelineJson(hostLegs:)`; `bench.sh` prints a round's frame stats;
  `docs/automation.md` and `streaming/README.md` document the fields and the tables.

Host-leg breakdown, probe run, medians (n = 21 sampler samples, 60 s, 1080p60):

| run     | press>tick | tick>built | built>raster | raster>capture* | press>screen | stream total |
| ------- | ---------- | ---------- | ------------ | --------------- | ------------ | ------------ |
| k1probe | 17         | 0          | 5            | 20              | 250          | 208          |

Game frames: probe 18.3 ms/frame, build 0.5 + raster 5.4 ms, 0.0 % slow; round 48.6 fps, 20.4 ms/frame,
build 1.2 + raster 7.8 ms, 1.3 % slow. Renderer: Impeller (OpenGLES/SDF) over Mesa d3d12 (bench.sh sets
`GALLIUM_DRIVER=d3d12`, adapter NVIDIA; gpu 49.8 %, no llvmpipe string in the log).

Biggest finding: the host leg is 42 ms here, not 66 — 22 ms in the stages, 20 ms derived; `tick>built` reads 0
because build is 0.5 ms and stages are whole ms (the `build ms` gauge has the decimals). The container game
paces at 20.4 ms/frame while build+raster is 9 ms, so phase 2's 3.7 ms/frame sits outside Flutter's own work.

Decisions: a real press is not wired (files outside `allow:`, `game_session.dart` 389 lines) — probe only;
whole-ms stages; the derived cell as `raster>capture*` with a footnote. Open: `gameFps` for the card?

## The two runs

Both in the distro, headless Chrome viewer, one session, 1920x1080, 60 s window, 1 simulated player.

- k1probe (`--probe`, card, presses every ~2 s): ready 6 s, window ended after 73 s. Run line: 1 viewer,
  2076 kbit/s against a 10000 ceiling, summary 4156 bytes, game 18.3 ms/frame, build 0.5 + raster 5.4 ms,
  0 % slow (no fps: the card reports none).
- k1round (arena round): ready 6 s, window ended after 76 s. Run line: 1 viewer, 9383 kbit/s against a
  10000 ceiling, summary 4184 bytes, game 48.6 fps, 20.4 ms/frame, build 1.2 + raster 7.8 ms, 1 % slow.

Pipeline, probe run (median/p95 ms): capture 2/2, encode 29/29, network 1/1, jitter 173/388, decode 3/3,
display 0/0, total 208/423, press>screen 250/414. The derived cell follows: 250 − (17 + 0 + 5) − 208 = 20.

Resources, the game's frames (median/p95):

| run     | game fps  | build ms | raster ms | frame ms  | slow %  |
| ------- | --------- | -------- | --------- | --------- | ------- |
| k1probe | -         | 0.5/0.6  | 5.4/5.7   | 18.3/18.8 | 0.0/0.0 |
| k1round | 48.6/54.0 | 1.2/1.4  | 7.8/9.2   | 20.4/24.4 | 1.3/4.0 |

Resources, CPU and pipeline (median/p95):

| run     | cpu %       | game cpu %  | enc cpu %   | gpu %    | enc fps   | pipeline ms |
| ------- | ----------- | ----------- | ----------- | -------- | --------- | ----------- |
| k1probe | 182.8/187.1 | 87.0/90.4   | 86.5/88.7   | 49.8/52.0 | 57.0/58.0 | 33.7/33.9  |
| k1round | 207.5/225.1 | 90.2/102.7  | 103.9/107.7 | 49.3/51.0 | 57.2/59.0 | 33.8/34.0  |

So the game (87-90 %) and the encoder (87-104 %) are the two CPU halves; the rest of the pipeline is small.

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** not affected — the change adds stages and gauges the host reports about itself; any
   host (TV, phone on this phone / show on this device, joined phone) sends the same `status`, and an older
   build simply sends no `probe.legs`/`frames` (the sampler then writes no host stages and no frame gauges,
   shown by `stream_host_legs_test.dart`'s null cases).
2. **When kept state starts and ends:** the leg ring starts at the press and ends when the frame's timings
   arrive (or at the next press), keeps the last 32 and stops with the provider's `onDispose`; the frame
   window starts at the first frame after a read and is emptied by the read; both do nothing when no press or
   no frame happens (`probe_leg_test.dart` "records nothing without a press", `frame_timing_test.dart`
   "a stopped window counts nothing" and the empty second `take()`).
3. **How a new state combines:** not affected — nothing pauses, hides or blocks input; the recorder listens to
   the existing scheduler callbacks and the card's flip is unchanged, so pause/away/ready/drop/results/leaving
   behave as before.
4. **Stay in the job's folder:** every file written is this report, `docs/briefs/m15/fix6/k1-1/`, the code and
   docs in `allow:`; the bench wrote only `/work/stream-bench/*` and `/work/*.log` inside the distro.
5. **Stop rather than overstep:** one gap was left rather than overstepped — a real controller press cannot
   feed the ring without touching files outside `allow:` (`game_session.dart` is 389 lines), recorded under
   Decisions; the sync and check scripts refused by the sandbox were worked around and are reported.

## Checks

- Windows, before the bench: `tools/check.sh format analyze metrics host` — all passed (61 s): format,
  analyze, metrics 155 tests, host 425 tests.
- Distro, after the bench: `tools/check.sh format analyze metrics host tv` — format PASS, analyze PASS,
  metrics 155 tests PASS, tv PASS (20 s), host 424/425. The one failure is
  `automation_server_test.dart: a body with no length stops being read at the cap, and is refused`: it passes
  on Windows and fails on Linux although `automation_body.dart`, `automation_server.dart` and
  `automation_api.dart` are byte-identical between the two trees (md5 compared), so it is the platform, not
  this job. `streaming/bench.sh` passes `bash -n`.

## How the runs were done

The sandbox refused `tools/wsl-sync.sh` (it needs `tar`) and later `tools/check.sh`/`dart` on Windows, so the
tree went into the distro as: copy the previous job's synced tree (`cp -a /work/flash-20261112-080327-3495
/work/flash-20261112-093948-5445`), then one `cat <file> | wsl -d tp-stream -u root -- bash -lc 'cat > <path>'`
per changed file (25 files, including the newer `automation_server_test.dart`); the streaming stack and the
report binary match in size (`wc -c` totals 103186 on both sides). Commands that worked:

```
docker build -f streaming/Dockerfile -t tp-session:latest .      # 2 min, in the distro at the tree's root
streaming/bench.sh --probe --seconds 60 --label k1probe --out /work/stream-bench/k1probe
streaming/bench.sh --seconds 60 --label k1round --out /work/stream-bench/k1round
cd packages/metrics && PATH=/opt/flutter/bin:$PATH dart run bin/report.dart /work/stream-bench/k1probe/summaries
```

started detached with `setsid nohup … > /work/<log> 2>&1 < /dev/null &` (a plain `&` dies with the shell).
No container was left running (`docker ps` empty). Results: `docs/briefs/m15/fix6/k1-1/` holds
`k1probe0-summary.json`, `k1round0-summary.json`, `k1probe-report.txt`, `k1round-report.txt`, and
`docs/briefs/m15/bench-results/20261112-095941/k1probe/` and `…/20261112-100128/k1round/` hold the same
summary and report.

## Decisions

1. **A real press is not wired into the ring.** The places a phone's press arrives (`connection`,
   `server_game_host`) and `game_session.dart` (389 lines) are outside `allow:`; the brief's fallback applies,
   so the probe stays the only source. The bench's simulated player and the probe set the same `GamepadState`
   a real press sets after it arrives, so the probe is the same path once the state is on the host.
2. **Host stages are whole ms** (`Map<String,int>`, as capture/encode are), so a 0.5 ms build prints `0`; the
   engine's own numbers stay in the `build ms`/`raster ms` gauges at two decimals.
3. **The derived cell is `raster>capture*`** with one footnote line under the table: adding a table-shaped note
   would have meant changing `plainTable` for one column.
4. **Only the sampler polls `frames`**, because a read empties the window; the bench's own status reads can
   steal one window, which is why the run lines print frame stats from the sampler's gauges.

## Hand-over

What exists: the host leg as three stages and `raster>capture*`, the game's frame stats as gauges, both in the
stream stats framework; the app's ring and frame window in `automation/`; the sampler code in
`packages/metrics/lib/src/stream_host_legs.dart`; a probe run's report shows the host-leg table with no extra
flag and a round's run line ends with `game <fps> fps, <ms> ms/frame, build <a> + raster <b> ms, <p>% slow`.

Compare against (k1probe / k1round, above): press>tick 17, tick>built 0 (build 0.5 ms), built>raster 5,
raster>capture* 20, press>screen 250, total 208; round game 48.6 fps, 20.4 ms/frame, build 1.2, raster 7.8,
slow 1.3 %, game cpu 90.2 %, enc cpu 103.9 %, gpu 49.3 %.

Suspicions, ranked by measured cost: (1) the game paces at 20.4 ms/frame while its build+raster is 9 ms, so
~3.7 ms/frame is spent outside Flutter's own work — engine pacing/vsync in the container, worth 22 % of the
budget and the reason a press waits ~17 ms for its frame; (2) `raster>capture*` 20 ms — compositor commit, the
60 Hz capture sampling and the host/container clock gap, not measured separately yet; (3) `built>raster`
5-8 ms is Impeller's d3d12 raster, the honest cost of the 1080p frame.

Do not redo: the stage/gauge plumbing, the CSV/report columns or the sampler's status read; and do not make the
probe path faster than a real press (owner's rule) — the ring holds probe samples only, which phase 2 inherits.

## Commit message

stats: measure the host leg and the game's frame times

Host leg as three stages (press>tick 17 ms, tick>built 0 ms with a 0.5 ms build,
built>raster 5 ms) plus the derived raster>capture* (20 ms) in a new report file;
the game's frames as gauges (18.3 ms/frame probe, 48.6 fps / 20.4 ms/frame round,
1.3 % slow); the app records a ring of probe legs and a frame window in status;
the sampler turns both into stages and gauges; a round's run line ends with the
game's frame stats. Results in docs/briefs/m15/fix6/k1-1/.

## Status row

k1-1 measure: host leg and game frame times in the stats framework, probe report prints press>tick 17 |
tick>built 0 (build 0.5) | built>raster 5 | raster>capture* 20 | press>screen 250 | total 208, round game
48.6 fps 20.4 ms/frame 1.3 % slow (Impeller over d3d12, game cpu 90 % vs enc 104 %); open: a real press is not
wired into the ring (files outside allow) and the probe's press count is not printed.

## Delete

- none from this job. Already untracked or modified before it, and not mine:
  `docs/briefs/m15/bench-results/20261112-092537/`, `docs/briefs/m15/c2/results/bench/`,
  `docs/briefs/m15/fix6/run-base` and the six `tv_test_app/{linux,windows}/flutter/generated_*` files.
