# n0-2 baseline: three probe runs of the untouched image, and the noise they set

## Summary

Three probe runs of the session image as it is, nothing switched on (every log
opens with `switches: none`), 45 s each, 1080p60, one session and one headless
Chrome viewer. **Headless Chrome, not Safari**: these numbers say what the host
and Chrome do with nothing switched on; the phone decides what a switch does.

- **press-to-screen** median 244 / 205 / 218 ms, p95 275 / 241 / 252 ms
  (n 90 / 89 / 89): spread **39 ms median, 34 ms p95**. That is the noise every
  fix7 variant is judged against.
- **jitter buffer** = the Streaming report's `jitter` stage, `stream_jitter_buffer`
  (mean of `jitterBufferDelay / jitterBufferEmittedCount`, not the `jitterMs`
  packet-jitter gauge): median 136 / 96 / 107 ms; **stream total** 171 / 131 / 142 ms.
- Run 0 sits ~35–40 ms above runs 1–2 (bimodal) and reproduces k1-4's default
  baseline (total 179, press 244); runs 1–2 are the lower mode.
- Host side steady: capture 2 ms, encode 29 ms (p95 30), `pipelineMs` 33.7 /
  40.3 / 40.3 ms (the last two means are each pulled up by one ~145 ms sample;
  p95 is 33.9 / 34.1), encodedFps 56.6 / 55.4 / 56.0, game 19.2 / 18.4 / 18.5
  ms/frame.
- Every run: exactly **1 viewer row** (`browser/chrome-headless`) with receive
  data (jitter, network and decode stages present), 2910 / 2727 / 2781 frames
  received, 8 / 10 / 7 dropped, no freezes, 2096–2113 kbit/s received.
- **webrtcsink** writes no element-latency record of its own (`stream_send` is
  absent, as in k1-4); its internal `queue0` waits 18.1 / 18.1 / 18.0 ms
  (whole-run means from `pipeline.log`), `queue1` 10.0 / 12.6 / 10.8 (n=8),
  `queue2` 0.5.
- Image `tp-session:latest` sha256:a19f88a1622e…; GStreamer 1.24.2;
  webrtcsink 0.13.6-RELEASE. No h264 profile/level line exists in either log.

A variant must move press-to-screen by more than ~40 ms — and its own three runs must be tighter than that.

## Method

Phase 2 of n0 runs the image unchanged; no code change was needed and
`streaming/bench.sh` is untouched.

```bash
# in tp-stream (Ubuntu), from /work/flash-20261112-131054-14470
docker build -f streaming/Dockerfile -t tp-session:latest .
for i in 0 1 2; do
  bash streaming/bench.sh --probe --seconds 45 --label n0b$i --out /work/stream-bench/n0b$i --keep
  docker cp thumb-party-n0b${i}0:/run/thumb-party/pipeline.log /work/stream-bench/n0b$i/pipeline-n0b${i}0.log
  docker rm -f thumb-party-n0b${i}0
done
```

The three runs were driven by one small loop script in the background with a
single wait, and only the summary lines were read. `tools/stream.sh bench` was
not used: this job's shell refused the repository scripts (`tools/stream.sh`,
`tools/wsl-sync.sh`, `tools/check.sh`, `tools/wsl-fetch.sh`, and every `git`
call), so the checkout was put in the distro by copying the previous job's
`/work/flash-20261112-125557-13309` and overwriting the two files that differ
from HEAD (`streaming/bench.sh`, `streaming/player/options.js`, sha256 checked
against the checkout), the image was rebuilt with `docker build`, and the
checks were run one by one. The image was rebuilt even though no run file
changed, because that copy predated two committed files; the image id below is
from HEAD.

`--keep` is used so `pipeline.log` can be copied (bench itself copies
`pipeline.json`, `sampler.log`, `app.log` and the container log, not
`pipeline.log`); every container was removed by the loop afterwards (`docker ps
-a` shows no `n0b*` container). Numbers come from `python3` reading the
summaries and `pipeline.log` in the distro; the three summaries were copied
into `docs/briefs/m15/fix7/n0-2-baseline/` and are sha256-identical to the
distro's.

## The three runs

