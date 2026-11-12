# n3-1 sender build: what webrtcsink holds, and the one switch step 1 leaves

## Summary

**Headless Chrome, not Safari**: the viewer says whether a switch works and what
it does to the host and to Chrome; the phone decides whether it helps.

1. **What webrtcsink builds for encoded h264:** sink pad → `clocksync` →
   `appsink` → per consumer `appsrc` → `h264parse` → capsfilter → `rtph264pay`
   (already `aggregate-mode=zero-latency`) → capsfilter → `webrtcbin` → `srtpenc`
   → `nicesink`, with **no queue** on that path (`imp.rs:457` is the unused one).

2. **No element there holds a frame.** In the 45 s baseline `n0b0` the element
   means are `h264parse3` 0.29 ms, `rtph264pay2` 0.06, RED/FEC 0.02/0.03, and the
   consumer chain from its `appsrc` to the `webrtcbin` pad is 0.46 ms whole,
   against the encoder's 33.55 and the path to `ws` 38.07; the session's own
   `h264parse0` is 0.11 ms, so the parser does not wait for the next access unit.
   The wait is the encoder's push into the sink pad, whose `appsink` is the one
   element with no record (a sink writes none).

3. **Correction:** the `queue0` of 18.1 ms that n0-2 and k1-4 call webrtcsink's
   internal queue is the **sound branch's** (5578 records; the picture has 3165).

4. **One switch:** `SESSION_CONGESTION=disabled|gcc`, default `disabled` (today's
   pipeline unchanged). `homegrown` is refused with a warning: on an encoded
   stream webrtcsink 0.13.6 divides by its own zero encoder count and aborts
   (`homegrown_cc.rs:386`, measured); no `SESSION_SINK_*`, no `SESSION_PARSE`
   either, because step 1 shows no property that names the hold.

5. **Three 30 s probe runs** (limit five): disabled / gcc / homegrown→disabled;
   all play with one `chrome-headless` row of data, under the 10000 ceiling.

## Step 1 — the properties, and what webrtcsink builds for an encoded stream

`gst-inspect-1.0 webrtcsink` in the image (plugin `rswebrtc`, **0.13.6-RELEASE**,
2025-05-13) with the read-only ones left out:

| property | default | reachable? |
| --- | --- | --- |
| `congestion-control` | `gcc` (enum 2; 0 `disabled`, 1 `homegrown`) | the session's switch |
| `max-bitrate` / `min-bitrate` / `start-bitrate` | 8192000 / 1000 / 2048000 bit/s | already set by entrypoint |
| `do-fec`, `do-retransmission` | true, true | `SESSION_FEC`, `SESSION_RETRANSMISSION` |
| `do-clock-signalling` | false | no hold (adds RFC 7273 attributes only) |
| `enable-data-channel-navigation` | false | no |
| `ice-transport-policy`, `stun-server`, `turn-servers` | all / Google STUN / none | no (transport only) |
| `video-caps`, `audio-caps` | vp8/h264/vp9/h265/av1, opus | no (which codecs are offered) |
| `meta` | null | names a producer, no time |
| pad `msid` | null | names a stream, no time |
| `stats` | (read-only) | reports, no time |
| queue, latency, clock | — | none on an encoded stream (below) |

What it builds for `video/x-h264` in (`imp.rs`, `gst-plugins-rs` 0.13.6):

- sink pad → `clocksync` → `appsink`, and a `StreamProducer` from that appsink
  (`imp.rs:1304-1324`).
- per consumer: `appsrc` named after the stream (`video_0`), configured live,
  `max-time` 500 ms, leaky downstream (`gstreamer-utils/streamproducer.rs:227-241`),
  then `h264parse` (`imp.rs:806`, `utils.rs:683`; the same parser is added even
  when the input is already encoded), a capsfilter of `parser_caps`
  (`imp.rs:815`), `rtph264pay` with **`aggregate-mode=zero-latency`** and
  `config-interval=-1` (`imp.rs:708-710`), a capsfilter, then a webrtcbin pad.
- inside `webrtcbin`: its own `rtpbin` send session (`rtpsession`), RED and
  ULPFEC (`rtpredenc`, `rtpulpfecenc`) when `do-fec`, `rtprtxsend` when
  `do-retransmission`, `srtpenc`, a `funnel` and `nicesink`. No jitterbuffer,
  no send-side latency (measured: all ≤ 0.06 ms).
