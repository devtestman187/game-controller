# sentry1: the run's review (round 2, after f1-f3)

## Summary

**Verdict: one fix batch** — 1 must, 9 should, 18 could. The first round's four musts are done (CI DSN,
`release.md:90`, the stats answer reaching the recorder, the player names); what remains is one must, a
deferred pop that is never made up, plus test and doc gaps left by f1-f3 and by the earlier verdicts.
Five that matter most:
1. `connect_screen.dart:61`: the pop skipped while the launch prompt was up is never done after the answer, so a phone that pairs under the prompt stays on Connect with only Disconnect.
2. `crash_reports_test.dart:32`: with the fake now dropping reports while off, deleting `CrashReports.capture`'s `enabled` guard keeps that test green.
3. `host_id.dart:75`: the id retry is still not stopped on dispose, and its last failure is only reported, never logged.
4. `docs/design/sentry-consent.md:7` still says the upload holds "no names or device IDs", which f2's protocol and uploadable text now contradict.
5. `uploadable.dart:44` still documents the old team rule; `code-health.md:166` records two of the items the verdicts sent there.

Hand-fixes (`run.log`): phone-consent's patch (line 48) has its tests-first proof (4 files, lines 58-61) and
its worker review; f3's moved dialog-no tests (line 100) have theirs (lines 104-113) and its review. Both fine.
Checked and dropped as fixed: the CI DSN, `release.md:90`, the stats-off listener, `playerNames` wiring, the
in-process player, the pause-kept answers, protocol §8c's wording, the private crash button, the Retry guard,
`presentError`, the guarded `enable()`, the fake export, the TV release format, the TV "in settings" words,
the `site/shots` churn, the tv-consent review.
For the owner: the deferred Connect pop (Q1), a paired phone's first launch (Q2), old saved sessions uploading
players nobody asked (Q4), and back closing the crash prompt with no answer (Q7).

## Findings

