# B-005: a marble may take back its own dropped coin after a wait

## Summary

Built: a dropped coin is out of its dropper's reach only for a wait, then it is
the dropper's again; anyone else still takes it at once, so the scatter stays
fair. No protocol change: `ageS` already rides the frame.

- **Constant:** `dropLockS` = `ArenaFieldRules.dizzyS + ArenaFieldRules.safeS`
  = 2.0 s, one documented top-level constant in `arena_bumper.dart`. `0` means
  no wait (a coin's `ageS < 0` is never true).
- **Rule:** `_takeCoins` skips a coin only when it is `_outOfReach`: its
  dropper is the marble and `coin.ageS < dropLockS`.
- **Doc:** party-night §7 now says anyone takes the drop at once and its
  dropper may take it back after 2 s.
- **Numbers:** reach 32 px (marble 16 + coin 16); a drop lands 25.6 px behind
  the marble (1.6 × 16 px), so it is in reach on landing and the lock is what
  holds it; a coin is aged in its drop step, so it is 1/60 s old then.
- **Tests** in `arena_coin_rules_test.dart` (13 in the file, all pass): at
  1.9 s the dropper still has its old count 1 and the coin's age is 1.917 s;
  0.2 s later it has 2. Another marble takes the drop at once (0 → 1 in a
  frame). A coin taken back is dropped again by the drain:
  [coinsDropped, coins] = [2, 1]. One test pins the 2.0 s default; every other
  time goes through `dropLockS`.
- **Old code:** with `=> coin.dropper == p.id` put back, the 1.9 s / 2.0 s test
  and the drop-again test fail; the "another marble" test passes on both.
- **Not done:** `ArenaCoin`'s doc (`arena_coin.dart:46-48`) still says "anyone
  but its dropper"; outside `allow`.
- **On a device:** drop a coin under yourself in a Bumper Round — nothing for
  about 2 s, then it comes back with the coin tick; a second marble takes it
  at once.

## Self-check (review-rules part A)

1. **Every host setup.** Rules only: no message, transport or host code changed,
   and the snapshot version stays 2. The lock reads a coin's `ageS`, which the
   frame already carries, so a TV host, a phone host and a joined phone all see
   the same rule; an older peer gets the same frame fields. Shown by "the frame
   carries a drop's dizzy and safe flags and its coin's dropper" and "a gold
   coin goes into the frame, and the frame stays inside its budget".
2. **When kept state starts and ends.** The lock is the coin's own age, not a
   player timer: it starts at the drop (age 0), ends the step its age reaches
   `dropLockS`, and a coin nobody takes stays open to its dropper for the rest
   of its life. No round or no players means no coins, so nothing holds. Shown
   by "a shove into a wall drops one coin, and its dropper waits to take it
   back" and "a coin its dropper took back can be dropped again".
3. **How it combines with the other states.** It is a property of a coin, so it
   cannot pause, hide or block input, and it never touches the phase or the
   pause menu. It lives beside two existing windows: the sparkle second (a
   field coin is never dropper-locked; a dropped coin never sparkles) and
   dizzy/safe (the same 2 s, so a marble can neither drop again nor take its
   coin back before the safe second is over). Shown by "a coin that just came
   out sparkles for a second and can't be taken" and "a hazard drops exactly
   one coin, and the dropper is dizzy and then safe", both still passing.
4. **Stay in the job's folder.** Changed only the allowed paths; `git status`
   in `packages/test_game` lists only `lib/src/arena_bumper.dart` and
   `test/arena_coin_rules_test.dart`.
5. **Stop rather than overstep.** Nothing blocked the job. The one file that
   still carries the old sentence, `arena_coin.dart`, is outside `allow`, so it
   is reported instead of edited (see "Not done").

## Decisions

- **`dropLockS` is a top-level constant, not a static beside `dropGapShare`.**
  The brief asks for both "beside dropGapShare" and for the tests to read
  `dropLockS`, and `_BumperGame` is private, so a static on it is invisible to
  the tests. It is therefore declared at the top of the same file, just above
  the class that uses it.
- **The value is the sum of the field rules, not a bare 2.0.** `dizzyS + safeS`
  is exactly 2.0 today and states why the wait is that long; the pin test keeps
  the default visible for a play test to change.
- **`0` needs no special case.** `ageS < 0` is never true, so a 0 lock opens the
  coin to its dropper at once, as the brief asks.
- **Replaced one test with four, keeping its coverage.** The old shove test's
  drop, its `coinLost` sound and the "anyone else takes it at once" half are
  kept, split across the new tests.
- **A test-local tenth of a second.** The "1.9 s" check is written as
  `dropLockS - 0.1`, so the boundary is proved without a hard-coded 2.

## Questions and suggestions

1. `ArenaCoin.dropper`'s doc (arena_coin.dart:46-48) still states the old rule;
   a later job should reword it. I did not touch it (outside `allow`).
2. Nothing else in `lib/` or `test/` mentions the old rule (grepped "anyone
   but", "take it back", "dropper").
3. Sound for taking a coin back: it is the plain coin tick, as for any take. If
   the owner wants a "got it back" cue, that is a new event or sound, not this
   job.

## Commit message

M14 bugs6 b005: a marble may take back its own dropped coin after 2 s

`dropLockS` (dizzyS + safeS, 2 s) keeps a dropped coin out of its dropper's
reach for the drop's dizzy and safe seconds; anyone else still takes it at
once, so the scatter stays fair. `_takeCoins` now skips a coin only while its
`ageS` is under the lock. The coin rules tests cover the 1.9 s / 2.0 s
boundary, another marble taking it at once, and dropping a taken-back coin
again, all through the constant, plus one test pinning the 2 s default.
party-night §7 says the same in words. No protocol change.

## Status row

B-005 done: a dropper may take back its own dropped coin after `dropLockS` (2 s), with tests and party-night §7 updated; open: the same sentence in `ArenaCoin`'s doc (outside this job), and play-test tuning of `dropLockS`.

## Delete

- none
