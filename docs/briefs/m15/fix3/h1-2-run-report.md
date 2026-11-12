# M15 h1 phase 2 (run): how much of the browser's jitter buffer is the rig?

## Summary

Five round runs as the brief writes them; the probe pair is a footnote (no game loop, Decision 1).

| run | shape | jitter med/p95 | total med/p95 | press med/p95 | delivered fps | game fps | session CPU | viewer CPU |
|---|---|---|---|---|---|---|---|---|
| b1 | round 1080p60, unpinned | 226 / 260 | 262 / 297 | – | 58.7 | 45.4 | 251 % | 134 % |
| b2 | round 1080p60, unpinned | 220 / 254 | 256 / 291 | – | 57.8 | 41.9 | 239 % | 132 % |
| p1 | round 1080p60, session 0-11, viewer 12-15 | 193 / 233 | 229 / 269 | – | 58.2 | 51.2 | 249 % | 129 % |
| p2 | round 1080p60, session 0-11, viewer 12-15 | 144 / 249 | 181 / 287 (n = 4) | – | 57.6 | 49.7 | 252 % | 128 % |
| l1 | round 720p30, unpinned | 200 / 232 | 218 / 250 | – | 29.7 | 60.0 | 160 % | 52 % |

(Milliseconds; CPU as % of one core, mean for the session and median for the viewer; see Decision 3. Every cell
but p2's total has n ≥ 8; p2's total rests on four samples and is marked, its jitter buffer on 21.)

Probe pair, no game loop: q1 unpinned 193 / 236 jitter, 227 / 272 total, press 218 / 359 (n = 118); q2 pinned
225 / 246, 260 / 282, press 259 / 363 (n = 119).

**Answer: pinning may cut the buffer by up to about 76 ms (220 → 144), but this PC's run-to-run spread (49 ms) is
too large to say; a real device must answer it.**

## The question, read out

- **Baseline (b1, b2):** jitter 226 and 220 ms, total 262 and 256 ms; the game drew 45.4 and 41.9 fps. These
  are the runs the pin's effect is read against.
- **Pinned (p1, p2):** 193 and 144 ms. The 144 ms run is the lowest number this PC has produced, and its twin
  (p1, same flags, three minutes later) is 49 ms higher: that spread is the noise of one run on this machine.
  Read against the better baseline (220 ms), the lowest pinned run is 76 ms lower (82 ms against 226 ms),
  while the two pinned repeats themselves differ by 49 ms.
- **Press pair (no game loop):** 218 ms unpinned against 259 ms pinned — pinning *raised* the press figure by
  41 ms, the opposite of the round pair — and its buffer is 32 ms *above* its baseline (225 against 193 ms).
  That is what noise looks like at this size.
- **Light picture (l1):** 720p30 drops the session to 160 % and Chrome to 52 % of one core, and the game holds
  60.0 fps — neither side is starved — yet the buffer is 200 ms, 23 ms under the baseline's mean. Its encode fell
  to 15 ms and its decode to 2 ms with the lower load (29 and 4 at 1080p60), so the stages around the buffer
  follow what is drawn while the buffer moves far less.
- **Where the time goes:** the jitter buffer is 80–92 % of `stream_total` in every round (b1 226 of 262 is 86 %,
  p2 144 of 181 is 80 %, l1 200 of 218 is 92 %), and the other stages held at 1080p60 (encode 29, capture 2,
  network 1, decode 4, display 0 ms); only the buffer and the totals it carries move.
- **What is left:** the viewer's own playout delay (~2–3 frames of 30/60 fps plus Chrome's scheduling) is most
  of what is measured. The 110–160 ms an earlier phase reported is not what a round shows here, and g1's 16 ms
  (162 → 146) is inside the noise this PC measures (49 ms between repeats). A machine with a smaller spread, or
  a real device, is what the rig's share needs.

## Commands as run

Inside the distro (`tp-stream`, 16 logical CPUs: Ryzen 7 5800X with SMT), one call per run. The bench is
`streaming/bench.sh` from the copy at `/work/flash-20261112-000014-3492`, run directly rather than through
`tools/stream.sh` so the sampler can watch it (Decision 2):

