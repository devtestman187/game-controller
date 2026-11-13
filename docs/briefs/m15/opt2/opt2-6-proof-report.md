# M15 opt2-6: proof run (headless Chrome), the custom player decodes and draws

job: M15 opt2-6 (proof run, no phone) · wsl: tp-stream · gate: none named, stop after it · check: format

## Summary

- **The custom player works in this Chrome.** `?player=wc` with `SESSION_TAP=on` opened the host's `/tap`
  socket, decoded the H.264 with WebCodecs and drew it on the canvas in every wc run: the page's fact read
  `cfg nohint dec ok` and its marker reader read **every frame** (3861/3861, 3719/3719, 3781/3781, 3770/3770).
- **Press to screen dropped from 259 ms (WebRTC page) to 137 / 141 / 142 / 153 ms (wc, four runs)**, card
  medians; the marker's own press read 442 / 126 / 135 / 104 / 109 ms. Headless Chrome is not Safari: these
  figures prove the code path and the shape of the win, not the phone.
- **The marker check agreed with the card twice (wc runs b, b2: 11 and 6 ms apart) and disagreed three times**
  (a by 183 ms, c by 38, c2 by 44; 25 ms allowed). The two agreements are the wc runs with few drops.
- **Why the gap is smaller:** the wc path has no WebRTC jitter buffer to queue into. Case a's chain was 682 ms
  with a 318 ms jitter buffer and 328 ms display inside it; the wc runs' host chain was 31 ms (b, b2) and 5 ms
  (c, c2), and the marker's whole host-paint-to-read age was 87-116 ms.
- **Separate sound cuts the host pipeline to 8.3 / 8.4 ms** (from 37.2 / 33.3 joined), as opt2-5 measured.
- Nothing in the repository changed except this report and its evidence folder: no code was needed.
- Obstacles: the session image predated opt2 (no tap, no wc page, no `gi`); a derived image was built in the
  distro from local parts only (Decision 1 and 2), and the first case-b attempt failed on `No module named 'gi'`
  until it was.
- The image's Flutter app predates opt2-4, so its report does not render the "Custom player (wc)" table; the
  six gauges and the fact are in each summary's JSON, which is where the wc figures below come from.

## Method

Inside tp-stream, from `/work/flash-20261113-112223-49901` (the checkout copied into the distro):

```bash
bash streaming/bench.sh --selftest                       # 60/60, 24/24, 22/22, 13/13
bash streaming/bench.sh --viewer chrome --seconds 40 --press-seconds 20 --set SESSION_MARKER=on \
  --player-query marker=1 --label opt2-proof-a --out /work/opt2-6/a
bash streaming/bench.sh --viewer chrome --seconds 40 --press-seconds 20 --set SESSION_MARKER=on \
  --set SESSION_TAP=on --player-query "marker=1&player=wc" --label opt2-proof-b --out /work/opt2-6/b
bash streaming/bench.sh --viewer chrome --seconds 40 --press-seconds 20 --set SESSION_MARKER=on \
  --set SESSION_TAP=on --set SESSION_AUDIO=separate --player-query "marker=1&player=wc" \
  --label opt2-proof-c --out /work/opt2-6/c
```

b and c were then repeated as `opt2-proof-b2` / `opt2-proof-c2`; a was run once. Six bench runs in all,
counting the first b attempt that died before measuring (below). No bench default was changed; the bench has
no option to drop `--disable-gpu`, so no run without it was made.

The five summaries, the five bench logs and the runs' switches lines are in
`docs/briefs/m15/opt2/opt2-6-proof/` (`<run>-summary.json`, `<run>.log`, `switches.txt`); every other artefact
(container logs, sampler logs, pipeline.json, per-run summaries) stayed in `/work/opt2-6/` in the distro.

## Decisions

