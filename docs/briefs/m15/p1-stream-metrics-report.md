# M15 p1: streaming measurements in the stats framework — report

The session summary gains a `stream` record, `SessionCollector` gains the calls a host makes to fill it, and the
CLI report gains a Streaming section and a stream CSV. Nothing feeds it yet: the host's ingest is job a2 and the web
player and the container's sampler are job c2.

## Files changed

- `packages/metrics/lib/src/stream_names.dart` (new): the stage, kind and resource names as `StreamStage`,
  `StreamKind` and `StreamResource`, with the pipeline order and the two controller stages used for the estimate.
- `packages/metrics/lib/src/stream_resource_sample.dart` (new): `StreamResourceSample`, one reading of the host
  container's resources (15 nullable numbers, each with its unit).
- `packages/metrics/lib/src/stream_stats.dart` (new): `StreamTally`, everything the summary keeps about a stream:
  per viewer stages (with `stagesByFps`), gauges, counters and facts, the host's resource gauges and its two single
  values, the caps, and the derived `stream_total` and `press_to_screen`.
- `packages/metrics/lib/src/session.dart`: `SessionCollector` gets six delegating methods (`streamViewer`,
  `streamStage`, `streamGauge`, `streamCounter`, `streamFact`, `streamResource`) and `summary()` writes `stream`,
  left out while nothing was recorded.
- `packages/metrics/lib/src/report_stream.dart` (new): reads a summary's `stream` record (`StreamViewerRow`,
  `StreamHostRow`) and builds the five Streaming tables.
- `packages/metrics/lib/src/report_stream_csv.dart` (new): `streamCsvHeader` and `streamCsv`, one row per viewer.
- `packages/metrics/lib/src/report_table.dart`: `report()` puts the Streaming section after the frame-rate table
  and before Enjoyment, and leaves it out when no session streamed.
- `packages/metrics/lib/metrics.dart`: exports the five new files.
- `packages/metrics/bin/report.dart`: `--csv-stream <file>`, and the help text describes the Streaming tables and
  columns.
- `packages/metrics/test/stream_stats_test.dart` (new): 11 tests of the record and the collector.
- `packages/metrics/test/report_stream_test.dart` (new): 6 tests of the report section and the CSV.
- `docs/protocol.md`: new §13, "Session analytics: the `stream` record (M15)", with the shape, every stage, gauge,
  counter and fact with its unit, the derivation of the two totals, the host's readings, and the collector call that
  feeds each one.
- `docs/briefs/m15/p1-stream-metrics-report.md` (new): this report.

## The record

