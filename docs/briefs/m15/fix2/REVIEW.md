# M15 fix2 run review: the g1 change as one

## Summary

Verdict: **one fix batch**. Counts: **0 must, 10 should, 12 could**.
The run holds where the earlier review said it did: the body cap stops at the cap, the bind line clears on a
rebuilt server and on `stop()`, the player's problem clears, the relay test moved to `relay_test.py`, `url`
names the LAN address. What is left is one new defect and a group of claims the documents make about evidence
that cannot support them.

1. `reporter.js:131`: the new animation-frame fallback is never cancelled, so a reconnect adds a frame loop.
2. `bench.sh:520`: `--viewer-cpus` is inert with `--viewer external`, yet the report's pinned run (ext1) is
   external — the "viewer 12-15" row has no mechanism behind it.
3. `docs/automation.md:34` still promises a 400 for a body over 64 KB, the code now closes the connection for a
   chunked one, and the server-level test of a declared-too-long body was deleted (S3 below).
4. The report's own numbers: the received-kbit/s column is one row out (2237 belongs to vbv1, not vbv2) and
   the `phone/safari-ios` example describes a split the reporter does not make.
5. `streaming/README.md:192` and `docs/dev-tools.md:244` say four cores failed and eight worked; the report
   (`:117`) says 0-7 (eight) failed and twelve worked.

Owner-only questions: does the kbits reading stand against fix1's `must` (fix1/REVIEW.md:15)? May an over-cap
client see the close instead of the 400? The rest of the open questions have safe answers I would pick.

## Findings