```bash
bash streaming/bench.sh --sessions 1 --seconds 60 --game arena --label h1b1 --out /work/stream-bench/h1b1
bash streaming/bench.sh --sessions 1 --seconds 60 --game arena --label h1b2 --out /work/stream-bench/h1b2
bash streaming/bench.sh --sessions 1 --seconds 60 --game arena --label h1p1 --viewer-cpus 12-15 \
  --session-cpus 0-11 --out /work/stream-bench/h1p1
bash streaming/bench.sh --sessions 1 --seconds 60 --game arena --label h1p2 --viewer-cpus 12-15 \
  --session-cpus 0-11 --out /work/stream-bench/h1p2
bash streaming/bench.sh --sessions 1 --seconds 60 --game arena --size 1280x720 \
  --set SESSION_FRAME_RATE=30 --label h1l1 --out /work/stream-bench/h1l1
bash streaming/bench.sh --sessions 1 --seconds 60 --probe --label h1q1 --out /work/stream-bench/h1q1
bash streaming/bench.sh --sessions 1 --seconds 60 --probe --label h1q2 --viewer-cpus 12-15 \
  --session-cpus 0-11 --out /work/stream-bench/h1q2
# the 20 s diagnostic of the viewer count (Observation 1):
bash streaming/bench.sh --sessions 1 --seconds 20 --game arena --label h1x --out /work/stream-bench/h1x
```

Beside each bench, in the same shell call, a sampler ran from the first `measuring …` line of the bench log to
the end of the window: it read `utime+stime` of every `chrome-headless` process every 2 s, summed them and
wrote the result in % of one core to `chrome-cpu.log`; at its first sample it also recorded
`docker inspect -f '{{.Name}} cpuset={{.HostConfig.CpusetCpus}}' thumb-party-<name>` and `taskset -cp` of every
Chrome pid. The summaries were copied out with `tools/wsl-fetch.sh` into `h1-2/<run>/`.

## Proof of pinning

From `h1-2/evidence.txt` (the same lines are in each run's `chrome-cpu.log` in the distro):

```
== b2:  /thumb-party-h1b20 cpuset=                      pid 3116 … affinity list: 0-15
== p1:  /thumb-party-h1p10 cpuset=0-11                  pid 4727 … affinity list: 12-15   (all 7 Chrome pids)
== p2:  /thumb-party-h1p20 cpuset=0-11                  pid 6334 … affinity list: 12-15   (all 7 Chrome pids)
== l1:  /thumb-party-h1l10 cpuset=                      pid 7940 … affinity list: 0-15
== q2:  /thumb-party-h1q20 cpuset=0-11                  pid 14291 … affinity list: 12-15  (all 7 Chrome pids)
```

An empty `cpuset` is docker's "no pinning", and `0-15` is the whole machine, so the two pinned runs really are
pinned and b2 and l1 really are not. b1 has no `cpuset` line: its `docker inspect` named the wrong container
(`thumb-party-h1b1` instead of `...h1b10`), so only its seven Chrome processes' `0-15` affinity was recorded
(`h1-2/evidence.txt:14`) — that is what an unpinned run's Chrome shows, inheriting the container's set, but it
does not prove the set was empty. Each viewer row in the table comes from that run's `v1` viewer
(`browser/chrome-headless`, 20–23 samples per run).

## Decisions

1. **A probe pair on top of the five runs (q1, q2).** The brief asks for `press_to_screen` for every run, but a
   round run never starts the latency card: `bench.sh` only sets `press_loop` in `--probe` mode, and the round
   summaries have no `press_to_screen` stage at all (checked in all five). The probe pair repeats the baseline
   and the pinned shape with the card, so the press figure exists; it is reported separately and changes no flag.
2. **`streaming/bench.sh` directly, not `tools/stream.sh bench`.** The outer tool owns the whole distro call, so
   nothing could be sampled beside the run; calling the bench in the distro left the same flags and the same
   `--out`, and the summaries were fetched with `tools/wsl-fetch.sh` as the brief asks.
3. **The viewer's CPU is measured here, not read from the summary.** The session's summary carries only the
   session's own `cpuPct` (cgroup); no field holds the viewer's CPU. It was sampled from `/proc/<pid>/stat`
   (utime+stime of every `chrome-headless` process over 2 s, summed), which is the same unit as `cpuPct`, so the
   two columns compare. The median over the window is reported; every sample is in the evidence file.
4. **720p30 is `--size 1280x720 --set SESSION_FRAME_RATE=30`.** The entrypoint's `SESSION_FRAME_RATE` (default
   60) is the only frame-rate setting; the run's delivered fps of 29.7 and encode of 15 ms show it took.
5. **The inline distro script writes every `$` as `\$`.** The job harness expands `$VAR` in a `wsl … bash -lc`
   argument before it reaches the shell, which the first attempt showed the hard way (see Wasted attempt).
