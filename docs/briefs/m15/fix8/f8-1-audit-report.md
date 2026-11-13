# M15 fix8 phase 1 (audit, read-only): the Safari stream tables and the 61-139 ms gap

## Summary

**NO SINGLE DEFINITE FAULT.** No code path and no recorded value shows one fault that fully explains the 61-139 ms gap; the
data point at one explanation (an unmeasured tail glass-ward of the chain) and at several smaller ones.

- **The chain is short by construction.** Its last stage is `stream_display` = `max(0, presentationTime −
  expectedDisplayTime)` (metrics.js:85-88, reporter.js:262), so it reads 0 whenever a frame is presented *at or before*
  the planned time and never measures decoded → glass (0 with max 0, n=33, in all four runs): it ends at the plan.
- **After the host legs, 36, 104, 117 and 73 ms are left over** (press median − the three host-leg medians − total). That
  residue is the whole gap and nothing measured accounts for it.
- **The press does not follow the chain**: 179, 187, 169, 223 ms against totals of 118, 61, 30, 130. The run with the most
  host headroom (audio off, encode 3 ms) has the *biggest* gap, which a host-side bias (the clock offset) cannot produce —
  a leaner host means a *faster* `/status` answer and thus a *smaller* bias.
- **Best fit (inference):** Safari's `jitterBufferDelay` is only part of the playout wait; the rest sits in WebKit's video
  renderer queue, compositing, the vsync wait and the panel, none of which any field covers. Under that reading press is
  the more trustworthy of the two phone numbers, and the jitter-buffer stage is a partial one.
- **Press-side defects found** (p95/max, not medians): the patch is read every 8th frame while no press waits (≤133 ms
  late, latency_probe.js:27, 64); a press can be matched to a later cadence or next-press flip up to 499 ms after it
  (latency_probe.js:131-151) — all four maxima (418-470) sit just under that cut; presses are polled every 200 ms.
- **The chain's `total` is a sum of six stage medians** from different windows and two sources (stream_stats.dart:297-320),
  not any frame's time; its p95/max are sums of stage p95s/maxes (documented), not percentiles.
- **Safari gives**: `jitterBufferDelay`/`jitterBufferEmittedCount`, `totalDecodeTime`/`framesDecoded`,
  `framesPerSecond`, `freezeCount`/`totalFreezesDuration`, the candidate pair's RTT, frames received/decoded.
  **It does not give**: `estimatedPlayoutTimestamp` (no `audioSyncMs` in any run), `concealedSamples`/`totalSamples` (no
  `audioConcealedPct`), a useful `presentationTime − expectedDisplayTime` (always 0), the spec's `framesDropped` (the page
  derives it), and no stage at all from encoder output to the glass.
