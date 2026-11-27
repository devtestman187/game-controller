# phone1a run review (read-only)

## Summary
- Verdict: **needs Claude's design** (the `ChoiceRound` value object; where titles are cut; the G3 verdicts conflict with the rules extract).
- Counts: 2 must · 6 should · 6 could (14 findings; the run's review of all four jobs, read as one change).
- Top five:
  1. `choice_round_test.dart:266` the dispose-while-away test passes on the old code, so it does not prove the grace timer is cancelled.
  2. `choice_round.dart:20` the `ChoiceRound` constructor takes 10 named parameters; G3 caps it at 5.
  3. `choice_round.dart:224` card titles go out uncut, though `choices.dart:22` and `contract.md` say the host cuts them to 24.
  4. `choice_round.dart:141` is still over 120 columns; the y0g report says it was wrapped.
  5. `choice_fallback.dart:94` a phone that connects after `start()` gets no labels or status and its presses are ignored.
- Owner questions: reopen the G3 verdicts (ChoicesMessage, ChoiceCard, one type per file)? Is a picked-but-unlocked card counted at timer end? Labels as title or count? Who owns pause for the grace and end timers, before y0d?
- Fix batches (no finding is phone-pinned: no controller_app file uses the new names). Wave A, one job per file: job 1 `choice_round_test.dart` (:266, :80); job 2 `choice_round.dart` (:141, :224, :99 and :206); job 3 `choice_fallback.dart` (:94, :17 and :71, :118); job 4 `choice_fallback_test.dart` (:26, :114 and :133-134, :207). Wave B, after the design, since they share files with wave A: `choice_round.dart:20` (value object), `:16` (naming), and the types at `choice_fallback.dart:16` and `:70`.
- Fixed, unverified: needs device check: y0g's dispose guards (`choice_round.dart:93,117,135,178,187,206`; no test fails on the old code); y0g's grace 300 ms and end 300 ms (`choice_round_test.dart:18,25`; flakiness not measured); y0g's line-wrap claim (false, see `choice_round.dart:141`).
- Hand-fixes: `run.log` has no `HAND-FIX` line. Unlogged hand edit: `coverage_all_test.dart:10` (y0a). Tests-first proof: y0a, y0b and the y0c test file are in `run.log`; y0g's dispose tests have none (its report says exempt).
- Review reports exist for every job (`wave1`, `wave2`, `wave3` reviews; `y0a`, `y0b`, `y0c`, `y0g` reports).

## Findings
- **must** packages/connection/test/choice_round_test.dart:266 The dispose-while-away test passes on the old code: `lockedIds` is empty before any grace timer could run, and only the `close()` check at :275 fails on the old code → rename the test to what it checks and make the grace timer observable (fake clock or a registered-timer check), so it fails on the old code. (from: wave3 review)
- **must** packages/connection/lib/src/choice_round.dart:20 The `ChoiceRound` constructor takes 10 named parameters (lines 21-30), over the G3 limit of 5, and no review saw it → group the setup (server, round, title, cardsFor, players, duration, grace, nowMs, defaultId, currency) into one value object, with the three defaults as fields of it. (from: across jobs)
- **should** packages/connection/lib/src/choice_round.dart:141 The `server.send(entry.key, ChoicesEndMessage(...))` line is 121+ columns, though the y0g report says it was wrapped → wrap it as `dart format` does and re-run the format check. (from: wave2 review; wave3 review; y0g)
- **should** packages/connection/lib/src/choice_round.dart:224 `_sendState` sends `cardsFor(playerId)` uncut, while `choices.dart:22` and `contract.md` say the host cuts each title to 24 characters (y0a decision 3 deferred this to y0b; no code or test does it) → cut titles to 24 in `_sendState` (or the doc), and add one test. (from: across jobs)
- **should** packages/connection/lib/src/choice_round.dart:99 `if (!_isDisposed) close();` can never run after dispose, since `_cancelWatching()` cancels `_endTimer` (:159); the grace guard `_isDisposed ||` at :206 is dead for the same reason (:165-168) → remove the `_isDisposed` test at :99 and :206, keep `isClosed`. (from: wave3 review)
- **should** packages/connection/test/choice_round_test.dart:80 `round.start()` runs before the two phone drains (:81-82), so the 300 ms `_shortRound` timer (used at :242 and :252) can end the round before the test calls `dispose()` or listens to `changes.first`; the comment at :23-24 says the opposite → start after the drains, or pass `start: false` and call `start()` after them. (from: wave3 review)
- **should** packages/connection/lib/src/choice_fallback.dart:94 `start()` skips any phone missing from the snapshot (`controller == null`), so a phone that connects later gets no labels or status, and its presses are ignored (the y0c decision list does not disclose this) → set the phone up when it connects (listen to `round.server.changes`), or record the decision with Claude. (from: wave3 review)
- **should** packages/connection/lib/src/choice_fallback.dart:16 The file holds two public types, `OldPhoneButton` (:16) and `OldPhoneChoices` (:70), against the one-type-per-file rule → move `OldPhoneButton` to its own file (needs one more allowed file) or record the exception. (from: wave3 review)
- **could** packages/connection/lib/src/choice_fallback.dart:118 `phone.held` survives a dropped link, so a button released while the phone is away is not seen as released → clear `held` when the phone drops, or confirm the phone resends its state on reconnect. (from: wave3 review)
- **could** packages/connection/lib/src/choice_fallback.dart:17 The public constructors of `OldPhoneButton` (:17) and `OldPhoneChoices` (:71) have no dartdoc → add one line each. (from: wave3 review)
- **could** packages/connection/test/choice_fallback_test.dart:26 The `_Setup.choices` field (:30) is set at :78 and never read → remove the field. (from: wave3 review; checked by reading)
- **could** packages/connection/test/choice_fallback_test.dart:114 The literals 12 (:114) and 24 (:133-134) repeat the label and status limits → use the constants the code cuts to. (from: wave3 review)
- **could** packages/connection/test/choice_fallback_test.dart:207 The test "the outcome at close is the stored pick" repeats the path of the test at :185 → remove it or keep it as the only close check. (from: wave3 review)
- **could** packages/connection/lib/src/choice_round.dart:16 The doc calls a phone without the capability "legacy", while `choice_fallback.dart:66-68` and the brief say "old phone" → use "old phone" in `choice_round.dart:16-17`. (from: across jobs)

## Open questions
- Reopen the G3 verdicts? The wave1 verdicts dismissed the five-parameter rule (`choices.dart:90` ChoicesMessage, 9; `:7` ChoiceCard, 6) and one-type-per-file (`choices.dart:6`, four types) by saying no such rule exists in the docs. The worker extract states both rules. Suggested answer: reopen them, and give `choice_round.dart:20` the same value-object treatment too.
- Is a picked-but-unlocked card counted at timer end? `contract.md:22` still lists it as an assumption; `choice_round.dart:171-175` counts it. Suggested answer: yes, and move it out of the assumptions.
- Labels: card title cut to 12 (`choice_fallback.dart:179`), or title with count, as the owner's note "A = Build 1" reads? Suggested answer: keep the title (y0c Q1, decision taken), and confirm with the owner.
- Who owns pause, leave and "Get ready" for the grace and end timers (`choice_round.dart:98`, `:204`)? The wave2 verdict carries it to y0d. Suggested answer: a `Pausable` owner, built in y0d.
- A round's end at 300 ms versus the brief's 250 ms (`choice_round_test.dart:25`; y0g Q3). Suggested answer: keep 300 ms, the brief's own rule.
- Public statics `ChoicesMessage.maxCards` (`choices.dart:105`) and `ChoiceCard.maxCountLimit` (`:17`) are exported. Suggested answer: keep them public, since the decode checks in the same file use them.
- `packages/protocol/test/coverage_all_test.dart:10` is a hand edit to a generated file, with no `HAND-FIX` in `run.log`. The verdict says the generator gives the same line. Suggested answer: run the generator once to confirm, and log it.
- `docs/protocol.md` still lacks the three messages and the capability (the verdict defers this to y0d). Suggested answer: y0d adds it.

## Numbers against targets
- Grace 300 ms (`choice_round_test.dart:18`) meets the brief's "at least 300 ms" rule for new tests.
- End round 300 ms (`:25`) meets that rule but not the brief's last line, which says 250 ms (y0g Q3, recorded as a decision).
- Line length: 1 line over 120 columns (`choice_round.dart:141`), a miss of the 120-column target.
- `host_server.dart` is 380 lines, at the G3 limit of 380; there is no headroom for the next change.
- `choice_round.dart` 234, `choice_fallback.dart` 196, `choices.dart` 277 lines: all within 300.
- Test counts: y0a's report says 16 codec tests; the runner's count for `protocol` is 17. Not a target, but unexplained.
- No timing was measured; the real-timer race (M1, S4) is judged by reading.

## Could not check
- Nothing was run: this is a read-only job. The `tools/mine.sh` result, `dart analyze` and the tests were not run.
- `run.log:66-67`: y0c's checks failed, then were retried and committed; the retry's result is not logged, so the status of `40c11c06` is unknown.
- Whether the new tests fail on the old code: judged by reading the diff, not by checkout.
- `controller_app`: a search found no file that uses the new names; its own tests were not run.
- The host's own player as a choices player (review-rules A1): no caller in this run.
- `docs/coding-guidelines.md` and `docs/review-rules.md` were checked only for the rules the extract quotes.
