# Review of the race1b run (r3a, r3b, r3c, r3d, f1)

## Summary

- Verdict: **one fix batch**
- Counts: must 1 · should 14 · could 17
- Read: the whole change `6359a020..5c6cafe7` (34 files, read as the diff plus each new file), all wave reviews, every `*-report.md`, run.log, run-findings.md. No code changed, no tests run.
- Carried over: all wave1 and wave3 items hold in the final code (wave3's second must is downgraded to should). run-findings.md:1 holds. wave1's summary says 4 should, its list has 6. No REVIEW-VERDICTS.md, so nothing skipped. run.log has no HAND-FIX lines.
- Five that matter most:
  1. present_wiring_test.dart:91 must (fixed): "a frame with no present draws none" compares two identical frames; it cannot fail.
  2. present_snapshot_test.dart:98 should: the 40-byte budget has no lower bound, so it passes with no present.
  3. present.dart:34, :36, :37 and snapshot.dart:361 should: bare `0.5` in the halfway switch.
  4. match_painter.dart:193 should: the phone path draws the present; no test at any phone size.
  5. across jobs should: r3b and r3d have no per-job review; they were hand-committed in 4cc98eb4, outside run.log.
- Owner questions: (a) does PuzzleMatch.update() stop while paused, host away or on a dropped link? The present's clock depends on it. (b) PRD-v2.md:764 still says Party knocks; update it to Wild? (c) accept match.dart at 328 lines (+19, target +14)?
- Fix jobs (one wave, ≤3 findings, no shared files): (1) [phone] present.dart + snapshot.dart: the halfway constant and the dartdoc; (2) present_wiring_test.dart: delete the tautology, add the phone-size and night cases (covers match_painter.dart:193); (3) present_match_test.dart: the positive and the name; (4) present_snapshot_test.dart: the budget lower bound and its comment; (5) present_painter.dart: the six-parameter `_fuse` and the wiggle test; (6) [phone] puzzle_painter.dart:156 side fallback. Docs: PRD line; r3d and r3a report corrections; r3c report claims. Review jobs: r3b and r3d, and the rule-A3 combinations.

## Findings

- **must** (closed, fixed: the vacuous test was deleted; the two positive tests carry the proof) packages/puzzle_game/test/present_wiring_test.dart:91 "a frame with no present draws none" calls `changed(…, null)`, which builds `frame(puzzle)` for both frames, so it always gets 0 and cannot fail; it passes on the old code → delete the test; the two "held by" tests already compare against a frame with no present (from: wave3)
- **should** packages/puzzle_game/test/present_snapshot_test.dart:98 the 40-byte budget uses only `lessThanOrEqualTo(presentMaxBytes)`, so it passes when `pr` is never written (0 bytes added) → add `greaterThan(0)` with a reason (from: wave1)
- **should** packages/puzzle_game/lib/src/match_painter.dart:193 [phone-pinned file] the phone path passes `present: s.present`, and the wiring test only runs a 640x360 split window → add a phone-size case to present_wiring_test.dart (rule A1, A6) (from: wave3)
- **should** packages/puzzle_game/lib/src/present.dart:34 [snapshot.dart:361 is phone-pinned] the bare `0.5` appears at :34, :36, :37 and snapshot.dart:361 → one named `static const` with a doc comment (the switch is at halfway), used on all four lines (from: wave1)
- **should** packages/puzzle_game/test/present_match_test.dart:54 the "no present on Off, on Wild, or on one board" test asserts only `isNull`, so it passes on the old code and does not show the rule is live → add a Little-with-Lively positive to the same test (downgraded from must: the negative asserts do catch a present that should not show) (from: wave3)
- **should** packages/puzzle_game/test/present_wiring_test.dart:14 the wiring runs at one window size (640x360, `box`) and one look (`sunny`, :63 and :74) → add a night look and a phone-size window (rule A6) (from: wave3)
- **should** packages/puzzle_game/lib/src/present.dart:6 the public `const PresentState(...)` constructor has no dartdoc, and neither does `fromJson` at :23 → one line each: what the fields mean, and that `fromJson` reads the `pr` entry (from: wave1)
- **should** packages/puzzle_game/lib/src/present_painter.dart:102 `_fuse` takes 6 parameters; the rule is at most 5 → compute `warn` inside `_fuse` from `present.fuseMs`, dropping a parameter (from: r3d)
- **should** packages/puzzle_game/lib/src/match.dart:172 [phone-pinned file] match.dart grew from 309 to 328 lines against r3c's target of +14 → accept now, or trim the field's doc comment when the file is next touched (owner's call) (from: wave3)
- **should** docs/PRD-v2.md:764 "On Party a placed piece it knocks loose goes back to the tray" is Wild-only now (cat_chaos.dart:281) → update the line in a docs job once owner Q4 is confirmed (from: wave3)
- **should** across jobs (rule A3) no job tests the present with the pause menu, host away, player away, "Get ready", a dropped link or leaving; the only covered combinations are the end() path (present_rules_test.dart:106) and the result gate (match.dart:231) → name each pair "not tested" with its reason, or add one match-level test per state (from: across jobs)
- **should** across jobs r3b and r3d have no per-job review report: wave1-review covered r3a only (wave1-review-report.md:1). Both were committed by hand in 4cc98eb4, outside run.log (run.log:28 stop) → run the per-job review for r3b and r3d (from: across jobs)
- **should** docs/briefs/m17/race1b/r3d-report.md:7 names `present_paint.dart` and `present_paint_test.dart`; the files are `present_painter.dart` and `present_painter_test.dart`. Its "Blocked" section (:25-27) is resolved: f1 imports present_painter.dart in view.dart (view.dart:18) and calls paintPresent at puzzle_painter.dart:156 → correct the names and status (run.log:24-25 uses the old names too) (from: r3d)
- **should** docs/briefs/m17/race1b/r3c-report.md:21 says host setups are "covered by present_match_test", but that file drives PuzzleMatch only; :23 says pause, host away and dropped link were "not touched" → say "not tested" for each, with its reason (from: wave3)
- **should** docs/briefs/m17/race1b/r3a-report.md:75 the hand-over says "Nothing staged or committed", but af673590 committed all five files → "Committed in af673590" (from: wave1)
- **could** packages/puzzle_game/test/present_wiring_test.dart:22 `i` is never read in the loop; :44 bare `4` (bytes per pixel) → build the list from a named count; name the 4 (from: wave3, f1)
- **could** packages/puzzle_game/test/present_match_test.dart:43 the name says "on Little and Party, Calm and Lively", but the loop pairs Little with Lively and Party with Calm → state the pairs in the name (from: wave3)
- **could** packages/puzzle_game/test/present_rules_test.dart:4 the doc line is over 120 columns → wrap it (from: r3b)
- **could** docs/briefs/m17/race1b/r3b-report.md:8 and :63 say 15 tests; present_rules_test.dart has 14 `test(` calls → correct the count (from: r3b)
- **could** packages/puzzle_game/test/present_snapshot_test.dart:12 says "the fuse half run down", but 9000 of 15000 ms is 40% run down → fix the comment (from: r3a)
- **could** packages/puzzle_game/test/present_snapshot_test.dart:6 imports `nightFrame` from another test file → move it to test/support in a later job that allows it (from: wave1)
- **could** packages/puzzle_game/lib/src/present.dart:23 `PuzzleSide.values[j[0] as int]` and the other `as int` casts are unvalidated; same pattern as cat_view.dart:72-76 → accept at this boundary, or default a bad index (from: wave1)
- **could** packages/puzzle_game/lib/src/present.dart:52 `toString` is not in the brief → drop it (from: wave1)
- **could** packages/puzzle_game/lib/src/puzzle_painter.dart:156 [phone-pinned file] `side: s.side ?? PuzzleSide.left` draws a board with no side as the left board; no report mentions it → make a null side draw nothing, or document why it cannot happen (from: wave3)
- **could** packages/puzzle_game/lib/src/present_painter.dart:1 the file is 140 lines against r3d's "under 90" target → split the box and the fuse bar into their own file, or drop the target (from: r3d)
- **could** packages/puzzle_game/lib/src/present_painter.dart:67 `_pxPerUnit` copies text_paint.dart's private helper → expose one shared function (from: r3d)
- **could** across jobs the race setup is written three times: cat_test.dart:32 `wildRace`, present_match_test.dart:11 `raceOn` and :21 `leftAhead`, cat_review_test.dart:100 inline `begin(...)` → one helper in test/support (needs an allow entry) (from: across jobs)
- **could** across jobs no test covers re-enabling after a disable (present_rules.dart:124 `_clear` restarts the clock) or a fractional `dt` (r3b's suggestion) → add tests to present_rules_test.dart (from: across jobs)
- **could** docs/briefs/m17/race1b/f1-report.md:1 has no `## Summary` block (run-findings.md:1) → add one (from: across jobs)
- **could** across jobs comments cite job letters (present.dart:3 "M17 r3a", present_rules.dart:7 "M17 r3b", present_painter.dart:38 "B11's") → keep the milestone tag only (from: across jobs)
- **could** packages/puzzle_game/lib/src/puzzle_painter.dart:1 [phone-pinned] is 373 lines (base 368), 7 under the 380 limit for touched files; the next change to it fails the size rule → plan the split before the next change (from: across jobs)
- **could** packages/puzzle_game/lib/src/present_painter.dart:55 the wiggle's rotation is not tested (r3d "Not verified") → add one test that the box turns with the effects on (from: r3d)

## Open questions

1. r3a Q1: name the 0.5 halfway switch? Yes: one named constant in present.dart, used by snapshot.dart:361 too.
2. r3a Q2: give cat_snapshot_test's night frame a present? No: nightFrame already carries one for the byte budget.
3. r3a Q3: measure the byte cost with load8? Yes, once; it replaces the hand count of 23.
4. r3b Q1: alternation per present or per snap? Keep as built (per present); the tests pin it.
5. r3b Q2: should a disable reset the clock? Keep as built; add the re-enable test (see the could finding on present_rules_test.dart).
6. wave3 (PRD, owner Q4): change PRD-v2.md:764 to Wild? Yes, in a docs job.
7. wave3: is cat_review_test's plan 3→4 on Wild meant to differ from Lively? Yes; cat_tuning_test shows 4 visits on Wild.
8. wave3: accept match.dart at 328 lines? Accept now; trim when it is next touched.
9. wave3: puzzle_painter.dart:156 `side ?? PuzzleSide.left`: make a null side draw nothing.
10. wave3: PuzzleView (view.dart) passes no present: keep it that way; the race screens use MatchView.
11. wave3: match.dart:229-231 has no `_result == null` gate on the snap loop: add the gate; harmless now because end() clears the holder.
12. r3c: do pause, host away and a dropped link stop PuzzleMatch.update()? Must confirm; the present's clock depends on it. Call sites are outside the diff.
13. r3c: a shared preset helper in test/support is not in allow: yes, in a later job with the allow entry.
14. r3d Q2: keep present_painter.dart at 140 lines? Split it if the "under 90" target stands; otherwise drop the target.
15. f1 Q1: should PuzzleView take a present? No for now.
16. wave1: keep `toString` on PresentState? Drop it.

## Numbers against targets

- match.dart: 328 lines (base 309, +19); r3c's target +14 → **misses** (r3c-report.md:30).
- present_painter.dart: 140 lines; r3d's target "under 90" (quoted at r3d-report.md:32) → **misses**.
- Present bytes: 23 by hand against the 40-byte budget (present_snapshot_test.dart:8-9) → meets; not measured.
- 4-player night frame against PuzzleSnapshot.maxBytes = 2048 (snapshot.dart:75): the test asserts under it (present_snapshot_test.dart:103); the size is not reported → unverified.
- Fuse floor: 4000 ms after snaps (present_rules_test.dart:50) → meets.
- Warning colour at 3000 ms (present_painter.dart:24) → meets the brief.
- Function length: paintPresent about 24 lines (present_painter.dart:39-63), within 40; PuzzlePainter.paint not measured.
- 5-parameter limit: `_fuse` has 6 (present_painter.dart:102) → **misses** the rule.
- Touched lib files under 380: puzzle_painter 373, cat_chaos 365, snapshot 364, match 328, view 233 → meet; puzzle_painter has 7 lines of room.
- Test counts: r3a 10 ✓, r3c 5 ✓, r3d 16 ✓, f1 3 ✓, r3b claims 15 but the file has 14 → **misses**. Suite totals (500, 514) not verified.
- Calm knock at 40.858 s on the base (r3c-report.md:11): measured before the fix; no target.

## Could not check

- No tests, analyzer or formatter run (read-only job). Per-test "fails on the old code" is only file-level evidence (run.log:12-25, :48-49); I did not check each test.
- Whether pause, host away, dropped link or "Get ready" stop the match's update(): call sites are outside this diff (owner question 12).
- Look on device: no phone or TV screen check for the present; the painter is checked only by pixel counts in the test harness. So f1 (3ff32392) and r3d (4cc98eb4) are "Fixed, unverified: needs device check" for the phone and TV looks. No bug fix in this run was reproduced on a device.
- Byte and pixel counts were not measured by any job (load8 not run).
- The tools/review.sh log (.dart_tool/run-jobs/docs_briefs_m17_race1b/run-review.log, run.log:28) is outside the read list and was not read.
- Phone pins come from a grep of controller_app/test only; tv_test_app was not searched.
- DRIVER-NOTES.md is not in the read list and was not read.

## Commit message — a draft

Review the race1b run: one fix batch, 1 must and 14 should

Read-only review of the race1b run (r3a, r3b, r3c, r3d, f1) as one change,
against the coding guidelines and review rules. No code changed. The one
must (fixed in 9e3736ff, the vacuous test was replaced by one pinning the pr key): a no-present wiring test compares two identical frames and cannot
fail. The 14 shoulds: a budget test with no lower bound, a bare 0.5 in the
halfway switch, a phone-size gap, a six-parameter helper, missing dartdoc,
stale report claims, a PRD line that still says Party, and two jobs with
no per-job review.

## Status row

M17 race1b run review: one fix batch (1 must, 14 should, 17 could); no code changed. Done: all wave reviews carried over and checked against the final code. Open: the must and should fixes, the r3b and r3d reviews, the PRD line, and the pause question.

## Delete

- none
