# M14 bugs14 — the run's review

## Summary

**one fix batch.** must 1, should 5, could 10. B-027 is close to its brief; B-028 is not fixed.
- **The band comes back**: `TakenNoticeNotifier` re-arms on the next heartbeat snapshot after it hides, so a phone
  whose colour was taken sees the band over the game in a 5 s-on, ~1 s-off cycle — the B-028 symptom survives.
  No test can see it (the fake client never ticks).
- A restart whose load fails leaves the engine dead **and** unwatched for the rest of the session (`sound.dart:214`).
- The watchdog's timer, its not-wanted and no-voice branches, and the player wiring have no test; the player reads
  `WidgetsBinding` with no seam, so the wiring can't be tested without a one-line injection.
- Nothing ran on a device: both jobs are "Fixed, unverified", and B-027's cause was triage, not a measurement.
- Hand-fixes: none — `run.log` has no `HAND-FIX` line; its tests-first lines (`run.log:8-9`) and both review
  reports exist. No `bugs14/STATUS.md` and no `run-findings.md`, so no third-party "passes on old code" entries.
- Per-job review findings checked against the final code: all b027 ones still hold; one b028 one does not — the
  band/card stack order is the other way round (finding 14). No finding was fixed by a later job.
- Open questions only the owner can answer: the host phone's own band (b028 Q1), the band over the host-away card
  (Q2), accessories (Q3), and whether an effect `play()` that throws should restart the whole engine (b027 §6).

## Findings

- **must** controller_app/lib/src/providers/profile.dart:94 the guard compares the answer with `state`, which
  `_hideNow` (`:100`) sets to null, and every 1 s pong sets a new `ClientSnapshot` (`client_messages.dart:123`, no
  `==`), so the next snapshot re-shows the band and restarts its timer: 5 s on, ~1 s off, for ever, and again after
  every `ViewStarted` → keep the (asked, assigned) pair already announced in a field the timer and the view listener
  do not clear, and let the hide clear only the shown state (from: b028 review, still holds)
- **should** controller_app/test/taken_notice_profile_test.dart:77 nothing is emitted after the 5 s timer (or after
  the `ViewStarted` at `:86`), and `FakeClient.emit` (`test/support/fakes.dart:41`) never ticks, so no test fails if
  the band returns → emit the same differing answer once more after each end and expect no band (from: b028 review)
- **should** packages/party_host/lib/src/sound.dart:214 `_isLoopWanted` needs `_status.ready`, so a restart whose
  `_load` fails at `soloud.init()` (`:169-173`) leaves `ready` false; `_sources` were cleared (`:233`) so `play()`
  returns at `:247` before its catch, every look is skipped and the engine stays silent until the app is hidden and
  shown — the B-027 symptom, back for the session → count "a loop is wanted but the status is not ready" as dead
  (restart after the cooldown, logged) or state the limit in the report (from: b027 review)
- **should** packages/party_host/lib/src/sound.dart:205 `_isActive` reads `WidgetsBinding.instance.lifecycleState`
  inside the player, so the watchdog's `active` has no fake (guideline §1: a platform read behind an interface with
  a fake) and nothing tests `start()` (`:200`), `failed()` (`:257`) or the hidden case → take `active` as an injected
  `bool Function()` defaulting to that read, and add one player test with a fake engine (from: across jobs — b027
  review finding 4 and guideline §1)
- **should** packages/party_host/lib/src/sound_watchdog.dart:78 `start()` and `dispose()` (`:105`) are never called
  by `sound_watchdog_test.dart`, so Decision 8 (a second `start()` keeps one timer) and guideline §5 (dispose leaves
  nothing running) are unshown → a `fakeAsync` test: two `start()` calls, one look 3 s later, none after `dispose()`
  (from: b027 review)
- **should** packages/party_host/test/sound_watchdog_test.dart:86 `wanted` is never false and `_Rig` always plays a
  voice (`:60`), so `sound_watchdog.dart:82` (not wanted: judge nothing) and `:87` (wanted, no voice: restart) are
  unexercised → a `wanted = false` case with no restart, and a rig whose loop never got a voice that restarts on the
  first look (from: b027 review)
