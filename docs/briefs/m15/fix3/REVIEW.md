# M15 h1 fix3 run: review

## Summary

Verdict: **one fix batch**. Counts: **1 must, 9 should, 12 could**.

- The run's headline number does not survive its own data: h1-2's "190–230 ms floor, ~25 ms rig share" is
  undercut by its p2 (144 ms jitter, 181 ms total), and nothing in the report derives 25 ms.
- The reporter fix covers only the animation-frame fallback; the `requestVideoFrameCallback` loop Chrome and
  Safari take still re-arms per reconnect and `stop()` never cancels it.
- Two g1 report corrections the brief named are still unfixed (:170's "viewer 12-15" row and :186's four/eight
  wording), so the run whose pinning was withdrawn still prints as a pinned run.
- `docs/automation.md:34` promises a declared-too-long body is "answered at once … before any of it is read",
  which the same job measured a client cannot see; the body.dart comment it wrote says otherwise.
- The h1-1 report's "nothing can make it" is false (`automation_server_test.dart:324` covers the throw), and
  the new widget test's two `hasScheduledFrame` expectations hold with or without the call they document.
- Owner-only questions: does the rVFC loop go in this batch; is a probe pair with no game loop the press
  answer; should the bench record the viewer's own CPU.

## Findings

- **must** docs/briefs/m15/fix3/h1-2-run-report.md:23 (and :42) calls the buffer's floor "190–230 ms" and any rig share "at most ~25 ms" while its own p2 is 144 ms jitter and 181 ms total (`h1-2/p2/h1p20.json`, jitter n=21, total n=4), 46 ms under that floor → restate the floor from the lowest run (144 ms) and derive the share (220 − 144 = 76 ms) or drop the number. (from: h1-2-run review)
- **should** streaming/player/reporter.js:158 the `requestVideoFrameCallback` loop re-registers itself (:158) and `stop()` (:121) cancels only `_animationFrame` (:128), so on the browsers that have the callback every reconnect leaves the old reporter counting frames and reading the picture once per displayed frame → keep the handle from :158/:160 and call `this._video.cancelVideoFrameCallback(handle)` in `stop()`. (from: h1-1-fix review)
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:170 the run table still says `g1-ext1 external, viewer 12-15, session 0-11`, while the job's own :16 and :125 say that pin did nothing → relabel the row `g1-ext1 external, viewer unpinned, session 0-11`. (from: h1-1-fix review)
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:186 the decisions bullet reads "Pinning the session to four cores was abandoned: `0-7` (eight cores) …", the wording the brief asked to fix → say "Pinning the session to eight cores (`0-7`) was abandoned". (from: h1-1-fix review)
- **should** packages/party_host/test/automation_api_test.dart:219 the test added for fix2/REVIEW.md:32 passes with or without `host_automation.dart:181`'s `scheduleFrame()`, and its two frame expectations (:222, :224) hold either way → keep the release assertions (:225, :228) and drop the two `hasScheduledFrame` expectations that prove nothing. (from: h1-1-fix review)
- **should** docs/briefs/m15/fix3/h1-1-fix-report.md:30 says the restored declared-cap test "does not fail without the early `contentLength > limit` throw, and nothing can make it", but `automation_server_test.dart:324` fails the moment that throw goes → say the guard is covered at unit level and only the server-level path is not. (from: h1-1-fix review)
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:26 "85–88 % of `stream_total` in every round" is contradicted by the same table and the fetched files: p2 is 144/181 = 80 %, p1 193/229 = 84 %, l1 200/218 = 92 % → give the measured range (80–92 %) or the ratio per run. (from: h1-2-run review)
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:27 "the other stages are stable across all runs (encode 29 … decode 4 …)" is false for l1, whose encode median is 15 and decode 2 (`h1-2/l1/h1l10.json`), as its own Decision 4 (:104) says → say the stages held at 1080p60 and that l1's encode and decode fell with the lower load. (from: h1-2-run review)
- **should** docs/briefs/m15/fix3/h1-2-run-report.md:3 the Summary runs from :3 to :28 (21 non-blank lines, seven table rows, two analysis paragraphs) against the brief's "at most 15 lines: the five runs in one table, and one sentence answering" → keep the five run rows with the probe pair as a footnote and one answer sentence, and move the rest to "The question, read out". (from: h1-2-run review)
- **should** docs/automation.md:34 says a declared-too-long body "is answered at once … before any of it is read", while the job measured that a client which declares the length and sends nothing gets no answer and an open socket (h1-1-fix-report:27) → say the host decides from the declared number without reading and the client sees the 400 once it has sent the body, matching `automation_body.dart:14`. (from: h1-1-fix review, as a could)
- **could** packages/party_host/test/automation_server_test.dart:311 the comment says "unlike the chunked body above", but the chunked test is below it (:318) → say "below". (from: h1-1-fix review)
- **could** streaming/player/reporter.js:1 is 460 lines, over §3's 400-line hard limit (fix2/REVIEW.md:36 named it for the next job that touches it; this run added nine), and `streaming/bench.sh:1` (561) and `tools/stream.sh:1` (626) are over it too and this run added 8 and 10 → split `reporter.js`'s helpers from :432 into a module and the two scripts into their own job. (from: across jobs)
- **could** tv_test_app/linux/flutter/generated_plugin_registrant.cc:1 and the five other generated files under `tv_test_app/{linux,windows}/flutter/` are left modified in the working tree (line endings only) → restore them, so a `git add -A` does not carry them. (from: h1-1-fix review)
- **could** tools/stream.sh:178 and streaming/bench.sh:147 refuse the same `--viewer-cpus`/`--viewer external` pair with exit 2 and exit 1, and only the outer one is tested (`tv_test_app/test/stream_tool_test.dart:49`) → keep both guards but give them one message and one exit code and one test. (from: h1-1-fix review, decisions)
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:14 p2's total (181 / 287) rests on n = 4 samples where the jitter cell has n = 21 and the other runs 8–21 (`h1-2/p2/h1p20.json`) and the table shows no n → add n per cell or mark the cells with fewer than eight samples. (from: h1-2-run review)
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:43 "g1's own pair (162 → 146) is the same size as the noise measured here" — this run's own spread is 49 ms (p1/p2) and 32 ms (q1/q2), so 16 ms is inside the noise → say "inside the noise". (from: h1-2-run review)
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:87 "the others really are not [pinned]" rests on b1 having a docker-inspect line it does not have (`h1-2/evidence.txt:14` records the wrong container name, so only its 0-15 Chrome affinity is shown) → say b1's cpuset line is missing and why. (from: h1-2-run review)
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:111 the report has no Self-check section, which review-rules part A and guidelines §11 ask of every job, so A4 (folder) and A5 (stop) are unstated → add the five one-line answers. (from: h1-2-run review)
- **could** streaming/player/relay_test.py:112 `any(...)` stops at `/player.js`, so `/metrics.js` is never requested, and `body` at :110 is unused; the h1-1 report's reason for leaving it (h1-1-fix-report.md:40, "adding both adds a seventeenth check") is wrong, since naming both keeps sixteen → name both files and drop the variable. (from: h1-1-fix review, decisions)
- **could** packages/party_host/lib/src/automation/automation_server.dart:84 `onStartState?.call(null)` after a successful bind can never clear anything (`start()` returns early while `_startError` is set, :72) and no test fails without it → delete it (automation_providers.dart clears on a rebuild) or let `start()` retry. (from: fix2 findings, still open)
- **could** streaming/player/reporter.js:307 and streaming/player/stats.js:51 define the same `kindOf` helper twice, each beside its own copy of the inbound-rtp parse → one small stats-parsing module. (from: fix2 findings, still open)
- **could** docs/briefs/m15/fix3/h1-2-run-report.md:49 records only that the bench came from the copy at `/work/flash-20261112-000014-3492`, with no revision and no run through `tools/stream.sh`, so `docs/dev-tools.md:221`'s pinned example has never been exercised end to end → record the synced commit in the report and run one pinned round through the outer tool. (from: h1-2-run review, decisions)