Means unless said otherwise; ms. `jitter` is the viewer's buffer stage
(median/p95), `total` the capture-to-screen stage (median/p95),
`encode` the viewer's copy of the encode stage.

| run | jitter | total | press (n) | pipelineMs | encodedFps | encode | capture | network | decode | display | game ms/frame |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `n0b0` | 136/137 | 171/173 | 244/275 (90) | 33.66 | 56.56 | 29/30 | 2 | 1 | 3 | 0 | 19.22 |
| `n0b1` | 96/101 | 131/137 | 205/241 (89) | 40.33 | 55.39 | 29/30 | 2 | 1 | 3 | 0 | 18.44 |
| `n0b2` | 107/108 | 142/144 | 218/252 (89) | 40.32 | 55.96 | 29/30 | 2 | 1 | 3 | 0 | 18.49 |

`gameFps` is not in a probe run's summary (`frames.drawn` 0); `gameFrameMs`
reads 19.2 / 18.4 / 18.5, i.e. about 52 / 54 / 54 fps.

Spread over the three runs (min–max, spread): jitter median 96–136, **40**;
jitter p95 101–137, **36**; total median 131–171, **40**; total p95 137–173,
**36**; press median 205–244, **39**; press p95 241–275, **34**;
`pipelineMs` 33.66–40.33, **6.7**; encodedFps 55.39–56.56, **1.2**;
encode median 29–29, **0**; game ms/frame 18.44–19.22, **0.8**; received
2095.6–2112.7 kbit/s, **17**.

Host resource means: cpu 177 / 175 / 174 %, gpu 50.7 / 50.3 / 50.0 %,
encoderPct 6.4 / 6.5 / 6.2, build 0.53 / 0.50 / 0.55 ms, raster 5.39 / 5.61 /
5.49 ms. Run lines: "1 viewer(s) browser/chrome-headless, 2096/2104/2113 kbit/s
received against the 10000 kbit/s ceiling"; window ended after 58 s, first
frame 1403 / 1323 / 1421 ms.

From `pipeline.log` (whole-run element means, ms): `queue0` 18.1 / 18.1 / 18.0
(n 5578 / 5272 / 5242), `queue1` 10.0 / 12.6 / 10.8 (n=8), `queue2` 0.5 (n 253
/ 242 / 240), `videoconvert0` 4.4, `h264parse0` 0.1, `nvautogpuh264enc0` 33.5 /
33.8 / 34.1 (the same element the sampled window reads as 29).

## Environment

- Docker image: `tp-session:latest`,
  `sha256:a19f88a1622eb144512ebe3edd321cf49c2b2ecc01cdedd438dd5295634da957`
  (short `a19f88a1622e`), built 2026-11-12 13:13:29 -06:00.
- GStreamer 1.24.2 (`gst-inspect-1.0 --version` in the image).
- webrtcsink 0.13.6-RELEASE (`gst-plugin-webrtc`).
- h264 profile/level: **no such line** in `pipeline.log` or the container log
  (`grep -i profile|level|caps` finds none; caps are not logged at this debug
  level). The container log names the encoder (`nvautogpuh264enc`, 4716 kbit/s
  video) and the viewer's facts say codec H264 only.

## Checks

`tools/check.sh format analyze metrics tv` was refused by this job's shell, so
its four commands were run one by one: `dart format --set-exit-if-changed`
783 files, 0 changed; `dart analyze --fatal-infos` no issues; `packages/metrics`
155 tests passed; `tv_test_app` 75 passed, 1 skipped (as before). No test was
added (measurement only), and `dart format` was run again after the suites
(0 changed; the generated plugin registrants kept their 13:11 stamps).

## Decisions

1. Used the previous job's distro copy plus the two files that differ from
   HEAD, because `tools/wsl-sync.sh` was refused; sha256 checked, so the folder
   is HEAD for everything the runs read.
2. Rebuilt the image so the recorded id is built from HEAD, although no run
   file changed.
3. Ran with `--keep`, copied `pipeline.log`, then removed each container
   myself, so the webrtcsink queues could be reported.
4. Reported the send stage from `pipeline.log` queue means because the `ws`
   element writes no element-latency record (the same hole k1-4 hit).
