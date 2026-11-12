# M15 fix7 n1 phase 2 — `SESSION_AUDIO=off` and `separate` against the baseline

## Summary

**Headless Chrome, not Safari.** Six 45 s probe runs, 1080p60, one session and one headless Chrome
viewer each: three with `--set SESSION_AUDIO=off` and three with `SESSION_AUDIO=separate`, compared
with n0's three untouched baselines. A headless run says whether a switch works and what it does to
the host and to Chrome; the phone decides whether it helps.

- **`off`** (no sound at all): jitter buffer 28 / 17 / 14 ms against the baseline's 136 / 96 / 107;
  stream total 37 / 26 / 23 (171 / 131 / 142); press median 128 / 130 / 136 (244 / 205 / 218).
  69–116 ms of press and 68–122 ms of buffer below the baseline, far outside both spreads.
- **`separate`** (sound on its own connection): jitter buffer 14 / 13 / 13 ms, total 49 / 48 / 48,
  press median 145 / 146 / 143. The viewer's side matches `off`, so the sync wait is gone; the
  host's side does not move (encode stage 29 ms, `pipelineMs` 40.5–40.8, webrtcsink `queue0` 18.0,
  encoder element 34.2 ms, all as in the baseline). Only `off` removes the host's wait (encode stage
  1–2 ms, `pipelineMs` 7.7, encoder element 3.2 ms).
- The sound in `separate` arrives on its own producer and connection: Chrome holds 55.7 / 60.0 /
  60.2 ms for it (`audioJitterMs`), opusenc spends 20.2 ms, the target is 96 kbit/s. `off` has none.
- Both variants lengthen the press tail: p95 311–453 and max 367–498 against the baseline's p95
  241–275 and max 270–283, while the median falls. Five of six runs are above the baseline p95.
- One viewer row (`browser/chrome-headless`) with receive data in every run, 11 stage rows, 2747–2983
  frames received, 2–3 dropped, no freezes, 2083–2132 kbit/s received, `encodedFps` 55.9–57.0, game
  17.1–20.0 ms/frame: the picture itself is untouched by the switch.
- Verdicts: `off` **works as intended**; `separate` **works as intended on the viewer side** and has
  no effect on the host side; **the phone decides** for both (commands in "The owner's runs").

## Method

`streaming/bench.sh` inside `tp-stream`, not `tools/stream.sh` (the distro route the earlier run
phases used): the checkout was put there by `tools/wsl-sync.sh tp-stream`, and the six runs were
driven by one small script started in the background (its log read twice, not once per run).

- Image `tp-session:latest`, `sha256:6bbd5f47f424d9a2a4b7e5cca7ebbb8f638a4407042781e23ef3c8d5ac60a0c6`
  (the n1-1 build). Its `/usr/local/bin/entrypoint.sh` and `player/player.js` are sha256-identical to
  HEAD, so nothing was rebuilt: this phase changes no file the image carries.
- Each run: `bash streaming/bench.sh --probe --seconds 45 --label <label> --out /work/stream-bench/<label> --keep --set SESSION_AUDIO=<off|separate>`,
  then `docker cp` of `pipeline.log` and `docker rm -f` (the loop's last container was removed by
  hand afterwards; `docker ps` shows none).
- `switches.txt` of every run names its setting (`switches: SESSION_AUDIO=off, player-query none,
  player-options none`; `separate` likewise), and every container's ready line ends `audio=off` or
  `audio=separate`.
- The six summaries are in `n1-2-audio-run/` (`n1off00.json` … `n1sep20.json`) and `bench.log` is the
  loop's log. Element and path latencies come from the runs' `pipeline.log` (whole-run means of the
  `element-latency` records, as in n0-2).
- GStreamer 1.24.2, webrtcsink 0.13.6-RELEASE, same image as n1-1; 1 session, 1 simulated player, one
  headless Chrome, nothing else running.

## The six runs

Medians/p95 unless said otherwise, ms. `jitter` is the viewer's `stream_jitter_buffer`, `total` the
`stream_total` stage (capture + encode + network + jitter + decode), `press` the probe's
press-to-screen, `encode` the stage the page copies from the host, `q0` webrtcsink's own `queue0`
from `pipeline.log`.