- **could** packages/party_host/lib/src/sound.dart:253 `failed()` fires on any `play()` that throws, so one bad or
  missing effect key restarts the whole engine every 5 s, reloads every sound and restarts the music at 0 (`:226`),
  and no test covers that side effect → restart on a throw only while the loop's voice is also gone (or on a second
  throw inside the cooldown), and say so in the report (from: across jobs — b027 review, Decision 6 to confirm)
- **could** controller_app/lib/src/providers/profile.dart:81 `build()` returns null and only listens, so an answer
  already in the snapshot when the provider is first built is not shown until the next snapshot (up to 1 s late, and
  a second of its 5 s gone) → seed from `ref.read(clientStateProvider)` (from: b028 review)
- **could** packages/connection/lib/src/client_types.dart:129 `reconnecting()` and `failed()` (`:143`) clear
  `character` but keep `askedCharacter`, so the ask outlives the link it was sent on → clear both (from: b028 review)
- **could** packages/party_host/lib/src/sound_watchdog.dart:92 "frozen" is exact equality with the previous place
  and no loop length is known, so a loop whose length divides 3 s reports the same place on two looks and is
  restarted every cooldown for ever → carry the loop's length in `SoundPulse` (`SoundLoop` has `getLength`) and take
  a place one length later as moving (from: b027 review)
- **could** packages/party_host/lib/src/sound_watchdog.dart:47 the fixed 5 s cooldown restarts an engine that cannot
  come back every 6 s for the session, each time a deinit, an init and every sound reloaded (`sound.dart:223-241`)
  → widen the cooldown after each restart that did not help, and say why (from: b027 review)
- **could** packages/party_host/lib/src/sound_watchdog.dart:7 `SoundPulse` sits beside the watchdog, so
  `sound_loop.dart:8` imports the watchdog — the reverse of who uses whom (guideline §3) — and one file holds two
  public types → move `SoundPulse` next to `SoundLoop` and import it in the watchdog (from: b027 review)
