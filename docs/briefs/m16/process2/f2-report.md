# f2 report: stop-safe reviews, a review that RUN_MAX_MIN can end

## Summary

All three brief items are done, inside `allow:`, and the checks pass.

1. **A wave review is skipped only when its committed report covers the wave.** `review_covers` in
   `tools/run-review.sh` looks for every job of `RV_NAMES` in the committed
   `$B/wave$1-review-report.md` as a whole name. A job committed after that report (a split's second
   job, a hand-fix restart) gets a review of its own, briefed as `wave$1-<first job>`, so it is a new
   review, not a resume of the old one. The wave-1-is-the-whole-run skip is unchanged.
2. **A stop waits for a running wave review.** `stop` in `tools/run-jobs.sh` flushes the running
   reviews (`flush_reviews wait`) before it kills the children, for every cause except `stop file`:
   a person asking the run to end wants it gone at once, and the test pins that the report is then
   not kept. Without the wait a stop lost the review's report, because the kill came first.
3. **The run's final review runs in the background and is polled.** `run_review` (new, in
   `run-review.sh`) starts `tools/flash.sh --brief run-review.md` with `&` and polls it with
   `while kill -0 "$pid"; do check_stop; sleep 5; done`, the same 5 s poll a job gets. So the STOP
   file is seen during it, and `RUN_MAX_MIN` ends a stuck review with `STOPPED: TIMEOUT` instead of
   waiting behind it. `final_review` keeps the result-4 churn salvage and the `REVIEW.md` check; the
   inline block moved out of `run-jobs.sh`, which is now 326 lines (limit 340).

Sizes: `run-jobs.sh` 326, `run-review.sh` 120, `run-wire-test.sh` 321, `run-jobs-split-test.sh` 189.
Checks: `tools/selftest.sh tools/tests` 7/7 PASS in 197 s (`run-wire` 85 s, split 10 s);
`tools/check.sh format` PASS (10 s).

## Files changed

- `tools/run-review.sh`: added `review_covers`; `wave_review` skips only on a covering report and
  otherwise briefs `wave$1-<first job>`; added `run_review` (background, 5 s `check_stop` poll) and
  `final_review` (moved out of `run-jobs.sh`, keeping the result-4 salvage), with doc comments on all
  three. 120 lines.
- `tools/run-jobs.sh`: `stop` waits for running reviews before the kill, except for `stop file`; the
  final-review block replaced by `final_review`; header text updated (and its `-h` range). 326 lines.
- `tools/tests/run-wire-test.sh`: new cases 11, 12, 13, a `date` stub fake clock (on PATH only while
  `STUB_NOW` is set), a slow-review branch and a STOP-on-fail branch in the flash stub; per-case
  `timeout -k 5 60`; header documents the f2 cases.
- `tools/tests/run-jobs-split-test.sh`: four wave-review naming cases through a `rv_wave` helper that
  sources `run-review.sh` first and then replaces `review_brief` (a fake defined before the source is
  overwritten by the real one); `review_covers`, `run_review`, `final_review` added to the
  defined-once list.
- `docs/briefs/m16/process2/f2-report.md`: this report.

## Tests and the values I computed

`tools/tests/run-jobs-split-test.sh` (fast, each case builds a repo whose
`docs/briefs/fix/wave1-review-report.md` is committed, `WAVES=(one two)`, `review_brief` fake):

- covered: report text `# Wave1 review: runjob`, `RV_NAMES=(runjob)` → `WREV` empty (skip).
- uncovered: `RV_NAMES=(runjob otherjob)` → `wave1-runjob` (the report names `runjob` only).
- boundary: report names `p2-split`, `RV_NAMES=(p2)` → `wave1-p2` (a whole-name match: `p2` inside
  `p2-split` does not cover it).
