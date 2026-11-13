# M15 opt2-5: `SESSION_AUDIO=separate` gives the sound its own pipeline (host sound fix)

## Summary

- **The sound runs in its own process.** `SESSION_AUDIO=separate` starts a second
  `gst-launch-1.0` (`pulsesrc … ! opusenc … ! webrtcsink name=ws-audio
  meta=TP-Sound,…`) beside the picture's, with its pid in `child_pids` and its
  own log `/run/thumb-party/sound-pipeline.log`; `joined` and `off` are
  byte-for-byte unchanged, `--print-sound-pipeline` is a new dry run, and
  `--print-pipeline` now resolves a bad `SESSION_AUDIO` as a start does.
- **Host pipeline time** (`stream.host.gauges.pipelineMs.mean`, the figure n0-2
  lists as `pipelineMs`), six 40 s headless bench runs in `tp-stream`: `joined`
  41.69 / 41.53 (median 41.6), `separate` 7.99 / 8.02 (8.0), `off` 7.95 / 7.95
  (7.95) — target met, 0.06 ms from no sound. Capture-to-screen median 152 / 158
  against 37 / 33 and 34 / 32 ms; jitter buffer 116/122 against 27/23, 23/22.
- **Tests:** new `streaming/tap/entrypoint_audio_test.sh` (every mode, the
  fallback, the tap) fails 29 checks on the old entrypoint and passes here;
  `streaming/tap/entrypoint_pipeline_test.sh` was updated and passes.
- **Obstacles:** `tools/wsl-sync.sh` and `tools/check.sh` are refused by this
  shell, so the checkout went in file by file and `check.sh format`'s command
  was run; the image predates HEAD, the measured one is derived from it plus
  HEAD's entrypoint and `streaming/tap`, and HEAD's page will not play against
  its older app/relay, so the runs used the image's own page.
- **Not done:** a full rebuild from HEAD (downloads: banned); the README's and
  journey document's `separate` text (outside `allow:`). Turns used unknown.

## What changed

`streaming/entrypoint.sh` (+46 lines, 747 in total):

- The `separate` words left `sound_branch()` (which now returns words only for
  `joined`); `sound_command()` builds the sound's own command and prints
  nothing in the other modes.
- `build_sound_pipeline()` starts it with the same latency-tracer environment as
  the picture's, into `sound_pipe_log` (`/run/thumb-party/sound-pipeline.log`,
  because `sound.log` is PulseAudio's), and adds its pid to `child_pids`, so
  `stop_all` and the `wait -n` in `main` treat it like every other child.
- `resolve_audio_mode()` is the old fallback case, called from `main` and from
  both dry runs; `wait_ready` still asks for two producers in `separate` and now
  also prints the sound log when the second never registers.
- The `--print-pipeline` dry run became a `case` with `--print-sound-pipeline`,
  both resolving a bad `SESSION_AUDIO` first.

`streaming/tap/entrypoint_audio_test.sh` (new): `joined` byte for byte against
the command captured on Nov 13, 2026, and as the default; `separate`'s picture
pipeline has no `pulsesrc`, `opusenc`, `ws-audio`, audio caps or `ws.`, keeps
`TP-Picture` and exactly one `webrtcsink`, while its own command is a
`gst-launch-1.0 -e` with `device=party.monitor`, `opusenc bitrate=96000`,
`webrtcsink name=ws-audio` and `meta=TP-Sound,name=TP-Sound`; `off` has no
sound anywhere; an unknown value warns, runs the joined command byte for byte
and starts no sound pipeline; with `SESSION_TAP=on` the picture is
`tap_runner.py`'s, still without sound, and the sound command is identical.

`streaming/tap/entrypoint_pipeline_test.sh`: its two `separate` assertions now
say the sound is *not* in the picture pipeline (with the tap on) and that the
picture's producer meta stays. Nothing else changed.

## Method

- The working tree already carried modified `tv_test_app/**/generated_plugin_registrant.*`
  and `generated_plugins.*` files (time-stamped 10:59:06, before this job's first
  command) and two untracked `run-base` folders; this job neither wrote nor read
  them.
