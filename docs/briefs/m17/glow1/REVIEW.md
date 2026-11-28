# glow1 run review (read-only)

## Summary

Verdict: one fix batch (plus one design question on the `gd` wire key).
Counts: must 1 · should 8 · could 7 (16 findings, all still holding in the final code; no run-findings.md, STATUS.md or REVIEW-VERDICTS.md exists).
Top five:
1. must `packages/puzzle_game/lib/src/match.dart:338`: `golden: golden` in `Match.snapshot()` is untested; no test calls `snapshot()`, so deleting it leaves all green.
2. should `packages/puzzle_game/lib/src/snapshot.dart:273` and `:328`: the `gd` key is a wire change with no `MatchSnapshot.version` bump, against the Nov 27 owner rule (wire changes only as a same-day TV+Android+iOS release). Needs Claude's design.
3. should `packages/party_host/lib/src/ui/present_pop_widgets.dart:66`: the boolean `paused` breaks `docs/coding-guidelines.md:50` ("Booleans read as questions"; `isPaused`). The wave-1 review said the rule was not in the file; it is.
4. should commit `901486e6`: the subject reads ``Subject: `fix(glow1): confetti freezes while the game is paused` `` (literal prefix and backticks). Rewording is a history rewrite, so Claude decides.
5. should `packages/party_host/test/present_pop_widgets_test.dart:156-158`: the "not replayed" check would pass even if a pop replayed on resume, because it pumps 1500 ms before checking.

Questions only the owner can answer: pop during a pause dropped or replayed (open_questions 1); whether `Pausable`'s paused covers host away and "Get ready" (2); the `gd` release route (3).

## Findings