- **must** controller_app/lib/src/ui/connect_screen.dart:61 `_promptUp` only skips the pop (:72) and `whenComplete` clears the flag, so a connection that lands under the launch prompt leaves Connect up after the answer, with only Disconnect and the pad never shown → pop in the `whenComplete` when `clientStateProvider` is connected and assert the controls show after the answer in `connect_consent_pop_test.dart` (from: f1 review; pins: phone)
- **should** packages/party_host/test/crash_reports_test.dart:32 this test and :74 read `fake.captures`, and `FakeCrashReporter.capture` now drops while off (fake_crash.dart:55), so removing `CrashReports.capture`'s `enabled` check keeps them green → keep the off case on a local reporter that records every capture, and leave the fake's drop to `fake_crash_off_test.dart` (from: f3 review; pins: host)
- **should** packages/party_host/lib/src/host_id.dart:75 nothing cancels the retry's wait (`wait(hostIdRetryDelay)`) when `LiveHostService.dispose` runs, so a restarted host can write the stopped session's id last, and :77 sends the last failure only to `CrashReports` (nothing with reports off) → pass a liveness check into `persistHostId` and log one line through the service's `LogSink` at the last failure (from: host-id review; pins: host)
- **should** docs/design/sentry-consent.md:7 the owner's stats line still says "Aggregates only, no names or device IDs", while `uploadableSummary` uploads each sharing player's `install`, device kind and model and `docs/protocol.md` §8c now says so → reword the design line to what goes up (from: across jobs; pins: docs)
- **should** packages/metrics/lib/src/uploadable.dart:44 the doc says "a winner or a team is left out unless every listed player shares", while :54 keeps a team of two among three → say a team keeps its sharing members only while two or more of them share (from: f2 review; pins: metrics)
- **should** packages/party_host/lib/src/crash/crash_reporter.dart:72 (also `sentry_reporter.dart:80`, `:90`, `crash_start.dart:58`) four `on Object` catches hold only a comment, so a reporter that always fails or a scrub that drops every report is invisible (guidelines §2) → log one line with no error text through the package's `LogSink` (from: sentry-core review + across jobs; pins: host)
- **should** tv_test_app/test/crash_setup_test.dart:30 the only TV wrapper assertion is `same(reporter)`, so restoring the old `versionLabel` release or a wrong environment keeps the suite green → call `tvStartCrashReporting(prefs)` and assert the built reporter's `release` and `environment` (from: f1 review; pins: tv)
- **should** controller_app/lib/src/host/hosting.dart:103 only `crash_names_test.dart` covers the lobby provider; no test drives `phoneCrashLobbyProvider` under a real host, so a wrong read here or at `main.dart:55` ships silently → add a widget test that hosts on the phone, joins a player and checks `CrashReports.playerNames` (from: f1 review; pins: phone)
- **should** docs/briefs/m14/sentry1/f3-report.md:14 the report lists `crash_dialog_no_test.dart` (3 tests) as new, but no such file exists (the cases are in `consent_prompts_test.dart:115-149`), and self-check 5 (:51) says nothing was stopped where `run.log:99-100` records the stop and the hand-fix → say so in the report (from: f3 review; pins: docs)
- **should** docs/code-health.md:166 the M14 sentry1 section holds two items; the verdicts sent the empty catches, the host-id retry, the `statsConsent` second writer, the substring scrub and a non-idempotent `installCrashHandlers` here, and none is recorded → add them under the same heading (from: across jobs; pins: docs)
- **could** packages/party_host/lib/src/crash/crash_names.dart:19 `crashNamesProvider` sets `CrashReports.playerNames` but has no `ref.onDispose`, so a disposed container leaves the last lobby's names in the static set (`crash_names_test.dart:13` clears it by hand) → clear it in `ref.onDispose` (from: f1 review; pins: host)
- **could** controller_app/lib/src/host/hosting.dart:40 `gameShownProvider` is set before `hostingProvider` holds the host (:45) and `phoneServiceProvider` throws while it is null (:112), so a synchronous read in that gap throws "No host is running" → set the state before the flag (from: f1 review; pins: phone)
- **could** packages/party_host/lib/src/crash/scrub.dart:28 names are replaced as case-insensitive substrings, so "Sam" turns "same" into "[name]e" in messages and frames → match on `\b` word boundaries or say the over-replacement is intended (from: sentry-core review; pins: host)
- **could** packages/party_host/lib/src/live_stats.dart:166 `setConsent` writes `statsConsent`, and `consent_state.dart:65` writes the same key just before, so the design's "the notifier is the only writer" no longer holds → let `setConsent` change only its state on that path (from: consent-model review; pins: host)
- **could** packages/party_host/lib/src/ui/stats_screen.dart:40 "A Retry pressed while one is reads nothing" → "while one is going reads nothing" (from: f3 review; pins: host)
- **could** packages/party_host/test/stats_retry_once_test.dart:76 "the reading flag clears when a read fails" repeats `stats_screen_failure_test.dart:64` and passes on the old code → drop it, or make it assert a retry during a later held read (from: f3 review; pins: host)
- **could** packages/party_host/test/fake_crash_off_test.dart:18 "the same report is kept once reports are on" passes on the old code and repeats `crash_reports_test.dart:37` → drop it (from: f3 review; pins: host)
- **could** controller_app/test/coverage_all_test.dart:1 the header says "GENERATED … Do not edit" and the job added two imports by hand → rerun `tools/coverage.sh` so the generator writes them (from: phone-consent review; pins: phone)
- **could** packages/party_host/lib/src/text/settings_text.dart:72 the row says stats are sent "only if an adult allows it on the device that hosts", while the switch is this phone's own answer that also gates its uploads → reword next to `ConsentText` (from: phone-consent review; pins: phone + host)
- **could** tv_test_app/lib/src/app_info.dart:21 a second copy of `appWithBuild`/`_buildCount`, identical to `controller_app/lib/src/app_info.dart:19`, will drift → share one helper once a file both apps may import exists (from: f1 review; pins: tv)
- **could** docs/release.md:80 "the switch in Settings turns them off again" is false on the TV, whose control is the Stats screen's button, and :90 says "only the name is logged" while `codemagic.yaml:167` prints "Sentry: set"/"not set" → say where each switch is and what the log prints (from: ci-wiring review; pins: docs)
- **could** packages/party_host/lib/src/consent/consent_prompts.dart:75 the ~490-character crash body sits in a plain `Text` in a fixed 560 px `SizedBox` with no scroll view → wrap it in a `SingleChildScrollView` (from: consent-model review; pins: host)
- **could** packages/party_host/test/crash_reports_test.dart:6 (also `fake_crash_off_test.dart:2`, `host_id_test.dart:6`) party_host's own tests import `src/testing/fake_crash.dart` while the apps now use `package:party_host/testing.dart` → import the testing library in both (from: f1 review; pins: host)
- **could** across the run's commits — `live_stats_share_test.dart` sits in 8c621c8, `host_id_test.dart` in 14dc30b and f2's/f3's tests in 52389e7c, so those commits cannot build their own suites → from now on commit a job's tests with the code they test (from: across jobs; pins: none)
- **could** packages/party_host/lib/src/text/host_text.dart:374, controller_app/lib/src/ui/settings_screen.dart:371, `live_stats.dart` 369 and `connect_screen.dart` 353 lines are over the ~300 aim and `code-health.md:168` names only settings_screen → record the sizes and split at the next touch (from: across jobs; pins: host + phone)
- **could** docs/briefs/m14/sentry1/f1-report.md:88 self-check 2 says the `_promptUp` flag is cleared "even if the prompt throws (`connect_consent_pop_test.dart`)", but that file's one test never makes the prompt throw → add the case or drop the claim (from: f1 review; pins: docs)
- **could** docs/briefs/m14/sentry1/f3-report.md:1 and stats-bug-report.md:1 open with a `#` title and summaries past 30 lines, where the brief asks for `## Summary` first → drop the titles (from: across jobs; pins: docs)
- **could** packages/party_host/lib/src/crash/crash_start.dart:22 `installCrashHandlers` chains a new handler pair on every call, so a second start in one process captures one error per install → make it install once, and test the second call changes nothing (from: sentry-core review; pins: host)