| run | jitter | total | press (n, max) | pipelineMs | encFps | encode | capture | network | decode | q0 | audioJitter |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `n1off00` | 28/32 | 37/41 | 128/422 (83, 495) | 7.60 | 56.99 | 1 | 2 | 3 | 3 | 12.3 (n8) | – |
| `n1off10` | 17/18 | 26/27 | 130/311 (82, 410) | 7.71 | 56.76 | 1 | 3 | 3 | 2 | 12.4 (n8) | – |
| `n1off20` | 14/17 | 23/26 | 136/411 (79, 496) | 7.71 | 55.87 | 2 | 3 | 1 | 3 | 14.2 (n8) | – |
| `n1sep00` | 14/17 | 49/53 | 145/364 (80, 498) | 40.46 | 56.77 | 29 | 2 | 1 | 3 | 18.0 | 55.71 |
| `n1sep10` | 13/15 | 48/51 | 146/453 (78, 479) | 40.64 | 56.07 | 29 | 2 | 1 | 3 | 18.0 | 59.98 |
| `n1sep20` | 13/16 | 48/52 | 143/238 (82, 367) | 40.75 | 56.88 | 29 | 2 | 1 | 3 | 18.0 | 60.21 |

The baselines they are judged against (n0-2, same command, nothing set):

| run | jitter | total | press (n, max) | pipelineMs | encFps | encode | q0 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `n0b0` | 136/137 | 171/173 | 244/275 (90, 283) | 33.66 | 56.56 | 29 | 18.1 |
| `n0b1` | 96/101 | 131/137 | 205/241 (89, 278) | 40.33 | 55.39 | 29 | 18.1 |
| `n0b2` | 107/108 | 142/144 | 218/252 (89, 270) | 40.32 | 55.96 | 29 | 18.0 |

Noise: the baselines' spread is 39 ms on press median, 34 on press p95, 40 on jitter, 40 on total,
6.7 on `pipelineMs`, 1.2 on `encodedFps`; a variant's own spread is 8 / 111 / 14 / 14 (off) and
3 / 215 / 1 / 1 (sep) on press median / p95 / jitter / total. Every claim below clears both, and
what does not is called noise.

Run level facts, all six: 1 viewer row, `v1`, `browser/chrome-headless`, 11 stages and receive
gauges; received 2093.7 / 2117.6 / 2109.1 (off) and 2111.5 / 2083.5 / 2132.0 kbit/s (sep) against
the baseline's 2096–2113 kbit/s (probe card, 10000 ceiling); 2747–2983 frames received, 2–3
dropped, 0 freezes, first frame 1359–1578 ms; cpu 155–157 % (off) and 170–178 % (sep), gpu 45.7–51.7
%, game 17.1–20.0 ms/frame; the window ended after 52–57 s.

## Answers

**1. With `off`, is the jitter buffer different from the baseline by more than the noise?** Yes, by
far. Buffer 14–28 ms against 96–136 (68–122 ms lower), total 23–37 against 131–171, press median
128–136 against 205–244 (69–116 ms lower) — all several times the 39–40 ms noise, with the variant's
own runs tighter than 15 ms. So the upper bound of what the sound's presence (and with it Chrome's
lip-sync group) costs a viewer is about **70–120 ms of buffer and 70–116 ms of press**: that is what
`off` takes away. The host side falls with it (encode stage 29 → 1–2 ms, encoder element 34 → 3.2,
`pipelineMs` 40.3 → 7.7); `off` is therefore not a pure viewer-side change, but a run with no sound
has nothing for the encoder to wait for.

**2. With `separate`, does it match `off` or stay at the baseline?** It matches `off` on the viewer's
side: buffer 13–14 ms (off 14–17 in its two settled runs; off's first run 28 is the same first-run
elevation the baselines show), total 48–49 ms (off 23–37, 11–25 ms more, inside the 40 ms noise),
press median 143–146 (off 128–136, 7–18 ms more, inside noise). So **the sync wait was the cause and
the separation takes effect**. The evidence that the separation is real, in every `separate` run:

- the ready line's `pipeline registered: TP-Picture (522a24eb…);TP-Sound (0fee94f9…)` (ids differ per
  run), where the `off` runs registered one unnamed producer (`3a08469a-…`);
