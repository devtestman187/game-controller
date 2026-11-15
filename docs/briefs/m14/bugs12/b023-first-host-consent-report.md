# b023-first-host-consent report (B-023)

Fixed, unverified: needs device check.

## Summary

The phone now asks the host stats consent once, at "Host a game", before the host route opens (B-023). The
tap picks a way to host, the host starts, the adult gets the host's own consent prompt (`askConsent`, the one
the TV shows on first launch), and only then does the host route open. An answered phone (yes or no) is asked
nothing and hosts as before; a prompt closed without an answer still hosts, and the next host asks again.

- Code: a private helper `_askHostConsent` in `controller_app/lib/src/ui/connect_panels.dart`, called from the
  `hostGame` button after `hostingProvider.start` and before `Navigator.push(HostScreen)`. It reads
  `statsStateProvider.consent` and calls the existing `askConsent` when it is null. No new dialog, no new text,
  no change to the Stats screen or the Settings row.
- Tests: new file `controller_app/test/first_host_consent_test.dart`, 4 widget tests. On the old code 3 of the 4
  fail (no `consentDialog` ever appears); the fourth ("an adult who said yes is not asked again") passes on the
  old code too, by construction, and guards the answered path. All 4 pass now.
- Pins updated, intent kept: `test/support/host_app.dart` (`enterHostMode` answers the prompt, new
  `ConsentAnswer` enum and `answerConsent` helper), `host_mode_test.dart` (answers the prompt at its direct
  tap), `host_stats_test.dart` (consent is `false`, not `null`, after the first host; the Settings test leaves
  the prompt unanswered so Settings still has to ask), `settings_stats_row_test.dart` (two tests leave the
  prompt unanswered to keep the row's "not answered" state).
- Checks: `tools/check.sh format analyze phone` → all PASS. Format 4 s, analyze 19 s, phone 482 tests in 46 s.
- Counts seen: 4 tests in the new file (3 failing on the old code); 482 tests in the whole phone suite.

## Decisions

1. **Ask after `hosting.start`, not before it.** The brief's item 2 says "before `hostingProvider.start`", but
   the answer is read from and saved through `statsServiceProvider`, which is `hostServiceProvider.stats`, and
   the phone's `hostServiceProvider` (overridden by `phoneServiceProvider`) throws until a host exists. Asking
   before the start would neither read `consent` nor save the answer without moving consent out of the stats
   service (a `party_host` change, outside `allow:`). The prompt still comes at the "Host a game" tap, once,
   before the host route opens and before any round, which is what the brief's tests pin.
2. **Reuse `askConsent` exactly as it is.** The design asks for the existing prompt; the wording, keys
   (`consentDialog`, `consentYes`, `consentNo`) and the saved answer stay the TV's and the Stats screen's.
3. **Keep the helper next to its only caller.** One private function in `connect_panels.dart` (the file of the
   "Host a game" tap); nothing UI-shaped added to `hosting.dart`, whose `start` stays UI-free.
4. **`enterHostMode` answers the prompt with "don't share" by default.** Every hosting test now passes the
   prompt, so the shared helper answers it; "don't share" keeps stats uploads off in tests. Tests that need
   the unanswered state pass `ConsentAnswer.dismiss`.
5. **A dismissal is the back gesture on the dialog.** `askConsent` sets `barrierDismissible: false`, so the only
   way to close it without an answer is the system back; the tests and the helper pop the dialog the same way.

## Self-check (review-rules.md part A)

1. **Every host setup.** TV/PC host: unchanged (the TV's own `FirstLaunchConsent` is untouched; nothing in
   `tv_test_app` changed). Phone "Play on this phone": asks once, then the route opens —
   `first_host_consent_test` "Host a game asks the host's consent once". Phone "Show on this device": the same
   shared tap, so the same ask — same file, "dismissing the prompt...". Joined phone: no host starts, so
   nothing new — `connect_screen_test`/`pad_test` unchanged and green. A phone one build older: the answer is
   the same `statsConsent` setting, read at every host start, so an older build's answer shows no prompt —
   `first_host_consent_test` "an adult who said yes is not asked again" (prefs `statsConsent: true`).
2. **When kept state starts and ends.** The prompt starts after the host starts and ends on either button or a
   back dismissal; it holds nothing afterwards (the answer lives in prefs). Ends proven by
   `first_host_consent_test` tests 1 and 4 (dialog gone / still null, and asked again on the next host).
3. **How a new state combines with the others.** It is a modal dialog over the Connect screen, before the host
   route exists, so it cannot meet a round, the pause menu, the host away, "Get ready", results or leaving:
   test 1 asserts `HostScreen` is absent while the prompt is up. Not tested: backgrounding the app while the
   prompt is up (the host is started, so its start carries on; nothing pauses a round, as there is none).
4. **Stay in the job's folder.** `git status` shows this job's writes only: the report, `connect_panels.dart`,
   and five files under `controller_app/test/`. The tree's other modified files (`docs/design/*.png`,
   `site/shots/*.png`, `docs/briefs/m14/bugs12/run.log`, `tv_test_app/windows/generated_plugin_*`) and the
   untracked `run-*.patch` files were dirty before this job and are not mine.
