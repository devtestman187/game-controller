# n3-2 sender run: three sender variants, three probe runs each, nothing moves the host

## Summary

**Headless Chrome, not Safari.** Nine 45 s probe runs (1080p60, one session, one
headless Chrome viewer), three per sender switch, judged against n0's three
baselines. Chrome says whether a switch works and what it does to the host and to
the viewer; **the phone decides whether it helps**.

- **No variant lowers the frame's whole host time.** `pipelineMs` mean 40.10–41.40
  in all nine against n0's 33.66 / 40.33 / 40.32 (spread 6.7); the p95 (the stable
  figure; the mean carries one outlier sample, as in n0) is 32.80–33.95 against
  n0's 33.9 / 34.1. Every variant's own spread is 0.4–1.3 ms — **inside noise**.
- **The encode stage reads 29 ms in every run** (28 in `n3x0`): nothing was renamed.
- **FEC off** works, and the wire bitrate halves (1022–1055 kbit/s received against
  2096–2113 in n0) — FEC/RED overhead gone, **not a latency gain**. Jitter buffer
  230 / 104 / 219 ms, total 265 / 139 / 254, press 252 / 207 / 273; its own spread
  (126 ms jitter, 66 ms press) is three times n0's, so nothing can be read from it.
- **Retransmission off** works, bitrate unchanged (2063–2108); jitter 218 / 196 /
  125, total 253 / 231 / 160, press 280 / 253 / 219 — inside noise, leaning high.