6. **The five runs are the brief's commands, including the label and the `--seconds 60`;** the labels are
   `h1b1`, `h1b2`, `h1p1`, `h1p2`, `h1l1` (and `h1q1`, `h1q2`, `h1x`), so `/work/stream-bench/<label>` holds
   each run's summary, bench log, Chrome log and CPU log. They are removed after the fetch.

## Wasted attempt

The first b1 attempt was killed at the tool's 2-minute limit and left nothing: no container (`docker ps -a`
empty), no summary and no run folder. Its inline script had its variables expanded before the distro saw them
(`out` and `$!` came out empty in the shell, proved with a probe afterwards), so its paths and its wait went
where nothing was written. That is what turned Decision 5 up; nothing it did is in the results.

## Observations

- **Four viewer rows per summary, one timed.** Every run's summary has `v1` (`browser/chrome-headless`, the
  headless page, counters and gauges) and three `browser/chrome` rows holding only the session-side stages
  (`stream_encode`/`stream_capture`/`stream_total`, n = 6–7) and no gauges. A 20 s diagnostic run (h1x) with
  `ss -tnp` every 3 s showed no client at the player or signaller port but the bench's own loopback ones (the
  relay, the signaller, the sampler), so the extra registrations come from the page itself, not from another
  device. g1's runs had one viewer row, so something changed since. The bench's run line therefore reads
  "4 viewer(s)"; the table uses `v1`, the only row with the page's numbers.
- **Received bitrate is twice the ceiling in every round** (19.6–20.2 Mbit/s against 10, and 20.9 at 720p30),
  as the earlier reports found; the card carries 6.8–7.1.
- **The game does not hold 60 fps at 1080p60** (game fps 41.9–51.2 with a session CPU of ~250 %), while at
  720p30 it reaches 60.0 with a session CPU of 160 %. The jitter buffer is not what limits it.

## Blocked

- Nothing stopped the runs and no flag is missing: `SESSION_FRAME_RATE` exists (Decision 4). The only thing the
  brief's shape cannot give is `press_to_screen` in a round run, which is a property of the bench (no card in a
  round), not a missing flag; Decision 1 answers it with the probe pair.

## Results files

`docs/briefs/m15/fix3/h1-2/` holds `b1/h1b10.json`, `b2/h1b20.json`, `p1/h1p10.json`, `p2/h1p20.json`,
`l1/h1l10.json`, `q1/h1q10.json`, `q2/h1q20.json` (the sessions' summaries, fetched with
`tools/wsl-fetch.sh`), and `evidence.txt` (the pinning lines and every Chrome CPU sample).

## Questions

1. Should the bench record the viewer's own CPU (a `ps`-style reading beside the session's) so the two columns
   come from one file? It is measured here by hand for every run.
2. The page registers four viewers per run (Observation 1). Is that worth a job of its own before more
   pinning experiments, or is it already known?

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** none changed; this is a measurement report, and only its words moved. Nothing ran.
2. **When kept state starts and ends:** nothing kept; the runs are over and their summaries are in `h1-2/`.
3. **How a new state combines:** no state, no round and no screen involved.
4. **Stay in the job's folder:** only this file changed, and only the sections the review named.
5. **Stop rather than overstep:** nothing was needed outside `allow:`; the four-viewer rows and the 42–51 fps
   stay as open questions rather than being measured here.

## Commit message

M15 h1-2: the pinned viewer rerun; pinning may save up to 76 ms

Five headless runs (arena 60 s, twice unpinned and twice with the session on
0-11 and Chrome on 12-15, plus one at 720p30) and a probe pair, with the
pinning shown by docker inspect and taskset. The jitter buffer is 220-226 ms
unpinned, 193 and 144 pinned, and still 200 ms at 720p30 with both CPUs
halved; the two pinned repeats differ by 49 ms and the pinned probe is 32 ms
worse, so a rig share of up to 76 ms cannot be told from this PC's noise, the
16 ms claim is withdrawn, and a real device must answer. Only docs changed.

## Status row

- **h1 phase 2 run (fix3):** measured with the headless viewer — jitter buffer 220/226 ms unpinned, 193/144
  pinned, 200 ms at 720p30, press 218 → 259 ms in the probe pair (no game loop); **open:** pinning may save up
  to 76 ms (220 → 144) but this PC's run-to-run spread (49 ms) is too large to say, so a real device must
  answer; the four-viewer rows per summary and the game's 42–51 fps at 1080p60 are recorded but not explained.

## Delete

- none
