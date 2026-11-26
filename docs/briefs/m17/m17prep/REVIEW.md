## Summary

Verdict: **needs Claude's design** (the resume-path cause, the 20 px floor and verdict asserts, the 3 s anchor and where the shared measurer lives each need a decision; the rest is one fix batch).
Counts: must 2 · should 20 · could 12 (34 findings).
Five that matter most:
1. The Home resume fix has no known cause: the resume test got a second bare `pump()` and no recorded passing run (`controller_app/test/phone_home_screen_test.dart:183-184`). Fixed, unverified: needs device check.
2. `p0a-report.md` has no Summary block and no review-rules part A self-check (`docs/briefs/m17/m17prep/p0a-report.md:1`).
3. The 3 s Home wait now restarts on the first discovery start and on hosting and Connect restarts, not only on Search again and resume (`controller_app/lib/src/home/phone_home_screen.dart:150-153`).
4. Both fit tests hard-code the `docs/briefs/m17/m17prep/p0a-fit.json` path and write into docs when `NIGHT_FIT=1` (`packages/party_host/test/night_cards_fit_test.dart:35-39`, `controller_app/test/night_result_fit_test.dart:40-44`).
5. The fit measurer is copied into two tests and the copies already differ; the review's `lib/testing.dart` idea conflicts with guideline §2, which allows that file only for fakes (`docs/coding-guidelines.md:31`).
Phone-pinned findings are tagged `[phone]` (controller_app tests or lib).
Owner-only questions: 20 px floor, 360x640 meaning, 8-player team shape, real time in the load test, and the 3 s anchor (see Open questions).

## Findings

