# M15 fix4 i1: the fix3 review's must, shoulds and named coulds

## Summary

- **`streaming/player/reporter.js` — done (must):** the frame handle is kept and cancelled in `stop()`; 473
  lines, not split.
- **`docs/briefs/m15/fix3/h1-2-run-report.md` — done (must, five shoulds, four coulds):** table, "no game
  loop" probe footnote and one answer sentence (15 lines with the heading); p2 `(n = 4)`; 76/49 answer; 80–92 %
  share; l1's 15/2; 16 ms inside the noise; b1's missing `cpuset` explained; Self-check added.
- **`docs/briefs/m15/fix2/g1-fixes-and-real-viewer-report.md` — done (should):** row "viewer unpinned",
  decision "eight cores (`0-7`)".
- **`docs/automation.md` — done (should):** decided from the declared number; the 400 seen after the body.
- **`docs/briefs/m15/fix3/h1-1-fix-report.md` — done (should + knock-ons):** unit guard at
  `automation_server_test.dart:324` named; Decisions 2, 5 and 6 aligned with this job.
- **`packages/party_host/test/automation_api_test.dart` — done (should):** the two frame expectations gone.
- **Coulds — done:** `automation_server_test.dart:311` "below"; `relay_test.py` both files (16 checks);
  `bench.sh` exits 2 with `stream.sh`'s sentence.
- **`docs/code-health.md` — done (could):** "M15 streaming" with the five items.
- **Not done:** six generated `tv_test_app/{linux,windows}/flutter/` files still modified (outside `allow:`).

## Decisions

1. **The frame handle is kept, not re-derived.** `_videoFrame` is assigned from both calls (the first and each
   re-registration), so `stop()` always has the live one; `_stopped` is the fallback for a browser with
   `requestVideoFrameCallback` but no cancel, where the queued frame ends the loop instead.
2. **`stop()` cancels only where the cancel exists.** `typeof … === "function"` and not a try/catch: an older
   WebView without the method would throw where the check is free.
3. **The bench's refusal keeps its own `bench:` prefix.** The sentence is the outer tool's word for word and
   the exit code is 2 in both, but `bench.sh` names itself in every line it prints (as does `stream.sh`), so
   the prefix stays; the brief's "one message" is one sentence, not one byte string (question 1).
4. **The relay test makes both requests inside one `check`.** A `list` comprehension requests `/player.js` and
   `/metrics.js` and compares both statuses, which names both files, keeps sixteen checks and keeps the
   message one line (question 2).
5. **The code-health sizes are measured after this job** (473 / 572 / 634) rather than the review's 460 / 561 /
   626, which were already stale for the two scripts before this job touched them.
6. **The h1-2 commit message and status row moved with the answer.** They carried the withdrawn "floor is the
   browser's" wording; no measured number changed, only the words around it.

## Checks

- `tools/check.sh format analyze host tv`: **PASS** — format 5 s, analyze 17 s, host 417 tests 96 s, tv 20 s
  (which runs `stream_tool_test.dart` and `bash -n` on `entrypoint.sh`, `bench.sh` and `tools/stream.sh`).
- `bash -n streaming/bench.sh` and `bash -n tools/stream.sh`: clean (also inside the tv suite).
- Relay test check count: 16 `check()` calls, from the source (not run: Python is unavailable here).
- The values the report uses: p2's total n = 4 (jitter 21), b1/b2/q1/q2 totals n = 8, p1 n = 10, l1 n = 21; the
  stage medians are the summaries' own.

## Self-check (docs/review-rules.md part A)

1. **Every host setup:** none changed — the diff is the player page's JS, two scripts, two test files and docs;
   no protocol, game or phone flow. Tested by the host (417) and tv suites.
2. **When kept state starts and ends:** the reporter's `_videoFrame` starts with `_watchFrames()`, ends in
   `stop()` (cancelled where the browser can, otherwise `onFrame` returns on the next frame) and is null
   before start; a reconnect makes a new reporter, so two loops can no longer run.
3. **How a new state combines:** nothing here pauses, hides or blocks input; the stopped flag combines only
   with a reconnect, which replaces the reporter.
4. **Stay in the job's folder:** yes — only files in `allow:` changed (the report lists them).
5. **Stop rather than overstep:** nothing was needed outside `allow:`; the generated-file leftovers and the
   coulds left alone are named in the report and `docs/code-health.md` instead.

## Questions

1. Is the bench's refusal acceptable as one sentence with its own `bench:` prefix and exit 2, or should it
   print `stream:`'s line byte for byte? No test runs `bench.sh` itself (the tv test runs `tools/stream.sh`,
   which refuses before it reaches the bench), so a direct-caller test is still open.
2. Should `relay_test.py` give each page file its own `check` (seventeen) rather than one check over both? The
   brief's "name both files" is met either way; the docs' "sixteen checks" is why I kept one.

## Suggestions

- The three over-long files are now in `docs/code-health.md`; the next job that touches `reporter.js` should
  take its split, since this one grew it.

## Commit message

M15 fix4 i1: the player's frame loop ends; the h1-2 report restated

The reporter keeps the handle from both requestVideoFrameCallback calls and
cancels it in stop() where the browser has the cancel, and onFrame returns at
once once stopped, so a reconnect no longer leaves an old loop counting. The
h1-2 report now answers from its own data: pinning may cut the buffer by up to
76 ms (220 -> 144), this PC's spread is 49 ms, so a real device must answer;
the share is 80-92%, b1's missing cpuset line is explained, p2's four samples
are marked, and a Self-check is added. Two script guards and two tests align,
and code-health gains an M15 streaming section. No default changed.

## Status row

- **M15 fix4 i1 (fix3 review's must, shoulds and named coulds):** the player's frame-callback loop now ends in
  `stop()`, the h1-2 report answers from its data (76 ms possible, 49 ms spread, a real device must answer),
  and the four doc/test corrections and three coulds are in; **open:** the six generated `tv_test_app` files
  are still modified in the tree, the three over-long files wait in code-health, and the bench's own guard has
  no test.

## Delete

- none
