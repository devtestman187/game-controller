# M15 run review

## Summary

Verdict: **one fix batch**. Must 4 · should 5 · could 6.

The five that matter most:

1. Gate 1's press-to-screen target is missed, not merely unproven: **203 ms median vs "under 80 ms"**, and that figure already leaves out the phone's own leg (the press comes from the automation interface, not a phone).
2. `packages/metrics/lib/src/session.dart` is at **400 lines** — the guidelines' hard ceiling and past the runner's own 380 stop — because all three jobs appended to it.
3. The host's **64 KB body cap is enforced only after the whole body is read**, so a chunked body is buffered without limit while `docs/automation.md` promises "at most 64 KB".
4. `stream_ingest.dart` says a malformed batch is "refused whole" but applies it up to the bad item, and `docs/automation.md` repeats the claim ("nothing is half applied").
5. The player relay is a **token-less proxy to the host's automation interface on 0.0.0.0**, while its own docstring says a browser can never reach that API — anyone on the LAN inherits the token's power.

Questions only the owner can answer: is a real phone ever tested on Wi-Fi against the session image (c1's open item), and is M15's job only to *measure* at this point, or should the fix batch chase gate 1's 80 ms now?

## Findings

- **must** `docs/briefs/m15/STATUS.md:8` still says "research and three hands-on probes… **Nothing of the product is built**" and line 9 that the run "is on branch `m14`", both false after five commits of product code → rewrite "Where things stand" and "Not yet created" to the run's state. (from: across jobs)
- **must** `packages/metrics/lib/src/session.dart:1` is 400 lines: the guidelines' hard limit and over the runner's own 380 stop, after p1, c1 and c2 each appended a block → move the six `stream*` methods and the two summary keys into a separate file (or an extension in `stream_stats.dart`) so the collector is back under 300. (from: across jobs)
- **must** `packages/party_host/lib/src/automation/automation_server.dart:181` checks the 64 KB cap only after `utf8.decoder.bind(request).join()`, so a body with no `contentLength` (chunked) is buffered whole, contradicting `docs/automation.md:33` → refuse an unknown length or stop reading at the cap, and add a chunked-body test beside `automation_server_test.dart:258`. (from: a2)
- **must** `packages/party_host/lib/src/automation/stream_ingest.dart:15` claims a malformed body is "refused whole, so half a batch never lands", but the viewer is registered and earlier stages/gauges/counters are applied before a later item throws, and `docs/automation.md:33` repeats it → validate the whole body first and then apply it, or say in both places that a batch lands up to the first bad item. (from: a2)
- **should** `packages/metrics/lib/src/report_stream.dart:251` shows only the mean of each host resource gauge, though the c2 brief's item 8 asked for a p95 column for CPU, memory and GPU ("the JSON already has it") and the report does not say why it is missing → print `mean/p95` in those cells as the stage columns print `median/p95`. (from: c2)
- **should** `streaming/player/serve.py:27` says a page "can measure a session but never reach the host's own API", while `/stats/stream`, `/presses`, `/flips` and `/player` are forwarded to the host with the session's token from `0.0.0.0` → correct the docstring and state the trust assumption in the security list of `docs/automation.md`, or bind the relay to the bench machine's own interface. (from: c2)
- **should** `packages/party_host/lib/src/automation/automation_providers.dart:144` starts the server with `unawaited(server.start())`, so a bind failure is dropped and the interface silently never listens while `bench.sh` only shows a timeout → keep the error and report it in `/status` and the log. (from: a2)
- **should** `packages/party_host/lib/src/live_stats.dart:137` adds `session` as a second getter for the same `_session` that `live` (line 134) already returns, splitting callers between two names → keep `live` and use it in the tests too. (from: across jobs)
- **should** `docs/protocol.md:340` justifies the series cap with "the summary at 89 KB with 32 and eight viewers full", but the cap is 16 since c2, so the doc quotes a record nobody can produce now → measure a 16-series record and quote that as the current cost, keeping 89 KB as the reason for the change. (from: across jobs)

- **could** `tv_test_app/lib/src/tv_text.dart:185` keeps `waitingForController`, unused since the debug start screen (`debug_start.dart`) replaced the old start → delete the constant. (from: a2)
- **could** `packages/party_host/lib/src/automation/host_automation.dart:173` sets the probe's button and never releases it, so the host's game keeps it held and a second probe of the same button changes nothing → release it on the next frame, as `bench.sh` releases the presses it sends. (from: a2)
- **could** `packages/metrics/lib/src/report_stream_csv.dart:8` has no `pipeline_ms` column although the text report and the protocol both carry the host gauge that covers capture, encode and parse in one number → add it, or record the omission as a decision. (from: c2)
- **could** `packages/metrics/bin/stream_sampler.dart:401` returns null for every file it cannot read, so a container with wrong cgroup paths reports a stream with no CPU or memory and says nothing → keep the null for vanishing `/proc` entries but warn once when a cgroup read fails. (from: c2)
- **could** `docs/flash-framework.md:46` says the report's Summary is "at most 30 lines" while its own templates say 20 (`templates/run-review.md:14`) and 12 (`templates/job-review.md:15`) → one number in all three. (from: across jobs)
- **could** `tools/run-jobs.sh:213` passes `run-findings.md` to `save` unconditionally, and that file only exists after a finding, so `git add` fails on the missing path and the run's closing log line is never committed → use the same `[ -f … ]` guard as line 194. (from: across jobs)

## Open questions

- c2: "Shape Race's round is not recorded" — not a bug: `bench.sh collect_session` stops the round with `POST /game/stop`, which the recorder treats as an abandoned round (M14 N1, `session_recorder.dart`); leave it, and say so in the report. Suggested answer: keep as is.
- c1: Wi-Fi reachability from another device was never tested. Suggested answer: the owner runs `tools/stream.sh url` from a phone before gate 1 item 1 is called met; until then it is untested.
- p1 Q4 / c2 brief item 8: the resources p95 column. Suggested answer: add it (see the finding above); it is a table change, not a design change.
- p1: `stream_send` is "not measured" (no tracer record for a sink element). Suggested answer: accept `pipelineMs` + `stream_network` for now, as `docs/protocol.md:348` already explains, and revisit only if the bench needs to split encode from send.
- c2 §7: the 10 000 kbit/s pin is ignored (19.9 Mbit/s measured on Arena). Suggested answer: fix or drop the encoder property in `streaming/entrypoint.sh`, and stop calling it "pinned" in the run table until then.
- a2: automation-driven sessions are marked `simulated` and filtered out of uploads (`stats_service` upload filter). Suggested answer: keep them out — they are measurements, not play.
- Across jobs: was `tv_test_app/linux/` (generated runner, analyzer-skipped) meant to be committed? Suggested answer: yes, it is the container's build target; keep it.
- The gate itself: 203 ms vs "under 80 ms". Suggested answer: M15 was a measurement gate; the latency work belongs in the next brief, not in this fix batch.

## Numbers against targets

- Gate 1 item 3 "a press reaches the screen in under 80 ms": **203 ms median, p95 323, max 463, n 114** (c2 §6). Miss, and the true phone figure is worse by the phone's own leg, which this run does not include.
- Gate 1 item 2 "all six latency stages in one report": `input` is missing (no phone or simulated input path during a round) and `stream_send` is "not measured" — five of the seven video stages and the press figure are in the report, so this item is partial.
- Gate 1 item 1 "the family plays on the TV browser with phones": untested — the bench presses through the automation interface, not a phone.
- Frame rate: one 1080p session draws 44.7 fps in the app against the capture probe's 56.9; two sessions encode 38.9 / 34.3 fps against the probe's 43–45. Both are worse, and the run says so.
- Viewer pipeline: 126 ms median for one session, of which the receiver's jitter buffer is 89 ms. Bitrate: the 10 000 kbit/s pin overshoots to 19.9 Mbit/s on Arena.
- Session summary budget (PRD "about 50 KB"): measured at 89 KB with 32 series, so a2 halved the cap to 16; the size of a full record at the new cap is not measured anywhere in the run.
- Sizes: `session.dart` 400 (limit 400, runner stop 380); every other touched `lib` file is under 300.

## Could not check

- I ran no build, test or stream myself: no distro, no Docker, no device. Every number above is quoted from the jobs' reports and result JSONs, not re-measured.
- Windows-side reachability (phone → host, browser → relay) and anything that needs the `tp-stream` distro were not exercised by me.

## Commit message

Run review M15: gate 1 missed at 203 ms, four must-fix seams

Read the six commits of the run as one change against the guidelines and
the review rules. No per-job reviews or run-findings existed, so every
finding comes from the diff. Verdict: one fix batch (4 must, 5 should,
6 could), nothing that needs a design decision from the owner.
The musts: session.dart at 400 lines, the body cap applied after the
read, and "refused whole" that is not. Gate 1's press-to-screen target
is missed at 203 ms median against under 80.

## Status row

M15 prototype reviewed (6 commits): measurements end to end, automation interface, session image and tools/stream.sh — verdict one fix batch (4 must, 5 should, 6 could); open: gate 1 press-to-screen 203 ms vs under 80, the input and send stages unmeasured, phone-on-Wi-Fi reachability untested by the owner.

## Delete

- none