- **should** streaming/player/reporter.js:131 the fallback for a browser without `requestVideoFrameCallback` starts a `requestAnimationFrame` loop that `stop()` (reporter.js:120) never cancels, so each reconnect (player.js:185) leaves another loop counting frames and reading the picture at 60 Hz → keep the loop's handle and cancel it in `stop()`. (from: g1-fixes-and-real-viewer)
- **should** streaming/bench.sh:520 `--viewer-cpus` is read only inside `start_viewer` (:240), which runs for `--viewer chrome` alone (:520), so `--viewer external --viewer-cpus 12-15` (docs/dev-tools.md:220) is accepted and does nothing, while report:156 calls g1-ext1 "viewer 12-15" → refuse or warn on the pair, and say the operator pins their own browser. (from: g1-fixes-and-real-viewer)
- **should** docs/automation.md:34 still promises a body over 64 KB is "refused whole with a 400", but automation_body.dart:22 throws before reading and a chunked body now ends with the connection close (automation_server_test.dart:299 expects `HttpException`), and the only server-level test of a declared-too-long body was deleted from automation_server_test.dart:282 → put that test back and say which of the two a client sees. (from: g1-fixes-and-real-viewer)
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:151 the received-kbit/s column is one row out: g1-vbv10.json:121 is 2237.1 and g1-vbv20.json:121 is 2200.95, but the table shows "—" for vbv1 and 2237 for vbv2 → 2237 in the vbv1 row, 2201 in the vbv2 row. (from: g1-fixes-and-real-viewer)
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:124 says a phone would be kept as `phone/safari-ios`, but reporter.js:365 hard-codes `kind: "browser"` and `platformOf` (reporter.js:423-431) returns browser names only (`safari`, `chrome-headless`, …) → say `browser/safari` with no OS, or add the family/OS split the sentence describes. (from: g1-fixes-and-real-viewer)
- **should** streaming/README.md:192 and docs/dev-tools.md:244 say a session pinned to four cores never became ready and eight did, while report:117 says 0-7 (eight cores) failed and the run used 0-11 (twelve) → one corrected sentence in each file naming the lists that failed and the one that worked. (from: g1-fixes-and-real-viewer)
- **should** packages/party_host/lib/src/automation/host_automation.dart:181 the added `SchedulerBinding.instance.scheduleFrame()` fixes a press that stays held on a screen that draws nothing, but no test fails without it (guideline §9; `HostAutomation` has no test file) and report:5 says every Dart change has one → a widget test that presses twice without pumping a frame. (from: g1-fixes-and-real-viewer)
- **should** packages/party_host/test/automation_start_error_test.dart:10 `until` polls with `Future.delayed(5 ms)` against a `Stopwatch` and returns silently on timeout — the run's only real-time wait, against guideline §9 → hand the test a `Completer` fed by `onStartState` (or await the notifier). (from: g1-fixes-and-real-viewer)
- **should** docs/dev-tools.md:246 and streaming/README.md:174 say `relay_test.py` has "fifteen checks" while the file has 16 `check(` calls (relay_test.py:111-157) and report:73/75 say 16 → say sixteen. (from: g1-fixes-and-real-viewer)
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:17 puts "~16 ms of the buffer is the rig" on one run each side (g1-ext00.json / g1-ext10.json), below the job's own 36–44 ms noise (report:145), with the session's cpuset changed at the same time as the viewer's cores → say "one pair of runs, inside the noise" or repeat the unpinned run before attributing. (from: g1-fixes-and-real-viewer)
- **could** streaming/player/reporter.js:1 is 451 lines, past §3's 400 hard limit (it was 429 when fix1/REVIEW.md:32 asked for the job that next touches it to split it, and this job added 22); tools/stream.sh (626), streaming/bench.sh (561), streaming/entrypoint.sh (425) and packages/metrics/bin/stream_sampler.dart (445) are over too → move reporter.js's tail (`platformOf`, `postJson`, `readHostStages`, from :422) to a small module and plan the script splits. (from: across jobs)
- **could** packages/party_host/lib/src/automation/automation_server.dart:84 `onStartState?.call(null)` after a successful bind can never clear anything, because `start()` returns early while `_startError` is set (:72), and no test fails without it → delete it (automation_providers.dart:184 already clears on a rebuild) or let `start()` retry so it is reachable. (from: g1-fixes-and-real-viewer)
- **could** streaming/player/reporter.js:298 and streaming/player/stats.js:51 define the same `kindOf` helper twice, each beside its own copy of the inbound-rtp parse → one small stats-parsing module. (from: across jobs)
- **could** packages/party_host/lib/src/ui/stats_screen.dart:90 shows the bind line while tv_test_app/lib/src/ui/latency_screen.dart:34 still watches the same provider, so one failed bind appears on two screens and A3 has two owners for one line → keep the shared Stats screen and make the TV screen point at it, or say in code-health why both stay. (from: across jobs)
- **could** streaming/player/relay_test.py:112 `any(...)` stops at `/player.js`, so `/metrics.js` is never requested, and `body` at :110 is unused → ask for both files by name and drop the variable. (from: g1-fixes-and-real-viewer)
- **could** streaming/bench.sh:538 the viewer wait runs session by session, so `--sessions 2 --viewer external` can wait six minutes against the "up to three minutes" of docs/dev-tools.md:244 and streaming/README.md:188 → wait for all sessions inside one 180 s loop. (from: g1-fixes-and-real-viewer)
- **could** streaming/bench.sh:536 starts the round before waiting up to 180 s for the viewer, so a viewer slower than the round is timed against the results screen → start the activity again once the viewer has registered. (from: g1-fixes-and-real-viewer)
- **could** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:209 claims the line "fits at 852×393 — `screen_fit_test.dart`", but that test (packages/party_host/test/screen_fit_test.dart:139) pumps `StatsScreen` without the line → pump it with the line or drop the claim. (from: g1-fixes-and-real-viewer)
- **could** packages/party_host/lib/src/automation/automation_body.dart:18 says a script that sends past the cap "still hears the refusal", which automation_server_test.dart:299 contradicts for a chunked body → say the answer may be lost to the close. (from: g1-fixes-and-real-viewer)
- **could** docs/briefs/m15/STATUS.md:11 says `bench --viewer external` "now times a phone, tablet or TV", but both external runs were a desktop Chrome (g1-ext00.json:40, `"kind": "browser"`) and the same file's "Next" still asks for a real device → say "proven with a desktop Chrome; a real device next". (from: across jobs)
- **could** docs/briefs/m15/STATUS.md:8 does not record that f1's commit `5ffd764` carries t1's `stream_tool_test.dart` and fails `tools/check.sh tv`, which fix1/REVIEW.md:16 asked STATUS to note (the relay tests have since moved, so the tree is fine) → add one clause or drop the request. (from: across jobs)
- **could** packages/party_host/lib/src/automation/stream_ingest.dart:24 the refusal for a `viewer` that is neither a word nor an object is still not recorded as a decision in any report (fix1/REVIEW.md:30) → add it to the g1 report's Decisions. (from: across jobs)

## Open questions

