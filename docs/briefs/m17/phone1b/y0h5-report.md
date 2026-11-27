# phone1b y0h5 report: away player's host pick kept over a pause

## Summary

- `ChoiceRound.resume()` no longer starts an away timer for a player whose pick was stored during the pause. A new private set `_pickedWhilePaused` is filled in `pick()` while paused and cleared at the end of `resume()`.
- The pause test "already away when the pause starts" no longer has the fixed `Future.delayed` before `pause()`.
- "keeps it after resume" asserts no change event for 700 ms after resume (grace is 300 ms).
- "host pick survives" now uses a player who is away before the pause (phone-2 never connects) and expects the host pick after resume and the grace.
- Dartdoc at `choice_round.dart:38` says "the build stop's default card" instead of "Save +2".
- `choice_round_test.dart`: the shop-round test asserts `defaultId == 'save'` and the lock before the pick (see question 3 for `byDefault`).
- Checks: `tools/mine.sh` passes (9 files formatted, `packages/connection` analyzed, 62 tests pass; `party_host` 55 tests pass).
- Mutation checks (temporary, reverted): without the `_pickedWhilePaused` guard the host-pick test fails in both transports; without the `byDefault` guard the "already set to the default" test fails in both transports.

## Files changed

- `packages/connection/lib/src/choice_round.dart`: new `_pickedWhilePaused` set; `pick()` adds the player while paused; `resume()` skips those players and clears the set; `defaultId` dartdoc says "the build stop's default card".
- `packages/connection/test/choice_round_pause_test.dart`:
  - "already away when the pause starts": removed the `Future.delayed(_insideGrace)`; the wait is the existing `_dropPhones` (server snapshot shows phone-1 disconnected).
  - "already set to the default ... keeps it after resume": waits until both players are locked (new `_untilAllLocked`, `_playerCount = 2`), subscribes to `changes`, and expects 0 change events after resume and `_pastEnd`.
  - "host pick ... survives resume" renamed to "... for a player away before it survives resume": no phone-2 connects, so the round starts with phone-2 away; pause, pick for phone-2, resume, wait `_pastEnd`, expect `build` x3 with `byDefault: false`.
- `packages/connection/test/choice_round_test.dart`: the shop-round test adds `expect(s.round.defaultId, 'save')` before the pick.
- `docs/briefs/m17/phone1b/y0h5-report.md`: this file.

## Computed values

- Grace `_graceMs` = 300 ms; `_pastEnd` = 700 ms; `_insideGrace` = 100 ms. The expectations after resume wait 700 ms, past the grace.
- "already set to the default": change events after resume = 0 expected. Before the test was reshaped, the count was 1, from phone-2's own default (both phones were away), which is why it now waits for both to be locked.
- "host pick ... away before it survives": expected `ChoiceOutcome(build, count 3, byDefault false)`. Without the guard the outcome is `save x1 default` (grace 300 ms expires after resume).
- Test count: `packages/connection` 62 pass (both transports), `packages/party_host` 55 pass.

## Brief items not done as written

- Item 2 asked for a poll on a public signal that the round has seen the drop. The round has no such signal: `changes` fires on picks, defaults and close, not on a drop, and it has no getter for away timers. I removed the fixed delay and relied on the snapshot wait in `_dropPhones`, plus the round subscribing to `server.changes` in `start()` before the test's own listener. That ordering is reasoned, not measured. See question 1.
- Item 4 asked for `byDefault: true` to be asserted before the pick. `ChoicesMessage` carries `picked` and `locked` but not `byDefault`, and `lockedIds` does not say why a player is locked. The only public way to see `byDefault` is `close()`. The test asserts what is visible. See question 3.

## Review-rules part A self-check

1. Host setups: the pause tests run under `webSocket` and `inProcess` (both transports, `TestTransport.values`). The round's tests are with a TV-style host (`startHost`) and phones via `WirePhone`; a phone on "Play on this phone" and a peer one build older are covered by the existing `phone-2` old-phone setup in `_setup` (no capability). Not covered here: the phone-side UI.
2. Kept state: the pick set starts empty at construction, is filled while paused, and is cleared at `resume()`. Nothing paused means nothing kept. Test: "a host pick made during the pause for a player away before it survives resume".
3. Combinations: pause with a host pick (kept), host away / player away (the away player's grace is held through the pause), "already set to default" (not re-armed), dropped link during pause (test "a player who drops during the pause is not defaulted..." still passes), results (close while paused still works, test "close while paused ..." passes), leaving (dispose clears the pause, unchanged). Test: the pause file passes in both transports in the last `tools/mine.sh` run (62 tests in `packages/connection`).
4. Files: only the allow-listed files changed.
5. Stopping: no stop. Brief items 2 and 4 are reported above.
6. Looks: no UI change; no look-sized widget touched.

## Hand-over

- Open for Claude: the questions below.
- No deletions.

## Questions

1. Is removing the drop delay acceptable, given the round has no public drop signal and the ordering is reasoned, not measured? Alternative: add a public `ChoiceRound` signal (for example a `watching` count) so the test can poll for it.
2. The brief says the "already set to the default" test fails on the old `resume()` that re-arms the grace. The code before this change already skipped `byDefault` players in `resume()`; the test pins that guard and fails only when it is removed. Is pinning it enough?
3. `byDefault` is not visible before `close()`. Do you want a read-only getter (for example the held pick's `byDefault`) so the shop test can assert it before the pick?
4. After `dropAllConnections()` the phones reconnect on their own (host_server.dart:199 comment), so a drop-based "away" test can flap. The new host-pick test avoids drops by never connecting phone-2. Should there be a helper that drops one phone?
5. The pick set is cleared at `resume()`, as the brief asks. If the player drops again after the resume, the normal grace applies and a host pick can still be overwritten. Should the set last until the player reconnects or the round closes?

## Suggestions

- A `ChoiceRound` getter for held picks (question 3) would also make the review's `ChoicesMessage` coverage easier.
- Add a one-phone drop helper to `wire_phone.dart` or `helpers.dart`, so "away" tests do not depend on the reconnect timing.

## Commit message — a draft

choice round: keep a host pick made during a pause

A host pick stored while a round is paused was overwritten by the default
after resume, when the player was away: resume() started a grace for every
away player that was not already on the default. The round now records the
players picked while paused and resume() skips them; the set is cleared at
resume. The pause tests drop the fixed delay before pause(), assert no change
event after a resume for a player already on the default, and test the host
pick for a player away before the pause. Each changed test fails on the
previous resume(). Docs: the default card is named by role, not by a game.

## Status row

phone1b y0h5 (choice round pause): done: a host pick made during a pause survives resume, and the pause tests pin it (both fail on the old resume); open: a public held-pick getter for byDefault, a one-phone drop helper, and whether the pick guard should last past a later drop.

## Delete

- none