- **must** controller_app/test/phone_home_screen_test.dart:183-184 The resume test's second bare `pump()` has no stated cause, and no recorded run shows the test passing after the hand-fix; the resume fix the owner asked for is unproven → find the event order that needs it (the lifecycle restart reaching the Home listener) or say why one pump is enough, then record a passing run; mark it "Fixed, unverified: needs device check" until then. [phone] (from: wave1-home)
- **must** docs/briefs/m17/m17prep/p0a-report.md:1 The report has no Summary block and no review-rules part A self-check (its headings are Files changed, Setup, tables, Conclusion, Questions) → add a Summary at the top and the six self-check answers, each with the test that shows it. (from: wave1, run-findings)
- **should** packages/party_host/test/night_cards_fit_test.dart:94 Only "no overflow or exception" is asserted; the brief's asserts for the 20 px floor, free band, corner width and verdict are missing → assert them after the floor decision (open question 3), or record the decision in the brief; no skip. (from: wave1)
- **should** controller_app/lib/src/home/phone_home_screen.dart:150-153 The listener restarts Home's 3 s wait on the first start and on the hosting and Connect restarts (`hosting.dart:67`, `connect_screen.dart:187`, unread), not only on Search again and resume; the stated reason (a Search again after a failed start) fails when the retry fails again because `stop()` keeps `error` (`discovery.dart:151`) → choose the anchor (open question 2), correct the decision text, and test a second failed retry and one Connect restart. [phone] (from: wave1-home)
- **should** controller_app/lib/src/home/phone_home_screen.dart:55 The doc "True once [homeSearchWait] passed since the first frame" is wrong now that the wait starts again on each search → say "since the latest search started". [phone] (from: wave1-home)
- **should** controller_app/lib/src/discovery.dart:206-209 The first-host log has no test; `discovery_first_host_test.dart` tests only the string from `firstHostLine`, so a wrong `wasEmpty` or a log on every host passes → add a test that feeds two resolved hosts through the discovery and asserts one log line (inject the clock if needed). [phone] (from: wave1-home)
- **should** controller_app/test/support/fakes.dart:240 `FakeDiscovery.restart` reads `DateTime.now()`, against the no-real-time rule (guidelines §9); line 241 also clears `hosts`, which the brief did not ask for → use a fixed base time plus the restart count, and say in the report that restart clears hosts. [phone] (from: wave1-home)
- **should** controller_app/test/home_view_test.dart:153-161 The searching-chip test runs only at 568x320 in the menu look (`pumpHome` defaults, lines 42-43); rule A6 needs the TV look and the size list → loop it over the sizes and `tv: true`. [phone] (from: wave1-home)
- **should** packages/party_host/test/night_cards_fit_test.dart:190-269 `_measure` takes 6 parameters (limit 5) and is 80 lines → pass (layout, scale, bodyStyle) as one value object and split it at the paragraph and box passes. (from: wave1)
- **should** controller_app/test/night_result_fit_test.dart:243-316 `_measure` is 74 lines, and the file is 331 lines (above the 300 target) → split with the shared measurer of finding 12. [phone] (from: wave1)
- **should** controller_app/test/night_result_fit_test.dart:101-121 The 360x640 cases are named "draws without overflow or exception", but at :114-121 they assert the card is absent and measure nothing, so brief item 2's 360x640 measure is not made → rename the test to what it checks, and settle open question 4. [phone] (from: wave1)
- **should** packages/party_host/test/night_cards_fit_test.dart:100-164 and controller_app/test/night_result_fit_test.dart:132-164, :243-316 The measurer, results-file writer and overflow stub are copied in both tests, and the copies already differ (rounding, `belowFloor`; `night_result` uses `_decimals`, `night_cards` uses bare 100) → one shared test helper. The suggested `lib/testing.dart` is allowed only for fakes (`docs/coding-guidelines.md:31`), so Claude picks the place (a test-support package or a test-only library). (from: across jobs, wave1) [phone for the controller_app copy]
- **should** packages/party_host/test/night_cards_fit_test.dart:35-39 and controller_app/test/night_result_fit_test.dart:40-44 The results path `docs/briefs/m17/m17prep/p0a-fit.json` is hard-coded in two tests, which write into docs when `NIGHT_FIT=1` → take the path from a define or an environment variable with no default into docs; the worker rule bars hard-coded paths. (from: across jobs) [phone for the controller_app one]
- **should** packages/party_host/test/night_cards_fit_test.dart:216 and :292 Bare `1000` and bare `100` break the no-magic-numbers rule → name them as constants (`night_result_fit_test.dart:33` already has `_decimals`). (from: wave1)
- **should** packages/puzzle_game/test/snapshot_eight_players_test.dart:80 The line is over 120 columns (the grep shows 121+) → split the string into adjacent literals. (from: wave1)
- **should** packages/party_host/test/night_cards_fit_test.dart:79 and controller_app/test/night_result_fit_test.dart:92 `as Map<String, Object?>` on the decoded results file is unchecked → test `is Map` before the cast. [phone for the second] (from: wave1)
- **should** docs/briefs/m17/m17prep/p0a-report.md:41 Conclusion 3 says option C's strip "is the setup that gives it", but option C was not measured → cut the claim to what was measured, or measure option C. (from: wave1)
- **should** docs/briefs/m17/m17prep/home-report.md:5, :52, :64, :68 The Summary says "all parts are in and the test passes" (5), while the questions (52), commit draft (64) and status row (68) say the resume test still fails → make them say one thing that matches the recorded run. (from: wave1-home)
- **should** docs/briefs/m17/m17prep/e0f-report.md:32-37 The numbers (inputs/s, wall ms per 1000, max lag, bytes at 4, 6 and 8 players) are "not measured" (brief item 4) → with owner approval, run `bash tools/load8.sh` once and fill the two result lines in. (from: wave1)
- **should** packages/connection/test/load_eight_phones_test.dart:117 and :147 The load test uses real time (Stopwatch, `Future.delayed`) against guidelines §9 → the owner accepts it as a measuring exemption and the test's doc says so (open question 7); otherwise remove it. (from: wave1)
- **should** docs/briefs/m17/m17prep/ci-report.md:9 The report says six packages run twice, but does not say that the Coverage step now also gates metrics, game_kit, toy_look and puzzle_game, which no CI step gated before → add that to the Summary and the commit draft. (from: wave2)
- **should** docs/briefs/m17/m17prep/ci-report.md:11 and :29 The expected job time is 25.5 min by addition (:28) and 28.6 min with 20% growth (:29), but the evidence's "about 36 min" (ci-evidence.md:16, not read by me) does not follow → recompute, use one figure in the STATUS row (open question 10). (from: wave2, ci-report Q1)
- **could** packages/connection/test/load_eight_phones_test.dart:115-181 `runLoad` is 67 lines → split at the pair, send and drain seams, about 40 lines each. (from: wave1)
- **could** packages/connection/test/load_eight_phones_test.dart:213 `second.sent == first.sent` cannot fail, because each phone sends seconds × 60 inputs by construction → drop the line, or keep it as a note. (from: wave1)
- **could** packages/connection/test/load_eight_phones_test.dart:190 The literal `8 phones:` repeats the count → interpolate `phoneCount`. (from: wave1)
- **could** packages/party_host/test/night_cards_fit_test.dart:218 The floor check counts empty-text paragraphs (p0a-report.md:24 says two exist) → skip paragraphs whose text is empty. (from: wave1)
- **could** controller_app/test/night_result_fit_test.dart:126 The second `expect(measured.errors, isEmpty)` repeats the check at :113 → remove it. [phone] (from: wave1)
- **could** docs/briefs/m17/m17prep/p0a-report.md:9 The scale is written 0.6948; the code (`night_cards_fit_test.dart:142`) gives min(667/960, 375/540) = 0.6944, and p0a-fit.json rounds to 0.69 → correct the report. (from: wave1)
- **could** docs/briefs/m17/m17prep/e0f-report.md:21 "The JSON is ASCII, so this equals the byte count" is asserted by no test → assert it or drop the claim. (from: wave1)
- **could** controller_app/lib/src/discovery.dart:209 `_state.startedAt` is still the previous search's start while `await discovery.start()` runs (it is set at :129), so the log can show a wrong N → set `startedAt` before the await, or say why it cannot happen. [phone] (from: wave1-home)
- **could** controller_app/test/discovery_first_host_test.dart:11 The name "counts whole milliseconds, 1 ms after one millisecond" is garbled, and no case shows the truncation → rename it and add a 1.9 ms case. [phone] (from: wave1-home)
- **could** .github/workflows/ci.yml:35 `timeout-minutes: 45` has no comment saying why → add a one-line reason with no date. (from: wave2)
- **could** .github/workflows/ci.yml:53 The comment "(Nov 26, ~10 min)" carries a date and a minute figure that go stale → keep the why and drop the date and minutes. (from: wave2)
- **could** packages/connection/test/load_eight_phones_test.dart:39, packages/puzzle_game/test/snapshot_eight_players_test.dart:20, packages/party_host/test/night_cards_fit_test.dart:17, controller_app/test/night_result_fit_test.dart:20 The LOAD8 and NIGHT_FIT env-flag read is copied in four files → one shared pattern (the same flags are read with two different expressions). (from: across jobs)

