## Summary

- Verdict: **small fixes** — 1 must, 5 should, 5 could.
- Files: only this report changed (read-only review of f1's commit `52389e7c`).
- The must: the pop the brief's item 3 asked to skip is never let through again, so a connection that
  lands under the launch prompt leaves the phone on Connect for good (`connect_screen.dart:61`, `:71`).
- The report's self-check cites `connect_consent_pop_test.dart` for a prompt that throws
  (`f1-report.md:88`); that test has one case and never throws.
- Nothing asserts the TV's release reaches its reporter, so `tv_host_setup.dart:97` can be reverted with
  every test still green.
- Also: the commit carries four test files the report does not list, and `fake_crash_off_test.dart` tests
  the fake only.

## Findings

- **must** controller_app/lib/src/ui/connect_screen.dart:61 `_promptUp` makes the connection listener skip its `maybePop` and nothing pops once the prompt is answered, so a connection that lands under the launch prompt leaves the Connect screen up with only a Disconnect button (`connect_panels.dart:184`) and the pad behind it never shows → pop in the `whenComplete` when `clientStateProvider` is connected (or hold the skipped pop and do it there), and assert the controls show after the answer in `connect_consent_pop_test.dart`.
- **should** docs/briefs/m14/sentry1/f1-report.md:88 the self-check says the flag is cleared "even if the prompt throws", "(`connect_consent_pop_test.dart`)", but that file's single test never makes `askConsents` throw → add a case that throws out of the prompt and checks the flag cleared, or drop the claim.
- **should** tv_test_app/lib/src/tv_host_setup.dart:97 no test reads the release the TV's reporter gets (`app_with_build_test.dart` covers the helper alone), so restoring `versionLabel` here keeps the suite green → add a `tvStartCrashReporting` case that records the release it was started with.
- **should** docs/briefs/m14/sentry1/f1-report.md:47 the Files changed list omits four files the commit contains (`packages/party_host/test/fake_crash_off_test.dart`, `live_stats_answer_kept_test.dart`, `stats_retry_once_test.dart` and the additions to `consent_prompts_test.dart`), so self-check item 4 ("only `allow:` files changed") cannot be checked from the report → list them, or leave them to the commits of the jobs they belong to.
- **should** packages/party_host/test/fake_crash_off_test.dart:1 all three tests check the test double `FakeCrashReporter` and no app behaviour, and the brief asked for none of them → drop the file, or say in the report why the fake needs its own tests.
- **should** controller_app/lib/src/host/hosting.dart:104 the phone's lobby is the one path no test drives (the report says the socket widget test hung), so a wrong read here or in `main.dart:53` ships silently and the phone's own host reports would carry names → add a widget test that hosts on the phone, joins a player, and checks `CrashReports.playerNames`.
- **could** packages/party_host/lib/src/crash/crash_names.dart:21 the name set never ends with the provider: a disposed container leaves the last lobby's names in `CrashReports.playerNames` (`crash_names_test.dart:11` has to clear it by hand) → clear the set in `ref.onDispose`.
- **could** tv_test_app/lib/src/app_info.dart:21 the second copy of `appWithBuild` and `_maxBuildDigits` (identical to `controller_app/lib/src/app_info.dart:19-26`) will drift → share one helper once a file both apps may import is allowed.
- **could** packages/party_host/test/fake_crash_off_test.dart:2 imports `package:party_host/src/testing/fake_crash.dart` directly while `consent_prompts_test.dart:4` now imports `package:party_host/testing.dart` → import the testing library in both.
- **could** controller_app/lib/src/host/hosting.dart:40 `gameShownProvider` is set before `hostingProvider` holds the host (line 45), and `phoneServiceProvider` throws while it is null (line 112), so any synchronous read of the new lobby in that gap throws "No host is running in this app" → set the state before the flag, or guard the lobby on a host that exists.
- **could** docs/briefs/m14/sentry1/f1-report.md:103 the computed value says `client.metrics` "stays empty after a mode switch", but the test's baseline is `sent`, which already holds the batch the off tap sends, and it only asserts the length does not grow → say "no new batch" so the value can be checked.

## Decisions to confirm

- `crashLobbyProvider` replaces the brief's `ref.exists(hostServiceProvider)` guard (`crash_names.dart:14`): the reason is a riverpod-3 claim I did not verify; if it holds, it belongs in `docs/project-notes.md` (the report's own suggestion).
- Turning stats off re-runs `_updateMetrics`, and `PhoneMetrics.setActive` ends *and sends* the segment (`phone_metrics.dart:47-52`), so one last batch leaves at the off tap (`metrics.dart:51-54`); confirm that is wanted rather than dropping the segment.
- The phone keys its lobby on `gameShownProvider` (`hosting.dart:104`) rather than on a live host service; a stopped host keeps its (empty) player list, so confirm no names should outlive "stop".

## Could not check

- The counts in `f1-report.md:16` (host 570, phone 526, tv PASS, `tools/review.sh` 0 fail / 4 note): not re-run.
- `ref.exists` behaviour in riverpod 3, and why the phone's hosting widget test hung.
- Device-only items: a report reaching Sentry, and the prompts' look.

## Commit message

sentry f1 fixes: defer the connect pop, prove the TV release

The skip added for the launch prompt is never made up, so a connection
that lands under it leaves the phone on Connect; pop once the answer is
in. Add a case for the prompt throwing, and one showing the TV's reporter
gets the 0.14.0+654 release. Drop the fake's own tests, list or move the
commit's four unlisted test files, and cover the phone-hosting names
path. Small cleanups: clear the name set on dispose, one appWithBuild.

## Status row

sentry f1 review: 1 must (Connect stays up when a connection lands under the launch prompt), 5 should, 5 could; open: the deferred pop, the throwing-prompt and TV-release tests, the phone-hosting names test, the extra test files in the commit.

## Delete

- none