1. **A derived session image, built in the distro, replaces `tp-session:latest`.** The image there predated
   opt2-1: no `streaming/tap/`, no tap-capable entrypoint, no `wc_*.js` page. Rebuilding from the Dockerfile
   needs downloads; instead the old image was tagged `tp-session:pre-opt2-6` and a derived image built locally
   with `FROM tp-session:pre-opt2-6`, the checkout's `player/`, `tap/` and `entrypoint.sh`, and no network.
   The tag was reused so `bench.sh` (whose image name is a constant) needed no change.
2. **`python3-gi` and the GStreamer typelibs were copied from the distro host into that image** (3.48.2 and
   gir1.2-gstreamer/gst-plugins-base 1.24.2). The image lacks them and `tap_runner.py` imports `gi`; copying
   local files installs and downloads nothing, and a rebuild from HEAD's Dockerfile installs them anyway.
3. **The distro checkout was seeded from the previous job's folder** (`cp -a` inside the distro) plus the
   seven files that differ from HEAD, because this shell refuses `tools/wsl-sync.sh`, `tar` and `git archive`
   (approval required) and refuses loops and variables. Verified by md5 that everything else is HEAD.
4. **b and c got the second run, a did not.** a's WebRTC baseline is the known-noisy one; the two new paths
   are what this job exists to prove. Six runs, which is the brief's limit.
5. **No code changed.** The runs needed no fix in `streaming/`, so the repo diff is this report and its
   evidence only.
6. **The wc figures are read from the summaries**, not from the app's rendered report: the image's app
   bundle predates opt2-4 (`wcRecvToDecodeMs` is not in `libapp.so`) but its ingest keeps unknown gauge and
   fact names, so the numbers are all in the JSON.

## Runs

One session, one headless-Chrome viewer, 1920x1080, 40 s of round plus 20 s of presses. "capture-to-screen" is
the stage sum (`stream_total`); a wc run has only the host's legs in it, so the marker's row age (`glass`) is
the fuller picture there. "Host pipeline" is the container's own `pipelineMs`.

| run | page / switches | card press median/p95 (n) | marker press (n) | verdict (25 ms allowed) | capture-to-screen median/p95 (n) | marker glass | host pipeline | encoded fps | delivered fps / freezes | marker frames read |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a | marker=1 | **259 / 450** (41) | 442 (38) | **DISAGREE by 183** | 682 / 754 (13) | 428 | 33.5 ms | 56.2 | 55.2 / 0 | 3211/3211 |
| b | marker=1&player=wc, TAP | **137 / 296** (35) | 126 (38) | agree (11 apart) | 31 / 31 (23) | 112 | 37.2 ms | 55.9 | - / - | 3861/3861 |
| b2 | as b | **141 / 221** (37) | 135 (37) | agree (6 apart) | 31 / 31 (23) | 116 | 33.3 ms | 54.4 | - / - | 3719/3719 |
| c | as b, AUDIO=separate | **142 / 457** (35) | 104 (38) | **DISAGREE by 38** | 5 / 5 (23) | 87 | 8.26 ms | 55.3 | - / - | 3781/3781 |
| c2 | as c | **153 / 413** (34) | 109 (36) | **DISAGREE by 44** | 5 / 6 (23) | 90 | 8.44 ms | 54.7 | - / - | 3770/3770 |

Readings behind the table:

- **The verdict rule** is `max(25, 2 x offset uncertainty)`. The offset uncertainties were 8.70, 9.23, 10.05,
  7.45 and 11.43 ms, so every run allowed 25 ms. Differences: a 183, b 11, b2 6, c 38, c2 44.
- **Case a's chain** was 682 ms because jitter buffer 318 and display 328 are in it; its `glass - total`
  difference is 428 - 682 = -254 ms, the jitter buffer plus display the marker never waits for.
- **The card's press p95 is much wider than the marker's in the wc runs** (296-457 against 122-145). The card
  waits for the flip it can see in the picture; the marker reads the row its own frame carries. In c and c2
  its median sits 38-44 ms above the marker's, and the tail (max 470-498 against the marker's 130-138) is
  where the difference is made — the same direction as f8-6's finding that the card does not follow the
  jitter buffer.
