# sentry1: the run's review

## Summary

**Verdict: needs Claude's design** — 4 must, 13 should, 11 could. One fix batch clears the code findings;
the CI patches, the player-names wiring and three design choices need Claude or the owner first.
Five that matter most:
1. `release.yml`/`codemagic.yaml` still get no `SENTRY_DSN`, so every store build ships crash reporting off, while `docs/release.md:90` says the DSN is passed (ci-wiring items 1–2, never done).
2. `metrics.dart:46`: turning usage stats off in Settings no longer reaches the recorder, so the phone keeps counting and sending touches.
3. `CrashReports.playerNames` is never set in either app, so the name scrubbing the prompt and the release doc promise never runs.
4. `live_stats.dart:279`: a host pause and resume starts a new session that no phone re-answers, so a player who said yes counts as "not sharing" for the rest of the evening.
5. `session_player.dart:102`: a phone hosting "Play on this phone" never marks its own in-process player as sharing, so the host's own play data is dropped from every upload.
Hand-fix checked: phone-consent's `HAND-FIX` line (`run.log:48`) has its tests-first proof (four files, `run.log:58-61`) and its worker review (`f9fbf4dd`, 8 findings) — nothing missing there.
No `docs/briefs/m14/sentry1/STATUS.md` and no `run-findings.md` exist; the carry-over below comes from the eight job reports and seven worker reviews.
Unverified, mark "Fixed, unverified: needs device check" in the batch: Sentry sending from a DSN build, the two prompts' look on a phone and a TV, the legacy-`shareStats` migration, a refused prefs write (host id), the crash button on a real panel, and the DSN passing once the CI patches land.
Only the owner can answer: whether the in-process player always shares, whether answers survive a host pause, where player names come from, whether the TV's release is name+build, and who edits `.github/` and `codemagic.yaml`.

## Findings