- the page's `audioJitterMs` gauge 55.71 / 59.98 / 60.21 ms: the page only sets that gauge from the
  sound's *own* connection (n1-1's `setSoundGauges`), so the sound reached the page on a stream of
  its own; `off` has no such gauge;
- `pipeline.log` has `pulsesrc0 → ws-audio` latency records and `opusenc0` 20.2 ms per run, and no
  `opusenc` at all in any `off` run;
- no audio track on the picture's connection: the picture's `audioSyncMs`/audio gauges are absent and
  the received video bitrate is the baseline's.

What does **not** match `off` is the host: encode stage 29 ms, encoder element 33.9–34.2,
`pipelineMs` 40.5–40.8, webrtcsink `queue0` 18.0 — the 28 ms k1-4 measured, still there with the
sound on a second sink. So `separate` buys the viewer's buffer and press and leaves the host's hold
alone. (In `off`, `queue0` has only 8 latency records, startup ones, so its 12–14 ms is not
comparable to the 18.0 of the other runs; the encoder element and the encode stage are the host
evidence.)

**3. What the sound does in each.** `off`: no sound at all — no `pulsesrc`/`opusenc`/`ws-audio` in
the pipeline, no audio gauge, the overlay says `sound none`. `separate`: the sound on its own
producer, peer connection and stream id, played on its own element; Chrome holds 55.7–60.2 ms for it
(the overlay's `sound jitter`), opusenc costs 20.2 ms on the host, and its target is the default 96
kbit/s (`SESSION_AUDIO_BITRATE_BPS`). The overlay's **audio bitrate** is computed by the page from
the audio receiver's byte count; the summary carries only `audioJitterMs`, not that bitrate, so the
measured audio bitrate is not in the tables — the target is 96 kbit/s and the video is unchanged
(video 4716 kbit/s in the ready line of all six runs, 2083–2132 kbit/s received against the
baseline's 2093–2118).

**4. The tail.** Both variants lower the press median and lengthen the tail: p95 311–422 (off) and
238–453 (separate) against 241–275, max 367–498 against 270–283. Five of six runs are above the
baseline p95; the exception is `n1sep20` (238). The sample counts are 78–83 presses against the
baseline's 89–90, so the tail is not a small-sample artefact. A small buffer that a late frame cannot
be hidden in would look like this; nothing here says whether a phone shows it, and no run exposed a
bug to fix.

The owner's runs ("the phone decides"), one per variant:

```bash
tools/stream.sh bench --probe --seconds 45 --label phone-off --set SESSION_AUDIO=off --viewer external
tools/stream.sh bench --probe --seconds 45 --label phone-sep --set SESSION_AUDIO=separate --viewer external
```

There is no `--player-query` form for either: the audio switch is a pipeline setting and the page
follows what the stream carries (n1-1), so the page has no audio key to put on its URL. `--player-query`
is how the batch's page-side switch travels (`--player-query <key>=<value>`, appended to the URL the
phone opens), and n2's zero-playout-delay switch is the first that needs it.

## Decisions

- `--set SESSION_AUDIO=…` with `streaming/bench.sh` in `tp-stream`, not `tools/stream.sh`: the route
  the earlier run phases used, so the numbers are comparable and the distro holds the image.
- No image rebuild: the image's entrypoint and player are byte-identical to HEAD (sha256 checked),
  and this phase changes no file the image copies.
- `--keep` on every run, to copy `pipeline.log` (element latencies) before removing the container;
  containers removed in the same loop.
- No code change: nothing failed, nothing was exposed as a bug. The missing audio-bitrate gauge and
  the empty `/player` body (below) are written up as suggestions, not acted on.
- The variants are reported as measured, including the press tail, rather than smoothing it away.

## Open

- The page's `/player` body came back empty after every run (`docker exec … curl -s` after the bench
  returned nothing, as it did not in n1-1), so this phase has no per-run msids. The evidence for
  `separate` is the producer registration, the page's `audioJitterMs` gauge and `pipeline.log`.
  Suggestion: if the msids are wanted per run, the bench could save the last `/player` body while it
  waits for the viewer to play.
- The press tail (p95/max) is unexplained and belongs to the phone runs.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup.** No app or player code changed; `SESSION_AUDIO` is a session-image setting.
   A TV or PC host, a phone on "Play on this phone" / "Show on this device", a joined phone and a
   phone one build older all keep the old pipeline (`joined`) and the old page, because nothing in
   this job touched them; the Linux session host ran both new values with one headless viewer.
