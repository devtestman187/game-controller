# B-005 review: a marble may take back its own dropped coin after a wait

## Summary

Verdict: **small fixes**. 0 must · 1 should · 4 could. The rule, the one named constant and the brief's three items are in place, and the self-check lines are true as far as they are checkable.

- I ran the changed files myself: `arena_coin_rules_test.dart` 13/13 pass, `arena_bumper_test.dart` 15/15 pass, `dart format --set-exit-if-changed` clean on both, `flutter analyze` clean.
- **should** `arena_coin.dart:48` still documents the old rule ("anyone but its dropper"); it is the one stale place left and the worker flagged it.
- **could** the take-back is proved at 2.117 s, not at 2.0 s, so the brief's "takes it at 2.0 s" case — and `<` vs `<=` at the boundary — is not tested.
- **could** the brief's `format` / `analyze` / test results are never reported; the only evidence is the "all pass" claim at `b005-coin-report.md:19` (true, I re-ran it).

## Findings

- **should** packages/test_game/lib/src/arena_coin.dart:48 `ArenaCoin.dropper`'s doc still says a dropped coin is "takable at once, by anyone but its dropper", the rule B-005 removed → reword it to "out of its dropper's reach for `dropLockS`, then anyone's" in the next job allowed to touch the file.
- **could** packages/test_game/test/arena_coin_rules_test.dart:143 the coin is taken back at 2.117 s (1.917 s + 0.2 s), three frames past the earliest allowed step, so the `ageS == dropLockS` boundary and the `<` in `_outOfReach` are not proved → run ~5 more frames (0.083 s) instead of `run(g, 0.2)`, so the take is the first step after `dropLockS` and a `<` that should be `<=` would fail.
- **could** docs/briefs/m14/bugs6/b005-coin-report.md:19 the report never states the result of the brief's `check: format analyze arena`, only "all pass" → add a short Checks line with the three results (they are clean, I re-ran them).
- **could** docs/design/party-night.md:101 "its dropper may take it back after 2 s, having been dizzy for 1 s (no dash) and then safe for 1 s (drops nothing)" now reads as if dizzy and safe are the price of taking the coin back → split the clause: "…; its dropper is dizzy for 1 s and then safe for 1 s, as before, and may take the coin back once that 2 s is over."
- **could** packages/test_game/lib/src/arena_bumper.dart:133 `_outOfReach` returns a bool but does not read as a question (guidelines §4) → rename it `_isOutOfReach` (the older `_goldRush` getter has the same fault, so this is only worth doing when the file is touched).

## Decisions to confirm

- `dropLockS = ArenaFieldRules.dizzyS + ArenaFieldRules.safeS` (`arena_bumper.dart:7`) ties the coin wait to the dizzy and safe seconds, so a play test that retunes `dizzyS` silently moves the coin wait with it; the owner said the wait "may need to change later", which this makes a two-place change.
- The same constant is a top-level public member of the `arena.dart` library rather than "beside `dropGapShare`" as the brief said, because `_BumperGame` is private and the tests must read it; it is now part of the package's exported API (the brief's own test item requires that).
- A drop lands 25.6 px behind its dropper against a 32 px reach, so the dropper stands on a coin it cannot take for 2 s and takes it on the first step after the lock with no input at all; that is the brief's design, but the owner should feel it on a device.

## Could not check

- The report's claim that the 1.9 s test and the drop-again test fail on the old code: this is a read-only job, so I could not put `coin.dropper == p.id` back and run it. The failure follows from that line, but it was not run.
- Whether the 2 s wait feels right on a phone: needs device check.
- The rest of `packages/test_game`'s suite (34 test files): I ran only the two arena files named above, both pass.
- `docs/briefs/m14/bugs6/run-findings.md` does not exist, so there are no runner entries about this job to weigh.

## Commit message

M14 bugs6 b005 review: small fixes (stale coin doc, 2 s boundary)

Read-only review of b005-coin. The rule, the single documented `dropLockS`
constant and the brief's three items are in place; tests, format and analyze
pass when re-run. One should finding: `ArenaCoin.dropper`'s doc still states
the old "anyone but its dropper" rule. Three coulds: the 2.0 s boundary is
proved only at 2.117 s, the report never states its check results, and one
design-doc sentence now reads as if dizzy/safe pay for taking the coin back.
No code or document other than this report is changed.

## Status row

B-005 reviewed (small fixes): the rule, `dropLockS` = 2 s and party-night §7 are in place and the file's tests pass; open: `arena_coin.dart:48`'s stale doc, a test at the exact 2 s boundary, a Checks line in the report, and play-test tuning of `dropLockS`.

## Delete

- none
