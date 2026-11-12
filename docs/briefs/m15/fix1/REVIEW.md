## Summary

Verdict: **one fix batch**. Format, analyze, metrics (144) and host (412) pass; one setting never ran what its docs say, one provider has no end and no test, and the f1 commit carries t1's test file.

- Severity: **1 must, 9 should, 11 could**.
- Top: `SESSION_VBV_KBITS` is kbits but reaches nvcodec's `vbv-buffer-size`, which is bits, so the one-frame VBV was 167 bits — the README and the t1 report describe a setting that never ran (t1's own must, still in the tree).
- Top: commit `5ffd764` (f1) contains `tv_test_app/test/stream_tool_test.dart`, whose keep-alive, `--set` and 413 tests cannot pass on f1's `tools/stream.sh` and `serve.py`: `tv` is red at that commit and the f1 report's count (58 → 59) is a run without them. The two briefs' allow lists overlap on that file.
- Top: the bind error (`automationStartErrorProvider`) is written and never cleared or re-armed, its link to the server has no test, and only the TV's latency screen shows it — the phone host and the shared `StatsScreen` say nothing.
- Top: the body reader drains to twice the cap after refusing, which is the opposite of f1 item 2's letter, and its test is named "before it is all read" while asserting 147,456 bytes were read.
- Top: the player's `problem` is never cleared though t1's self-check says it is, and the statistics-stopped line it sets can never reach the overlay.
- Owner's questions: after the VBV unit is fixed, re-run the one-frame experiment before trusting it; the relay trusts anyone who can open the page; `url` still calls localhost "on this PC" where no media flows; no bench ever went through `tools/stream.sh bench --set` end to end.

## Findings

