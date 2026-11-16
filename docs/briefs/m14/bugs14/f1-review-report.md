# M14 bugs14 f1 — review

## Summary

`clean` — must 0, should 0, could 5.
- Two new behaviours have no test: `_announced = null` in `build()` (`profile.dart:82`) and the `asked == null`
  branch (`profile.dart:96-97`), so a rebuilt notifier, and a drop that ends a band early, are unexercised.
- The public doc of `askedCharacter` (`client_types.dart:116`) still says "Null until a hello goes out", while
  `reconnecting()` and `failed()` now set it back to null.
- The band tests wait a literal `Duration(seconds: 5)` (`taken_notice_rearm_test.dart:36`, `:67`) instead of
  `takenNoticeDuration`.
- Ran here: both new files pass (4 + 4), the three band/phone files 15 pass, `tools/check.sh format analyze` PASS.
  The "fails on the old code" claims are judged from the diff at `17147e5..f4020e`, not run.

## Findings

- **could** controller_app/lib/src/providers/profile.dart:82 the reset of `_announced` in `build()` and the
  `asked == null` sub-case at `:96` have no test (every band case builds once and always sets both characters) →
  add a case that emits a snapshot with `character: null` between two equal differing pairs and expects the line
  again.
- **could** packages/connection/lib/src/client_types.dart:116 the dartdoc "Null until a hello goes out, and for a
  phone that sends no character" no longer says the whole story, since `reconnecting()` (`:138`) and `failed()`
  (`:152`) now clear it → add "and null again when the link drops or the client gives up".
- **could** controller_app/test/taken_notice_rearm_test.dart:36 the 5 s waits (`:36`, `:67`) are a literal, so a
  change to `takenNoticeDuration` leaves the tests green → import `package:controller/src/providers/profile.dart`
  and pump the constant.
- **could** controller_app/lib/src/providers/profile.dart:102 the new comment reads "keeps the line's own seconds
  rather than starting them again, or saying it after the hide", which does not parse → "so every heartbeat keeps
  the line's own seconds and never says it again after a hide".
- **could** docs/briefs/m14/bugs14/f1-report.md:11 the report gives `profile.dart` as 118 lines; `wc -l` says 120 →
  correct the number.

## Decisions to confirm

- A drop now clears `askedCharacter` (`client_types.dart:138`, `:152`), which reaches `_onHostAnswer`'s null branch
  and hides a band that is on screen before its 5 s — confirm a dropped link should end the line early.
- A later hello on the same link with the same pair says nothing (the pair is re-sayable only after a null/equal
  answer): confirm brief item 1's "a new hello … shows the band again" was meant for a new pair or a new link.
- `build()` resets `_announced`, so a rebuilt notifier can say the same pair a second time (report Decision 3) —
  confirm that is wanted rather than keeping the pair for the notifier's lifetime.
- Report Decision 5 (a literal 5 s because the constant lives in a file the test does not import) is a choice, not
  a limit: the test may import `package:controller/src/providers/profile.dart`.

## Could not check

- That the band and connection cases fail on the old code: this job is read-only, so I judged it from the diff
  (old `profile.dart:94` compared with `state`, which `_hideNow` cleared; old `reconnecting()`/`failed()` had no
  `askedCharacter: null`) instead of running the tests against the old lib.
- `tools/review.sh` (reported 0 fail, 0 note) and the full suites (reported phone 504, connection 294): not re-run;
  I ran the two new files and `taken_notice_rearm_test.dart` + `taken_notice_profile_test.dart` +
  `m14_phone_test.dart` (15 passed).

## Commit message

```
Review of bugs14 f1: the taken-colours band re-arm

Reads the f1 diff against the guidelines, the review rules and the brief:
verdict clean, no must and no should. Five coulds: the untested `build()`
reset and null-answer branch, the stale `askedCharacter` dartdoc, a literal
5 s in the new band tests, a garbled comment, and a line count in the
report. Adds no code. Also lists the drop-ends-the-band question and the
"same pair on a new hello" reading for the owner.
```

## Status row

**bugs14 (Nov 15, fix batch after the run review):** f1 reviewed — the band fix, its four band tests and the
`askedCharacter` clearing hold (0 must, 0 should, 5 could); still open: review findings 3-8 and 10-16, the device
check for B-028, and the four decisions above.

## Delete

- none
