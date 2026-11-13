# M15 fix8 phase 6 (run): the independent check on headless Chrome, and what the marker costs

## Summary

- **Setup:** six 45 s runs in `tp-stream`, headless Chrome, image `tp-session:latest` (`ea9d8634c538`); the synced
  checkout `/work/flash-20261112-220045-33184` matches HEAD's player files and entrypoint (sha256), so no rebuild.
- **Every frame readable** in all four marker runs (2209/2209, 2329/2329, 2562/2562, 2751/2751); unreadable 0 by
  checksum, sync, canvas and other.
- **The verdict flips between two identical probe runs:** marker press>screen 369 against the card's 241
  (`DISAGREE by 128 ms`, 25 allowed) in run 1, 236 against 213 (agree, 23 ms apart) in run 2.
- **The marker's press follows the run's jitter buffer, the card's does not:** jitter 259 → 109 ms, marker
  369 → 236 (−133), card 241 → 213 (−28); f8-3's run (jitter 258) had the same 134 ms gap.
- **Headless Chrome cannot say whose press number is right** — it says the check works; the phone decides, where the
  gap was 61-139 ms.
- **Clock offset uncertainty** 8.44 / 9.17 (probe) and 9.13 / 8.73 ms (round), from RTT 16.9-18.3 ms, so the rule's
  25 ms floor was the allowance everywhere.
- **rVFC:** nine fields (presentationTime, expectedDisplayTime, receiveTime, processingDuration, presentedFrames,
  width, height, mediaTime, rtpTimestamp), no `captureTime`, `markerDisplayFrom` `expected-receive`, as in f8-3.
- **Cost, probe (card, ~2.1 Mbit/s),** on runs 1/2 against off: game 20.09 / 19.85 vs 17.92 ms a frame, raster
  6.65 / 6.11 vs 5.53, build 0.67 / 0.65 vs 0.49, delivered 53.6 / 56.2 vs 56.4 fps, host CPU 180 / 182 vs 178 %,
  GPU 52.8 / 48.4 vs 48.5 %, encoder CPU 84.9 / 87.2 vs 85.9 %, received 2059 / 2124 vs 2100 kbit/s.
- **Cost, round (1080p60, ~9.2 Mbit/s),** on runs A/B against off: raster 11.13 / 11.53 vs 8.37 ms, slow frames
  12.6 / 12.3 vs 1.5 %, game 45.3 / 52.2 vs 46.2 fps, host CPU 220 / 229 vs 206 %, encoder CPU 105.3 / 106.9 vs
  102.0 %, GPU 48.1 / 49.0 vs 47.2 %, received 9186 / 9076 vs 9348 kbit/s; the slow share repeated once.
- **An upper bound for a phone:** the page's read (5.0-6.7 ms a frame) shared the container's machine here; f8-2
  measured the row alone at +0.2 ms build and +0.5 ms raster.
- **No code changed**; the **Phone runs** block has the three owner commands and what to read first.

## Decisions

- **No code change.** All six runs read every frame with no unreadable reason; the 128 ms disagreement in run 1 is a
  measurement finding, not a broken row, and the brief allows a fix only for a broken marker.
- **The sixth (spare) run repeated the round with the marker on**, not another probe: the round-on run's slow-frame
  share (12.6 %) was eight times the off run's, and that is the one cost figure the table would otherwise state from a
  single run. The repeat agreed (12.25 %), so it is reported as the marker's round cost, not chased further.
- **The probe off run is one run, the round off run is one run**, as the brief counted them (2 + 1 + 1 + 1 + spare);
  no attempt was made to widen the off side.
- **The run logs** (bench's own output) are kept beside each summary in `f8-6-proof-run/`, because the report quotes
  ready times and window lengths from them; they are 340-405 bytes each.
- **The verdict lines were computed from the report's rule** (`report_stream_marker.dart:138-156`: agree while the two
  press medians differ by less than `max(25, 2 × offset uncertainty)`) by hand from the summaries' medians, because
  `dart run` needs an approval this shell does not have. The inputs are the two medians and the uncertainty mean, all
  in the JSON in `f8-6-proof-run/`.
- **"Cost" is read as on-minus-off within the same run type** (probe against probe, round against round); the probe's
  card and the round's game are not compared with each other.

## The runs

All in `/work/flash-20261112-220045-33184`, one at a time, no container left afterwards (`docker ps -a` empty). The
45 s window ended after 53-60 s including start-up, which is the normal bench overhead.