- **must** streaming/entrypoint.sh:255 `SESSION_VBV_KBITS` is named, commented and documented in kbits (`entrypoint.sh:38`, `streaming/README.md:65`) but passed unchanged to nvcodec's `vbv-buffer-size`, which GStreamer documents in bits, so `167` was 167 bits and `t1-vbv`–`t1-vbv2`, `t1-f1`–`t1-f3`, `t1-feca`, `t1-fa`, `t1-720` and `t1-cuda` measured something other than a one-frame buffer → pass `$((vbv_kbits * 1000))`, or rename the setting to bits with one frame's worth written out. (from: t1)
- **should** tv_test_app/test/stream_tool_test.dart:57 f1's commit `5ffd764` adds the keep-alive, `bench --set` and relay-413 tests (57, 72, 86, 153) while its `tools/stream.sh` has no `keep-alive`/`--set` and its `serve.py` has no 413, so `tools/check.sh tv` fails on that commit; the cause is the briefs, whose allow lists both hold this file (f1's `tv_test_app/test`, t1's `tv_test_app/test/stream_tool_test.dart`) → note it in STATUS and give each file to one brief next time; the final tree is unaffected. (from: f1)
- **should** packages/party_host/lib/src/automation/automation_body.dart:33 a body past the cap is drained up to twice the cap before the refusal, where f1 item 2 says "stop with the too long error as soon as the cap is passed", and the test at automation_server_test.dart:288 is named "before it is all read" while :305 asserts 9 × 16 KB were read → stop the stream at the cap as the brief says, or rename the test and record the drain as a decision. (from: f1)
- **should** packages/party_host/lib/src/automation/automation_providers.dart:148 the start error is set once and never cleared — not by a successful start, a `stop()` or a rebuilt server provider — so f1's self-check A2 ("ends with the server (a settings change rebuilds the provider)") is untrue and a host that frees its port keeps showing the old line → add `clear()` and call it on a successful start, or write in A2 that it lasts for the app run. (from: f1)
- **should** packages/party_host/lib/src/automation/automation_providers.dart:161 nothing tests the `onStartError` → `automationStartErrorProvider` link: the server test passes no callback and latency_screen_test.dart:49 sets the notifier itself, so deleting this line leaves both green → add a test that fails a bind with the provider listening and asserts its state. (from: f1)
- **should** streaming/player/player.js:62 `problem` is set by `noteProblem` and cleared nowhere (not in `closeConsumer` at :187), so one failed measurement leaves a `measurement: …` line in the overlay for the page's whole life, though the t1 report's A2 says it is reset at `closeConsumer` → clear it there, as `playingStream` is. (from: t1)
- **should** docs/briefs/m15/fix1/t1-latency-tuning-report.md:124 the split-track run is reported as "the audio/video sync offset … was 0 ms", but `docs/briefs/m15/fix1/t1/results/t1-split/t1-split0.json:125` holds `audioSyncMs` n=2, mean 0, p95 and max 1000, so the run cannot answer the brief's "under 60 ms" question → report the two ±1000 ms readings and say the sync question is open. (from: t1)
- **should** docs/briefs/m15/fix1/t1-latency-tuning-report.md:50 the five-minute survival is offered as the keep-alive's hands-on proof while the limitation at :52 says no detached process could be started in that session, so whatever held the distro up was not the keep-alive → name the process that held it or drop the claim and leave the keep-alive proven by its two tests. (from: t1)
- **should** tv_test_app/test/stream_tool_test.dart:97 the relay group starts a real Python process and opens real sockets from `tv_test_app`, which §9 allows only in `connection` tests, and skips itself silently when Python is absent (`:168`) → move it to `connection` or `tools/` tests, or say in the test's doc why it is here and what happens on a machine without Python. (from: t1)
- **should** packages/party_host/lib/src/ui/stats_screen.dart:20 the start error is shown only by the TV's latency screen (latency_screen.dart:50), so a phone in host mode — and the TV's own Stats screen — say nothing about a bind that failed (A1) → show the one line in the shared `StatsScreen` both shells open. (from: across jobs)
- **could** packages/party_host/lib/src/automation/host_automation.dart:177 `addPostFrameCallback` does not ask for a frame, so when nothing else draws one the release never runs and the probe button stays held → call `SchedulerBinding.instance.scheduleFrame()` after queueing it. (from: f1)
- **could** packages/party_host/lib/src/automation/host_automation.dart:177 the release sets a whole empty pad, so a stick or button another `POST input` set just before is dropped one frame later → release only the probe's button, or say in automation.md that a probe clears the player's input. (from: across jobs)
- **could** docs/automation.md:162 "two calls in a row are two presses" is false for two calls inside one frame, where the second changes nothing before the release → say "two calls a frame apart". (from: f1)
- **could** streaming/player/player.js:153 the "statistics stopped" failure calls `noteProblem` and then `stopStats`, so the overlay tick that would print the new `measurement:` line never runs again, though t1 report:79 lists that failure among those shown → print the problem once before stopping the timer. (from: t1)
- **could** tools/stream.sh:280 `start_keepalive` runs before the "a session named … already runs" check (:288) and before `docker run`, so an `up` that fails leaves a keep-alive holding the distro up with no session → call `stop_keepalive` on those failure paths, or start it once the container is up. (from: t1)
- **could** packages/party_host/lib/src/automation/stream_ingest.dart:24 a viewer that is neither a word nor an object now gets its own refusal, a behaviour change neither in the brief nor in the f1 report's decisions → list it as a decision or drop it. (from: f1)
- **could** packages/metrics/bin/stream_sampler.dart:1 this touched file is 445 lines, with tools/stream.sh at 557, streaming/bench.sh at 447, streaming/player/reporter.js at 429 and streaming/entrypoint.sh at 425 (383 before this run), all past §3's hard limit of 400, and f1's "no touched file over 380 lines" is untrue of the bin file → split each along the seams named (the keep-alive into its own script, the relay tests out of the shell tool) in the job that next touches it. (from: across jobs)
- **could** docs/briefs/m15/STATUS.md:11 "Next: the f1 fixes, then fix1/t1 latencies … then tuning (step 3)" is stale now both are done, and :9 still quotes c2's 126 ms press figure without t1's baseline (183) and final (161/234); no job after f1 had STATUS in its allow list → give the next brief STATUS and one line per finished job. (from: across jobs)
- **could** streaming/README.md:38 says the automation interface is "loopback only" (and :162 "listens on loopback inside the container only") while entrypoint.sh:307 sets `THUMBPARTY_AUTOMATION_BIND=0.0.0.0` in a `--network host` container, so it is on the LAN and only the token and the owner's firewall keep it closed → say that. (from: across jobs)
- **could** tv_test_app/test/stream_tool_test.dart:136 the `POST /players` half of the "answers 404" test also passes on the old relay, whose `do_POST` ended in the same 404 with the same message, so only the 413 test proves the refuse-before-the-body change → assert the refusal arrives without the body being read, or note that only the GET half fails on the old code. (from: t1)
- **could** streaming/player/serve.py:64 and packages/party_host/lib/src/automation/automation_body.dart:10 hold the same 64 KB cap for one request path as two constants with no test tying them, so a change to one leaves the other's refusal wrong → have serve.py's comment point at the host's constant. (from: across jobs)

## Open questions