## Open questions

- The declared body's wording (h1-1-fix question 1): say the host refuses from the declared number without reading and the client sees the 400 after sending, as `automation_body.dart:14` now does.
- The pair refused in both tools (h1-1-fix question 2): keep both refusals, since a direct bench caller needs one; align the exit codes and test the bench's guard.
- Where the rVFC loop is fixed (h1-1-fix review decision): in this batch, as the should above; it is ten lines and the same bug class.
- The kbits ruling (h1-1-fix review decision): nothing to change; the correction on fix1/REVIEW.md:15 reads right.
- The coulds h1-1 left alone (h1-1-fix report Decision 6): put them in code-health.md with an owner; none is a defect a tester hits.
- Should the bench record the viewer's own CPU (h1-2-run question 1): yes, as a small tool job; the job's utime+stime-over-2-s method from `h1-2/evidence.txt` can move into `bench.sh`.
- Four viewer rows per run (h1-2-run question 2): a job of its own before more pinning runs, since g1's runs had one row; keep Observation 1 meanwhile.
- Is the probe pair the press answer (h1-2-run review decision): yes for press only, because a round run never shows the card; label the pair "no game loop" wherever the number is quoted.
- Do the numbers stand without one run through `tools/stream.sh` (h1-2-run review decision): yes, the guard these runs don't use is the only bench change since; record the copy's revision next time.
- Hold the withdrawal of g1's 16 ms (h1-2-run review decision): yes, but only after the must above restates the floor, since 144 ms makes the share larger, not zero.
- The h1x diagnostic (h1-2-run review decision): keep it as an observation, and mark that its `ss` output was not fetched, so it is not evidence.

