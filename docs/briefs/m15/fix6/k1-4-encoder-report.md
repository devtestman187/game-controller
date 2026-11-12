# k1-4 encoder: what the 30 ms encode stage waits on, and why no setting halves it

## Summary

1. **What the stage is.** `stream_encode` is the tracer element named after the
   encoder (`PipelineWindow.stageOf`, `stream_sampler.dart:52-56`) averaged over
   its `element-latency` records (`stages()`, `:77-83`): each `time` runs from
   the buffer entering the sink pad to leaving the src pad, so it holds the
   element's work, its internal queue and whatever its push waits for
   **downstream** — not a queue before it (that reports its own). Measured: a
   20 ms `identity` after the encoder lifted it 4.6 → 115.6 ms, a queue in front
   left it at 9.3-10.0. The frame's whole host time is `pipelineMs`.
2. **The encoder is waiting.** `encoderPct` is 6 % of the GPU's encode engine,
   and alone (test source, nothing downstream) it holds a frame **9.2-11.3 ms
   over nine settings** (2 ms spread) and 9.8 ms at half the input rate: neither
   its work nor its pacing. In the session the same element is **29-34 ms**.
3. **It waits for `webrtcsink` to take its output.** A two-frame queue between
   the encoder and the parser dropped the stage to 3 ms while `pipelineMs` stayed
   33 and `encodedFps` 56, and `webrtcsink`'s internal queue then read 27.2 ms
   (18.1 before): the ~26 ms the encoder reported was the pipeline after it, and
   the frame waited exactly as long. The queue renames the wait; it shortens
   nothing.
4. **Skia does not free it:** one run with `THUMB_PARTY_IMPELLER=0` (GPU 47.9 %
   against 50.7, raster 1.8 against 5.6 ms) left the stage at 29 ms.
5. **Defaults changed: none; nothing was kept.** Three runs
   (`bench.sh --probe --seconds 45`, summaries in `k1-4/`):

| run | what it is | encode | pipelineMs | encodedFps | encoderPct | gpu % | total | press |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `k4b` | the defaults (baseline) | 29 | 33.8 | 56.8 | 6.3 | 50.7 | 179 | 244 |
| `k4n0` | `THUMB_PARTY_IMPELLER=0` (Skia) | 29 | 33.8 | 57.1 | – | 47.9 | 171 | 250 |
| `k4q` | a two-frame queue after the encoder | 3 | 32.9 | 56.1 | 6.3 | – | 159 | 254 |

`total` and `press` move 159-179 and 244-254, inside t1's 44 ms noise, and
`encodedFps` stays 56-57: none of the three is better on the frame's own path,
so no setting became a default and `entrypoint.sh` is HEAD.

## The micro-bench

`streaming/encoder-bench.sh`, 20 s per variant: `videotestsrc` 1080p60, the
session's own encoder properties (4716 kbit/s, CBR, gop 60, no B-frames, no
lookahead, p1/ultra-low-latency), `h264parse ! fakesink sync=false`, nothing
else in the pipeline. Encode ms is the element's mean / p95, fps from the
tracer's own stamps, CPU is the gst-launch process over the measured window.