- **must** packages/puzzle_game/lib/src/match.dart:338 `golden: golden,` in `Match.snapshot()` is untested: the five tests in golden_snapshot_test.dart build `MatchSnapshot` by hand → add a new test file that calls `PuzzleMatch.snapshot()` on a split match with a golden target and checks `golden` (from: g1, wave 1 review)
- **should** packages/puzzle_game/lib/src/snapshot.dart:273 and :328 `gd` is a wire change with no `version` bump (`version = 2` at :275) and no release route, against the Nov 27 owner rule → Claude decides: bump, or document why an old phone ignores the key, and how it ships (from: across jobs, g1)
- **should** packages/party_host/lib/src/ui/present_pop_widgets.dart:66 (field) and :60 (constructor) `paused` is a boolean named as an adjective; `docs/coding-guidelines.md:50` says booleans read as questions → rename to `isPaused` here, at the call site `puzzle_screen.dart:353-355`, and in the test file (from: c1; the wave-1 review missed this rule)
- **should** commit 901486e6 (c1) subject is ``Subject: `fix(glow1): confetti freezes while the game is paused` `` → the commit subject should be `fix(glow1): confetti freezes while the game is paused`; reword only if Claude approves a history change (from: c1; run.log:37)
- **should** packages/party_host/test/present_pop_widgets_test.dart:156-158 (both looks) the "not replayed" check waits 1500 ms after the resume, and a replayed burst would have ended by then → assert `findsNothing` straight after the resume pump, before any further pump (from: c1, wave 1 review)
- **should** packages/puzzle_game/lib/src/match_painter.dart:148 and :199, packages/puzzle_game/lib/src/match_view.dart:219 the golden wiring has no test: `golden_glow_paint_test.dart` builds `PuzzlePainter` directly → add a test that builds `MatchPainter` from a split snapshot with `golden` set and checks target 0 glows on both boards (from: g2, wave 2 review; phone-pinned)
- **should** packages/puzzle_game/lib/src/slot_paint.dart:21-23 (constants 24-27) four constants share one block comment; the brief asked for a doc line each → give `_goldenGlowMinAlpha`, `_goldenGlowMaxAlpha` and `_goldenPulseMs` their own `///` line saying why (from: g2, wave 2 review; phone-pinned)
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:353-358 the `Positioned.fill(` call is split over three lines and an unrelated comment is rewrapped (357-358), so the file grew by 1 line (379 → 380), not 0 as c1-report.md:13 says → put `Positioned.fill(child: PresentConfetti(tracker: _present, paused: paused)),` back on one line and restore the three-line comment; the file returns to 379 (from: c1, wave 1 review)
- **should** docs/protocol.md:334 the new frame key `gd` is not documented, while `cat` on the same line is → add one sentence on `gd` (the golden target's index, absent while none) beside the `cat` text; outside g1's `allow:`, so Claude decides (from: g1, wave 1 review)
- **could** packages/party_host/lib/src/ui/present_pop_widgets.dart:94 the resume test `_burst.value > 0` means a pause before the burst's first frame (value 0) loses the burst for good; a fix that only drops the `> 0` would start a burst on resume with no pop behind it, so it needs a "frozen mid-burst" flag → Claude's design; not reproduced (from: across jobs, read from the code only)
- **could** packages/party_host/test/present_pop_widgets_test.dart:143 and :159 `paused.dispose()` sits at the end of each test body, so a failed `expect` leaks the notifier → `addTearDown(paused.dispose)` after creating it (from: c1, wave 1 review; lines moved since that review)
- **could** packages/party_host/test/present_pop_widgets_test.dart (helper block, wave 1 cites :25-43) `pausableStage` repeats `stage` except for the `ValueListenableBuilder` → let `stage` take an optional paused notifier (from: c1, wave 1 review)
- **could** docs/briefs/m17/glow1/c1-report.md:23 "The remaining 1300 ms" is wrong: 700 of 1500 ms have run, so 800 ms remain → write 800 ms (from: c1; checked by reading the file)
- **could** docs/briefs/m17/glow1/g2-report.md:24 self-check 3 says the results state is "not tested", but `golden_slot.dart:71` clears the slot once a result is in → state that and say pause and "Get ready" were not checked (from: g2, wave 2 review)
- **could** packages/puzzle_game/test/golden_glow_paint_test.dart:36 every test paints the Sunny look, and the glow colour is that look's `star` → add one Night case or state the gap (from: g2, wave 2 review)
- **could** packages/puzzle_game/lib/src/snapshot.dart:367 `golden: t < 0.5 ? golden : next.golden` is not in the `lerpTo` dartdoc, which lists what each field does → add one line on `golden` (nearer frame wins) (from: g1, its question 1)

## Open questions

1. Should a pop during a pause be dropped (as built, present_pop_widgets.dart:85) or replayed on resume? Suggested: keep dropped.
2. Does `Pausable`'s paused (packages/party_host/lib/src/ui/pause_menu.dart:59, not read) also go true for host away and "Get ready"? Suggested: check, then say so in the c1 report.
3. `gd` without a version bump or a same-day release (snapshot.dart:273): bump, or document why an old phone ignores the key? Suggested: Claude decides on the release route before the batch.
4. The pulse test pins 0 vs 300 ms, not the brief's 0 vs 600 ms (a sine gives equal alpha there): accept and correct the brief's wording. Suggested: accept.
5. The golden glow sits above Easy's tint and the ready fill, not under it as the brief said: confirm. Suggested: keep.
6. Both boards glow the same target index: confirm intended. Suggested: yes.
7. The split test uses the farthest target because the neighbour's blur moves target 0 by 0.00059 in L: accept the exact-equality check or loosen it. Suggested: accept.
8. Commit 901486e6's subject: reword the history, or leave it? Suggested: leave it and note it in the batch.

## Numbers against targets

- `puzzle_screen.dart` 380 lines (limit 380 for a touched lib file): passes at the limit; 379 after the Positioned.fill fix above.
- `puzzle_painter.dart` 378 lines (limit 380): passes; the next change to it must split first.
- `snapshot.dart` 370 lines (limit 380): passes.
- `gd` frame cost: `,"gd":3` is 7 bytes for a one-digit target (g1 brief ceiling 7): met.
- Pulse check, brief 0 vs 600 ms: cannot differ (alpha 0.55 at 0 ms and 600 ms): target as written not met; test uses 0 vs 300 ms (0.55 vs 0.75).
- Freeze test progress: 200 / 1500 ms (0.133) paused, 700 / 1500 ms (0.467) resumed: matches the c1 report.
- Test counts: `present_pop_widgets_test.dart` declares 7 tests (6 × 2 looks plus 1 = 13 run), c1 reported "OK 14 tests": mismatch, not reconciled. `golden_snapshot_test.dart` declares 5, g1 reported "OK 6 tests" (the total may cover another file; not checkable). `golden_glow_paint_test.dart` declares 4; g2 reported "OK 16 tests" for the package.
- g2 turns: 42 against a cap of 35 (run.log:42, accepted by the runner): over.

## Could not check

- HAND-FIX lines: none in run.log. Hand steps not labelled so: "resume g1" and "resume c1 (applied by hand, not committed yet)" (run.log:29-30); no review of those hand steps beyond the job reports.
- Tests-first proof: g1 (run.log:15, :32) and g2 (run.log:44) have it; c1 is exempt in its brief. Review reports exist for g1, c1 and g2 and for both waves.
- Fixed, unverified: needs device check: c1 (confetti freezes on pause), on the TV look at distance; g2 (glow pulse) on the TV and phone boards and the Night look.
- controller_app's tests were not run or read (controller_app/pubspec.yaml:23 and :28 depend on party_host and puzzle_game), so every lib finding in those two packages is phone-pinned.
- Phone decoder for `gd` (an older build ignoring the key): not in the diff, not read.
- `Pausable` paused states: pause_menu.dart:59 located, not read.
- `pieceMean` and `capture` in test/support (wave 2): not read.
- The runner's test counts and `mine.sh` output: not in run.log; not re-run (read-only).

## Fix-job sizing

- Job A (puzzle_game tests, phone-pinned): match.dart:338 test; the MatchPainter/MatchView wiring test (match_painter.dart:148, :199; match_view.dart:219). Two new test files, no shared lib edits.
- Job B (party_host, c1 cleanup, one test file): rename `paused` → `isPaused` (present_pop_widgets.dart:60, :66; puzzle_screen.dart:353-355); replay check (test :156-158); dispose and helper (test :143, :159). Three findings in one job if the rename is kept to the test file's calls; otherwise split the helper out.
- The puzzle_screen.dart line-count fix (353-358) also edits `puzzle_screen.dart`, which Job B's rename touches: put it in Job B, so the file is edited once (four findings; split the helper cleanup out to keep Job B at three).
- Job D (puzzle_game docs, phone-pinned): slot_paint.dart:21-27 doc lines; snapshot.dart:367 lerpTo doc line.
- Job E (docs, not phone): protocol.md:334 `gd` sentence; c1-report.md:23 (800 ms); g2-report.md:24 wording.
- Design, Claude: `gd` version and release (snapshot.dart:273, :328); the `paused` flag for a burst paused before its first frame (present_pop_widgets.dart:94); the commit subject (901486e6).
- Could-level test gaps (Night look, Sunny-only): Claude's choice; leave out of the batch if the batch is at 3.
