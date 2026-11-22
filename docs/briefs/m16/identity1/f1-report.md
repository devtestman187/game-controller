# f1 report: identity1 fix round 1 (REVIEW must 2, two doc lines)

## Summary

- **Tests first.** NEW `controller_app/test/host_lists_identity_test.dart`, 2 tests. Written and run
  before the code: both failed at the welcome assertion with `Actual: ['metrics', 'rating']` (the host
  said no identity), then passed with the one-line host change. Re-run twice more: green both times.
- **Must 2, the host's list.** `LiveHostService` (the TV, the PC and a phone that hosts all build it)
  now offers `Capability.identity` beside `metrics` and `rating`, so a phone's welcome carries it and
  `client_connection.dart:218-219` sends the phone's `set_character`, which was dead in the apps.
- **Must 2's `storage.dart` half: not done, on purpose.** `controller_app/lib/src/storage.dart:55` is
  the *phone's hello* list, not a host's welcome (a welcome is built from the host server's own list,
  `host_server.dart:80`), and the client library already adds `identity` to every hello
  (`ControllerIdentity.libraryCapabilities`), which `phone_metrics_test.dart:303` pins. Putting it in
  the app's own list costs nothing but breaks `controller_app/test/joined_view_test.dart:38` (it pins
  `own.capabilities` to `[metrics, rating, layout, status]`), a file outside this job's `allow:`. I
  tried it (both tests above plus `joined_view_test` in one run) and reverted; Question 1.