5. **Stop rather than overstep.** Item 2's "before `start`" cannot be met as written; reported under Decisions
   rather than worked around with a second consent store or a prefs key copied into the app (a hard-coded
   identity, guideline §2).

## Files changed

- `controller_app/lib/src/ui/connect_panels.dart`: `_askHostConsent` helper (consent null → `askConsent`) and
  its call in the "Host a game" tap between `hosting.start` and the host route; import line widened to
  `askConsent`, `statsStateProvider`. 342 lines.
- `controller_app/test/first_host_consent_test.dart` (new): 4 widget tests, see below.
- `controller_app/test/support/host_app.dart`: `ConsentAnswer` enum, `answerConsent` helper, and
  `enterHostMode({..., ConsentAnswer consent = ConsentAnswer.dontShare})` that answers the prompt.
- `controller_app/test/host_mode_test.dart`: answers the prompt after its direct `hostOnPhone` tap.
- `controller_app/test/host_stats_test.dart`: consent expectation `isFalse` (was `isNull`) after the first
  host; the Settings test uses `ConsentAnswer.dismiss` so Settings still has to ask.
- `controller_app/test/settings_stats_row_test.dart`: `_hostWithStats` gains a `consent` parameter; two tests
  pass `ConsentAnswer.dismiss` to keep the row's "not answered" state.

## The new tests and the values they check

1. `"Host a game" asks the host's consent once, before the host route opens` — after the tap and the sheet:
   `consentDialog` 1, `HostScreen` 0; tap "Share stats" → route up, dialog gone, `statsStateProvider.consent`
   `true`, prefs `statsConsent` `true`.
2. `an adult who said yes is not asked again` — prefs `statsConsent: true` → no dialog, route up.
3. `an adult who said no hosts once and is asked no more` — via `enterHostMode` (answer "don't share"):
   consent `false`, prefs `false`; stop the host, host again → no dialog, route up.
4. `dismissing the prompt without an answer still hosts, and the next host asks again` — dialog up, popped with
   no result: route up, consent `null`, prefs `null`; stop, host again → dialog up again; "don't share" → route.
   This test waits for `host.started` before stopping the first host (see Suggestions).

Old-code run: tests 1, 3 and 4 failed with "Found 0 widgets with key [<'consentDialog'>]"; test 2 passed.

## Questions

1. Is asking *after* `hosting.start` but before the host route acceptable, or does Claude want the consent read
   moved out of the host's stats service so the phone can ask before starting? That would touch `party_host`,
   outside this job's `allow:`.
2. Should the host start log get a step for the consent wait? Today that wait counts inside the time to the
   route's first frame (`HostStartStep.firstFrame`), so a slow adult looks like a slow start.

## Suggestions

- A host stopped while its `start()` is still binding its server leaves the server listening: in this job's
  dismissal test, stopping the first host before `host.started` failed teardown with a pending HTTP server timer
  (the app's own "Stop hosting" path can only be reached once the route is up, so it is unlikely in practice).
  The test now waits for `started` before stopping. Worth a look in `phone_host.dart`/`hosting.dart` later.
- `host_stats_test`'s Settings test now leaves the prompt unanswered only to reach the Settings ask; if Claude
  would rather the Settings ask be tested from a fresh unanswered state another way, the `ConsentAnswer` seam
  is the place to change it.

## Hand-over

- Device check: on a phone build, host a game for the first time. The host's prompt should come after picking
  a way and before the game appears; "Share stats"/"Don't share" should both go straight to the game, and
  Settings → host Stats should show the answer with no second prompt. The back gesture should close the prompt
  and still open the game, and the next host should ask again.
- The answer's destination (Firebase) is not checked here: with consent yes, a finished hosted session should
  upload as the TV's do (the owner's original B-023 symptom).

## Commit message

Ask the phone's adult for host stats consent at the first host (B-023)

A phone's hosted sessions never reached Firebase because the phone never asked the
adult to share them; only the TV asked, on its first launch. "Host a game" now shows
the host's own consent prompt (askConsent, no new dialog) after the way to host is
picked, once, before the host route opens and never during a round. An answered
phone is asked nothing and hosts as before; a prompt closed without an answer still
lets the phone host and the next host asks again. New widget tests in
first_host_consent_test.dart fail on the old code; the hosting test helper answers
the prompt, and the consent pins in host_stats_test and settings_stats_row_test keep
their intent.

## Status row

- **B-023 first host consent:** fixed; the phone shows the host's own stats consent prompt once at "Host a game",
  before the host route opens, saves the answer, and asks nothing once answered (back-dismissal still hosts);
  open: the owner's device check, and the consent text/Stats screen and the Settings row (job b023-stats-card).

## Delete

- none
