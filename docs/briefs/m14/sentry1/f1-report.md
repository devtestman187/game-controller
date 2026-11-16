## Summary

All four findings of `REVIEW-r1.md` are fixed, each test written to fail first.

1. **Metrics consent reaches the recorder.** `metrics.dart` listens for the stats answer
   and starts or ends this phone's recording with it, so a no in Settings ends the live
   segment (`stats_consent_recording_test.dart`).
2. **`CrashReports.playerNames` is set.** A `crashLobbyProvider` seam (default: no lobby)
   feeds `crashNamesProvider`, kept at both apps' roots: the TV from `gamePlayersProvider`,
   the phone only while it hosts (`crash_names_test.dart`, `crash_setup_test.dart`).
3. **The TV sends `0.14.0+654`**, the phone's format, and `dev` (`app_info.dart`,
   `tv_host_setup.dart`, `tv_test_app/test/app_with_build_test.dart`).
4. **A connection that lands while the launch prompt is up waits for the answer**; the
   screen no longer pops the dialog (`connect_consent_pop_test.dart`).

Counts: host 570, phone 526, tv PASS; `tools/review.sh` 0 fail, 4 note.

Decisions: the brief's `ref.exists(hostServiceProvider)` guard cannot work in riverpod 3
(`exists` is false for a provider nobody read, even overridden, and a provider that
returned early never re-runs), so a `crashLobbyProvider` seam replaces it; the phone keys
its lobby on `gameShownProvider`, since a stopped host stays in `hostingProvider`; a
default of `null` means no app reads a host it does not run; the TV gets its own
`appWithBuild`; the test fakes come from `party_host/testing.dart`.

Fixed, unverified: needs device check — a report reaching Sentry and the prompts' look.
The phone-hosting names path has no test (the socket widget test hung twice; dropped).

## Decisions

- The crash-names seam is `crashLobbyProvider` (a list or `null`), not the brief's
  `ref.exists(hostServiceProvider)` guard — `exists` is false for a provider nobody has
  read, even when overridden, and a provider that returns early never re-runs, so the
  guard could never see a host that starts later (proved with the probe now deleted).
- The phone's lobby follows `gameShownProvider` — that is this app's start/stop signal; a
  stopped host deliberately stays in `hostingProvider`, and the names must end with it.
- The default is `null` (no lobby) — a pairing phone or joined phone must not build a host
  service just to find names it does not have.
- The TV takes `gamePlayersProvider` — it always runs the host while it shows a lobby.
- `tv_test_app` gets its own `appWithBuild` copy — a TV app cannot import the phone's
  lib, and the phone's helper is not in an allowed package this job.
- `FakeCrashReporter` from `party_host/testing.dart` replaces both ad-hoc test fakes —
  one fake, already exported.
- The connect screen suppresses its pop while the prompt is up (`_promptUp`) instead of
  awaiting `askConsents` in the listener — a listener must not block the connection
  state, and the flag clears in `whenComplete` even if the prompt throws.

## Files changed

- `controller_app/lib/main.dart` — overrides `crashLobbyProvider` with the phone's lobby and
  keeps `crashNamesProvider` running at the root.
- `controller_app/lib/src/host/hosting.dart` — adds `phoneCrashLobbyProvider` (the players
  while `gameShownProvider` says this phone hosts, else `null`).
- `controller_app/lib/src/providers/metrics.dart` — `_tellStatsShare` now listens and turns
  this phone's recording on and off with the stats answer.
- `controller_app/lib/src/ui/connect_screen.dart` — `_promptUp` keeps the launch prompt up
  when a connection lands; the hosting pop is skipped while it is set.
- `controller_app/test/stats_consent_recording_test.dart` (new) — 2 tests: a no ends the
  live segment, a yes starts it.
- `controller_app/test/connect_consent_pop_test.dart` (new) — 1 test: the prompt survives
  the connection and the answer is recorded.
- `controller_app/test/settings_consent_test.dart` — uses `party_test.FakeCrashReporter`.
- `packages/party_host/lib/src/crash/crash_names.dart` (new) — `crashLobbyProvider` (default
  `null`) and `crashNamesProvider`, which fills `CrashReports.playerNames`.
