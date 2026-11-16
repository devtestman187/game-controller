# M14 bugs14 b028 - review of the taken-colours band fix (B-028)

## Summary

small fixes — the fix is not complete: the band comes back.
- must: 1, should: 1, could: 3.
- `TakenNoticeNotifier` re-arms the band on the very next snapshot after it hides: every pong (1 s heartbeat) sets
  the client state, and the guard at `profile.dart:94` only works while the band is still showing, so after the 5 s
  end or a view start it shows again and stays over the game — the B-028 symptom, in a 5 s-on cycle.
- The tests cannot see it: the fake client is emitted once per test and never ticks a heartbeat.
- The rest holds: the asked colour is recorded where the hello is built, the Settings change shows no band, the
  pinned test keeps its intent, and the 11 tests pass here.

## Findings

- **must** controller_app/lib/src/providers/profile.dart:94 the guard compares the answer with the *showing* state, which `_hideNow` (`:100`) sets to null, so the next snapshot re-shows the band and restarts its timer — every heartbeat pong calls `setSnapshot` (`client_messages.dart:123`, 1 s interval), `ClientSnapshot` has no `==`, so the listener fires every second and the band never stays gone → keep the (asked, assigned) pair already announced in a field and return without showing while it is unchanged; the timer only clears the display.
- **should** controller_app/test/taken_notice_profile_test.dart:77 the 5 s test asserts nothing after the timer fires, so no test would fail if the band came back on a later snapshot → emit the same differing answer once more after the end and expect no band (and the same after the `ViewStarted` in the test at `:80`).
- **could** controller_app/lib/src/providers/profile.dart:81 `build()` returns null and only `ref.listen`s, so an answer already present in the snapshot when the provider is first built is not shown until the next snapshot (up to 1 s late, and 1 s less of its 5 s) → seed from `ref.read(clientStateProvider)` in `build()`.
- **could** packages/connection/lib/src/client_types.dart:137 `reconnecting()` and `failed()` clear `character` but keep `askedCharacter`, so the ask outlives the link it was sent on → clear `askedCharacter` beside `character` in both.
- **could** docs/briefs/m14/bugs14/b028-taken-notice-report.md:94 the self-check says the band "can sit over the host-away/waiting card"; `controller_screen.dart:234` draws `_WaitingOverlay` after the band at `:244`, so the card is over the band → correct the report (and question 2 at `:108`).

## Decisions to confirm

- `ClientSnapshot.askedCharacter` (report decision 1): a UI-only value carried by the connection package — phone-side only, no protocol change, but the connection package now holds state only the band reads.
- Report decision 3: a "phase change" is a view start/end on this phone, so a phone hosting "Play on this phone" ends its own band only on the 5 s (report question 1) — owner call.
- Report decision 5: the notifier lives in `providers/profile.dart` because `providers.dart` (the barrel) is outside `allow:` — accepted here, but it puts client view listening into the profile file.
- No decision covers what happens when the answer is unchanged after the band hid; that is finding 1, not a design choice made and listed.

## Could not check

- No device or emulator run, so the 1 s re-show is read from the code (`client_messages.dart:123`, `controller_client.dart:331`) and not seen; the fake client in `test/support/fakes.dart:41` can't produce it.
- `tools/check.sh analyze connection` from the job's report was not re-run; only the two test files were.
- `run-findings.md` does not exist under `docs/briefs/m14/bugs14/`.

## Commit message

Add the review of the taken-colours band fix (B-028)

Finds one must: the band re-arms on the next heartbeat snapshot after
it hides, so it comes back over the game and the bug is not fixed.
Adds a should for the missing repeat-snapshot test and three coulds
(no seed from the current snapshot, a stale asked colour after a
dropped link, and a report claim about the stack order that the code
contradicts). The 11 tests in the job were run here and pass.

## Status row

**bugs14 (Nov 15, review done, unpushed):** review of B-028 (the taken-colours band) written: verdict small fixes, 1 must (the band re-shows on every heartbeat snapshot after it hides, so it still sits over the game), 1 should (no test for a repeated snapshot), 3 coulds. Open: the must fix and its test, then a device check.

## Delete

- none
