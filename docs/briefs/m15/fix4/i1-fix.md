job: M15 i1: the fix3 review's must and shoulds (docs/briefs/m15/fix3/REVIEW.md): the frame-callback loop in the player, and report and doc corrections
pub: no
stop: after it.
read: docs/briefs/m15/fix3/REVIEW.md ("Findings" and "Numbers against targets" only) · then only the files and lines each finding names
decide: low-usage mode: never stop for a question. Make the safest choice that fits the design and list each under "Decisions" with one line of why. Stop only if the job truly cannot be done; then say why under "Blocked".

A short job: aim for under 100 turns. Claude verified the must and the first should; do the **must**, every **should**, and only the **could** items named below, as REVIEW.md writes them, with these rulings:

1. **`streaming/player/reporter.js`**: keep the handle that `requestVideoFrameCallback` returns (both calls) and cancel it in `stop()` with `cancelVideoFrameCallback` when the browser has it; `onFrame` also returns at once when the reporter is stopped. Do not split the file in this job.
2. **`docs/briefs/m15/fix3/h1-2-run-report.md`**: restate the answer from the data. The lowest pinned run's buffer is 144 ms (p2, total n = 4, mark it), the unpinned baselines 220–226 ms; the pinned repeats differ by 49 ms and the pinned probe is 32 ms above its baseline. So the honest sentence is: "pinning may cut the buffer by up to about 76 ms (220 → 144) but this PC's run-to-run spread (49 ms) is too large to say; a real device must answer it". Remove "190–230 ms floor" and "at most ~25 ms" everywhere. Give the buffer's share as 80–92 %; say the other stages held at 1080p60 and that l1's encode (15) and decode (2) fell with the load; "inside the noise" for g1's 16 ms; say b1's cpuset line is missing and why; add n beside any cell with fewer than eight samples; add the five-line Self-check. Shorten the Summary to the table (five runs; the probe pair as a footnote, labelled "no game loop") and the one answer sentence; move the rest down.
3. **`docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md`** :170 and :186 as written in the findings.
4. **`docs/automation.md:34`**: the host decides from the declared length without reading the body; the client sees the 400 once it has sent the body.
5. **`docs/briefs/m15/fix3/h1-1-fix-report.md:30`**: the guard is covered at unit level (`automation_server_test.dart:324`); only the server-level path is not.
6. **`packages/party_host/test/automation_api_test.dart:219`**: drop the two `hasScheduledFrame` expectations, keep the release assertions.
7. Coulds to do: the "above"→"below" comment (`automation_server_test.dart:311`); `relay_test.py:112` name both files and drop the unused variable; one message and one exit code (2) for the `--viewer-cpus` with `--viewer external` refusal in `tools/stream.sh` and `streaming/bench.sh`.
8. Add a section "M15 streaming" to `docs/code-health.md` (create the file if missing) listing the coulds left alone, one line each: `reporter.js` 460 lines, `bench.sh` 561, `tools/stream.sh` 626 (split each); `kindOf` defined twice (reporter.js, stats.js); `automation_server.dart:84` dead `onStartState?.call(null)`; the bench should record the viewer's own CPU; one viewer row per run.

tests: no new test file. All existing suites pass; `bash -n` on both scripts.

in the report: start with `## Summary` (at most 15 lines): each finding by file with done / not done, decisions. Nothing else needed but the Self-check (docs/review-rules.md part A, items 1–5, one line each).
rules: no lib file you touch may end over 380 lines · no function over 60 lines · scripts pass `bash -n` · write only inside this job's folder · change no measured number: correct only the words around them · leave no scratch file behind in the repository
allow: docs/briefs/m15/fix4/i1-fix-report.md · docs/briefs/m15/fix3/h1-2-run-report.md · docs/briefs/m15/fix3/h1-1-fix-report.md · docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md · docs/automation.md · docs/code-health.md · streaming/player/reporter.js · streaming/player/relay_test.py · streaming/bench.sh · tools/stream.sh · packages/party_host/test · tv_test_app/test/stream_tool_test.dart
check: format analyze host tv
report: docs/briefs/m15/fix4/i1-fix-report.md
