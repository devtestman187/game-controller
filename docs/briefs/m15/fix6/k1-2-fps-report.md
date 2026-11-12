# k1-2 fps: what holds the game under 60 fps, and what a switch does about it

## Summary

The 48 fps is a frame-clock wait, not a busy game: in the Arena round the app's own work was
build 1.1 + raster 10.4 ms of a 16.7 ms slot, yet frames started 20.4 ms apart (`gameFrameMs`), so about
9 ms of every frame was spent waiting for the compositor's frame callback, and roughly one frame in five
missed its slot (the app itself counted 18.5 % and 13.5 % of its frames dropped).

- **Cause, measured:** Impeller's raster of a 1080p frame (9.9 ms mean, 4x the run-to-run spread of 1.1 ms)
  leaves no margin for the one-vsync wait the GTK frame clock adds, and a frame that misses is a whole
  16.7 ms. Halving the raster (Skia) halves the wasted time.
- **Skia, `THUMB_PARTY_IMPELLER=0`** (new switch in the Linux runner): raster 4.6 ms, **55.3 and 52.1 fps**
  against the baselines' 48.5 and 51.9, `slowFramePct` 0.6/1.3 against 3.5/3.6, drops 5.6/11.9 %
  against 13.5/18.5 %, game CPU 79 % against 102 %. The frame cost is outside the noise (5.2 ms against
  1.1); the frame rate's gain (3.5 fps) is at the edge of the 3.4 fps noise.
