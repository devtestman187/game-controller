# M14 bugs12 f1: first host consent fix

## Summary

Fixes the B-023 review's findings 1, 2, 3 and 4. The consent prompt now belongs to the host route.

- **Finding 1 (must):** `_askHostConsent` is gone from the Connect panel's "Host a game". The button pushes
  `HostScreen` straight after `hosting.start`, with nothing between the start and the push, so the own client's
  link cannot take the panel (or the push) away. `_HostScreenState.initState`'s post-frame callback (mounted check
  first) steps the first-frame log and then calls `_askConsent()`: it reads `party.statsStateProvider` and, when
  `consent == null`, awaits `party.askConsent(context, ref)` over the route's first frame. A first frame has no
  round, so the prompt is never asked during one; a prompt closed without an answer still leaves the host running,
  and the next host asks again.
- **Finding 2 (must):** "an adult who said yes is not asked again" now has the first host answer **share** and
  asserts the host route is already up under the prompt (which the old code fails), then that the second host
  shows no prompt. It was not deleted, because it also pins the "share" answer.
- **Finding 3 (should):** `answerConsent` takes `mayBeAbsent` (default false) and `expect`s the dialog unless it is
  true; `enterHostMode` forwards it. Callers that broke were given `mayBeAbsent: true` only where a prompt is not
  expected (second host, saved answer): `host_mode_test` (both second hosts), `host_own_player_test` (both second
  hosts), `host_stats_test` (saved `statsConsent: true`), `settings_stats_row_test` (through `_hostWithStats`, for
  `FakeStats(consent: true)`).
- **Finding 4 (should):** the new test is `controller_app/test/first_host_consent_link_test.dart` (the brief's
  `tests:` rule puts new tests in the sibling file). It waits for the own player's link (`hostReady`, real clock)
  and a real socket phone (`joinPhone`, `HttpOverrides.global = null`) to arrive **while the prompt is up**, then
  answers and checks the route is still on screen and `phone-b` is among the host's players.

Test counts I ran: `first_host_consent_link_test.dart` 1/1; `first_host_consent_test.dart` 4/4; the affected set
(`settings_stats_row`, `host_stats`, `host_mode`, `host_lifecycle`, `phone_host_stats_lifecycle`) 36/36; the full
phone suite 484/484 (483 before this job + the 1 new test). No new test run against the old code in this job (no
revert allowed); the old-code failure rests on `expect(find.byType(HostScreen), findsOneWidget)` after picking the
mode, which the old code has not pushed yet — the runner's record should confirm it.

**Fixed, unverified: needs device check.** The device check is the point of finding 1: host from the Connect screen
on a real phone, answer the prompt, and the host route must be up with its bar and "Stop hosting".

## Decisions

- Ask on the host route's first frame, not on the Connect panel: the panel is rebuilt away by the own client's link
  (finding 1), and the route's first frame is the earliest moment the host is up and no round exists.
- Guard the post-frame callback with `mounted` and start `_askConsent()` with `unawaited`: the callback must not
  keep the frame waiting, and a route gone before its first frame asks nothing.
- `_askConsent` is a private method rather than inline code: it needs its own doc comment (why the prompt lives
  here) and keeps `initState` short.
- Keep an existing test and make it fail on the old code (brief item 2's first option) instead of deleting it: the
  "share" answer is the one the settings row reads, and the prompt's position is now pinned in it too.
- Run the prompt's dismissal and second-host cases unchanged otherwise: they already covered "answered" and
  "dismissed" and still pass on the new placement.

## Self-check (review-rules part A)

1. **Every host setup.** TV/PC host untouched (`tv_test_app`'s own first-launch consent). "Play on this phone":
   `first_host_consent_test` test 1 and `first_host_consent_link_test`. "Show on this device": test 4 in
   `first_host_consent_test` (`hostOnDevice`). Joined phone: the link test joins `phone-b` under the prompt. Older
   build: no protocol or saved-format change (the answer is still `statsConsent`, `live_stats.dart`).
2. **When kept state starts and ends.** The prompt starts on the route's first frame and ends on either answer
   (saved through the stats service) or dismissal (nothing saved); the host runs either way, and a dismissal makes
   the next host ask again — `first_host_consent_test` "dismissing the prompt without an answer still hosts, and the
   next host asks again". Nothing is timed or held while no round runs.
3. **How a new state combines with the others.** The prompt is a modal over the host route's first frame, where no
   round, pause menu or away state exists yet, so those pairs cannot meet; the link test covers the two things that
   do happen under it (the own player pairing, a phone joining), and the lifecycle tests
   (`host_lifecycle_test`) still pass.
4. **Stay in the job's folder.** Only `controller_app/lib/src/host/host_screen.dart`,
   `controller_app/lib/src/ui/connect_panels.dart`, `controller_app/test/**` and this report changed.
5. **Stop rather than overstep.** Nothing needed outside `allow:`; no brief/code contradiction found.

## Blocked

Not blocked.

## Hand-over

- Needs the owner's device check (above): the whole job is about a bug the widget clock cannot show.
- The runner should record `first_host_consent_link_test.dart` on the old code; its first `HostScreen` expectation
  is the one that fails there.
- Questions (not acted on): if a host could be stopped while the prompt is up (no path reaches it today, since the
  dialog is modal over the chip and the back press), the route's `disposed` pop would close the dialog, and
  `party.askConsent`'s trailing `ref.read(statsServiceProvider)` would run on a possibly disposed ref — a guard
  inside `party_host` may be worth a later job.

## Commit message

Fix the first host consent prompt to ask on the host route

The Connect panel asked the B-023 consent prompt after the host started, but the start points this phone's client
at its own player, which rebuilds the panel away: on a device the answer was followed by a dropped route push, and
the phone hosted with no screen or Stop. "Host a game" now pushes the host route at once, and the route asks the
prompt on its first frame, where no round exists. The test helper now fails when the first host asks nothing
(`mayBeAbsent` for a second host or a saved answer), the "said yes" test really answers share first, and a new test
links the own player and joins a socket phone under the prompt before answering.

## Status row

- **B-023 first host consent:** fixed for the review's findings 1-4 (prompt on the host route's first frame, tests
  that fail on the old code, the helper's silent miss removed); open: the owner's device check.

## Delete

- none