- **must** `.github/workflows/release.yml:97` (and `codemagic.yaml:161`) the phone, TV and Windows bundles still end at the two FIRESTORE defines and the .ipa step trims only those, so brief items 1 and 2 are undone and every release build has an empty DSN → apply the review's Hand-over hunks (the worker's standing rule denies both paths, so Claude or a permitted job must) (from: ci-wiring review; pins: none)
- **must** `docs/release.md:90` "release.yml passes the two GitHub variables, and ios-testflight passes the Codemagic one" is false at HEAD, since neither build file changed → land the CI patches in the same commit as this sentence, or mark it as planned (from: ci-wiring review; pins: docs)
- **must** `controller_app/lib/src/providers/metrics.dart:46` the parent build's `ref.listen(shareStatsProvider, …)` that re-ran `_updateMetrics` was replaced by `_tellStatsShare`, which only calls `client.setStatsShare`, so a phone keeps recording and sending touches after the adult turns stats off and a yes given in Settings starts nothing until another setting or the connection changes → listen to `consentProvider.select((c) => c.stats == true)` and call `_updateMetrics` from it, plus a `stats_share_to_host_test`/`phone_metrics_test` case that turns it off mid-session and sees no further batch (from: phone-consent review; pins: phone)
- **must** `packages/party_host/lib/src/crash/crash_reporter.dart:51` `CrashReports.playerNames` has no caller in `controller_app/lib` or `tv_test_app/lib`, so `scrubEvent` always gets an empty name set while `ConsentText.crashBody:15` and `docs/release.md:80` promise names are removed → set it from the lobby's nicknames in both apps' host setup and clear it when the lobby empties, with a test that a name in an error becomes `[name]` (from: across jobs; pins: host + phone)
- **should** `packages/party_host/lib/src/crash/crash_start.dart:28` the handler only calls `previousFlutterError?.call(details)`, so when `FlutterError.onError` was null the error is no longer presented (`FlutterError.presentError`) — a reports-off build loses every uncaught framework error from the console, and the test always installs a previous handler → call `(previousFlutterError ?? FlutterError.presentError)(details)` and add a case with `FlutterError.onError = null` (from: sentry-core review; pins: host)
- **should** `packages/party_host/lib/src/crash/crash_start.dart:54` `await chosen.enable()` is unguarded on app startup, so a throw from `SentryFlutter.init` can abort `main()` before `runApp` → wrap it in `try`/`on Object`, leave reports off, log one line without personal data, and test it with a reporter whose `enable` throws (from: sentry-core review; pins: host + tv)
- **should** `packages/party_host/lib/src/crash/crash_reporter.dart:72` (also `sentry_reporter.dart:80`, `:90`) the `on Object` catches are empty, so a reporter that always fails or a scrubber that drops every report is invisible, against guidelines §2 → log one line with no error text through the package's `LogSink` at this boundary (from: sentry-core review; pins: host)
- **should** `packages/party_host/lib/src/host_id.dart:77` nothing stops a pending retry when `LiveHostService.dispose` runs, so a host stopped and restarted within the ~2 s window can have the stopped session's id written last, and the final failure goes only to `CrashReports` (silent with reports off) → pass a liveness check (or mint one id per app) and log one line on the last failure (from: host-id review; pins: host)
- **should** `packages/party_host/lib/src/live_stats.dart:279` `resume()` calls `_checkPlayers()`, which starts a new session for still-paired phones that never re-pair, and `SessionRecorder` keeps answers only in the collector, so a yes is lost for the rest of the evening → keep controller id → answer in the recorder and apply it when that player joins a session (from: stats-optb review; pins: host)
- **should** `packages/metrics/lib/src/session_player.dart:102` `'share': p.local || p.shares` leaves the phone host's own player out: it joins over the in-process link (`inProcess: true`, `local: false`) and nothing calls `setStatsShare` for it, so "Play on this phone" data is never uploaded even with a yes → treat `inProcess` like `local`, or have the host send the in-process client its own consent (from: stats-optb review; pins: host + phone)
- **should** `docs/protocol.md:207` (and the same words in `uploadable.dart:7`) says the uploaded session holds "no names or device IDs", but `playerJson` passes `install` (the persisted controller id) and `device` for every sharing player (`session_player.dart:102-111`) → either strip `install`/`device` in `uploadableSummary` or reword both sentences to what goes up (from: stats-optb review; pins: docs)
- **should** `packages/party_host/lib/src/ui/stats_screen.dart:114` `onRetry: () => unawaited(_load())` starts a read with no in-flight flag and leaves the button pressable, so two quick presses race and a slow failure can cover a newer table → a `_reading` flag set in `_load()` and cleared when it ends, with a test that a second press while reading reads once (from: stats-bug review; pins: host)
- **should** `packages/party_host/lib/src/ui/stats_screen_widgets.dart:24` `CrashSharingButton` is public although only `stats_screen.dart:100` uses it, and `party_host.dart:96` exports that library, so it is added to the public surface where its neighbour `_SharingButton` is private → make it `_CrashSharingButton` (from: stats-bug review; pins: host)
- **should** `packages/party_host/test/consent_prompts_test.dart:57` the only crash-dialog test here presses `crashYes`, and `crashNo`/"Don't send" is pressed by no test in the repo, so a dialog whose two buttons both pop true passes → add a `crashNo` case expecting `consent.crash` false, prefs false and `crash.disableCount` 1 (from: consent-model review; pins: host)
- **should** `site/shots/dpad.png:1` (with `menus`, `results`, `sticks`, `tilt`) the phone check's `site_shots_test` rewrote five PNGs outside `allow:` and they are still modified in the working tree → `git checkout -- site/shots` before the next job, or keep them on purpose and say why (from: phone-consent review; pins: none)
- **should** `packages/party_host/lib/testing.dart:9` the fake export was left out again, so `tv_test_app/test/crash_setup_test.dart:10` and `controller_app/test/settings_consent_test.dart:66` each hand-wrote a crash reporter beside the unused `FakeCrashReporter` → add `export 'src/testing/fake_crash.dart';` and delete the two local fakes (from: sentry-core review + across jobs; pins: tv + phone)
- **should** `packages/party_host/lib/src/text/consent_text.dart:16` (also `host_text.dart:267` and `docs/release.md:80`) both prompts and the doc say the answer can be changed "in settings", but the TV has no Settings crash or stats row — its controls are the Stats screen ("Crash reports: on/off", Sharing) → say where each host's switch is, or make the TV's words the Stats screen's (from: across jobs; pins: host + docs)
- **could** `packages/party_host/lib/src/live_stats.dart:168` `setConsent` writes `statsConsent` and `ConsentNotifier.setStats` (`consent_state.dart:65`) writes the same key first, so the design's "the notifier is the only writer" no longer holds → let `setConsent` change only its state on that path (from: consent-model review; pins: host)
- **could** `packages/party_host/lib/src/crash/scrub.dart:28` names are replaced as case-insensitive substrings, so `Sam` turns "same" into "[name]e" in messages and frames → match on `\b` word boundaries or say in the doc that over-replacement is intended (from: sentry-core review; pins: host)
- **could** `packages/party_host/lib/src/testing/fake_crash.dart:52` the fake records captures while `enabled` is false, unlike `SentryCrashReporter.capture`, so no test can catch a missing enabled check → have it ignore captures while off (from: sentry-core review; pins: host)
- **could** `packages/metrics/lib/src/uploadable.dart:13` any player entry without a `share` key is dropped, so a session saved before this build uploads with no players at all; and `:29` a team win filtered to one sharing member keeps `winners: [n]` → keep the old player list when every entry predates the field and drop `winners` when fewer than two remain (from: stats-optb review; pins: metrics)
- **could** `tv_test_app/lib/src/tv_host_setup.dart:95` the TV passes `release: versionLabel` ("0.14.0 (dev)") where the design says name+build and the phone uses `appWithBuild` ("0.14.0+654"), so two release formats ship for one product → use `appWithBuild(appVersion, buildNumber)` here too (from: across jobs; pins: tv)
- **could** `controller_app/lib/src/ui/connect_screen.dart:65` the screen pops itself with `maybePop` when a connection lands, so with the launch prompt up it pops the dialog instead, dropping the answer and leaving Connect open → skip the pop while a consent prompt is up, and pair a test with the prompt showing (from: phone-consent review; pins: phone)
- **could** `controller_app/test/coverage_all_test.dart:1` the file says "GENERATED … Do not edit" and the job added its two imports by hand → rerun `tools/coverage.sh` so the generator writes them (from: phone-consent review; pins: phone)
- **could** `controller_app/test/launch_consent_test.dart:68` (with `settings_consent_test.dart:24` and `consent_migration_test.dart:15`) these three assert less than their names say: the first two also hold on the old code and the migration one only checks that nothing was written → make each the contrast case its name claims, or rename it (from: phone-consent review; pins: phone)
- **could** `settings_text.dart:74` the Settings row still says stats are sent "only if an adult allows it on the device that hosts", while the switch is now this phone's own answer that also gates its uploads → reword next to `ConsentText` in a party_host job (from: phone-consent review; pins: phone + host)
- **could** no per-job review exists for tv-consent (run.log has none) and `docs/briefs/m14/sentry1/stats-bug-review-report.md` is untracked at HEAD, while `14dc30b` carries host-id's `host_id_test.dart` and `8c621c8` carries stats-optb's `live_stats_share_test.dart`, so those two commits cannot build their own suites → record only; commit a job's tests with its code, and review tv-consent before the milestone closes (from: across jobs; pins: none)
- **could** `packages/party_host/lib/src/text/host_text.dart:371` (also `controller_app/lib/src/ui/settings_screen.dart:371`, `live_stats.dart:380`, `connect_screen.dart:346`) four files this run touched sit past the ~300-line aim with no split and no code-health entry for two of them → split at the next change and record the sizes in `docs/code-health.md` (from: across jobs; pins: host + phone)

