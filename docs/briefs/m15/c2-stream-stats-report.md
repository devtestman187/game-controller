# M15 c2: the stream measured end to end

The web player, the container and the host's stats framework now measure one
stream together, and `tools/stream.sh bench` prints the Streaming report for a
run without a person watching. Five runs were made in the `tp-stream` distro on
this PC (RTX 3080, WSL2): a 60 s Arena Bumper round at 1080p, a Shape Race, two
sessions at once, one session at 720p, and the latency card with 114 timed
presses. Press-to-screen came out at **203 ms median (p95 323)** and the whole
viewer's pipeline at **126 ms median (p95 131)** for one 1080p session, of which
the receiver's jitter buffer is 89 ms. Two sessions fall to **37 encoded fps
each**; the encoder element's 30 ms and the 8 ms the capture probe measured for
the same pipeline are **not** the same thing, and that gap is the one number
this job flags rather than explains (section 7).

## 1. What was built

| Piece | What it does | Where |
| --- | --- | --- |
| the player's reporter | one batch every 3 s of `getStats()` + `requestVideoFrameCallback` numbers, the flip it sees in the picture and the press times it matches | `streaming/player/reporter.js`, `streaming/player/metrics.js` |
| press-to-screen | the bench presses only after an observed flip; the page reads an 8×8 patch inside `rVFC`, converts the flip's time to the host's clock (pinged from `/clock`) and reports the press's own flip | `streaming/player/reporter.js`, `streaming/player/player.js` |
| the relay | `serve.py` serves the page and passes `/stats/stream`, `/player`, `/clock`, `/presses`, `/flips`, `/pipeline` to the host with the session's token, so the browser needs none | `streaming/player/serve.py` |
| the sampler | every 3 s: cgroup CPU (split into game / pipeline / rest), memory and peak, `nvidia-smi` GPU, encoder and memory, encoded fps, sessions at once, and the tracer's capture/encode/pipeline times | `packages/metrics/bin/stream_sampler.dart`, `packages/metrics/lib/src/stream_sampler*.dart` |
| the tracer's stages | the pipeline runs with `GST_TRACERS="latency(flags=pipeline+element)"`; the sampler turns its records into `stream_capture`, `stream_encode` and the `pipelineMs` gauge | `streaming/entrypoint.sh`, `packages/metrics` |
| ingest | `POST /stats/stream` takes a page's batch or a sampler's resources into the host's session summary; an unknown viewer id is refused | `packages/party_host/lib/src/automation/stream_ingest.dart` |
| the report | the Streaming resources table gained a `pipeline ms` column (the streaming CSV keeps its columns) | `packages/metrics/lib/src/report_stream.dart` |
| the benchmark | `bench` starts the sessions, a headless Chrome viewer each, a simulated player, the round (or the card), and copies the session summaries out and prints the report; `stats` reprints a run's report | `streaming/bench.sh`, `tools/stream.sh bench|stats` |

The entrypoint already starts the automation interface for the session (bind
`0.0.0.0` inside the container, a random 16-byte token in
`/run/thumb-party/automation.token`), waits until `status.ready` is true and the
pipeline has registered before it prints its own `ready:` line, and gives the
player page the automation port and token through `serve.py`.

## 2. The measurement chain

Every column of the Streaming report, where it comes from, and what it leaves
out. "Measured" means read from a clock or counter of the thing that does the
work; "derived" means computed from two measured numbers; "missing" means the
report has the column and the run cannot fill it, with the reason.

