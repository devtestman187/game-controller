# M15 t1 review: the latency tuning and the session fixes

## Summary

Verdict: **small fixes** — 1 must, 4 should, 5 could.
- **must:** `SESSION_VBV_KBITS` goes straight to nvcodec's `vbv-buffer-size`, which GStreamer documents in bits, so the
  "one-frame VBV" experiment set 167 bits rather than 167 kbit, and the report and `streaming/README.md` describe a
  setting that never ran (`streaming/entrypoint.sh:255`).
- `strict-gop=true` was added inside the same `if` as the VBV switch, so the VBV runs changed two encoder settings at
  once and the result cannot be attributed to the buffer (`streaming/entrypoint.sh:255`).
- The player's `problem` is never cleared, although the report's self-check says it is reset at `closeConsumer`
  (`streaming/player/player.js:54`, report line 233).

## Findings

- **must** streaming/entrypoint.sh:255 `SESSION_VBV_KBITS` is named and documented in kbits (comment 38–45,
  `streaming/README.md:65`) but passed unchanged to nvcodec's `vbv-buffer-size`, whose unit gst-nvcodec documents as
  bits, so `167` is 167 bits and the switch does not do what the report measured it doing → pass `vbv_kbits * 1000`, or
  rename the setting to bits and document one frame's worth as `bitrate_bps / frame_rate`.
- **should** streaming/entrypoint.sh:255 `strict-gop=true` is added only when the VBV is on, so `t1-vbv`, `t1-vbv2` and
  `t1-f1`–`f3` changed two encoder settings at once and their numbers cannot be credited to the VBV → make
  `strict-gop` its own setting, off by default, or drop it, and list it under Decisions.
- **should** streaming/player/player.js:54 `problem` is set by `noteProblem` and never reset, so one failed measurement
  leaves a stale `measurement: …` line in the overlay for the rest of the page's life, and report line 233 says it is
  reset at `closeConsumer` → clear `problem` in `closeConsumer()` next to `playingStream = null`, or correct the report.
- **should** docs/briefs/m15/fix1/t1-latency-tuning-report.md:125 the split-tracks run is reported as "the audio/video
  sync offset … was 0 ms", but `t1-split0.json` holds `audioSyncMs` n=2, mean 0, p95 and max 1000, i.e. two readings of
  ±1000 ms, not a 0 ms offset → report what the gauge held (and how few samples) and say the run cannot answer the sync
  question, which the brief asked to keep under 60 ms.
- **should** docs/briefs/m15/fix1/t1-latency-tuning-report.md:50 the five-minute survival is offered as the keep-alive's
  hands-on proof while the next sentence and the Decisions entry (line 169) say no detached process could be started in
  this session; a session that stayed up for five minutes with no keep-alive proves nothing about the keep-alive → name
  the process that actually held the distro up, or drop the survival claim and leave the keep-alive proven by the tests.
- **could** streaming/player/player.js:152 the "statistics stopped" failure calls both `noteProblem` and `stopStats`, so
  the overlay tick that would print the new `measurement:` line never runs again, and report line 81 lists that failure
  among those shown in the overlay → show the problem once before stopping the timer, or reword the report.
- **could** tools/stream.sh:280 `start_keepalive` runs before `docker run` in `cmd_up`, so an `up` that fails after it
  leaves a keep-alive holding the distro up with no session to keep alive → call `stop_keepalive` on the failure path, or
  start it only once the container is up.
- **could** tools/stream.sh:1 the file is 557 lines (it was 432 before this job) against the guidelines' hard limit of
  400, which the keep-alive's ~40 lines pushed further over → move the keep-alive's five functions into a
  `tools/stream-keepalive.sh` sourced by the tool.
- **could** docs/briefs/m15/fix1/t1-latency-tuning-report.md:188 experiment 6 (leaky one-buffer queues, in the pipeline
  and so inside `allow:`) was not attempted at all, while its three-attempt time-box was meant for experiments that
  cannot run → run at least the queue half, or say plainly it was skipped for time.
- **could** tv_test_app/test/stream_tool_test.dart:141 the `POST /players` half of the "answers 404" test passes on the
  old relay too, because the old `do_POST` also ended in a 404 with the same message, so it does not prove the
  refuse-before-the-body change (the 413 test is the one that does) → assert the refusal arrives without reading the
  body, or note that only the GET half fails on the old code.

## Decisions to confirm

- **VBV off, FEC and retransmission on, split tracks off, one keyframe a second:** the measurements do not beat the
  noise, so each is a judgement about bandwidth and drops rather than one the numbers settle for the owner.
- **The relay keeps two host calls (`GET /status`, `POST /stats/stream`) and trusts whoever can open the page:** the
  docstring now says so; it is still an ingest hole on any network the page is reachable from.
- **A browser on this PC cannot play the stream** (README "Watching from another device"): worth the owner confirming
  that this is the accepted state, since `tools/stream.sh url` still lists the localhost address as "on this PC".
- **Benches ran in the distro, not through `tools/stream.sh`:** `bench --set` and `--results` were exercised only inside
  the distro, so the tool's own path for them is untested end to end.

## Could not check

- `gst-inspect` in the distro (approval refused here), so the `vbv-buffer-size` unit comes from GStreamer's documented
  description, not from this machine; the fix's correctness rests on that one check.
- Python is not installed here, so the relay group in `stream_tool_test.dart` skips; I ran no `flutter test`, and the
  review brief named no check.
- The five-minute WSL survival, the owner's iPhone play, the `.wslconfig` state and the pre-fix image (`t1-before`)
  cannot be reproduced from this checkout.
- The relay and keep-alive tests are in the tree but were committed in 5ffd764 (the parent), not in this diff, so I
  cannot tell from the diff which job wrote them; they do exercise the new code.
- `docs/briefs/m15/fix1/run-findings.md` does not exist, so no "passes on the old code" entries were available.

## Commit message

M15 t1 review: one must, four should, five could

The VBV switch passes kbits to a property that takes bits, so the one-frame
experiment never ran what the report and the README describe; `strict-gop` rides
with the same switch, so those runs changed two settings at once. The player's
overlay problem is never cleared though the self-check says it is, the split
tracks' "0 ms" sync is a mean of two ±1000 ms readings, and the keep-alive's
five-minute proof contradicts the report's own limitation. Docs, numbers and the
tests otherwise match the code.

## Status row

t1 reviewed: 1 must (VBV unit), 4 should (strict-gop bundled, stale player problem, split-sync number, keep-alive proof), 5 could; open: the VBV switch and its docs to be fixed and the one-frame experiment re-run, `strict-gop` split out, `problem` cleared on close, the keep-alive's hands-on proof or its limitation stated.

## Delete

- none
