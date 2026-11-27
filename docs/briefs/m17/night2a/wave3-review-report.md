# Wave 3 review (night2a f1, f2)

## Summary

- Verdict: small fixes
- Counts: must 2, should 3, could 2
- 1. `night_director.dart:128` breaks the 120-column rule; f1-report says no line is over 120.
- 2. The ten-draw pickers test passes on the base code by construction (brief item 3b asked for it).
- 3. The `steady` dartdoc is wrong for a close table whose tier cannot rise (it reports steady).

## Findings

- **must** packages/party_host/lib/src/night/night_director.dart:128 `_choose` signature is over 120 columns, though brief item 4(b) required 120 or fewer and f1-report claims none is → wrap the named parameters one per line, then run `dart format` and `grep -n '.\{121,\}'` again.
- **must** packages/party_host/test/night_pickers_test.dart:30 the ten-draw no-repeat test passes on the base code by construction (no code change is needed to pass it), so it has no failing-first proof → keep it only if Claude accepts the brief's exemption for pinned behaviour; otherwise drop it.
- **should** packages/party_host/lib/src/night/night_director.dart:11 the `steady` dartdoc says steady means neither lopsided nor close, but `_reasonFor` (lines 111-112) also returns steady for a close table whose tier cannot rise: pool [shapeHard], played [shapeHard], totals [10, 9] gives shapeHard with reason steady → name that case in the dartdoc, or give it its own reason (see Decisions).
- **should** packages/party_host/lib/src/night/night_director.dart:43 `NightDirector` is a third public type in a file that also holds `DirectorReason` (line 7) and `DirectorPick` (line 25) → move `NightDirector` to its own file, as f2 did for the pickers, or state the exception in the report.
- **should** packages/party_host/test/night_director_test.dart:127 a comment line is over 120 columns → rewrap the comment.
- **could** packages/party_host/test/night_director_test.dart:77 the name says "eases one tier", but the test asserts `kindForLastPlace` (a kind pick) and repeats the rule of the test at line 86 → rename it to say it picks the kind variant, or drop it.
- **could** packages/party_host/test/night_pickers_test.dart:41 `expect(played.take(_pool.length).toSet(), _pool.toSet())` repeats the check at line 27 of the first test → drop line 41.

## Decisions to confirm

- A table of one total is steady (`night_director.dart:117`): a one-player night no longer raises a tier. The brief asked for this; f1-report question 2 asks for confirmation.
- The one-player test (`night_director_test.dart:135-143`) expects shapeEasy with reason steady, not "same tier" as brief item 3 asked. With that pool, easy and hard tie at distance 1, so "same tier" cannot hold. Confirm, or add medium to the pool.
- A close table at the top tier reports `steady` (finding 3). Decide whether the B8 caption needs its own reason for it.
- f2 also added the explicit null check in the `generate` helper (`night_pickers_test.dart`, the `played.add(next!)` with no `expect` before it). Item 3a names only the ones after an `expect`. The change is harmless.
- f2 did not apply `probe-f2.patch`. That is the right call: it adds stub files with the real names.

## Could not check

- No test, analyzer or format run: this review is read-only. I traced the five new director tests by hand against the code; each fails when its rule is removed (values below). I did not re-run the mutation proofs claimed in f1-report.md.
- The counts claimed by `tools/mine.sh` (14 and 18 tests) are not verified.
- `run-findings.md`: a grep for director, picker, f1 and f2 found no entries about these jobs. I did not read the file whole.
- `coding-guidelines.md`: I used the worker extract plus a grep of the one-public-type rule; I did not read the whole file.
- `review-rules.md` parts B and C do not apply: no game, UI or protocol code changed. No docs changed except the two job reports.
- Column counts come from `grep` on `.{121,}`, which counts characters.

Values traced by hand (lead = leader − last; lopsided when lead ≥ 0.5 × leader; close when lead ≤ 0.2 × leader):
- (a) [10, 6]: lead 4, steady; target 1; with rule b the options are shapeMedium and shapeEasy, so the result is shapeMedium (test expects shapeEasy); without the rule the test fails.
- (b) [10, 2], played shapeHard: lopsided, target 1, kind = {shapeEasy}, so shapeEasy with kindForLastPlace; without rule d the result is arenaMedium with easedAfterLopsided.
- (c) [10, 2], played arenaHard: lopsided, target 1, no kind; shapeMedium with easedAfterLopsided; without the ease the target is 2 and the result is shapeHard.
- (d) [10, 9], played arenaEasy: lead 1, close, target 1; shapeMedium with raisedAtCloseTable; without the raise the target is 0 and the result is shapeEasy with steady.
- one player [10]: the base code gives close, target 2, shapeHard with raisedAtCloseTable; the new code gives steady, and the tie goes to shapeEasy.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

wave3 review: night2a f1 and f2 (findings only)

Read-only review of the night2a f1 (director) and f2 (pickers) jobs against
the guidelines, the review rules and their briefs. Writes only this report.
Findings: 2 must, 3 should, 2 could. Must: the _choose signature in
night_director.dart is over 120 columns (the f1 report says none is), and the
ten-draw pickers test passes on the base code by construction.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2a wave 3 review (f1, f2): done, verdict small fixes (2 must, 3 should, 2 could). Open: wrap `_choose` in night_director.dart:128, decide on the ten-draw test, fix the `steady` dartdoc, split NightDirector out of night_director.dart, confirm the solo-table and one-player decisions.

## Delete

- none