- **For phase 2:** a drawn host clock measures the picture's age, but that age is `(page clock + /clock offset) − drawn
  clock`, so it inherits the very offset this audit suspects. The marker check must also time the press *inside the
  picture* (press host time drawn in the flip cell, read against the clock in the same frame — no offset), and `/clock`
  should return the host's own receive/answer stamps so the offset's handling part can be subtracted.

## Decisions

- Read-only: no file changed but this report; no distro, no run, no new script.
- "chain total" = the `stream_total` stage of each summary (source `stages`); "press" = `press_to_screen` (source `probe`);
  "gap" = press median − total median. "Host leg" = host_tick + host_build + host_raster medians, as the host-leg table's
  derived cell does (report_stream_hostleg.dart:63-74).
- A summary keeps only aggregates, not the raw getStats dictionaries or the per-press samples, so "which fields Safari
  gives" is read off the stage/gauge/counter names that are present or absent in the four `0.json` files; every such
  reading is marked *(inference)* where the absence of a name could have another cause.
- Each of the four folders holds exactly one run (one `0.json` and a `switches.txt`); I treated each as the run.
- Arithmetic was done by hand from the JSON values; no scratch file and no script (none is allowed by `allow:`).

## Q1. What stamps a probe press, and what the host sends

- `pressProbe` reads `gameHostProvider.nowMs` **before** it applies the press (host_automation.dart:186), then sets the
  local player's pad (`local.set(...)`, :191), records the leg (`ProbeLegRecorder.press(atMs)`, :193), adds the release
  post-frame callback, asks for the frame (`scheduleFrame()`, :198), flips the card (:202) and answers
  `{'player', 'button', 'hostMs': atMs}` (:203).
- So the stamp is the host clock at the moment the host had the press, not the moment the frame ran; the app draws the
  flip in the *next* frame (latency_test_card.dart:74-81 via the listener :87-89), which is the leg's `tick`.
- The bench reads `hostMs` from that answer (bench.sh:467-469) and POSTs it to the relay's `/presses` (bench.sh:478); the
  page polls `/presses?since=` every 200 ms (reporter.js:33, latency_probe.js:80-87) and keeps `hostMs` with its own
  `performance.now()` arrival (`receivedAtMs`, latency_probe.js:86).
- The card flips on the press *and* on its own 500 ms cadence (latency_test_card.dart:24, 64-70), and the bench presses
  once per flip it sees (bench.sh:455-483, `sleep 0.4` at :481), so presses follow flips at about 0.52 s (58 in ~30 s).

## Q2. "On screen": what is counted, where, how often, on which clock

- **The event:** a luminance flip of an 8x8 patch of the video element at a quarter in (`patchSizePx = 8`,
  latency_probe.js:18, 110-111), averaged down to 1x1 by `drawImage(video, x, y, 8, 8, 0, 0, 1, 1)` +
  `getImageData(0, 0, 1, 1)` (:113-114), and classified by `FlipWatcher` with light ≥ 120 / dark ≤ 80
  (latency_probe.js:20-24, 49; metrics.js:154-185). A reading between the thresholds is ignored.
- **Where it is read:** inside the `requestVideoFrameCallback` callback (`onFrame`, reporter.js:147-161, `watch` at
  :158); a browser without rVFC falls back to `requestAnimationFrame` (:137-145) and then has no display stage. Reading
  `nowMs, frames` — the callback's time argument, not `metadata.presentationTime`.
- **How often:** every frame while a press waits; every 8th frame otherwise (`patchEveryNthFrame = 8`, latency_probe.js:27;
  guard at :64). At 59.2 delivered fps that is a 133 ms grid when idle.
- **Which clock:** the rVFC callback's time, made host time by adding the median `/clock` offset (`_toHostMs`,
  reporter.js:199-203). The sample is `hostAtFlip − press.hostMs` (latency_probe.js:138-147).
- **How that stamp relates to the glass:** the HTML spec calls the rVFC time the moment the frame was *submitted to the
  compositor*; if WebKit follows it, the stamp is *before* the panel by at least the compositing/vsync wait, so
  press>screen *understates* by that much. Whether WebKit fires before or after the frame reaches the glass cannot be
  established from these files *(inference; the marker check's frame counter settles it)*.
- **Can `drawImage` return another frame than the one on glass?** Unknown from the files. `drawImage(video)` copies the
  element's current frame; whether that is the presented one, one behind (a stale copy) or one ahead (decoded but not yet
  composited) is a WebKit detail. A stale copy would add up to one frame (≤17 ms) to every sample *(inference)*.
- The pixel readback itself happens *after* `nowMs` was fixed for that callback, so any readback cost is not in the stamp
  (it understates by that cost, a few ms at most).
- `flipsSeen` counts sightings but is never reported (`_noteFlip`, latency_probe.js:123-128 only POSTs `/flips`), so the
  summary cannot say how many flips the page saw versus how many presses it matched.

## Q3. How the two clocks are related

- One `fetch('/clock')` every 10 s plus one at `start()` (reporter.js:36, 102-108); the last **5** offsets are kept and
  their **median** is used (:39, 191-202). Each sample is a midpoint estimate: `offset = hostMs − (sentAt + receivedAt)/2`
  (:190).
- The host value comes from `/status` (`'hostMs'`, host_automation.dart:68) through the relay's own local call
  (serve.py:155-159, 180-181), so the host reads its clock *after* the request has travelled and has been scheduled on the
  app's isolate. That is a one-sided, positive bias: the offset is too large by roughly the time from the request's
  arrival to line 68, minus the request's network one-way.
- **Quantified where the data allows:** rttMs mean 4.1 / p95 8 (base; 4.45 in sep), jitterMs 3.73 — the network half of
  the error is ≤ ~4 ms. The host half is unmeasured but bounded by the app's own frame interval: gameFrameMs mean 17.78 /
  max 23.34, slowFramePct 5.19 (base JSON). So **the offset's plausible error is ~0 to +25 ms**, not 100.
- The offset is applied **to the flip only** (reporter.js:199-203). The press is already host time; the chain uses no
  cross-clock value at all (the host stages are copied in as numbers, :288-291). Therefore an offset error lands 1:1 in
  the gap and in nothing else.
- A loaded Wi-Fi biases it by half the path asymmetry; a single stalled fetch cannot move a 5-sample median much (2 of 5
  would), but a *systematic* host scheduling delay biases all five the same way.
- The four JSONs cannot quantify the offset: no stage, gauge or counter carries it.

## Q4. How jitter, decode, display and total are derived

- **jitter** = `ΔjitterBufferDelay / ΔjitterBufferEmittedCount × 1000` over the 3 s window (metrics.js:53-59,
  reporter.js:260). Present in all four runs (79, 22, 18, 89 median, n=32).
- **decode** = `ΔtotalDecodeTime / ΔframesDecoded × 1000` (metrics.js:68-74, reporter.js:261): 5 ms median everywhere
  (max 77 in base).
- **display** = mean of `max(0, presentationTime − expectedDisplayTime)` (metrics.js:85-88, reporter.js:153-157, 262):
  **0 in all four runs, max 0, n=33**. It is not "decoded → shown": it is "presented no later than planned". If Safari
  returns the two timestamps equal, it reads 0 by construction, and the code cannot tell that from an on-time frame.
- **network** = `currentRoundTripTime × 1000 / 2` (metrics.js:97-100): an RTT halved, not a measured one-way (2, 2, 2, 4
  median). Null when RTT is 0, which is why its n is 30/33/33/33 while the other stages are 32-33.
- **total** = the medians of capture + encode + network + jitter + decode + display added (stream_stats.dart:160-164,
  297-320); `n` = the fewest samples of any part; p95/max = the sum of the parts' p95/max (an upper bound, also stated in
  the code, :293-296).
- `send` has no viewer sample: the tracer writes no record for a sink pad (stream_sampler.dart:50 and its doc, :11-15), so
  the "send" column is always '-'.
- **Safari's numbers, from the four files:** jitter present and moving; decode present but metric-flat at 5 ms; display 0
  with max 0; network present; RTT present; freezeCount 2/0/0/0 with freezeMs 9320/0/0/0; `framesDropped` is
  `framesReceived − framesDecoded` (reporter.js:307), not the spec field; `framesLate` is 0 in all four because the late
  test compares the clamped display delay to a frame budget (:156-157) and so can never fire.
- **Nothing covers:** decoder output → compositor (WebKit's own video renderer queue), the vsync wait, compositing, the
  display pipeline and the panel. `presentationTime`/`expectedDisplayTime` describe the compositor's plan, not the glass.
  That is the whole of the 36-117 ms residue in Q6.

## Q5. What network, encode, capture and the host legs measure; where the unmeasured time sits

- **capture** = the element times of `capsfilter0` and `videoconvert0`, **encode** = the encoder element's own time, both
  from the container's tracer as 3 s means (stream_sampler.dart:47-83), written by the sampler into `pipeline.json`
  (:155-166) and copied into the page's batch (reporter.js:288-291, 361-370). The encode stage includes the encoder's wait
  for `webrtcsink` to take its output (k1-4), so 30 ms there is not 30 ms of encoding.
- **network** = RTT/2 (above): a lower bound on one-way, not a measurement of it.
- **Host legs** (app clock only, no cross-clock subtraction, stream_host_legs.dart:45-74): press → the start of the next
  frame (`tick`, probe_leg.dart:88-95); tick → built (tick + build duration, :99-114 with :121-127); built → raster
  (`rasterFinish − built`, sampler :59). They land in the viewer's batch as one sample each per sampler window.
- **Between the press applied and the capture:** the compositor commit after raster, the Wayland draw, the capture
  plugin's 60 Hz pull (0-16.7 ms), and the app clock → pipeline clock join. None is measured; the `raster>capture*` cell is
  their only trace and it is a subtraction of two independent end-to-end numbers (k1-3: 11, 48, 48, 51, −16).
- **Found on the way (host gauges, not the gap):** `status()` calls `frameTimingProvider.take()` (host_automation.dart:73),
  so every `/status` empties the frame-timing window — the page's 10 s clock ping consumes windows the sampler's 3 s read
  would have covered. The `frameBuildMs`/`frameRasterMs`/`gameFrameMs`/`slowFramePct` means therefore mix partial windows.

## Q6. The four runs: gap, arithmetic, sample counts, coverage

Medians in ms; n in brackets. Chain order: capture / encode / network / jitter / decode / display.

| run | capture | encode | network | jitter | decode | display | total (n) | press (n) | p95 / max press | gap | host tick/build/raster (n) | host leg | residue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20261112-191250 phone-base | 2 | 30 | 2 | 79 | 5 | 0 | 118 (30) | 179 (58) | 239 / 460 | 61 | 17/1/7 (10) | 25 | 36 |
| 20261112-191539 phone-audio-sep | 2 | 30 | 2 | 22 | 5 | 0 | 61 (32) | 187 (56) | 321 / 418 | 126 | 13/1/8 (11) | 22 | 104 |
| 20261112-193438 phone-audio-off | 2 | 3 | 2 | 18 | 5 | 0 | 30 (32) | 169 (56) | 370 / 470 | 139 | 14/1/7 (11) | 22 | 117 |
| 20261112-200543 phone-lowdelay | 2 | 30 | 4 | 89 | 5 | 0 | 130 (32) | 223 (60) | 317 / 322 | 93 | 13/1/6 (11) | 20 | 73 |

- **The sums check exactly.** 2+30+2+79+5+0 = 118; 2+30+2+22+5+0 = 61; 2+3+2+18+5+0 = 30; 2+30+4+89+5+0 = 130. Gaps:
  179−118 = 61, 187−61 = 126, 169−30 = 139, 223−130 = 93. Residues: 179−25−118 = 36, 187−22−61 = 104, 169−22−30 = 117,
  223−20−130 = 73 (that is the cell the host-leg table would print).
- **What adds up differently from the labels:** the total is a sum of medians, not a frame's time; its n is the minimum;
  its p95/max are sums of p95s/maxes; `network` is RTT/2; `display` is a lateness, not a delay; `press>screen` is per
  press and the chain is per 3 s window, so the gap is *not* a paired difference.
- **Sample counts and coverage:** the chain's stages are one sample per 3 s batch — 30-33 batches ≈ 90-99 s, i.e. the 60 s
  round *and* the press phase. The host legs are one sample per sampler window — 10-11 × 3 s ≈ 30-33 s, the press phase.
  The press samples are 56-60 per press phase (~30 s at ~0.52 s each). **So the press median covers the card seconds; the
  chain median also covers 60 s of the round.** A pairing over seconds is impossible from a summary, which keeps only
  aggregates.
- Base run n=32 for jitter/decode vs 33 for the others: two freezes (freezeMs 9320) froze `jitterBufferEmittedCount` and
  `framesDecoded` for a window, so those two metrics returned null and were left out (metrics.js:55-56, 70-71). The same
  thing explains the base total's n=30 (network was null in 3 windows).
- The host-leg n (10/11) and press n (56-60) agreeing on ~30 s is a useful cross-check that the press phase was the
  default 30 s (bench.sh:61) and that nearly every press was matched.

## Suspected faults, ranked by how much of the 61-139 ms each could explain

| # | fault | size it could explain | evidence | confirm / refute | what the marker check distinguishes |
| --- | --- | --- | --- | --- | --- |
| 1 | **The chain stops at the compositor's plan; Safari's renderer/display tail is in no field** | the whole residue after host legs: 36-117 ms | display 0/max 0 in all four (metrics.js:85-88); total 30-130 while press stays 169-223; the leanest host (run 3) has the biggest gap | confirm: drawn clock in the picture reads an age ≥ total + residue; refute: age ≈ total | frame counter + drawn host clock read back gives the picture's age directly: age − total is this fault's size, without any getStats field |
| 2 | **Clock-offset bias (host reads `/status` late, offset is one-sided)** | 0 to +25 ms | formula reporter.js:190; host stamp at host_automation.dart:68; bounded by gameFrameMs 17.78 / max 23.34; rttMs 4.1 leaves ≤4 ms network | refute: `/clock` answering its own receive/answer stamps, so the page can subtract the host's handling; or two independent offset paths agreeing | the press timed *from the picture* (press time drawn in the flip cell, seen against the clock drawn in the same frame) needs no offset; the offset-corrected age then shows the bias as the difference between the two |
| 3 | **The patch is read every 8th frame when no press waits** | 0-133 ms per sample, only when the press reaches the page after its own flip | latency_probe.js:27, 64; poll 200 ms (reporter.js:33) | confirm: flip sighting times vs drawn frame counter; refute: read every frame and the median is unchanged | the frame counter in the picture says which frame the page read, so a late sighting is visible per sample |
| 4 | **A press matched to a later flip (card cadence or the next press)** | up to +499 ms on the samples it takes; p95/max, rarely median | latency_probe.js:131-151 (only ≥500 ms is dropped); maxima 460, 418, 470 all just under 500; lowdelay's p95 317 / max 322 | confirm: count presses with no flip of their own; refute: draw the press number in the flip cell and drop samples whose number is not the press's | the flip cell carries the press's number/host time, so a mismatched sighting is provable instead of silent |
| 5 | **The total is a sum of six medians from two sources and different windows** | a few ms, direction unknown | stream_stats.dart:297-320; n=min; p95/max summed; chain 90-99 s vs press 30 s | confirm: per-frame stages (rk marker) or per-batch pairing; refute: a batch that carries stages and presses together | reading both from the same drawn frame removes the timing join |
| 6 | **`network` is RTT/2 and `display` is clamped at 0** | ±2-5 ms in the total | metrics.js:85-88, 97-100 | refute: one-way from a capture timestamp carried with a frame | none needed: the drawn clock's age is a direct one-way measure |
| 7 | **rVFC stamp vs glass, `drawImage` frame vs presented frame** | ≤1-2 frames (≤34 ms), direction unknown | reporter.js:147-161; latency_probe.js:113 | confirm: compare the drawn frame counter with `presentedFrames` in the metadata | the counter is the only field that says *which* frame was read |
| 8 | **`/status` `take()` steals the frame window from the sampler** | 0 on the gap; biases the host frame gauges | host_automation.dart:73; frameBuildMs n=45 | trivial: keep a copy for the sampler or give the clock ping its own endpoint | not needed for the gap |

**Verdict: NO SINGLE DEFINITE FAULT.** Fault 1 covers the whole residue but is inference (no field measures it); faults 2-4
are real code weaknesses but each is bounded well below 139 ms on the median; none of them alone accounts for the four
gaps, and the shape of the four runs (press stable, chain swinging with the reported jitter) argues that the press is the
better number and that the chain under-reads Safari's playout.

## What Safari gives and does not (answer (c), from the four files)

- **Gives:** `jitterBufferDelay` and `jitterBufferEmittedCount` (jitter stage present, n=32); `totalDecodeTime` and
  `framesDecoded` (decode present); `framesPerSecond` (deliveredFps 59.19 / 59.55 / 59.9x); `framesReceived`, `framesDecoded`;
  `freezeCount` and `totalFreezesDuration` (2 / 9320 base, 0 elsewhere); `bytesReceived`, `packetsReceived/packetsLost`
  (loss 0.0); `jitter`; the nominated candidate pair's `currentRoundTripTime` (4.1 mean) and the local candidate type
  (relay `no`); the codec (H264) and 1920x1080.
- **Does not give (absent from all four):** `estimatedPlayoutTimestamp` on either track (no `audioSyncMs`); `concealedSamples`
  / `totalSamples` (no `audioConcealedPct`); a `presentationTime − expectedDisplayTime` that ever differs from 0; the spec's
  `framesDropped` (the page derives it); any sound stage on a joined connection; anything from decoder output to the glass.
- **Constant or suspicious values:** display 0 (max 0), decode 5 (metric-flat), capture 2, encode 30 (3 in run 3 — the
  audio-branch wait), `framesLate` 0 in all four (the late test can never fire while display is clamped).

## What I could not establish

- Whether WebKit's rVFC time and `drawImage` describe the frame on the glass or a neighbouring one — both are marked
  inference above; only a marker in the picture can say.
- Whether Safari's `jitterBufferDelay` is the whole playout wait. The run-to-run shape suggests it is not, but nothing in
  the files measures the rest.
- The actual `/clock` offset error per run: no field carries it, and the raw ping samples are not kept.
- Whether the press phase and the round had the same playout behaviour: a summary has only whole-session aggregates.
- The press phase's exact start: ~30 s is inferred from the host-leg n × 3 s, not recorded in the JSON.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup:** not affected — no code changed; the audit covers the Linux container host with a Safari viewer only.
2. **When kept state starts and ends:** not affected by this job; the reader's kept state is described in Q3/Q2 (offsets:
   start at `start()`, replaced as the last 5, never cleared but by `stop()`; presses: `poll` adds, `forgetSent`/timeout/
   the batch remove).
3. **How a new state combines with others:** not affected — nothing new is added; the audit names the existing cross-state
   risk (a press timing out or expiring when no flip follows) in Q2 and the fault table.
4. **Stay in the job's folder:** only `docs/briefs/m15/fix8/f8-1-audit-report.md` was written.
5. **Stop rather than overstep:** the brief did not require another file; nothing outside `allow:` was changed, no run was
   made, and every item I could not settle is listed as inference rather than guessed at.

## Hand-over

- **Exists now:** this audit only; no code, no run, no distro work.
- **Commands that worked:** `sed -n`, `grep -n`, `cat` over `docs/briefs/m15/bench-results/20261112-19*/…/0.json`,
  `streaming/player/*.js`, `streaming/bench.sh`, `streaming/player/serve.py`, `packages/metrics/lib/src/stream_*.dart`,
  `packages/metrics/lib/src/report_stream*.dart`, `packages/party_host/lib/src/automation/*`, `latency_test_card.dart`.
  No python is installed and no script was needed.
- **Numbers phase 2 must not recompute from scratch:** chain totals 118 / 61 / 30 / 130; press 179 / 187 / 169 / 223; gaps
  61 / 126 / 139 / 93; host legs 25 / 22 / 22 / 20; residues 36 / 104 / 117 / 73 (Q6).
- **Do not redo:** reading-only confirmation that `display` is a lateness (always 0), that `total` is a sum of medians, and
  that the four maxima sit under the 500 ms cut.
- **The phase-2 marker check must:** draw a frame counter and the host clock as cells; draw the press's host time in a flip
  cell; read both back in the page; compute (i) press → drawn clock, which needs no offset, and (ii) picture age, which
  needs the offset; and have `/clock` return the host's own receive/answer stamps so (ii) is trustworthy.
- **Open:** whether the residue is real (fault 1) or the offset/read grid (faults 2-3); the p95 tail 321-370; the
  `/status` `take()` side effect; no phone run reproduces the 80 ms gate under any reading.

## Commit message

docs: fix8 audit — how the Safari stream tables are produced, and the 61-139 ms gap

Read-only audit of the press probe, the flip watcher, the clock ping and the
stage derivation, against the four clean iPhone runs. The chain total is a sum of
stage medians and its display stage is clamped to 0, so nothing after the
decoder is measured; the residue after the host legs is 36-117 ms. The press is
stable (169-223) while the chain swings (30-130), the offset can only bias it by
about one host frame, and the maxima sit under the probe's 500 ms cut. Verdict:
no single definite fault; ranked faults and a marker-check design are in the
report.

## Status row

M15 fix8 f8-1 audit done: the press stamp, the flip sighting (8-frame idle grid, rVFC time, 120/80 thresholds), the 5-sample clock offset, the getStats derivations and the four runs (gaps 61/126/139/93, residues after host legs 36/104/117/73) are documented with file:line and JSON values, and no single definite fault is found — the best-fit inference is an unmeasured tail glass-ward of the chain; open: the phase-2 marker-in-picture measurement (offset-free press timing plus picture age), a `/clock` that returns the host's handling time, and the `/status` `take()` side effect on the host frame gauges.

## Delete

- none