- **Docs.** `protocol.md` §8d no longer claims "never during one": a phone that re-pairs mid-round
  has its hello's character taken at once. `i1d-report.md` Q1 now says `players`/`chars` already
  reach an app host (the gate for a host message is the session's hello, `host_server.dart:225`), and
  what is missing is only the host's offer; its suggestion and hand-over line said "two lists" and
  "the feature", both corrected.
- **Checks.** `tools/mine.sh` OK (2 files formatted, 2 packages analyzed, 2 tested; exit 0).
  `tools/check.sh format analyze phone host connection` **all PASS**: format 5 s, analyze 13 s,
  connection 338 tests 16 s, host 89 s, phone 67 s. The connection count is 338 because i1d's two
  `m9_test` failures no longer exist: `m9_test.dart:35` already expects `[..._both, identity]`, so it
  needed no change here.

## Files changed

- `packages/party_host/lib/src/host_service.dart` — the one code change: `LiveHostService`'s server
  capabilities gain `Capability.identity`, with the comment saying what it is for (M16 identity).
- `controller_app/test/host_lists_identity_test.dart` — NEW, 2 tests, 172 lines.
- `docs/protocol.md` — §8d's `set_character` paragraph: the rule is "answers at once in the lobby and
  between rounds, holds during a round", plus the re-pairing hello exception.
- `docs/briefs/m16/identity1/i1d-report.md` — Q1's wording, the suggestion under it, and the
  hand-over's "capability lists" → "capability list".
- `docs/briefs/m16/identity1/f1-report.md` — this report.
- Not changed: `controller_app/lib/src/storage.dart` (see Summary and Question 1),
  `controller_app/test/phone_metrics_test.dart`, `packages/connection/test/m9_test.dart` (both already
  list `identity`; no expectation needed widening).

## What each test shows, and the values it computed

| Test | Setup | Expected |
|---|---|---|
| a phone that hosts lists identity in its welcome, and answers the character its phone picks | `PhoneHost.live(..., playsHere: true)` ("Play on this phone"), its own player paired first, then a joined phone on the in-process link | welcome capabilities `['metrics', 'rating', 'identity']` (`['metrics', 'rating']` before this job); the own player is player 1 wearing `forPlayer(1)` = slot 1, ears, so the phone's hello crown (slot 4, crown) and its later pick (slot 2, bow) are both free; the answer to its `set_character` is (2, bow) |
| the TV host lists identity in its welcome, and answers the character its phone picks | `party.LiveHostService` with `FakeAdvertiser`, `FakeHostDirectories` and an `InProcessListener` for the test's phone (the host harness) | the same `['metrics', 'rating', 'identity']`; the phone is player 1 wearing (4, crown) and asks (2, bow) → (2, bow) |

Both tests are a real `ControllerClient`: they change `client.identity.character` after pairing, and
the app's own heartbeat (`_tellCharacterIfChosen`) is what sends `set_character` — so the phone
demonstrably sends it only because the welcome named identity, and the `player` answer is read back
from the client's own snapshot. The phone's pairing is awaited before the ask, so the player numbers
(and the characters) are fixed, not raced.

## Self-check (docs/review-rules.md part A)

1. **Every host setup.** The TV and the PC host are `LiveHostService` (the second test, via the host
   harness), a phone on "Play on this phone" is `PhoneHost.live` (the first test); "Show on this
   device" builds the same `LiveHostService` with no own player, so the same welcome. A joined phone is
   both tests' subject. A peer one build older has a host that lists no identity: the same code path
   then leaves the client's `set_character` unsent (`client_connection.dart:219`), which is the gate
   the first assertion of each test measures from the welcome side.
2. **When kept state starts and ends.** This job adds no kept state: the capability list is a
   constant, and the welcome that carries it goes once per connection. With nothing going on there is
   no player message and no ask: the second `expect` only runs after the phone itself changed its pick.
3. **Combining with other states.** The pause menu, the host away, a player away, "Get ready", a
   dropped link, the results and leaving all act on the `set_character` *hold*, which i1d owns and
   this job does not touch; its tests ("a change during a round waits for the round to end…") still
   pass in the `connection` and `host` suites. The welcome and the character reservation at pairing
   are unchanged.
4. **Job folder and `allow:`.** Only `host_service.dart`, the new test file, `protocol.md`,
   `i1d-report.md` and this report were written. `storage.dart` was edited for one run, then restored
   byte for byte (`git diff` shows no change). Three things moved without me: `run.log` is the
   driver's; the `tv_test_app/windows` generated registrants were reverted by `tools/mine.sh`'s own
   churn step; and `site/shots/*.png` were rewritten by the `phone` suite's screenshot tests when
   `tools/check.sh` ran — `site/shots/` is on `tools/churn.sh`'s list, so the runner's revert puts
   them back. I ran no git command that changes anything.
5. **Stop rather than overstep.** `controller_app/lib/src/storage.dart:55` stays as it is: the brief's
   "add identity to both capability lists" was written for a host list it is not, and adding it
   there breaks `controller_app/test/joined_view_test.dart:38`, outside `allow:`. Question 1 says what
   a later job needs to widen.
6. **Every look.** No UI in this job: no widget, no menu look, no TV look, and no look-sized box. The
   one visible change (a phone can now change its character against a real host) is drawn by i1e's
   settings and taken notice, unmodified here.

## Questions

1. **Should `joined_view_test.dart:38` gain `identity`, so `storage.dart` can list it?** As it stands
   the phone's hello gets `identity` from `ControllerIdentity.libraryCapabilities` and the app's own
   list does not need it; the brief asked for both, and the second half needs a one-line test change
   in a file this job may not touch. Suggested: leave the app list as it is (the library owns the
   capability), or widen `joined_view_test.dart:38` in the next phone job and then list it in
   `storage.dart` too.
2. **Is `m9_test.dart` still to be widened?** It already is: line 35 expects
   `[..._both, Capability.identity]`, so it needed no change in this job; the same goes for
   `phone_metrics_test.dart:303`. Nothing else in the tree pins a welcome or hello list exactly.

## Suggestions (not acted on)

- Add a one-line note to `LiveHostService`'s dartdoc listing what the host offers (`metrics`,
  `rating`, `identity`), so the next capability is added in one place with its reason next to it.
- `joined_view_test.dart:38` would read better as `contains`/`isNot(contains(view))` than as an exact
  list: every new phone capability will otherwise cost a test edit.

## Commit message

host: offer identity, so phones can change character

LiveHostService now lists Capability.identity beside metrics and
rating, so every welcome (TV, PC, a phone that hosts) offers it and
a joined phone's set_character, which was gated on that offer, now
reaches the host: the character change works in the real apps.
Two new phone tests pair on the in-process link against the phone
host mode and against the host harness, check the welcome and read
the player answer back from the client.
protocol.md says a re-pairing hello's character is taken at once
instead of claiming changes never land during a round, and i1d's
Q1 now says players and chars already flow to an app host.

## Status row

| identity1 f1 | done: the host's welcome lists `Capability.identity` (`host_service.dart`), so `set_character` reaches a real host; 2 new tests (phone host mode and TV host harness); `protocol.md` §8d says a re-pairing hello's character is taken at once; i1d Q1 corrected; format, analyze, connection (338), host and phone PASS | open: `storage.dart:55` left without `identity` because `joined_view_test.dart:38` pins the phone's hello list (outside f1's allow — Question 1), the blank-nickname "Player N", the six-parameter painters, i1g not started |

## Delete

- none
