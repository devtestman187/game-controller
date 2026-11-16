# Stats screen: an error state when sessions() fails, and the crash button

## Summary

The Stats screen no longer sits on its spinner when the saved sessions cannot be read, and it now
carries the crash reports choice beside the stats one (design sentry-consent.md).

What changed:
- `stats_screen.dart`: `_load()` reads through `CrashReports.guard(..., where: 'stats_load')`, so a
  throw is reported (the guard's capture) and never escapes unhandled. `_readSessions()` sets a new
  `_failed` flag and clears it on the next good read; the failure also clears `_loading`, so the
  spinner is gone for good. The body gets one `_SessionsRead` value (entries, picked one, loading,
  failed, Retry).
- `stats_screen_widgets.dart`: new `CrashSharingButton` (public, same look as `_SharingButton`,
  key `statsCrash`, label follows `consentProvider.crash`, opens `askCrashConsent`, draws nothing
  where `crashAvailableProvider` is false); new `_SessionsFailed` card with
  `HostText.sessionsFailed` and a `statsRetry` `HostButton`; `_StatsBody` shows it in place of the
  list and keeps the status card, Export and Sharing working.
- `HostText.sessionsFailed = 'Could not read the saved sessions.'`, `HostText.retry = 'Retry'`;
  `ConsentText.crashOn = 'Crash reports: on'`, `crashOff = 'Crash reports: off'`.
- `docs/code-health.md`: the `stats_screen.dart:39` bullet is gone; the rest of that line stays.

Tests: new `packages/party_host/test/stats_screen_failure_test.dart` (5 tests) and
`stats_crash_button_test.dart` (7 tests); all 12 fail on the old code (both files were run against
it first: 5 and 6 of 7 failed, the passing one is the "no button where reports are unavailable"
guard). With them: `stats_screen_test` + `screen_fit_test` + the two new files = 33 passed.
`tools/check.sh format analyze host phone`: all PASS (host 566 tests, phone 505).
`tools/review.sh`: 0 fail, 1 note (`host_text.dart` 373 lines, over the 300 aim, under the 400
limit).

Fixed, unverified: needs device check — the crash button on a real build with a DSN (the button is
invisible in every local build, test and dev run, so nothing here has seen it on a TV or a phone),
and the error card's look on a real panel (only the test fonts were measured).

## Decisions

1. The crash button hides itself (`SizedBox.shrink`) rather than the screen checking the provider,
   so both apps and both host types get one rule and no screen changes for a DSN-less build.
2. `crash == null` reads "Crash reports: off", like the Sharing button's null → off: an unasked
   question sends nothing, so the label tells the truth.
3. Icons: `Icons.bug_report` when on, `Icons.bug_report_outlined` when off (Material has no bug-off
   pair) — solid reads as active, the cloud pair on Sharing does the same.
4. Retry is a `HostButton` but not autofocused: Export keeps the remote's focus (an existing test
   presses select for Export), and a second autofocus in one scope is undefined; the remote reaches
   Retry with Tab, which a test does.
5. A failed read hides only the sessions area: the status card, Export and Sharing stay, because the
   adult can still export and change answers while the folder is unreadable.
6. Retry keeps the error card up until a read succeeds (no spinner flash): the card is the state the
   thumb is looking at, and a second failure reports again.
7. `_SessionsRead` is a small value object: the body would otherwise take 6 parameters, over the
   guideline's 5.

## Self-check (review-rules part A)

1. **Every host setup** — the TV/PC host and a phone hosting ("Play on this phone") build the same
   `StatsScreen`; the error state and the crash button are in that one screen, and a joined phone
   never shows it. Shown by the fit tests at 960×540 and 852×393
   (`stats_crash_button_test.dart`) and by `controller_app/test/host_stats_test.dart` in the phone
   suite (5 tests, pass).
2. **When kept state starts and ends** — `_failed` starts false when the screen is created, is set by
   a failed read, cleared only by a later good read; it dies with the route, so reopening the screen
   reads again. Nothing is timed. Shown by "Retry reads the sessions again and shows the table once
   they come".
3. **How the new state combines** — the error state only takes the sessions area while `_loading` is
   false; the two consent dialogs open over it and leave it unchanged underneath. Not a pause or
   round state, so none of the round states pair with it. Shown by "the crash dialog fits a phone"
   and "Export still saves the session files while the sessions could not be read".
4. **Stay in the job's folder** — every changed file is in `allow:`; no lib file touched ends over
   380 lines (219, 236, 373, 30).
5. **Stop rather than overstep** — nothing needed a file outside `allow:` and no rule had to be
   bent, so nothing was stopped.

## Hand-over

- The read is fire-and-forget through the guard: `_load()` returns the guard's future (which never
  fails) and both callers `unawaited` it, so a store that throws can never reach the zone handler.
- The error state has no autofocus of its own; if a later job wants the remote to land on Retry
  when the read fails, Export's autofocus has to give way first.
- Nothing here covers the phone's Settings crash switch (design sentry-consent.md asks for one); this
  job was the TV/Stats screen's button only.
- `host_text.dart` is at 373 lines (aim 300): the next text added there should go to a text file of
  its screen.

## Commit message

Show the Stats error with Retry, and add the crash reports button

A failing sessions() left the Stats screen on its spinner for good
(docs/code-health.md). It now shows "Could not read the saved sessions."
and a Retry, and the read runs through CrashReports.guard, reporting it
under 'stats_load'; Export and Sharing keep working.
New CrashSharingButton in the app bar, shown only where
crashAvailableProvider is true, its label following consentProvider.crash
and its press asking askCrashConsent. Texts in HostText and ConsentText;
the code-health bullet is removed.

## Status row

- **sentry1 stats-bug (Nov 16, 2026):** the Stats screen shows "Could not read the saved sessions." with a Retry when `sessions()` fails (reported as `stats_load`), and carries the "Crash reports: on/off" button where a DSN exists; check.sh passed (host 566, phone 505). Open: a device check of the crash button and the error card on a build with a DSN.

## Delete

- none
