# b023-first-host-consent review

## Summary

needs Claude

- must 2 · should 2 · could 2
- The host route is pushed only if the Connect panel's context is still mounted after the prompt, but starting the host makes `clientStateProvider` switch to the phone's own client, which rebuilds that panel away within a second; on a device the adult's answer is followed by `return` at `connect_panels.dart:125` and the phone hosts with no screen and no Stop. The tests cannot see it because `settle` never runs the real event loop.
- `first_host_consent_test.dart:35` passes on the old code, which its own report admits; the brief and review rule make that a must.
- `answerConsent` (`support/host_app.dart:183`) returns silently when the prompt is absent, so most hosting tests cannot fail if the new prompt stops appearing.

## Findings

- **must** controller_app/lib/src/ui/connect_panels.dart:125 `if (!context.mounted) return;` drops the host route on a device: `hosting.start` (hosting.dart:36) points `clientProvider` at the own client (providers/connection.dart:80, 97), so `ConnectionPanel` (connect_panels.dart:32) rebuilds from `_NoTvActions` to `_Waiting`/`_Connected` (connect_screen.dart:38 names exactly this) while the prompt is up, unmounting the button's context before the adult answers → the phone stays hosting invisibly, with no Stop anywhere (only host_screen.dart:76 stops it) → capture `Navigator.of(context)` before the await and push through it, or push the host route first and ask the prompt there.
- **must** controller_app/test/first_host_consent_test.dart:35 "an adult who said yes is not asked again" passes on the old code (report: "test 2 passed"), so it proves no new behaviour and breaks the brief's "each new test must fail on the code as it was" → answer "share" at the first host's prompt inside the test (which fails on the old code) and check the second host asks nothing, or drop the test because test 3 already covers "answered, so no prompt".
- **should** controller_app/test/support/host_app.dart:183 `if (dialog.evaluate().isEmpty) return;` hides the prompt's absence: every `enterHostMode` caller and the Settings-row tests (`settings_stats_row_test.dart:18`, `:73`) would still pass if the prompt never came up → take a `mayBeAbsent` flag (true only for a second host) and `expect` the dialog otherwise.
- **should** controller_app/lib/src/ui/connect_panels.dart:119 the host is started and listening (and advertising) while the adult reads the prompt, a window of seconds that did not exist before; no test has a phone join during it (self-check A3 answers only the round pairs) → add a consent-test case where a fake peer joins while `consentDialog` is up and check the answer still opens the route with that player listed.
- **could** controller_app/test/first_host_consent_test.dart:15 the test pumps only the fake clock (`settle`, pump_app.dart:137), so it cannot reproduce the panel rebuild of the first finding; a real-loop wait (`until`/`runAsync`) between the tap and the answer would have caught it → let the host's own link come up before tapping `consentYes`.
- **could** controller_app/test/first_host_consent_test.dart:31 the prefs key `'statsConsent'` is spelled in the test, duplicating `live_stats.dart:118`'s private key; pre-existing in `host_stats_test`, so only a note → if the key ever moves, these tests fail without a code reason; a small `party_test` accessor would keep it in one place.

## Decisions to confirm

- Decision 1 (ask after `hosting.start`, not before): the reason is true (`phoneServiceProvider` throws with no host, hosting.dart:101), but it is also what puts the route push across an await and behind the panel's lifetime (finding 1); whether to ask before the start by moving the read out of the stats service, or to ask on the host route, is Claude's call.
- Decision 4 (`enterHostMode` answers "don't share" by default): it changes the saved state of every hosting test (all now write `statsConsent: false`); harmless today, but it makes the shared helper opinionated about stats.
- Self-check A1's "asks once, then the route opens" is true of the widget tests only; it is the claim the device will contradict (finding 1), so the report's "Fixed, unverified" is what stands.

## Could not check

- No device or real-clock run, so finding 1 is from the code path (own client's `connecting` at controller_client.dart:197 after `service.start`) and not from a repro; the widget suite cannot show it.
- The old-code run of the new tests (the runner's record has no old-code log; the report's own admission is the evidence for finding 2).
- Whether consent answered mid-host reaches Firebase: `setConsent` triggers `uploadNow` (live_stats.dart:165-171), which skips the open session file, but the upload itself is out of this job.

## Commit message

Review the first host consent job (B-023): findings only

The phone asks for host stats consent at "Host a game" after the host starts and before the
host route opens; the review finds that the route push is gated on the Connect panel's context,
which the phone's own client link rebuilds away while the prompt is up, so on a device the
host opens no screen. Also: one new test passes on the old code (the report admits it), the
test helper answers the prompt silently when it is missing, and no test covers a phone joining
while the prompt is up. The phone suite passes (482 tests).

## Status row

- **B-023 first host consent:** reviewed; the change is small and the pins keep their intent, but the
  route push after the prompt is unsafe on a device (must) and one new test does not fail on the old code
  (must); open: Claude's decision on asking before the start or on the host route, then a fix job and the
  owner's device check.

## Delete

- none
