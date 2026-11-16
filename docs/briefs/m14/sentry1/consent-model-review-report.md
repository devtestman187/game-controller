# sentry1 consent-model review

## Summary

`small fixes` — 1 must, 1 should, 3 could.
The commit also carries the parallel host-id job's `host_id_test.dart`, which imports `src/host_id.dart`, a file
that does not exist at 14dc30b, so party_host tests cannot compile at that commit; the report names the file nowhere.
The crash prompt's "Don't send" (`crashNo`) is never pressed by any test, so a dialog whose two buttons both
pop true would pass everything.
The rest holds: I re-ran the two new files (9/9 pass), the runner logged both failing on the old code (run.log:24-25),
`tools/check.sh format analyze host` PASS (host 554 tests at HEAD) and the five controller_app files the report
names pass (21 tests); the new code is format-clean, every lib file is under 200 lines, and I found the report's
self-check claims true in code except self-check 4 (line 123), which the extra file contradicts.

## Findings

- **must** packages/party_host/test/host_id_test.dart:5 the consent commit 14dc30b adds this 169-line file from the parallel host-id job, and it imports `package:party_host/src/host_id.dart`, which first appears in b4052425, so `flutter test` in party_host cannot compile at 14dc30b and the report's file list and self-check 4 (line 123) do not mention it → leave the file to host-id's own commit and name it in the report.
- **should** packages/party_host/test/consent_prompts_test.dart:46 the only crash dialog test taps `crashYes`, so `crashNo`/"Don't send" is never exercised and a wiring whose two buttons both pop true would pass every test → add a case that taps `crashNo` and expects `consent.crash` false, prefs `crashConsent` false and the reporter off (`crash.disableCount` 1).
- **could** packages/party_host/lib/src/consent/consent_state.dart:64 `setStats` writes `statsConsent` and then calls `LiveStats.setConsent`, which writes the same key again (live_stats.dart:169), so the design's "the notifier is the only writer" no longer holds and the two writes could drift → let `LiveStats.setConsent` change only its state on this path, or record the second writer in the design.
- **could** packages/party_host/lib/src/consent/consent_state.dart:11 `statsConsentKey` is exported from party_host.dart though only this file uses it, while LiveStats keeps the same value as a private `_consentKey` (live_stats.dart:118) → make it private here or export it `show`-limited and have LiveStats use it.
- **could** packages/party_host/lib/src/consent/consent_prompts.dart:75 the crash body is about 490 characters and `_ask` puts it in a plain `Text` inside an `AlertDialog` with no scroll view → wrap the body in a `SingleChildScrollView` so a small phone in landscape cannot overflow.

## Decisions to confirm

- `crashReporterProvider` (consent_state.dart:34) is what `setCrash` enables, while `CrashReports.capture` goes through whatever `startCrashReporting` set (crash_reporter.dart:68-71); nothing in this commit or its tests ties the two, so an app that overrides one and not the other saves "yes" and starts nothing.
- The stats prompt's words stay in `HostText` while the crash prompt's are in `ConsentText` (consent_prompts.dart:39, :50): two homes for one prompt pair, as the report's Decision says; confirm the design wants that split.
- `askConsents` still asks the stats question after a crash prompt dismissed without an answer (consent_prompts.dart:119); the report's Decision covers it, but the design's "each unanswered question in turn" also reads as stop-after-dismissal, so the re-ask for crash deserves a yes from the owner.
- The stats body now says "in settings" (host_text.dart:267) while the TV's control sits on its Stats screen (site/privacy.html:49 says "in settings (on the TV, on the Stats screen)"); confirm the shorter app wording is acceptable on the TV.

## Could not check

- run.log:23 logs "consent-model finished: result 4" where every other job in the wave logged 0; I cannot read what exit code 4 means, so whether the worker hit a limit or a check is unknown.
- `tools/review.sh` was not re-run, so its "0 fail, 1 note" claim is unverified here; I ran format, analyze, the party_host suite and the five controller_app files instead.
- A device check of the crash prompt's height and wrapping (the report's own open item) cannot be done here; the fixed 560 px width and the long body on a phone are unverified.
- Whether each app's `main()` will override `crashAvailableProvider`/`crashReporterProvider` and call `askConsents` is a later job; nothing in this commit wires a prompt into an app.

## Commit message

Review sentry1 consent-model: 1 must, 1 should, 3 could

The consent commit carries host-id's host_id_test.dart, which imports
src/host_id.dart, absent at 14dc30b, so party_host tests cannot compile
there. The crash prompt's "Don't send" is never pressed by a test.
Also found a second writer of statsConsent, an exported key used only
inside its file, and a long dialog body with no scroll view. The
reporter provider and the two text homes need a look from Claude.

## Status row

sentry1 consent-model review: 1 must (host-id's host_id_test.dart in the consent commit, unmentioned), 1 should (crashNo untested), 3 could — open: that file in the commit, a crashNo test, the reporter-provider and text-home decisions.

## Delete

- none