- **could** packages/party_host/lib/src/sound.dart:1 the file ends at 347 lines, past the "about 300" of guideline
  §3 (the brief's 380 is met; it was 309 before this job) → split the watchdog/lifecycle wiring out when next
  touched (from: across jobs — no single job saw the size)
- **could** docs/briefs/m14/bugs14/b028-taken-notice-review-report.md:20 the finding reads the Stack backwards:
  `controller_screen.dart:234` is the waiting card and the band is at `:238-248`, later in the same `Stack` (`:209`),
  so the band is over the card and the job report is right (`b028-taken-notice-report.md:94`, `:109`) → drop that
  could; the only fix is that the b028 Q2 answer stands (from: across jobs)
- **could** docs/briefs/m14/bugs14/b027-audio-watchdog-report.md:56 self-check 1 and 2 (`:62`) name tests that call
  `tick()` by hand as showing the `lifecycleState` read, the timer's start and end and `play()` → `failed()`, which
  no test does → mark those three "untested by this job" (from: b027 review finding 4)
- **could** packages/connection/lib/src/client_connection.dart:110 the hello's colour is recorded in `_attach`
  (`:115`) with no test in `packages/connection/test`, so a later change to the hello breaks the band silently → a
  small connection test: say hello, read `snapshot.askedCharacter` (from: b028 report question 4)

## Open questions

1. b028 Q1, the phone hosting "Play on this phone" gets no views, so its own band ends on the 5 s only — leave it:
   reading `roundPhaseProvider` there breaks m12 rule 6 for joined phones and needs a second rule for the host.
2. b028 Q2, the band can sit over the host-away card up to 5 s (report `:109`, correct) — leave it: it takes no
   touch and the round is not waiting on it; hiding it on `HostAway` couples the band to the waiting card's state.
3. b028 Q3, an accessory that was taken shows no band — leave it: the text names colours only.
4. b028 Q4, no connection test for the recorded hello — add one (finding 16); it is the cheapest pin in the batch.
5. b027 §1, a round with no music is unwatched — accept for now, stated in the report; the owner's case had music on.
6. b027 §2, `wanted` requires `ready` — change it (finding 3): the alternative is the same silent engine for a session.
7. b027 §3, a dead voice restarts the music at 0 — accept: it is the existing `restart()` and the owner's case was a
   frozen engine, where the place is unreadable anyway.
8. b027 §6, a `play()` that throws restarts the whole engine — narrow it (finding 7) rather than accept the cost.
9. b027 §7, `pulse` reports `Duration.zero` when invalid — fine, every reader checks `valid` first (`:87`).
10. b028 D1, `askedCharacter` in the connection package — keep: phone-side only, no protocol change, one field.
11. b028 D5, the notifier in `providers/profile.dart` — keep for this batch (the barrel was outside `allow:`); a fix
    job with `providers.dart` in `allow:` could move it to `providers/view.dart` beside `AbandonedNoticeNotifier`.

## Numbers against targets

- Turns: b027 48, b028 70; the briefs aimed 80-120 (`run.log:6-7`). Both came in under, and the shortfall is exactly
  the untested paths in findings 3-6.
- New tests: 6 (watchdog) and 4 (band) as briefed. Re-run here: `sound_watchdog_test.dart` 6 passed;
  `taken_notice_profile_test.dart` + `m14_phone_test.dart` 11 passed — matches the b028 report's "11".
- Claimed and not re-run here: host 504 tests (498 before), phone 500, analyze and format PASS.
- File sizes against the brief's 380: `sound.dart` 347 PASS, `sound_loop.dart` 252, `sound_watchdog.dart` 120,
  `profile.dart` 109, `client_types.dart` 197; test files 173 and 91. Against guideline §3's "about 300":
  `sound.dart` over (finding 13).
- B-028's 5 s: shown at 4.5 s, hidden at 5.5 s in test 3 — "about 5 s" met; with finding 1 the band is back ~1 s
  later, so the target that matters (the band is gone) is missed.
- B-027's "music back within about 3 to 8 s": no measurement, on a device or in a test.

## Could not check

- Any device behaviour: whether the iPad engine freezes as triaged, what a restart costs, and how `getPosition` on a
  looping SoLoud voice behaves (`sound_loop.dart:69`) — no device run.
- The 1 s re-show of finding 1: read from the code (`client_messages.dart:123`, `heartbeatInterval` = 1 s at
  `controller_client.dart:30`) — no test or device measured it, and no file may be added here to reproduce it.
- The full suites: only the two test files above were run; the reports' 504/500 and the format/analyze results are
  taken from the reports.
- Whether any diagnostics screen lists `ClientSnapshot`'s fields and would want `askedCharacter` — not read.

## Commit message

```
Fix the taken-colours band so it stays gone, and test the watchdog

The band compared the host's answer with a state the hide had just
cleared, so every 1 s heartbeat showed it again: it is now driven by
the pair already announced, and the phone tests emit the same answer
after the end. A restart whose load fails no longer leaves the engine
unwatched, the watchdog's timer and its not-wanted and no-voice looks
get tests, and the player takes the lifecycle read as an injected
function so the wiring can be tested. The b028 review's stack-order
finding was wrong and is dropped.
```

## Status row

**bugs14 (Nov 15, fix batch after the run review, unpushed, nothing built):** B-027 (sound engine restarted when it
dies) and B-028 (the taken-colours band) are in, but B-028 is not fixed and the batch is open: the band re-arms on
every heartbeat (must, `profile.dart:94`) plus its missing test, a failed restart leaves the engine unwatched
(`sound.dart:214`), and the watchdog timer, not-wanted, no-voice and player-wiring tests are missing; the smaller
coulds (seed from the snapshot, the stale ask after a drop, the frozen check's loop length, the cooldown, `SoundPulse`
placement, `sound.dart`'s size) sit behind them. Both bugs stay Fixed, unverified: needs device check.

## Delete

- none

## Round 2 verdicts (f1, f2 reviews)
f1 review: 0 must, 5 could; f2 review: 0 must, 2 should (no player-level test of _loadTried; _load 45 lines), 2 could. All deferred to docs/code-health.md (M14 bugs14 leftovers). Full check.sh passed.