2. **When kept state starts and ends.** No state added. The runs' own state: six containers started
   and removed (the loop's last one by hand), `docker ps` shows none; the loop script and its log are
   removed from the distro.
3. **How a new state combines with the others.** No new state. Each run is one session, one viewer,
   one switch, recorded in its `switches.txt`; the press probe is the only timed thing and it ends
   with the run.
4. **Stay in the job's folder.** Only `docs/briefs/m15/fix7/n1-2-audio-run/` (six summaries,
   `bench.log`) and this report were written. The three `tv_test_app/**/generated_plugin_*` files git
   reports as modified carry the checkout's own 14:24 timestamp and were not touched here; no other
   file in the tree changed.
5. **Stop rather than overstep.** No file outside `allow:` was touched and no default changed; the
   `off`/`separate` behaviour is behind the switch and `joined` is still the default.

## Questions and suggestions

1. `separate` leaves the host's 28 ms encode wait in place (only `off` removes it). Is the batch's
   technique (1) meant to remove it, or is that the sender switch's (n3) job?
2. The press tail grows in both variants (p95 up to 453, max up to 498). Should the phone runs watch
   p95 and stalls, and should n2/n3 consider a buffer floor?
3. The summary has no audio-bitrate gauge (only `audioJitterMs`); adding one would let a report say
   what the sound costs, not just what it holds.
4. For the phone runs, the two commands above are enough; no page query is involved.

## Hand-over

- Exists now: six 45 s headless probe runs for `SESSION_AUDIO=off` and `separate` with their summaries
  (`docs/briefs/m15/fix7/n1-2-audio-run/n1off0{0,1,2}.json`, `n1sep0{0,1,2}.json`) and `bench.log`.
- Numbers (headless Chrome): jitter 28/17/14 (`off`) and 14/13/13 (`separate`); total 37/26/23 and
  49/48/48; press median 128/130/136 and 145/146/143, p95 422/311/411 and 364/453/238; pipelineMs
  7.6–7.7 and 40.5–40.8; encFps 55.9–57.0; `audioJitterMs` 55.7–60.2 in `separate` only. Baselines:
  jitter 136/96/107, total 171/131/142, press 244/205/218, pipelineMs 33.7–40.3.
- Commands that worked (from `/work/flash-20261112-142429-18546` in `tp-stream`, image unchanged):

      bash streaming/bench.sh --probe --seconds 45 --label n1sep0 --out /work/stream-bench/n1sep0 --keep --set SESSION_AUDIO=separate
      docker cp thumb-party-n1sep00:/run/thumb-party/pipeline.log /work/stream-bench/n1sep0/pipeline-n1sep00.log
      docker rm -f thumb-party-n1sep00
      tools/wsl-fetch.sh tp-stream /work/stream-bench/n1sep0/summaries/n1sep00.json docs/briefs/m15/fix7/n1-2-audio-run/n1sep00.json

- Do not redo: these six runs, the image build (it is HEAD), the baseline comparison, the n1-1 design.
- Open: the phone runs decide; the press tail; the host's 28 ms wait survives `separate`; the empty
  `/player` body after a run.

## Commit message

docs: fix7 n1-2 audio off and separate against the baseline

Six 45 s headless probe runs, three each with SESSION_AUDIO=off and separate, against n0's
three baselines. With off the viewer's jitter buffer falls to 14-28 ms (baseline 96-136) and
press median to 128-136 (205-244); with separate the buffer (13-14) and press (143-146) match
off, so Chrome's sync wait is gone, while the host keeps its 29 ms encode wait and 40.5 ms
pipeline. Both lengthen the press tail (p95 up to 453). Headless Chrome, not Safari: the phone
decides. Summaries in fix7/n1-2-audio-run/; no code changed.

## Status row

n1 phase 2 (run) done: three 45 s headless probe runs each with SESSION_AUDIO=off and separate against the n0 baselines (buffer 14-28 and 13-14 ms, press 128-136 and 143-146 ms against 96-136 and 205-244; separate matches off on the viewer's side and leaves the host's 29 ms encode wait); open: the owner's two phone runs, the press tail (p95 up to 453), the host wait in separate, and n2/n3.

## Delete

- none
