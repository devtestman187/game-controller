# M14 bugs14 f1 — the taken-colours band stays gone

## Summary

Finding 1 of the run review is fixed: the band's guard compared the host's answer with `state`, which the hide
had just set to null, so the next ~1 s heartbeat snapshot re-showed the band and restarted its timer — 5 s on,
~1 s off, for ever, and again after every round start or end. The notifier now keeps the pair it already said in
a private `_announced` field that neither the timer nor the view listener clears; the hide clears only the shown
`state`, so the look and text of the band are untouched.

- `controller_app/lib/src/providers/profile.dart` (118 lines): `_announced` added, set beside `state`, compared
  instead of `state`; a null answer or one matching the ask clears it; `build()` resets it.
- `packages/connection/lib/src/client_types.dart` (199 lines): `reconnecting()` and `failed()` also clear
  `askedCharacter`, so the ask does not outlive the link it was sent on (review finding 9; the doc comments say so).
- New `controller_app/test/taken_notice_rearm_test.dart` (4 tests) and new
  `packages/connection/test/client_ask_test.dart` (4 tests).
- Tests seen here: the new band file 4 tests, 2 of them fail on the old code for the bug's reason (the same
  answer after the 5 s, the same answer after a `ViewStarted`); the new connection file 4 tests, 2 fail on the old
  code (the ask kept by `reconnecting()` and by `failed()`), the 2 hello cases pass on the old code (they pin what
  already works). `taken_notice_rearm_test.dart` + `taken_notice_profile_test.dart` + `m14_phone_test.dart`:
  15 passed after the fix.
- Checks run here: `tools/check.sh format analyze phone connection` — format PASS, analyze PASS,
  connection 294 tests PASS, phone 504 tests PASS. `tools/review.sh`: 0 fail, 0 note.

## Decisions

1. **The pair lives in the notifier.** The brief names a private field in `TakenNoticeNotifier`, so it is not a
   second provider (and `providers.dart` is outside `allow:`; review question 11 keeps the notifier where it is).
2. **An answer that is no longer taken clears the pair too.** A snapshot with no wanted colour, or one where the
   host gave the asked slot, sets `_announced` back to null, so a later hello that gets the same pair again is
   said again — a host re-answering after a reconnect is a new answer.
3. **`build()` resets `_announced`.** A rebuilt notifier (a new client) starts with nothing said, whether or not
   Riverpod reuses the notifier instance, so kept state starts clean at build.
4. **The new connection cases go in a new file** (`client_ask_test.dart`), as the brief asks: two unit cases for
   `reconnecting()`/`failed()` and, for each transport, "say hello → `askedCharacter` is the identity's character".
5. **The 5 s in the band test is a plain `Duration(seconds: 5)`**, as in `taken_notice_profile_test.dart`:
   `takenNoticeDuration` sits in `providers/profile.dart`, which that test does not import.

## Self-check (review rules part A, items 1-5)

1. **Every host setup.** A joined phone is the case and is tested (`taken_notice_rearm_test.dart`, all 4). A TV or
   PC host and a phone on "Show on this device" reach the same snapshot path; no host-specific code changed. The
   phone hosting "Play on this phone" gets no views (review Q1), so its band still ends on the 5 s only, which the
   five-seconds test covers. A host one build older sends no character, so there is no pair and no band — cleared,
   not shown, unchanged by this job, not tested here.
2. **Kept state starts and ends.** `_announced` starts null at build, is set when a differing answer is said,
   ends when the answer becomes null/equal, and is untouched by the timer and the view listener; the notifier's
   dispose cancels the timer. Shown by "the same answer after the five seconds does not show the band again",
   "the same answer after the round starts does not show the band again", "a new answer after the band hides shows
   it again", "an answer that is no longer taken lets the same one be said again".
3. **How it combines with other states.** The band pauses nothing and blocks no input; the only states it meets are
   a round start or end (the view listener) and the host-away card (review Q2, unchanged). The round-start pair is
   shown by "the same answer after the round starts does not show the band again"; the host-away pair is not
   touched by this job.
4. **Stay in the job's folder.** Only the five allowed paths changed: the two `lib` files, the two new test files
   and this report (`git status` shows no other file of mine).
5. **Stop rather than overstep.** No contradiction found between the brief and the code; nothing outside `allow:`
   was needed. Review finding 8 (seed the band from the current snapshot in `build()`) is a could, not this brief.

## Computed test values

- Band, heartbeat case: asked `PlayerCharacter(4, crown)`, assigned `PlayerCharacter` blue (slot 1) → the band is
  one widget; after `pump(5 s)` nothing; after emitting the same pair in a new snapshot (as a heartbeat does — a
  new `ClientSnapshot` with no `==`) plus `settle` (a pump and a 500 ms pump) still nothing. On the old code the
  last check finds one band.
- Band, round-start case: same pair, `viewStart(arenaStart())` then `settle` → nothing; the same pair again →
  still nothing (old code: one band).
- Band, new pair: after the 5 s, asked teal crown (slot 4) / assigned pink tuft (slot 5) → one band.
- Band, cleared pair: differing pair → one band; equal answer (asked blue, assigned blue) → nothing; the differing
  pair again → one band.
- Connection: `ClientSnapshot(connected, character: tealCrown, askedCharacter: tealCrown).reconnecting(detail:
  'gone', attempt: 1)` → both null (old code: `askedCharacter` is `PlayerCharacter(4, crown)`), and the same for
  `failed(ClientProblem.connectionLost, 'gone')`. Hello case: an identity with `tealCrown` connects → the snapshot's
  `askedCharacter` is `tealCrown`, on both the WebSocket and the in-process transport.

## Notes and questions

- `controller_app/test/host_start_log_test.dart` ("Host a game logs each step of the start with the ms since the
  tap") failed once during a full phone run — expected `(tap, 0)`, actual `(tap, 3)` — and passed alone and on the
  next full run. It measures the wall clock (guideline §9: no real time in tests), so it is load-sensitive and
  unrelated to this diff; not touched here. Question: is it already known, or would Claude like it as a later job?
- Suggestion: review finding 8 (seed `build()` from `ref.read(clientStateProvider)`) would also make the first
  answer show without waiting for the next snapshot; it is a separate brief.
- The band's re-show after a round start is now the test the review (finding 2) asked for; finding 14 (the stack
  order) is unrelated and untouched.

## Hand-over

B-028's review finding 1 and finding 9 (the stale ask after a drop) are fixed and pinned by tests that fail on the
old code. The band keeps its look and text; nothing else in `profile.dart` changed. Open in bugs14: review findings
3-8 and 10-16 (the sound engine and the watchdog, plus the smaller coulds) — none touched here. Both bugs stay
"Fixed, unverified" until a device run.

## Commit message

```
Keep the taken-colours band hidden after it hides

The band's guard compared the host's answer with a state the hide had
just cleared, so every 1 s heartbeat snapshot showed it again, and
again after every round start or end. The pair already said is now
kept where the hide and the view listener leave it alone, so only a
new answer (or one no longer taken) says the line again. A dropped or
failed link also clears the colour the last hello asked for. New
tests: four band cases and four connection cases, four of them red on
the old code.
```

## Status row

**bugs14 (Nov 15, fix batch after the run review):** f1 fixes the band coming back after it hides (review finding 1
and finding 9, the ask kept after a drop; both now pinned by tests that fail on the old code); still open: the
watchdog and sound findings (3-8) and the smaller coulds, and a device check for B-028.

## Delete

- none
