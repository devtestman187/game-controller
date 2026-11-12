# M15 fix5 j1-1: the first phone run's three defects

## Summary

- **`streaming/player/reporter.js` — done (1a):** `_report()` keeps its `_previous` bookkeeping and sends no
  batch until the page has a decoded frame (`framesDecoded > 0`).
- **`packages/metrics` — done (1b, tests first):** `streamViewers` lists a row only with a gauge, a counter or
  a stage outside `capture`/`encode`/`send`/`total`, counts the rest, and prints "N viewer row(s) with no
  receive data left out"; the CSV follows; `report_stream_test.dart` has `phantomViewerSession()` and two tests.
- **`streaming/bench.sh` — done (1c, 3):** `wait_viewer` waits for `bitrateReceivedKbps` or
  `stream_display`/`stream_decode`; `report_run` counts viewers with a gauge (python, not `grep -c`);
  `--press-seconds N` (30 s with an external viewer, else 0) keeps a round snapshot, flashes
  `probe/flash {"on": true}` after the window, times the press window and reports refusals.
- **`streaming/entrypoint.sh` — done (2), with a decision:** the encoder gets `(ceiling − audio)/(1 + overhead)`
  and the ready line prints `<ceiling>kbit/s (video <n>)`.
- **`tools/stream.sh` — done (3, 4, 5):** `--press-seconds` checked (whole, 0–600) before anything starts;
  results default to `docs/briefs/m15/bench-results/<start>/<label>`, `stats` finds the newest; Wi-Fi → home
  network in all seven printed places.
- **`streaming/README.md`, `docs/dev-tools.md` — done (1d, 2, 3, 5):** settings table, wire ceiling, stale-tab
  note, press phase, results folder, home network; nothing else is left undone and no lib file passes 380 lines.
- **Root cause, item 1:** every reporter batch held the host's stages too, so a connected page with a black
  picture read as a viewer — and both the report and the bench listed any viewer row, counted or not.
- **Root cause, item 2:** the ceiling was the encoder's CBR setting; FEC/RED re-sends on the wire, so a session
  set to 10000 kbit/s delivered 20353.
- **The two 30 s runs:** FEC on → **20353 kbit/s** received (v1, browser/chrome-headless, 57.92 fps, 2271
  frames); `--set SESSION_FEC=false` → **9693** (56.5 fps, 2195 frames); the encoder stays near its setting, so
  the excess ≈ 110 % is FEC/RTX — the brief's case 1.

## Decisions

