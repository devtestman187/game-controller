# night2b f1 — report

## Summary

Three fixes from the wave 1 review, no new feature, no change to the pick rules.

1. **settleVote: a repeated offer counts once.** `offered` is now reduced to its distinct variants before the count and
   the tie-break. Before, `[A, A, B]` with one vote each gave A two of three draws (134 of 200 seeds on the base).
2. **NightPickNotifier.build: no night, no played list.** With `partyNightProvider` null at build, the saved played
   list is cleared and none is loaded. A saved list is loaded only for a running night.
3. **Director tests.** The seeds 0 to 19 loop replaces the single-seed check, and there is one opening case at
   `difficultyMin` medium.

Decisions:
- The brief's 30 to 70 percent band for the tie test cannot fail on the base (the base gives 67 percent), so the band
  is 40 to 60 percent (80 to 120 of 200). Under the fix the expected count is about 100.
- The existing test "the played list survives a new container on the same prefs" started its night with no round
  played. `NightSave.load` drops a night with round 0, so after the change the second container had no running night.
  I added one `recordRound` to that setup so the night is a running one. The assertion is unchanged.

Test counts: `flutter test` on the two files, base run: 27 passed, 2 failed (the tie case and the first-read case).
After the fixes: 29 passed. `tools/mine.sh`: format OK, analyze OK, 46 tests in party_host OK.

Self-check (review-rules part A):
1. Host setups: pure logic and provider tests, no host UI touched. Covered by the existing host tests (46 pass).
2. Kept state: the played list starts empty with no night and is cleared when none runs (new test "with no night
   running, the first read clears..."); kept for a running night ("the played list survives a new container...").
3. Combinations: the night end path is unchanged (`_forgetNight`, test "the played list is cleared when the night
   ends", passes).
4. Only the four allowed lib and test files, plus this report.
5. Nothing stopped.
6. No look or layout changed.

## Hand-over

- The tie fix is in `settleVote`; `offerFor` already gave distinct offers, so only `settleVote` needed the change.
- The director loop (seeds 0 to 19) passed on the base too. It guards the played-list rule but does not pin a fix.
- The exact count of the tie test after the fix was not printed; it passed the 80 to 120 band.

## Commit message

Fix tie odds for repeated offers, clear the played list with no night

A game offered twice counted and drew twice in settleVote, so it won a 1-1 tie two times in three. Settle over the
distinct offered games instead. NightPickNotifier.build now clears the saved played list when no night is running,
rather than loading it; a saved list is kept only for a running night. Tests: the tie over 200 seeds, the first read
with no night, a director loop over seeds 0 to 19, and an opening at medium.

## Status row

M17 night2b f1: done — repeated-offer tie, no-night played-list clear, director tests; open: none in this job.

## Delete

- none