| variant | what it changes | enc mean | enc p95 | fps | cpu % |
| --- | --- | --- | --- | --- | --- |
| `session` | the session's own settings (baseline) | 9.3 | 13 | 60.7 | 45.5 |
| `queue1` | `queue max-size-buffers=1 leaky=downstream` before the encoder | 10.0 | 13 | 60.1 | 48.1 |
| `preset-p4` | `preset=p4` (NVENC's own default) | 9.9 | 13 | 60.6 | 45.0 |
| `tune-low` | `tune=low-latency` | 9.0 | 13 | 60.7 | 45.6 |
| `tune-hq` | `tune=high-quality` | 9.5 | 13 | 60.7 | 45.4 |
| `reorder` | `zero-reorder-delay=false` | 9.4 | 13 | 60.6 | 44.0 |
| `rc-vbr` | `rate-control=vbr` (NVENC's default) | 9.3 | 13 | 60.6 | 44.4 |
| `rc-cbrld` | `rate-control=cbr-ld-hq` | 11.3 | 15 | 60.7 | 47.5 |
| `vbv167` | `vbv-buffer-size=167 strict-gop=true` | 9.2 | 13 | 60.6 | 44.3 |
| `cuda` | `nvcudah264enc` with the same properties | 9.4 | 13 | 60.0 | 43.9 |
| `nvh264` | `nvh264enc` | failed: the element has no `rate-control` | – | – | – |

Two probes outside the table: the `session` variant at `--fps 30` reads 9.8 ms
(a wait for the next frame would double there), and the same script inside
`tp-session:latest` with `--gpus all` reads 9.2 ms (docker and the container's
NVENC add nothing). The same settings read 4.6 ms in a 5 s window and 9.3 and
9.4 in two 20 s ones: the number moves with the window, which is why no line
above is called a winner — the 2 ms between variants is smaller than that.

The `nvautogpuh264enc` properties found (`gst-inspect-1.0`, GStreamer 1.24.2),
with their defaults: `preset` p4, `tune` default, `rate-control` vbr,
`b-frames` 0, `rc-lookahead` 0, `zero-reorder-delay` false, `vbv-buffer-size` 0
(NVENC's own, a second), `strict-gop` false, `spatial-aq`/`temporal-aq` false,
`repeat-sequence-header` false, `qos` false, `multi-pass` default,
`weighted-pred` false, `nonref-p` false, `aud` true, `bitrate` 0 (automatic),
`aq-strength` 0, `min-qp-*`/`qp-*` -1, `min-force-key-unit-interval` 0. There is
no async-depth, surface-count or max-tasks property: gst-nvenc 1.24 exposes none.

The session's own log (`k4b`, read with `encoder-bench.sh --log`) puts the rest
of the host path: `videoconvert0` 4.4 ms, `h264parse0` 0.1, `webrtcsink`'s
internal queues 18.1 / 10.8 / 0.5, `opusenc0` 20.2; in `k4q` the new queue read
0.4 and those queues 27.2 / 18.1 / 13.5.

### Decisions

- **No encoder setting becomes a default**: nine settings measured one at a
  time moved the element's number by at most 2 ms, against 4.8 ms between two
  runs of the baseline.
- **No new session setting**: the queue after the encoder is the only thing that
  moved the stage, and it does not move the frame; keeping it would make the
  reported stage lie about the host leg.
- **The micro-bench copies `build_pipeline`'s properties word for word** (4716
  kbit/s, CBR, gop 60, no B-frames, no lookahead, p1/ultra-low-latency) so every
  other line is read against what the session runs, and `--props` takes the
  whole string from the command line as the brief asks.
- **The three session runs went to baseline, Skia and the queue** rather than
  baseline twice and a winner twice: nothing in the encoder won, and those two
  were the only levers that could still move the stage (GPU share and the
  downstream handover).
- **Runs inside the distro directly** (`bash streaming/bench.sh …`, image built
  with `docker build -f streaming/Dockerfile`): this sandbox refused
  `tools/stream.sh`, as in k1-2 and k1-3.
- **The temporary switch left the code**: `SESSION_ENCODER_QUEUE` existed for one
  run and `entrypoint.sh` was reverted; `git diff` on it is empty.

### Open questions

1. The wait is now `webrtcsink`'s internal queue (27 ms with the encoder
   decoupled): is that worth a separate job (a webrtcsink version with a
   configurable queue, or `do-fec` off, which t1 measured as no delay change but
   which the FEC/RED encoder still pays for per packet)?
2. k1-2's Skia gain (raster 5.6 → 1.8 ms here) is real and its fps gain was at
   the noise edge; this job's Skia run adds an encode stage that did not move and
   `total`/`press` that moved 8 and −6 ms, no help in deciding it.
3. Why the same encoder element reads 4.6 ms in a 5 s window and 9.3-9.4 in a
   20 s one is not explained; the bench drops neither the first frame nor the
   flush, and a 222 ms start-up record is only 0.17 ms of a 20 s mean.

## Method

- Code read: `stream_sampler.dart` (`stageOf`, `add`, `stages`, `pipelineMs`),
  `bin/stream_sampler.dart` `_readTracer`, `stream_sampler_readings.dart`
  (`tracerRecordOf`, `pipelineRecordOf`), `entrypoint.sh` `build_pipeline`.
- Micro-bench: new `streaming/encoder-bench.sh`, run in tp-stream (`/work/
  flash-20261112-112122-10599`, the distro's own GStreamer 1.24.2 nvcodec, the
  same plugin the image has): `bash streaming/encoder-bench.sh` (11 variants,
  20 s each), `--only session --fps 30`, `--after "identity sleep-time=20000"`
  at 5 s, and the same script inside `tp-session:latest` with `--gpus all`.
- Sessions: `bash streaming/bench.sh --probe --seconds 45 --label k4b|k4n0|k4q
  --out /work/stream-bench/<label>` inside the distro; the image was rebuilt
  once for the queue switch (and the third run was the only one with it). Each
  kept container was stopped and removed by its name, and its
  `/run/thumb-party/pipeline.log` copied out and read with
  `encoder-bench.sh --log`.
- `encoder-bench.sh` parses the tracer by itself (awk: `element=(string)`,
  `time=(guint64)`, `ts=(guint64)`), which also gives the fps from the tracer's
  own stamps and leaves the start-up out of it. The tracer prints its record
  format at start-up with an element named `%s`; the parser skips it.
- `tools/check.sh tv` runs `flutter test`, which rewrote `tv_test_app`'s six
  generated plugin registrant files with LF endings; their content is unchanged
  (`git diff --name-only` lists only `docs/dev-tools.md`, `streaming/README.md`
  and `tv_test_app/test/stream_tool_test.dart`), and this sandbox refuses the
  line-ending tools that would put the CRLF back.

## Self-check (review-rules part A)

1. **Every host setup:** the change is a dev script and docs; no app, host or
   protocol code is touched, so a TV, phone, joined device or older build is
   unaffected (proved by `tools/check.sh` passing, and by three sessions on the
   unchanged image except the switch, whose output shows the same pipeline).
2. **When kept state starts and ends:** the bench keeps nothing between runs: it
   starts one gst-launch per variant, ends it with INT after `--seconds`, and
   writes only its log under `--out`. A failed start is reported and the run
   goes on (`nvh264` did).
3. **How a new state combines with others:** none added; the session's pipeline
   is HEAD's (the queue existed for one run only).
4. **Stay in the job's folder:** every edited file is in `allow:`
   (`encoder-bench.sh`, `README.md`, `dev-tools.md`, the test file, the report
   and `k1-4/`), and the image and logs stayed in the distro.
5. **Stop rather than overstep:** the owner's "halve it" could not be delivered
   from encoder settings; the report says so with the numbers instead of
   shipping a switch that only renames the wait (`git diff streaming/entrypoint.sh`
   is empty).

## Hand-over

Final state: the pipeline and defaults are unchanged (encode 29, pipelineMs
33.8, encodedFps 56.8, encoderPct 6.3, GPU 50.7 %); the encoder alone is
9.2-11.3 ms whatever its settings say, and in the session the stage is
`webrtcsink`'s handover (queue after the encoder: stage 3, pipelineMs 32.9).

```bash
tools/wsl-sync.sh tp-stream            # then in the distro, /work/<job>:
bash streaming/encoder-bench.sh        # 11 variants, 20 s each, ~5 min
bash streaming/encoder-bench.sh --log /work/encoder-bench/k4b-pipeline.log
docker cp thumb-party-k4x0:/run/thumb-party/pipeline.log /work/encoder-bench/k4x-pipeline.log
```

Not to be redone: the nine encoder settings (all inside the noise, and
`nvh264enc` has no `rate-control` here), the queue after the encoder (stage
down, frame unchanged), Skia as an encoder lever. Unexplained: the 4.6 ms of a
5 s window against 9.3 of a 20 s one, and what inside `webrtcsink` costs 27 ms.

## Commit message

streaming: an encoder micro-bench, and what the 30 ms encode stage is

The encode stage is the tracer's record of the encoder element, so it
holds the element's work, its internal queue and the wait for its push
downstream. A new `streaming/encoder-bench.sh` times that on the
session's own settings with nothing else in the pipeline: NVENC holds a
frame 9.2-11.3 ms across nine settings, at 30 as at 60 fps, in the
container too, and the session's 29 ms is the encoder waiting for
webrtcsink (a queue after it reads 3 ms with `pipelineMs` still 33).
No setting halves it, so no default changed. Numbers and the three
session runs are in docs/briefs/m15/fix6/k1-4/.

## Status row

k1-4 encoder: the encode stage is the encoder's element record (own work + its
internal queue + the wait for its src-pad push), and with nothing downstream the
element is 9.2-11.3 ms across nine settings and at 30 fps, so the session's 29
ms is `webrtcsink` taking its output (a queue after the encoder: stage 3,
pipelineMs 32.9, fps 56.1, unchanged frame path); no default changed, entrypoint
byte for byte, `streaming/encoder-bench.sh` added; open: what inside webrtcsink
costs 27 ms, and why the bench reads 4.6 ms in a 5 s window and 9.3 in a 20 s one.

## Delete

- none