`stream` sits beside the summary's existing keys and is left out until the session records something, so an older
summary (no key) reads as before and an older report ignores it. A sample, from the report test's one-viewer session
(a real `jsonEncode` of the collector's output, with some stage, gauge and counter entries left out to fit):

```json
"stream": {
  "viewers": [
    {
      "id": "v1", "kind": "browser", "platform": "chrome",
      "stages": {
        "stream_capture": {"n": 3, "median": 4, "p95": 6, "max": 6},
        "stream_encode": {"n": 3, "median": 10, "p95": 12, "max": 12},
        "stream_send": {"n": 3, "median": 2, "p95": 3, "max": 3},
        "stream_network": {"n": 3, "median": 30, "p95": 40, "max": 40},
        "stream_jitter_buffer": {"n": 3, "median": 8, "p95": 10, "max": 10},
        "stream_decode": {"n": 3, "median": 5, "p95": 7, "max": 7},
        "stream_display": {"n": 3, "median": 6, "p95": 8, "max": 8},
        "sent_to_received": {"n": 3, "median": 14, "p95": 16, "max": 16},
        "received_to_drawn": {"n": 3, "median": 7, "p95": 9, "max": 9},
        "audio_capture_to_play": {"n": 3, "median": 50, "p95": 60, "max": 60},
        "stream_total": {"n": 3, "median": 65, "p95": 86, "max": 86, "source": "stages"},
        "press_to_screen": {"n": 3, "median": 86, "p95": 111, "max": 111, "source": "stages"}
      },
      "gauges": {
        "audioSyncMs": {"n": 3, "mean": -4.0, "p95": 0.0, "max": 0.0},
        "bitrateSentKbps": {"n": 2, "mean": 6100.0, "p95": 6200.0, "max": 6200.0},
        "lossPct": {"n": 2, "mean": 0.6, "p95": 0.7, "max": 0.7}
      },
      "counters": {"framesSent": 1000, "framesReceived": 990, "framesDropped": 5, "freezes": 1, "freezeMs": 250},
      "facts": {"codec": "h264", "encoder": "nvh264enc", "relay": "no"}
    }
  ],
  "host": {
    "samples": 2,
    "gauges": {"cpuPct": {"n": 2, "mean": 50.0, "p95": 55.0, "max": 55.0},
               "memMb": {"n": 2, "mean": 925.0, "p95": 950.0, "max": 950.0}},
    "memPeakMb": 950.0, "firstFrameMs": 800
  }
}
```

A stage is `n`, `median`, `p95`, `max` in ms (the summary's existing `DelayStats`, so a stage reads exactly as a
phone's does today). A gauge is `n`, `mean`, `p95`, `max` in its own unit, rounded to two decimals. A counter is the
newest total since the session started. A fact is a short technical string. Bounds: 8 viewers, 32 series each for a
viewer and the host, 32-character names, 256 samples a gauge, 8 frame rates, 24-character facts.

## Collector API

On `SessionCollector`, all of them safe to call at any time: an unknown viewer id or a full record drops the call
instead of throwing, and `streamViewer` returns the id the other calls take.

```dart
String streamViewer({required String kind, String platform = ''});   // 'v1' … or '' when full
void streamStage(String viewerId, String name, int ms, {int? fps});  // a latency sample, ms
void streamGauge(String viewerId, String name, num value);           // a reading, mean/p95/max
void streamCounter(String viewerId, String name, num value);         // a running total
void streamFact(String viewerId, String name, String value);         // a short technical string
void streamResource(StreamResourceSample sample);                    // one container reading
```

`StreamResourceSample` takes any subset of `cpuPct`, `gameCpuPct`, `encoderCpuPct`, `memMb`, `memPeakMb`, `gpuPct`,
`encoderPct`, `gpuMemMb`, `gameFps`, `frameBuildMs`, `frameRasterMs`, `encodedFps`, `encodeQueue`, `sessionsAtOnce`
and `firstFrameMs`; nulls are left out. A viewer id from another session, a name over 32 characters, a value that
isn't finite, a non-technical fact, or a ninth viewer drops the call rather than throwing: a client can't break a
session's summary.

## The Streaming section

`report()` puts it after the frame-rate table. From the two sessions of the report test (one Windows host with one
browser, one phone host with an app and a browser):

```
Streaming pipeline
session  viewer     kind  platform  input  host  capture  encode  send  network  jitter  decode  display  total  press>screen     src
-------  ------  -------  --------  -----  ----  -------  ------  ----  -------  ------  ------  -------  -----  ------------  ------
one          v1  browser    chrome  14/16   7/9      4/6   10/12   2/3    30/40    8/10     5/7      6/8  65/86        86/111  stages
two          v1      app   android      -     -    12/14    8/10     -        -       -       -        -  20/24             -       -
two          v2  browser   firefox      -     -        -       -     -        -       -       -        -      -         80/90   probe

Streaming quality
session  viewer  sent kbps  recv kbps  loss %  rtt ms  jitter ms   fps  sent  recv  decoded  dropped  late  freezes  first frame ms  reconnects  relay  codec
-------  ------  ---------  ---------  ------  ------  ---------  ----  ----  ----  -------  -------  ----  -------  --------------  ----------  -----  -----
one          v1     6100.0     5850.0     0.6    13.0        4.0  60.0  1000   990      985        5     2    1/250             800           1     no   h264
two          v1          -          -       -       -          -     -     -     -        -        -     -        -               -           -      -      -
two          v2          -     4500.0     1.2    50.0          -     -     -  1800        -       12     -    2/900            1500           -    yes   h264

Streaming sound
session  viewer  audio ms  sync ms  concealed %
-------  ------  --------  -------  -----------
one          v1     50/60     -4.0          2.0
two          v1         -        -            -
two          v2         -        -            -

Streaming resources
session  samples  cpu %  game cpu %  enc cpu %  mem MB  gpu %  enc %  gpu mem MB  game fps  build ms  raster ms  enc fps  queue  first frame ms  mem peak MB
-------  -------  -----  ----------  ---------  ------  -----  -----  ----------  --------  --------  ---------  -------  -----  --------------  -----------
one            2   50.0           -          -   925.0   45.0   12.0           -      59.0         -          -     60.0      -             800        950.0
two            1   70.0           -          -  1800.0   78.0   12.0           -      30.0         -          -     45.0      -               -       1800.0

Streaming by sessions at once
sessions at once  sessions  cpu %  gpu %  enc %  game fps  enc fps  mem MB
----------------  --------  -----  -----  -----  --------  -------  ------
1                        1   50.0   45.0   12.0      59.0     60.0   925.0
2                        1   70.0   78.0   12.0      30.0     45.0  1800.0
```

Each stage cell is `median/p95` in ms, a dash when nothing was recorded; `src` is the derived totals' `source`. A
session with no stream record adds no row and no table, and when no session streamed the whole section is left out,
so an older export reports exactly as before. The CSV (`--csv-stream stream.csv`) has one row per viewer and 65
columns: `session`, `viewer`, `kind`, `platform`, the nine stages and the two totals as `_median_ms` and `_p95_ms`,
`press_source`, `audio_median_ms`, `audio_p95_ms`, `sync_mean_ms`, `concealed_mean_pct`, the quality numbers, the
counters, `relay`, `codec`, `encoder`, and the host's means with `sessions_at_once` repeated on every row of the
same session.

## What later jobs must send

| Field | Who measures it (job) | How |
| --- | --- | --- |
| `sent_to_received`, `received_to_drawn` | host, already (a2 copies them) | the session's existing controller stages, copied into the viewer entry so one row reads input → display and `press_to_screen` can be derived |
| `stream_capture` | container pipeline (c2) | the game's frame time → the captured buffer's PTS (GStreamer appsink probe) |
| `stream_encode` | container pipeline (c2) | captured PTS → the encoder's output packet PTS |
| `stream_send` | container pipeline (c2) | output packet ready → webrtcsink has it on the wire (probe after the payloader) |
| `stream_network` | viewer (c2) | `candidate-pair.currentRoundTripTime` ÷ 2, or the frame's capture timestamp against a mapped local clock |
| `stream_jitter_buffer` | viewer (c2) | frame arrival (`requestVideoFrameCallback` metadata) → decoder input |
| `stream_decode` | viewer (c2) | decoder input → decoded frame ready |
| `stream_display` | viewer (c2) | decoded → `requestVideoFrameCallback` presented |
| `stream_total` | probe (c2) when it times capture → presented; otherwise nobody (derived) | recorded as its own samples with `source: measured`, or added up from the seven stages (`source: stages`) |
| `press_to_screen` | probe (c2); otherwise derived | press event time → the presented frame showing it (`source: probe`), or total + the two controller stages (`source: stages`) |
| `audio_capture_to_play` | viewer (c2) | audio output time minus the chunk's capture time (RTCP sender reports), or its encode / network / jitter parts when only those are known |
| `audioSyncMs` | viewer (c2) | signed: audio and the video frame presented beside it (`getOutputTimestamp` vs rVFC) |
| `audioConcealedPct` | viewer (c2) | `concealedSamples ÷ totalSamples × 100` |
| `bitrateSentKbps` | container (c2) | webrtcsink's own stats, every few seconds |
| `bitrateReceivedKbps` | viewer (c2) | `bytesReceived` delta ÷ interval × 8 ÷ 1000 |
| `lossPct` | viewer (c2) | `packetsLost ÷ (packetsReceived + packetsLost) × 100` |
| `rttMs`, `jitterMs` | viewer (c2) | `candidate-pair.currentRoundTripTime` × 1000; `inbound-rtp.jitter` × 1000 |
| `deliveredFps` | viewer (c2) | `inbound-rtp.framesPerSecond` |
| `framesSent`, `keyframes`, `nacks`, `plis`, `firs` | container (c2) | `outbound-rtp`: `framesEncoded`, `keyFramesEncoded`, `nackCount`, `pliCount`, `firCount` |
| `framesReceived`, `framesDecoded` | viewer (c2) | `inbound-rtp.framesReceived`, `framesDecoded` |
| `framesDropped` | viewer (c2) | received − decoded |
| `framesLate` | viewer (c2) | frames presented later than their capture time plus the frame budget (c2 decides the test) |
| `freezes`, `freezeMs` | viewer (c2) | `inbound-rtp.freezeCount`, `totalFreezesDuration` × 1000 |
| `firstFrameMs` (viewer) | viewer or container (c2) | session start → the first frame presented (viewer) or encoded (container); record one meaning |
| `reconnects` | container (c2) | the session's own reconnect count |
| `relay` | container (c2) | the selected candidate pair's type is `relay` → `yes` |
| `codec`, `encoder` | container (c2) | the negotiated codec; the encoder element's name |
| `cpuPct` | container sampler (c2) | cgroup `cpu.stat` delta ÷ interval ÷ cores |
| `gameCpuPct`, `encoderCpuPct` | container sampler (c2) | the same, per process group (the game; the encoder pipeline) |
| `memMb`, `memPeakMb` | container sampler (c2) | `memory.current`; `memory.peak` when it exists, otherwise the highest reading here |
| `gpuPct`, `encoderPct`, `gpuMemMb` | container sampler (c2) | `nvidia-smi --query-gpu` and `--query-compute-apps` |
| `gameFps`, `frameBuildMs`, `frameRasterMs` | game host (a2, already drawn) | the host's own per-frame numbers |
| `encodedFps`, `encodeQueue` | container (c2) | the encoder's frames a second; the queue's current level |
| `sessionsAtOnce` | container sampler (c2) | how many session containers run on the machine |
| host `firstFrameMs` | container (c2) | session start → the first frame ready to encode |

## Tests

Before: 106 metrics tests. After: 123 (11 in `stream_stats_test.dart`, 6 in `report_stream_test.dart`), each new one
written before the code and failing for the missing behaviour (`Method not found: 'streamReport'` and the like).

The new tests cover: the record round-tripping through `summary()` JSON; a summary taken before a sample keeps what it
had; a session with no stream has no `stream` key, an unchanged CSV and no Streaming section; only a known kind and a
technical platform are kept; stage and gauge maths; a signed gauge; the caps (300 gauge samples keep 256, mean 128.5,
p95 243, max 256; 32 series; a long name dropped; a ninth viewer gets `''`); filing by frame rate (60 and 30 kept,
a nonsensical 500 ignored); the totals in both modes (`stream_total` 65/86 from stages and 110/120 measured;
`press_to_screen` 86/111 from stages and 80/90 from a probe); no `press_to_screen` without the controller stages; the
five tables from a fixed set of sessions (the cells above, including a session with no stream); the section's place in
`report()`; and the CSV's header and values.

## Decisions

- **One session-level key, left out when empty.** Old summaries and old reports read a session that never streamed
  exactly as before, and no existing test changed.
- **Stages reuse `DelayStats`.** A stream stage reads like a phone stage, and the 1 ms histogram keeps 256 samples
  cheap.
- **A gauge keeps its first 256 samples** yet reports `n` as the kept count, not every call: bounded memory, and the
  mean still covers a whole session at the sampler's rate.
- **The derived total adds medians, p95s and maxes and takes the fewest `n`.** The stages' samples can't be paired, so
  the p95 and max are an upper bound; the JSON says `source: stages` so a reader knows it isn't a measurement. The
  alternative (dropping the totals) would have lost the one number the owner asked for.
- **`press_to_screen` needs both the controller stages and a total**, in the same viewer entry, or it's left out: an
  estimate from half the path would mislead.
- **The controller stages are copied into the viewer entry** by whoever feeds the record (a2 reads them from the
  session it already has). The summary's stage series are per player, not per viewer, so copying is the only way one
  row can read input → display without joining two ids.
- **A viewer is a screen, not a person:** 8 viewers, ids `v1`…`v8`, kind out of `browser`/`app`/`other`, platform
  cleaned like a device string. No address, no user agent.
- **Unknown series names are kept** (32 characters, 32 series), as stage names are today, so a newer client's numbers
  survive into the report instead of being dropped.
- **Resources carry a memory peak and a first frame time as single values**, outside the gauges: they're one-off
  moments with no distribution; the peak is the sampler's own `memory.peak` when given, otherwise the highest reading.
- **The Streaming section is one section with five tables and one CSV file** (`--csv-stream`): the existing CSVs stay
  as they are, and a job that doesn't stream costs nothing.
- **The tables show means for resources, stages show median/p95:** a resource reading isn't a latency, and a mean is
  what capacity questions ask for; p95 and max stay in the JSON for a later table.
- **Files split to stay under 400 lines** (`stream_names.dart` holds the constants, the CSV has its own file); the
  largest lib file after the split is `session.dart` at 384.

## Self-check (review-rules part A)

1. **Every host setup.** Not affected: no host, UI, game or protocol message changed, and the record is only reached
   through the collector; a session that never streams writes no key and reports as before — test
   "a session with no stream has no record and reports as before". Streaming itself is the Windows/WSL container
   (M15 design), not a phone setup.
2. **When kept state starts and ends.** The record starts with the first collector call and ends with the session;
   nothing is timed, no timer runs, and with no calls the record stays empty and is never written — tests
   "a summary taken before a sample keeps what it had" and the no-stream test. A summary taken mid-session carries
   what it has, and writing it again later adds the rest.
3. **How a new state combines with the others.** Not affected: nothing pauses, hides or waits; the record is written
   from the host's stats loop and read by the CLI, never by a round.
4. **Stay in the job's folder.** All writes are `packages/metrics`, `docs/protocol.md` and this report, all in
   `allow:`. `docs/PRD-v2.md` was in `allow:` but the environment refused to write it (see Questions 1), so it is the
   one brief item I could not do.
5. **Stop rather than overstep.** Instead of working around the refusal (a shell write, another path) I stopped and
   put the exact S7 text below, and I made no design choice that the brief didn't already settle — every judgement is
   under Decisions.

The S7 line that still needs adding (one sentence appended inside the S7 row, the rest of the row untouched):

```
Streaming can add encode, network, decode and display stages later, and the results stay comparable. M15 names the
stream stages `stream_capture`, `stream_encode`, `stream_send`, `stream_network`, `stream_jitter_buffer`,
`stream_decode` and `stream_display`, with `stream_total` (capture to display) and `press_to_screen` derived from
them | M9, M12, M15 |
```

## Checks

`tools/check.sh format analyze metrics`:

```
PASS  format      (3s)
PASS  analyze     (15s)
PASS  metrics     (123 tests, 3s)
All checks passed (21s).
```

`tools/review.sh` could not run here: the Bash tool refused it ("This command requires approval"), and so did a plain
`sed` write of the PRD line. By hand: no added file has a `print`, a `dynamic` or an empty `catch` (grep); no lib file
is over 400 lines (the longest is `session.dart`, 384, against 300 for a note); no added function is over 60 lines
(the longest is under 25); the numeric literals it would flag are the caps and the two-decimal rounding, both
constants with a doc comment.

## Questions

1. **`docs/PRD-v2.md` is writable in the brief but refused by the environment.** Both Edit and Bash were denied with
   "denied by your permission settings". Please apply the S7 sentence above, or allow the file and I'll add it.
2. **`tools/review.sh` doesn't run here** either. If the job needs its output, it needs to run where Bash is
   unrestricted; the checks above are my manual equivalent.
3. **`stream_network` is documented as the viewer's RTT ÷ 2.** If a2 would rather have the container's RTCP-derived
   one-way time, the name doesn't change, only who records it — worth settling before c2 writes it.
4. **The tables and CSV show resource means only**, while the JSON keeps p95 and max. If the capacity question
   ("how many sessions on this machine") needs the worst case, the table wants a p95 column; say and I'll add it.
5. **Nothing enforces the record's size at the summary level:** 8 viewers × 32 series × (256 samples) is bounded, but
   the 50 KB summary budget in PRD v2 ("Batches stay under about 4 KB. A session summary stays under about 50 KB") was
   not measured; a2 should check it with a full session before shipping.

## Commit message

```
metrics: record streaming stages, sound and container resources

Add the session summary's `stream` record: per viewer stages, gauges,
counters and facts, and the host container's resource readings, left out
until a session streams so older summaries read as before.
Derive `stream_total` and `press_to_screen` and say in `source` whether
a probe measured them or the stages were added up.
Add the collector calls a host makes to feed the record, with every
series capped so a runaway client can't grow the summary.
Add the report's Streaming section and `--csv-stream`; document the fields
and units in protocol §13.
```

## Status row

M15 p1 done: the summary's `stream` record, its collector API, the Streaming report section and stream CSV in
packages/metrics, and protocol §13; open: the PRD S7 sentence (edit blocked in this environment), job a2's ingest and
job c2's sampler and probe.

## Delete

- none