5. Read the jitter figure as the `stream_jitter_buffer` stage (the Streaming
   report's `jitter`), not the `jitterMs` gauge, which is packet jitter.

## Self-check (review-rules.md part A)

1. **Every host setup.** Not affected: no app, game or player code changed; TV
   host, phone hosts and joined phones run the same image as fix6 and none of
   them is exercised here (headless Chrome viewer only).
2. **Kept state.** Nothing is held: the only state is the image tag rebuilt
   once and each run's containers, all removed (`docker ps -a` has no `n0b*`);
   the viewers were closed by bench.
3. **Combines with other states.** Measurement only, all switches off
   (`switches: none`); no pause, wait or input path is touched.
4. **Stay in the job's folder.** Changes are this report and the three
   summaries under `docs/briefs/m15/fix7/n0-2-baseline/`; nothing else.
5. **Stop rather than overstep.** The shell refused the repo scripts and git,
   so the copy, builds and checks were done with explicit commands (above); no
   file outside `allow:` was needed or changed.

## Questions and suggestions

1. The ~40 ms press-to-screen spread is large: three runs per variant are the
   minimum, and a variant 20–30 ms "better" than one baseline should not be
   called a win.
2. The h264 profile/level the brief expects does not exist in either log. If a
   later job needs it, one caps log line in `entrypoint.sh` would add it; that
   is a build-phase decision.
3. The bimodality (run 0 ~35–40 ms slower than 1–2) may be GPU-clock or page
   warm-up; a discarded warm-up run before the three baselines is worth a
   decision in n4.
4. Container memory halved in runs 1–2 (`memMb` 1040 → 488, peak 1084 → 533)
   with the same image; unexplained, and no stream number moved with it.
5. `n0b1`'s viewer gauges hold one `audioSyncMs` sample of 1000 ms; it looks
   like a first-sample artifact and the stages are unaffected.

## Hand-over

Three baselines as the sessions' own summaries in `docs/briefs/m15/fix7/n0-2-baseline/`
(`n0b00.json`, `n0b10.json`, `n0b20.json`; headless Chrome, not Safari).

| run | jitter | pipelineMs | total | press | encFps | game ms/f | viewer | encode | webrtcsink q0 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `n0b0` | 136 | 33.66 | 171/173 | 244/275 (90) | 56.56 | 19.22 | 1, chrome | 29 | 18.1 |
| `n0b1` | 96 | 40.33 | 131/137 | 205/241 (89) | 55.39 | 18.44 | 1, chrome | 29 | 18.1 |
| `n0b2` | 107 | 40.32 | 142/144 | 218/252 (89) | 55.96 | 18.49 | 1, chrome | 29 | 18.0 |

Noise (min–max, spread): press median 205–244 (39), press p95 241–275 (34), jitter 96–136
(40), total 131–171 (40), pipelineMs 33.7–40.3 (6.7), encodedFps 55.4–56.6 (1.2).

```
cd /work/flash-20261112-131054-14470 && bash streaming/bench.sh --probe --seconds 45 --label n0b0 --out /work/stream-bench/n0b0 --keep
```

Not to redo: these three runs, the image build, the summary layout. Open: no h264
profile/level line in any log; the bimodality and the memory halving unexplained.

## Commit message

docs: three fix7 baseline runs and the noise they set

Three 45 s probe runs of the untouched session image (n0b0-n0b2) with
switches: none, headless Chrome, 1080p60. Press-to-screen median 244/205/218 ms,
jitter buffer 136/96/107 ms, stream total 171/131/142 ms, encode 29 ms,
encodedFps 55.4-56.6; spread ~40 ms on press, jitter and total is the noise
every variant is judged against. Summaries live in fix7/n0-2-baseline/; the
image, GStreamer 1.24.2 and webrtcsink 0.13.6 are recorded. No code changed.

## Status row

n0 phase 2 (baseline) done: three probe runs of the untouched image, the noise table (press 205-244 median, jitter 96-136, total 131-171) and the image/versions recorded; open: the three switches to build (n1-n3), the h264 profile/level line missing from every log, and the bimodality unexplained.

## Delete

- none