| Column | Where | How | Kind | Includes / excludes |
| --- | --- | --- | --- | --- |
| `input` | controller | the summary's controller stages | missing | no phone or simulated input path in these runs (the bench adds a player but presses nothing during a round) |
| `host` | app | the app's own stage records | missing | the app records none in these runs; the automation `frames.drawn` counter is its only timing-free count |
| `capture` | sampler | `element-latency` of `capsfilter0` (0.02 ms) + `videoconvert0` (2–3 ms) | measured | from the frame the compositor hands the converter to the encoder's sink pad; **excludes** the compositor's own paint and the source plugin's hold (the source and the sink emit no such record) |
| `encode` | sampler | `element-latency` of `nvautogpuh264enc0` (28–33 ms) | measured | the copy to the GPU and the encode, **including the wait for a free encoder slot**; excludes `h264parse` and `webrtcsink` |
| `send` | — | none | **missing** | GStreamer's tracer writes `element-latency` only for elements with a sink and a src pad, and a sink has no src pad: `ws` (webrtcsink), `webrtcbin` and the app sinks appear only in the pipeline record |
| `network` | player | succeeded candidate pair's `currentRoundTripTime` / 2 | derived | one-way estimate; no RTP `abs-capture-time` extension is carried, so the RTP leg itself is not measured |
| `jitter` | player | `jitterBufferDelay / jitterBufferEmittedCount` | measured | the receiver's buffer hold, which dominates the total |
| `decode` | player | `totalDecodeTime / framesDecoded` | measured | the decoder's own time |
| `display` | player | `rVFC` `presentationTime − expectedDisplayTime` | measured | 0 in headless Chrome: there is no real display, so the frame is "presented" at once. On a screen this would show the compositor's scheduling delay |
| `total` | report | sum of the stages above for one viewer | derived | not the app's draw, not the phone's touch; it is the sum of what the columns say |
| `press>screen` | bench + player | the bench calls `probe/press`, the page finds the card's flip in the video and subtracts the press's host time | measured | from the press's arrival at the host's automation interface to the frame that shows the flip; **includes** the compositor's frame, GPU copy, encode, network, jitter buffer, decode and browser compositing; **excludes** the phone's touch and radio (the press is made by an automation call, not a phone). A flip 500 ms or more after the press could be the card's own cadence and is dropped, not counted as slow |
| `audio ms` (`audio_capture_to_play`) | — | the probe cannot make a click | **missing** | the card is visual and the game's music has no onset the page can find; a click needs a sound the probe can trigger, which the app does not have yet |
| `sync ms` | player | audio vs video `estimatedPlayoutTimestamp` | derived | dropped when the two are more than 1 s apart (a renegotiation restarting one track's base) |
| `concealed %` | player | `concealedSamples / totalSamples` | derived | headless Chrome reports neither field, so it stays empty |
| `sent kbps`, `sent`, `keyframes`, `nacks`, `plis`, `firs` | — | one side the page cannot see | **missing** | these live on the sender (`outbound-rtp`, which the page has no access to) and `webrtcsink` exposes no stats to the sampler; the summary and the CSV carry the columns, waiting for a source |
| `recv kbps` | player | `bytesReceived` delta / window | measured | the page's own inbound bytes |
| `loss %`, `rtt ms`, `jitter ms` | player | `packetsLost/Received`, round trip, `jitter` | measured | — |
| `fps` | player | `inbound-rtp.framesPerSecond` | measured | Chrome's own count |
| `recv`, `decoded`, `dropped`, `late`, `freezes` | player | counter deltas; `late` counts frames `rVFC` never presented in time | measured | `dropped` is received − decoded (Chrome reports no drop counter of its own) |
| `first frame ms` | player / sampler | page: `play()` to the first `rVFC`; host: the first encoded frame the tracer saw | measured | two different starts; both are on the row |
| `reconnects` | player | a drop after the picture has played at least once | measured | a page that opens before the TV has a producer waits once and that wait is a start, not a reconnect |
| `relay`, `codec` | player | local candidate type, `codec.mimeType` | measured | — |
| `cpu %`, `game cpu %`, `enc cpu %` | sampler | cgroup v2 `cpu.stat` deltas split by `/proc/<pid>/stat` and `cmdline` | measured | percent of one core, the whole container (PulseAudio, the player's web server, the signalling server and the sampler included) |
| `mem MB`, `mem peak MB` | sampler | `memory.current`, `memory.peak` | measured | the container, not one process |
| `gpu %`, `enc %`, `gpu mem MB` | sampler | `nvidia-smi --query-gpu=utilization.gpu,utilization.encoder,memory.used` | measured | the **whole GPU**, so two sessions report the same GPU percentage |
| `game fps` | sampler | Δ `status.frames.drawn` / Δt | measured | the app's own draw rate, the same counter the app's `FRAME_STATS` used |
| `enc fps` | sampler | encoded-frame records per window from the tracer | measured | what leaves the encoder |
| `pipeline ms` | sampler | the tracer's `latency, src-element=waylanddisplaysrc0 … sink-element=ws` record | measured | one captured frame's whole way to `webrtcsink`, the sum of capture + encode + the queues between them |
| sessions at once | bench → entrypoint | `SESSIONS_AT_ONCE` | given | how many sessions this machine ran, for the per-machine table |

## 3. The runs

All five ran in the `tp-stream` distro, image `tp-session:latest`, 1920×1080@60
unless said, NVENC H.264 at a pinned 10 000 kbit/s CBR, Opus 96 kbit/s, one
simulated player and one headless-Chrome viewer per session, automation on.

| Label | Command (inside the distro) | Content | Window | Round recorded | Ready |
| --- | --- | --- | --- | --- | --- |
| `arena60` | `bench --seconds 65 --game arena --label arena60` | one session, Arena Bumper | 65 s | 1 round, `mode_bumper`, `map_toy-factory`, 60.0 s, finished | 3 s |
| `shape60` | `bench --seconds 65 --game shape_race --label shape60` | one session, Shape Race | 65 s | **none** (see below) | 4 s |
| `two60` | `bench --sessions 2 --seconds 65 --game arena --label two60` | two sessions, Arena Bumper | 65 s | 2 rounds, `map_playroom` and `map_block-castle`, 60.0 s each, finished | 3 s and 4 s |
| `hd720` | `bench --seconds 65 --size 1280x720 --game arena --label hd720` | one session at 720p, Arena Bumper | 65 s | 1 round, `map_pinball`, 60.0 s, finished | 4 s |
| `probe60` | `bench --seconds 60 --probe --label probe60` | one session showing the latency card | 60 s | — (114 timed presses) | 4 s |

The window is 65 s so that a 60 s round's finish (and its round record) lands
inside the measured window; the round itself is the first 60 s of it. Ready is
the container's own `ready:` line, counted from the start of `docker run`.

**Shape Race opened but recorded no round.** `POST game/start` with
`shape_race` was accepted and `GET status` reported `"screen":"game"` for the
whole 65 s (a fresh start watched for 17 s stays), the app drew at 46.7 fps
(`game fps`), and the stream carried 7335 kbit/s — a puzzle's static picture.
But the summary has no round and `frames.drawn` 0: the host's round record and
its frame count are the *round collector's*, and the puzzle's round never
reached it. The stream numbers in the tables are real; the round record is
missing and the reason is not established here (it is the app's, not the
measurement path's).

**`game/start` is dropped when it arrives too early.** In the first attempts the
bench's start was sent while the app was still warming up and the app stayed on
its home screen for the whole window (`screen: home`, `round: false` by the end
of a run whose numbers looked plausible). `bench` now waits for
`GET status` to say the game screen, checks it is still there 3 s later and
sends the start again if not, and fails the run if a session never gets there.
Every run in the tables passed that check, except that Shape Race shows
`screen: game` while recording no round (above).

## 4. Bench results

Stage columns are median/p95 in milliseconds, as the report prints them.
`send` and the controller's `input`/`host` are missing (section 2).

### 4.1 Pipeline stages

| Run · viewer | capture | encode | send | network | jitter | decode | display | total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arena60` 1080p | 2/2 | 30/30 | – | 1/1 | 89/94 | 4/4 | 0/0 | 126/131 |
| `shape60` 1080p | 2/2 | 30/30 | – | 1/1 | 105/107 | 3/3 | 0/0 | 141/143 |
| `two60` session A (`5aa4422fd43faedf`) | 4/5 | 17/18 | – | 1/1 | 91/93 | 7/7 | 0/0 | 120/124 |
| `two60` session B (`73eee4637d5c2c86`) | 4/4 | 17/18 | – | 1/2 | 77/93 | 6/7 | 0/0 | 105/124 |
| `hd720` 1280×720 | 1/1 | 32/32 | – | 1/1 | 111/113 | 2/2 | 0/0 | 147/149 |
| `probe60` card | 2/3 | 29/30 | – | 1/1 | 98/407 | 3/4 | 0/1 | 133/446 |

The probe run's p95s (407 and 446) are one hitch sample: its maximum is 446 ms
and its median 133. Everywhere else the stages are steady.

### 4.2 Quality

| Run · viewer | recv kbit/s | loss % | rtt ms | jitter ms | fps | recv / decoded / dropped | freezes | first frame ms | reconnects | relay | codec |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arena60` | 19 883 | 0.0 | 0.5 | 6.9 | 59.8 | 4123 / 4117 / 6 | 0 | 1230 | 0 | no | H264 |
| `shape60` | 7 335 | 0.0 | 0.5 | 2.4 | 59.6 | 4295 / 4289 / 6 | 0 | 1254 | 0 | no | H264 |
| `two60` A (`5aa4…`) | 11 893 | 0.0 | 0.9 | 11.1 | 37.5 | 2772 / 2769 / 3 | 0 | 1440 | 0 | no | H264 |
| `two60` B (`73ee…`) | 8 110 | 0.0 | 1.2 | 8.0 | 37.6 | 2903 / 2899 / 4 | 0 | 1436 | 0 | no | H264 |
| `hd720` | 18 668 | 0.0 | 0.1 | 6.1 | 60.1 | 4316 / 4309 / 7 | 0 | 1250 | 0 | no | H264 |
| `probe60` | 2 105 | 0.0 | 0.6 | 1.1 | 55.2 | 3481 / 3456 / 25 | 0 | 1281 | 0 | no | H264 |

Nothing was lost and nothing froze in any run, and no page reconnected. The
received bitrate is the picture's, not the pin: the card is almost static
(2.1 Mbit/s) and the puzzle nearly so (7.3), while the Arena fills the 10 000
kbit/s pin and overshoots it (19.9 Mbit/s, see section 7).

### 4.3 Sound

| Run · viewer | audio ms | sync ms | concealed % |
| --- | --- | --- | --- |
| every run | – (missing: no click to probe) | 0.0 (one reading per run) | – (missing: headless Chrome) |

The sound itself reached the viewer in every run (the encoder sent Opus and the
page decoded it); what is missing is the *onset* measurement: the probe cannot
make the app play a sound at a known instant, so `audio_capture_to_play` has no
source. Sync was read once per run, from the two playout timestamps, and was
0.0 ms.

### 4.4 Host resources (per container, mean and p95)

| Run · session | CPU % | game CPU % | encoder CPU % | mem MB | mem peak MB | GPU % | encoder % | GPU mem MB | game fps | enc fps | pipeline ms (mean / p95 / max) | host first frame ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `arena60` `25804d…` | 223.7 / 242.3 | 88.5 | 118.4 | 635 / 779 | 799 | 46.0 / 48.0 | 6.2 / 7.0 | 1433 | 44.7 | 56.9 | 38.9 / 34.3 / 143.0 | 1456 |
| `shape60` `b56851…` | 202.9 / 225.7 | 101.7 | 90.2 | 549 / 630 | 652 | 46.4 / 50.0 | 6.1 / 7.0 | 1455 | 46.7 | 55.8 | 38.7 / 34.2 / 144.3 | 1451 |
| `two60` A `5aa4…` | 269.1 / 298.9 | 108.3 | 139.4 | 594 / 689 | 715 | 66.0 / 67.0 | 10.2 / 15.0 | 1985 | 28.9 | 35.1 | 24.8 / 25.5 / 26.0 | 1624 |
| `two60` B `73ee…` | 248.4 / 278.3 | 104.4 | 126.0 | 557 / 642 | 663 | 65.6 / 69.0 | 11.2 / 17.0 | 1974 | 24.9 | 35.4 | 24.9 / 25.7 / 26.0 | 1504 |
| `hd720` `21bfed…` | 164.9 / 182.1 | 65.5 | 85.9 | 583 / 729 | 751 | 38.1 / 41.0 | 6.6 / 8.0 | 1286 | 57.6 | 57.2 | 38.7 / 34.3 / 142.5 | 1431 |
| `probe60` `3e697b…` | 174.1 / 201.0 | 81.6 | 82.9 | 500 / 528 | 551 | 49.6 / 53.0 | 6.0 / 6.0 | 1405 | – | 52.7 | 38.3 / 34.1 / 144.7 | 1428 |

The `pipeline ms` mean is pulled up by one startup sample (the max, 142–145 ms)
and its p95 is the honest steady-state number, 34.2–34.3 ms for one 1080p
session and 25.5–25.7 ms each with two. The GPU's percentages are the whole
GPU's, so two sessions show the same ~66 %.

### 4.5 Press-to-screen

`probe60`: **n = 114, median 203 ms, p95 323 ms, max 463 ms**, from the press's
arrival at the host to the frame the page saw showing the flip. The bench
presses only when it has seen the previous flip, so the card's own 500 ms
cadence cannot be mistaken for the press; a press whose flip comes ≥ 500 ms
later, or not before the next press, is dropped rather than recorded as slow.

What it includes: from the automation call's arrival, the card's colour change,
the compositor's frame, `videoconvert`, the GPU copy, the encode (30 ms), the
network (in-container, 1 ms round trip), the receiver's jitter buffer, the
decode, the browser's compositing and the page's `rVFC` presentation. What it
does not: the phone's touch and radio (there is no phone in these runs — the
press is an automation call over loopback), and the ~16.7 ms the source may hold
a frame for the next compositor tick. So this is a *lower bound* for a real
phone's press-to-picture, by at least the phone's own leg.

Per-frame `stream_display` is 0 in every run because headless Chrome has no
display to schedule against; the press number is the only end-to-end latency
measured on this page.

### 4.6 Ready and first frame

| Run | `ready:` after container start | host's first encoded frame, from the sampler | page's first frame, from `play()` |
| --- | --- | --- | --- |
| `arena60` | 3 s | 1456 ms | 1230 ms |
| `shape60` | 4 s | 1451 ms | 1254 ms |
| `two60` | 3 s / 4 s | 1624 / 1504 ms | 1440 / 1436 ms |
| `hd720` | 4 s | 1431 ms | 1250 ms |
| `probe60` | 4 s | 1428 ms | 1281 ms |

The host's first frame is later than the page's because the sampler's window
starts earlier (it sees the pipeline's first encoded frame from the session's
boot, the page starts counting when it calls `play()`), not because the page
saw a frame the host had not encoded.

## 5. The Streaming report output

`tools/stream.sh stats --results docs/briefs/m15/c2/results/<label>` prints
this from a fetched folder (only the Streaming part is shown below). First,
`docs/briefs/m15/c2/results/arena60`, one session playing Arena Bumper at
1920×1080:

```text
Streaming pipeline
session           viewer     kind         platform  input  host  capture  encode  send  network  jitter  decode  display    total  press>screen  src
----------------  ------  -------  ---------------  -----  ----  -------  ------  ----  -------  ------  ------  -------  -------  ------------  ---
25804dc9983bc187      v1  browser  chrome-headless      -     -      2/2   30/30     -      1/1   89/94     4/4      0/0  126/131             -    -

Streaming quality
session           viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
----------------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
25804dc9983bc187      v1          -    19883.4     0.0     0.5        6.9  59.8     -  4123     4117        6     0      0/0            1230           0     no   H264

Streaming sound
session           viewer  audio ms  sync ms  concealed %
----------------  ------  --------  -------  -----------
25804dc9983bc187      v1         -        -            -

Streaming resources
session           samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  pipeline ms  first frame ms  mem peak MB
----------------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  -----------  --------------  -----------
25804dc9983bc187       23  223.7        88.5      118.4   634.7   46.0    6.2      1432.6      44.7         -          -     56.9      -         38.9            1456        798.5

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
1                        1  223.7   46.0    6.2      44.7     56.9   634.7
```

`docs/briefs/m15/c2/results/shape60`, Shape Race at 1920×1080:

```text
Streaming pipeline
session           viewer     kind         platform  input  host  capture  encode  send  network   jitter  decode  display    total  press>screen  src
----------------  ------  -------  ---------------  -----  ----  -------  ------  ----  -------  -------  ------  -------  -------  ------------  ---
b56851f7e0777207      v1  browser  chrome-headless      -     -      2/2   30/30     -      1/1  105/107     3/3      0/0  141/143             -    -

Streaming quality
session           viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
----------------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
b56851f7e0777207      v1          -     7335.0     0.0     0.5        2.4  59.6     -  4295     4289        6     0      0/0            1254           0     no   H264

Streaming sound
session           viewer  audio ms  sync ms  concealed %
----------------  ------  --------  -------  -----------
b56851f7e0777207      v1         -        -            -

Streaming resources
session           samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  pipeline ms  first frame ms  mem peak MB
----------------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  -----------  --------------  -----------
b56851f7e0777207       24  202.9       101.7       90.2   548.5   46.4    6.1      1454.5      46.7         -          -     55.8      -         38.7            1451        651.9

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
1                        1  202.9   46.4    6.1      46.7     55.8   548.5

```

`docs/briefs/m15/c2/results/two60`, two sessions at once, both playing Arena
Bumper at 1920×1080:

```text
Streaming pipeline
session           viewer     kind         platform  input  host  capture  encode  send  network  jitter  decode  display    total  press>screen  src
----------------  ------  -------  ---------------  -----  ----  -------  ------  ----  -------  ------  ------  -------  -------  ------------  ---
73eee4637d5c2c86      v1  browser  chrome-headless      -     -      4/4   17/18     -      1/2   77/93     6/7      0/0  105/124             -    -
5aa4422fd43faedf      v1  browser  chrome-headless      -     -      4/5   17/18     -      1/1   91/93     7/7      0/0  120/124             -    -

Streaming quality
session           viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
----------------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
73eee4637d5c2c86      v1          -     8110.0     0.0     1.2        8.0  37.6     -  2903     2899        4     0      0/0            1436           0     no   H264
5aa4422fd43faedf      v1          -    11893.0     0.0     0.9       11.1  37.5     -  2772     2769        3     0      0/0            1440           0     no   H264

Streaming sound
session           viewer  audio ms  sync ms  concealed %
----------------  ------  --------  -------  -----------
73eee4637d5c2c86      v1         -      0.0            -
5aa4422fd43faedf      v1         -      0.0            -

Streaming resources
session           samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  pipeline ms  first frame ms  mem peak MB
----------------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  -----------  --------------  -----------
73eee4637d5c2c86       26  248.4       104.4      126.0   556.5   65.6   11.2      1974.2      24.9         -          -     35.4      -         24.9            1504        662.7
5aa4422fd43faedf       25  269.1       108.3      139.4   593.8   66.0   10.2      1985.3      28.9         -          -     35.1      -         24.8            1624        715.0

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
2                        2  258.8   65.8   10.7      26.9     35.3   575.2

```

`docs/briefs/m15/c2/results/hd720`, one session playing Arena Bumper at
1280×720:

```text
Streaming pipeline
session           viewer     kind         platform  input  host  capture  encode  send  network   jitter  decode  display    total  press>screen  src
----------------  ------  -------  ---------------  -----  ----  -------  ------  ----  -------  -------  ------  -------  -------  ------------  ---
21bfed45dc2f4827      v1  browser  chrome-headless      -     -      1/1   32/32     -      1/1  111/113     2/2      0/0  147/149             -    -

Streaming quality
session           viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
----------------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
21bfed45dc2f4827      v1          -    18667.8     0.0     0.1        6.1  60.1     -  4316     4309        7     0      0/0            1250           0     no   H264

Streaming sound
session           viewer  audio ms  sync ms  concealed %
----------------  ------  --------  -------  -----------
21bfed45dc2f4827      v1         -      0.0            -

Streaming resources
session           samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  pipeline ms  first frame ms  mem peak MB
----------------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  -----------  --------------  -----------
21bfed45dc2f4827       24  164.9        65.5       85.9   583.1   38.1    6.6      1285.8      57.6         -          -     57.2      -         38.7            1431        751.1

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
1                        1  164.9   38.1    6.6      57.6     57.2   583.1

```

`docs/briefs/m15/c2/results/probe60`, one session showing the latency card and
114 timed presses at 1920×1080:

```text
Streaming pipeline
session           viewer     kind         platform  input  host  capture  encode  send  network  jitter  decode  display    total  press>screen    src
----------------  ------  -------  ---------------  -----  ----  -------  ------  ----  -------  ------  ------  -------  -------  ------------  -----
3e697bd0ebb1bd98      v1  browser  chrome-headless      -     -      2/3   29/30     -      1/1  98/407     3/4      0/1  133/446       203/323  probe

Streaming quality
session           viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
----------------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
3e697bd0ebb1bd98      v1          -     2104.5     0.0     0.6        1.1  55.2     -  3481     3456       25     0      0/0            1281           0     no   H264

Streaming sound
session           viewer  audio ms  sync ms  concealed %
----------------  ------  --------  -------  -----------
3e697bd0ebb1bd98      v1         -      0.0            -

Streaming resources
session           samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  pipeline ms  first frame ms  mem peak MB
----------------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  -----------  --------------  -----------
3e697bd0ebb1bd98       21  174.1        81.6       82.9   500.1   49.6    6.0      1404.7         -         -          -     52.7      -         38.3            1428        551.0

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
1                        1  174.1   49.6    6.0         -     52.7   500.1
```

The summaries themselves are in `docs/briefs/m15/c2/results/<label>/`:
`arena60/arena600.json`, `shape60/shape600.json`, `two60/two600.json` and
`two60/two601.json`, `hd720/hd7200.json`, `probe60/probe600.json`.

## 6. Missing, and why

- **`stream_send`**: the tracer writes `element-latency` only for elements with
  a sink and a src pad; sinks (`ws`, `webrtcbin`) appear only in the pipeline
  record. The send stage needs the difference between the pipeline record's
  total and the last element's record, which the tracer does not give.
- **`sent kbps`, `frames sent`, `keyframes`, `nacks`, `plis`, `firs`**: the
  page can only read `inbound-rtp`; the sender's counters are the host's, and
  `webrtcsink` exposes no statistics the sampler can poll. The summary's counters
  and the streaming CSV already have the columns.
- **`audio_capture_to_play`**: the press probe cannot make a click — the latency
  card is a picture and the game's music has no onset to detect — so the page has
  nothing to time. This is the one field of the brief that cannot be measured
  with the app and probe as they are.
- **Concealed audio %**: Chrome reports neither `concealedSamples` nor
  `totalSamples` in these runs.
- **`stream_display`**: measured, but always 0: headless Chrome has no display
  to schedule a frame against.
- **The controller's `input` and `host` stages**: the app records none of its
  own input-to-draw timing in these runs, and the bench's simulated player
  presses nothing during a round.
- **The shape race round record**: missing (section 3).

## 7. Against the capture probe

The probe ([capture-probe-report.md](capture-probe-report.md)) measured the same
pipeline without `webrtcsink`'s consumer, without the viewer, and with the file
sink; it counted the app and the pipeline processes only.

| Number | Capture probe | This job | Better or worse |
| --- | --- | --- | --- |
| encoded fps, one 1080p session | 60.0 | 56.9 (p95 60.0) | **worse** |
| the app's own draw rate, one 1080p session | 55.0–59.6 fps | 44.7 fps | **worse** |
| GPU, one session | 45–47 % | 46.0 % (p95 48) | same |
| encoder, one session | 11–12 % | 6.2 % (p95 7) | lower (fewer frames reach NVENC) |
| encoded fps, two sessions | 43–45 each | 35.1–35.4 each | **worse** |
| the app's draw rate, two sessions | 28–31 each | 24.9–28.9 each | slightly worse |
| GPU, two sessions | 75–78 % | 65.6–66.0 % | lower |
| JPEG-to-encoded latency (the probe's tracer figure) | 7.99 ms mean / 9.32 p95 | capture 2 + encode 30 = 32 ms; pipeline p95 34.3 ms | **worse, and not comparable** |
| CPU per session | ~1.0 core app + ~0.3 pipeline | 224 % of a core, whole container | different scopes |
| jitter buffer (c1's figure) | 96–140 ms | 89–94 ms (1080p), 111–113 ms (720p) | better |

Four things are flagged:

1. **The encoder element holds ~30 ms per frame where the probe's whole
   pipeline cost 8 ms.** The element record is the GPU copy and the encode
   including the wait for the encoder, and with two sessions it drops to 17 ms
   (fewer frames, less waiting); with 720p it is 32 ms, so it is not the pixel
   count. The probe's 8 ms was the *pipeline* record of a pipeline that ended
   in a file sink; this job's pipeline record, on the same elements, is 34 ms.
   The difference is not explained by the tracer flags and is the first thing to
   investigate (section 8, item 2). Until it is, "capture 2 ms + encode 30 ms"
   and the probe's 8 ms must not be compared as if they measured the same thing.
2. **One session's app draws 44.7 fps where the probe's drew 55–59.6.** The
   bench adds what the probe did not have: a headless Chrome decoding 1080p
   H.264 in the same VM (not in the container, so it does not show in the
   container's CPU), and the app's automation overlay with its frame callback.
   The 720p run draws 57.6 fps, which points at the viewer's decode cost rather
   than the app. Not isolated here.
3. **Two sessions encode 35 fps each, not 43–45.** The GPU is *less* busy (66 %
   vs 75–78 %) and NVENC is at 10–11 % (vs 24–42 %), so neither is the cap; the
   CPU per container is higher (248–269 % vs ~190 %). The likeliest cause is the
   same single-threaded compositor and shm copies the probe named, now with a
   viewer's decode on the same cores — again not isolated.
4. **The pinned 10 000 kbit/s does not hold**: one 1080p Arena session sends
   19.9 Mbit/s. `nvautogpuh264enc` still ignores CBR's bitrate in this image
   (the probe found the same); the picture is fine, the pin is not a cap.

## 8. Tuning notes (not tuning)

Three settings most likely to cut the measured delay next, each with the stage
it would reduce:

1. **The receiver's jitter buffer: 89–94 ms of the 126 ms total at 1080p, and
   111–113 ms of 147 ms at 720p.** The page already sets `jitterBufferTarget`
   and `playoutDelayHint` to 0, so this is Chrome's floor for the jitter it
   sees, not a hint left at a default. Cutting it means making the arrival
   steadier (the two-session runs show jitter 8–11 ms, so the buffer is far
   above the network's own spread) or paying for less protection:
   `stream_jitter_buffer`, and with it `stream_total` and `press>screen`.
2. **The encoder element's 30 ms** (`stream_encode`). It is steady (p95 30) and
   falls to 17 ms under load, which says it is the wait for the encoder rather
   than the encode. `nvautogpuh264enc` runs `preset=p1 tune=ultra-low-latency
   b-frames=0 zero-reorder-delay=true rc-lookahead=0` already; the next things
   to test are `rate-control=cbr` vs `constqp`, a higher `bitrate` (the pin is
   not honoured), and whether the D3D12 GPU path (the game drawing at 46 % while
   NVENC waits) is the contention. Cuts `stream_encode` and `pipelineMs`.
3. **The compositor's frame rate with two sessions** (`game fps` 25–29,
   `enc fps` 35): pinning `videorate max-rate=40` (or starting the second
   session at 720p, where the encoder is 32 ms and the GPU 38 %) gives two
   households a steady rate instead of one that falls between 25 and 37. Cuts
   nothing by itself, but makes `stream_encode` and the two-session
   `press>screen` predictable.

And one measurement, not a setting: carrying `abs-capture-time` (or the
`webrtcsink` sender stats) would replace the derived `stream_network` (rtt/2,
~0.5 ms) and fill the missing sender columns; the RTP leg is the only part of
the chain with no clock on it.

## 9. Decisions

- **The probe runs as its own session**, not inside a round: the card covers the
  screen, so a press measured while it is up would measure the round's picture
  as seen through the card. `bench --probe` is that run.
- **The measured window is 65 s for a 60 s round**, so the round's finish (and
  its record) lands inside the window; the round is the first 60 s.
- **capture = caps filter + videoconvert; send = missing; a `pipelineMs` gauge
  added.** The tracer has no record for a source or a sink, so the alternative
  was to guess the send stage; the pipeline record measures the whole way
  instead and is reported next to the stages.
- **A press whose flip comes ≥ 500 ms later is dropped.** The card flips on its
  own 500 ms cadence, so a later change is ambiguous; 2 of the first run's 42
  samples were exactly that and were being counted as slow presses.
- **The jitter-buffer "minimum" run of the brief is the run we have**: the page
  forces the minimum (`playoutDelayHint = 0`) on every run, so a second run with
  a different hint would measure the same thing.
- **`bench` retries a round start** that the app dropped while warming up, and
  fails the run if a session never reaches the game screen (section 3).
- **`pipelineMs` went into the session model, the report and its table, not the
  streaming CSV.** The brief asks for the report's Streaming section; adding a
  CSV column would change a file format other tools read for no measured gain.

## 10. Tests and checks

| Suite | Count | Result |
| --- | --- | --- |
| `packages/metrics` (whole suite) | 142 | pass |
| `packages/metrics/test/report_stream_test.dart` | 6 (1 new) | pass |
| `packages/metrics/test/stream_sampler_test.dart` | 15 (4 new) | pass |
| `packages/party_host/test/automation_api_test.dart` | 9 (1 changed: the card's own cadence) | pass |
| `packages/party_host/test/stream_ingest_test.dart` | 3 (new file) | pass |
| `tv_test_app/test/stream_tool_test.dart` | 5 (2 new) | pass |
| `tools/check.sh format analyze metrics host tv` | 5 steps | pass (format, analyze, 142 + 407 tests, tv) |
| `bash -n` on `streaming/entrypoint.sh`, `streaming/bench.sh`, `tools/stream.sh` | — | clean |

The new tests, in the order they were made to fail first where they could:

- **the page's pure functions and the batch it makes**: `metrics.js` has no JS
  test runner, so its logic stays in small pure functions (the batched numbers
  are computed there) and the batch format is proved through the Dart ingest
  test: `stream_ingest_test.dart` feeds a complete fixture batch and checks every
  Streaming column of the report, then an id-reuse batch (one viewer row, two
  decode samples) and an unknown id (refused).
- **the sampler's parsing**: cgroup `cpu.stat`/`memory.current` text,
  `/proc/<pid>/stat` ticks, the `nvidia-smi` query output and the tracer's
  `element-latency`/`pipeline` lines are parsed by pure functions with fixture
  text (`stream_sampler_test.dart`), including which element is capture, encode
  and send-ish (`ws`), and which records form the pipeline (video branch only).
- **`bash -n`** for the three scripts, and the tool test also checks the bench's
  usage lines and that a bad label or a missing results folder is refused.

`tools/check.sh format analyze metrics host tv` passes at the end of the job
(format 3 s, analyze 8 s, `metrics` 142 tests, `host` 407 tests, `tv` 13 s). The
first run of it flagged three files as unformatted and one `curly_braces` info
after reformatting (`stream_sampler`); both were fixed and the run above is the
one after the fix. `bash -n` was checked after the last edit to each script.

## Self-check (review-rules part A)

1. **Every host setup: not affected.** Nothing in the app's screens, the
   controller protocol or the phone paths changed: the job adds a reporter to
   the web player page, a sampler and tracer to the container, an ingest call
   and a report column. An older host's summaries simply lack `pipelineMs` and
   the ingest ignores columns it is not given (`stream_ingest_test`,
   `report_stream_test`).
2. **When kept state starts and ends: the page's four keeps.** The viewer id
   (kept for the page's life; an unknown id is refused, `stream_ingest_test`),
   the reconnects counter (starts after the first presented frame; a wait for
   the producer is not a reconnect — 0 in every run), the press list (a press
   ends when its batch sends it, when it times out, or when a flip comes
   ≥ 500 ms later; `probe60` timed 114 and dropped the ambiguous ones), the
   clock offsets (5 kept, median used), the sampler's window lists (cleared every
   window; `stream_sampler_test` covers clear). With nothing going on the page
   sends rates of 0 and the press list stays empty.
3. **Combinations with other states: one pair only.** The card is measured
   instead of a round, never on top of one; the player page reads `getStats` and
   does not touch pause, away or the results, so no pair exists there. The
   automation token is per session and refused without it
   (`automation_api_test`).
4. **Stay in the job's folder: yes.** Only files under `allow:` were written:
   `streaming/` (`README.md`, `bench.sh`, `entrypoint.sh` and `player/`),
   `packages/metrics`, `packages/party_host`, `tv_test_app/test/stream_tool_test.dart`,
   `tools/stream.sh`, `docs/{automation,protocol,dev-tools}.md`,
   `docs/briefs/m15/c2-stream-stats-report.md` and the summaries under
   `docs/briefs/m15/c2/results/`.
5. **Stop rather than overstep: nothing needed outside `allow:`.** One rule
   could not be met and is said here rather than worked around: the brief's
   audio-onset field cannot be measured (no click to probe) and is reported
   missing. The other five runs, the checks and the fetched summaries all stayed
   inside the allowed files, and the bench's containers are stopped (`docker
   ps -a` is empty in the distro).

## Commit message

M15 c2: the stream measured end to end

The web player reports its batches (getStats + requestVideoFrameCallback, the
card's flip and timed presses) through the container's relay to the host's
stats/stream; the container's sampler sends cgroup CPU/memory, nvidia-smi GPU,
encoder and memory, the game's fps and the latency tracer's capture, encode and
pipeline times; the tracer gets a pipelineMs gauge and the report a column for
it. tools/stream.sh bench starts sessions with a headless viewer and a
simulated player, times presses against the latency card, fetches the summaries
into docs/briefs/m15/c2/results and prints the Streaming report; stats reprints
it. Measured: 1080p Arena at 60 fps, 126 ms total (jitter buffer 89), press to
screen 203 ms median (p95 323, n=114), 224 % CPU and 635 MB per container, GPU
46 %, encoder 6 %; two sessions 37 fps each, 720p 147 ms at 38 % GPU.

## Status row

c2 done: player, container and sampler report into the stats framework (every Streaming column measured or derived except input, host, send, the sender's counters, audio onset and concealed audio, each with its reason); bench/stats print the Streaming report; 1080p60 round: capture 2 + encode 30 ms, network 1, jitter buffer 89/94, decode 4, total 126/131, press>screen 203/323 (n=114), 19.9 Mbit/s, 0 loss, 0 freezes, 224 % CPU, 635 MB, GPU 46 %, enc 6 %; two sessions 37 encoded fps and 25-29 game fps each at 66 % GPU; 720p total 147/149 at 38 % GPU; open: the encoder element holds 30 ms against the probe's 8 ms, one session's app draws 44.7 fps against the probe's 55-59.6, the 10 Mbit/s pin is still ignored, sender stats (sent kbps, keyframes, NACK/PLI) have no source, Shape Race's round is not recorded, audio onset cannot be probed.

## Delete

- None: the summaries under `docs/briefs/m15/c2/results/` are the evidence for this report and stay with it.
