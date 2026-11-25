# Review of wave 6 job n8b3 (commit c5b6246f): launch routing

## Summary
- Verdict: needs Claude
- Counts: 3 must, 7 should, 3 could
- Top 1: c5b6246f is committed red: 5 tests fail (run.log:255); two of them (connect_screen_test:177, launch_consent_test:52) are outside n8b3's allow list and the report does not name them.
- Top 2: two of the new tests pass on the pre-change code: launch_home_test.dart:55 (Join a Game) and :108 (dropped link), so they prove nothing about the new routing.
- Top 3: routeLaunch shows the pad when no TV is discovered at all (launch_route.dart:17, connection.dart:197-199), against owner Q4 ("pad only when the last host is found live").

## Findings
- **must** controller_app/test/launch_home_test.dart:55 "Join a Game on the launch Home opens Connect" passes on the pre-change code: reachConnect returns at once when Home is absent (pump_app.dart:168-169) and the old launch opened Connect, so Home is never asserted → assert `find.text(HomeText.joinGame)` is found before calling reachConnect.
- **must** controller_app/test/launch_home_test.dart:108 "a link that dropped after connecting does not return to Home" passes on the pre-change code (no Home existed, so homes() is empty) → give it a positive control on its own app: a connecting→failed run that must show Home, then the dropped sequence on a separate app.
- **must** docs/briefs/m16/wave2-789/run.log:255 the commit went in with "5 tests still fail (f4)"; f4.md:11-12 names connect_screen_test:177 and launch_consent_test:52, both outside n8b3's allow list, and n8b3-report.md:18-21 only says "may still fail" → n8b3 should have stopped at the red tests; Claude runs `check: phone` on c5b6246f before any further job builds on it.
- **should** controller_app/lib/src/home/launch_route.dart:17 with no TV discovered, reconnectToLastHost connects to the remembered address and returns true (controller_app/lib/src/providers/connection.dart:197-199), so the pad stays, against Q4 and the brief's claim that reconnectToLastHost already does this → Claude decides; if Q4 stands, route to Home when the host is not found live, with a test that has an empty discovery list.
- **should** controller_app/test/launch_home_test.dart:1 brief item 2 asks for "a hosting phone never gets Home"; no test sets hostingProvider live, so the guard at launch_route.dart:42 and :43 is untested → add a test: hosting live plus a connecting→failed run shows no Home; or Claude confirms the repair note (n8b3.md:10) overrides item 2.
- **should** controller_app/test/launch_home_test.dart:27 brief item 2 asks for the menu look and the TV look; the loop covers only the two menu palettes 'sunny' and 'night', and no toyTvProvider override appears (party_host look_providers.dart:56) → add a TV-look pass, or record in the report that the phone never shows the TV look.
- **should** docs/briefs/m16/wave2-789/n8b3-report.md:6 says "12 tests"; the file has 7 testWidgets calls, the look loop gives 4 runs, so 10 tests → correct the count to 10.
- **should** docs/briefs/m16/wave2-789/n8b3-report.md:18 the report has no review-rules part A lines for host setups (A1), staying in the folder (A4), stopping (A5) or the look check (A6); the "Rules as built" block only covers A2/A3 in part → add one line each for A1 to A6, with "not affected" where true.
- **should** controller_app/test/support/pump_app.dart:72 and :103 `toConnect` defaults to true, so every unpaired pumpApp test now goes Home then Join; the report does not mention this default change (it was hand-added, run.log:255) → list it in the report as a decision.
- **should** docs/dev-tools.md:345 says `tools/emulator.sh launch` "clears data and opens the Connect screen"; an unpaired launch now opens Home → change the line to say Home, then Join a Game opens Connect.
- **could** controller_app/test/launch_home_test.dart:84 the "host gone" test relies on two settle calls (500 ms each) reaching the 1 s reconnectDiscoveryWait (controller_app/lib/src/providers/connection.dart:153) → pump the wait explicitly.
- **could** controller_app/lib/src/home/launch_route.dart:29 `launchHomeRoute` is public but only used in this file → make it private.
- **could** controller_app/lib/src/home/launch_route.dart:12 the doc says the caller checks that context is mounted, but routeLaunch checks it again at :18; the sentence at :14-15 ("which put this launch's own two questions") is hard to follow → reword both.

## Decisions to confirm
- The zero-discovery path (launch_route.dart:17, connection.dart:197-199): the pad stays and connects to the remembered address when no TV is found; this differs from owner Q4 as written.
- The failed-connect guard suppresses on any route above the pad (launch_route.dart:43, ModalRoute.isCurrent), not only Home or Connect: this stops stacking, but it also means a failure while the launch consent dialog or Settings is up never returns to Home. The report discloses the Settings part only.
- The hosting-guard test was dropped on the repair note's word (n8b3.md:10) against item 2 (n8b3.md:13).
- pumpApp's toConnect default is true (pump_app.dart:72), so all unpaired test launches now pass through Home.
- reachConnect taps the coach-mark Skip in every test that reaches Connect (pump_app.dart:170-176): a test-helper change only, but it touches all of them.
- The commit was made by hand with known red tests (run.log:253-255); whether Claude accepts it, or reverts to a green state, is an owner call.

## Could not check
- No tests were run (read-only review; nothing installed). The pass/fail claims for the old code come from reading the diff, not from running c5b6246f^; the only runner evidence is run.log:253-255.
- run-findings.md has no entry for n8b3 (its one line is about n8d1), so there was no "passes on old code" entry to verify.
- Whether the 1 s discovery timer fires inside the two settle calls, and whether the Home route is built in time, needs a test run.
- The state of the 5 failing tests now: f4 has no report (only f4.md), so it cannot be verified that they pass.
- The consent-dialog-plus-failed-connect path on a device was not exercised.

## Commit message
review: wave2-789 n8b3 launch routing, 3 must and 7 should

Review of the n8b3 commit c5b6246f against the coding guidelines,
the review rules and its brief. The commit ships with 5 failing
tests (run.log), two of them outside its allow list. Two new tests
pass on the pre-change code. The zero-discovery path shows the pad,
against owner Q4. The report counts 12 tests where there are 10 and
lacks the part A lines. Findings only; no code changed.

## Status row
wave6 review of n8b3 (c5b6246f): needs Claude. Done: read review of code, tests, brief and report. Open: 5 red tests on c5b6246f (outside allow), 2 tests that pass on old code, zero-discovery route (Q4), no hosting or TV-look test, dev-tools.md:345.

## Delete
- none