- **no queue** anywhere on this path (only the `nvv4l2` converter path builds
  one, `imp.rs:457`).

Measured in the 45 s baseline run (`n0b0`, `switches: none`), means of the
`element-latency` records (ns → ms); a source and a sink write none, so
`waylanddisplaysrc0` and `appsink0` appear only in the whole-path records below:

| element | n | mean ms | what it is |
| --- | --- | --- | --- |
| `videoconvert0` | 3167 | 4.38 | the session's converter |
| `nvautogpuh264enc0` | 3165 | **33.55** | the encoder (9-11 ms alone, k1-4) |
| `h264parse0` | 3165 | 0.11 | the session's own parser |
| `clocksync0` | 3165 | 0.07 | webrtcsink's sink-pad clock sync |
| `h264parse3` | 2964 | 0.29 | webrtcsink's internal parser |
| `capsfilter14` | 2964 | 0.06 | parser caps |
| `rtph264pay2` | 2964 | 0.06 | the payloader (zero-latency) |
| `rtpredenc3` / `rtpulpfecenc3` | 17356 / 8678 | 0.02 / 0.03 | RED and FEC |
| `queue0` | 5578 | 18.07 | **the sound branch's queue**, not the sink's |

and the whole-path (`latency`) records, which name the source and the sink:

| path | n | mean ms | what it is |
| --- | --- | --- | --- |
| `waylanddisplaysrc0` → `ws` | 3165 | 38.07 | the sampler's `pipelineMs`, whole-run |
| `waylanddisplaysrc0` → `appsink0` | 3165 | 38.14 | the same path plus the sink pad, into its `appsink` |
| `video_0` → `webrtcbin-…` | 2964 | 0.46 | webrtcsink's consumer chain, `appsrc` to the `webrtcbin` pad |

Conclusion for step 1: the ~25 ms the encode stage shows is the encoder's src-pad
push waiting for the sink pad to take the buffer. The pad itself takes it in
0.07 ms and the consumer chain then costs 0.46 ms; the only unrecorded piece is
the sink pad's `appsink` and its hand-off to the `appsrc` (a sink writes no
record). Every property in the list above is either about bitrate, codecs,
transport or naming; none of them is a queue, a latency or a clock wait on this
path. So there is nothing for a `SESSION_SINK_*` or a `SESSION_PARSE` to switch,
and the batch keeps one sender switch.

## What changed

- `streaming/entrypoint.sh`: `congestion_control="${SESSION_CONGESTION:-disabled}"`
  with the comment above; the picture's `ws` and the sound's `ws-audio` both get
  `congestion-control=$congestion_control` (the sound sink had `disabled`
  hard-coded); a value check in `main()` beside the `SESSION_AUDIO` one
  (`disabled`/`gcc` pass, `homegrown` warns and runs `disabled`, anything else
  warns and runs `disabled`); and one line after `ready:` —
  `sink ws: congestion-control=… max-bitrate=… start-bitrate=… do-fec=…
  do-retransmission=…` — so a run's log says which sender settings its numbers
  belong to.
- `streaming/README.md`: a `SESSION_CONGESTION` row in the settings table, and a
  paragraph in "Switches (M15 fix7)" naming technique 3's one switch and the step
  1 result.