- Does the kbits reading stand against fix1/REVIEW.md:15's `must` (pass `kbits * 1000`)? — Safest: yes, 167 stays 167; `gst-inspect` says kbits and 167 000 kbits is no bound; record it as a decision.
- May a chunked over-cap client see the connection close instead of the 400? — Safest: yes, keep the close, correct `docs/automation.md:34` and restore the declared-length test.
- Should the viewer wait stay 180 s per session, six minutes for two? — Safest: one 180 s wait for all sessions.
- Is session pinning 0-7 worth a retry, or does 0-11 stand? — Safest: 0-11 stands; correct the two docs' core lists.
- Is the bind line kept on both the Stats screen and the TV latency screen? — Safest: keep both for now; one provider, one line.
- Should `--viewer external --viewer-cpus` be refused or warned? — Safest: warn, and say the operator pins their own browser because a device cannot be pinned from here.
- Is a real-time `until` acceptable for an OS bind (test-only)? — Safest: no; use a `Completer`.
- Is the "16 ms is the rig" number kept as it is? — Safest: keep the number, label it one pair of runs inside the noise.
- Should STATUS note f1's commit carrying t1's test file? — Safest: one clause; it is history now that the relay tests moved.
- Is the `stream_ingest` refusal a decision to record? — Safest: yes, one line in the g1 report.

## Numbers against targets

- **Gate 1 is press-to-screen under 80 ms** (docs/design/streaming-roadmap.md, quoted in STATUS.md:9): g1's probe medians were 223–257 ms (best 223, vbv3; the ext rows 246 and 257), 143–177 ms over; STATUS.md:11 puts it at "154 ms away" from t1's 234.
- **One session is 1080p60** (STATUS.md:27): g1 delivered 55.8–58.0 fps mean (g1-b0b0.json:115 is 55.77, g1-ext10.json:115 is 58.0), under 60.
- **Run-to-run noise is 36–44 ms** (report:145): the one-frame VBV's 25 ms mean saving (report:158) and the "16 ms is the rig" (report:17) are both inside it; the first is treated as a switch, the second is not.
- **The keep-alive's five minutes** (t1's brief) is still not shown (report:24, report:182).
- **The viewer wait is "up to three minutes"** (docs/dev-tools.md:244, streaming/README.md:188): it is three minutes per session, so six for `--sessions 2` (bench.sh:538).
- **The relay test's count**: 16 checks in the file, "fifteen" in both docs.

## Could not check

- No Dart test was run: `packages/party_host/.dart_tool/package_config.json` is absent and `pub get` would install, so the 415 host / 463 phone / tv suite counts, the new tests and the "16 ok lines" in the distro are the worker's word. `dart format` (10 files, 0 changed) and `bash -n` on the five scripts pass here.
- `gst-inspect-1.0`'s text (no distro here): the kbits reading is taken from streaming/README.md:65 and report:38-41, which agree.
- Any bench run or `relay_test.py` run: the eight summaries were read for the numbers cited (bitrate, fps, stage medians), not executed.
- `tools/run-jobs.sh:53` `usage()` reads field 10 of `~/.thumbparty/flash-usage.tsv`, whose format I have not seen, so the new "N turns, M min" log line is unchecked.
- `docs/briefs/tools/research-lean-agents*.md` (new in the range, outside the brief's read list) were not reviewed; `site/shots` churn claims cannot be seen in the diff.
- The report's sandbox claims (the detached keep-alive, the real device) cannot be verified from here.

## Commit message

Review: g1's fixes hold; the external-viewer evidence needs a batch

No must and ten shoulds. The new requestAnimationFrame fallback in the player's
reporter is never cancelled, so every reconnect leaves a frame loop behind.
--viewer-cpus does nothing with --viewer external, so the pinned ext1 run has no
mechanism behind it. docs/automation.md still promises a 400 for a body over
64 KB and the server test for a declared-too-long body was deleted. The report's
received-kbit/s column is one row out and its phone/safari-ios example is wrong;
README and dev-tools disagree with it on the core list. Twelve coulds, mostly
report and doc corrections around the external viewer.

## Status row

- **g1 reviewed (fix2 run review):** 0 must, 10 should, 12 could; the body cap, the bind line, the player's problem and the relay selftest hold as reported; **open:** the reporter's uncancelled frame loop, `--viewer-cpus` inert with `--viewer external`, `docs/automation.md`'s 400 promise, four report/doc corrections and the fifteen-vs-16 check count before the external-viewer numbers are trusted; the VBV kbits decision is Claude's to confirm.

## Delete

- none