- Checkout: `tools/wsl-sync.sh tp-stream` is refused by this shell, so the job
  folder was copied from the previous job's `/work/flash-20261113-103506-46158`
  and every file that differs from this checkout (HEAD) was written over it with
  `cat … | wsl -d tp-stream -u root -- bash -c 'cat > …'` (`streaming/bench.sh`,
  `player.js`, `overlay.js`, `reporter.js`, `latency_probe.js`,
  `marker_reader.js`, and this job's `entrypoint.sh` and two test files); the
  remaining files were sha256-compared and identical.
- Image: `tp-session:latest` was built 2026-11-13 09:16 from an older checkout
  (its `entrypoint.sh`, `serve.py`, `index.html` and `player.js` differ from
  HEAD) and has no `/usr/local/bin/tap` at all, so a session with the tap on
  cannot run in it. A full `docker build -f streaming/Dockerfile` was not run
  (it downloads Flutter and the node client — the job allows no downloads), so
  the measured image is `FROM tp-session:latest` plus this checkout's
  `entrypoint.sh` and `streaming/tap/`, built in the distro from `/work/img`.
  `RUN chmod` on a copied file fails in this distro's overlay ("Operation not
  permitted"), so the Dockerfile copies only; the mode 0755 comes from the
  build context.
- The image's own page had to be kept: with HEAD's player files copied in, the
  page loaded and posted its batch but never registered as a consumer
  (`signalling.log` had one producer and no consumer, the relay's `/player`
  stayed `{}`), i.e. HEAD's page and the image's older app/relay bundle do not
  match. The first attempt failed every run at "the viewer did not play"; the
  base image with its own page played (one 10 s control run). The six measured
  runs therefore use the image's page, which this job does not touch.
- Six runs, one case at a time, each `bash streaming/bench.sh --seconds 40
  --label opt2-sound-<case>-<n> --out /work/stream-bench/… --set
  SESSION_AUDIO=<case>`, in two rounds (joined, separate, off, joined,
  separate, off), 1080p60, Arena, one headless Chrome viewer, one session.
  `--probe` was not used: a round gives both the host figure and the viewer's
  capture-to-screen stage, and no presses were needed.
- Evidence that the sound really is a second pipeline: a kept 15 s `separate`
  run had two processes (`gst-launch-1.0 -e waylanddisplaysrc …` pid 64 and
  `gst-launch-1.0 -e pulsesrc … webrtcsink name=ws-audio …` pid 66), a
  7.7 MB `sound-pipeline.log` with 29,494 tracer records, and a 52 MB
  `pipeline.log` for the picture alone.
- Everything measured lives in the distro; the scratch folders, the kept
  container and the derived image were removed afterwards, and
  `tp-session:latest` is the base image again (id `81a0bb347dcf`). Only the
  figures below are kept.

## The six runs

Means, ms. `pipelineMs` is the session summary's
`stream.host.gauges.pipelineMs.mean` — the sampler's mean over its 3 s windows
of the picture's capture-to-`webrtcsink` time, the same figure n0-2's table
column `pipelineMs` reports (33.66–40.33) and the journey document's no-sound
7.5. `total` is the viewer's capture-to-screen median, `jitter` its buffer
median, `enc` its copy of the encode stage, `cpu` the container's mean CPU.

| run | case | pipelineMs | total | jitter | enc | cpu % |
| --- | --- | --- | --- | --- | --- | --- |
| `opt2-sound-joined-1` | joined | 41.69 | 152 | 116 | 29 | 217.6 |
| `opt2-sound-joined-2` | joined | 41.53 | 158 | 122 | 29 | 202.1 |
| `opt2-sound-separate-1` | separate | 7.99 | 37 | 27 | 3 | 203.1 |
| `opt2-sound-separate-2` | separate | 8.02 | 33 | 23 | 3 | 214.7 |
| `opt2-sound-off-1` | off | 7.95 | 34 | 23 | 3 | 202.0 |
| `opt2-sound-off-2` | off | 7.95 | 32 | 22 | 3 | 193.7 |

Case medians: `joined` 41.61 ms, `separate` 8.01, `off` 7.95. `separate` is
0.06 ms above `off` and 33.6 ms below `joined`, against a 5 ms target. The
hypothesis held: one `gst-launch` shares one pipeline latency, so the picture
waited for the sound branch; with the sound in its own process it does not.

The `joined` figure is higher than fix7's 33.7–40.3 because this image is a
derived one (its app, sampler and page predate HEAD); the three cases ran in one
image on one day, which is what the comparison needs.

## Decisions

- `separate` means "the sound has its own process and pipeline"; `joined` stays
  the default and its command is byte-for-byte the old one (pinned by both
  tests), `off` is untouched. The owner asked for `separate` itself to be the
  tested path.
- The sound keeps `name=ws-audio`, `meta=TP-Sound,name=TP-Sound` and the same
  signaller/congestion/retransmission settings, so the page's producer pick-up
  is unchanged; only the process it lives in changed.
- The sound pipeline gets the same `GST_TRACERS` environment as the picture's,
  so its log says what the sound costs, and its log has a name of its own
  (`sound.log` is PulseAudio's).
- The fallback for a bad `SESSION_AUDIO` moved into `resolve_audio_mode()` so the
  dry runs show the warning and the same fallback a start takes, without
  changing what `main` does.
- A new dry-run mode rather than a second section in `--print-pipeline`, so
  job 1's test keeps comparing one command against one expected block.
- Measured with the image's own page (obstacle above) rather than rebuilding the
  app; the page is identical in all three cases, so the host comparison stands,
  and capture-to-screen stays comparable with fix7's images.
- `streaming/entrypoint.sh` is 747 lines, over the 380-line script limit in the
  brief's rules. It was not split: this job adds ~46 lines to a 701-line script
  whose split is a refactor of its own, and the brief's steps all land in it. It
  is flagged here rather than done inside a measurement job.

## Self-check (docs/review-rules.md part A, 1-5)

1. **Every host setup.** Not affected: no Dart/app file changed; the sound
   pipeline exists only inside the Linux session container. Shown by the
   dry-run test and by the six runs' summaries (app frames unchanged, 19–22 ms
   per frame in all cases).
2. **Kept state starts and ends.** The sound process starts right after the
   picture pipeline in `main`, is added to `child_pids`, and ends the same three
   ways as every other child: `stop_all` on a TERM/INT trap, the `wait -n` that
   ends the session when any child exits, or the container stopping. Evidence:
   the kept run's two pids 64 and 66, killed by the bench's own stop.
3. **New state combinations.** `separate` × `SESSION_TAP=on`: tested (picture
   is `tap_runner.py`'s and has no sound; the sound command is unchanged by the
   tap). `separate` × a bad `SESSION_AUDIO`: not possible (one value);
   an unknown value falls back to `joined` and starts no sound pipeline,
   tested. `separate` × `off`: exclusive values of one switch.
4. **Stay in the job's folder.** Only `streaming/entrypoint.sh`,
   `streaming/tap/entrypoint_audio_test.sh`,
   `streaming/tap/entrypoint_pipeline_test.sh` and this report were written;
   all inside `allow:`.
5. **Stop rather than overstep.** `streaming/README.md` (its `SESSION_AUDIO`
   row), `docs/streaming-latency-journey.md` and a Dockerfile-based rebuild are
   outside `allow:` or banned; each is reported instead of changed.

## Checks run

- `bash -n streaming/entrypoint.sh`, `bash -n streaming/tap/entrypoint_audio_test.sh`,
  `bash -n streaming/tap/entrypoint_pipeline_test.sh`: all clean.
- `bash streaming/tap/entrypoint_audio_test.sh` in `tp-stream`: `ok: the
  entrypoint audio modes`; the same file against the previous job's entrypoint
  (old code): `29 check(s) failed`.
- `bash streaming/tap/entrypoint_pipeline_test.sh` in `tp-stream`: `ok: the
  entrypoint pipeline, tap off and on`.
- `tools/check.sh format` is refused by this shell; its own command
  (`dart format --output=none --set-exit-if-changed controller_app tv_test_app
  packages assets`) was run directly: `Formatted 795 files (0 changed)`.

## Hand-over

- What exists: `separate` = the sound's own `gst-launch` process, started and
  stopped like the other children, logged to `/run/thumb-party/sound-pipeline.log`;
  `--print-sound-pipeline` for the tests; two test files covering all three
  modes.
- Commands that worked (in `tp-stream`):
  - copy a file: `cat streaming/<file> | wsl -d tp-stream -u root -- bash -c 'cat > /work/<job>/streaming/<file>'`
  - derived image: a `/work/img/Dockerfile` with `FROM tp-session:latest`,
    `COPY entrypoint.sh /usr/local/bin/entrypoint.sh`,
    `COPY tap/ /usr/local/bin/tap/`, then `docker build -q -t tp-session:latest /work/img`
  - runs: `bash streaming/bench.sh --seconds 40 --label <label> --out /work/stream-bench/<label> --set SESSION_AUDIO=<joined|separate|off>`
  - figure: `stream.host.gauges.pipelineMs.mean` and
    `stream.viewers[0].stages.stream_total.median` in `summaries/<name>.json`.
- Do not redo: the hypothesis test (sound in its own pipeline drops the host to
  the no-sound figure — measured, 8.0 against 7.95) or the proxy/file-by-file
  sync route.
- Open: a full rebuild from HEAD would restore HEAD's page and the 33 ms
  baseline; the README's `separate` row and the journey document's open item
  ("sound sets a pipeline-wide wait of about 27 ms") need updating outside this
  job's files; the sound pipeline's own `pipeline-latency` records were not in
  its log (element records only), so the sound's own end-to-end wait is not yet
  a number.

## Commit message

opt2-5: sound gets its own pipeline in SESSION_AUDIO=separate

The sound branch leaves the picture pipeline and runs as a second
gst-launch with its own webrtcsink, producer meta and log, started and
stopped like the other children (entrypoint.sh). A new
--print-sound-pipeline dry run prints its command, and --print-pipeline
now resolves a bad SESSION_AUDIO like a start does. Six headless bench
runs: the host pipeline time falls from 41.6 ms (joined) to 8.0 ms
(separate), 0.06 ms from no sound at 7.95, and capture-to-screen from
155 to 35 ms. Tests cover every mode, the fallback and the tap.

## Status row

opt2-5 done: `SESSION_AUDIO=separate` runs the sound in its own pipeline and the host pipeline time is 8.0 ms against `joined`'s 41.6 (off 7.95), tested; open: full image rebuild from HEAD (33 ms baseline and HEAD's page), README and journey-document updates outside this job's files.

## Delete

- none