1. After the VBV unit is fixed, does the one-frame buffer still need re-measuring before its switch is trusted? Suggested: yes, re-run `t1-vbv` and three finals; the switch stays off until then.
2. FEC and retransmission stay on at 11.6 against 7.2 Mbit/s: is that the owner's trade? Suggested: keep them on, the delay is identical and FEC is what the bandwidth buys.
3. The relay trusts anyone who can open the player page (it writes measurements and reads the clock). Suggested: accept it as documented; the firewall rule opens 45780–45782 and not 45783.
4. `tools/stream.sh url` prints `http://localhost:<port>/ on this PC` while the README says a browser on this PC gets no media. Suggested: reword the line to say the picture only flows from another device.
5. f1's suggestion that the relay also forward `probe/press` so a browser could time a press itself. Suggested: leave it out; it widens the one hole for a measurement the container already makes.
6. No bench ever went through `tools/stream.sh bench --set`/`--results` (they ran inside the distro). Suggested: one end-to-end `bench --probe --set` run by the owner confirms the tool's own path.
7. f1 asked whether the CSV should carry the tables' `50.0/55.0` cells; it already has separate `_p95` columns. Suggested: no change.
8. f1 asked for the 64 KB wording in `docs/dev-tools.md`; the file does not carry that sentence. Suggested: nothing to change.
9. Experiments 6 (leaky queues, frame pacing), 8 (the app's 44.7 fps) and 9 (the host's ~73 ms leg) are undone. Suggested: an app-code job for 8 and 9, and 6 only if a later run shows the capture interval moving.

## Numbers against targets

- **Gate 1: under 80 ms press to screen.** Final 234 ms median / 273 p95 (`t1-fin3`), baseline 248 → 154 ms over; `stream_total` 183 → 161 (p95 161), the floor of this design.
- **t1's own rule: keep a change only if it beats the 36–44 ms noise.** No change did (best 144–145 total, 213–223 press); none was made a default — met.
- **The split-tracks sync question ("under 60 ms is acceptable").** Unanswered: n=2, p95 1000 ms, reported as "0 ms" (see Findings, the split-track line).
- **Part A1's hands-on keep-alive proof (a session up 5 minutes with no other Windows process attached).** Claimed and contradicted by the same report (see Findings, the five-minute line).
- **The bitrate ceiling (Part A3).** 4 000 asked → 3 736 received with FEC off; 10 000 → 11 580 with FEC; the excess is FEC and the 96 kbit/s sound, documented — met.
- **f1 item 10: the full record against the PRD's 50 KB.** 45,580 bytes (44.5 KB), pinned by `stream_budget_test.dart` — met.
- **f1's "no lib file over 380 lines"** met (largest 359); "no touched file over 380" is not (445, see Findings, the 400-line line).
- **§3's hard limit of 400 lines.** Five touched files over it (see Findings, the 400-line line).
- **The f1 report's tv count (58 → 59).** Its commit adds 7 tv tests, so 59 is a run without `stream_tool_test.dart` (see Findings, the f1 commit line).

## Could not check

- The `tv` and `phone` suites: I ran format, analyze, metrics (144) and host (412) only; `flutter test` rewrites `tv_test_app/{linux,windows}/flutter/generated_*`, which are already modified in the working tree before this review.
- The tv failure at `5ffd764` is inferred from `git show 5ffd764:tools/stream.sh` (no `keep-alive`, no `--set`) and `serve.py` (no 413), not from a run.
- `gst-inspect`'s `vbv-buffer-size` unit: taken from GStreamer's documented description, not from the distro on this machine; the must rests on that one fact.
- The WSL runs, the iPhone play, the five-minute survival and the pre-fix image cannot be reproduced from this checkout.
- The relay group of `stream_tool_test.dart` skipped here (no Python), so its 404/413 tests were read, not run.

## Commit message

M15 fix1 review: one must, nine shoulds, eleven coulds

The one-frame VBV passes kbits to a property that takes bits, so the setting
and its two documents describe a run that never happened. f1's commit carries
t1's stream_tool_test.dart, whose keep-alive, --set and 413 tests cannot pass
there, and the body reader drains past the cap against its brief and its test's
name. The bind error never clears, its provider link and the phone host show
nothing, and the player's problem is never cleared. Coulds: the probe's frame
release, the relay tests' real sockets, five files over 400 lines and a stale
STATUS. No code or document changed.

## Status row

- **run review done:** 1 must (the VBV unit), 9 shoulds (f1's commit carrying t1's test file, the cap drain, the bind error's missing end, its untested link and its TV-only display, the player's stale problem, two wrong t1 report claims, real sockets in the tv tests) and 11 coulds; **open:** Claude to verify the must and write one fix batch, and the owner's answers to the VBV re-run, the relay's trust and the localhost wording.

## Delete

- none