## Open questions

1. Does the phone host's own in-process player always share, or send its own answer? Suggested: treat it as sharing (the host's yes is what allows the upload), as finding 10.
2. Do consent answers survive a host pause and resume? Suggested: yes — remember them per controller in the recorder (finding 9).
3. Where do player names come from for the scrubber? Suggested: the lobby's nicknames in both apps, set on lobby change (finding 4).
4. Is the TV's Sentry release name+build like the phone's? Suggested: yes, `appWithBuild` (finding 22).
5. Who edits `.github/workflows/release.yml` and `codemagic.yaml`, since workers are denied? Suggested: Claude, in the same commit as the `release.md:90` fix.
6. Does a paired phone's launch ask its two questions outside Connect? Suggested: ask on the controller screen too when the launch has not asked (worker's Q1, unanswered).
7. Is a phone that never touched the old stats setting meant to be asked again rather than carried over? Suggested: yes, as built; a never-touched "on" is no answer.
8. Is dropping a report that cannot be scrubbed (Decision 5) wanted over sending a partly scrubbed one? Suggested: keep dropping.
9. Should `installCrashHandlers` install once per process? Suggested: yes, make it idempotent.
10. Should the `host_id_write` tag be camelCase like the other tags? Suggested: rename to `hostIdWrite` before more tags arrive.
11. May the crash row's words stay in `controller_app` until `ConsentText` owns them? Suggested: yes, logged in code-health; move them with the TV's row.
12. Is the stats prompt's "in settings" acceptable on the TV, whose control is the Stats screen? Suggested: no — fix with finding 17.
13. Should the Retry stay unfocused and spinner-free on the Stats screen? Suggested: yes, once the in-flight guard exists (finding 12).
14. Is a `--dart-define=SENTRY_DSN` TV build covered by the milestone's device check? Suggested: yes, one device pass covers both apps.

## Numbers against targets