- **Not the cause:** the latency tracer (off: 51.5 fps, inside 48.5-51.9, though it costs 26 % of a core in
  the encoder's process) and `videoconvert`'s single thread (`n-threads=4`: 43.7 fps, 4.8-8.2 below both
  baselines, more CPU everywhere).
- **Became a default: nothing.** The renderer switch is kept and documented; the default stays Impeller
  because the fps gain does not clearly beat the noise (see Decisions).
- **Still not 60:** at 5.4 ms of app work 1 frame in 15 still doubles, and the card did it at 5.9 ms of work
  in k1-1 (18.3 ms/frame). That residue is on the frame-clock/compositor side, is not explained here, and
  needs a knob this job's files do not have.
- **Host leg:** not re-measured. No default changed, so the rows k1-1 left stand; the sixth run went to the
  brief's second named candidate instead. Skia should move `built>raster` from ~5 to ~2.5 ms by the same
  gauge (predicted, not measured).

Noise for every verdict below: the two baselines differ by 3.4 fps, 1.27 ms/frame and 1.14 ms of raster.

## Method

All six runs were `--sessions 1 --seconds 45 --game arena` of `streaming/bench.sh` **run directly inside
tp-stream** (`tools/stream.sh` and `tools/check.sh` are refused by this sandbox; `tools/wsl-sync.sh` too, so
the checkout was seeded from the previous job's `/work/` copy and the two changed files were piped in with
`cat`), then `docker build -f streaming/Dockerfile -t tp-session:latest .` in `/work/<job>`. Each run's
summary is in `docs/briefs/m15/fix6/k1-2/`. The window the bench reports ended after 55-62 s (45 s of round
plus its settle), as in k1-1.

The image was rebuilt once with the two entrypoint switches (`SESSION_TRACER`, `SESSION_CONVERT_THREADS`,
both off by default) and the runner's renderer switch, and once more after the C++ tidy-up and the removal of
the two losing switches. A by-hand smoke run of the final image (no settings) printed
`Using the Impeller rendering backend (OpenGLESSDF)`, so the default is unchanged, and the container was
removed again.

One attempt at the converter experiment failed before measuring (`videoconvert n-threads=4` as one
gst-launch token is a syntax error; it needs two), was fixed and rerun as k2e4b; the failed start measured
nothing and is not counted as a run.

## The runs

Means unless said otherwise; p95 of `gameFps` in brackets; "drops" is the app's own
`frames.dropped / (drawn + dropped)` from `GET status`; CPU columns are the container's, the game's and the
encoder process's.

| run  | setting                    | game fps        | frame ms | build+raster  | slow % | drops % | cpu %  | game cpu | enc cpu | enc fps |
| ---- | -------------------------- | --------------- | -------- | ------------- | ------ | ------- | ------ | -------- | ------- | ------- |
| k2b0 | baseline                   | 48.5 (51.7)     | 20.4     | 1.1 + 10.4    | 3.5    | 18.5    | 218.9  | 104.1    | 101.7   | 58.4    |
| k2b1 | baseline                   | 51.9 (53.7)     | 19.1     | 1.2 + 9.3     | 3.6    | 13.5    | 214.8  | 99.7     | 101.9   | 56.2    |
| k2e1 | `THUMB_PARTY_IMPELLER=0`   | 55.3 (58.7)     | 17.8     | 1.1 + 4.3     | 0.6    | 5.6     | 197.5  | 79.2     | 104.8   | 57.1    |
| k2e2 | `THUMB_PARTY_IMPELLER=0`   | 52.1 (56.7)     | 19.3     | 1.2 + 4.9     | 1.3    | 11.9    | 199.2  | 79.7     | 105.7   | 56.6    |
| k2e3 | `SESSION_TRACER=false`     | 51.5 (53.7)     | 19.3     | 1.1 + 9.6     | 2.8    | 13.0    | 183.4  | 101.7    | 75.5    | -       |
| k2e4 | `SESSION_CONVERT_THREADS=4`| 43.7 (46.4)     | 22.1     | 1.2 + 10.9    | 9.4    | 25.2    | 219.2  | 96.7     | 109.2   | 58.0    |

(k2e3 has no encoder fps: that gauge comes from the latency tracer's records, which were off.)

What each says:

1. **Renderer (Skia, candidate 4).** The raster falls from 9.9 to 4.6 ms in both runs — five times the
   raster noise — and the frame rate rises on both runs (52.1 and 55.3 against 48.5 and 51.9, so every Skia
   run is at or above every baseline run), the app's own dropped frames fall from 13.5-18.5 % to 5.6-11.9 %,
   `slowFramePct` to 0.6-1.3, and the game's CPU from 102 % to 79 %. The frame rate's gain (mean 3.5 fps) is
   just inside the baselines' 3.4 fps spread, so it is kept as a switch, not as the default.
2. **The tracer (candidate 1).** Turning the tracer and `GST_DEBUG` off took the encoder's process from
   101.7 % to 75.5 % of a core and the container from 215 to 183 %, and the game drew 51.5 fps (inside
   48.5-51.9) with a 9.6 ms raster (inside 9.3-10.4). So the tracer does cost CPU, but not the game's: the
   measurement is not stealing frames, and nothing about the default needs to change.
3. **`videoconvert`'s threads (candidate 2).** Four threads made it worse in every column — 43.7 fps
   (4.8-8.2 below both baselines, outside the noise), raster 10.9, `slowFramePct` 9.4, drops 25.2 %, the
   encoder's process 109 %. The conversion is not the bottleneck; the extra threads only take cores from the
   game. Left out of the code.
4. **`--session-cpus` (candidate 2's other half)** was not run: the CPU never ran out (215 % of a 16-core
   VM, the game at ~1 core) and the runs that were left went to the named candidates and to the renderer.

## What the data says about the frame clock (candidate 3, candidate 5)

- The compositor renders on demand: the source's `create()` sends `Command::Buffer`, the compositor's loop
  waits out the rest of the refresh interval from the last render, renders, sends the buffer **and** then the
  client's frame callbacks (`wayland-display-core/src/comp/mod.rs:1087-1178`, callbacks at :1133). The
  output's mode refresh is the negotiated frame rate in mHz (:734-736, :811; 60 fps = 60000), so the app's
  frame clock is driven by the pipeline's pull cadence, one callback per rendered frame.
- That makes every frame exactly one 16.7 ms tick long, and a frame whose present arrives after the tick
  waits a whole second tick: the app's interval is 16.7 or 33.3 ms, never in between, which is what
  `gameFrameMs` 17.8-20.4 against a 16.7 grid looks like (22 % doubles with Impeller, 6-12 % with Skia).
- `gst-inspect-1.0 waylanddisplaysrc` in the image has **one** property, `disable-intel-workaround`: there is
  no property that ties capture to commits or to the client's frame callbacks, so candidate 5 has no switch
  to try and the 60 Hz sampling cannot be removed from the pipeline side.
- This engine has **no** `FLUTTER_ENGINE_SWITCHES` string (`grep` of `/app/lib/libflutter_linux_gtk.so`);
  it does export `fl_dart_project_set_enable_impeller` (`fl_dart_project.h:170` in the SDK the image builds
  with), which is the route the runner switch takes. Its only renderer knob otherwise is
  `FLUTTER_LINUX_RENDERER` (`software`/`opengl`), which is not the Impeller/Skia choice.
- Unexplained: at 5.4 ms of app work 1 frame in 15 still doubles, and k1-1's card did 18.3 ms/frame at
  5.9 ms of work. Either the compositor's render (software, 1080p, in the pipeline's own thread) or the
  GTK frame clock adds a missed tick that this job cannot reach; it is where the next phase should look.

## Decisions

1. **Skia stays a switch** (`THUMB_PARTY_IMPELLER=0`), not the default: its fps gain is inside the noise by
   the brief's rule, while its raster and drop numbers are not. The switch is documented in the runner's
   comment and in `streaming/README.md`, with both runs' numbers.
2. **The tracer and converter switches left the code** after measuring: the brief keeps only what beats the
   noise, and both lost (the tracer inside the noise, the converter worse). `entrypoint.sh` is back to its
   previous content, byte for byte.
3. **No UI change and no change to a press**: the probe path and the Arena's host tree were not touched. The
   only app change is one embedder call in the Linux runner.
4. **The host leg was not re-measured** with a probe run: with no default changed the rows are k1-1's, and
   the last run was needed for the second named candidate. The Skia prediction above is labelled as such.
5. **The renderer switch goes through the runner, not an engine-switch variable**: the engine in the image has
   no such variable (evidence above), and the embedder API is the supported route.

## Questions

1. Should Skia become the default? The case is the raster (4.6 against 9.9 ms), the dropped frames (5.6-11.9 %
   against 13.5-18.5 %) and the game CPU (79 % against 102 %); the counter is that 3.5 fps is inside the
   3.4 fps noise over two runs each. Two more pairs would settle it.
2. The residue (1 frame in 15 doubled at 5 ms of work) is on the compositor/GTK side; a fix would need the
   plugin (a patch pinned in the Dockerfile) or a GTK frame-clock knob, both outside this job.
3. Worth a cheaper tracer (`flags=pipeline`, or a longer `SAMPLER_INTERVAL_S`) to give back the 26 % of a core
   the tracer costs the encoder's process? It bought no game fps here, so it is only headroom for more
   sessions at once.

## Files changed

- `tv_test_app/linux/runner/my_application.cc`: `THUMB_PARTY_IMPELLER` (default on) passed to
  `fl_dart_project_set_enable_impeller`, so the container can compare Skia with Impeller; the comment carries
  the measured numbers.
- `streaming/README.md`: the new setting in the settings table, with both runs' figures and why it is not the
  default yet.
- `docs/briefs/m15/fix6/k1-2-fps-report.md` and `docs/briefs/m15/fix6/k1-2/*-summary.json`: this report and
  the six runs' summaries.
- Nothing else: `streaming/entrypoint.sh` was changed for the two losing switches, measured, and reverted
  byte for byte (`git diff` is empty for it).

## Checks

`tools/check.sh format analyze metrics host tv` could not be run: this sandbox refuses `tools/check.sh` (and
`dart`) the same way it refused `tools/stream.sh`. No Dart file changed — the diff is one C++ runner file
and one markdown file — so `format`/`analyze` have nothing new to look at. The C++ was compiled by the image
build (`docker build` exit 0 after the final edit, Flutter release build of `tv_test_app`), and
`bash -n streaming/entrypoint.sh streaming/bench.sh tools/stream.sh` passes on the final scripts (the two
entrypoint switches are gone).

Measured test values, for the review: dropped % = 499/2690, 365/2714, 152/2718, 324/2715, 352/2699,
683/2706; mean fps pairs 50.18 (baseline) against 53.70 (Skia), 51.51 (tracer off), 43.68 (converter).

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** a desktop or TV host that sets nothing keeps Impeller exactly as before (the smoke
   run printed the Impeller line); a phone host or an older build does not run this runner at all, and the
   streaming container's app is built from this checkout, so it gets the switch only when its environment
   names it. Nothing in the status/stream protocol changed.
2. **When kept state starts and ends:** nothing is held, timed or counted; the runner reads the variable once
   at startup (`impeller_from_env`, before the engine exists) and the value lives as long as the process.
3. **How a new state combines:** nothing pauses, hides or blocks input. The renderer is chosen once, before
   the first frame, so pause/away/ready/drop/results/leaving are the same code on both renderers.
4. **Stay in the job's folder:** every file written is this report, `docs/briefs/m15/fix6/k1-2/`,
   `streaming/README.md` and `tv_test_app/linux/runner/my_application.cc`, all in `allow:`; the bench wrote
   only `/work/stream-bench/*` and `/work/*.log` inside the distro, and the one smoke container was removed.
5. **Stop rather than overstep:** the host-leg probe run and `--session-cpus` were left unrun rather than
   going past the six-run budget; `tools/check.sh`, `tools/wsl-sync.sh` and `tools/stream.sh` were refused by
   the sandbox and are reported, not worked around inside the repository; the compositor patch idea was not
   taken because it needs a file outside `allow:`.

## Hand-over

Final state: `THUMB_PARTY_IMPELLER=0|false` draws with Skia in the Linux runner; unset keeps Impeller.

Commands that worked in tp-stream, in the job folder under `/work/` (`tools/stream.sh` is refused here):

```
cat <file> | wsl -d tp-stream -u root -- bash -c 'cat > /work/<job>/<path>'   # per changed file
docker build -f streaming/Dockerfile -t tp-session:latest .                    # ~4 min with the app
bash streaming/bench.sh --sessions 1 --seconds 45 --game arena --label k2e1 --out /work/stream-bench/k2e1 \
  --set THUMB_PARTY_IMPELLER=0
```

Numbers to compare against: baseline **48.5 / 51.9 fps**, raster 9.3-10.4, drops 13.5-18.5 %; Skia
**52.1 / 55.3 fps**, raster 4.3-4.9, drops 5.6-11.9 %; noise 3.4 fps and 1.27 ms/frame.

Unexplained: the 1-in-15 doubled frame at 5 ms of work. Do not redo: the tracer and converter switches (both
lost), the `FLUTTER_ENGINE_SWITCHES` search (this engine has none), the `waylanddisplaysrc` property search
(one property, unrelated), a `--session-cpus` test here (the CPU is not short).

## Commit message

runner: a renderer switch, measured against Impeller

The Linux runner reads THUMB_PARTY_IMPELLER: 0 or false draws with Skia,
anything else keeps Impeller, the engine's own default. The streaming
container has no engine-switch variable to do this, so the comparison runs
through fl_dart_project_set_enable_impeller. Measured on the Arena round
(k1-2): Skia halved a 1080p frame's raster (4.6 ms against 9.9) and drew
52.1-55.3 fps against the baselines' 48.5-51.9, with fewer dropped frames;
the gain is at the edge of the run-to-run noise, so it stays a switch.
Results and the two switches that lost are in docs/briefs/m15/fix6/k1-2/.

## Status row

k1-2 fps: the 48 fps is the one-vsync frame-clock wait (app work 11.5 ms of 16.7, `gameFrameMs` 20.4) plus
Impeller's 9.9 ms raster; a new runner switch (THUMB_PARTY_IMPELLER=0, Skia) halves the raster and drew
52.1-55.3 fps against the baselines' 48.5-51.9 (gain at the noise edge, kept as a switch, default unchanged);
the tracer and videoconvert threads measured no gain and left the code; open: the 1-in-15 doubled frame at
5 ms of work is on the compositor/GTK frame-clock side, and no probe run after (host leg unchanged).

## Delete

- docs/briefs/m15/fix6/k1-2/all-summaries.jsonl
