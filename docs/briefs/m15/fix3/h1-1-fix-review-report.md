# M15 h1-1 fix: review

## Summary

Verdict: **small fixes**. Counts: **0 must, 5 should, 4 could**.

- The reporter's fix covers the animation-frame fallback only: the `requestVideoFrameCallback` loop, which
  Chrome and Safari take, still re-arms itself and is never cancelled, so a reconnect leaks it exactly as the
  finding said.
- The g1 report still labels the `g1-ext1` row "viewer 12-15" and still opens a bullet "Pinning the session to
  four cores" beside "(eight cores)" — the two corrections the brief named, left half done.
- The viewport test added for `scheduleFrame()` cannot fail without it (the report says so), so fix2's tenth
  should is open; the report's "nothing can make it" is too strong, since `automation_server_test.dart:324`
  does fail without that throw.

## Findings

- **should** streaming/player/reporter.js:158 the `requestVideoFrameCallback` loop re-registers itself (:158) and `stop()` (:121) cancels only `_animationFrame`, so on the browsers that have the callback every reconnect leaves the old reporter counting frames and reading the picture once per displayed frame → keep the handle from :160/:158 and call `this._video.cancelVideoFrameCallback(handle)` in `stop()` beside `cancelAnimationFrame`.
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:170 the run table still says `g1-ext1 external, viewer 12-15`, while the job's own :16 and :125 say that pin did nothing → relabel the row `g1-ext1 external, viewer unpinned, session 0-11`.
- **should** docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md:186 the bullet now reads "Pinning the session to four cores was abandoned: `0-7` (eight cores) …", the four/eight wording the brief asked to fix → say "Pinning the session to eight cores (`0-7`) was abandoned".
- **should** packages/party_host/test/automation_api_test.dart:212 the test added for fix2/REVIEW.md:32 passes with or without `host_automation.dart:181`'s `scheduleFrame()` (report Decision 5), and its two `hasScheduledFrame` expectations (:222, :224) hold either way → keep the release assertions, drop the two frame expectations that prove nothing, and leave the gap to code-health rather than to a test.
- **should** docs/briefs/m15/fix3/h1-1-fix-report.md:30 says the restored test "does not fail without the early `contentLength > limit` throw, and nothing can make it", but `automation_server_test.dart:324` (`readRequestBody` on an empty stream, declared over-cap) fails the moment that throw goes → correct the sentence: the guard is covered at unit level, only the server-level path is not.
- **could** docs/automation.md:34 says a declared-too-long body "is answered at once … before any of it is read", while the job measured that a client which declares the length and sends nothing gets no answer and an open socket (report:27) → say the host decides from the declared number without reading, and that the script sees the 400 once it has sent the body.
- **could** packages/party_host/test/automation_server_test.dart:311 the comment says "unlike the chunked body above", but the chunked test is below it (:318) → say "below".
- **could** streaming/player/reporter.js:1 is 460 lines, over §3's 400-line hard limit, and fix2/REVIEW.md:36 named this file for the next job that touches it; this job added nine lines → move `platformOf`, `postJson` and `readHostStages` (from :432) into a module in the phase-2 job.
- **could** tv_test_app/linux/flutter/generated_plugin_registrant.cc:1 and the five other generated files under `tv_test_app/{linux,windows}/flutter/` are left modified in the working tree (line endings only) → restore them before the next commit, so a `git add -A` does not carry them.

## Decisions to confirm

- **The reporter's frame handle:** the job fixed only the fallback path and A2/A3 speak of "the frame handle" combining with a reconnect; the rVFC path is untouched — decide whether the finding above goes to phase 2 or back to the reporter's job.
- **The declared body and the client (report Question 1):** the docs promise the 400 "at once" while the job observed the client cannot see it before it has sent the body; pick the wording before a script author reads it as a handshake.
- **The pair refused twice (report Question 2):** `tools/stream.sh:445` exits 2 for the pair and `streaming/bench.sh:146` exits 1 for the same; refusing in both is the safe choice, but only the outer one is tested (`tv_test_app/test/stream_tool_test.dart:49`).
- **Coulds left alone (report Decision 6):** `relay_test.py:112`'s `any(...)` still means `/metrics.js` is never requested, and the over-400 files grew (`reporter.js` 451 → 460).
- **kbits (ruling 1):** nothing changed in `entrypoint.sh`; the correction sits on fix1/REVIEW.md:15 and reads correctly.

## Could not check

- `docs/briefs/m15/fix3/run-findings.md` does not exist, so there were no per-run entries to weigh.
- No JS runtime here: `reporter.js` was read, not run, and `streaming/player/relay_test.py` does not load it.
- I ran only the three changed host test files (25 tests, all pass); the full 417 and the tv suite were not rerun, and `bench.sh`'s own refusal was not exercised (needs the distro).
- Whether the new viewport test fails without `scheduleFrame()` was not reproduced (that needs a lib edit); the report's measurement is taken as said.
- `bash -n` is clean on `streaming/bench.sh` and `tools/stream.sh`; `dart format --set-exit-if-changed` is clean on the five changed Dart files.

## Commit message

M15 h1-1 review fixes: the Chrome frame loop and two report labels

The reporter now cancels its requestVideoFrameCallback loop in stop(), so the
path Chrome and Safari take no longer leaks a frame loop per reconnect. The g1
report's run table stops calling g1-ext1 "viewer 12-15" and its decisions bullet
stops saying four cores beside 0-7's eight. The viewport test keeps its release
assertions and drops the two hasScheduledFrame expectations that hold without
the call, and the fix report no longer claims nothing tests the declared body
cap, which automation_server_test.dart:324 does.

## Status row

- **h1-1 fix reviewed (fix3 run):** 0 must, 5 should, 4 could; nine of the ten shoulds done as reported, the scheduleFrame test still open; **open:** the reporter's rVFC loop, two g1 report labels, the api test's frame expectations and the fix report's cap-coverage claim.

## Delete

- none