| Run | Switches | Type | Window | Summary |
| --- | --- | --- | --- | --- |
| `f8-6-on1` | `SESSION_MARKER=on, player-query marker=1` | probe 45 s | 58 s | 5763 bytes |
| `f8-6-on2` | the same | probe 45 s | 53 s | 5759 bytes |
| `f8-6-offprobe` | `none` | probe 45 s | 54 s | 4154 bytes |
| `f8-6-roundon` | `SESSION_MARKER=on, player-query marker=1` | round 45 s | 55 s | 5353 bytes |
| `f8-6-roundoff` | `none` | round 45 s | 55 s | 3883 bytes |
| `f8-6-roundon2` | the same as `f8-6-roundon` | round 45 s | 60 s | 5355 bytes |

Each run's own line says what it was given: the on runs wrote `switches: SESSION_MARKER=on, player-query marker=1,
player-options none` and the off runs `switches: none`, and the off summaries carry no `marker*` key and
`stream_display` 0, as before this batch. The bench's ready line is `f8-6-on10: ready after 6s` (4-6 s in all six).
Files: `docs/briefs/m15/fix8/f8-6-proof-run/` (`README.md` maps each run to its command).

## Q1. Does the independent press-to-screen agree with the existing one?

Per run, medians with p95 in brackets (ms), from the summaries' `stream.viewers[0]`:

| Run | marker press>screen | card press>screen | differ | allowed | verdict |
| --- | --- | --- | --- | --- | --- |
| `f8-6-on1` | 369 [446], n=88 | 241 [406], n=89 | 128 | 25.0 | DISAGREE by 128 ms |
| `f8-6-on2` | 236 [412], n=84 | 213 [398], n=85 | 23 | 25.0 | agree (23 ms apart) |

Beside them, the marker's own times and the chain, medians: `marker_glass` 349 (n=17) and 215 (n=16); `stream_total`
545 (n=12) and 263 (n=8); glass − total −196 and −48; `markerDecodeDisplayMs` mean 251.7 and 156.1; callback lateness
mean 0.0 and −0.01.

- **Raw medians:** one run agrees inside the rule's floor, one disagrees by five times it. The rule's verdict is
  therefore only as good as the run it is given, and a single phone run will not settle the phone either unless its
  jitter state is known.
- **What moves:** between the two runs the jitter-buffer median fell 259 → 109 ms, the marker's press fell 133 ms, the
  card's fell 28 ms, and `marker_glass` fell 134 ms. Within a run, the marker's per-batch medians and the card's track
  each other's spread (p95 446/406 in run 1, 412/398 in run 2), so the disagreement is in the middle, not the tail.
- **Read as evidence about the audit's fault 1:** the marker's press includes the playout wait the chain's jitter stage
  measures; the card's does not follow it. That is the "press does not follow the chain" finding of f8-1, now visible
  in a second measurement. It is not proof: n = 2 runs here and one in f8-3, and the card's watcher is where f8-1
  suspected the loss.
- **All frames readable:** `markerFrames` = `markerReadable` in all four marker runs; `markerChecksumBad`,
  `markerSyncBad`, `markerCanvasBad` and `markerOtherBad` are 0 everywhere, at 1080p, 10 Mbit/s ceiling, ~2.1 and
  ~9.2 Mbit/s received.
- **Clock offset:** `markerOffsetMs` mean 3653.96 (run 1), 1756.99 (run 2), 1949.33 / 3592.10 (rounds) — arbitrary
  per boot; what matters is the uncertainty: 8.44 and 9.17 ms on the probes, 9.13 and 8.73 on the rounds, from RTT
  means 16.88 / 18.34 / 18.26 / 17.47 ms (max 20.7-23.0). The offset stayed put inside each run (p95 within 4 ms of
  the mean).
- **rVFC fields:** the nine above in every marker run, values min/median/max as f8-3 printed them (e.g. run 1
  `receiveTime 49.15 50.68 52.13`, `processingDuration 0.8 2.4 7.6`, `presentedFrames 2447 2524 2599`);
  `captureTime` absent, not 0.

## Q2. What does the marker cost

Probe runs (the latency card fills the picture, so the bitrate is not the game's):

| Run | Marker | received kbit/s | delivered fps | game ms/frame | build + raster ms | host CPU % | GPU % | encoder CPU % | encoder % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `f8-6-offprobe` | off | 2100 | 56.44 | 17.92 | 0.49 + 5.53 | 178.19 | 48.47 | 85.93 | 6.29 |
| `f8-6-on1` | on | 2059 | 53.59 | 20.09 | 0.67 + 6.65 | 180.10 | 52.81 | 84.87 | 6.25 |
| `f8-6-on2` | on | 2124 | 56.19 | 19.85 | 0.65 + 6.11 | 181.76 | 48.41 | 87.21 | 6.18 |

Round runs (the game, 1080p60):

| Run | Marker | received kbit/s | delivered fps | game fps | game ms/frame | build + raster ms | slow % | host CPU % | GPU % | encoder CPU % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `f8-6-roundoff` | off | 9348 | 58.35 | 46.23 | 21.44 | 1.39 + 8.37 | 1.47 | 206.33 | 47.22 | 102.03 |
| `f8-6-roundon` | on | 9186 | 57.06 | 45.32 | 21.89 | 1.29 + 11.13 | 12.61 | 220.07 | 48.11 | 105.30 |
| `f8-6-roundon2` | on | 9076 | 57.61 | 52.19 | 19.45 | 1.29 + 11.53 | 12.25 | 229.35 | 49.00 | 106.92 |

- **The row plus the reader costs 0.6-1.1 ms of raster in a probe and ~3 ms of raster in a 60 fps round**, and at 60
  fps it turns about one frame in eight slow (1.5 % → 12.3-12.6 %), reproducibly. Delivered fps loses 0.7-1.3, the
  received bitrate 160-270 kbit/s at the same ceiling, encoder CPU gains 3-5 points and GPU 1-2 points. The row is
  912 x 16 px, so its own pixels do not explain these; the next point is what does, as far as these runs can say.
- **Where the ~3 ms comes from is not this run's to say.** The page's read is 5.0 ms a frame in probes and 6.6-6.7 ms
  in rounds (`markerReadMs` mean, p95 6.9-7.6), i.e. the viewer holds about a third of a core on the same machine as
  the container; f8-2, with the row on and no reader, measured +0.2 ms build and +0.5 ms raster. A phone run has the
  reader on the phone, so the host side should cost less there — and this is a question for the phone numbers, not a
  code change here.
- The off runs' summaries are byte-for-byte the shape the report always printed (no `marker*` name), so a run with
  everything off is unaffected.

## Phone runs

Three runs, one at a time, on Windows (each copies this checkout into `tp-stream` and runs the bench there). Every
flag exists as spelled in `tools/stream.sh` (usage 131-148) and `streaming/bench.sh` (138-167), and every session
switch exists in `streaming/entrypoint.sh` (`SESSION_AUDIO` line 84, `SESSION_MARKER` line 156); nothing needed
correcting.

```bash
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-base --set SESSION_MARKER=on --player-query marker=1
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-audio-sep --set SESSION_MARKER=on --set SESSION_AUDIO=separate --player-query marker=1
bash tools/stream.sh bench --viewer external --seconds 60 --press-seconds 30 --label phone-marker-audio-off --set SESSION_MARKER=on --set SESSION_AUDIO=off --player-query marker=1
```

**How the URL comes.** A few seconds after the command starts, the run prints one line per session:

```
phone-marker-base0: open http://<the PC's LAN address>:<port>/?marker=1 on a phone, tablet or TV on the home network
```

That exact address — with `?marker=1` already on it — is the page to open, and the run then waits up to 180 s for the
phone to register, saying `a viewer registered after Ns` when it does. Headless Chrome is not used in these runs.

**The routine, per run:**

1. Close **all** stream tabs on the phone (a page loaded before the session is ignored: f8-5), then say ready.
2. Start the command.
3. When the printed line appears, open that URL in a fresh page on the phone and stay on it until the run ends
   (`the window ended after Ns`). The run plays the round for 60 s, then the latency card for 30 s of presses.

**Read first:** the Streaming section's **Independent check** table, and under it the verdict line
(`independent check <session>/v1: agree (...)` or `DISAGREE by N ms (...)`), then the `marker press>screen`,
`press>screen (card)` and `stream total` rows. The run prints
`report again with: bash tools/stream.sh stats --results docs/briefs/m15/bench-results/<stamp>/<label>`; that command
prints the same section again. Compare the three runs' verdicts and presses by hand: a difference inside 25 ms is
agreement by the rule, and the run's `clock offset` uncertainty widens that only if it passes 12.5 ms.

## Checks

- `tools/check.sh format analyze metrics host`: **PASS** format (3 s), **PASS** analyze (17 s), **PASS** metrics
  (162 tests), **PASS** host (442 tests); all checks passed in 121 s.
- Six bench runs, each ending with its own summary line and `results in` line; no container and no headless Chrome
  left afterwards (`docker ps -a` empty, no `chrome-headless` process), no scratch file left in the repository. The
  distro's `/work/f8-6/` holds the runs' raw output (bench's own folder pattern); nothing was mounted or installed.
- `git status` lists the six `tv_test_app/*/generated_*` files as modified; their mtime is 22:00, the job's own
  start, before this job's first command. That is the line-ending rewrite f8-2's hand-over names, not a file this job
  wrote (and not in `allow:`), so it is left as it is.

## Self-check (docs/review-rules.md part A, items 1-5)

1. **Every host setup:** not affected — no code changed; the marker row and the page's reader are off unless a run
   asks for them, and the two runs with `switches: none` produced the report and picture this batch always had.
2. **When kept state starts and ends:** unchanged and ended — each run removed its container and its viewer at exit;
   what stayed is its output folder under `/work/f8-6/` (profiles, logs), which no process holds open.
3. **How a new state combines with the others:** no new state; the row is a paint-only overlay above the shell and the
   reader a page option, neither pauses, hides nor blocks input (the strip is `IgnorePointer`).
4. **Stay in the job's folder:** wrote `docs/briefs/m15/fix8/f8-6-proof-run/` (19 files) and this report; the runs
   wrote only under `/work/f8-6/` in the distro.
5. **Stop rather than overstep:** no file outside `allow:` touched, no default changed, no install; the one thing the
   shell refused (`dart run`) is reported under Decisions instead of worked around.

## Hand-over

- **Exists now:** this report and `docs/briefs/m15/fix8/f8-6-proof-run/` (six summaries, six `switches.txt`, six run
  logs, a README mapping run to command). No code changed.
- **What worked:** `tools/wsl-sync.sh tp-stream` → `/work/flash-20261112-220045-33184`; then inside the distro
  `cd /work/flash-20261112-220045-33184 && bash streaming/bench.sh --probe --seconds 45 --set SESSION_MARKER=on
  --player-query marker=1 --label f8-6-on1 --out /work/f8-6/on1` (and the five others, README table);
  `tools/wsl-fetch.sh tp-stream /work/f8-6/fetched/<file> docs/briefs/m15/fix8/f8-6-proof-run/<file>`. No image
  rebuild was needed: the player files and entrypoint in `tp-session:latest` are sha256-identical to HEAD.
- **Numbers not to recompute:** every frame readable (2209/2209, 2329/2329, 2562/2562, 2751/2751); marker press 369
  vs 241 (disagree 128) and 236 vs 213 (agree 23); jitter 259 → 109; offset uncertainty 8.44 / 9.17 / 9.13 / 8.73 ms;
  round cost +2.8-3.2 ms raster and 12.3-12.6 % slow frames; probe cost +0.6-1.1 ms raster.
- **Do not redo:** verifying that the row survives encode/decode at 1080p (four runs, zero unreadable), or the rVFC
  field list (nine, no `captureTime`), or the image check.
- **Open:** the phone's three runs; whose press figure is right when the jitter buffer is deep (the card's does not
  follow it here, the marker does); whether the ~3 ms round-time raster cost in this shared machine repeats when the
  reader is on the phone instead.

## Questions

1. **Should a round-type run also have a press phase?** The brief's cost runs had none, so no run shows the marker's
   press and the card's press in the game's picture; the probe-only evidence above is all there is.
2. **The card's press figure not tracking the jitter buffer** is the same finding as f8-1's fault 1, now with a second
   measurement. If a phone run also shows it, the next fix is probably in the card's flip watcher, not in the marker —
   say whether f8-7 should chase it.
3. **Is 12 % of frames slow a phone concern?** It is measured where the reader shares the host machine; on a phone run
   the host should be cheaper. If the phone run still shows it, the row's raster cost is worth a design look (a
   smaller repaint region, or a row drawn into the texture once a second instead of every frame).

## Commit message

docs: fix8 phase 6 — the marker's proof runs and what it costs

Six 45 s runs in tp-stream (two probe runs with the marker on, a probe off, a
round on, a round off, and one repeat of the round on). Every frame was
readable in all four marker runs; the two presses agreed in one run (23 ms)
and disagreed in the other (128), and the marker's figure followed the run's
jitter buffer (259 → 109 ms) while the card's did not. The offset uncertainty
stayed at 8.4-9.2 ms; headless Chrome gave nine rVFC fields with no captureTime.
The row plus the reader costs 0.6-1.1 ms of raster in a probe and ~3 ms, with
12 % slow frames, in a 60 fps round where the reader shares the machine.

## Status row

M15 fix8 phase 6 (proof run) done: the marker reads every frame in six tp-stream runs, the verdict flips with the
run's jitter buffer, and its cost is ~0.6-1.1 ms raster (probe) / ~3 ms plus 12 % slow frames (round); open: the
three iPhone runs, and whether the card's press figure is the one at fault.

## Delete

- none