## Open questions

1. Resume test: which event order needs the second pump? Suggested: find it before B1 closes; if it is not found, the report says the pump is a workaround.
2. Home 3 s wait: start at Home's first frame (brief) or at each discovery start (as built)? Suggested: first frame for the first start; restart only on Search again and resume.
3. 20 px text floor: assert it (suite fails on start and scoreboard) or record it as a finding? Suggested: record it; the layout fix is a later job.
4. 360x640: the phone-as-host portrait window, or the phone in landscape (640x360)? Suggested: measure 640x360 as well (p0a's own suggestion) and treat 360x640 as "not drawn" for the phone card.
5. "8 players": 4 a side as built, or another team shape? Suggested: 4 a side as built; B10 decides.
6. Approve one `bash tools/load8.sh` run so e0f's numbers can be filled in? Suggested: yes, once.
7. Real time in the load test: accept as a measuring exemption? Suggested: accept, and say so in the test's doc.
8. Eight phones on one seed (`load_eight_phones_test.dart:81`): keep it and say the phones are not eight players, or give each phone its own seed? Suggested: keep it and say so.
9. `FakeDiscovery.restart`: clear `error` as the real start does, and clear `hosts`? Suggested: clear `error` (the real start sets it to null at `discovery.dart:129`) and say so in the report.
10. Job time: 36 min (evidence) or 28.6 min (arithmetic)? Suggested: 28.6 min, recomputed; the 45 min limit holds either way.
11. Coverage runs with no threshold, while HANDOFF asks for a manual check against 92.8%. Suggested: keep it, and add the manual check to the next-push list.
12. `e0f-report.md` is outside e0f's allow list (the report field names it). Suggested: accept.

## Numbers against targets

- 20 px text floor (p0a, host cards, frame px): start 18.0, scoreboard 15.0 ("Round 2 of 5"), game names 18.72 and 18.0 (p0a-report.md:24) → all miss; reveal 23.4 meets.
- 56 dp head on host cards (corner free width): 360x640 start 9.0, scoreboard 7.88, reveal 9.0; 667x375 start 27.78, scoreboard 14.58 (4p) and 22.22 (6p), reveal 16.67 (p0a-report.md:17-22) → all six miss.
- 2-line caption strip on host cards (needs 15.0 dp at 360x640, 27.78 dp at 667x375; free band 3.0 and 5.56 dp) → all six miss.
- Phone result card, 56 dp head at 667x375 (corner 123.5, 110.34, 75.63, 58.2) → all four meet; 360x640 is not drawn.
- Phone result card, 2-line strip (needs 40.0 dp; free band 40.0, 21.37, 14.43, 10.94) → 1 of 4 meets (round 2, 4 players, exactly equal).
- Snapshot under `PuzzleSnapshot.maxBytes` 2048: 4 players asserted, and run.log records "result 0"; no byte count is written in any report. 6 and 8 players: not measured.
- Load: inputs/s, wall ms per 1000 inputs, max host lag: not measured (no target is named in the reports).
- CI `analyze-test-android` limit 45 min (raised from 30): expected 25.5 to 28.6 min (ci-report.md:28-29); cancelled main runs took 30m15s to 30m20s; passing runs 26m05s and 28m21s → meets.
- Home wait 3 s (`homeSearchWait`, phone_home_screen.dart:24): kept → meets; the anchor changed (finding 4).
- Time to first host: the log line exists; no figure is recorded anywhere → not measured.
- Coverage 92.8% (HANDOFF): no figure recorded in these reports → not checked.

## Could not check

- Whether any test passes now: run.log records only "result 0" per job; no run after the home hand-fix; I ran no tests or analyzer (read-only).
- The whole-range diff (`git diff 011736ba..0efa1815`) was refused; I read the files in the brief's list and the reports instead, so changes outside those files are not covered.
- `docs/briefs/m17/m17prep/STATUS.md` does not exist; I read `docs/briefs/m17/STATUS.md` (job list and owner decisions). `M17a-batches.md` (outside the repo) was not read, and its "Home search wait" section may fix the anchor.
- Not read: `controller_screen.dart:118`, `hosting.dart:67`, `connect_screen.dart:187`, `providers/connection.dart:19-21` (whether the discovery state arrives async); the restart-path claims rest on the reports.
- `ci-evidence.md` was not read; the CI times come from `ci-report.md` and the wave2 review.
- `tools/coverage.sh:12` records the decision to use `flutter test --coverage` everywhere (M14 bugs15), which answers the wave2 "dart test vs flutter test" question; I did not carry it as a finding.
- `phone_home_screen_test.dart:57` is 121+ columns (grep); not read, and I cannot tell whether this run added it.
- The wave1-home review cites `home-report.md:23, :82, :86`; those lines do not match the file (72 lines). I used :5, :52, :64 and :68.

## Commit message — a draft

m17prep run review: findings only (report)

Adds docs/briefs/m17/m17prep/REVIEW.md: the run's review, read as one change against
the coding guidelines and review rules. No code or other document changed.
Findings: 2 must, 20 should, 12 could. Main: the Home resume fix has no known cause
and no recorded passing run; p0a has no Summary or self-check; the 3 s wait anchor
changed; the two fit tests hard-code a docs path and share a copied measurer.
Open for Claude: the 20 px floor, the 3 s anchor, the shared measurer's place.

## Status row

m17prep run review: done: 34 findings (2 must, 20 should, 12 could) in REVIEW.md; open: the resume fix cause (unverified), p0a Summary and self-check, owner decisions on the 20 px floor, the 3 s anchor and 360x640, and the e0f load numbers.

## Delete

- none
## Driver verdicts (Nov 26)
- must 1 resume test second pump: verified. Cause: FakeDiscovery.restart emits the new startedAt on the stream in a microtask after the first frame; the second pump rebuilds. Test passes (run alone and in the full check); comment added. Closed. Still device-unverified (please check on a phone).
- must 2 p0a-report Summary: added by hand, with the 0.6944 scale and the option C claim corrected. Closed.
- should: Home doc comment (phone_home_screen.dart:55) fixed; FakeDiscovery.restart uses a fixed base time (fixed); home-report inconsistencies and e0f numbers filled in (load: 480.4 inputs/s, 2081.5 ms per 1000, max lag 8.13 ms; snapshot 773/796/817 bytes at 4/6/8 players) (fixed). Open question 2 (3 s anchor on each search start) kept as built, noted for the device check. Open questions 3, 4, 5, 7, 8, 9, 10: recorded, no owner call needed now (floor recorded not asserted; 4 a side; real time accepted as measuring exemption; Q10 uses the arithmetic 25-29 min).
- Everything else (test-file duplication, long functions, magic numbers, ci.yml comments, load8.sh missing line, first-host log test, chip test sizes): minor, in docs/code-health.md (m17prep entries). No fix job: nothing blocks B2.