- **`SESSION_CONGESTION=gcc`** works; `pipelineMs` 40.10 / 40.58 / 40.78 (p95 32.80
  / 33.23 / 33.81, the lowest p95 of the nine, 0.6–1.3 ms under n0's), jitter 104 /
  206 / 190, total 138 / 241 / 225, press 216 / 241 / 234 (p95 367 / 352 / 384)
  against n0's 205 / 244 / 218 — inside noise; bitrate unchanged (2043–2125).
- **Every run: one viewer row** (`browser/chrome-headless`) with receive data, H264
  1920x1080, 2531–2930 frames received, 11–15 dropped, **no freeze**, loss 0 %.
- **This batch is noisier than n0**: jitter spread 126 ms (n0: 40) and all nine
  press p95s (352–395) exceed every n0 p95 (241–275) while medians stay in range.
- Owner command per variant: `tools/stream.sh bench --viewer external --probe` with
  `--set SESSION_FEC=false`, `--set SESSION_RETRANSMISSION=false` or
  `--set SESSION_CONGESTION=gcc`; all defaults stay as they were.

## Method

- Route: **`streaming/bench.sh` run directly in `tp-stream`**, not
  `tools/stream.sh` — the wrapper is refused by this sandbox ("This Bash command
  contains multiple operations … requires approval", also for `status`), the same
  refusal fix5 j1-2, fix6, n0-2 and n2-2 hit. `tools/wsl-sync.sh` and
  `tools/wsl-fetch.sh` both work.
- Checkout copied with `tools/wsl-sync.sh tp-stream` into
  `/work/flash-20261112-154523-23306`; image built there from this checkout
  (`docker build -q -f streaming/Dockerfile -t tp-session:latest .`,
  `sha256:7fe2f3e27c25…`; entrypoint and player are COPY layers near the end, so
  the build used the cache).
- Nine runs, three per variant, in the brief's order:

  ```bash
  cd /work/flash-20261112-154523-23306
  bash streaming/bench.sh --probe --seconds 45 --label n3nofec0 \
    --out /work/stream-bench/n3nofec0 --set SESSION_FEC=false
  # n3nofec1, n3nofec2 with the same --set; then n3noretx0-2 with
  # --set SESSION_RETRANSMISSION=false; then n3x0-2 with
  # --set SESSION_CONGESTION=gcc
  ```

  Three runs per `wsl` call (a loop inline, ~80 s each), no `--keep`, so bench
  removed each container itself; `docker ps -a` was empty at the end.
- **One label accident, from n2-2's `$` quirk**: the first FEC-off loop used
  `--label n3nofec$i` and the `$i` reached the distro empty (a `\$i` works), so
  all three runs shared the folder `n3nofec` and the later two overwrote the
  first. The third run's summary was kept as `n3nofec0` (copied before the
  folder was removed) and two runs were made again as `n3nofec1`, `n3nofec2`.
  So eleven runs were made and nine kept; the two lost runs carried the same
  `switches:` line as the kept ones.
- The candidate for `n3x` is `SESSION_CONGESTION=gcc`: it is the only new
  switch n3-1 added (step 1 found no other sender property that names the hold),
  so it is the most promising by default; the "both off" fallback did not apply.
- Numbers from the distro's `python3` over the fetched summaries
  (`docs/briefs/m15/fix7/n3-2-sender-run/*.json`, the `summaries/<label>0.json`
  bench strips); `switches.txt` in the same folder holds the nine
  `switches:` lines. Scratch logs and the duplicate `n3nofec` folder removed.

## The nine runs

Median/p95 in ms unless said otherwise; `jitter` is the viewer's buffer stage
(`stream_jitter_buffer`), `total` capture-to-screen (`stream_total`), `press`
the probe's press-to-screen, `pipelineMs` and `encodedFps` the host gauges.

### `SESSION_FEC=false` (n3nofec0–2)

| run | jitter | pipelineMs mean / p95 | total | press (n) | encFps | kbit/s | recv/drop |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n3nofec0` | 230/267 | 40.86 / 33.78 | 265/302 | 252/395 (89) | 55.89 | 1055 | 2726/15 |
| `n3nofec1` | 104/248 | 41.40 / 33.79 | 139/283 | 207/369 (85) | 55.85 | 1022 | 2732/15 |
| `n3nofec2` | 219/247 | 40.86 / 33.95 | 254/282 | 273/369 (91) | 56.67 | 1053 | 2759/14 |
| n0 baseline | 136/96/107 | 33.7–40.3 | 171/131/142 | 244/205/218 | 55.4–56.6 | 2096–2113 | — |

### `SESSION_RETRANSMISSION=false` (n3noretx0–2)

| run | jitter | pipelineMs mean / p95 | total | press (n) | encFps | kbit/s | recv/drop |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n3noretx0` | 218/261 | 40.76 / 33.85 | 253/296 | 280/388 (91) | 56.54 | 2063 | 2930/14 |
| `n3noretx1` | 196/241 | 40.66 / 33.85 | 231/277 | 253/370 (89) | 56.09 | 2108 | 2735/11 |
| `n3noretx2` | 125/239 | 40.34 / 33.43 | 160/274 | 219/365 (88) | 54.46 | 2085 | 2652/15 |

### `SESSION_CONGESTION=gcc` (n3x0–2)

| run | jitter | pipelineMs mean / p95 | total | press (n) | encFps | kbit/s | recv/drop |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n3x0` | 104/247 | 40.10 / 32.80 | 138/282 | 216/367 (89) | 51.93 | 2099 | 2531/14 |
| `n3x1` | 206/233 | 40.58 / 33.23 | 241/268 | 241/352 (91) | 53.48 | 2043 | 2771/13 |
| `n3x2` | 190/242 | 40.78 / 33.81 | 225/277 | 234/384 (89) | 56.05 | 2125 | 2733/12 |

### Stage rows (all nine runs)

| run | encode | capture | network | decode | display | host tick | host build | host raster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `n3nofec0` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 15/21 | 0/1 | 5/6 |
| `n3nofec1` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 16/21 | 0/1 | 5/8 |
| `n3nofec2` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 19/23 | 0/1 | 5/6 |
| `n3noretx0` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 15/20 | 0/1 | 5/7 |
| `n3noretx1` | 29/29 | 2/2 | 1/2 | 3/3 | 0/0 | 15/18 | 0/1 | 5/6 |
| `n3noretx2` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 18/21 | 1/1 | 5/6 |
| `n3x0` | 28/28 | 2/2 | 1/2 | 3/3 | 0/0 | 15/21 | 0/1 | 6/7 |
| `n3x1` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 16/23 | 1/1 | 6/7 |
| `n3x2` | 29/29 | 2/2 | 1/1 | 3/3 | 0/0 | 13/20 | 1/1 | 5/7 |

Element means from `pipeline.log` were not re-read this phase: n3-1 already
showed webrtcsink adds no element of its own over 0.5 ms and that its `queue0`
is the sound branch's. Here the encode stage is flat at 29 ms while `pipelineMs`
is flat at ~40.5 in all nine, so the sink-side hold is unchanged.

### Spreads (min–max, ms)

| variant | jitter | total | press | press p95 | pipelineMs mean | pipelineMs p95 | encFps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FEC off | 104–230 (126) | 139–265 (126) | 207–273 (66) | 369–395 | 40.86–41.40 (0.54) | 33.78–33.95 (0.17) | 55.85–56.67 |
| retx off | 125–218 (93) | 160–253 (93) | 219–280 (61) | 365–388 | 40.34–40.76 (0.42) | 33.43–33.85 (0.42) | 54.46–56.54 |
| GCC | 104–206 (102) | 138–241 (103) | 216–241 (25) | 352–384 | 40.10–40.78 (0.68) | 32.80–33.81 (1.01) | 51.93–56.05 |
| n0 noise | 96–136 (40) | 131–171 (40) | 205–244 (39) | 241–275 | 33.66–40.33 (6.7) | 33.9–34.1 | 55.4–56.6 |

## Verdicts

One line each; "inside noise" means the difference is smaller than both the n0
spread and the variant's own three-run spread. A difference can be real and still
not be a latency gain (the wire bitrate).

1. **`SESSION_FEC=false` — inside noise.** `pipelineMs` 40.86 / 41.40 / 40.86
   (p95 33.8) is n0's high mode; jitter, total and press move up and down by more
   than the whole baseline range within the variant. The wire bitrate halves
   (1055 / 1022 / 1053 against 2096–2113 kbit/s) — that is FEC/RED overhead gone,
   **not a latency gain**; the encoder is still given the ceiling less the sound.
   Owner command: `tools/stream.sh bench --viewer external --probe --set SESSION_FEC=false`.
2. **`SESSION_RETRANSMISSION=false` — inside noise, leaning high.** `pipelineMs`
   40.76 / 40.66 / 40.34 (p95 33.4–33.9), encode 29 in all; jitter 218 / 196 /
   125 and press 280 / 253 / 219 are two runs above n0's maxima but the variant's
   own spread (61–93 ms) covers the whole baseline range. Wire bitrate unchanged.
   No retransmission means a lost packet stays lost: a playability cost with no
   measured gain. Owner command: `--set SESSION_RETRANSMISSION=false`.
3. **`SESSION_CONGESTION=gcc` — inside noise.** `pipelineMs` 40.10 / 40.58 / 40.78,
   p95 32.80 / 33.23 / 33.81 — the lowest p95 of the nine and 0.6–1.3 ms under
   n0's, well inside the baseline's own spread. Press 216 / 241 / 234 fits n0's
   205 / 244 / 218; bitrate unchanged (no congestion on a near-static card);
   encodedFps 51.9 / 53.5 / 56.1 leans low (own spread 4.1) and the packet-jitter
   gauge rises (1.06–1.50 ms against 0.13–0.88) — GCC paces, and on this probe it
   buys nothing. Owner command: `--set SESSION_CONGESTION=gcc`.

What headless Chrome cannot say: whether Safari honours any of this. FEC and
retransmission are negotiated sender properties the phone's browser already
receives either way; GCC changes only what the sender sends; the ~25 ms hold in
webrtcsink that the owner sees as part of the 158 ms is untouched by all three.
**The phone decides.**

## Open problems

1. **This batch is noisier than n0 and its tail differs.** All nine press p95s
   (352–395) are above every n0 p95 (241–275), and jitter/total spreads reach 126
   ms against n0's 40, while medians stay in n0's range. Either the machine was
   busier (nine runs back to back) or the batch carries a tail n0 did not. The
   medians are the only comparable figures here; p95 across batches is not.
2. `pipelineMs` mean sits ~40.5 in all nine runs and never in n0b0's 33.66 mode;
   p95 is ~33. This is n0's bimodality, now the high mode for nine runs in a row.
3. GCC's encodedFps (51.9–56.1) is the only figure whose spread exceeds the
   baseline's; no explanation from the summaries (bitrate and drop counts normal).

## Decisions

1. **`n3x` = `SESSION_CONGESTION=gcc`.** n3-1 added exactly one sender switch;
   with no other new property, it is the most promising by default and the
   "FEC and retransmission both off" fallback did not apply.
2. **`bench.sh` directly in `tp-stream`**, because the wrapper is refused by this
   sandbox; the brief names this route.
3. **Kept the third FEC-off run as `n3nofec0`** and redid two, because the `$i` in
   the first loop reached the distro empty (n2-2 hit the same) and overwrote the
   folder. Labels, switch line and settings are unchanged, so the kept run is one
   of the three.
4. **No `--keep`**, so bench removed each container; no container this job started
   is left.
5. **No element-latency re-read** (`pipeline.log`): n3-1 measured every element
   webrtcsink adds and both `h264parse` elements; the flat encode stage and flat
   `pipelineMs` answer the question without it.

## Questions and suggestions

1. Should a run phase discard one warm-up run before its three (n0 asked this
   too)? Nine runs back to back may be what raised this batch's tail.
2. Is `SESSION_CONGESTION=gcc` worth a phone comparison at all, given it does not
   touch the hold and leaves the bitrate alone on a quiet LAN? A full Arena round
   is where GCC could differ; this phase only had the probe.
3. `SESSION_FEC=false` halves the wire bitrate: if a later phase wants a bitrate
   reading, it should say which switch was on — the received kbit/s is not
   comparable across FEC settings.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup.** Not affected: no app, player or game code changed; the
   three switches are session-image environment values with the same defaults as
   before, and only the Linux session host in the headless Chrome setup was run.
2. **When kept state starts and ends.** Nothing is held: each run's containers,
   Chrome profile and logs are bench's own and were removed when it ended; the
   image tag was rebuilt once from this checkout.
3. **How a new state combines with the others.** All switches are independent
   start-up properties of the two sinks (n3-1, code read); the runs used one at a
   time with every other switch off, so no pair was exercised.
4. **Stay in the job's folder.** Wrote `docs/briefs/m15/fix7/n3-2-sender-run/`
   (nine summaries and `switches.txt`) and this report; nothing else.
5. **Stop rather than overstep.** No file outside `allow:` was touched; no default
   changed; the wrapper route being refused is reported, not worked around.

## Checks

- `tools/check.sh format analyze metrics tv` on Windows: **PASS** — format (3 s),
  analyze (17 s), metrics (157 tests), tv (66 s).
- Nine probe runs: all rc=0; one viewer row each, no freeze (tables above).
- `docker build` from the synced checkout: passed; `docker ps -a` empty after.
- The working tree still carries the six uncommitted `tv_test_app/**/generated_plugin_*`
  files it was cut with (as in n2-2); this job did not touch them.

## Hand-over

- Exists now: nine probe summaries and the switches lines in
  `docs/briefs/m15/fix7/n3-2-sender-run/` (`n3nofec00/10/20.json`,
  `n3noretx00/10/20.json`, `n3x00/10/20.json`, `switches.txt`); image
  `sha256:7fe2f3e27c25…` in `tp-stream`; verdicts above.
- Commands that worked (in `tp-stream`, folder `/work/flash-20261112-154523-23306`):

      docker build -q -f streaming/Dockerfile -t tp-session:latest .
      cd /work/flash-20261112-154523-23306 && bash streaming/bench.sh --probe \
        --seconds 45 --label n3noretx2 --out /work/stream-bench/n3noretx2 \
        --set SESSION_RETRANSMISSION=false

  Then `tools/wsl-fetch.sh tp-stream /work/stream-bench/<label>/summaries/<label>0.json
  docs/briefs/m15/fix7/n3-2-sender-run/<label>0.json`. Use `\$i` in a `wsl -lc`
  loop, not `$i`.
- Numbers: host flat (encode 29, `pipelineMs` mean 40.1–41.4 / p95 32.8–33.95);
  press median 207–280, jitter 104–230, total 138–265 in all nine; FEC off halves
  the wire bitrate; retx off and GCC leave it alone.
- Do not redo: these nine runs, these three switches against the probe card, or
  the n0 baselines. A full-round run is the only thing that could show GCC.
- Open: the batch tail (press p95 352–395 against n0's 241–275), the high
  `pipelineMs` mode in all nine, GCC's low encodedFps; the phone decides all three.

## Commit message

docs: nine sender probe runs — FEC, retransmission and GCC move nothing

Three 45 s probe runs each with SESSION_FEC=false, SESSION_RETRANSMISSION=false and
SESSION_CONGESTION=gcc, headless Chrome, judged against n0's baselines. Host
pipelineMs stays at n0's high mode (mean 40.1-41.4, p95 32.8-33.95) and the encode
stage 29 ms in every run, so no stage was renamed; press-to-screen, jitter and total
all overlap the baseline inside a batch whose own spread is three times n0's. FEC
off halves the wire bitrate (1022-1055 against 2096-2113 kbit/s), overhead gone and
not a latency gain; retransmission off and GCC leave the bitrate alone. Headless
Chrome, not Safari: the phone decides. Nine summaries and switches.txt in
fix7/n3-2-sender-run/; no code or default changed.

## Status row

M15 fix7 n3 phase 2 (run) done: FEC off, retransmission off and `SESSION_CONGESTION=gcc` each ran three 45 s probes with one viewer row and no freeze, and none lowers the host's pipelineMs beyond the noise (FEC off halves the wire bitrate, not latency); open: the batch-wide press p95 tail and the high pipelineMs mode unexplained, GCC never exercised on a full round, and the phone decides.

## Delete

- none
