## Summary

Verdict: **needs Claude** (review of job wave1-home, commit 20032489; line numbers are at that commit)
Counts: must 0 · should 8 · could 2
Top three:
1. The 3 s wait now starts at discovery start, not Home's first frame, and the report's reason for the listener (a Search again after a failed start shows Looking) is false when the retry fails again (phone_home_screen.dart:150-153).
2. The resume test has an unexplained second `pump()` (phone_home_screen_test.dart:183-184); the report's diagnosis does not fit the code, and the report still says the test fails while the commit has it passing (home-report.md:23, 52, 82, 86).
3. The first-host log (discovery.dart:206-209) has no test: only the string is tested.

## Findings

- **should** controller_app/test/phone_home_screen_test.dart:183-184 The resume test needs a second bare `pump()` that nothing explains; the report blames the lifecycle path, but resume and Search again both call `discoveryProvider.restart()` (controller_screen.dart:118, phone_home_screen.dart:184) → find the event order (e.g. async delivery of the discovery stream) and wait for it explicitly, or state why one pump is enough.
- **should** docs/briefs/m17/m17prep/home-report.md:23 The Summary says done and 52 and 82 and 86 say the resume test still fails (the commit draft and status row) → correct the commit draft and status row to match the committed, passing test before Claude uses them.
- **should** controller_app/lib/src/home/phone_home_screen.dart:150-153 The listener also resets the wait on the first start, so the 3 s no longer runs from Home's first frame (brief: keep 3 s from first frame), and the report's reason (a Search again after a failed start shows Looking) is false when the retry fails again: `stop()` keeps `error` (discovery.dart:151) and `_find()` returns none on error (phone_home_screen.dart:126) → decide the anchor, correct the decision text, and test a second failed retry.
- **should** controller_app/lib/src/discovery.dart:206-209 The first-host log is untested (discovery_first_host_test.dart tests only the string), so a wrong `wasEmpty` or a log on every host would pass → add a test feeding two resolved hosts and asserting one log line (inject `now` if the clock blocks it).
- **should** controller_app/lib/src/home/phone_home_screen.dart:55 The doc "True once [homeSearchWait] passed since the first frame" is now wrong, since the wait starts again on each search → say "since the latest search started".
- **should** controller_app/lib/src/home/phone_home_screen.dart:150-153 The listener resets Home's wait on the restarts from hosting.dart:67 and connect_screen.dart:187 too, and home-report.md:43 says host setups are "not touched" → correct self-check lines 1 and 3, and test the Connect-screen restart or say it is untested.
- **should** controller_app/test/home_view_test.dart:153-161 The searching-chip test runs only at 568x320 in the menu look (pumpHome defaults, lines 42-43), but rule A6 needs the TV look and the size list (line 13) → loop it over the sizes and `tv`.
- **should** controller_app/test/support/fakes.dart:240 `FakeDiscovery.restart` reads the real clock (`DateTime.now()`), against the no-real-time rule (guidelines §9) → use a fixed base time plus the restart count.
- **could** controller_app/lib/src/discovery.dart:209 `_state.startedAt` can still be the previous search's start when a host resolves inside `await discovery.start()` (set only at line 129), so the log may show a large wrong N → set `startedAt` before the await, or say why it cannot happen.
- **could** controller_app/test/discovery_first_host_test.dart:11 The test name "counts whole milliseconds, 1 ms after one millisecond" is garbled, and no sub-millisecond case checks the truncation → rename it and add a 1.9 ms case.

## Decisions to confirm

- The 3 s wait starts at the first discovery start as well as at Home's first frame (phone_home_screen.dart:150-153): the brief said keep the first-frame anchor; confirm the change.
- The listener resets on any new non-null `startedAt`, not only when the previous one was non-null (brief item 2): its stated reason does not hold on a second failed retry (finding 3).
- `FakeDiscovery.restart` also clears `hosts` (fakes.dart:241): not in brief item 4 and not in the report; it changes every test that restarts discovery with hosts.
- Hosting (hosting.dart:67) and Connect (connect_screen.dart:187) restarts now reset Home's wait: not in the report; Home is covered there, so the chip can show "Looking for a screen" for 3 s after the user returns.
- The extra frame in the resume test (phone_home_screen_test.dart:184) was accepted without a stated cause.

## Could not check

- No test or analyze run: this review is read-only and installs nothing. The report's pass claims are unverified; run-findings.md has no entry for this job.
- Whether `discoveryStateProvider` (providers/connection.dart:19-21) delivers state asynchronously: not read in full, and finding 1 depends on it.
- The stray `mine_out.tmp` in the report: `git status` in this worktree shows no untracked files; not checked elsewhere.
- The chip's look on screen (TV look) was not seen.

## Commit message — a draft

Review of the m17prep wave1-home job

Written against commit 20032489 (Home says "Looking for a screen…" while searching).
Findings: 0 must, 8 should, 2 could. Verdict: needs Claude.
Main points: the 3 s wait anchor and the failed-retry claim, the resume test's extra
frame, the untested first-host log, and the report's stale status lines.

## Status row

m17prep wave1-home review: 0 must, 8 should, 2 could; needs Claude on the 3 s anchor and failed-retry claim, the resume test's extra frame, the untested first-host log and the stale report status; no code changed.

## Delete

- none