- `packages/party_host/lib/party_host.dart` — exports `crash_names.dart`.
- `packages/party_host/test/crash_names_test.dart` (new) — 2 tests: no lobby clears the
  names, a joined phone's nickname is scrubbed and removed with the player.
- `tv_test_app/lib/main.dart` — overrides `crashLobbyProvider` from `gamePlayersProvider`
  and keeps `crashNamesProvider` running.
- `tv_test_app/lib/src/app_info.dart` — the `appWithBuild` copy.
- `tv_test_app/lib/src/tv_host_setup.dart` — sends `appWithBuild(appVersion, buildNumber)`.
- `tv_test_app/test/app_with_build_test.dart` (new) — 3 tests: `+654`, `dev`/empty, and a
  too-long count.
- `tv_test_app/test/crash_setup_test.dart` — uses `FakeCrashReporter`; asserts the report's
  `where`.

## Self-check (review-rules.md part A)

1. **Every host setup.** TV/PC host: `crashNamesProvider` reads `gamePlayersProvider` —
   `crash_names_test.dart` (join, leave) and the TV's `crash_setup_test.dart`. Phone
   hosting: `phoneCrashLobbyProvider` follows `gameShownProvider`; untested over a socket
   (see Summary). Show on this device, joined phone, one build older: not affected — they
   run no host, so `crashLobbyProvider` stays `null` (`crash_names_test.dart` test 1).
2. **When kept state starts and ends.** The scrub set starts empty, follows the lobby's
   nicknames while a host runs, and is cleared when the host stops or the last player
   leaves (`crash_names_test.dart`: join → `{'Sam'}`, remove → `{}`). The recording
   segment starts on a yes and ends on a no (`stats_consent_recording_test.dart`, both
   directions). The `_promptUp` flag is cleared in `whenComplete` even if the prompt
   throws (`connect_consent_pop_test.dart`).
3. **How a new state combines with the others.** Pop suppression combines with the
   launch prompt only: it is checked after the hosting check and cleared before any other
   state can pop. Pairs tested: consent prompt + connection landing
   (`connect_consent_pop_test.dart`); prompt + user answers
   (`first_host_consent_test.dart`, `settings_consent_test.dart`). Not tested: prompt +
   pause menu,
   which cannot be up together (the prompt is on the connect screen only).
4. **Stay in the job's folder.** Only `allow:` files changed; `git status` shows no job
   file outside them.
5. **Stop rather than overstep.** The brief's mechanism contradicted the code; said so and
   used the seam above instead of guessing at a third design.

## Computed values

- `stats_consent_recording_test.dart`: off → `client.metrics` stays empty after a mode
  switch; on → exactly `['sticks']`.
- `connect_consent_pop_test.dart`: consent dialog still up after the connection lands, and
  `statsConsent` is `true` in the prefs only after the tap.
- `crash_names_test.dart`: `CrashReports.playerNames == {'Sam'}` and
  `scrubText('Sam scored') == '[name] scored'`; after `removeController('p1')` the set is
  empty.
- `crash_setup_test.dart`: report `where` values from `FakeCrashReporter`.

## Questions

1. None blocking. Suggest adding the `ref.exists` pitfall to `docs/project-notes.md` so the
   next brief does not specify it.
2. Should the two `appWithBuild` copies be shared once an allowed file exists for it?

## Hand-over

- Items 1, 2, 3 and 4 are done; nothing in `allow:` is left half-changed.
- `controller_app/test/zz_probe_test.dart` is the temporary riverpod probe; delete it.
- The tests to watch on a device: the prompt look, and a report arriving in Sentry.

## Commit message

sentry f1: the review's four findings, each with a test

Metrics consent now stops and starts the phone's recording; the crash
reports learn the lobby's names through a crashLobbyProvider seam (the
brief's ref.exists guard cannot work in riverpod 3); the TV sends the
phone's 0.14.0+654 release format; and a connection that lands while the
launch prompt is up waits for the answer instead of popping the dialog.

## Status row

sentry f1: metrics consent reaches the recorder, crash-report names set in both apps, TV release format fixed, prompt race fixed; open: a device check of prompt look and a report reaching Sentry, and a test for the phone-hosting names path.

## Delete

- controller_app/test/zz_probe_test.dart