- stats-bug report `stats-bug-report.md:24` claims all 12 new tests fail on the old code; the same paragraph gives 5/5 and 6/7, i.e. 11 of 12 — `stats_crash_button_test.dart` "no crash button where this build cannot send reports" passes on the old code, against the brief's "each new test file must fail on the code as it was".
- Per-job host counts do not line up: 515 (stats-optb report), 538 (sentry-core), 545 (host-id), 548 (consent-model), 554 (two reviews), 566 (stats-bug). The 515 was measured at 7eed4bda where the review counted 539; the rest differ because parallel jobs landed after each report. Quote the final count (566 claimed) once, not per job.
- phone-consent ran 193 turns (`run.log:37`) against the brief's "aim for 80-120 turns".
- File aim ~300 (hard 400, brief 380): `host_text.dart` 371, `settings_screen.dart` 371, `connect_screen.dart` 346, `live_stats.dart` 380 — over the aim, none over the brief's cap.
- Report format: `stats-bug-report.md:1` starts with a `#` title and its `## Summary` spans lines 3–33 (31 lines), where the brief asks for `## Summary` within 30 lines and no title.
- TV suite: 62 passed, 1 skipped (tv-consent report); host 566, phone 521 per the job reports — I did not re-run any suite.

## Could not check

- A device: Sentry sending from a DSN build, both prompts' layout on a phone in landscape and on a TV panel, the migration on a phone holding an old `shareStats`, and a first launch whose prefs write is refused.
- `sentry_flutter` 10.4.0 internals: whether its integrations install their own handlers, whether `Sentry.close()` then `enable()` restarts the SDK, and what `SentryEvent.fromJson` drops after the `beforeSend` round-trip.
- Whether the worker was really denied `.github/` and `codemagic.yaml`; only the ci-wiring report says so.
- Every suite at HEAD (read-only job): counts come from `run.log`, the job reports and the worker reviews.
- The old-code failures the runner recorded; no checkout was run.
- What the upload endpoint does with `install` ids or a one-member `winners`; the server is not in this repo.
- Whether rerunning `tools/coverage_imports.dart` would produce exactly the two hand-added imports (the tool writes files).
- tv-consent's diff was read by me only (no per-job review exists); its tests were not re-run.

## Commit message

Review sentry1: 4 must, 13 should, 11 could

The run is one feature across seven jobs: crash reporting with consent,
stats option B, the CI wiring and the docs. Read whole, it has four must
findings: the DSN never reaches release builds (ci-wiring items 1-2 not
done), release.md:90 says it does, the phone keeps recording touches after
stats are turned off, and player names are never wired into the scrubber.
The rest: an unguarded enable at startup, a lost stats answer after a host
pause, the phone host's own player never sharing, the false "no device IDs"
line, the unguarded Retry and the public crash button.

## Status row

- **M14 sentry1 run review (Nov 16, 2026):** 4 must, 13 should, 11 could — the DSN is not passed by either build file, `release.md:90` is false, the stats answer no longer reaches the recorder, and `CrashReports.playerNames` is never set; open: those four, the CI patches (Claude), the player-names wiring, the pause/resume and in-process answers, `site/shots` restore, and the device checks.

## Delete

- none

## Verdicts (Claude/driver, Nov 16)

Verified at file:line against HEAD before writing.
- must release.yml / codemagic.yaml DSN, must release.md:90: real; fixed by hand (commit 74159b5e). The worker was denied `.github/` and `codemagic.yaml`.
- must metrics.dart:46 stats off not reaching recorder: real; fix job f1 item 1.
- must CrashReports.playerNames never set: real; fix job f1 item 2.
- should crash_start presentError and unguarded enable: real; fixed by hand (74159b5e) with test crash_start_guard_test.dart. Idempotent install (Open question 9): not done, tests call it repeatedly; noted in code-health.
- should empty catches in crash_reporter/sentry_reporter (no log): minor; code-health.
- should host_id retry not stopped at dispose: minor (2 s window, only a stop+restart inside it); code-health.
- should resume loses answers: real; f2 item 1.
- should in-process player never shares: real; f2 item 2.
- should docs claim "no device IDs": real wording bug; the controller ID is kept on purpose (the privacy page uses it for deletion requests), so reword; f2 item 3.
- should Retry in-flight guard, CrashSharingButton public, crashNo test: real; f3.
- should site/shots PNGs modified: churn from site_shots_test, not ours; left unstaged (a restore was refused by the permission system).
- should fake export, local fakes: export fixed by hand; local fakes removal in f1 item 4.
- should "in settings" wording on the TV: real; fixed by hand (texts now say "on the TV, on the Stats screen").
- could setConsent second writer, substring scrub, uploadable old files, TV release format, connect pop, coverage_all hand imports, weak test names, settings_text.dart:74 wording, sizes, no tv-consent review: some in f1-f3 (fake while off, uploadable, TV release, connect pop); the rest go to docs/code-health.md.
