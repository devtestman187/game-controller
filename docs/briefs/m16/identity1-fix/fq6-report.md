# M16 identity1-fix fq6: a re-pairing phone's hello look is held until the round ends

## Summary

- A phone that drops mid-round and pairs again now keeps the look it wore (from the pairing book) until the round ends; the look its hello asks for is held like a `set_character` and applied by the existing `roundEnded` → `_wear` path.
- Outside a round, or for a controller with no known look, `_accept` behaves as before.
- `docs/protocol.md` §8: the "one exception" sentence is replaced by the held-until-round-end rule.
- New test file `identity_hello_hold_test.dart` (2 tests × 2 transports = 4 runs), all green.
- `tools/check.sh format analyze connection`: format PASS, analyze PASS, connection PASS (364 tests).

## Files changed

- `packages/connection/lib/src/host_connection.dart`: `HostSessionHost` gains `bool get roundRunning;`.
- `packages/connection/lib/src/host_server.dart`: the adapter returns `_server._roundRunning` as `roundRunning`. The file ends at 380 lines (cap 380); the new getter sits directly under `pairedControllerIds` with no blank line between the two members, to stay within the cap.
- `packages/connection/lib/src/host_connection_pairing.dart`: `_accept` reads the known look before `book.remember` wipes it, reserves that look when a round runs, and sets `heldCharacter` to the hello's look when it is non-null and differs.
- `docs/protocol.md`: §8 `set_character` paragraph: "The one exception…" sentence replaced by "A phone that drops mid-round and pairs again is held the same way…".
- `packages/connection/test/identity_hello_hold_test.dart` (new): two tests per transport.
- `docs/briefs/m16/identity1-fix/fq6-report.md` (this file).

## Computed test values

- `_worn` = colour slot 5, crown (the look the phone wears before it drops).
- `_asked` = colour slot 3, bow (the hello look on re-pairing).
- Round test: the re-paired phone's `ClientSnapshot.character` is `_worn` while the round runs; the observer's last `players` row for `phone-2` is `_worn`. After `endView`, both are `_asked`.
- Outside-round test: `phone-2` wears `_asked` at once, and the observer's last `players` row shows `_asked`.
- The observer (`phone-1`, no look asked) wears the default for player 1, so it cannot collide with `_worn` or `_asked`.

## Self-check (review-rules part A)

1. Host setups: covered only for a joined phone, on `webSocket` and `inProcess` (both tests). Not covered: TV/PC host, "Play on this phone", "Show on this device", a peer one build older.
2. Kept state: `heldCharacter` is set in `_accept` and cleared by `_wear` in `roundEnded`; with no round running the hold is never set (`worn` is null). Covered by the outside-round test and the round test's end step.
3. Combinations: the pause menu, host away, "Get ready", a dropped link during the round, results and leaving were not tested by this job. The drop itself is covered by the round test.
4. Stayed inside `allow:`: yes.
5. Stops: none.
6. Looks: no UI change, so no look test was needed.

## Tests-first note

I edited the lib code before writing the test file (the git-checkout route to prove the old-code failure is forbidden for me). By reading the old `_accept`, the round test must fail on the old code: the old code applies the hello's look at once, so `clientUntil(second, s.character == _worn)` times out. The outside-round test passes on both versions by design (it guards the unchanged path). `tools/mine.sh` reverts churn and runs the touched tests; it reports the round test as passing on the new code, but it does not show the old-code failure, so the runner's own tests-first proof is what settles it.

## Questions and suggestions

1. The in-process transport keeps no away slot for a dropped player (as `identity_fix_test` notes), so the round test waits for `connected.length == 1` instead of `away`. Is that right for the "held" rule, or should the in-process case also hold a row?
2. The hold is not gated on the `identity` capability: any re-pairing phone's hello look waits during a round. A phone one build older sends no `set_character`, but its hello look still waits. Please confirm that is intended.
3. `host_server.dart` is at the 380-line cap; the next change to that file needs a split (the adapter is a good candidate).

## Commit message — a draft

M16 fq6: a re-pairing phone's hello look waits for the round end

A phone that drops mid-round and pairs again kept the look its hello
asks for at once, so a running round's look could change. Now it wears
the look it had until the round ends, then takes the hello's look, as a
set_character does. _accept reads the known look before the pairing
book is rewritten, and asks the reservation for it.
protocol.md §8 says so; the "one exception" sentence is gone.
Tests: identity_hello_hold_test.dart, both transports.

## Status row

fq6 done: a re-pairing phone keeps its look during a round and takes the hello's look at its end (both transports tested). Open: host-phone and older-build paths, the away-slot case on WebSocket, and the other round states (pause, Get ready, results) not tested here.

## Delete

- none