## Open questions

1. After a connection lands under the launch prompt, should the answer pop Connect (finding 1)? Suggested: yes, pop once connected.
2. A phone that launches already paired never sees Connect, so its questions wait until the adult opens it: should the controller screen ask once too? Suggested: yes, on its first frame when nothing was asked.
3. Does the phone host's own player always share, even if its own pad said no (session_player.dart:105)? Suggested: yes; the host's yes is what allows an upload.
4. Do sessions saved before this build upload every player and winner, nobody having been asked (uploadable.dart:22)? Suggested: yes, as built and as the privacy page reads.
5. Is dropping a report that cannot be scrubbed still wanted over sending a partly scrubbed one (sentry_reporter.dart:80)? Suggested: keep dropping.
6. Should `installCrashHandlers` be idempotent? Suggested: yes.
7. May back/Esc close the crash prompt with no answer (no `PopScope` in `consent_prompts.dart`)? Suggested: yes, no answer counts as not asked.
8. Should the tag be `hostIdWrite` rather than `host_id_write` (host_id.dart:24)? Suggested: yes, before more tags arrive.
9. Is the last batch at the stats-off tap wanted (PhoneMetrics.setActive ends and sends the segment)? Suggested: yes, it is the segment's end.
10. Should the two `appWithBuild` copies be shared once a file both apps may import exists? Suggested: yes, with the next app-level helper.
11. Should `ref.exists`'s riverpod-3 pitfall be added to `docs/project-notes.md`, as f1 asks? Suggested: yes.
12. Should Retry stay enabled and spinner-free during a read, now that a press is swallowed (stats_screen.dart:55)? Suggested: yes, with a "reading" line if the delay shows.
13. Is the design doc's "no device IDs" line to be reworded to protocol §8c's wording (finding 4)? Suggested: yes.

## Numbers against targets

- phone-consent ran 193 turns (`run.log:37`) against the brief's aim of 80-120.
- `stats-bug-report.md:24` still claims "all 12 fail on the old code"; the same paragraph gives 5/5 and 6/7, and the review measured 11 of 12 (`stats_crash_button_test.dart`'s no-button case passes on the old code). `run-findings.md` adds f3's dialog-no file passing on the old code, which the f3 report still presents as red-first.
- Host counts disagree across the run: 570 (f1 report), 570 (f2), 576 (f3), 566 (stats-bug), and 580/580 measured by the f2 and f3 reviews; phone 521/526/505. No report quotes the final count once, which the first review asked for.
- f3-report.md:50 gives `fake_crash.dart` as 55 lines; `wc -l` says 58.
- File aim ~300 (hard 400): host_text 374, settings_screen 371, live_stats 369, connect_screen 353 — over the aim, none over the hard limit.
- tv-consent report's suite (62 passed, 1 skipped) and host 580 are the last figures I trust; I ran no suite.

## Could not check

- A device: Sentry sending from a DSN build, the two prompts' look on a phone and a TV panel, the legacy-`shareStats` migration, a refused prefs write (host id), the crash button on a real build, and "Play on this phone" uploads.
- `sentry_flutter` 10.4.0 internals: its own handlers, `Sentry.close()` then re-`init`, and what `SentryEvent.fromJson` drops after the beforeSend round trip.
- Every suite at HEAD (read-only job): counts come from `run.log`, the reports and the worker reviews.
- The runner's old-code red runs: recorded in `run.log`, not re-run here.
- What exit code 4 means for consent-model, stats-bug, phone-consent, f1 and f3 in `run.log`; the hand-fixes' own runs logged 0.
- That the CI DSN actually reaches a store build, and whether the worker's `.github/` and `codemagic.yaml` denial was real (both are now hand-fixed).

## Commit message

Review sentry1 round 2: one must, nine should

The first round's four musts are fixed; read as a whole, the run keeps one:
a connection that lands under the launch prompt leaves Connect up for good.
Also carried: the crash-off test no longer pins the enabled guard, the host
id retry outlives its host and logs nothing, the design doc still says no
device IDs, the team rule's comment is stale, four catches log nothing, and
the TV release, phone-hosting names and f3's report claims are unpinned or
wrong. Code-health records two of the items the verdicts sent it.

## Status row

- **M14 sentry1 run review, round 2 (Nov 16, 2026):** 1 must, 9 should, 18 could — the CI DSN, the stats-off listener, player names, kept answers and the in-process player are fixed; open: the deferred Connect pop, the unpinned crash-off test, the host-id retry, the design doc's device-ID line, the unlogged catches and the code-health gap.

## Delete

- none
