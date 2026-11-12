# M15 g1 review: the fixes and the external viewer

## Summary

Verdict: **small fixes**. Counts: **0 must, 8 should, 7 could**.
The fixes themselves hold (VBV kbits is right — gst-inspect's text is quoted; the cap stops at the first chunk
past it; the bind line clears on start, stop and rebuild and is on the shared Stats screen with tests; the
player's problem clears; the relay test moved to a script test; url says the LAN address). The weaknesses are in
the evidence and the documents around Part B:

1. `report:124` says a phone would be recorded as `phone/safari-ios`; `reporter.js:365,423` sends `kind:"browser"`
   always and `platformOf()` never returns a family or an OS (`safari`, `chrome`, `chrome-headless`, `browser`).
2. `report:151`–`152`: the received kbit/s column is shifted one row (the files say vbv1 = 2237, vbv2 = 2201).
3. `bench.sh:520` starts the viewer only for `--viewer chrome`, so `--viewer-cpus` does nothing with
   `--viewer external` — yet the pinned run (ext1) that carries the "16 ms is the rig" claim is external.

## Findings

- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:124 it says a phone would be kept as `phone/safari-ios`, but `streaming/player/reporter.js:365` hard-codes `kind: "browser"` and `platformOf()` (`:423`) returns only `edge|firefox|chrome-headless|chrome|safari|browser` → say that an external viewer is recorded as `browser/<browser name>` with no device or OS, or add the family/OS split the sentence describes.
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:151 the received-kbit/s column is one row out: `g1-vbv10.json` has 2237.1 and `g1-vbv20.json` 2201.0, but the table shows "—" for vbv1 and 2237 for vbv2 → put 2237 in the vbv1 row and 2201 in the vbv2 row.
- **should** streaming/bench.sh:520 `--viewer-cpus` is only used by `start_viewer`, which runs for `--viewer chrome` alone, so an external run accepts the flag and never applies it while the report's pinned run (ext1, "viewer 12-15") is external → refuse or warn on `--viewer external --viewer-cpus`, or say in the report and README that the operator starts the device's browser themselves.
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:17 the conclusion "~16 ms of the buffer is the rig" rests on one run each side (162 vs 146 ms, `g1-ext00.json` / `g1-ext10.json`) and is smaller than the job's own 36–44 ms run-to-run noise, and the two rows also changed the session's cpuset at the same time as the viewer's cores → say "one pair of runs, inside the noise", or repeat the unpinned run before the attribution.
- **should** docs/dev-tools.md:244 it says "a session pinned to four cores never became ready, eight did", while `g1-fixes-and-real-viewer-report.md:117` says "four cores (0-7)" never became ready and the run table pins the session to 0-11 (twelve) — and 0-7 is eight cores, not four → one corrected sentence in each file naming the core lists that failed and the one that worked.
- **should** docs/automation.md:34 it still promises that a body over 64 KB "is refused whole with a 400 that says which field to fix", but a chunked over-cap body now gets the connection closed and the client sees an `HttpException` (`packages/party_host/test/automation_server_test.dart:297`) → say a body that declares its length gets the 400 and a chunked one may only see the close.
- **should** packages/party_host/lib/src/automation/automation_server.dart:84 the successful-bind `onStartState?.call(null)` has no test that fails without it (the rebuild test is satisfied by `automation_providers.dart:184`'s microtask, the stop test by `stop()`), and `start()` (`:72`) returns early while `_startError` is set, so no provider path ever binds twice → delete the line or test it through a server stopped after a failure and started again.
- **should** docs/briefs/m15/STATUS.md:11 the f1-commit note the brief inherited from `docs/briefs/m15/fix1/REVIEW.md:16` ("f1's commit carries t1's test file", note it in STATUS) is in no STATUS line and in no "Not done" line of the g1 report → add one clause to the g1 entry.
- **could** streaming/player/reporter.js:1 the file is 451 lines, 22 more than before this job, past §3's 400-line limit and listed by `fix1/REVIEW.md:31` for splitting when next touched → move `platformOf`/`postJson`/`readHostStages` (the tail from `:422`) into `stats.js` or a small `host-stats.js`.
- **could** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:175 "Not done" lists four items, but the could findings it skipped (`fix1/REVIEW.md:30` stream_ingest's refusal, `:31` the over-400 files beyond the two scripts) appear nowhere → list them under "Not done" as the brief asks.
- **could** packages/party_host/test/automation_start_error_test.dart:10 the `until` helper polls with `Future.delayed(5 ms)` against a `Stopwatch` cap, which §9's "no real time in tests" rules out → hand `onStartState` a `Completer` and await it.
- **could** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:208 the self-check says the error line "fits at 852×393 — `screen_fit_test.dart`", but that test (`packages/party_host/test/screen_fit_test.dart:139`) pumps `StatsScreen` without the line → add the line to that pump or drop the claim.
- **could** packages/party_host/lib/src/automation/automation_body.dart:17 the dartdoc says a script that sends past the cap "still hears the refusal", which the test at `automation_server_test.dart:297` contradicts → say the answer may be lost to the close, as the test does.
- **could** streaming/player/relay_test.py:112 the "the page's own files are served" check uses `any(...)`, which never asks for `/metrics.js` once `/player.js` answers 200, and `body` at `:110` is unused → check both files, and call the responses without binding them.
- **could** streaming/bench.sh:538 the viewer wait runs session by session, so `--sessions 2 --viewer external` can wait six minutes against the "up to 3 minutes" the report and `docs/dev-tools.md:244` promise → wait for all sessions inside one 180 s loop.

## Decisions to confirm

- **The VBV unit against the brief's ×1000.** The brief said pass `kbits * 1000`; the job kept kbits because `gst-inspect-1.0`'s own text says kbits. The evidence (the quoted description, and a 167 Mbit buffer being no bound) supports the worker, but this is a direct deviation from an instruction and Claude should say it stands.
- **A refused body is not drained, so a chunked client may not see the 400.** Reasonable, but it is a wire behaviour change (a client gets a close, not an answer) and the two documents above still describe the old one.
- **The external bench starts the round before it waits** and gives up at 180 s per session. Sound for the host's `accepted: false` drop; note the per-session timeout above.
- **Session pinning to 0-7 was abandoned after 90 s** and the run took 0-11. The numbers in the two documents disagree (see Findings); the decision is the owner's if 4-core pinning should be retried.
- **The bind error line sits in the shared `StatsScreen` above an `Expanded`** and is duplicated on the TV's latency screen. Fine, but it means two screens can show the same failure.

## Could not check

- `git diff 5f94cdc4..5b2a040f` (the sandbox refuses git), so "only the allow list was written" and the claim about `site/shots/*.png` were read, not verified.
- Any test run: `packages/party_host/.dart_tool/package_config.json` is absent and resolving it needs `pub get`, which the rules forbid. The "415 host, 463 phone, tv" counts and "16 ok lines" in the distro are the worker's.
- `gst-inspect-1.0`'s output (no distro access here): the kbits description is taken from the report and the README, which agree.
- The relay script test and the eight bench runs: `bash -n` passes on the three scripts here, but nothing was executed.

## Commit message

Review: g1's fixes hold; its external-viewer evidence needs four fixes

The fixes are as reported: the cap stops at the cap, the bind line clears on
start, stop and rebuild and is on the shared Stats screen, the player's problem
clears, the relay test moved to a script test, and url names the LAN address.
The review finds eight shoulds, all in the report and docs around Part B: the
viewer-kind sentence describes a split the code does not make, the received
kbit/s column is one row out, --viewer-cpus is inert with --viewer external so
the pinned run does not prove what it claims, the "16 ms is the rig" number is
inside the noise, dev-tools and the report disagree on the cores, and the
over-cap body's 400 is no longer promised by the code. Seven coulds.

## Status row

- **g1 review done:** 0 must, 8 should, 7 could; the fixes verified against the code, the Part B evidence and its documents need the four corrections above; **open:** Claude to rule on the kbits decision and the report/doc fixes.

## Delete

- none