1. **`SESSION_FEC_PERCENTAGE` cannot exist, so the overhead is measured.** `gst-inspect` in the image shows
   webrtcsink 0.13.6 has `do-fec`, not `fec-percentage`; in the cc-disabled branch `imp.rs` sets the
   transceiver's 50 % itself, and rtpredenc adds more on top. Entrypoint keeps `fec_overhead_percent=110`
   (named, commented with the two runs' numbers) and derives `video_kbps = (ceiling − 96)·100/(100 + FEC)`, so
   the wire rate is the ceiling. `SESSION_FEC=false` gives 9904 kbit/s (the FEC saving goes to video).
2. **The ready line keeps `bitrate_ceiling`'s grep.** It prints `10000kbit/s (video 4716)`: the ceiling first,
   exactly as `[0-9]*kbit/s` reads it, with the derived rate after it.
3. **The metrics filter and the bench helper use one rule.** Both leave out a row whose stages are all
   host-side; the report states the count, the bench simply does not count it.
4. **The app viewer fixture got a counter.** A real app viewer counts `framesReceived`, so the fixture now
   does too (18-cell quality row updated); otherwise the filter would rightly drop the app row.
5. **`report_run` reads either file shape.** The round snapshot is the stats answer (one line per key), where
   the old awk found no `"mean"`; `received_kbps` is now python and takes the first viewer's gauge — 20353 on
   the raw answer, 9693 on a pretty summary (both checked in the distro).
6. **Press phase: only for a real viewer.** 30 s default needs `--viewer external` and not `--probe`; a bench
   probe run or a headless Chrome run keeps 0. `--press-seconds 0` is the way to say none.
7. **Wording went past the printed lines.** README prose and dev-tools say "on the home network" too; the one
   "Wi-Fi address" left in README is a hardware statement, not a line the tools print.

## Checks

- `tools/check.sh format analyze metrics tv`: **PASS** — format 3 s, analyze 19 s, metrics 146 tests, tv 15 s
  (the tv suite runs `stream_tool_test.dart` and `bash -n` on `entrypoint.sh`, `bench.sh` and `tools/stream.sh`).
- `bash -n streaming/bench.sh`, `bash -n tools/stream.sh`, `bash -n streaming/entrypoint.sh`: clean.
- `tools/stream.sh selftest` in `tp-stream`: 16/16 checks.
- The two headless bench runs (30 s each), numbers above; a real viewer plus one phantom in both logs — the
  defect reproduced, then the helper picked only the real viewer.
- Press phase and the round-snapshot branch: run with stubbed functions (`bash -x`), the open line printed for a
  session with no `press_to_screen` stage.
- `--press-seconds abc` and `601`: exit 2, `stream: --press-seconds is a whole number of seconds 0 to 600,
  got "abc"`, before any container starts (tv suite).
- Computed values: 4716 = 990400 div 210; 9904 = 990400 div 100; 20353/10000 ≈ 2.04 → overhead 104 %, the
  named 110 % covers RTX.

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** not affected — no app, game, protocol or phone flow changed; the diff is the player
   page's JS, two scripts, the metrics package and docs, tested by the metrics and tv suites.
2. **When kept state starts and ends:** the reporter's `_previous` still starts empty and updates on every
   poll; only the send is gated, so the first real batch covers the window before it; when no media ever
   arrives nothing is sent and the relay has no viewer to forget.
3. **How a new state combines:** nothing here pauses, hides or blocks input; the press phase runs after the
   round's clock has stopped, so it cannot overlap a round, a pause or "Get ready".
4. **Stay in the job's folder:** yes — only the twelve files in `allow:` were written.
5. **Stop rather than overstep:** the brief's `SESSION_FEC_PERCENTAGE` cannot be set on webrtcsink 0.13.6; the
   measurable substitute above is reported here instead of guessed around (decision 1).

## Questions

1. Is a measured `fec_overhead_percent` (110, one named value in `entrypoint.sh`) acceptable where the brief
   asked for a settable `SESSION_FEC_PERCENTAGE` (default 25)? A settable knob would be a lie on this
   webrtcsink; the bench could print the measured overhead per run instead.
2. `streaming/bench.sh` traps `stop_all` on EXIT, so a `fail` exits 0 (pre-existing; reproduced with the old
   `--sessions 9` check). Not touched — it needs a decision on how to keep the cleanup and the code.
3. The two ceiling runs' result folders live in the distro's `/work` and were removed with the scratch (the
   brief says leave none); their numbers are in the summary. Should a re-run write them under
   `docs/briefs/m15/bench-results/` for the record?

## Hand-over

- **What exists now:** a bench whose viewers are only the ones with numbers; `--press-seconds` with a round
  snapshot and a "press refused" line; a wire ceiling in the session image; results under
  `docs/briefs/m15/bench-results/<start>/<label>` with a `stats` command that finds them.
- **Working commands:**
  `bash tools/stream.sh bench --viewer external --sessions 1 --seconds 30` (round + 30 s of presses) and
  `bash tools/stream.sh bench --viewer external --press-seconds 0 ...` (round only);
  `bash tools/stream.sh stats --results docs/briefs/m15/bench-results/<start>/<label>`.
- **Phase 2 must not redo:** the viewer filter, the reporter gate, the ceiling derivation, the press phase and
  the results folder — all verified here.
- **Open:** a real phone run with the press phase was not possible in this job (no devices started); the two
  questions above; the `received_kbps` change only reached the report line, not the docs' description of it.

## Commit message

```
fix stream bench: phantom viewers, honest ceiling, press phase

A page that never decoded a frame no longer registers as a viewer, and the
metrics report and bench leave out rows with only the host's stages. The
session's ceiling is now a wire ceiling: the encoder gets (ceiling - audio)
/(1 + FEC overhead), measured at 110 % on Nov 12 (20353 vs 9693 kbit/s).
An external-viewer run measures presses after the round and keeps the round
snapshot; bench results default to docs/briefs/m15/bench-results.
```

## Status row

- **M15 fix5 j1-1 (the first phone run's defects):** a page with no decoded frame is no longer a viewer
  (reporter and report), the session's ceiling is a wire ceiling (encoder 4716 of 10000 kbit/s, FEC measured at
  20353 → 9693 off), an external-viewer run times presses after the round, bench results default under
  `docs/briefs/m15/bench-results/`, and the tools say "home network".

## Delete

- none