- no committed report: `wave1` (today's behaviour).

`tools/tests/run-wire-test.sh`:

- case 11: `more_briefs runjob failjob`, `seed_report runjob` (the runner resumes `runjob`, so no job
  poll), `STUB_REVIEW_SLEEP_S=6`, `STUB_FAIL_BRIEF=failjob.md`. Expected and measured: rc 1,
  `STOPPED: jobs that failed`, `HEAD:$batch/wave1-review-report.md` present, `review-done` marker
  present — the report survives the stop.
- case 12: the same plus `STUB_STOP_ON_FAIL=1` (the failing stub writes `$batch/STOP` and sleeps 30
  s, so the runner's poll reaches `check_stop` instead of exiting it). Expected and measured: rc 1,
  `STOPPED: stop file`, the report absent from the worktree and from `HEAD`, no `review-done`.
- case 13: `seed_report runjob`, `STUB_REVIEW_SLEEP_S=30`, the `date` stub reading `STUB_NOW` and
  jumping it by `STUB_JUMP_S=3600` when the review starts, `RUN_MAX_MIN=1` (60 s). Expected and
  measured: rc 1, `STOPPED: TIMEOUT`, `review-start` present, no `REVIEW.md`, no `review-done`,
  real elapsed under 25 s.

Both new run-wire cases cost the runner's fixed 5 s poll per review plus the 6 s stub sleep; a
review runs about 11-16 s in the test.

The new cases fail on the code as it was, reasoned case by case (`git checkout` is forbidden to me, so
this is not observed): the old `wave_review` skipped whenever the report was committed, so the
uncovered and boundary cases returned `none`; the old `stop` killed before `flush_reviews`, so case
11 found no report; the old final review ran in the foreground with no time check, so case 13 came
back rc 0 after the 30 s sleep instead of `STOPPED: TIMEOUT`. The covered and STOP-file cases pass on
the old code too: they pin behaviour that must stay.

## Self-check (review rules part A)

1. **Every host setup:** not affected — no app code, no UI, no protocol; the change is in the shell
   runner. Shown by `tools/selftest.sh tools/tests` (all runner cases still pass).
2. **Kept state:** the review pid, `REVPIDS` and a wave's `RV_NAMES`/`RV_RANGES`. They start at
   `wave_review`/`save` and end at the next serial `flush_reviews` (or the stop's `flush_reviews
   wait`); `wave_review` clears both arrays, so with nothing going on no brief is written. Shown by
   the four split `rv_wave` cases and run-wire 11/12.
3. **Combines with:** a stop waits for a running wave review (case 11); the STOP file does not
   (case 12); the final review ends on the time limit (case 13) and on `check_stop` inside the same
   poll (the STOP file during it takes the `stop file` cause, so no wait). No round, pause or player
   state is involved.
4. **Stay in the job's folder:** only the five allowed paths changed; `git status` shows nothing else
   of mine.
5. **Stop rather than overstep:** nothing needed outside `allow:`; the two calls I would have made
   differently are in Questions rather than in the code.
6. **Every look:** not affected — no look-sized widget, no UI.

## Questions

1. `script-rules.md:10` puts a self-test at 60 s; `run-wire` is now 85 s (was 44 s), because each
   review case pays the runner's fixed 5 s poll. A `REVIEW_POLL_S` setting (default 5, the tests set
   1) would bring it to about 50 s. I did not add one: the brief fixes the 5 s poll.
2. `RUN_MAX_MIN=0` cannot reach the final review — a `check_stop` in the wave loop fires first — so
   case 13 uses a fake `date` clock with `RUN_MAX_MIN=1` and a stub that jumps the clock by 3600 s.
   A literal 0 knob needs the run to get past every earlier `time_check`; is the fake clock the
   intended test shape?
3. The brief says every cause except the STOP file waits for a running wave review, so a `TIMEOUT`
   stop waits for a stuck *wave* review too (its own timeout is checked before it starts). Say if
   TIMEOUT should skip the wait like the STOP file.
4. Debug scratch files from this job remain at `.dart_tool/wire-progress` and
   `.dart_tool/wire-trace` (gitignored, untracked); `rm` is denied to me — please delete them.

## Suggestions

- Give the runner one poll interval setting (`REVIEW_POLL_S`/`JOB_POLL_S`, default 5) so the
  self-tests can run faster and the poll is not repeated as a literal in three loops.
- `review_covers` is deliberately conservative (a job named only as `name-report.md` does not count
  as covered); a `docs/` report convention that always writes the bare job name in a heading would
  make re-reviews rarer.

## Commit message

```
Wait for a wave review at a stop; poll the run's review

A wave review is skipped only when the committed wave1-review-report.md names
every job of the wave; a job committed after it is reviewed as wave1-<job>.
stop waits for a running wave review and flushes its report before the kill,
except for the STOP file, which kills at once.
The run's final review runs in the background under the 5 s check_stop poll,
so RUN_MAX_MIN ends a stuck review with STOPPED: TIMEOUT.
```

## Status row

Done: a stop keeps a running wave review's report (except the STOP file), an uncovered wave is
reviewed as `wave1-<job>`, and the final review is polled so RUN_MAX_MIN stops it; open: the
run-wire self-test is 85 s against the 60 s target (a poll-interval knob would fix it).

## Delete

- none
