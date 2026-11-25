# Review of wave4-n8b2 (PhoneHomeScreen, commit b85f31ad)

## Summary
Verdict: needs Claude
Counts: must 2, should 5, could 2
1. Platform exit call sits in the screen (phone_home_screen.dart:115); guideline §1 puts platform channels in an adapter, and the brief asked for a platform-channel test, so the fix is a design choice.
2. Test file has a line over 120 columns (phone_home_screen_test.dart:44), so the brief's `format` check fails.
3. The report's test count is wrong (report line 13): the file has 13 `testWidgets` calls and 16 tests run, not 14.

## Findings
- **must** controller_app/lib/src/home/phone_home_screen.dart:115 `SystemNavigator.pop()` is a platform channel called from the widget, against guideline §1 (platform code only in an adapter with a fake) → put the exit behind a small injected adapter (a Dart interface with a fake) and have the test check the fake; the brief's "platform channel test" then becomes a fake-call test (see Decisions).
- **must** controller_app/test/phone_home_screen_test.dart:44 the line is over 120 columns → wrap it as `dart format` would.
- **should** controller_app/test/phone_home_screen_test.dart:245 `reason: 'the pad alone overflows'` is inverted (the expectation is that nothing overflows), so a failure prints the wrong sentence → change the reason to 'the pad alone must not overflow'.
- **should** controller_app/lib/src/home/phone_home_screen.dart:58 the search timer is started on the first frame and cancelled in `dispose` (line 68), but no test proves dispose cancels it (guideline §5 "a test proves dispose leaves nothing running"); the only timer tests run to the timer's end → add a test that disposes Home before `homeSearchWait` and pumps past it with nothing pending.
- **should** controller_app/lib/src/home/phone_home_screen.dart:82 and controller_app/lib/src/home/launch_consent.dart:17 the two live-hosting guards (no close, no prompt) are new behaviour with no test in the commit; the consent test and the leaving tests all run with no live host → add a test: Home on a phone that hosts live asks nothing and stays open on a connection.
- **should** docs/briefs/m16/wave2-789/wave4-n8b2-review-report.md:13 "14 tests (16 reported …)" does not match the file: 13 `testWidgets` calls, 16 tests run (the looks loop gives 4) → correct it to "13 tests in the file, 16 run".
- **should** docs/briefs/m16/wave2-789/wave4-n8b2-review-report.md:30-31 self-check line 3 cites "a connection closes Home" as the dropped-link test, but that test starts from an idle link; no test covers a dropped link with Home open → say "dropped link: not tested", or add the test.
- **could** controller_app/test/phone_home_screen_test.dart:158 `await tester.pump(homeSearchWait);` has no assertion and no comment; it looks like a timer drain → drop it, or say in a comment why it is there.
- **could** controller_app/lib/src/home/phone_home_screen.dart:22 the dartdoc cites "APP-START.md, item 8 of JOBS.md", which are planning files, not the reason for the code → cut the parenthetical; the dartdoc should say why.

## Decisions to confirm
- The exit (`SystemNavigator.pop`) is in the widget (phone_home_screen.dart:115), which the brief asked for ("platform channel test") but guideline §1 forbids; the adapter fix changes the test the brief named. Owner or Claude to pick.
- Home closes itself with `removeRoute`, not `pop` (phone_home_screen.dart:84): sound, and listed in the report.
- "Search again" does not reset `_searchWaited` (phone_home_screen.dart:44, 129): after a restart with no host the find stays "none" (Play leads) and never goes back to "searching". Is that intended?
- The search timer runs even when a host is already found (phone_home_screen.dart:58): harmless, but it is a timer with nothing to time (review rule B2).
- TV look at 568x320 is not tested for Home (phone_home_screen_test.dart:233-235); the pad overflows there by 12 px. The repo skips the same size in connection_chip_test and touch_targets_test, so this follows the pattern.
- `askLaunchConsent` is new, but the old guards stay in controller_screen.dart:109-110 and connect_screen.dart:62-66 until n8b3, so the same rule exists in three places for now; per the brief.

## Could not check
- docs/briefs/m16/wave2-789/run-findings.md does not exist, so no runner evidence was available.
- I did not run `dart format`, `dart analyze` or the tests (read-only job). The line-length and test-count findings come from reading the files.
- The file design/sentry-consent.md (cited in launch_consent.dart:8) was not located; the grep found only references to it in other docs.
- APP-START.md and JOBS.md (cited in phone_home_screen.dart:22) were not opened.
- The helpers `hostOf`, `hostReady`, `until`, `closeSettings` and `answerConsent` were not read in full; the tests' dependence on them is unverified.
- I read the working-tree copies of the changed files; the start-of-session git status did not list them as changed.

## Commit message — a draft
none: this is a read-only review and this report is the only file it changes.

## Status row
n8b2 reviewed (wave4-n8b2-review): 2 must, 5 should, 2 could; open: the platform exit in the widget (guideline §1, needs a decision), the 120-column line, the inverted test reason, dispose and live-host tests, and the report's test count.

## Delete
- none