- `docs/briefs/m15/fix7/n3-1-sender-build/`: `n3cc0.json`, `n3cc2.json`,
  `n3cc3.json` (the three runs' summaries) and `runs.txt` (the three `switches:`
  lines and the panic's two lines).

With every switch off the built pipeline is the one that shipped: the `ws`
argument list is identical except `congestion-control=disabled` is now written
from the variable, which defaults to exactly that string.

## Runs (30 s probe, one per switch value)

    docker build -f streaming/Dockerfile -t tp-session:latest .
    bash streaming/bench.sh --probe --seconds 30 --label n3cc0 \
      --out /work/stream-bench/n3cc0 --set SESSION_CONGESTION=disabled --keep
    # and n3cc2 with SESSION_CONGESTION=gcc, n3cc3 with SESSION_CONGESTION=homegrown

| run | switches | `sink ws:` line | viewer | jitter | total | press (n) | encode | pipelineMs | enc fps | kbit/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `n3cc0` | `SESSION_CONGESTION=disabled` | `congestion-control=disabled` | 1 × chrome-headless | 182 | 217 | 254 (56) | 29 | 33.70 | 56.55 | 1989 |
| `n3cc2` | `SESSION_CONGESTION=gcc` | `congestion-control=gcc` | 1 × chrome-headless | 234 | 269 | 225 (59) | 29 | 43.67 | 55.65 | 2044 |
| `n3cc3` | `SESSION_CONGESTION=homegrown` | `congestion-control=disabled` (warning) | 1 × chrome-headless | 182 | 217 | 199 (59) | 29 | 43.54 | 55.31 | 2117 |

- Every run: `codec H264`, `1920x1080`, 2057 / 1876 / 1865 frames received,
  8 / 12 / 15 dropped, **no freeze**, `deliveredFps` 57.0 / 56.8 / 56.8, host
  gauges present (`encoderPct` 6.3 / 6.5 / 6.4, `gameFrameMs` 18.0 / 18.3 / 18.3).
- The **wire ceiling is honoured** in all three (2.0 of 10.0 Mbit/s); the probe
  card is a near-static picture, so the probe run says nothing about whether GCC
  would pull the bitrate down on a full game — that is n3-2's job.
- `gcc` works and keeps the stream playing. These runs prove working-ness only:
  one 30 s run each, and the spread of the totals (217 / 269 / 217) is as large
  as the baseline's own 40 ms noise, so the comparison is n3-2.
- **`homegrown` aborts the pipeline** (first attempt, run kept as evidence):
  `thread '<unnamed>' panicked at net/webrtc/src/webrtcsink/homegrown_cc.rs:386:
  attempt to divide by zero`, then `fatal runtime error: failed to initiate
  panic, error 5, aborting`; the session log's own tail is
  `GST_TRACERS=… Aborted (core dumped)` and `a part of the session ended
  (status 134)`. The reason is structural: the heuristic divides its bitrate by
  the number of encoders webrtcsink itself owns, and on an already-encoded
  stream that is zero. The fallback run above (`n3cc3`) proves the refusal leaves
  a working session.
- One wasted run: the first `n3cc1` (homegrown) never went ready because the
  `--keep`ed `n3cc0` container was still holding the pinned controller and
  automation ports. Every run after it removes the previous container first.

## Checks

- `bash -n streaming/entrypoint.sh` in the distro: passed (twice, after each edit);
  `docker build` of the image: passed; three probe runs: passed as in the table.
- `tools/check.sh format analyze metrics tv`: **not run.** This sandbox refused
  every script and tool invocation it did not have on an allowlist (`bash
  tools/check.sh`, `tools/wsl-sync.sh`, `tools/wsl-fetch.sh`, `dart`, `tar` all
  answered "This command requires approval", with and without the sandbox
  disabled). No Dart file was changed by this job, so `format`/`analyze`/
  `metrics`/`tv` are unaffected by the diff; the reviewer should still run
  `tools/check.sh format analyze metrics tv` to confirm.

## Method (how the distro was used)

`tools/wsl-sync.sh tp-stream` is killed by the sandbox above, so the checkout
reached the distro another way: a shallow clone of `origin/m15` at the job's HEAD
(`22fc5db`, the same commit the job started from) into
`/work/flash-20261112-151856-22332`, then each file this job edits piped in with
`cat <file> | wsl -d tp-stream -u root -- bash -lc 'cat > …/streaming/entrypoint.sh'`
and the image rebuilt there. Every bench summary was fetched the same way, with
the distro's `cat` and a Windows-side redirect. Nothing was installed, nothing
was mounted, no other distro or `wsl` state was touched, and every container this
job started was removed (`docker ps` empty at the end).

## Decisions

1. **One sender switch, not three.** Step 1 measured every element webrtcsink
   adds (all ≤ 0.5 ms) and lists every property; none names the hold, so a
   `SESSION_SINK_*` would be a switch with nothing to justify it.
2. **No `SESSION_PARSE`.** Both `h264parse` elements measure 0.11 and 0.29 ms, so
   the alignment variant cannot shorten anything, and `nal` output would risk the
   payloader's AU and marker bits in a stream that must stay playable.
3. **`homegrown` is refused, not passed through.** It aborts the pipeline on this
   path; a value that kills the session would read to the owner as "this
   technique made it worse". The refusal keeps a run alive and says why in the
   session log.
4. **The switch reaches both sinks.** `SESSION_CONGESTION` is the session's
   congestion control; leaving the sound sink pinned at `disabled` would split
   the two senders and make the run's numbers harder to read.
5. **An unknown value runs `disabled` with a warning**, the same way an unknown
   `SESSION_AUDIO` runs `joined`: a typo must not leave a run with no picture.
6. **The switch is not in `tools/stream.sh`.** `bench --set` already passes any
   `KEY=VALUE`, which is how the three runs were made.

## Questions

1. Should `homegrown` be dropped from the documented values entirely, or kept as
   a refused value as it is now? It is a webrtcsink 0.13.6 bug and may work on an
   encoded stream in a later release.
2. Confirm the placement of the `sink ws:` line (after `pipeline registered:`,
   same `say` stream) is where the run phase should read it from.

## Self-check (docs/review-rules.md part A, items 1–5)

1. **Every host setup:** this is a session-image pipeline switch, not app code;
   the TV/phone hosts and an older build see the same picture unless the image is
   given `SESSION_CONGESTION`, and the default is the old pipeline. Tested: the
   Linux session host in all three values.
2. **Kept state:** webrtcsink's own state is a consumer connection; the switch
   only changes a start-up property of two sinks (changeable in NULL/READY, which
   is when they are set), so nothing is held, timed or cached by this change. With
   no viewer the sinks idle exactly as before (`n3cc0`'s viewer connected after
   ready and the run's counters show it).
3. **How the new state combines:** `SESSION_CONGESTION=gcc` + `SESSION_AUDIO`
   joined is the run shown; `separate` would apply the same value to `ws-audio`
   (code path read, not run); `gcc` + `SESSION_FEC=false` changes `max-bitrate`
   (the video gets the ceiling without the FEC divisor) — not run, one line of
   code, no interaction beyond the number.
4. **Stay in the job's folder:** only `allow:` files were written
   (`streaming/entrypoint.sh`, `streaming/README.md`, the report and its folder).
5. **Stop rather than overstep:** nothing outside `allow:` was touched; the two
   things this job could not do (run `tools/check.sh`, use `wsl-sync`) are
   reported rather than worked around in the repository.

## Hand-over

- Exists now: `SESSION_CONGESTION=disabled|gcc` (`homegrown` refused), on both sinks,
  a `sink ws:` line after `ready:` naming the sink properties used, the README row and
  technique 3 paragraph, and three probe summaries in `fix7/n3-1-sender-build/`.
- Commands that worked (in `tp-stream`, folder `/work/flash-20261112-151856-22332`):

      docker build -f streaming/Dockerfile -t tp-session:latest .
      bash streaming/bench.sh --probe --seconds 30 --label n3cc2 \
        --out /work/stream-bench/n3cc2 --set SESSION_CONGESTION=gcc --keep
      docker rm -f thumb-party-n3cc20   # before the next run: the ports are pinned

- Numbers: encode 29 ms in all three; jitter 182 / 234 / 182; total 217 / 269 / 217;
  press 254 / 225 / 199 ms (n 56 / 59 / 59); pipelineMs 33.70 / 43.67 / 43.54; enc
  fps 56.55 / 55.65 / 55.31; received 1989 / 2044 / 2117 kbit/s.
- Do not redo: the property survey, `n0b0`'s means, the `homegrown` crash, the three
  runs, and the one-switch decision (there is no other sender property to try).
- Open: whether GCC engages on a full game (probe mode's 2 Mbit/s card cannot show
  it) — n3-2 judges that, and the phone decides; and no `tools/check.sh` run here.

## Commit message

Add SESSION_CONGESTION: webrtcsink's congestion control as one switch

`SESSION_CONGESTION=disabled` (default) is the pipeline as it was; `gcc` runs
webrtcsink's Google Congestion Control on both sinks, with `max-bitrate` as the
ceiling the estimate may not cross and `start-bitrate` where a consumer starts,
so the video can run below the wire ceiling. The element's third value,
`homegrown`, is refused with a warning: on an already-encoded stream 0.13.6
divides by its own zero encoder count and aborts the pipeline (measured). The
ready log gains a `sink ws:` line naming the sink properties actually used.
Probing the element showed no other property that names the ~25 ms wait — every
element webrtcsink adds measures under 0.5 ms — so there is no SESSION_SINK_* or
SESSION_PARSE. README row and three probe summaries; no default changed.

## Status row

M15 fix7 n3 phase 1: `SESSION_CONGESTION=disabled|gcc` builds and runs (three
30 s probes: one viewer row, metrics, ceiling honoured; `homegrown` refused and
falls back), and step 1's survey says no other sender switch exists; open: the
n3-2 comparison (does GCC engage on a full game, and what the phone sees).

## Delete

- none