## Numbers against targets

- h1-2 brief, Summary "at most 15 lines": the report's is 21 non-blank lines (:3–:28).
- h1-2 brief, "the five runs in one table, and one sentence answering": seven rows plus two analysis paragraphs.
- h1-2 brief, press median and p95 per run: the five round rows show "–"; only q1/q2 carry press (218/359 and 259/363), and those runs have no game loop.
- h1-2 report :23, floor 190–230 ms and "at most ~25 ms": p2 is 144 ms of jitter and 181 ms of total; 220 − 144 = 76 ms is the share a derivation would give.
- h1-2 report :26, "85–88 % of `stream_total`": 80 % (p2), 84 % (p1), 86 % (b1, b2, q1, q2), 92 % (l1) — 80–92 %.
- h1-2 report :27, "encode 29 … decode 4 … across all runs": l1's encode is 15 and decode 2 (`h1-2/l1/h1l10.json`).
- h1-2 report :14, p2 total n = 4 against jitter n = 21; the other runs' totals have n = 7.
- h1-1 report, 417 host tests: I reran only the three changed files (25 tests, pass); `stream_tool_test.dart` reran 12, pass; format on the five changed Dart files and `bash -n` on both scripts are clean.
- Size: `reporter.js` 460 lines against §3's 400 hard limit; `bench.sh` 561 and `tools/stream.sh` 626 against the same limit.

## Could not check

- The distro: the bench's own refusal, container cleanup, the relay's sixteen checks and which revision `/work/flash-20261112-000014-3492` holds are all unreachable from here.
- No JS runtime here: `reporter.js` was read, not run, so the rVFC leak is a reading of :149–:160, not an observation.
- The new `_callDeclaring` test's behaviour without the early throw was not reproduced (that needs a lib edit, and this job changes no code); `automation_server_test.dart:324` was read, and it would fail without the throw.
- The api test's pass without `scheduleFrame()` is taken from the h1-1 report's measurement, not reproduced.
- The full host suite (417) and the full tv suite were not rerun, and `dart analyze` was not run; only the three changed host test files and `stream_tool_test.dart` were.
- The viewer CPU medians were not recomputed from the samples in `h1-2/evidence.txt`; only the table's stage and press cells were checked against the JSONs.
- `docs/briefs/m15/fix3/run-findings.md` and a `STATUS.md` in the fix3 folder do not exist.

## Commit message

M15 h1 fix batch: the run's floor, the rVFC loop, the g1 labels

The h1-2 report restates the browser floor from its lowest run (144 ms) instead of 190–230, and its ratio, stage and Summary claims match the fetched summaries. The reporter cancels its requestVideoFrameCallback loop on stop(), and the g1 report's g1-ext1 row and four/eight wording finally say the pin did nothing. The body-cap paragraph in docs/automation.md matches what a declaring client sees, the h1-1 report stops claiming nothing tests the declared cap, and the api test keeps only the release assertions. No code default and no measurement changed.

## Status row

- **h1 (fix3 run) reviewed:** 1 must, 9 should, 12 could — the h1-2 answer's floor and two Summary figures are contradicted by its own summaries, the rVFC loop and two g1 labels are still open, the declared-cap docs promise more than a client sees; **open:** restating the h1-2 floor and its derived share, the rVFC cancel, the two g1 labels, the api test's frame expectations, the h1-1 report line and automation.md's wording.

## Delete

- none
