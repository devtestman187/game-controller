# Review of wave 3 (y0c, y0g)

## Summary
- Verdict: small fixes
- Counts: 1 must, 5 should, 5 could
- 1. packages/connection/test/choice_round_test.dart:266: the dispose-while-away test passes its grace claim on the old code, so it does not show the grace guard.
- 2. packages/connection/test/choice_round_test.dart:80-81: the round starts before the phone drains, so the 300 ms timer tests can flip on a slow machine.
- 3. packages/connection/lib/src/choice_fallback.dart:94-96: a phone that connects after start gets no labels, no status and no counting, and this is not listed as a decision.

## Findings
- **must** packages/connection/test/choice_round_test.dart:274 The grace check (`lockedIds` empty) passes on the old code, because `dispose()` already cancels the away timers (choice_round.dart:165-167, unchanged context); only the `close()` check at :275 fails on the old code → rename the test to what it checks (dispose leaves nothing set and closes nothing) and drop the "grace never sets a default" claim.
- **should** packages/connection/lib/src/choice_round.dart:99 The `if (!_isDisposed) close();` guard in the end timer can never run after dispose, since `_cancelWatching()` cancels `_endTimer` (:159); the grace guard `if (_isDisposed || isClosed)` at :206 has the same dead part → remove the `_isDisposed` test from both timer callbacks (keep `isClosed` at :206), as the guidelines ban dead branches.
- **should** packages/connection/lib/src/choice_round.dart:141 The `server.send(entry.key, ChoicesEndMessage(...))` line is still over 120 columns, although the y0g report says it was wrapped → wrap the call the way `dart format` does (page_width is 120 in packages/connection/analysis_options.yaml).
- **should** packages/connection/test/choice_round_test.dart:80-82 `round.start()` runs before the two phone drains, so the 300 ms `_shortRound` timer (used at :242 and :252) can end the round before the test calls `dispose()` or subscribes to `changes.first`; the comment on `_shortRound` says the opposite → start the round after the drains, or pass `start: false` and call `start()` after the drains, and fix the comment.
- **should** packages/connection/lib/src/choice_fallback.dart:94-96 `start()` skips any phone missing from the snapshot (`controller == null`), so a phone that connects later never gets its layout or status and its presses are ignored → set up the phone when it connects (listen to `round.server.changes`), or list this as a decision to confirm.
- **should** packages/connection/lib/src/choice_fallback.dart:16 and :70 The file has two public types, `OldPhoneButton` and `OldPhoneChoices`; the guidelines allow that only for small types that make sense together (docs/coding-guidelines.md:45) → move `OldPhoneButton` to its own file (one more allowed file), or list the exception as a decision.
- **could** packages/connection/lib/src/choice_fallback.dart:118 `phone.held` survives a dropped link, so a button released while the phone is away is not seen as released → clear `held` when the phone drops, or confirm the phone resends its state on reconnect (protocol not read).
- **could** packages/connection/lib/src/choice_fallback.dart:17 and :71 The public constructors of `OldPhoneButton` and `OldPhoneChoices` have no dartdoc → add one line each.
- **could** packages/connection/test/choice_fallback_test.dart:26 The `_Setup.choices` field is set but no test reads it → remove the field, or use it.
- **could** packages/connection/test/choice_fallback_test.dart:114, :133, :134 The literals 12 and 24 repeat the limits in code → use `GameLayoutMessage.maxLabelLength` and `StatusMessage.maxTextLength`.
- **could** packages/connection/test/choice_fallback_test.dart:207 The test "the outcome at close is the stored pick" repeats part of the "B after A" (:185) and "Y clears" tests → remove it or keep it as the close check on its own; either is fine.

## Decisions to confirm
- y0c: labels are the card title, not the count (the owner's note reads "A = Build 1"); the status carries the count. Why: the brief's signature has no count (y0c report, question 1).
- y0g: the end-timer round is 300 ms, but the brief's last line said 250 ms. Why: the brief's rule for new tests is at least 300 ms (y0g report, decisions).
- y0c: `OldPhoneChoices` has `start()` and `dispose()`, beyond the constructor the brief names. Why: the layout must be set at a start point (y0c report, decisions).
- y0c: a disabled card's press does nothing. Why: the round would ignore the pick anyway.
- y0c: a phone connected after start is skipped (the undisclosed decision behind the should finding at choice_fallback.dart:94-96).

## Could not check
- Nothing was run: this is a read-only review, and `tools/mine.sh` and the tests were not run. The y0c "format OK" and y0g "RESULT ok" claims are not reconciled with line 141 (choice_round.dart:141), which I could only see as over 120 columns.
- "Passes on the old code" was judged from the diff's unchanged context (dispose cancels the timers), not by running the old code (no checkout allowed).
- How long `WirePhone.drain()` takes is not measured, so the race at choice_round_test.dart:80-82 is judged by reading only.
- Whether the phone resends its button state on reconnect (choice_fallback.dart:118): the protocol spec was not read.
- docs/briefs/m17/phone1a/wave2-review-report.md was not read, so the y0g claim that the doc lines at :22-23 and :74 were fixed is not checked.
- docs/briefs/m17/phone1a/run-findings.md has one line, about y0b; it has no entries about y0c or y0g.
- docs/coding-guidelines.md and docs/review-rules.md were checked only for the rules quoted here (one public type, dartdoc, dead branches, magic numbers); they were not read whole.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

review: wave 3 (y0c, y0g) against the guidelines and their briefs

Adds docs/briefs/m17/phone1a/wave3-review-report.md: the findings on the
choice fallback (y0c) and the ChoiceRound dispose fix (y0g). One must
(a dispose test whose grace check passes on the old code), five shoulds
(dead timer guards, a 121-column line, a test start before the drains,
phones that connect after start, two public types in one file) and five
coulds. No code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

phone1a wave 3 review: done: findings on y0c and y0g written (1 must, 5 should, 5 could; verdict small fixes). Open: Claude to verify and fix the must and the shoulds; confirm the labels-as-title and 300 ms decisions; nothing run here.

## Delete

- none