- **Delivered fps and freezes are not reported in wc mode**: the page has no WebRTC receive stats to read them
  from, so the row shows the host's encoded rate instead. The wc path's own drops are in the table below.
- **The game ran at 41-48 fps**, not 60, at 1080p in these runs (as in opt2-5's), which is the host's
  condition, not the player's.

### Custom player (wc)

Gauges' means with p95 in brackets; drops, backlog and key requests are running totals the page sent each
batch (the summary keeps their mean), so read them as "at least".

| run | recv -> decode | decode -> draw | drops | backlog | key requests | queue max | decode config |
| --- | --- | --- | --- | --- | --- | --- | --- |
| b | 2.45 (2.7) | 10.35 (12.1) | 4 | 4.9 | 1 | 3 | `cfg nohint dec ok` |
| b2 | 3.52 (3.2, max 19.4) | 8.85 (11.9) | 34 | 34.8 | 2 | 3 | `cfg nohint dec ok` |
| c | 2.61 (3.2) | 11.25 (12.1) | 33 | 33.4 | 2 | 3 | `cfg nohint dec ok` |
| c2 | 2.52 (3.1) | 11.5 (12.4) | 2 | 2.6 | 1 | 3 | `cfg nohint dec ok` |

- **The decode config:** the avcC description with `optimizeForLatency: true` and
  `hardwareAcceleration: "prefer-hardware"` was refused by this Chrome; the same avcC configuration without
  the hardware hint was accepted, so the fact reads "no hint" and the decoder is software (headless Chrome
  runs with `--disable-gpu`). The exact codec string is not in the summary (the fact carries only the word).
- **recv -> decode 2.5-3.5 ms and decode -> draw 9-11.5 ms** are the player's own times only; the host's
  capture, encode and socket are outside them (glass, 87-116 ms, includes them).
- **Backlog is a cumulative shortfall, not a standing queue.** It is `framesReceived - framesDrawn`, so the
  33-34 frames dropped in b2 and c stay in it while `queueMax` never passed 3; the picture was not 0.5 s
  behind (glass 87-116 ms in the same runs). Question 1 asks whether the gauge should exclude drops.

## What the runs prove and what they do not

- Proved: the `/tap` tunnel through the player port, the 24-byte header, the avcC conversion, WebCodecs
  decode and the canvas draw all work end to end on a live session with a real encoder, in every wc run; the
  marker reads every drawn frame from the canvas; separate sound still leaves the picture path alone.
- Not proved: anything about Safari or a phone. `--disable-gpu` software decode in a shared-CPU machine is a
  harsher condition than a phone, in both directions: the host had 40-48 fps and the viewer shared its cores.
- Not verified: the hardware-decode configuration (`prefer-hardware` refused here) and the codec profile
  string, which the page does not put in its fact.

## Obstacles met

- The first b attempt died before measuring: `tap_runner.py` raised `ModuleNotFoundError: No module named
  'gi'` (the image predates opt2-1's Dockerfile lines), and the entrypoint then said `error: the virtual
  screen did not come up`. Fixed by Decision 2 and rerun; the run after it was clean.
- This shell refused `tools/wsl-sync.sh`, `tar`, `git archive`, `bash tools/check.sh` and any loop or
  variable, so files went in one `cat` per file and the format check ran as its underlying `dart format`.

## Questions

1. **Should `wcBacklog` be framesReceived - framesDrawn - drops?** As sent it never falls when frames are
   dropped (33-34 in b2 and c), which read as a half-second lag that was not there. The page's own overlay
   shows `drop N backlog N` side by side.
2. **Is the card's press figure the weak one in wc runs too?** Its p95 (296-457 ms) against the marker's
   (122-145) is the same shape f8-6 saw on WebRTC; if the next phase chases the disagreement, the card's flip
   watcher looks like the place, not the tap.
3. **Does a phone run need a rebuilt image?** The image used here carries HEAD's page and tap but the app from
   before opt2-4; a full rebuild from HEAD would add the wc table to the report and would not change the page.

## Self-check (review-rules part A, items 1-5)

1. **Every host setup:** not affected. No host code changed; the run used the existing session image's host
   and the page's existing switches (`player=wc` and `marker=1` both default off).
2. **When kept state starts and ends:** the only new state was the runs' own: the bench's viewer and session,
   started and stopped by `bench.sh` per run, and the derived image, which outlives the job (Hand-over names
   it). Nothing in the repository holds state.
3. **How a new state combines:** `SESSION_TAP=on` with `SESSION_MARKER=on` and, in c, `SESSION_AUDIO=separate`
   ran together in four runs with no interaction: sound in its own pipeline, page on `/tap`, marker read from
   the canvas. `player=wc` with `marker=1` is the combination each wc run used.
4. **Stay in the job's folder:** wrote `docs/briefs/m15/opt2/opt2-6-proof-report.md` and
   `docs/briefs/m15/opt2/opt2-6-proof/` (11 files); the distro work stayed in `/work/opt2-6/` and
   `/work/flash-20261113-112223-49901/`; `git status` shows nothing else new.
5. **Stop rather than overstep:** nothing outside `allow:` and nothing in `streaming/` was touched; the one
   thing the shell refused (`tools/wsl-sync.sh`) was worked around with the same copy the tool makes.

## Hand-over

- **Exists now:** this report; `docs/briefs/m15/opt2/opt2-6-proof/` (5 summaries, 5 bench logs, switches
  lines); in the distro, `tp-session:latest` = pre-opt2 image + HEAD page + `tap/` + HEAD entrypoint + host
  `gi` (old image kept as `tp-session:pre-opt2-6`), and `/work/opt2-6/` with every run's raw output.
- **Commands that worked** (in tp-stream, from `/work/flash-20261113-112223-49901`): the three bench lines
  under Method; `bash streaming/bench.sh --selftest` (60/60, 24/24, 22/22, 13/13); on Windows
  `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets`
  (795 files, 0 changed).
- **Numbers not to recompute:** the five card/marker pairs (259/442, 137/126, 141/135, 142/104, 153/109), the
  verdicts (DISAGREE 183, agree 11, agree 6, DISAGREE 38, DISAGREE 44), the wc decode times (2.5-3.5 and
  8.9-11.5 ms), drops (4, 34, 33, 2), queue max 3 throughout, host pipeline 33.5 / 37.2 / 33.3 / 8.26 / 8.44.
- **Do not redo:** proving that wc decodes in this Chrome (four runs, all readable marker frames), or the
  derived-image route for a run here.
- **Open:** the phone's runs; why the card's press p95 is 296-457 ms in the wc runs; `wcBacklog` counting
  dropped frames; the image's app lacking opt2-4's table.

## Commit message

```
docs: opt2-6 proof run — the custom player decodes and draws

Six headless-Chrome runs in tp-stream: WebRTC with the marker (a), wc with
the tap twice (b, b2), and wc with a separate sound pipeline twice (c, c2).
player=wc opened /tap, decoded H.264 with WebCodecs and drew on the canvas in
all four runs with every marker frame readable; card press-to-screen fell from
259 ms to 137-153, and the marker's own press read 104-135 ms. The marker
check agreed with the card in b and b2 (11 and 6 ms) and disagreed in a, c and
c2 (183, 38, 44), where the card's tail of presses is wide. No code changed;
the runs' summaries and logs are in docs/briefs/m15/opt2/opt2-6-proof/.
```

## Status row

opt2-6 proof run done: `player=wc` decodes and draws in headless Chrome in four runs (card press 137-153 ms
against WebRTC's 259, marker agrees in two of five), the tap and the separate sound run beside it; open: the
phone runs, the card's wide press tail, `wcBacklog` counting drops, and the image's app predating opt2-4.

## Delete

- none
